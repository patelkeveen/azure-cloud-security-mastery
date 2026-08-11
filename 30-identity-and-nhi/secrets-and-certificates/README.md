# Secrets and Certificates

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Guidance verified against Microsoft Learn **2026-08-10**.
> The credential layer under [`../app-registrations/`](../app-registrations/) and
> [`../key-vault/`](../key-vault/).

---

## 1. What it is

The credentials a workload uses to prove it is itself: a **client secret** (a bearer string), a
**certificate** (a key pair), or — better — **no credential at all**.

⭐ ✅ **Microsoft's guidance is unambiguous: *"Don't use password credentials, also known as
secrets."*** This topic exists mostly to explain why, and what to do instead.

---

## 2. The hierarchy, and why each step is better

| Rank | Credential | Why it beats the one below |
|---:|---|---|
| **1** | **Managed identity** | Nothing to manage, nothing to leak, Azure rotates it |
| **2** | **Federated credential** | No credential exists; trust replaces storage |
| **3** | **Certificate from a trusted CA**, in Key Vault | The **private key can be non-exportable** in an HSM |
| **4** | Self-signed certificate | Still asymmetric — the private key never transits |
| **✗** | **Client secret** | A **symmetric bearer string**. Whoever reads it, is you. |

> ⭐ **The structural difference is symmetry.** A secret is the *same value* at both ends — so
> reading it anywhere (a log, a config file, a screen share, a git history) grants full use. A
> certificate proves possession of a private key **without transmitting it**, so intercepting the
> handshake yields nothing reusable.

**That single distinction is the whole argument**, and it is a better answer than "certificates are
more secure."

---

## 3. Why secrets leak — the paths, not the theory

```
git history          committed once, rewritten never — the repo remembers
CI/CD logs           echoed by a debug flag nobody removed
config files         copied to a developer laptop "temporarily", in 2019
chat                 pasted once to unblock someone
screen share         visible for four seconds in a recording
support tickets      attached "so you can reproduce it"
```

⭐ **Every one of those is a *copy*.** A secret's defining weakness is that it can be copied
perfectly and silently, and no telemetry anywhere records that it happened. **You cannot detect the
theft; you can only detect the use** — which is why
[`../nhi-incident-response/`](../nhi-incident-response/) §7 watches sign-in geography rather than
credential access.

**Credential Scanner** and equivalent secret-scanning in the pipeline is the minimum control if
secrets exist at all.

---

## 4. Worked example — finding what will break, and when

**Expiry is a scheduled outage nobody scheduled.** This report should run on a timer:

```powershell
Connect-MgGraph -Scopes 'Application.Read.All'

$rows = Get-MgApplication -All | ForEach-Object {
  $app = $_
  $app.PasswordCredentials | ForEach-Object {
    [pscustomobject]@{ App=$app.DisplayName; AppId=$app.AppId; Type='Secret'
                       Name=$_.DisplayName; Expires=$_.EndDateTime
                       DaysLeft=[int]($_.EndDateTime - (Get-Date)).TotalDays } }
  $app.KeyCredentials | ForEach-Object {
    [pscustomobject]@{ App=$app.DisplayName; AppId=$app.AppId; Type='Certificate'
                       Name=$_.DisplayName; Expires=$_.EndDateTime
                       DaysLeft=[int]($_.EndDateTime - (Get-Date)).TotalDays } }
}
$rows | Where-Object DaysLeft -lt 90 | Sort-Object DaysLeft | Format-Table -AutoSize
```

```
App                    Type         Name          Expires              DaysLeft
---------------------  -----------  ------------  -------------------  --------
Payroll Integration    Secret       (none)        2026-08-19 09:00:00         8   <-- ⚠
HR Sync Service        Certificate  hr-sync-2024  2026-10-04 00:00:00        54
Legacy Reporting       Secret       old-key       2026-08-14 12:00:00         3   <-- ⚠⚠
```

**And the report that drives the strategy, not the fire-fighting:**

```powershell
$rows | Group-Object App | ForEach-Object {
  [pscustomobject]@{
    App     = $_.Name
    Secrets = ($_.Group | Where-Object Type -eq 'Secret').Count
    Certs   = ($_.Group | Where-Object Type -eq 'Certificate').Count
  }
} | Where-Object Secrets -gt 0 | Sort-Object Secrets -Descending
```

⭐ **An app with several secrets is a finding on its own** ✅ — *"don't have many credentials on one
application."* Multiple secrets usually means nobody knows which one is live, so nobody dares delete
any. **That is also exactly how an attacker-added credential hides in plain sight** —
[`../nhi-incident-response/`](../nhi-incident-response/) §4.

---

## 5. ⭐ Enforce it, don't request it

**Application management policies** ✅ (`applicationAuthenticationMethodPolicy`) can **limit secret
lifetimes or block secrets entirely**, tenant-wide or per application.

```
Tenant policy: passwordCredentials  → restrictForAppsCreatedAfterDateTime
                                    → maxLifetime  e.g. P90D
                                    → or DISALLOW entirely
```

> ⭐ **This converts a code-review argument into a control.** Most organisations debate secret
> hygiene in pull requests forever; the policy makes the debate unnecessary. Almost nobody knows it
> exists, which makes it a strong recommendation to bring to a customer.

**Certificate handling, when a certificate is genuinely required:**

- **Trusted CA over self-signed**, and a policy enforcing trusted issuers
- **Store in Key Vault**, ideally **HSM-backed and non-exportable**
- **Rotate before expiry with overlap** — upload the new certificate, cut over, *then* remove the old
- ⭐ **Never share a credential across applications.** One compromise becomes many, and revocation
  becomes a negotiation.

---

## 6. What breaks

**Secret expiry.** §4 — the most common cause of "it worked yesterday."

**Rotating without overlap.** Remove-then-add is an outage; add-then-cutover-then-remove is not.

**Many credentials on one app.** Nobody knows which is live; an attacker's addition is invisible.

**Credentials on a public client.** Extractable from the binary.

**Self-signed certificates in production** where a trusted CA was available.

**Exportable private keys.** The certificate's advantage over a secret evaporates.

**Sharing one credential across applications.** Blast radius, and revocation paralysis.

**Assuming rotation is eradication.** After a compromise, enumerate *all* credentials, owners and
federated credentials — §4 of
[`../nhi-incident-response/`](../nhi-incident-response/).

**No secret scanning in the pipeline.**

---

## 7. Customer discovery questions

1. How many app registrations hold **client secrets**? How many hold **more than one**?
2. Is an **application management policy** limiting or blocking secrets?
3. Is there an **expiry report** running on a schedule, with an owner?
4. Are certificates from a **trusted CA**, stored in Key Vault, **non-exportable**?
5. Is any credential **shared** between applications?
6. Is **secret scanning** enabled in the repositories and pipelines?
7. Which of these apps could be **managed identities** or use **federation** instead?
8. What is the rotation procedure — and does it overlap, or cut over hard?

---

## 8. Remember it

**Hook — "Managed identity → federation → certificate → never a secret."**

**Analogy — a password versus a signet ring.** A **secret is a password shouted across a room**: it
is the same value at both ends, so anyone who hears it can repeat it, and nobody can tell they did.
A **certificate is a signet ring** — you press it into wax to prove possession, and **the ring never
leaves your hand**. Watching the wax being stamped teaches an observer nothing they can reuse.

**The one thing:** ⭐ **you cannot detect secret theft, only secret use.** Copying is perfect,
silent, and leaves no trace anywhere — which is why the answer is to eliminate the credential class
rather than protect it better, and why **application management policies** (which can block secrets
outright) matter more than any amount of hygiene guidance.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. What is the structural difference between a secret and a certificate?
2. Rank the four credential options plus the one to avoid.
3. Why can't you detect secret theft?
4. What does an app with five client secrets tell you?
5. Which tenant control can block secrets entirely?
6. What is the correct rotation order, and why?
7. Why is a shared credential worse than two separate ones?
8. Why does an exportable private key undermine the point of a certificate?
9. After a credential compromise, why is rotation not eradication?

<details>
<summary>Answers</summary>

1. **Symmetry.** A secret is the same value at both ends and can be replayed by anyone who reads it.
   A certificate proves **possession of a private key without transmitting it**.
2. **Managed identity → federated credential → certificate from a trusted CA (in Key Vault) →
   self-signed certificate → client secret (avoid).**
3. Copying is **perfect and silent**, and nothing records it. You can only detect **use**.
4. **Nobody knows which one is live**, so none get deleted — and an attacker-added credential hides
   there unnoticed.
5. **Application management policies** — limit secret lifetime or disallow secrets entirely.
6. **Add the new credential, cut over, then remove the old.** Remove-first is an outage.
7. One compromise affects **every** application using it, and revocation becomes a negotiation
   between teams.
8. The private key can then be **copied**, which returns it to the properties of a secret.
9. The attacker may hold a **second credential, an owner entry, or a federated credential**.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — run the §4 expiry and multi-secret reports. ⭐ **Runnable today with Graph read access.**
- **`break-fix/`** — rotate a certificate **remove-first** and cause an outage in a lab; repeat with
  overlap and prove zero downtime.
- **`security/`** — application management policy configured; credential inventory by type;
  shared-credential audit; secret scanning enabled.
- **`operations/`** — expiry report scheduled with a named owner; documented rotation procedure with
  overlap.
- **`architecture-decisions/`** — ADR: certificates or federation only, with the policy that enforces it.
- **`customer-use-cases/`** — §7 answered against a real tenant.
