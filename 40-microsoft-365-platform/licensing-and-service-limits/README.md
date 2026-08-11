# Licensing and Service Limits

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **In Microsoft 365, licensing is a security control** — a feature you are not licensed for does
> not exist, no matter how correctly you configure it.
> ⚠ **SKU contents change constantly. Verify against current licensing documentation before advising
> anyone.**

---

## 1. ⭐ Why this is a security topic, not a procurement one

**In Azure, you deploy what you need and pay for consumption. ⭐ In Microsoft 365, capability is
gated by SKU — and the gate is silent.**

```
⭐ You design a control  →  configure it  →  ⭐ it does not apply to unlicensed users
                                              ⭐ often with NO error
```

⭐ **The failure mode is the dangerous one: partial application.** A Conditional Access policy
requiring a P2-only feature does not fail loudly — **it applies to the licensed users and silently
does not apply to the rest.** The policy exists, the report looks reasonable, and coverage is
incomplete in a way no dashboard states.

> ⭐ **So "is this licensed for everyone it targets?" is a design-review question**, and it belongs
> next to "is it enforced?" from
> [`../intune-and-device-management/`](../intune-and-device-management/) §2. **Two questions, both
> about whether a configured control actually applies.**

---

## 2. ⭐ The security capabilities most often assumed and not held

⚠ **Indicative only — SKU contents move. Verify current entitlements.**

| Capability | ⭐ Typically requires |
|---|---|
| ⭐ **Conditional Access** | Entra ID **P1** |
| ⭐ **Identity Protection** (risk policies) | ⭐ Entra ID **P2** |
| ⭐ **PIM** | ⭐ Entra ID **P2** |
| **Access reviews / entitlement management** | Entra ID **P2 / Governance** |
| **Intune MDM + MAM** | Intune plan / EMS |
| **Defender for Endpoint P2** | ⭐ M365 E5 / E5 Security — ⚠ *not* EMS E5 |
| **Defender for Cloud Apps** | E5 / EMS E5 |
| **Defender for Identity** | E5 / EMS E5 |
| ⭐ **Extended audit retention & `MailItemsAccessed`** | ⭐ E5 / add-on |
| **Insider Risk, Communication Compliance** | E5 compliance |
| **Sensitivity labels — auto-labelling** | ⭐ E5 (manual labelling is broader) |

⭐ **Two traps worth naming explicitly:**

1. ⭐ **EMS E5 is not M365 E5.** EMS E5 brings Entra ID P2, Intune, Defender for Cloud Apps and
   Defender for Identity — ⭐ **but not Defender for Endpoint P2**, which needs M365 E5 or E5 Security.
   **Estates routinely assume "we have E5" means all of it.**
2. ⭐ **Audit retention and `MailItemsAccessed` are licence-gated**
   ([`../exchange-online/`](../exchange-online/) §5). **The investigation you cannot run is decided by
   a purchasing decision made years earlier** — and nobody connects the two at incident time.

---

## 3. Worked example — do the licences cover the design?

```powershell
Connect-MgGraph -Scopes 'Organization.Read.All','User.Read.All','Directory.Read.All'

# ① What do we actually own, and how much is unassigned?
Get-MgSubscribedSku |
  Select-Object SkuPartNumber,
    @{n='Enabled';e={$_.PrepaidUnits.Enabled}},
    @{n='Assigned';e={$_.ConsumedUnits}},
    @{n='Spare';e={$_.PrepaidUnits.Enabled - $_.ConsumedUnits}} |
  Sort-Object Spare -Descending
```

```
SkuPartNumber                 Enabled  Assigned  Spare
----------------------------  -------  --------  -----
ENTERPRISEPREMIUM_NOPSTNCONF      500       471     29
EMS                                 0         0      0   <-- ⚠⚠ ⭐ nothing licensed
```

⭐ **A zero row is the finding**, and it is the exact position this repository is written from: an
E5-class SKU without the EMS entitlements means **Entra ID P2, PIM, Identity Protection and Intune are
not merely unconfigured — they cannot be configured.**

```powershell
# ② ⭐ The question that matters: are the users your policy TARGETS licensed for it?
$p2Plans = 'AAD_PREMIUM_P2'      # ⚠ verify current service plan names

$targets = Get-MgGroupMember -GroupId <targetedGroupId> -All
$unlicensed = foreach ($m in $targets) {
  $u = Get-MgUser -UserId $m.Id -Property UserPrincipalName,AssignedPlans -EA SilentlyContinue
  $has = @($u.AssignedPlans | Where-Object { $_.ServicePlanId -and $_.CapabilityStatus -eq 'Enabled' })
  # ⭐ resolve service plan names via Get-MgSubscribedSku; simplified here
  [pscustomobject]@{ User = $u.UserPrincipalName; PlanCount = $has.Count }
}
$unlicensed | Where-Object PlanCount -eq 0 | Select-Object -First 20
```

⭐ **This is the gap analysis nobody runs.** A CA policy targeting "All users" in a tenant where 300 of
4,000 people hold a lower SKU is **a control with a 7.5% hole that no report will ever describe as
one.**

```powershell
# ③ ⭐ Group-based licensing errors - silent, and they mean people have NOTHING
Get-MgGroup -All -Property Id,DisplayName,AssignedLicenses |
  Where-Object { $_.AssignedLicenses } | ForEach-Object {
    $errs = Get-MgGroup -GroupId $_.Id -Property LicenseProcessingState,AssignedLicenses -EA SilentlyContinue
    [pscustomobject]@{ Group=$_.DisplayName; State=$errs.LicenseProcessingState.State }
  } | Where-Object State -ne 'ProcessingComplete'
```

⭐ **Group-based licensing is the right pattern** — licence follows group membership follows role — ⚠
**and its failures are silent.** A licence conflict or insufficient count leaves users **unlicensed
while the group looks correctly configured**, and the symptom appears as a feature not working for
some people.

---

## 4. Service limits that behave like security controls

| Limit | ⭐ Security reading |
|---|---|
| ⭐ **Recipient rate limit** (per mailbox / hour) | ⭐ caps a compromised mailbox's spam blast |
| **Mailbox size / archive** | archive behaviour affects eDiscovery scope |
| ⭐ **Unified audit log retention** | ⭐ your investigation window, set by SKU |
| **SharePoint list view threshold** | breaks poorly designed permission structures |
| ⭐ **Entra service principal / app limits** | sprawl hits a ceiling and deployments fail oddly |
| **Teams membership limits** | large teams degrade before they fail |

⭐ **The recipient rate limit is the free containment control** from
[`../mail-flow-and-hygiene/`](../mail-flow-and-hygiene/) §4 — **a platform limit doing the work of a
detection.** It is the same argument as Azure quota
([`../../20-azure-platform/budgets-and-cost-controls/`](../../20-azure-platform/budgets-and-cost-controls/) §2):
⭐ **a ceiling converts an unbounded incident into a bounded one, and costs nothing.**

---

## 5. ⭐ Designing when you cannot buy the licence

**This is the real skill, and it is what a consultant is actually paid for:**

| Not available | ⭐ Compensating approach |
|---|---|
| PIM (P2) | ⭐ separate admin accounts + access reviews + alerting on role assignment writes |
| Identity Protection (P2) | ⭐ sign-in log detections in Sentinel / KQL |
| Defender for Endpoint P2 | ⭐ Defender Antivirus + ASR rules + baseline hardening |
| Extended audit retention | ⭐ **export the audit log to your own storage** |
| Auto-labelling | manual labelling + mandatory container labels |

⭐ **"Export the audit log" is the highest-value compensating control on that list**, because it
converts a licence-gated retention window into a storage decision you control
([`../../20-azure-platform/azure-resource-manager/`](../../20-azure-platform/azure-resource-manager/) §3).

> ⭐ **Never present "you need E5" as the whole answer.** It is true, it is unhelpful, and it is what
> a salesperson says. **The engineer's answer is: here is the control, here is the gap, here is what
> we do until the licence exists, and here is what specifically is still uncovered.**

---

## 6. What breaks

**Assuming a configured control applies to everyone.** §1 — ⭐ silent partial application.

**"We have E5" without checking which E5.** §2 — ⭐ EMS E5 ≠ M365 E5.

**Assuming Defender for Endpoint P2 comes with EMS E5.** §2.

**Discovering audit retention limits during an incident.** §2 — ⭐ decided years earlier.

**Not checking whether policy targets are licensed.** §3 — ⭐ a hole no report describes.

**Group-based licensing errors unmonitored.** §3 — ⭐ silent, and users end up unlicensed.

**Ignoring service limits.** §4 — ⭐ free containment left unused.

**Presenting "buy E5" as the answer.** §5 — ⭐ that is a sales answer, not an engineering one.

**Trusting a SKU comparison from memory.** ⚠ These move constantly — verify.

**Licences assigned per user rather than by group.** Unreviewable and drifts from role.

---

## 7. Customer discovery questions

1. Exactly **which SKUs** are owned, and how many are **unassigned**? *(§3.)*
2. ⭐ Are the users your **CA policies target** licensed for what those policies require? *(§3.)*
3. Is licensing **group-based**, and does anyone watch for **processing errors**? *(§3.)*
4. What is your **audit log retention**, and does it match what an investigation would need? *(§2.)*
5. Is **`MailItemsAccessed`** available to you?
6. Do you have **EMS E5 or M365 E5** — and does the team know the difference? *(§2.)*
7. Which security designs are **blocked by licensing**, and what compensates today? *(§5.)*
8. Are **recipient rate limits** understood as containment? *(§4.)*

---

## 8. Remember it

**Hook — "Unlicensed means it doesn't exist — silently."**

**Analogy — a sprinkler system plumbed into only half the building.** ⭐ **The design is correct, the
drawings show full coverage, the control panel reports normal** — and the east wing was never
connected because that part of the contract was not signed. ⭐ **Nothing alarms, because a sprinkler
that was never installed does not report a fault.** The only way to know is to compare the design
against the contract, room by room — which is precisely §3 ②.

**The one thing:** ⭐ **check that the users a policy targets are licensed for what it requires.** A
Conditional Access policy scoped to "All users" in a mixed-licence tenant applies to the licensed
subset and silently does not apply to the rest — **no error, no warning, and a coverage report that
looks complete.** It is one query, it is never run, and it is the difference between a control and a
control with a hole in it whose size nobody knows.

**Runner-up:** ⭐ **EMS E5 is not M365 E5** — Entra P2 and Intune yes, **Defender for Endpoint P2 no**.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. ⭐ Why is licensing a security control in M365 but not in Azure?
2. What is the dangerous failure mode, and why is it dangerous?
3. ⭐ What does EMS E5 include, and what does it notably not?
4. Which two investigation capabilities are licence-gated, and why does that matter at incident time?
5. ⭐ Which query does nobody run, and what does it reveal?
6. Why is group-based licensing right, and what is its silent failure?
7. Name two service limits that act as security controls.
8. ⭐ What is the single best compensating control for licence-gated audit retention?
9. Give compensating approaches for missing PIM and missing Identity Protection.
10. ⭐ Why is "you need E5" the wrong answer to give a customer?

<details>
<summary>Answers</summary>

1. ⭐ In Azure you **deploy and pay for consumption**; in M365 ⭐ **capability is gated by SKU**, so an
   unlicensed feature does not exist regardless of configuration.
2. ⭐ **Silent partial application** — the control applies to licensed users and not to the rest, with
   **no error**, so coverage is incomplete in a way no dashboard states.
3. ⭐ Entra ID **P2**, Intune, Defender for Cloud Apps, Defender for Identity. ⭐ **Not Defender for
   Endpoint P2**, which needs M365 E5 / E5 Security.
4. ⭐ **Extended audit retention** and ⭐ **`MailItemsAccessed`** — so what you can investigate was
   decided by a purchasing decision years earlier.
5. ⭐ **"Are the users this policy targets licensed for what it requires?"** — it reveals the
   percentage hole in a control that reports as complete.
6. Licence follows **group membership follows role** — reviewable. ⚠ Its failures are ⭐ **silent**:
   conflicts or insufficient counts leave users unlicensed while the group looks correct.
7. ⭐ **Recipient rate limits** (cap a compromised mailbox) and ⭐ **audit log retention** (the
   investigation window). Also service principal/app ceilings.
8. ⭐ **Export the audit log to your own storage** — it converts a licence-gated window into a storage
   decision you control.
9. **PIM** → separate admin accounts, access reviews, alert on role-assignment writes.
   **Identity Protection** → sign-in log detections in Sentinel/KQL.
10. ⭐ It is **a sales answer**. The engineering answer states the control, the gap, the compensating
    measure available today, and ⭐ **what specifically remains uncovered**.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — the §3 SKU inventory and the ⭐ **policy-target licence gap analysis**. **Runnable
  today on the current E5 licence** — and the SKU query already produces a finding in this tenant.
- **`break-fix/`** ⭐ — target a Conditional Access policy at a mixed-licence group, then show it
  applying to some members and **silently not applying to others** with no error anywhere. ⭐ **The
  absence of an error is the lesson** — nothing else demonstrates §1 as clearly.
- **`security/`** — SKU inventory with spare counts; ⭐ policy-target licence coverage per CA policy;
  audit retention versus investigation requirement; group-based licensing error monitoring.
- **`operations/`** — licence assignment by group tied to role; alerting on licensing processing
  errors; ⭐ audit log export to owned storage.
- **`architecture-decisions/`** — ADR: controls blocked by licensing, ⭐ **with the compensating
  measure and the residual gap both stated** — not "we need E5".
- **`customer-use-cases/`** — §7 answered; the licence-gap analysis presented as a coverage percentage
  rather than a shopping list.
