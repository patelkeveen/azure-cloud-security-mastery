# Service Principals

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (updated 2026-06-15).
> **SC-300 Domain 3 core.** Full depth in
> **[LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md](LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md)**.
> The runtime half of [`../app-registrations/`](../app-registrations/).

---

## 1. What it is

The **local instance** of an application in a specific tenant. Where the application object is the
blueprint, the service principal is the thing that **holds permissions, gets assigned roles, and
appears in sign-in logs**.

> ⭐ **A service principal is a security principal, exactly like a user.** It can be granted RBAC,
> assigned app roles, targeted by Conditional Access — and, this is the part people forget,
> **compromised**.

| Type | Has an app object? | Notes |
|---|---|---|
| **Application** | Yes | The normal case |
| **Managed identity** | **No** | Can be granted permissions; **cannot be modified directly** |
| **Legacy** | No | Pre-registration era; tenant-local only |

---

## 2. The per-tenant model, and what follows from it

**One application object. One service principal per tenant where the app is used.**

- **Permissions consented in Contoso's tenant have no effect in Fabrikam's.** Each tenant's admin
  consents for their own SP.
- ⭐ **Deleting the app object deletes its home-tenant SP — and restoring the app does not restore
  the SP.** Every role assignment and consent goes with it.
- **Prefer deactivation over deletion during an incident.** It stops token issuance while preserving
  both objects as evidence.

---

## 3. ⭐ The permission asymmetry that defines the risk

| | **Delegated** | **Application (app-only)** |
|---|---|---|
| Acts as | The signed-in user | ⭐ **Itself** |
| Effective access | **Intersection** of app permission **AND** the user's rights | ⭐ **The full permission. No intersection.** |
| Token claim | **`scp`** | ⭐ **`roles`** |
| Consent | User or admin | **Admin only** |
| Runtime consent | Incremental/dynamic supported | ✅ **No dynamic consent** — all permissions declared up front |

```
Delegated:     effective = app permission  ∩  user's own rights
App-only:      effective = app permission              ← nothing constrains it
```

**`Mail.Read` as an application permission reads every mailbox in the organisation.**
`Directory.ReadWrite.All` is effectively tenant admin.

✅ Microsoft's own test for when app-only is correct:

- Runs **automated, without user input**
- Needs resources belonging to **many different users**
- ⭐ *"You find yourself tempted to store credentials locally and let the app sign in **as** the user"*

✅ And the inverse, stated plainly: **never use app-only where a user would normally sign in to
manage their own resources.** Those scenarios must be delegated to be least privileged.

---

## 4. ⭐ Who can consent — and Graph is gated higher ✅

| Resource | Minimum role to grant **app-only** permissions |
|---|---|
| **Microsoft Graph** | ⭐ **Privileged Role Administrator** |
| Other resources | Application Administrator, Cloud Application Administrator |

> ⭐ **Application Administrator cannot grant Graph app roles.** That distinction is deliberate —
> Graph app-only permissions are effectively tenant-wide data access, so they sit behind a higher
> bar than "can manage applications". It is also a precise exam answer and a real design constraint
> when delegating app management.

✅ **Consumer Microsoft Accounts can never authorise app-only access.**

---

## 5. Worked example — ranking service principals by blast radius

**This is the assessment deliverable.** Do not list service principals; **rank them by what they
could do if compromised.**

```powershell
Connect-MgGraph -Scopes 'Application.Read.All','Directory.Read.All'

$critical = @('Directory.ReadWrite.All','RoleManagement.ReadWrite.Directory',
              'Application.ReadWrite.All','User.ReadWrite.All','Mail.Read','Mail.ReadWrite',
              'Mail.Send','Files.ReadWrite.All','Sites.FullControl.All')

$graph = Get-MgServicePrincipal -Filter "displayName eq 'Microsoft Graph'"
$roles = @{}; $graph.AppRoles | ForEach-Object { $roles[$_.Id] = $_.Value }

Get-MgServicePrincipal -All | ForEach-Object {
  $sp = $_
  $granted = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -ErrorAction SilentlyContinue |
             ForEach-Object { $roles[$_.AppRoleId] } | Where-Object { $_ }
  $risky = $granted | Where-Object { $_ -in $critical }
  if ($risky) {
    [pscustomobject]@{
      SP     = $sp.DisplayName
      Owners = (Get-MgServicePrincipalOwner -ServicePrincipalId $sp.Id -EA SilentlyContinue).Count
      Risky  = ($risky | Sort-Object -Unique) -join ', '
    }
  }
} | Sort-Object { ($_.Risky -split ',').Count } -Descending
```

```
SP                        Owners  Risky
------------------------  ------  ------------------------------------------------
Legacy Migration Tool          0  Directory.ReadWrite.All, Mail.ReadWrite, User.ReadWrite.All
Contoso Analytics Add-in       1  Mail.Read, Files.ReadWrite.All
Backup Service                 0  Files.ReadWrite.All
```

**Read that like a consultant.** `Legacy Migration Tool` — a migration finished years ago, **zero
owners**, still holding `Directory.ReadWrite.All`. That single row is worth the engagement: it is
tenant-admin-equivalent, nobody owns it, and nobody can authorise disabling it during an incident.

> ⭐ **Over-privileged application permissions are the standard critical finding, and the one
> customers cannot produce themselves.** Sort by blast radius, then by owner count.

---

## 6. ⭐ Constraining app-only access — the answers to "but it reads every mailbox"

App-only access is unconstrained **by default**. It does not have to stay that way:

| Mechanism | Effect |
|---|---|
| ⭐ **`Application.ReadWrite.OwnedBy`** | ✅ The app can manage **only service principals it owns** — its own identity constrains it |
| **Least-privilege role selection** | ✅ `User.ReadBasic.All` instead of `User.Read.All` when you only need to identify users |
| ⭐ **Exchange application access policy** | ✅ Exchange Online supports **limiting application permissions to specific mailboxes** |
| **Narrow app roles when publishing an API** | ✅ Avoid one role granting full read/write to everything |

> **"`Mail.Read` means every mailbox" is true out of the box and avoidable in practice.** Being able
> to name the Exchange application access policy — scoping an app to one mail-enabled security group
> — is what turns "that's too much access" into a design.

⚠ When defining app roles on your own API, **select `applications` as the only allowed member type**
if the role is meant for app-only access; app roles can also be assigned to users and groups, and
mixing them silently widens the grant.

---

## 7. Where they hide, and how to monitor them

Service principals accumulate from places nobody tracks: SaaS integrations consented by users,
migration tools granted broad access and never revoked, CI/CD pipelines, monitoring agents,
Microsoft first-party apps, and increasingly **agent identities**.

**They outnumber human identities in most tenants and almost none have a recorded owner.**

⭐ **Service principal sign-ins are not in `SigninLogs`:**

```kusto
AADServicePrincipalSignInLogs
| where TimeGenerated > ago(30d) and ResultType == 0
| summarize Countries = make_set(LocationDetails.countryOrRegion), Signins = count()
    by ServicePrincipalName, AppId
| where array_length(Countries) > 1
| sort by Signins desc
```

**Investigating a compromise with `SigninLogs` alone misses this entirely** — which is exactly why
modern attackers persist here. See
[`../../50-security-operations/threat-hunting/`](../../50-security-operations/threat-hunting/) §6.

⚠ Risky workload identity detections require **Workload Identities Premium** — a separate licence.
See [`../identity-protection/`](../identity-protection/) §5.

---

## 8. What breaks

**Treating an SP as "just config."** It is a principal with permissions and a credential.

**Granting application permissions when delegated would do.** §3 — ask whether a user is present.

**No owner recorded.** Nobody can authorise disabling it during an incident.

**Assuming deletion is recoverable.** §2.

**Expecting Application Administrator to grant Graph app roles.** ⭐ Needs Privileged Role
Administrator.

**Expecting dynamic consent for app-only.** ✅ Not supported — declare everything up front.

**Querying `SigninLogs` for workload identities.** §7 — wrong table.

**Publishing an app role without restricting member types**, so users and groups can hold it too.

**Long-lived secrets.** Prefer [`../managed-identities/`](../managed-identities/) or
[`../workload-identity-federation/`](../workload-identity-federation/).

**Leaving a migration tool's permissions in place** after the migration. §5.

---

## 9. Customer discovery questions

1. How many service principals hold **`Directory.ReadWrite.All`**, `Mail.Read`, or
   `Application.ReadWrite.All`?
2. How many have **zero owners**? *(§5 — the fastest finding.)*
3. Are any application permissions **scoped** — Exchange application access policy,
   `Application.ReadWrite.OwnedBy`?
4. Who can grant Graph app roles today? *(Should be a small Privileged Role Administrator set.)*
5. Is **`AADServicePrincipalSignInLogs`** collected and monitored?
6. Are there SPs from **completed migrations** still holding permissions?
7. Are workload identities in scope for **PIM** and access reviews?
8. Is **Workload Identities Premium** licensed for risk detection?
9. Do any SPs use client secrets rather than certificates or federation?

---

## 10. Remember it

**Hook — "Delegated intersects. App-only doesn't."** And the claims: **`scp` = delegated,
`roles` = app-only.**

**Analogy — a contractor's pass versus an escorted visitor.** A **delegated** app is an escorted
visitor: it can only reach rooms *both* the escort is allowed into *and* the pass permits — the
intersection. An **app-only** app holds a **contractor's master pass**: no escort, no intersection,
every room the pass names, at 3am, forever. **Which is why nobody should be issued a master pass
because it was convenient during a migration** — and why the pass with no registered holder (zero
owners) is the one you find first.

**The one thing:** ⭐ **application permissions have no user-rights intersection.** `Mail.Read` reads
**every** mailbox. That is the whole risk model — and the mitigations exist
(`Application.ReadWrite.OwnedBy`, Exchange application access policies, narrower roles), they are
just rarely applied.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 11. Self-test

1. How many SPs does one application object have?
2. Delegated versus application permissions — how is effective access calculated for each?
3. Which token claim carries each?
4. What is the minimum role to grant **Graph** app-only permissions, and why is it higher?
5. Does app-only access support dynamic consent?
6. Name two ways to constrain an app-only permission that "reads every mailbox".
7. Which table holds service principal sign-ins?
8. What happens if you delete an app registration and restore it?
9. Why is an SP with zero owners a finding, not an untidiness?
10. When is app-only the *wrong* choice?

<details>
<summary>Answers</summary>

1. **One per tenant** where the app is used — a multi-tenant app has one in every consenting tenant.
2. **Delegated = intersection** of the app's permission and the signed-in user's rights.
   **App-only = the full permission**, with no intersection.
3. **`scp`** for delegated, **`roles`** for app-only.
4. **Privileged Role Administrator.** Graph app roles are effectively tenant-wide data access, so
   they sit above "can manage applications".
5. **No** — all app-only permissions must be declared up front and admin-consented.
6. **`Application.ReadWrite.OwnedBy`** (self-scoping), an **Exchange application access policy**
   (specific mailboxes), or simply a narrower role such as `User.ReadBasic.All`.
7. **`AADServicePrincipalSignInLogs`** — not `SigninLogs`.
8. The **service principal does not return**; role assignments and consents are lost. Deactivate
   instead during an incident.
9. **Nobody can authorise disabling it during an incident**, and nobody will ever review its
   permissions.
10. Whenever a **user would normally sign in to manage their own resources** — that must be
    delegated to be least privileged.

</details>

---

## 12. Evidence this topic needs

- **`lab/`** — register an app, find its SP, confirm same `appId` and different object IDs; run the
  same Graph call **delegated as a non-privileged user** and then **app-only**, and compare results.
  That contrast is §3 made concrete.
- **`break-fix/`** — delete and restore an app registration; **prove the SP did not return**.
- **`security/`** ⭐ — the §5 blast-radius report; SPs with zero owners; the multi-country sign-in
  detection deployed; Exchange application access policy applied to at least one app.
- **`operations/`** — the NHI register (see [`../nhi-incident-response/`](../nhi-incident-response/));
  owner assigned to every SP; credential type and expiry per SP.
- **`architecture-decisions/`** — ADR: delegated-by-default policy, and the approval path for any
  application permission.
- **`customer-use-cases/`** — §9 answered against a real tenant.
