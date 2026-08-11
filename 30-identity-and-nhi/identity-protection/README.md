# Identity Protection

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (updated 2026-02-10).
> **SC-300 Domain 2/4. Requires P2.** Depth in
> [Layer 3 §4](../conditional-access/LAYER-3-DOMAIN-2-AUTH-AND-ACCESS.md).

---

## 1. What it is

Machine-learning risk detection over identity signals, expressed as scores that **Conditional Access
consumes as conditions** and that a SIEM can ingest.

| | **User risk** | **Sign-in risk** |
|---|---|---|
| Asks | Is this identity **compromised**? | Is **this sign-in** suspicious? |
| Examples | Leaked credentials, threat-intel match | Anonymous IP, impossible travel, unfamiliar properties |
| Remedy | **Secure password change** | **Require MFA**, or block |

**Three reports** ✅, and the difference matters when reading a portal:

- **Risk detections** — every individual detection
- **Risky sign-ins** — a sign-in with one or more detections
- **Risky users** — a user with a risky sign-in **or** a detection

---

## 2. Why the split matters

They are different questions with different remedies. A compromised *credential* needs the password
changed. A suspicious *sign-in* needs stronger proof **right now** — changing the password does
nothing if the credential was never the problem.

Conflating them produces the classic misconfiguration: a user-risk policy forcing password changes
on people whose password was fine, training everyone to click through the prompt.

---

## 3. ⭐ Detection quality depends on which Defender products you own ✅

**This is the thing almost nobody teaches, and it changes procurement advice.**

Identity Protection does not generate every detection itself. Several arrive **from Defender
products**, and you need the licence for the product that owns the signal:

| Signal | Comes from |
|---|---|
| Activity from anonymous IP address | **Defender for Cloud Apps** |
| **Impossible travel** | **Defender for Cloud Apps** |
| Mass access to sensitive files | **Defender for Cloud Apps** |
| New country | **Defender for Cloud Apps** |
| Suspicious inbox rules | **Defender for Office 365** |
| ⭐ **Possible attempt to access Primary Refresh Token** | **Defender for Endpoint** |

✅ **Microsoft 365 E5 covers all of them.**

> ⭐ **A tenant with Entra ID P2 alone sees fewer detections than a tenant with P2 plus the Defender
> stack** — and the portal does not tell you what you are missing. "We have P2, so we have Identity
> Protection" is true and incomplete. **Impossible travel — the detection everyone names first —
> comes from Defender for Cloud Apps.**
>
> That single fact reframes the licensing conversation: the Defender products are not just detection
> tools in their own right, they are **inputs that raise the quality of your identity risk engine**.

---

## 4. ⭐ The role separation nobody notices ✅

| Role | Can | **Cannot** |
|---|---|---|
| Global Reader | Read ID Protection | Write |
| **User Administrator** | **Reset user passwords** | ⭐ **Read or write ID Protection at all** |
| Conditional Access Administrator | Create risk-based policies | Read/write legacy ID Protection policies |
| Security Reader | View all reports | Configure, reset passwords, **give feedback on detections** |
| **Security Operator** | View reports; ⭐ **dismiss risk, confirm safe, confirm compromised** | Configure policies, **reset passwords** |
| Security Administrator | Full access to ID Protection | ⭐ **Reset a user's password** |

> ⭐ **No single role can both confirm compromise and reset the password.** A Security Operator
> confirms the compromise; a User Administrator performs the reset. That is **deliberate separation
> of duties**, and it means your remediation runbook needs **two people or two roles** — which is
> exactly the sort of detail that shows you have operated the product rather than read about it.

---

## 5. Licensing — and what P1 actually shows ✅

The common belief is "risk is P2, full stop." The reality is more useful:

| Capability | Free | **P1** | **P2** |
|---|---|---|---|
| **Risk-based policies** | ✗ | ✗ | ✅ |
| Risky users report | Medium/high only, no details, no history | Same as free | **Full** |
| Risky sign-ins report | No risk detail or level | Same as free | **Full** |
| Risk detections report | ✗ | Limited, no details drawer | **Full** |
| Notifications + weekly digest | ✗ | ✗ | ✅ |
| ⭐ **Graph API for risk reports** | ✗ | ✗ | **✅** |

**Two consequences worth carrying:**

1. **A P1 tenant can already see medium and high risky users** — enough to demonstrate value and
   justify P2, and enough to find a live compromise today. Do not tell a P1 customer they have nothing.
2. ⭐ **Graph API access to risk data is P2.** Any automation, export or SIEM enrichment built on the
   risk APIs stops working the day a P2 trial lapses — pair this with the PIM licence-expiry
   behaviour in [`../pim-and-access-reviews/`](../pim-and-access-reviews/) §8.

⚠ **Risky workload identities need *Workload Identities Premium*** ✅ — a **separate licence**, not
included by P2. Assuming P2 covers service principal risk is a costing and design error.

---

## 6. How it works underneath

**Leaked-credential detection requires Password Hash Sync.** Microsoft compares synced hashes
against credentials recovered from breach corpora. **A federated or PTA-only tenant gets nothing
from this** — one of the strongest practical arguments for enabling PHS even when authenticating
elsewhere. See [`../../35-active-directory-and-hybrid-identity/hybrid-coexistence/`](../../35-active-directory-and-hybrid-identity/hybrid-coexistence/) §3.

**Real-time versus offline detections.** ✅ Every sign-in runs the real-time detections and produces
a session risk level that policy acts on. Others surface minutes to hours later — so **a user who
"passed" can be flagged afterwards**, which is exactly what user-risk policies and Continuous Access
Evaluation exist to handle.

**Automatic versus manual remediation** ✅: if a risk-based policy is enabled and the user completes
the required control — MFA or a secure password change — **the risk is remediated automatically**.
Without such a policy, an administrator must dismiss, confirm safe, or confirm compromised by hand.

---

## 7. Worked example — reading and acting on risk

```powershell
Connect-MgGraph -Scopes 'IdentityRiskyUser.ReadWrite.All','IdentityRiskEvent.Read.All'

# Who is currently at risk, and has anything been done about it?
Get-MgRiskyUser -All -Filter "riskState ne 'remediated' and riskState ne 'dismissed'" |
  Select-Object UserPrincipalName, RiskLevel, RiskState, RiskDetail, RiskLastUpdatedDateTime |
  Sort-Object RiskLevel -Descending
```

```
UserPrincipalName        RiskLevel  RiskState        RiskDetail             RiskLastUpdated
-----------------------  ---------  ---------------  ---------------------  -------------------
priya@contoso.com        high       atRisk           none                   2026-08-09 14:22:31
svc-reporting@contoso..  medium     atRisk           none                   2026-08-07 09:11:04
j.okafor@contoso.com     low        confirmedSafe    adminConfirmedSafe     2026-08-05 16:40:12
```

⭐ **`RiskDetail: none` means nobody has triaged it.** Two entries sitting at `atRisk` with no detail
is the finding — risk was detected and nothing happened. **And risky users are never aged out until
remediated**, so this list is cumulative, which is why it grows quietly for years.

**What kind of risk, specifically:**

```powershell
Get-MgRiskDetection -All -Filter "riskState eq 'atRisk'" |
  Select-Object UserPrincipalName, RiskEventType, RiskLevel, DetectionTimingType, IPAddress, DetectedDateTime |
  Sort-Object DetectedDateTime -Descending | Select-Object -First 15
```

`DetectionTimingType` tells you **realtime** or **offline** — which decides whether a sign-in policy
could ever have caught it.

**Close the loop — this is the habit that separates an operator from someone who enabled a feature:**

```powershell
# Genuine compromise: raises the user to high risk and feeds the model
Confirm-MgRiskyUserCompromised -UserIds @('priya@contoso.com')

# Verified benign (e.g. a known VPN egress): teaches the model
Invoke-MgDismissRiskyUser -UserIds @('j.okafor@contoso.com')
```

> ⭐ **Confirming compromised or safe trains the model.** Dismissing risk without classifying it
> throws the signal away. ⚠ Note from §4 that **Security Administrator can do this but cannot reset
> the password** — the runbook needs both roles.

**Retention, verified:**

| Report | Free | P1 | **P2** |
|---|---|---|---|
| Risky sign-ins | 7 days | 30 days | **90 days** |
| **Risky users** | **No limit** | No limit | **No limit** |

Risky sign-ins are retained **longer than ordinary sign-in logs**. Export to Log Analytics via
diagnostic settings if you need more.

---

## 8. Deployment order

```
1. Enable and OBSERVE — do not enforce on day one
2. Read risky users/sign-ins for a week; learn YOUR baseline
3. Sign-in risk → require MFA          (low blast radius, high value)
4. User risk → require password change (higher friction — needs MFA coverage FIRST)
5. Registration campaigns to move users off SMS
```

**Step 4 has a trap: user-risk remediation requires prior MFA registration.** A user with no MFA
method cannot complete a secure password change, so the remediation path is itself blocked. Check
coverage first — see [`../authentication-methods/`](../authentication-methods/) §6.

---

## 9. What breaks

**Enforcing before observing.** Impossible travel fires for VPN users and frequent travellers.

**User-risk policy without MFA registration coverage.** The remediation is unreachable.

**Expecting leaked-credential detection without PHS.** It never populates.

**Assuming P2 alone gives every detection.** §3 — several come from Defender products.

**Assuming P2 covers workload identity risk.** §5 — separate licence.

**Assuming P1 shows nothing.** §5 — medium and high risky users are visible.

**Dismissing risk without classifying it.** Throws away model feedback.

**A runbook assuming one role can do everything.** §4 — confirm and reset are separate.

**Building automation on the risk Graph API without P2**, or losing it when a trial lapses.

**Ignoring workload identity risk** because the dashboard defaults to humans.

---

## 10. Customer discovery questions

1. Is P2 licensed — and which **Defender products**? *(§3 — decides detection coverage.)*
2. Is **PHS enabled**? *(No PHS → no leaked-credential detection.)*
3. How many users sit at `atRisk` with **`RiskDetail: none`**? *(§7 — nobody triaged them.)*
4. Are risk-based policies **enforcing**, or was it enabled and left in observe?
5. Does the remediation runbook name **both** roles — who confirms, who resets? *(§4.)*
6. Is **MFA registration coverage** sufficient for user-risk remediation to work?
7. Is **Workload Identities Premium** licensed? Is anyone reading service principal risk?
8. Is risk data exported to a SIEM? *(Graph API is P2 — what happens if it lapses?)*
9. Does anyone **confirm compromised / confirm safe**, or is risk just dismissed?

---

## 11. Remember it

**Hook — "User risk = the credential. Sign-in risk = the moment."** Different questions, different
remedies: password change versus prove-it-now.

**Analogy — a fraud department, not a lock.** Sign-in risk is the card machine declining a
transaction that looks wrong *right now*. User risk is the bank ringing you because your card number
turned up on a dump — the card still works, but it is compromised. **And crucially, the fraud team
gets its signals from many sources**: the merchant, the ATM network, the travel data. Cancel those
feeds and the model gets worse without anyone being told — which is exactly §3.

**The one thing:** ⭐ **Identity Protection's detection quality depends on which Defender products
you own.** Impossible travel, anonymous IP, new country and mass file access come from **Defender
for Cloud Apps**; suspicious inbox rules from **Defender for Office 365**; Primary Refresh Token
access attempts from **Defender for Endpoint**. "We have P2" is true and incomplete, and the portal
never tells you what you are not seeing.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 12. Self-test

1. User risk versus sign-in risk — what does each ask, and what is the correct remedy for each?
2. Which detections come from Defender products, and why does that matter commercially?
3. Which roles can confirm compromise, and which can reset the password?
4. What can a P1 tenant actually see?
5. Which licence do risky **workload identities** need?
6. Why does a federated tenant get no leaked-credential detections?
7. `RiskState: atRisk` with `RiskDetail: none` — what does that tell you?
8. Why does a user-risk policy fail on a user with no MFA registered?
9. What does `DetectionTimingType` tell you, and why does it matter?
10. What is lost by dismissing risk without classifying it?

<details>
<summary>Answers</summary>

1. **User risk** = is the identity compromised → **secure password change**. **Sign-in risk** = is
   this sign-in suspicious → **require MFA or block**.
2. Impossible travel, anonymous IP, new country, mass file access (**MDA**); suspicious inbox rules
   (**MDO**); PRT access attempts (**MDE**). **P2 alone yields fewer detections** — it changes the
   licensing recommendation.
3. **Security Operator and Security Administrator** can confirm/dismiss. **User Administrator**
   resets passwords — and neither can do the other's job.
4. **Medium and high risky users** (no details drawer or history) and risky sign-ins without risk
   level. No policies, no Graph API, no notifications.
5. **Workload Identities Premium** — separate from P2.
6. **Leaked-credential detection requires Password Hash Sync.** No synced hash, no comparison.
7. **Nobody has triaged it** — risk detected, no action taken. And risky users never age out.
8. The remediation *is* a secure password change, which **requires a registered MFA method** to
   complete.
9. **realtime** versus **offline** — whether a sign-in policy could ever have caught it in the moment.
10. **Model feedback.** Confirming compromised or safe trains the detections; a bare dismissal
    discards the signal.

</details>

---

## 13. Evidence this topic needs

- **`lab/`** — enable; generate risk from an anonymous IP; observe the detection, the policy, and
  automatic remediation. ✗ **Requires P2.**
- **`break-fix/`** ⭐ — trigger a user-risk policy on an account with **no MFA registered** and
  observe the remediation deadlock. Then register a method and prove it resolves.
- **`security/`** — the §7 risky-user export with untriaged entries flagged; confirm-compromised
  workflow documented **with both roles named**; workload identity risk reviewed if licensed.
- **`operations/`** — triage runbook: who investigates, what evidence, what closes a case; risk data
  exported to Log Analytics for retention beyond 90 days.
- **`architecture-decisions/`** — ADR: risk thresholds per policy, and the Defender licensing
  decision framed as **detection coverage** rather than product count.
- **`customer-use-cases/`** — §10 answered against a real tenant.
