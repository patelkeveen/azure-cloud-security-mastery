# Layer 3 — SC-300 Domain 2: Implement Authentication and Access Management (25–30%)

> The largest exam domain, and the one where the daily job actually lives. Layer 1 gave you
> tokens; Layer 2 gave you identities; this is the **decision engine** that stands between them.
>
> **Gate:** you own this layer when you can predict the outcome of a sign-in given a set of CA
> policies, read the CA tab of a sign-in log and say *why* a policy did or didn't apply, and
> design a break-glass exclusion without being told to.
>
> All product behaviour below verified against Microsoft documentation on **2026-08-09**.

---

## 1. Where Conditional Access actually sits — the thing that's mis-taught

```
1. User submits credentials
2. Entra validates the FIRST FACTOR         ← identity is now established
3. ══════ CONDITIONAL ACCESS EVALUATES ══════
4. Grant / block / require additional controls
5. Token issued (with amr, acr claims — Layer 1 §4)
```

**Conditional Access is evaluated *after* initial authentication.** Microsoft states this
explicitly. Two consequences almost nobody internalises:

**(a) CA does not stop a password from being tested.** Under a phishing-resistant strength
policy, a user *can still type their password* — they simply can't finish signing in without
a passkey. So an attacker with valid credentials still learns the credentials are valid. CA is
an **authorisation** gate, not a credential-protection mechanism. Protecting the credential
itself is a separate job: Entra Password Protection, smart lockout, and leaked-credential
detection (§4).

**(b) "Blocked by Conditional Access" in a log does not mean the password was wrong.** It means
it was *right*, and policy stopped the sign-in anyway. That distinction matters in an incident.

---

## 2. Policy evaluation logic ⭐⭐ — the most important page in this document

### The rules

1. **Every enabled policy is evaluated on every sign-in.** There is no "first match wins."
2. **Assignments decide whether a policy applies** — users/roles, target resources, and
   conditions. If any assignment doesn't match, the policy is *Not applied*.
3. **Block beats everything.** One matching block policy ends it, regardless of how many grant
   policies would have allowed it.
4. **Multiple grant controls default to AND.**

> ⚠ **The trap.** When you select several grant controls, the default is
> **"Require ALL the selected controls."** You must deliberately choose **"Require one of the
> selected controls"** to get OR behaviour. Getting this backwards produces a policy far
> stricter than intended — e.g. requiring MFA *and* a compliant device *and* hybrid join
> simultaneously, which locks out anyone missing any one of them.

5. **Conditions combine as AND across categories, OR within a category.** Platform *and*
   location *and* client app; but iOS *or* Android within platform.
6. **Session controls all apply** — they don't compete.

### Validation order (why your logs look weird)

Controls are validated in a fixed order: **MFA → device state → terms of use.** So if a user
must satisfy MFA and ToU, and no MFA claim is in the token yet, you'll see an *interrupt* and a
**ToU failure in the log even though the user accepted the ToU months ago**. A second log entry
appears after MFA completes showing both succeeded.

This single fact explains a recurring "our ToU is broken" ticket that isn't.

### Reading a sign-in log

The **Conditional Access** tab lists every policy and its result:

| Result | Meaning |
|---|---|
| **Success** | Applied, controls satisfied |
| **Failure** | Applied, controls not satisfied |
| **Not applied** | Assignments didn't match — expand to see which one |
| **Disabled** | Policy is off |
| **Report-only: …** | Would have had this result |

**"Not applied" is where you debug.** It tells you which assignment excluded the sign-in — wrong
user group, wrong resource, wrong condition. Guessing at policy JSON before reading this is the
most common time-waster in CA troubleshooting.

---

## 3. Building policies

### 3.1 Assignments

**Users** — include/exclude users, groups, directory **roles**, guest types, and
**workload identities** (requires Workload Identities Premium).

> **Targeting by directory role is a trap in one direction:** role assignment is dynamic, so a
> policy targeting "Global Administrator" covers whoever holds it today — including someone who
> just activated via PIM. Excellent for security, and exactly why break-glass accounts must be
> excluded explicitly.

**Target resources** — cloud apps, user actions (register security info, register/join device),
**authentication context** (`c1`–`c25`), and global secure access traffic profiles.

**Conditions**

| Condition | Notes |
|---|---|
| User risk / sign-in risk | Requires P2 (§4) |
| Insider risk | Purview integration |
| Device platforms | iOS, Android, Windows, macOS, Linux |
| Locations | Named locations, trusted IPs, countries, **compliant network** |
| Client apps | **Browser, mobile/desktop, and legacy: Exchange ActiveSync + "other clients"** |
| **Filter for devices** | Rule-based device targeting — heavily used in practice |
| Authentication flows | Device code flow, authentication transfer |

**Legacy authentication is the highest-value single policy you will ever write.** Basic auth
protocols (POP, IMAP, SMTP AUTH, older EWS) **cannot do MFA** — they submit a username and
password and get a token. Every MFA policy you write is bypassed by them. Block "Other clients"
for everyone, with an exclusion group for the handful of service accounts that genuinely need
it, and a plan to remove those.

### 3.2 Grant controls

| Control | Notes |
|---|---|
| **Block access** | Absolute. Test in report-only first |
| Require MFA | WHfB satisfies this |
| **Require authentication strength** | Modern replacement — see §3.3. **Cannot be combined with "Require MFA"** in the same policy; they're equivalent |
| Require compliant device | **Intune verdict.** No Intune ⇒ nobody passes |
| Require Hybrid Entra joined | Join-state fact. **Different from compliant** (Layer 2 §1.2) |
| Require app protection policy | Intune MAM |
| ~~Require approved client app~~ | **Scheduled for retirement early March 2026.** See warning below |
| Require password change | Only for user-risk policies; **must target All resources**; cannot combine with other controls |
| Require risk remediation | Auto-applies auth strength + sign-in frequency "every time" |
| Terms of use | Validated *after* MFA and device state |

> ⚠ **Approved client app retirement.** Microsoft scheduled the **Require approved client app**
> grant for retirement in **early March 2026** — a date now in the past — directing customers to
> move policies using *only* that grant to *"approved client app **OR** app protection policy"*,
> and to use **only app protection policy** for new policies. The documentation still carried the
> future-tense warning as of mid-2026, so **verify the live state in your tenant rather than
> trusting either the doc or this file.** Any policy you inherit that relies solely on this grant
> is a migration item.
>
> Caveat worth knowing: **Kaizala, Skype for Business, and Visio do not support the app
> protection policy grant** — an OR clause between the two grants will not save them.

**Device code flow does not support device-state grant controls.** The device authenticating
isn't the device receiving the code, so it can't present device state. Use MFA instead. This is
also a good reason to *block* device code flow via the authentication-flows condition unless
you need it (Layer 1 §2 — device code phishing).

### 3.3 Authentication strengths

Replaces the blunt "Require MFA" with a specification of *which* methods qualify. **Three
built-in strengths**, not modifiable:

| Method | MFA strength | Passwordless MFA | **Phishing-resistant MFA** |
|---|:---:|:---:|:---:|
| FIDO2 security key / passkey | ✅ | ✅ | ✅ |
| Windows Hello for Business / platform credential | ✅ | ✅ | ✅ |
| Certificate-based auth (multifactor) | ✅ | ✅ | ✅ |
| Microsoft Authenticator (phone sign-in) | ✅ | ✅ | — |
| Temporary Access Pass | ✅ | — | — |
| Password + something you have¹ | ✅ | — | — |
| Federated MFA | ✅ | — | — |
| SMS sign-in, password alone, QR code | — | — | — |

¹ text message, voice, push, software or hardware OATH token.

**Custom strengths** are supported for exact combinations.

> **The design pattern customers pay for:** set the *Authentication methods policy* broadly
> (what users may register), then use *authentication strengths* narrowly (what a specific
> resource demands). Everyday apps → MFA strength. Admin portals and crown-jewel data →
> phishing-resistant. That two-layer model is the answer to "how do we go passwordless without
> breaking everyone at once."
>
> **Known wrinkle:** authentication strength and sign-in frequency can be satisfied at
> *different times*. A passkey sign-in yesterday can satisfy today's strength requirement while
> today's Windows Hello unlock satisfies the frequency requirement. Users are not always
> re-prompted when you'd expect.

### 3.4 Session controls

| Control | Use |
|---|---|
| Sign-in frequency | Periodic reauth; or "every time" for high-risk actions |
| Persistent browser session | Block "stay signed in" on unmanaged devices |
| **Conditional Access App Control** | Hands the session to Defender for Cloud Apps (Layer 4) |
| **Continuous access evaluation** | Near-real-time revocation (Layer 1 §4) |
| Disable resistance defaults | Rarely correct |
| **Token protection** | Binds the refresh token to the device — defeats token theft/replay |

**Token protection matters more every year.** Once MFA is universal, attackers stop guessing
passwords and start **stealing tokens** (AitM proxies, infostealers). Token protection and CAE
are the controls that address that; MFA alone does not.

### 3.5 Persona-based design

Don't write policies per app. Write them per **persona**, which is how they stay maintainable:

| Persona | Typical baseline |
|---|---|
| **Break-glass** | **Excluded from everything.** Alert on any sign-in |
| Admins | Phishing-resistant strength, compliant device, short sign-in frequency |
| Internals | MFA, compliant-or-hybrid device, block legacy auth |
| Externals / guests | MFA (or trusted from home tenant — Layer 2 §1.3), session limits |
| Developers | Usually internals + device-code and workload-identity rules |
| Workload identities | Location-restricted, risk-based (Workload ID Premium) |

Naming convention that survives a tenant with 60 policies:
`CA<nnn>-<Persona>-<TargetResource>-<Control>-<State>` →
`CA001-Global-AllApps-BlockLegacyAuth-ON`

### 3.6 The exclusion that is not optional

Every CA policy needs a **break-glass exclusion**, and the accounts must match the design in
Layer 5 §4.3: two accounts, cloud-only, `*.onmicrosoft.com`, no dependency on a single MFA
method, credentials split and physically secured, **alerting on any sign-in**.

**The classic self-inflicted outage:** a policy targeting *All users* requiring a compliant
device, in a tenant without Intune fully deployed. Everyone is locked out, including every
admin, and the only way back in is an account you excluded in advance — or a Microsoft support
case measured in days.

---

## 4. Microsoft Entra ID Protection (P2)

### Risk types

| | **User risk** | **Sign-in risk** |
|---|---|---|
| Question | Is this identity compromised? | Is *this sign-in* suspicious? |
| Examples | **Leaked credentials**, threat-intel match | Anonymous IP, impossible travel, unfamiliar properties, token anomaly |
| Typical response | Require secure password change | Require MFA / block |

**Leaked-credential detection requires Password Hash Sync** (Layer 2 §1.4). Microsoft matches
your users' hashes against credentials found in breach dumps. **A federated or PTA-only tenant
gets nothing from this** — which is one of the strongest practical arguments for enabling PHS
even when you authenticate elsewhere.

**Real-time vs offline:** some detections fire during sign-in and can trigger a policy; others
surface minutes to hours later. A user who "passed" can be flagged afterwards — which is
precisely what CAE and user-risk policies are for.

### Operating it

- **Confirm compromised / confirm safe is a feedback loop that trains the model.** Dismissing
  risk without classifying it wastes the signal. Doing this consistently measurably improves
  detection quality — and it's a habit that distinguishes a real operator.
- **Registration campaigns** (2026-04-27 objective wording) nudge users from SMS toward
  Authenticator during sign-in.
- **Risky workload identities** — service principals get risk detections too. Under-taught,
  increasingly the actual breach path (Layer 4).

---

## 5. Authentication methods

### The policy migration

The **Authentication methods policy** is the modern control surface, replacing the legacy MFA
and SSPR method settings. Legacy settings are on a deprecation path — **migrate deliberately
and verify per-method**, because the two systems can disagree during transition.

### Methods worth real depth

| Method | What to know |
|---|---|
| **Passkeys (FIDO2)** | Phishing-resistant. Terminology updated — "passkeys (FIDO2)", including device-bound passkeys in Authenticator. Attestation and key-restriction settings control which authenticators are permitted |
| **Windows Hello for Business** | Satisfies MFA. Three trust models — **cloud Kerberos trust** (simplest, recommended), key trust, certificate trust. Cloud Kerberos trust needs Entra Kerberos configured |
| **Certificate-based auth** | Username binding rules, PKI trust store, single- vs multi-factor affinity. Government/PIV-CAC staple |
| **Temporary Access Pass** | Time-limited passcode. Onboarding a passwordless user, and recovery when someone loses their only factor. One-time or multi-use |
| **Microsoft Authenticator** | Number matching is enforced; additional context (app name, location) reduces MFA fatigue attacks |
| **SMS / voice** | Weakest. NIST SP 800-63B treats SMS as restricted. Migrate off it — that's what registration campaigns are for |

### SSPR

Registration policy, **combined registration** (one flow for MFA + SSPR), and — for hybrid —
**password writeback**, so a cloud reset propagates to on-prem AD. Without writeback the user
resets their cloud password and their laptop still wants the old one.

### Entra Password Protection

Global banned list plus a **custom banned list**, with fuzzy matching for variants
(`P@ssw0rd1!`). Extends on-premises via a **DC agent + proxy**. Run it in **audit mode first**
to see what would have been rejected before you enforce — turning it straight on can block
routine password changes at scale.

### Entra Kerberos / cloud Kerberos trust

Enables WHfB cloud Kerberos trust and Azure Files access with Entra credentials. The bridge that
lets a cloud-authenticated user reach Kerberos-dependent on-prem resources.

---

## 6. Global Secure Access

Microsoft's SSE entry. Three pieces:

| Component | What it does |
|---|---|
| **Private Access** | ZTNA. **Successor to Application Proxy for TCP/UDP** — App Proxy is HTTP(S)-only. Quick Access (broad) or per-app segments |
| **Internet Access** | Secure web gateway — web content filtering, threat protection |
| **Internet Access for M365** | Optimised M365 traffic profile; enables **tenant restrictions v2** |

Two CA integrations that make it more than a VPN replacement:

- **Compliant network** as a CA location condition — "this session came through our SSE," which
  is far stronger than an IP allowlist an attacker can source-spoof or VPN into.
- **Tenant restrictions v2** — stop users signing into *other* tenants from your network with
  your devices. The data-exfiltration control most organisations don't know exists.

---

## 7. `[BEYOND]` — Conditional Access for agent identities (Preview)

Directly relevant to your **SC-500** track, and brand new:

- Policies targeting **agents acting as users** support **Block access**, and **Grant with
  "Require device to be marked as compliant"** where the agent session runs on a managed
  endpoint providing device signals.
- **Agent identities themselves support only Block access** — no grant controls.
- Agent sessions running in cloud infrastructure may provide **no device signal at all**, so
  scope such policies with conditions to endpoint-based sessions only.

Non-human identity is becoming the dominant identity population, and this is the first control
plane for it. Nobody has this on a CV yet.

---

## 8. Troubleshooting decision trees

**"User was blocked and shouldn't have been"**
```
Open the sign-in log → Conditional Access tab
├── A policy shows Failure → which control? MFA? device? read the control
└── All show "Not applied" but access denied
     ├── check a BLOCK policy applied
     └── check the app's own permissions/assignment (not CA at all)
```

**"Policy isn't applying"**
```
Is it Enabled (not Report-only, not Off)?
└── YES → does the user match Users assignment (incl. exclusions/nested groups)?
     └── YES → does the resource match Target resources?
          └── YES → do ALL conditions match? (AND across categories)
               └── still no → run What-If; compare against a real sign-in log
```

**"MFA prompt appears more/less often than expected"**
→ sign-in frequency vs persistent browser vs token lifetime vs CAE claims challenge. Also the
strength/frequency wrinkle in §3.3 — they can be satisfied at different moments.

---

## 9. Hands-on gate

Needs your own tenant. **Do everything in report-only first.**

**Lab 1 — Baseline.** Create in report-only: block legacy auth; require MFA for all users;
require MFA for admins with phishing-resistant strength. Run for a day. Read the report-only
results in the sign-in logs *before* enabling.

**Lab 2 — Prove the AND/OR trap.** One policy, two grant controls, default (Require all).
Observe the outcome. Switch to "Require one of the selected." Observe the difference. **This is
the single most valuable thirty minutes in this layer.**

**Lab 3 — What-If.** Model a guest on iOS from a foreign country hitting SharePoint. Compare
the prediction against a real sign-in log and note where What-If is *not* authoritative (it
can't know live risk or real device state).

**Lab 4 — Lock yourself out on purpose.** Require a compliant device for a *test* user in a
tenant with no Intune. Confirm the block. Recover using break-glass. **Do this once in a lab so
you never do it accidentally in production.**

**Lab 5 — Auth strength.** Apply phishing-resistant strength to one app. Try to access with
password + SMS. Read the failure. Register a passkey. Retry.

**Lab 6 — Authentication context.** Create `c1`, bind it to a PIM role activation, require
phishing-resistant strength for it. This is the pattern for protecting privileged operations
without punishing everyday sign-ins.

**Lab 7 — Read the token.** After a CA-satisfied sign-in, decode the token (Layer 1 §4) and find
`amr` and `acr`. **Watch the policy decision appear as claims.** This is where Layers 1 and 3
close the loop.

---

## 10. Cross-references

| Concept here | Connects to |
|---|---|
| `amr` / `acr` claims, CAE | Layer 1 §4 — JWT internals |
| Device compliance vs hybrid joined | Layer 2 §1.2 — device join states |
| Guest MFA trust | Layer 2 §1.3 — cross-tenant access settings |
| Leaked credentials ⇒ PHS | Layer 2 §1.4 — hybrid auth choice |
| CA App Control sessions | Layer 4 — Defender for Cloud Apps |
| Authentication context | Layer 5 — PIM activation, protected actions |
| Sign-in log schema | Layer 5 — KQL over `SigninLogs` |
| Agent identity CA | Layer 6 — SC-500 / Entra Agent ID |
