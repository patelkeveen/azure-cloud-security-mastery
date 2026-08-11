# Passwordless and Passkeys

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Method list verified against Microsoft Learn **2026-08-10**.
> Builds on [`../authentication-methods/`](../authentication-methods/).

---

## 1. What it is

Authenticating with **something you have plus something you are or know locally** — a device-bound
key unlocked by biometric or PIN — **with no shared secret transmitted anywhere**.

⭐ **"Passwordless" and "phishing-resistant" are not the same thing.** Microsoft Authenticator
passwordless sign-in removes the password but is **not** phishing-resistant. Getting this pair right
is the single most common precision failure in this topic.

---

## 2. Why passwords fail structurally

Not "users choose bad passwords" — that is a symptom:

```
A password is a SHARED SECRET
   ├─ the user knows it            → can be phished
   ├─ the server stores a derivative → can be breached and cracked offline
   ├─ it is REPLAYABLE             → stolen once, used anywhere
   └─ it is REUSED across sites    → one breach compromises many
```

**A passkey inverts every line.** The private key never leaves the authenticator, nothing replayable
crosses the wire, and the credential is **bound to the origin** so it cannot be presented to a
lookalike domain.

> ⭐ **That origin binding is what "phishing-resistant" means**, and it is why a real-time
> adversary-in-the-middle proxy — which defeats OTP and push — cannot defeat a passkey. The browser
> simply will not release it to `contoso.com.evil.net`.

---

## 3. The methods, precisely ✅

**Phishing-resistant (six):**

```
Windows Hello for Business
Platform Credential for macOS
Synced passkeys (FIDO2)
FIDO2 security keys
Passkeys in Microsoft Authenticator
Certificate-based authentication (CBA)
```

**Passwordless but NOT phishing-resistant:**

- **Microsoft Authenticator passwordless sign-in** (number-matching push) — no password, but a
  proxied user approves a genuine prompt
- SMS sign-in — passwordless and weak on both counts

⭐ **Device-bound versus synced passkeys** is the decision that matters in design:

| | Device-bound | Synced |
|---|---|---|
| Key lives | Only on that authenticator | Synced via the platform's passkey provider |
| Lost device | Credential is gone — re-enrol | Recoverable from the sync account |
| Assurance | ⭐ Higher — one key, one device | Lower — key exists in more places |
| Use for | Admins, high-assurance roles | Broad workforce rollout |

**Both are phishing-resistant.** The trade-off is *recoverability versus assurance*, not security
against phishing — and stating it that way is what makes the design conversation productive.

---

## 4. ⭐ The bootstrap problem, and the thing that solves it

**A passwordless user has no credential to enrol a credential with.** That circularity is why
passwordless projects stall.

**Temporary Access Pass (TAP)** ✅ is the answer — a time-limited passcode usable as **primary or
secondary** authentication:

```
New joiner, no credential           → TAP → registers a passkey → TAP expires
Lost the only security key          → TAP → registers a replacement
Migrating a user off SMS            → TAP → registers Authenticator/passkey
```

> ⭐ **Without TAP, every passwordless enrolment falls back to a password or a helpdesk call** —
> and the helpdesk call is precisely the attack path that
> [`../authentication-methods/`](../authentication-methods/) §5 exists to close.

---

## 5. Worked example — sequencing a rollout that does not stall

```
1. ENABLE broadly            passkeys + Authenticator in the methods policy
2. ENABLE TAP                or enrolment has no bootstrap
3. MEASURE                   who has what, today (below)
4. CAMPAIGN                  registration campaign nudges users off SMS
5. DEMAND narrowly           phishing-resistant STRENGTH for admins via CA
6. WIDEN                     resource by resource
7. RETIRE SMS                only once §3 shows nobody depends on it
```

```powershell
Connect-MgGraph -Scopes 'AuditLog.Read.All','UserAuthenticationMethod.Read.All'

Get-MgReportAuthenticationMethodUserRegistrationDetail -All |
  Select-Object UserPrincipalName, IsAdmin, IsMfaRegistered, IsPasswordlessCapable,
                @{n='Methods';e={ $_.MethodsRegistered -join ',' }} |
  Group-Object IsPasswordlessCapable, IsAdmin |
  Select-Object Name, Count
```

```
Name           Count
-------------  -----
False, False     603
True, False      137
False, True       11    <-- ⚠ ADMINS who are NOT passwordless-capable
True, True         6
```

⭐ **Row three is the report.** Eleven administrators without a phishing-resistant option registered
— they are the highest-value phishing targets in the tenant, and they are also the smallest and
fastest population to fix. **Start there, not with the 603.**

**Then prove it in the token** — the ground truth, not the sign-in log summary:

```kusto
SigninLogs
| where TimeGenerated > ago(30d) and ResultType == 0
| mv-expand AuthDetail = AuthenticationDetails
| extend Method = tostring(AuthDetail.authenticationMethod)
| summarize Signins = count(), Users = dcount(UserPrincipalName) by Method
| sort by Signins desc
```

```
Method                          Signins  Users
------------------------------  -------  -----
Password                          41022    598
Microsoft Authenticator push      12877    412
Windows Hello for Business         6431    143
FIDO2 security key                  892     28
```

⭐ **Adoption is measured in sign-ins, not registrations.** A user who registered a passkey and still
signs in with a password every day has not adopted anything — and only this query shows it.

---

## 6. What breaks

**Conflating passwordless with phishing-resistant.** §1 — Authenticator push is the counterexample.

**No TAP enabled.** §4 — enrolment has no bootstrap and the project stalls.

**Retiring SMS before measuring dependence.** Lockouts.

**Measuring registration instead of usage.** §5.

**Synced passkeys for high-assurance roles** without acknowledging the key exists in more places.

**Expecting Windows Hello to satisfy MFA unconditionally** — it needs the user enabled for passkey
with one registered.

**Rolling out to everyone before admins.** The smallest, highest-value population is left exposed
longest.

**Ignoring the SMS/voice retirement dates.** ⚠ Reported as passkeys-by-default from
**1 September 2026** and Microsoft-provided SMS/voice retiring **1 February 2027** — verify at
source before quoting.

---

## 7. Customer discovery questions

1. How many **administrators** are not passwordless-capable? *(§5 — start there.)*
2. Is **TAP** enabled, and how are new joiners enrolled today?
3. Is adoption measured by **registration or actual sign-ins**?
4. Are **authentication strengths** enforced anywhere, or just "require MFA"?
5. Device-bound or synced passkeys — was that a decision?
6. What is the plan for the **SMS/voice retirement dates**?
7. How is a lost security key recovered — TAP, or helpdesk?
8. Are registration campaigns running?

---

## 8. Remember it

**Hook — "Passwordless ≠ phishing-resistant."** Six methods qualify; **Authenticator push is not
one of them.**

**Analogy — a house key versus telling someone the combination.** A **password is a combination**:
saying it aloud to the wrong person costs you the house, and you cannot tell it was overheard. A
**passkey is a key cut for one lock** — it physically will not turn in the lookalike door next
street. **Push notification is a doorbell**: genuinely yours, and you will happily buzz in whoever
is standing there claiming to be you.

**The one thing:** ⭐ **TAP is what makes passwordless possible at all.** A user with no credential
cannot enrol a credential — and without TAP that bootstrap falls back to a password or a helpdesk
call, which is the exact attack path passwordless exists to close.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Passwordless versus phishing-resistant — give a method that is one but not the other.
2. What does "bound to the origin" mean in practice?
3. Name the six phishing-resistant methods.
4. Device-bound versus synced passkeys — what is the actual trade-off?
5. What is the bootstrap problem, and what solves it?
6. Why is registration a misleading adoption metric?
7. Which population should a rollout start with, and why?
8. Under what condition does Windows Hello count as step-up MFA?
9. Why can't a real-time proxy defeat a passkey?

<details>
<summary>Answers</summary>

1. **Microsoft Authenticator passwordless push** — no password, but a proxied user approves a genuine
   prompt.
2. The browser **will not release the credential to a different origin** — `contoso.com.evil.net`
   gets nothing.
3. Windows Hello for Business, **Platform Credential for macOS**, synced passkeys, FIDO2 security
   keys, passkeys in Microsoft Authenticator, CBA.
4. **Recoverability versus assurance** — both are phishing-resistant. Synced keys exist in more places.
5. A passwordless user has **no credential to enrol a credential with**. **Temporary Access Pass.**
6. A user can register a passkey and still sign in with a password daily. **Measure sign-ins.**
7. **Administrators** — highest value to an attacker, smallest population, fastest to complete.
8. Only if the user is **enabled for passkey (FIDO2) and has one registered**.
9. The credential is **cryptographically bound to the origin**, so the proxy's domain cannot obtain it.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — register a passkey; sign in with it; **decode `amr`** and confirm the method
  ([`../oauth-oidc-saml-and-api-auth/`](../oauth-oidc-saml-and-api-auth/) §4). Issue a **TAP** and
  enrol a second user with no password.
- **`break-fix/`** ⭐ — remove a user's only method, lock them out, and **recover with TAP**.
- **`security/`** — the §5 admin gap report; phishing-resistant strength enforced for admins;
  SMS-only population identified.
- **`operations/`** — registration campaign configured; lost-key recovery procedure using TAP rather
  than the helpdesk.
- **`architecture-decisions/`** — ADR: device-bound for privileged roles, synced for the workforce,
  with the assurance/recoverability trade-off stated.
- **`customer-use-cases/`** — §7 answered; a passwordless rollout plan sequenced per §5.
