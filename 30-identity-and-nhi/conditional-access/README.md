# Conditional Access

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (updated 2026-03-25).
> ⭐ **The highest-weight topic in SC-300** and the control plane of a modern estate.
> Full narrative depth in **[LAYER-3-DOMAIN-2-AUTH-AND-ACCESS.md](LAYER-3-DOMAIN-2-AUTH-AND-ACCESS.md)**.

---

## 1. What it is

An **if-then policy engine** that sits between a successful first-factor authentication and the
issuing of a token. It evaluates signals — user, resource, network, device, risk — and decides
**block**, **grant**, or **grant with conditions**.

```
Assignments (WHO, WHAT, WHERE)   →   Access controls (grant / session)
```

---

## 2. ⭐ Where it actually sits — the thing that is mis-taught

```
1. User submits credentials
2. Entra validates the FIRST FACTOR      ← identity established
3. ══ CONDITIONAL ACCESS EVALUATES ══
4. Grant / block / require more
5. Token issued (amr, acr claims)
```

**CA runs *after* initial authentication.** Two consequences almost nobody internalises:

- **CA does not stop a password from being tested.** Under a phishing-resistant policy a user can
  still type a password — they simply cannot finish. **An attacker with valid credentials still
  learns they are valid.** Protecting the credential is a different job: password protection, smart
  lockout, leaked-credential detection.
- ⭐ **"Blocked by Conditional Access" in a sign-in log means the password was correct.** In an
  incident that distinction is the difference between a failed attack and a partially successful one.

---

## 3. How the decision is made ✅

**Two phases**, and knowing this explains most confusing behaviour:

| Phase | What happens |
|---|---|
| **Phase 1 — collect** | Gather session details: network, device identity. ⭐ **Runs for report-only policies too** |
| **Phase 2 — enforce** | Identify unmet requirements. **A `block` policy stops everything here.** Then prompt for unsatisfied grant controls in a fixed order |

**Every enabled policy is evaluated on every sign-in.** There is no first-match-wins, no priority
ordering. **All applicable policies must be satisfied**, combined with **AND**.

**Assignments are also ANDed.** Every configured assignment must match for the policy to trigger.

### ⭐ The grant control prompt order — all eight ✅

```
1. Multifactor authentication
2. Device marked as compliant
3. Microsoft Entra hybrid joined device
4. Approved client app
5. App protection policy
6. Password change
7. Terms of use
8. Custom controls              ⚠ retiring 30 September 2026 — see below
```

**This ordering is why users report a Terms of Use *failure* despite having accepted it months ago**
— MFA (step 1) had not yet been satisfied, so evaluation never reached step 7. The log shows the
first unsatisfied control, not the root cause.

⚠ **Custom controls retire 30 September 2026** (EOL May 2027) → migrate to **External Authentication
Methods**. See [`../../35-active-directory-and-hybrid-identity/okta-and-third-party-idp/`](../../35-active-directory-and-hybrid-identity/okta-and-third-party-idp/) §5.

### The AND/OR trap

> ✅ **"By default, multiple controls require all."** You must explicitly select *"Require one of the
> selected controls"* to get OR.

Getting this backwards builds a policy far stricter than intended — MFA **and** compliant device
**and** hybrid join simultaneously — locking out anyone missing any one of them. **Lab it
deliberately before writing a real policy.**

Session controls apply **only after all grant controls are satisfied**.

---

## 4. ⭐ The subtlety that catches experienced engineers ✅

> **Policies targeting roles or groups are evaluated only when a token is issued.**

Consequences, straight from the documentation:

- A user **newly added** to a group or role is **not subject to the policy until they get a new token**
- If they already hold a valid token, **the policy does not apply retroactively**

**So adding someone to "Require phishing-resistant MFA for admins" does not protect the session they
are already in.** They can hold an existing token for its full lifetime.

**Microsoft's own recommended mitigation:** trigger CA evaluation at **PIM role activation** — set
*on activation, require multifactor authentication* in the PIM role settings. See
[`../pim-and-access-reviews/`](../pim-and-access-reviews/).

This is also why [`../../50-security-operations/incident-response/`](../../50-security-operations/incident-response/)
§5 insists on `Revoke-MgUserSignInSession`: **changing policy does not evict an existing session.**

---

## 5. Worked example — a policy as code, read clause by clause

Portal clicking does not scale and cannot be reviewed. Read policies as objects:

```powershell
Connect-MgGraph -Scopes 'Policy.Read.All'
Get-MgIdentityConditionalAccessPolicy -All |
  Select-Object DisplayName, State,
    @{n='Users';    e={ $_.Conditions.Users.IncludeUsers -join ',' }},
    @{n='Excluded'; e={ $_.Conditions.Users.ExcludeUsers.Count }},
    @{n='Controls'; e={ $_.GrantControls.BuiltInControls -join ',' }},
    @{n='Operator'; e={ $_.GrantControls.Operator }} |
  Sort-Object State
```

```
DisplayName                        State       Users  Excluded  Controls              Operator
---------------------------------  ----------  -----  --------  --------------------  --------
CA001 - Block legacy auth          enabled     All           2  block                 OR
CA002 - MFA for all users          enabled     All           2  mfa                   OR
CA003 - Admins phishing-resistant  enabled     All           2  mfa,compliantDevice   AND
CA004 - Require compliant device   reportOnly  All           0  compliantDevice       AND   <-- ⚠
```

**Read that output like a reviewer.** `CA004` has **`Excluded: 0`** — **no break-glass exclusion**.
Enabling it in a tenant without full Intune coverage locks out every administrator including
yourself. That single column is the first thing to check in any tenant.

**The baseline that earns its keep**, in order:

| # | Policy | Why |
|---:|---|---|
| 1 | **Block legacy authentication** | ⭐ Basic auth **cannot do MFA**, so it bypasses every other policy you write |
| 2 | MFA for all users | |
| 3 | Phishing-resistant strength for admins | Authentication strengths, not just "MFA" |
| 4 | Require compliant/hybrid device for corporate apps | |
| 5 | Risk-based (sign-in and user risk) | **P2** |
| 6 | Block or restrict unfamiliar countries | |

**Design by persona, not by application.** Per-app policies reach ~30 policies and become
unmaintainable; personas (admins, staff, externals, service accounts, kiosks) stay stable.

**Test before enabling — What-If evaluates a hypothetical sign-in:**

```powershell
# Portal: Conditional Access > What If. Also available via Graph beta:
# POST /identity/conditionalAccess/evaluate  (⚠ verify current API surface)
```

**Then read what actually happened**, including report-only verdicts:

```kusto
SigninLogs
| where TimeGenerated > ago(7d)
| mv-expand Policy = ConditionalAccessPolicies
| extend Name   = tostring(Policy.displayName),
         Result = tostring(Policy.result)
| where Result in ("failure","reportOnlyFailure")
| summarize Failures = count(), Users = dcount(UserPrincipalName) by Name, Result
| sort by Failures desc
```

⭐ **`reportOnlyFailure` is a forecast of your next outage.** It says *"if this policy were enabled,
these users would have been blocked."* Read it before every promotion from report-only to enabled.

---

## 6. Assignments — the signals, and which ones you can trust ✅

| Assignment | Notes |
|---|---|
| **Users and groups** | All users, groups, **directory roles**, guests. ⚠ §4 token-issuance caveat |
| **Workload identities** | ⭐ Requires **Microsoft Entra Workload ID** licence |
| **Target resources** | Cloud apps, **user actions**, **authentication context** |
| **Network** | IP ranges, countries, and **Global Secure Access compliant network** |
| **Sign-in risk / user risk** | **P2 only** (ID Protection) |
| **Device platform** | ⚠ **Derived from unverified sources such as user agent strings** ✅ |
| **Client apps** | ⭐ **New policies apply to all client app types by default** |
| **Filter for devices** | Target by device attributes |

> ⭐ **Device platform is spoofable** — Microsoft says so explicitly. A policy that *blocks* a
> platform is trivially bypassed by changing a user agent. **Use it to scope convenience, never as a
> security boundary.** Device *compliance* and *join state* are verified facts; platform is a claim.

**Authentication context** is the underused one worth knowing: tag a *specific action* — not a whole
app — so that, for example, only role activation or a sensitive SharePoint site requires step-up.
That is how you avoid MFA-prompting people all day for everything.

---

## 7. What breaks

**No break-glass exclusion.** The classic self-inflicted outage. Two cloud-only
`.onmicrosoft.com` accounts, excluded from **every** policy, tested quarterly.

**"Require compliant device" ≠ "Require Hybrid Entra joined."** One is an Intune verdict, the other
a join-state fact. A device can be hybrid-joined and non-compliant.

**Enabling without report-only.** Every policy starts in report-only and you read the results.

**Assuming AND/OR is the other way round.** §3.

**Expecting a group change to take effect immediately.** §4 — new token required.

**Legacy authentication left unblocked.** It cannot do MFA. Everything else is decorative until it
is closed.

**Device code flow cannot satisfy device-state controls** — the authenticating device is not the one
receiving the code.

**Blocking by device platform for security.** §6 — spoofable.

**Forgetting new policies apply to all client apps by default.**

**Custom controls still in use.** ⚠ Retiring 30 September 2026 and they never satisfied the MFA claim.

---

## 8. Customer discovery questions

1. Is **legacy authentication blocked**? If not, nothing else you review matters.
2. Are there **break-glass accounts**, are they excluded from **every** policy, and when were they
   last **tested**?
3. Any policies with **zero exclusions**? *(Run the §5 command and look at the `Excluded` column.)*
4. Are policies designed by **persona or by app**? How many policies exist?
5. Is anything in **report-only**, and does anyone read `reportOnlyFailure`?
6. Are **authentication strengths** used for admins, or just "require MFA"?
7. Is **device platform** used as a security control anywhere? *(§6 — it is spoofable.)*
8. Are **custom controls** in use? *(30 September 2026 deadline.)*
9. Is CA **exported and version-controlled**, or clicked in the portal?
10. Do PIM role settings require MFA **on activation**? *(§4 mitigation.)*

---

## 9. Remember it

**Hook — "All policies, all assignments, all controls — everything is AND."** Plus: **block wins**,
and **report-only still runs Phase 1**.

**Analogy — a nightclub with many doormen, not one.** Every doorman checks you (all policies
evaluate), and you must satisfy **every** one of them. **Any single doorman saying "no" is final**
(block wins). They ask their questions in a **fixed order** — ID first, then dress code, then
membership — which is why you get turned away for the *first* thing you fail, not the real problem.
And crucially: **once you are inside, a new doorman starting their shift does not check you** — that
is the §4 token-issuance rule, and it is why policy changes do not evict existing sessions.

**The one thing:** ⭐ **CA evaluates after the password is validated.** It cannot stop credentials
being tested — "blocked by Conditional Access" means the password was **correct**. Protecting the
credential itself is a different control entirely.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 10. Self-test

1. At what point in the sign-in does CA evaluate, and what does that mean for a blocked sign-in?
2. Multiple grant controls — AND or OR by default?
3. List the first three grant controls in prompt order. Why does the order matter?
4. A user is added to an admin group with a CA policy attached. Are they immediately covered?
5. What is Microsoft's recommended mitigation for that gap?
6. `Excluded: 0` on an enabled all-users policy — what is the risk?
7. What does `reportOnlyFailure` in the sign-in logs tell you?
8. Why is blocking by device platform a weak security control?
9. Why is blocking legacy authentication the highest-value single policy?
10. Difference between "require compliant device" and "require hybrid joined"?

<details>
<summary>Answers</summary>

1. **After first-factor authentication.** So "blocked by Conditional Access" means the **password
   was correct** — the credential is confirmed valid to the attacker.
2. **AND** — "require all the selected controls" is the default. OR must be chosen explicitly.
3. **MFA → device compliant → hybrid joined.** Evaluation stops at the first unsatisfied control, so
   the logged failure is often not the root cause (e.g. a Terms of Use failure when MFA was the gap).
4. **No.** Role and group targeting is evaluated **only when a token is issued**; an existing valid
   token is unaffected.
5. Require **MFA on activation** in **PIM** role settings, which forces fresh CA evaluation.
6. **No break-glass exclusion** — enabling it can lock out every administrator including yourself.
7. It forecasts who **would have been blocked** if the policy were enabled. Read it before promoting.
8. Device platform is derived from **unverified sources like the user agent**, so it is spoofable.
9. **Legacy/basic auth cannot perform MFA**, so it bypasses every other policy.
10. **Compliant** is an Intune assessment; **hybrid joined** is a join-state fact. A device can be
    hybrid joined and non-compliant.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — build the §5 baseline in report-only, promote one at a time reading
  `reportOnlyFailure` between each; run the deliberate AND/OR experiment; compare What-If against a
  real sign-in log. ✗ **Requires Entra ID P1** — not on the current Office 365 E5 tenant.
- **`break-fix/`** ⭐ — **lock a test user out on purpose and recover via break-glass.** Once, in a
  lab, so it never happens accidentally in production.
- **`security/`** — the §5 export with the `Excluded` column reviewed; legacy auth usage; policies
  lacking break-glass exclusion; custom controls inventory against the September 2026 deadline.
- **`operations/`** — CA policies exported to source control; change runbook; report-only promotion
  procedure; quarterly break-glass test with dates.
- **`architecture-decisions/`** — ADR: persona model and the policy set derived from it.
- **`customer-use-cases/`** — §8 answered against a real tenant.
