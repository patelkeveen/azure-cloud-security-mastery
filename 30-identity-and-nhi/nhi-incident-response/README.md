# Non-Human Identity Incident Response

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> Ties together [`../service-principals/`](../service-principals/),
> [`../app-registrations/`](../app-registrations/), [`../managed-identities/`](../managed-identities/)
> and the federation topics. Pairs with
> [`../../50-security-operations/incident-response/`](../../50-security-operations/incident-response/).

---

## 1. What it is

Responding to the compromise of a **service principal, managed identity, app registration or agent
identity** — rather than a human account.

**Non-human identities outnumber humans in most tenants**, almost none have a recorded owner, and
they are increasingly the breach path *because* the human playbook does not touch them.

---

## 2. ⭐ Why the human playbook does not transfer

Almost every step of standard account-compromise response is **wrong** here:

| Human response | Why it fails for an NHI |
|---|---|
| Reset the password | ⭐ **There is no password** — a secret, a certificate, a federated trust, or nothing at all |
| Force MFA re-registration | Non-human identities do not do MFA |
| Disable the account | ⭐ **Disabling a service principal breaks production**, often immediately and widely |
| Contact the user | There may be **no owner recorded** |
| Revoke sessions | App-only tokens are stateless; revocation semantics differ |

**The blast radius is inverted, too.** A compromised user has that user's rights. A compromised
service principal holding **application permissions** has **no intersection with any user's rights** —
`Mail.Read` as an application permission reads **every** mailbox. See
[`../service-principals/`](../service-principals/) §3.

> ⭐ **This is the "two identities" pattern at its sharpest.** Everything you did to the user account
> — password, MFA, sessions — touched nothing here. The workload identity is a separate principal
> with its own credential, its own permissions and its own logs.

---

## 3. The response sequence

```
1. SCOPE       what permissions? delegated or APPLICATION? what Azure RBAC, at what scope?
2. ASSESS      blast radius BEFORE acting — step 3 causes an outage
3. CONTAIN     least → most disruptive (§4)
4. HUNT        AADServicePrincipalSignInLogs / AADManagedIdentitySignInLogs — NOT SigninLogs
5. ERADICATE   added credentials, added owners, granted permissions, federated credentials
6. RECOVER     with a BETTER credential — managed identity or federation, never a new secret
```

⭐ **Steps 1 and 2 come before 3 for a reason specific to NHI:** disabling a service principal is a
production outage with no user to warn. In human IR you contain fast; here, **containment
disruption is often larger than the compromise**, and that trade-off is a business decision.

---

## 4. Containment options, in increasing disruption

| Action | Disruption | Use when |
|---|---|---|
| **Revoke the specific consent grant** | Low, targeted | ⭐ Illicit consent — often sufficient on its own |
| **Remove the attacker's credential** | Low if you remove only theirs | A credential was added to a legitimate app |
| **Rotate all credentials** | Breaks anything using the old one | Credential provenance is unclear |
| **Disable the service principal** | ⭐ **Stops everything** | Active abuse, blast radius justifies an outage |
| **Delete** | Irreversible | Last resort — ⚠ restoring the app object does **not** restore the SP |

**Remove only the attacker's credential — record it as evidence first:**

```powershell
Connect-MgGraph -Scopes 'Application.ReadWrite.All'

# 1. Enumerate and CAPTURE before deleting
Get-MgApplication -Filter "appId eq '<appId>'" |
  Select-Object -ExpandProperty PasswordCredentials |
  Select-Object KeyId, DisplayName, StartDateTime, EndDateTime |
  Export-Csv evidence-credentials.csv -NoTypeInformation
```

```
KeyId                                DisplayName        StartDateTime        EndDateTime
------------------------------------ -----------------  -------------------  -------------------
7f3a1c22-...                         prod-deploy        2024-03-01 09:00:00  2026-03-01 09:00:00
c8e91b04-...                         (none)             2026-08-07 02:14:33  2028-08-06 02:14:33  <-- ⚠
```

⭐ **Read that output.** A credential with **no display name**, created at **02:14**, with a
**two-year expiry** — that is not how a deployment pipeline provisions a secret. The `StartDateTime`
is your earliest confirmed compromise time.

```powershell
# 2. Remove only that one
Remove-MgApplicationPassword -ApplicationId <objectId> -KeyId 'c8e91b04-...'

# 3. Or stop token issuance entirely, preserving both objects as evidence
Update-MgServicePrincipal -ServicePrincipalId <spId> -AccountEnabled:$false
```

⚠ **Do not forget federated credentials.** An attacker who added one has a credential-free backdoor
that no secret rotation touches:

```powershell
Get-MgApplicationFederatedIdentityCredential -ApplicationId <objectId> |
  Select-Object Name, Issuer, Subject, Audiences
```

---

## 5. ⭐ Managed identities are a different problem entirely

**You cannot rotate a managed identity's credential — Azure owns it.** So the containment options
are structurally different:

```
Managed identity compromised  ⇒  the COMPUTE was compromised
                                  (the credential never leaves the platform)
```

| Option | Effect |
|---|---|
| **Remove role assignments** | ⭐ Fastest meaningful containment — the identity survives, its access does not |
| **Detach the identity from the resource** | User-assigned only |
| **Rebuild the compute** | Addresses the actual compromise |
| Delete the identity | System-assigned dies with the resource; user-assigned must be deleted explicitly |

> ⭐ **A managed identity compromise is really a compute compromise**, because the only way to use it
> is to run code on the resource — or to reach IMDS through **SSRF**. That reframes the
> investigation: *what ran on that VM?*, not *who has the secret?* See
> [`../managed-identities/`](../managed-identities/) §4.

---

## 6. Attacker techniques to recognise

- **Illicit consent grant** — a malicious app requests delegated permissions; the user genuinely
  authenticates, so **MFA passes and Conditional Access passes**. No password was stolen, and **a
  password reset does not remediate it.** Revoke the grant. See
  [`../../50-security-operations/defender-for-cloud-apps/`](../../50-security-operations/defender-for-cloud-apps/) §4.
- **Credential addition to an existing app** — a *second* secret or certificate on a legitimate,
  trusted app. Quiet, durable, invisible unless you watch `AuditLogs`. ⭐ **Prevented by
  [app instance property lock](../app-registrations/)** §5.
- **Owner addition** — durable control, and it survives credential rotation.
- **Federated credential addition** — a backdoor with no secret to find.
- ⭐ **Domain federation** — `Add domain` / `Set domain authentication` lets an attacker mint tokens
  for **any user in the tenant**. The crown-jewel event.

---

## 7. Detection — build these before you need them

```kusto
// Credential or federated credential added to an application
AuditLogs
| where TimeGenerated > ago(30d)
| where OperationName has_any ("Update application", "Add service principal credentials",
        "Update application - Certificates and secrets management")
| mv-expand TargetResources
| extend App   = tostring(TargetResources.displayName),
         Actor = coalesce(tostring(InitiatedBy.user.userPrincipalName),
                          tostring(InitiatedBy.app.displayName))
| where tostring(TargetResources.modifiedProperties) has_any ("KeyDescription","PasswordCredentials","KeyCredentials")
| project TimeGenerated, OperationName, App, Actor
```

```kusto
// Service principal signing in from more than one country
AADServicePrincipalSignInLogs
| where TimeGenerated > ago(30d) and ResultType == 0
| summarize Countries = make_set(LocationDetails.countryOrRegion), IPs = dcount(IPAddress)
        by ServicePrincipalName, AppId
| where array_length(Countries) > 1
| sort by IPs desc
```

⭐ **`SigninLogs` contains none of this.** An investigation run against it concludes "no activity"
and closes. See [`../../50-security-operations/threat-hunting/`](../../50-security-operations/threat-hunting/) §6.

⚠ Risky workload identity detections need **Workload Identities Premium** — a separate licence.

---

## 8. The prerequisite nobody has: the NHI register

You cannot respond to a compromise of an identity you cannot describe.

| Field | Why it is needed at 2am |
|---|---|
| Identity, type, appId | Which object are we talking about |
| ⭐ **Owner** | **Who authorises the outage** |
| Purpose | What breaks if we disable it |
| Permissions + Azure RBAC scope | Blast radius |
| Credential type and expiry | What to rotate, and whether rotation is even possible |
| Last used | Whether anyone would notice |
| Rotation + revocation procedure | How, without a two-hour discussion |

> ⭐ **The owner field is the one that decides how fast the incident moves.** Everything else can be
> queried live; ownership cannot. **Building this register is a deliverable customers pay for,
> because they cannot produce it themselves.**

---

## 9. What breaks

**Disabling first, scoping second.** Outage, and you still do not know the blast radius.

**Querying `SigninLogs`** and concluding there was no activity.

**Rotating the credential without finding the persistence.** The attacker added another — or an
owner, or a federated credential.

**Forgetting federated credentials.** §4 — no secret to rotate, so rotation misses it entirely.

**Trying to rotate a managed identity's credential.** §5 — Azure owns it; remove role assignments.

**No owner recorded**, so nobody can authorise the disruptive action.

**Deleting the app registration.** Restoring it does not restore the SP.

**Recovering with a new secret** instead of removing the credential class — managed identity or
federation.

**Ignoring `Add domain` / `Set domain authentication`** in the audit sweep.

---

## 10. Customer discovery questions

1. Is there an **NHI register**? Does it have an **owner** per identity?
2. Are **`AADServicePrincipalSignInLogs`** and **`AADManagedIdentitySignInLogs`** collected?
3. Is there a detection for **credential added to an application**?
4. Does the IR runbook have an **NHI path**, or only the human one?
5. Who can authorise disabling a production service principal, out of hours?
6. Is **app instance property lock** configured on multi-tenant apps?
7. Are there service principals with **application permissions** and **no owner**?
8. Has anyone tested revoking a consent grant?
9. Is **Workload Identities Premium** licensed for risk detection?

---

## 11. Remember it

**Hook — "No password, no MFA, no user to ring."** And the order: **scope → assess → contain**,
because containment here *is* the outage.

**Analogy — a compromised master key versus a compromised employee.** With an employee you change
their password and ring them. With a **service principal you cannot ring anyone, there is no
password, and the key opens every door with no watchman checking whose hand is holding it.** Worse:
**cutting the key stops the night cleaners, the deliveries and the alarm system too** — which is why
you find out what the key opens *before* you cut it.

**The one thing:** ⭐ **rotating the credential is not eradication.** The attacker may hold a second
secret, an added *owner*, a *federated credential* with nothing to rotate, or a **federated domain**
that mints tokens for the entire tenant. **Enumerate all four before you declare it closed.**

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 12. Self-test

1. Name four human-IR steps that do nothing for a compromised service principal.
2. Why does scoping come before containment here, when human IR contains fast?
3. Least disruptive containment for an illicit consent grant?
4. In a credential list, what marks an attacker-added secret?
5. Why can't you rotate a managed identity's credential, and what do you do instead?
6. A managed identity is compromised. What was *actually* compromised?
7. Which two tables hold workload identity sign-ins?
8. Four persistence mechanisms that survive credential rotation?
9. Which audit operation lets an attacker mint tokens for any user in the tenant?
10. Which NHI register field most determines incident speed?

<details>
<summary>Answers</summary>

1. **Password reset, MFA re-registration, contacting the user, session revocation** — none apply.
2. **Containment is a production outage** with no user to warn, and the disruption may exceed the
   compromise. That trade-off is a business decision requiring blast radius first.
3. **Revoke the specific consent grant** — targeted and often sufficient.
4. **No display name, an unusual creation time, and an unusually long expiry.** `StartDateTime` is
   your earliest confirmed compromise time.
5. **Azure owns it.** Remove **role assignments**, detach the identity, or rebuild the compute.
6. **The compute.** The credential never leaves the platform — so either code ran on the resource,
   or **SSRF** reached IMDS.
7. **`AADServicePrincipalSignInLogs`** and **`AADManagedIdentitySignInLogs`**.
8. A **second credential**, an added **owner**, a **federated identity credential**, and a
   **federated domain**.
9. **`Add domain` / `Set domain authentication`.**
10. ⭐ **Owner** — everything else can be queried live; ownership cannot.

</details>

---

## 13. Evidence this topic needs

- **`lab/`** — build the NHI register for your tenant; add a second credential to a test app and
  **detect it from `AuditLogs`**. The register half is runnable **today** with Graph read access.
- **`break-fix/`** ⭐ — consent to a test app requesting `Mail.Read`, prove it still reads mail
  **after a password reset**, then revoke the grant and prove access stops. **The single clearest
  demonstration that the human playbook does not transfer.**
- **`security/`** — application permissions ranked by blast radius; SPs with permissions and no
  owner; the §7 detections deployed; app instance property lock configured.
- **`operations/`** — the NHI IR runbook with the §4 containment decision tree and named
  out-of-hours authority.
- **`architecture-decisions/`** — ADR: credential standard for workload identities, and the
  ownership requirement before any SP reaches production.
- **`customer-use-cases/`** — the NHI register delivered as an engagement artifact.
