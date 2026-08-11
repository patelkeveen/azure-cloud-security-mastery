# Authentication Methods

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (updated 2026-06-15).
> **SC-300 Domain 2 core.** Depth in
> [Layer 3 §5](../conditional-access/LAYER-3-DOMAIN-2-AUTH-AND-ACCESS.md).

---

## 1. What it is

The ways a user can prove identity, plus the **Authentication methods policy** that governs which
populations may **register and use** each one. This is the modern control surface — it replaces the
legacy per-user MFA settings and the separate SSPR method configuration.

---

## 2. ⭐ The two-layer model — why passwordless rollouts stall without it

*What a user may register* and *what a resource demands* are different questions. Conflating them is
why organisations get stuck.

| Layer | Scope | Example |
|---|---|---|
| **Authentication methods policy** | Broad — who may register what | "Engineering may register passkeys and Authenticator" |
| **CA authentication strength** | Narrow — what this resource demands | "The admin portal requires phishing-resistant" |

> **Enable methods broadly; demand them narrowly, resource by resource.** That is the answer to
> "how do we go passwordless without breaking everyone at once", and it is a genuinely useful
> sentence in a design meeting.

---

## 3. The methods — what each can actually do ✅

Verified 2026-08-10. **The columns matter as much as the rows**: a method usable for MFA is not
necessarily usable for SSPR, and some cannot be a first factor at all.

| Method | Primary | Secondary (MFA) | SSPR / recovery |
|---|:---:|:---:|:---:|
| **Passkey (FIDO2)** — security key | ✅ | ✅ | ✗ |
| **Synced passkey** | ✅ | ✅ | ✗ |
| **Passkey in Microsoft Authenticator** | ✅ | ✅ | ✗ |
| **Windows Hello for Business** | ✅ | ✅ ¹ | ✗ |
| **Platform Credential for macOS** | ✅ | ✅ | ✗ |
| **Certificate-based authentication (CBA)** | ✅ | ✅ | ✗ |
| Microsoft Authenticator push | ✅ | ✅ | ✅ |
| Microsoft Authenticator passwordless | ✅ | ✗ | ✗ |
| Authenticator Lite | ✗ | ✅ | ✗ |
| **External MFA** (EAM) | ✗ | ✅ | ✗ |
| Software OATH tokens | ✗ | ✅ | ✅ |
| Hardware OATH tokens *(preview)* | ✗ | ✅ | ✅ |
| **Temporary Access Pass (TAP)** | ✅ | ✅ | ✗ |
| QR code | ✅ | ✗ | ✗ |
| SMS sign-in | ✅ | ✅ | ✅ |
| Voice call | ✗ | ✅ | ✅ |
| Email OTP | ✗ | ✅ ² | ✅ |
| **Password** | ✅ | ✗ | ✗ |
| **Verified ID** | ✗ | ✗ | ⭐ **Account recovery only** |

¹ Windows Hello for Business can act as a **step-up MFA credential** only if the user is enabled for
passkey (FIDO2) **and has a passkey registered** — a footnote that catches people out.
² Email OTP is SSPR for members; also configurable for **guest sign-in**.

> ⭐ **Password is primary-only.** It can never be a second factor. Obvious once stated, and it is
> exactly why "password + security questions" was never MFA.

---

## 4. Phishing-resistant — the precise list ✅

**Six methods**, and this is the list to memorise:

```
Windows Hello for Business
Platform Credential for macOS        ⭐ the one people forget exists
Synced passkeys (FIDO2)
FIDO2 security keys
Passkeys in Microsoft Authenticator
Certificate-based authentication (CBA)
```

**"Phishing-resistant" has a precise meaning:** the credential is **cryptographically bound to the
origin**, so an adversary-in-the-middle proxy cannot replay it. The browser will not release a
passkey to `contoso.com.evil.net` because the origin does not match.

**Push notifications are not phishing-resistant.** Number matching reduces MFA fatigue; it does not
stop a proxy relaying a legitimate prompt. The user approves something they genuinely requested — on
the attacker's behalf.

⚠ **Dated changes to verify at source before quoting** — reported on Microsoft domains but not
confirmed on the page above: **passkeys become the default experience from 1 September 2026**
(auto-enabled for users enabled for SMS or voice), and **Microsoft-provided SMS and voice delivery
retires 1 February 2027**, after which customer-managed providers are required. If accurate, any
MFA story resting on SMS has a dated migration, not a preference.

---

## 5. ⭐ High-assurance account recovery — the answer to the current attack ✅

**Help desk password reset is the dominant initial-access technique of recent years.** An attacker
calls the service desk, impersonates an employee convincingly, and gets credentials reset. No
malware, no exploit — social engineering against a human following a script.

Entra now supports **government-issued ID verification with biometric matching** for account
recovery ✅:

```
User loses ALL credentials
     │
     ▼
Identity verification provider (chosen via Microsoft Security Store)
     │  192 countries/regions · passports, driving licences
     ▼
Verified ID Face Check — live selfie matched to the ID document photo
     │  ⭐ ONLY the match result is shared, not the identity data
     ▼
Recovery proceeds — no helpdesk interaction, no social engineering surface
```

> **This removes the human from the loop at exactly the point the human is the vulnerability.** It
> is a genuinely current, genuinely differentiating thing to raise — most estates still recover
> accounts by asking someone their manager's name.

⭐ **And note the classification trap:** ✅ **Verified ID is *not* an authentication method.** It
cannot satisfy sign-in, MFA or SSPR. It provides cryptographic proof of identity for **account
recovery only**. Calling it an MFA method in an interview is a tell.

---

## 6. Worked example — auditing method coverage before changing anything

**Never disable a method without checking who depends on it.**

```powershell
Connect-MgGraph -Scopes 'UserAuthenticationMethod.Read.All','AuditLog.Read.All'

# What is registered across the tenant?
Get-MgReportAuthenticationMethodUserRegistrationDetail -All |
  Select-Object UserPrincipalName, IsMfaRegistered, IsPasswordlessCapable,
                @{n='Methods';e={ $_.MethodsRegistered -join ',' }} |
  Group-Object { $_.Methods } | Sort-Object Count -Descending |
  Select-Object Count, Name -First 10
```

```
Count  Name
-----  ----------------------------------------------
  412  microsoftAuthenticatorPush,mobilePhone
  188  mobilePhone                                     <-- ⚠ SMS ONLY
   96  microsoftAuthenticatorPush,passKeyDeviceBound
   41  passKeyDeviceBound
   12  (none)                                          <-- ⚠ NO MFA AT ALL
```

**Two rows are the report.** **188 users with SMS as their only method** cannot be migrated by
disabling SMS — they would be locked out. **12 users with nothing registered** are the gap that
every "we have MFA" claim quietly excludes.

**Find the users, not just the count:**

```powershell
Get-MgReportAuthenticationMethodUserRegistrationDetail -All |
  Where-Object { $_.MethodsRegistered -contains 'mobilePhone' -and $_.MethodsRegistered.Count -eq 1 } |
  Select-Object UserPrincipalName, IsAdmin | Export-Csv sms-only.csv -NoTypeInformation
```

⭐ **Sort that output by `IsAdmin`.** An administrator whose only factor is SMS is the finding you
lead with.

**Prove what actually happened at sign-in** — the `amr` claim is ground truth:

```kusto
SigninLogs
| where TimeGenerated > ago(7d) and ResultType == 0
| mv-expand AuthDetail = AuthenticationDetails
| extend Method = tostring(AuthDetail.authenticationMethod)
| summarize Signins = count(), Users = dcount(UserPrincipalName) by Method
| sort by Signins desc
```

---

## 7. The rollout sequence that works

```
1. Enable Authenticator and passkeys broadly; leave SMS enabled but deprioritised
2. Run a REGISTRATION CAMPAIGN nudging SMS users onto Authenticator/passkeys
3. Demand phishing-resistant strength for ADMINS via Conditional Access
4. Widen the strength requirement resource by resource
5. ONLY THEN remove SMS as a permitted method — after §6 shows nobody depends on it
```

**Temporary Access Pass is what makes step 1 possible.** A TAP is a time-limited passcode that can
act as primary *or* secondary authentication, so it covers both **onboarding a passwordless user**
(who has no credential yet) and **recovering someone who lost their only factor**. Without TAP,
passwordless has a chicken-and-egg problem at enrolment.

---

## 8. What breaks

**Disabling a method someone depends on.** §6 — check coverage first; TAP is the rescue.

**Assuming push is phishing-resistant.** It is not. Number matching ≠ origin binding.

**Calling Verified ID an authentication method.** §5.

**Expecting Windows Hello to satisfy MFA unconditionally.** ¹ It needs the user enabled for passkey
with one registered.

**Legacy MFA and SSPR settings coexisting with the new policy** during migration, disagreeing with
each other. Migrate deliberately and verify per method.

**Password as a second factor.** Impossible — primary only.

**Authentication strength and sign-in frequency satisfied at different moments.** A passkey sign-in
yesterday can satisfy today's strength while a Hello unlock satisfies frequency; users are not
re-prompted when you expect.

**Signing in with a password when a strength requires Hello** — the user is not prompted to
step up; they must restart and choose the method.

**Ignoring the SMS/voice dates.** §4 — an SMS-based MFA estate has a migration, not an opinion.

---

## 9. Customer discovery questions

1. What is **registration coverage**? How many users have **SMS as their only method**? *(§6.)*
2. How many users have **no method registered at all**?
3. Are any **administrators** on SMS-only or push-only?
4. Are **authentication strengths** used, or just "require MFA"?
5. Has the **legacy MFA/SSPR** configuration been fully migrated to the methods policy?
6. Is **TAP** enabled? How are passwordless users onboarded today?
7. What is the **account recovery** process — and does it depend on a helpdesk conversation? *(§5.)*
8. Is there a plan for the **SMS/voice retirement dates**?
9. Are **registration campaigns** in use, or is adoption left to chance?

---

## 10. Remember it

**Hook — "Enable broadly, demand narrowly."** Methods policy is who *may* register; authentication
strength is what a resource *requires*.

**Analogy — a hotel with many door types.** The **methods policy** decides which keys reception is
allowed to issue — cards, fobs, phone keys. **Authentication strength** decides which doors accept
which key: the gym takes anything, the safe deposit room takes only the biometric. **Phishing
resistance is the key that physically cannot be copied by someone reading it out over the phone** —
which is precisely what a push notification is.

**The one thing:** ⭐ **"phishing-resistant" means cryptographically bound to the origin.** A passkey
will not release to `contoso.com.evil.net`. A push notification will happily be approved by a user
being proxied in real time — the user genuinely requested it, just on the attacker's behalf. Six
methods qualify; **push is not one of them.**

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 11. Self-test

1. Difference between the authentication methods policy and authentication strength?
2. Name the six phishing-resistant methods.
3. What does "phishing-resistant" mean precisely?
4. Can a password be a second factor?
5. Is Verified ID an authentication method? What is it for?
6. Under what condition does Windows Hello count as step-up MFA?
7. What must you check before disabling SMS, and what rescues a user who loses their only factor?
8. Which two rows of a registration-coverage report are the actual findings?
9. What attack does high-assurance account recovery address?
10. Which claim proves how a user actually authenticated?

<details>
<summary>Answers</summary>

1. **Methods policy** = who may register/use a method (broad). **Authentication strength** = what a
   specific resource demands (narrow, via Conditional Access).
2. **Windows Hello for Business, Platform Credential for macOS, synced passkeys, FIDO2 security
   keys, passkeys in Microsoft Authenticator, certificate-based authentication.**
3. The credential is **cryptographically bound to the origin**, so an adversary-in-the-middle proxy
   cannot replay it.
4. **No — primary only.**
5. **No.** It is identity verification for **account recovery only** — it cannot satisfy sign-in,
   MFA or SSPR.
6. Only if the user is **enabled for passkey (FIDO2) and has a passkey registered**.
7. **Registration coverage** — who has that method as their *only* factor. **Temporary Access Pass**
   is the rescue and the onboarding mechanism.
8. Users with **one method only** (especially SMS), and users with **none registered** — sorted by
   whether they are administrators.
9. **Helpdesk social engineering** — impersonating an employee to get credentials reset, the
   dominant initial-access technique of recent years.
10. **`amr`** in the token; visible per sign-in via `AuthenticationDetails`.

</details>

---

## 12. Evidence this topic needs

- **`lab/`** — register a passkey; apply phishing-resistant strength to one app; attempt
  password + SMS and capture the exact failure; decode `amr` in the resulting token.
  ✗ **Requires Entra ID P1 for authentication strengths.**
- **`break-fix/`** ⭐ — disable a method a test user depends on, lock them out, and **recover with
  TAP**. That single exercise teaches §6 and §7 together.
- **`security/`** — the §6 coverage report with SMS-only and no-method users identified and sorted
  by admin status; account recovery process reviewed against §5.
- **`operations/`** — registration campaign configuration; migration plan against the SMS/voice dates.
- **`architecture-decisions/`** — ADR: target method set per persona, and the sequence for retiring SMS.
- **`customer-use-cases/`** — §9 answered against a real tenant.
