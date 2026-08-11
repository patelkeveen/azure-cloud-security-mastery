# Entitlement Management

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (licensing updated 2026-07-30).
> **SC-300 Domain 4.** Depth in
> **[LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md](../pim-and-access-reviews/LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md)**.

---

## 1. What it is

**Access packages**: a bundle of resources — groups, applications, SharePoint sites — that people
**request**, an approver **grants**, and which **expires** on its own.

```
CATALOG          a container of resources, with its own owners
  └─ ACCESS PACKAGE      groups + apps + SharePoint sites, bundled by job need
       └─ POLICY         WHO may request · WHO approves · HOW LONG it lasts
```

⭐ **The policy is the product.** Anyone can put resources in a bundle; the value is that access
**arrives with an expiry date attached**.

---

## 2. Why it exists

Access accumulates. A person moves teams and keeps the old group. A project ends and nobody removes
anyone. Six years later they hold access to eleven systems they cannot name.

Access reviews *detect* that after the fact. **Entitlement management prevents it**, because access
was time-bounded when granted and nobody has to remember anything.

> ⭐ **The design insight: make the correct behaviour automatic rather than diligent.** A control
> that depends on someone remembering is not a control — it is a hope with a spreadsheet.

**And it is the right answer for guests**, who otherwise accumulate forever — see
[`../external-identities/`](../external-identities/) §6.

---

## 3. ⚠ The licensing boundary — verified, and it matters ✅

**Core entitlement management is P2. A large amount of what people assume is included requires the
separate Microsoft Entra ID Governance SKU.**

| Capability | P2 | **ID Governance** |
|---|:---:|:---:|
| Access packages: groups, apps, SharePoint sites | ✅ | ✅ |
| Users request for themselves; admin direct assignment | ✅ | ✅ |
| Multi-stage approval, specific approvers, managers as approvers | ✅ | ✅ |
| Separation of duties (incompatible packages) | ✅ | ✅ |
| Expiration of assignments | ✅ | ✅ |
| Conditional Access scoping | ✅ | ✅ |
| ⭐ **Auto-assignment policies** | ✗ | **✅** |
| ⭐ **Custom extensions (Logic Apps)** | ✗ | **✅** |
| ⭐ **Managers requesting on behalf of employees** | ✗ | **✅** |
| ⭐ **Entra roles in access packages** (preview) | ✗ | **✅** |
| **PIM for Groups eligibility in packages** | ✗ | **✅** |
| Verified ID / ID Protection / Insider Risk integration | ✗ | **✅** |
| **Mark guest as governed** | ✗ | **✅** |

> ⭐ ✅ **"No new Identity Governance features or capabilities will be added to the Microsoft Entra ID
> P2 SKU."** P2 is frozen for governance. Everything new lands in **ID Governance** or the
> **Entra Suite** — which makes "we have P2" an increasingly incomplete answer.

---

## 4. ⭐ Licence counting — the mistake that appears in proposals ✅

**You license everyone who *can* request, not everyone who *does*.**

| Scenario | Licences |
|---|---:|
| Policy says **All employees (2,000)** may request; **150 actually request** | ⭐ **2,000** |
| Auto-assignment policy grants **Sales (350)** access | **351** (+1 admin) |

**That first row is the trap.** Scoping a policy to "All employees" for convenience licenses the
whole company. **Scope requestor policies to the population that genuinely needs the package.**

⚠ Guest governance uses **MAU billing and requires an Azure subscription** — a separate model again.

---

## 5. Worked example — a joiner package that expires itself

```powershell
Connect-MgGraph -Scopes 'EntitlementManagement.ReadWrite.All'

# 1. Catalog — the container, with its own owners
New-MgEntitlementManagementCatalog -DisplayName 'Finance' `
  -Description 'Finance systems' -IsExternallySelectable:$false

# 2. Access package
New-MgEntitlementManagementAccessPackage -DisplayName 'Finance Analyst' `
  -Description 'Standard access for a finance analyst' `
  -CatalogId '<catalogId>'
```

**The policy is where the governance lives:**

```powershell
$params = @{
  DisplayName = 'Finance Analyst - internal'
  AccessPackageId = '<accessPackageId>'
  RequestorSettings = @{ ScopeType = 'SpecificDirectorySubjects'; AcceptRequests = $true }   # ⭐ NOT AllMembers
  RequestApprovalSettings = @{
      IsApprovalRequired = $true
      ApprovalMode = 'Serial'
      ApprovalStages = @(@{ ApprovalStageTimeOutInDays = 7
                            IsApproverJustificationRequired = $true
                            PrimaryApprovers = @(@{ '@odata.type' = '#microsoft.graph.requestorManager' }) })
  }
  AccessReviewSettings = @{ IsEnabled = $true; RecurrenceType = 'quarterly'; ReviewerType = 'Manager'
                            DurationInDays = 14 }
  DurationInDays = 180                     # ⭐ access EXPIRES
}
New-MgEntitlementManagementAccessPackageAssignmentPolicy -BodyParameter $params
```

⭐ **Three settings do all the work:** `DurationInDays` (it ends), `IsApprovalRequired` with the
**requestor's manager** as approver (someone accountable decides), and a recurring **access review**
(it is re-justified). Everything else is packaging.

**Audit what already exists:**

```powershell
Get-MgEntitlementManagementAccessPackage -All -ExpandProperty AssignmentPolicies |
  ForEach-Object {
    foreach ($p in $_.AssignmentPolicies) {
      [pscustomobject]@{
        Package  = $_.DisplayName
        Policy   = $p.DisplayName
        Expires  = if ($p.DurationInDays) { "$($p.DurationInDays)d" } else { 'NEVER' }
        Approval = $p.RequestApprovalSettings.IsApprovalRequired
      }
    }
  } | Sort-Object Expires
```

```
Package             Policy                Expires  Approval
------------------  --------------------  -------  --------
Contractor Access   External requestors   NEVER    False      <-- ⚠⚠
Finance Analyst     Internal              180d     True
```

⭐ **`Expires: NEVER` with `Approval: False` on a package named "Contractor Access"** is the finding.
The tool designed to time-bound access has been configured to grant it permanently, unreviewed.

---

## 6. Separation of duties

Mark two access packages **incompatible** and someone holding one cannot request the other — a
genuine SoD control, enforced at request time.

```
"Submit Payments"  ⟺  "Approve Payments"     incompatible
```

⭐ **This is one of very few places Entra enforces SoD natively**, and it is a strong answer to an
audit question most organisations answer with a spreadsheet.

---

## 7. What breaks

**Scoping requestor policies to "All employees" for convenience.** §4 — licenses the whole company.

**Packages with `DurationInDays` unset.** §5 — the entire point is lost.

**No approval, or self-approval.** A request nobody assesses is a self-service permission grant.

**Assuming P2 covers everything.** §3 — auto-assignment, custom extensions and manager-on-behalf
requests are **ID Governance**.

**Forgetting guest MAU billing** needs an Azure subscription.

**Catalogs with no owners.** The delegation model collapses back onto central IT.

**Building packages around org chart instead of job need.** Reorganisations then invalidate everything.

**Ignoring separation of duties** when the customer is audited on exactly that.

---

## 8. Customer discovery questions

1. Are there access packages, and do **all** of them have an expiry?
2. Any package with **no approval required**?
3. How are requestor policies scoped? *(§4 — is the whole company licensed unnecessarily?)*
4. Is **ID Governance** licensed, or only P2? Which capabilities are being assumed?
5. Are **guests** governed by packages, and is MAU billing configured?
6. Is **separation of duties** configured anywhere?
7. Do catalogs have **owners**, or does IT own everything?
8. Are recurring **access reviews** attached to packages?

---

## 9. Remember it

**Hook — "Catalog → package → policy,"** and **the policy is the product**.

**Analogy — a library, not a locksmith.** Traditional access management is a locksmith cutting keys
on request; nobody ever asks for them back. Entitlement management is a **library**: you borrow a
bundle of books, someone signs it out, **it has a due date**, and you get a reminder to renew or
return. **The due date — `DurationInDays` — is the entire innovation.** A library with no due dates
is just a room where books go missing.

**The one thing:** ⭐ **you license everyone who *can* request, not everyone who does.** Scoping a
policy to "All employees" for convenience licenses the entire company. And ✅ **P2 is frozen for
governance** — auto-assignment, custom extensions and manager-on-behalf all require the separate
**ID Governance** SKU.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 10. Self-test

1. What are the three layers, and which one carries the governance?
2. How are entitlement management licences counted?
3. A policy lets 2,000 employees request; 150 do. How many licences?
4. Name three capabilities that need ID Governance rather than P2.
5. What is Microsoft's stated position on new governance features in P2?
6. Which three policy settings make a package actually govern?
7. What does an access package with `Expires: NEVER` and no approval tell you?
8. How does entitlement management enforce separation of duties?
9. What extra requirement applies to governing guests?

<details>
<summary>Answers</summary>

1. **Catalog → access package → policy.** **The policy** — who may request, who approves, how long.
2. By everyone **in scope to request**, not by actual requesters.
3. **2,000.**
4. **Auto-assignment policies**, **custom extensions (Logic Apps)**, **managers requesting on behalf**
   (also Entra roles in packages, PIM for Groups eligibility, Verified ID / ID Protection integration).
5. ✅ **No new IGA features will be added to P2** — everything new lands in ID Governance or the
   Entra Suite.
6. **`DurationInDays`** (expiry), **approval by an accountable person**, and a recurring
   **access review**.
7. The tool for time-bounding access has been configured to grant it **permanently and unreviewed** —
   a finding, especially on a contractor package.
8. **Incompatible access packages** — holding one blocks requesting the other, enforced at request time.
9. **MAU billing**, which **requires an Azure subscription**.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — build the §5 package with expiry, manager approval and a quarterly review; request it
  as a test user and watch the approval land. ✗ **Requires P2 (ID Governance for the advanced parts).**
- **`break-fix/`** ⭐ — create a package with **no expiry**, assign it, and demonstrate that access
  persists indefinitely. Then add `DurationInDays` and watch it lapse.
- **`security/`** — the §5 audit of packages without expiry or approval; separation-of-duties pairs
  configured; catalog ownership.
- **`operations/`** — requestor scoping reviewed against licence counting; guest MAU billing configured.
- **`architecture-decisions/`** — ADR: package design by **job need** rather than org chart, and the
  P2-versus-ID-Governance decision with the capability list that drives it.
- **`customer-use-cases/`** — §8 answered; a contractor onboarding package as a deliverable.
