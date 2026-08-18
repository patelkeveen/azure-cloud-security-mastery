# Financial Services and Banking

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **Boundary:** [`../LAYER-7-INDUSTRY-VERTICALS.md`](../LAYER-7-INDUSTRY-VERTICALS.md) §2 is the
> two-page brief. ⭐ **This is engagement depth: the regulation-to-evidence chain worked end to end
> for one control.** Pairs with
> [`../../30-identity-and-nhi/pim-and-access-reviews/`](../../30-identity-and-nhi/pim-and-access-reviews/).

---

## 1. What it is

Identity and access engineering for regulated financial institutions — banks, payment processors,
insurers, fintechs — where the deliverable is not a working configuration but ⭐ **evidence that an
assessor will accept**, retained for years.

⭐ **In every other vertical the config is the product. Here the *audit trail* is the product, and
the config merely produces it.**

---

## 2. Why it is different

| Ordinary customer | ⭐ Financial services |
|---|---|
| "Is MFA on?" | ⭐ **"Prove it was on last March, for that user, on that system"** |
| Admin access controlled | ⭐ **who approved each elevation, and were they independent?** |
| 30-day log retention | ⭐ **years** — ⭐ and defaults are a **finding** |
| Roles model job function | ⭐ **entitlements must be provably incompatible** |
| Change went fine | ⭐ change went through a documented control |

⭐ **The regulator's question is always past tense.** A control that is correct today but cannot be
evidenced for the audit period has failed the only test that matters — ⭐ **and log retention is
unrecoverable retroactively**, which makes it the single highest-priority week-one check.

---

## 3. How it works underneath — the translation chain, worked

⭐ **Only the customer supplies links 1–2. You own 3–5.** Insisting on that boundary is what stops
you promising compliance you cannot verify.

```
① REGULATION            ⭐ customer names it. You do not interpret law.
   e.g. SOX ITGC access controls · PCI-DSS Req 7/8/10 · DORA · RBI · FCA · OSFI

② CONTROL OBJECTIVE     ⭐ customer's compliance team states it
   "Privileged access is granted only with independent approval and is time-bound"

③ TECHNICAL REQUIREMENT ⭐ YOURS
   "No standing Directory role assignments. Activation requires approval by a
    person who cannot themselves perform the activity, max 4 hours, justification recorded."

④ ENTRA FEATURE         ⭐ YOURS
   PIM eligible assignment + approver group + authentication context
   requiring phishing-resistant strength + protected actions on policy deletion

⑤ ⭐ EVIDENCE ARTIFACT   ⭐ YOURS - ⭐ THE DELIVERABLE
   PIM activation history export · access review results with decisions
   · CA policy JSON at a point in time · retention proof
```

⭐ **Most vendors jump from ① to ④ — regulation straight to product demo.** ⭐ **Writing ② and ③ down
explicitly, and making the customer own ②, is what a senior consultant does differently**, and it is
also your defence when the assessor disagrees with the compliance team.

---

## 4. Worked example — segregation of duties, and why roles cannot express it

**The requirement:** *"No individual may both submit and approve a payment."*

⭐ **The instinct — build a custom directory role — is wrong, and understanding why is the whole
lesson.**

```
⭐ WHY DIRECTORY ROLES CANNOT DO THIS

Directory roles grant permissions over DIRECTORY OBJECTS
  (create user, reset password, edit CA policy)

⭐ The SoD conflict is between BUSINESS ENTITLEMENTS
  (access to the payment submission app vs the approval app)

⭐ These live in different planes. A directory role has no opinion
   about your payments system.
```

**The mechanism that does work — incompatible access packages:**

```powershell
# Two packages representing the conflicting business entitlements
#   AP-Payments-Submit   → group GRP-APP-Payments-Submitters
#   AP-Payments-Approve  → group GRP-APP-Payments-Approvers

# ⭐ Declare them mutually exclusive. Enforced AT REQUEST TIME.
New-MgEntitlementManagementAccessPackageIncompatibleAccessPackageByRef `
  -AccessPackageId $submitPkgId `
  -BodyParameter @{ "@odata.id" =
    "https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/accessPackages/$approvePkgId" }
```

⭐ **What the requester now sees when they already hold the other package:**

```
You can't request this access package because you have incompatible access.
Remove the following before requesting: ⭐ "AP-Payments-Approve"
```

⭐ **Enforced at request time, by the platform, with a record** — rather than by a quarterly
spreadsheet review that finds the violation three months after it happened.

⭐ **And the retrospective check, which is what the auditor actually asks for:**

```powershell
# ⭐ Who currently holds BOTH? Should be zero, and you must be able to show it.
$sub = @(Get-MgGroupMember -GroupId $submitGroupId -All).Id
$app = @(Get-MgGroupMember -GroupId $approveGroupId -All).Id
$both = @($sub | Where-Object { $_ -in $app })
"SoD violations: $($both.Count)"
$both | ForEach-Object { (Get-MgUser -UserId $_).UserPrincipalName }
```

```
SoD violations: 0
```

⭐ **`SoD violations: 0`, dated and exported monthly, is an evidence artifact.** ⭐ **A statement that
the packages are configured as incompatible is not** — the assessor wants the outcome, not the
intent.

⚠ `⚠ check` — Graph cmdlet and endpoint names for entitlement management incompatibility have
changed between module versions; verify against the module in front of you.

---

## 5. Retention — the finding you will discover in week one

⭐ **This is where financial-services engagements most often begin, because the gap is large and the
fix is urgent.**

| Log | Entra default retention | ⭐ Typical regulated requirement |
|---|---|---|
| Sign-in logs | ⭐ **7 days** (Free) / **30 days** (P1/P2) | ⭐ **1–7 years** |
| Audit logs | 7 / 30 days | 1–7 years |
| PIM activation history | ⭐ within the audit log window | ⭐ the auditor's favourite question |

⚠ `⚠ check` — verify current default retention per licence tier before quoting; these have changed.

```powershell
# ⭐ Is anything being exported at all?  ⭐ If not, the clock has not started.
Get-MgBetaAuditLogSignIn -Top 1 | Out-Null   # confirms access
Get-AzDiagnosticSetting -ResourceId `
  "/providers/microsoft.aadiam/diagnosticSettings" -ErrorAction SilentlyContinue |
  Select-Object Name, @{n='Logs';e={($_.Log | Where-Object Enabled).Category -join ','}}
```

```
Name          Logs
(no output)   ⭐ ← THE FINDING
```

⭐ **No diagnostic setting means sign-in history older than the default window does not exist and
cannot be recovered.** ⭐ **Report it on day one, in writing, with the date** — because from that
moment the gap is a known, dated, accepted risk rather than something you failed to notice.

⭐ **PCI-DSS is worth knowing by number** because it is the most commonly cited and the most
specific:

| Requirement | Substance |
|---|---|
| **Req 7** | ⭐ least privilege, need-to-know |
| **Req 8** | ⭐ identify and authenticate — ⭐ **MFA for all access into the cardholder data environment** |
| **Req 10** | ⭐ log and monitor — ⭐ **retain audit history, with a recent window immediately available** |

⚠ `⚠ check` — PCI DSS v4.x requirement numbering, the exact retention period and future-dated
requirement deadlines must be read from the current standard. ⭐ **Never quote a PCI clause from
memory to a customer** — cite the document.

⭐ **India-specific and directly relevant if you are selling here:** ⭐ **RBI's payment-system data
localisation direction requires payment data to be stored within India**, which constrains tenant
region, Log Analytics workspace region and any third-party processor. ⚠ Verify current scope and
wording; ⭐ **but knowing to *ask* the localisation question first is what marks you out in an Indian
BFSI conversation.**

---

## 6. The reference design

| Control | Setting | ⭐ Why this vertical |
|---|---|---|
| PIM | ⭐ eligible only; ⭐ **approval + justification**; ≤ 4 h | independent approval is the control objective |
| Authentication context | ⭐ phishing-resistant on elevation | ⭐ elevation is the audited moment |
| Protected actions | ⭐ on **deleting a CA policy** | ⭐ stops an admin disabling the evidence trail |
| Access reviews | ⭐ quarterly, **auto-apply ON**, ⭐ no-response = Remove | ⭐ a review with no applied result is not a control |
| Entitlement management | incompatible packages | SoD, §4 |
| Diagnostics | ⭐ export to Log Analytics **and** immutable storage | retention |
| Break-glass | 2 accounts, ⭐ **quarterly tested**, alerted on sign-in | ⭐ auditors ask about this specifically |

⭐ **"Auto-apply ON, no-response = Remove" is the row that separates a real access review from
theatre.** ⭐ **A review where managers do not respond and nothing is removed produced a report and
changed nothing** — and an assessor who understands the product will ask exactly that.

---

## 7. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| ⭐ Auditor cannot be answered about last March | ⭐ no diagnostic export | ⭐ unrecoverable; ⭐ report and start the clock |
| SoD "implemented" but violated | expressed as directory roles | ⭐ incompatible access packages |
| Access reviews complete, ⭐ nothing removed | auto-apply off | ⭐ turn it on; no-response = Remove |
| ⭐ Admin deleted a CA policy | no protected action | ⭐ require step-up on the deletion itself |
| Elevation approved by the requester's own report | ⭐ approver group not independent | ⭐ independence is a **design** decision |
| Emergency change bypassed everything | no post-hoc control | ⭐ retrospective approval + review |

⭐ **"Approved by their own direct report" is a real and common finding**, and it is invisible in the
product — PIM will happily accept it. ⭐ **Independence is something you design into the approver
group and then evidence**, not something the platform enforces for you.

---

## 8. Customer discovery questions

1. ⭐ **"When your auditor asks who approved a privileged elevation last March, what do you show
   them?"**
2. "Which frameworks apply, and who in your organisation owns the interpretation?"
3. ⭐ **"How long must authentication records be retained, and where are they today?"**
4. "Which pairs of entitlements must never be held by the same person?"
5. ⭐ **"Is there a data-residency or localisation requirement?"** (⭐ ask first in India/EU)
6. "Who approves privileged elevation, and are they independent of the requester?"
7. ⭐ **"When were break-glass accounts last tested, and is there a record?"**

---

## 9. Remember it

**Hook — `R C T F E`: Regulation → Control objective → Technical requirement → Feature → Evidence.**
⭐ **The customer owns the first two; you own the last three; the last one is the deliverable.**

**Analogy — a restaurant kitchen inspection.** ⭐ **The inspector does not watch you cook. They read
the temperature log, check it was signed, and ask who checked it on the 14th.** The analogy predicts
everything here: ⭐ **a spotless kitchen with no log fails**, ⭐ **the log must be contemporaneous and
cannot be written afterwards**, and ⭐ **the person who signs must not be the person who cooked** —
which is segregation of duties, exactly.

**The one line:** ⭐ **The evidence artifact is the deliverable, and retention gaps cannot be fixed
retroactively.**

---

## 10. Self-test

1. Which links of the translation chain do you own?
   → ⭐ Technical requirement, Entra feature, evidence artifact. The customer owns regulation and control objective.
2. Why can't directory roles express segregation of duties?
   → ⭐ The conflict is between business entitlements, not directory permissions — different planes.
3. What enforces SoD at request time?
   → ⭐ Incompatible access packages in entitlement management.
4. Which gap is unrecoverable, and when must you find it?
   → ⭐ Log retention — week one. History that was never exported does not exist.
5. What makes an access review a control rather than a report?
   → ⭐ Auto-apply on, and no-response = Remove.
6. Why put a protected action on deleting a CA policy?
   → ⭐ It stops an admin disabling the evidence trail without step-up.
7. What does PIM not enforce that you must design?
   → ⭐ Approver independence.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | incompatible access packages configured, with the request-time rejection captured |
| `security` | ⭐ the SoD violation query, dated, returning zero |
| `operations` | ⭐ diagnostic export configured, with the start date recorded |
| `customer-use-cases` | ⭐ one control traced through all five chain links |
| `architecture-decisions` | the approver-independence design, and the retention decision |
