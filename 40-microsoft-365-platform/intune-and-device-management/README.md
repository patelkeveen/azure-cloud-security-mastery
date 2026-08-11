# Intune and Device Management

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Intune produces a signal; Conditional Access consumes it.** Neither is a control alone — §2.
> Pairs with
> [`../../30-identity-and-nhi/conditional-access/`](../../30-identity-and-nhi/conditional-access/).

---

## 1. What it is

**Cloud device and application management** — configuration, compliance evaluation, app deployment
and, critically, **an input to identity decisions.**

```
DEVICE ──enrolled──▶ INTUNE ──evaluates──▶ ⭐ compliant / non-compliant
                                                   │
                                                   └─▶ ⭐ CONDITIONAL ACCESS decides
```

---

## 2. ⭐ Compliance is a signal, not an enforcement

> **A device marked non-compliant is not blocked from anything. ⭐ Intune records the state; only a
> Conditional Access policy requiring compliance turns it into an outcome.**

⭐ **This is the most common misunderstanding in the topic, and it produces a specific false comfort:**

```
Intune console:  ⭐ "412 devices non-compliant"    ← a REPORT
Reality:         ⭐ all 412 are accessing everything ← unless CA requires compliance
```

**Three states, and only the third stops anything:**

| State | Meaning |
|---|---|
| **Enrolled** | Intune can see and configure it |
| **Compliant / non-compliant** | ⭐ an **assessment** |
| ⭐ **Enforced** | ⭐ **a CA policy requires compliance for a resource** |

⭐ **"Deployed is not enforced" again** (`RETENTION.md` §3b) — the same pattern as policy in audit
mode, DMARC at `p=none`, and a deployed control nobody proved. **This repo has now found it in five
products, which is why it is worth naming rather than re-learning.**

⚠ **And the grace period is the quiet part**: a compliance policy typically allows a remediation
window before marking a device non-compliant. **During that window the device reports compliant.**
Know the value, because it is the real gap between "failed a check" and "loses access".

---

## 3. ⭐ MDM versus MAM — the choice that decides BYOD

| | **MDM** (device enrolment) | ⭐ **MAM / App protection** (no enrolment) |
|---|---|---|
| Scope | ⭐ the whole device | ⭐ **the app's data only** |
| BYOD acceptance | ⚠ poor — users resist | ⭐ **high — personal device untouched** |
| Can wipe | ⭐ the device | ⭐ **only corporate data in the app** |
| Enforces | encryption, OS version, config | ⭐ copy/paste, save-as, PIN, ⭐ **no CA compliance signal** |

⭐ **MAM is the answer for BYOD and contractors**, and the reason is behavioural rather than technical:
**a control users will not accept is not a control.** Insisting on full enrolment on personal devices
produces workarounds — mail forwarded to personal accounts, screenshots, documents in consumer
storage — and every one of those is worse than a managed app boundary.

> ⭐ **Same argument as sanctioned AI versus banning AI, and governed guest access versus open
> federation.** ⭐ **Offer the governed path or lose the visibility** — that is now the third
> appearance of this reasoning in the repo, and it is a genuine principle rather than a coincidence.

⚠ **MAM does not produce a device-compliance signal.** ⭐ So a CA policy that requires *compliant
device* will block MAM-managed BYOD — you need **require approved client app / app protection
policy** instead. **Mixing the two grant controls up is the most common CA-plus-Intune failure**, and
`grant controls default to AND`
([`../../30-identity-and-nhi/conditional-access/`](../../30-identity-and-nhi/conditional-access/))
makes it lock people out fast.

---

## 4. Worked example — the enforcement gap

```powershell
Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All','Policy.Read.All'

# ① ⭐ How many non-compliant devices, and are they blocked from anything?
Get-MgDeviceManagementManagedDevice -All `
  -Property Id,DeviceName,ComplianceState,OperatingSystem,LastSyncDateTime,UserPrincipalName |
  Group-Object ComplianceState | Select-Object Count, Name
```

```
Count Name
----- ----
 3891 compliant
  412 noncompliant          <-- ⭐ blocked from what, exactly?
  118 ⚠ unknown             <-- ⭐ not evaluated: worse than non-compliant
```

⭐ **`unknown` is the row to look at first.** A device that has not checked in has **no assessment at
all** — and a CA policy requiring compliance treats it as non-compliant, while every dashboard shows
it as neither. **It is the "not evaluated" state that hides in the middle of a two-column report.**

```powershell
# ② ⭐ The question that matters: does ANY CA policy actually require compliance?
Get-MgIdentityConditionalAccessPolicy -All |
  Where-Object { $_.GrantControls.BuiltInControls -contains 'compliantDevice' -or
                 $_.GrantControls.BuiltInControls -contains 'compliantApplication' } |
  Select-Object DisplayName, State,
    @{n='Grants';e={ $_.GrantControls.BuiltInControls -join ',' }},
    @{n='Operator';e={ $_.GrantControls.Operator }},
    @{n='Apps';e={ $_.Conditions.Applications.IncludeApplications -join ',' }}
```

```
DisplayName                     State       Grants                         Operator  Apps
------------------------------  ----------  -----------------------------  --------  ------
Require compliant device        ⚠ enabledForReportingButNotEnforced
                                            compliantDevice                AND       All
```

⭐ **`enabledForReportingButNotEnforced` is report-only mode**, and it is the finding: the policy
exists, the console shows it, the compliance numbers look meaningful — **and 412 non-compliant devices
are accessing everything.** Report-only is the correct *first* step and a poor permanent state.

```powershell
# ③ ⭐ Stale devices - enrolled, never syncing, still "compliant" from an old assessment
Get-MgDeviceManagementManagedDevice -All -Property DeviceName,LastSyncDateTime,ComplianceState |
  Where-Object { [datetime]$_.LastSyncDateTime -lt (Get-Date).AddDays(-30) } |
  Sort-Object LastSyncDateTime | Select-Object DeviceName, ComplianceState, LastSyncDateTime -First 15
```

⭐ **A device that last synced four months ago and still reports `compliant` is asserting a fact about
a machine nobody has seen since.** Compliance is a *cached assessment*, and its age matters as much as
its value.

---

## 5. The controls worth arguing for

| Control | ⭐ Why |
|---|---|
| ⭐ **CA requiring compliance** | turns the signal into an outcome — §2 |
| ⭐ **App protection for BYOD** | §3 — the acceptable path |
| **Security baselines** | a defensible starting configuration |
| ⭐ **Filters for devices** | scope CA by device attribute, not just group |
| **Autopilot / provisioning** | ⭐ devices are managed from first boot, not retrofitted |
| ⭐ **Defender for Endpoint integration** | ⭐ risk level becomes a compliance input — closes the loop |

⭐ **The Defender integration is the most valuable and the least deployed.** It makes *device risk*
(from [`../../50-security-operations/defender-for-endpoint/`](../../50-security-operations/defender-for-endpoint/))
an input to compliance, which is an input to Conditional Access — so **an active threat on a device
can automatically remove its access.** That chain (EDR → compliance → CA → access) is the closest
thing M365 has to autonomous containment, and it is configuration rather than a product purchase.

---

## 6. What breaks

**Reading non-compliance counts as protection.** §2 — ⭐ a report, not a control.

**CA policy left in report-only.** §4 — ⭐ the policy exists and enforces nothing.

**Ignoring `unknown` compliance state.** §4 — ⭐ not evaluated, hidden between the columns.

**Stale devices asserting old compliance.** §4 — a cached fact about an unseen machine.

**Requiring MDM on BYOD.** §3 — workarounds that are worse.

**Requiring *compliant device* for MAM-managed BYOD.** §3 — ⭐ locks them out; use approved client app.

**Forgetting the grace period.** §2 — the real gap between failing and losing access.

**No Defender-to-compliance integration.** §5 — ⭐ the containment loop left open.

**Baselines deployed and never reviewed.** They drift as the product changes.

**No break-glass exclusion on device-based CA.** ⚠ A compliance outage becomes a lockout.

---

## 7. Customer discovery questions

1. ⭐ Does any **CA policy require compliance**, and is it **enforced** or report-only? *(§4.)*
2. How many devices are **`unknown`**, not merely non-compliant?
3. How many report **compliant** but have not synced in 30 days?
4. What is the compliance **grace period**?
5. Is BYOD handled by **MDM or app protection**? *(§3.)*
6. If MAM: does CA require *approved client app* rather than *compliant device*?
7. Is **Defender for Endpoint risk** feeding compliance? *(§5.)*
8. Are there **break-glass exclusions** from device-based policies?
9. ⭐ What would actually happen to a non-compliant device that tried to open SharePoint right now?

---

## 8. Remember it

**Hook — "Intune assesses. Conditional Access enforces."**

**Analogy — the MOT certificate and the police.** ⭐ **Intune is the garage that inspects the car and
writes down "fails".** ⭐ **That piece of paper stops nobody driving.** Only a check at the roadside
turns the assessment into an outcome — and Conditional Access is the roadside check. ⭐ **A country
with excellent inspections and no enforcement has very good statistics about the unsafe cars on its
roads.**

**The one thing:** ⭐ **a non-compliant device is not blocked from anything until a Conditional Access
policy says so.** The Intune console showing "412 non-compliant" is a report, and every one of those
412 is accessing mail and files normally unless a CA policy requiring compliance is **enabled** rather
than report-only. **Check the CA policy state, not the compliance dashboard** — and this is the fifth
product in which this repo has found the same *deployed-is-not-enforced* gap, which is why it is worth
carrying as a habit rather than a fact.

**Runner-up:** ⭐ **use app protection, not enrolment, for BYOD** — a control users reject produces
workarounds worse than the risk.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. ⭐ What does Intune produce, and what turns it into an outcome?
2. Name the three states and say which one stops anything.
3. What does `enabledForReportingButNotEnforced` mean in practice?
4. ⭐ Why is `unknown` compliance worse than non-compliant?
5. Why does a stale device's "compliant" status mislead?
6. Distinguish MDM from MAM on four axes.
7. ⭐ Why is MAM the right BYOD answer, and which principle does that follow?
8. Which CA grant control must you use with MAM, and what happens if you use the wrong one?
9. What is the grace period, and why does it matter?
10. ⭐ Describe the EDR-to-access containment chain.

<details>
<summary>Answers</summary>

1. ⭐ **A compliance assessment (a signal).** ⭐ **A Conditional Access policy** requiring compliance
   turns it into an outcome.
2. **Enrolled, assessed (compliant/non-compliant), ⭐ enforced.** ⭐ Only **enforced** stops anything.
3. ⭐ **Report-only** — the policy evaluates and logs but does not block. Correct as a first step, poor
   as a permanent state.
4. ⭐ Because the device has ⭐ **not been evaluated at all** — it hides between the two columns of a
   compliance report while CA treats it as non-compliant.
5. Compliance is a ⭐ **cached assessment**; a device that last synced months ago asserts a fact about
   a machine nobody has seen since.
6. **Scope** (device vs ⭐ app data), **BYOD acceptance** (poor vs ⭐ high), **wipe** (device vs ⭐ app
   data only), **enforces** (device config vs ⭐ copy/paste, save-as, PIN — and **no compliance
   signal**).
7. ⭐ Because **a control users reject produces workarounds worse than the risk** — the same principle
   as sanctioned AI over banning AI and governed guest access over open federation.
8. ⭐ **Require approved client app / app protection policy.** Requiring *compliant device* ⭐ **locks
   MAM-managed BYOD out**, and grant controls default to AND.
9. The ⭐ **remediation window** before a failing device is marked non-compliant — during it the device
   reports compliant, which is the real gap.
10. ⭐ **Defender for Endpoint risk → Intune compliance → Conditional Access → access removed** — the
    closest thing M365 has to autonomous containment, and it is configuration, not a purchase.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — the §4 three queries: compliance distribution including `unknown`, CA policies
  requiring compliance **and their state**, and stale devices. ⚠ Requires Intune licensing —
  **currently blocked pending EMS E5**, so the CA-policy query is the runnable half today.
- **`break-fix/`** ⭐ — mark a test device non-compliant and **access SharePoint successfully**; then
  switch the CA policy from report-only to enabled and watch the same access fail. ⭐ **That before/
  after is the entire §2 argument and it changes how a team reads its own dashboard.**
- **`security/`** — CA policies requiring compliance with their **state**; `unknown` and stale device
  counts; grace period values; BYOD approach and the matching grant control; Defender-to-compliance
  integration status.
- **`operations/`** — stale device cleanup; compliance exception process with expiry; break-glass
  exclusions verified.
- **`architecture-decisions/`** — ADR: app protection for BYOD with the ⭐ acceptability argument
  recorded; device risk feeds compliance feeds Conditional Access.
- **`customer-use-cases/`** — §7 answered; "your 412 non-compliant devices are accessing everything"
  as the opening finding.
