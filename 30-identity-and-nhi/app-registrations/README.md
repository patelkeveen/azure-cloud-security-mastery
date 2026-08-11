# App Registrations

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (updated 2026-06-15).
> **SC-300 Domain 3 core.** Depth in
> [Layer 4 §5](../service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md).

---

## 1. What it is

An **application object** — the globally unique definition of an application in its **home tenant**.
It declares how tokens may be issued, what resources it needs, and what it can do.

**It is a blueprint, not a running identity.**

---

## 2. The distinction that governs everything

```
APPLICATION OBJECT  (one, home tenant only)   →  App registrations blade
        │ template for
        ▼
SERVICE PRINCIPAL   (one PER TENANT)          →  Enterprise applications blade
```

1:1 with the software, 1:many with service principals. A single-tenant app has one SP; a
multi-tenant app gets one in **every tenant that consents**.

This is the source of *"I registered the app, why isn't it in Enterprise Applications?"* — and of
the more dangerous confusion, where an engineer grants a permission in the home tenant and expects
it to apply everywhere. **Consent is per-tenant because the service principal is per-tenant.**

⚠ **Registering in the portal creates both objects. Registering via Graph creates the SP as a
separate step** — script a registration and forget that, and you have an app that cannot be assigned
anything.

---

## 3. ⭐ Should this be an app registration at all?

Microsoft's own test ✅ — use a **managed identity** instead if **all** of these are true:

```
✅ The service runs in the Azure cloud
✅ The app doesn't need to sign in users
✅ The app doesn't need to act as the resource in a token flow (isn't a web API)
✅ The app doesn't need to operate in multiple tenants
```

> ⭐ **And note the widely-missed corollary: managed identities can access resources *outside*
> Azure, including Microsoft Graph.** "We need an app registration because it calls Graph" is a
> false premise. See [`../managed-identities/`](../managed-identities/).

---

## 4. ⭐ Credentials — and Microsoft's own ranking

✅ Verbatim from the guidance: **"Don't use password credentials, also known as *secrets*."**

| Preference | Credential | Why |
|---:|---|---|
| **1** | **Managed identity** | No credential to manage at all |
| **2** | **Federated credential** | ⭐ No secret exists — see [`../workload-identity-federation/`](../workload-identity-federation/) |
| **3** | **Certificate from a trusted CA**, stored in Key Vault | Private key can live in an HSM |
| **4** | Self-signed certificate | Still preferred over a secret |
| **✗** | **Client secret** | "Often mismanaged and easily compromised" |

**Two hard rules that catch people:**

- ✅ **A public/installed client (mobile, desktop) must have *no* credentials on the app object.**
  A credential there is extractable by anyone with the binary.
- ⚠ Federated credentials are only as trustworthy as the platform they trust. **Configure them only
  from platforms you trust** — an app is only as secure as the identity platform it federates to.

### The control almost nobody knows exists

⭐ **Application management policies** (`applicationAuthenticationMethodPolicy`) ✅ let you **limit
secret lifetimes or block secrets entirely, tenant-wide**. There is also a
`nonDefaultUriAddition` restriction that enforces default-only identifier URIs.

> **This turns "please use certificates" from a guideline into an enforced control.** Most
> organisations argue about secret hygiene in code review; the policy makes the argument unnecessary.

---

## 5. ⭐ App instance property lock — the defence against SP credential injection

This is the one worth understanding properly, because it closes a real attack.

**The problem** ✅: when an application has a service principal in a tenant, **a tenant admin can
customise that service principal** — in the home tenant *or* a foreign one. That includes
**adding credentials to the SP**, even though credentials should be owned by the app developer.

```
Attacker (or careless admin) with rights in ANY tenant where the app has an SP
        │
        └─► adds a credential to the SERVICE PRINCIPAL
                 │
                 └─► authenticates as the application, inheriting its permissions
```

That is exactly the technique the hunt in
[`../../50-security-operations/threat-hunting/`](../../50-security-operations/threat-hunting/) §6
looks for — and **app instance property lock is the control that prevents it.**

✅ **Guidance: configure app instance lock, and lock *every* sensitive property.** Critical for
multi-tenant applications, and recommended for all.

---

## 6. Worked example — auditing the app estate

**Secret expiry is a scheduled outage nobody schedules.** It is the most common cause of
"it worked yesterday":

```powershell
Connect-MgGraph -Scopes 'Application.Read.All'

Get-MgApplication -All | ForEach-Object {
  $app = $_
  $app.PasswordCredentials | ForEach-Object {
    [pscustomobject]@{
      App      = $app.DisplayName
      Type     = 'Secret'
      Expires  = $_.EndDateTime
      DaysLeft = [int]($_.EndDateTime - (Get-Date)).TotalDays
    }
  }
  $app.KeyCredentials | ForEach-Object {
    [pscustomobject]@{ App=$app.DisplayName; Type='Certificate'; Expires=$_.EndDateTime
                       DaysLeft=[int]($_.EndDateTime - (Get-Date)).TotalDays }
  }
} | Where-Object DaysLeft -lt 60 | Sort-Object DaysLeft
```

```
App                      Type         Expires              DaysLeft
-----------------------  -----------  -------------------  --------
Payroll Integration      Secret       2026-08-19 09:00:00         8
Contoso Analytics Add-in Secret       2026-09-02 12:00:00        22
HR Sync Service          Certificate  2026-10-04 00:00:00        54
```

**Now find the apps that should not have secrets at all:**

```powershell
Get-MgApplication -All |
  Where-Object { $_.PasswordCredentials.Count -gt 0 } |
  Select-Object DisplayName, Id,
    @{n='Secrets';e={$_.PasswordCredentials.Count}},
    @{n='Certs';e={$_.KeyCredentials.Count}},
    @{n='Federated';e={ (Get-MgApplicationFederatedIdentityCredential -ApplicationId $_.Id -ErrorAction SilentlyContinue).Count }},
    @{n='IsPublicClient';e={$_.IsFallbackPublicClient}} |
  Sort-Object Secrets -Descending
```

⭐ **Two findings to look for:** an app with `IsPublicClient = True` **and** secrets (a credential
anyone can extract from the binary), and any app carrying **many secrets** — ✅ "don't have many
credentials on one application."

**Ownership is an access review problem, not an app problem:**

```powershell
Get-MgApplication -All | ForEach-Object {
  $owners = Get-MgApplicationOwner -ApplicationId $_.Id -ErrorAction SilentlyContinue
  [pscustomobject]@{ App=$_.DisplayName; OwnerCount=$owners.Count
                     Owners=($owners.AdditionalProperties.userPrincipalName -join ',') }
} | Where-Object OwnerCount -eq 0
```

⭐ **Apps with zero owners are the finding.** Nobody can authorise disabling them during an incident,
and nobody will ever review their permissions.

---

## 7. Redirect URIs, identifier URIs and token version

**Redirect URIs** ✅:

- **Maintain ownership of every URI** — ⭐ *"a lapse in the ownership of one of the redirect URIs can
  lead to application compromise."* An expired domain in a redirect list is an account-takeover path.
- Monitor the DNS records
- **No wildcards**, no `http`, no `urn` schemes
- Keep the list **small** and trim unused entries

**Implicit flow** — use **authorisation code flow** instead. Implicit exists for legacy browsers and
leaks tokens through the URL fragment.

**Application ID URI** ✅: must be **unique in the tenant**, must **not end with `/`**, no wildcards,
use a verified domain. For apps issued **v1.0** tokens, use **only** the defaults —
`api://<appId>` or `api://<tenantId>/<appId>`.

**Access token version** — check `requestedAccessTokenVersion` in the manifest: `null` or `1` means
v1.0 tokens, `2` means v2.0. ⚠ **After moving to v2.0, the app's audience validation must accept
*only* its `appId`.** Getting that wrong is a token-confusion vulnerability, not a config nit.

---

## 8. What breaks

**Deleting the app object.** ⭐ It deletes the home-tenant SP, and **restoring the app does not
restore the SP** — every role assignment and consent is gone. Prefer **deactivation** during an
incident: it stops token issuance while preserving both objects as evidence.

**Secret expiry.** §6. Run the report on a timer.

**`Users can register applications` defaults to Yes.** Any user can create an app registration —
the substrate for the illicit consent grant attack. See
[`../../50-security-operations/defender-for-cloud-apps/`](../../50-security-operations/defender-for-cloud-apps/) §4.

**No app instance lock on a multi-tenant app.** §5.

**Credentials on a public client.** Extractable from the binary.

**Wildcard or lapsed-domain redirect URIs.** Account takeover.

**Group claims instead of app roles.** Groups hit the overage limit (~150–200) and the claim
silently vanishes; **app roles do not**.

**Creating the app via Graph and forgetting the SP.**

**Apps with no owners.** §6.

---

## 9. Customer discovery questions

1. How many app registrations carry **client secrets**? Are **application management policies**
   limiting or blocking them?
2. Are any **public clients** carrying credentials?
3. Is **app instance property lock** configured, especially on multi-tenant apps?
4. How many apps have **zero owners**?
5. Is `Users can register applications` still **Yes**?
6. Is there a **secret/certificate expiry report** running on a schedule?
7. Do any redirect URIs point at domains the organisation **no longer owns**?
8. Are group claims used where **app roles** would be safer?
9. Could any of these apps be **managed identities** instead? *(§3 — four-part test.)*
10. Are app permissions reviewed periodically, and by whom?

---

## 10. Remember it

**Hook — "Blueprint and instance."** One **application object** in the home tenant; one **service
principal per tenant**. Consent is per-tenant because the SP is per-tenant.

**Analogy — a franchise agreement.** The **app registration** is the franchise contract held at head
office: brand, menu, rules. The **service principal** is the individual restaurant in each town —
and each town's council grants *its own* licences to *its* restaurant. Head office cannot grant a
licence in a town it does not operate in, which is why consent does not travel. **App instance
property lock is head office forbidding the local manager from re-cutting the keys** — which is
otherwise exactly what a hostile local admin does.

**The one thing:** ⭐ **Microsoft's own guidance is "don't use client secrets."** The order is
managed identity → federated credential → certificate from a trusted CA in Key Vault → self-signed
cert → *never* a secret. And **application management policies can enforce that tenant-wide** rather
than leaving it to code review.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 11. Self-test

1. Application object versus service principal — how many of each, and where do they live?
2. When should something be a managed identity instead of an app registration?
3. Can a managed identity call Microsoft Graph?
4. Rank the credential types from best to worst.
5. What can a tenant admin do to a service principal, and which feature prevents it?
6. Why must a public client have no credentials?
7. What happens if you delete an app registration and restore it?
8. Why is a lapsed redirect-URI domain an application compromise?
9. What must an app's audience validation accept after moving to v2.0 tokens?
10. Why do app roles beat group claims at scale?

<details>
<summary>Answers</summary>

1. **One application object** in the home tenant; **one service principal per tenant** that consents.
2. When it **runs in Azure**, **doesn't sign in users**, **isn't a web API**, and **isn't
   multi-tenant** — all four.
3. **Yes** — managed identities can reach resources outside Azure, including Graph.
4. Managed identity → federated credential → certificate from a trusted CA (in Key Vault) →
   self-signed certificate → **client secret (avoid)**.
5. **Customise it, including adding credentials to it** — in the home or a foreign tenant.
   **App instance property lock** prevents it.
6. The credential ships with the binary and is **extractable by anyone who has it**.
7. The **service principal does not come back** — all role assignments and consents are lost.
   Prefer deactivation during an incident.
8. Whoever re-registers that domain can receive **authorisation codes/tokens** intended for the app.
9. **Only its own `appId`.**
10. Group claims hit an overage limit (~150–200) and the claim is **silently replaced**; app roles
    do not.

</details>

---

## 12. Evidence this topic needs

- **`lab/`** — register an app; find its SP; confirm the same `appId` and different object IDs.
  Create one via **Graph without the SP** and observe exactly what breaks.
- **`break-fix/`** ⭐ — delete an app registration, restore it, and **prove the SP did not come
  back**. Then repeat with *disable* instead and show both objects survive.
- **`security/`** — the §6 expiry and credential reports; apps with zero owners; public clients with
  secrets; app instance lock status on multi-tenant apps; application management policy configured.
- **`operations/`** — secret-expiry report scheduled with an owner; redirect URI domain ownership
  check.
- **`architecture-decisions/`** — ADR: credential standard (certificates or federation only), and
  the four-part test for choosing managed identity over app registration.
- **`customer-use-cases/`** — §9 answered against a real tenant.
