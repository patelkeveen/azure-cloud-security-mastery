# Security Baselines

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> How "secure by default" actually gets implemented. Measured by
> [`../posture-management/`](../posture-management/); enforced with Azure Policy and Intune.

---

## 1. What it is

A **pre-defined set of security configuration settings**, published by a vendor or standards body,
that you apply as a unit rather than deciding several hundred settings yourself.

```
Benchmark   what SHOULD be configured        CIS, MCSB, NIST, DISA STIG
Baseline    a deployable implementation      Intune security baseline, Azure Policy initiative
Drift       what is ACTUALLY configured now  ← the only number that matters
```

**Baselines are opinions with defaults.** Their value is that someone competent already had the
argument about each setting, and you inherit the conclusion.

---

## 2. Why they exist

Windows exposes thousands of security-relevant settings. Azure exposes hundreds per resource type.
Nobody can reason about all of them, so in practice organisations either:

- configure the dozen they have heard of and leave the rest at vendor defaults, or
- copy a hardening guide from the internet, apply it wholesale, and break production

**A baseline is the middle path**: a curated, tested set with a stated rationale, versioned, and
deployable as one object.

> ⭐ **The real value is not the settings — it is that a baseline makes drift measurable.** Without
> a declared target, "is this server hardened?" has no answer. With one, it is a number you can
> trend. That reframing is what turns hardening from an argument into a metric.

---

## 3. The baselines you will actually meet

| Baseline | Applies to | Delivered by |
|---|---|---|
| **Microsoft cloud security benchmark (MCSB)** | Azure, AWS, GCP resources | Defender for Cloud (default standard) |
| **CIS Benchmarks** | OS, cloud, containers | Independent (CIS); levels **1** and **2** |
| **Intune security baselines** | Windows, Edge, Defender | Intune configuration profiles |
| **Azure Policy initiatives** | Azure resources | Policy, with `Audit` or `Deny` |
| **DISA STIG** | Government/defence | Highly prescriptive |

**CIS Level 1 versus Level 2 is the distinction worth knowing:**

- **Level 1** — sensible security with minimal functional impact. A reasonable default almost anywhere.
- **Level 2** — defence-in-depth for high-security environments. **Expect functional breakage** and
  budget for testing.

> Proposing CIS **Level 2** across a general corporate estate is a common inexperience tell. It is
> correct for a regulated enclave and disruptive nearly everywhere else. Being able to say *"Level 1
> as standard, Level 2 for the cardholder-data segment"* is the answer that lands.

---

## 4. Worked example — deploy without breaking production

The pattern is identical to everything else in this domain, and by now it should feel automatic:

```
1. MEASURE   assess against the baseline BEFORE changing anything
2. AUDIT     deploy in Audit / report-only
3. ANALYSE   which settings would break which systems?
4. EXCEPT    document deviations with owner, reason, expiry
5. ENFORCE   move to Deny / apply, in rings
6. MONITOR   drift is continuous, not a project
```

**Step 1 — measure first, using what is already free:**

```bash
# Which built-in initiatives are assigned, and what is compliance?
az policy assignment list --query "[].{Name:displayName, Scope:scope, Enforcement:enforcementMode}" -o table
az policy state summarize --query "value[0].results.{NonCompliant:nonCompliantResources, Total:resourceDetails[0].totalResources}" -o json
```

```
Name                                    Scope                          Enforcement
--------------------------------------  -----------------------------  -----------
Microsoft cloud security benchmark      /subscriptions/xxxx            Default
CIS Microsoft Azure Foundations v2.0.0  /subscriptions/xxxx            DoNotEnforce
```

⭐ **`enforcementMode: DoNotEnforce` is audit mode.** A customer saying "we apply CIS" while every
assignment reads `DoNotEnforce` is *measuring* CIS, not applying it. That single field settles the
question and it is the first thing to check.

**Step 2 — see what would actually break:**

```bash
az policy state list --filter "complianceState eq 'NonCompliant'" \
  --query "value[].{Policy:policyDefinitionName, Resource:resourceId}" -o tsv | \
  cut -f1 | sort | uniq -c | sort -rn | head -20
```

The high-count policies are where enforcement will hurt. **Investigate those before switching to
`Deny`.**

**Step 3 — enforce in rings**, never estate-wide at once:

```
Ring 0  IT team devices / a sandbox subscription    1 week
Ring 1  a tolerant business unit                    2 weeks
Ring 2  general estate
Ring 3  ⚠ exceptions and legacy — may never move, and that must be a decision, not a drift
```

---

## 5. Exceptions — the part that determines credibility

Every baseline meets systems that genuinely cannot comply: a vendor appliance, an OT controller, a
legacy application. **Refusing to grant exceptions does not produce compliance — it produces
shadow IT and a baseline everyone ignores.**

An exception must record:

```
✅  Setting        : Require TLS 1.2 minimum
    System         : app-legacy-03
    Reason         : Vendor client supports TLS 1.0 only; replacement in FY27 budget
    Compensating   : Isolated VLAN, no internet route, traffic inspected at the gateway
    Approved by    : J. Okafor (CISO)          Expires: 2027-03-31
    Review         : quarterly
```

> **An exception without an expiry is not an exception — it is a silent revision of the baseline.**
> The register of expired exceptions is one of the fastest findings available in any assessment, and
> it is nearly always non-empty.

**Baselines are versioned, and versions matter.** When Microsoft or CIS publishes a new revision,
settings are added, removed and changed. **Adopting a new version is a change project**, not a
refresh — and estates commonly sit three versions behind while reporting "we are CIS aligned."

---

## 6. What breaks

**Applying a baseline without measuring first.** You cannot tell what you broke.

**Enforcing estate-wide with no rings.** One bad setting, everyone affected, simultaneously.

**CIS Level 2 by default.** Functional breakage and a lost mandate.

**Exceptions with no expiry.** The baseline silently erodes.

**Never adopting new versions.** "CIS aligned" against a benchmark from three revisions ago.

**Confusing benchmark with baseline.** The benchmark is the standard; the baseline is the
implementation. Customers use the words interchangeably — you should not.

**Assuming `DoNotEnforce` means enforced.** §4.

**No drift monitoring.** Baselines decay: an admin changes a setting to fix an outage and nobody
reverts it.

**Baseline conflicts.** An Intune baseline and a GPO both setting the same value produces
non-deterministic results. ⚠ Migrate rather than overlay, and check for overlap explicitly.

---

## 7. Customer discovery questions

1. Which benchmark is the declared standard, and **which version**?
2. Are Policy assignments in `Default` or **`DoNotEnforce`**? *(Ask for the output, not the answer.)*
3. Is CIS **Level 1 or Level 2**, and was that a deliberate choice?
4. How many exceptions exist, and how many have **expired**?
5. Was the baseline deployed in **rings**?
6. Who monitors **drift**, and how often?
7. Are Intune baselines and GPO both configuring the same settings anywhere?
8. When did the baseline version last get reviewed against the current publication?
9. Which systems are permanently exempt, and is that written down as a decision?

---

## 8. Remember it

**Hook — "Measure, audit, except, enforce, monitor."** And: **`DoNotEnforce` means audit.**

**Analogy — a building code, not a builder.** The **benchmark** is the building code; the
**baseline** is the standard set of drawings that satisfies it; **drift** is what the building
actually looks like after ten years of tenants knocking through walls. Codes get revised, and a
building compliant in 2019 is not automatically compliant now — which is why version currency, not
initial deployment, is the real work.

**The one thing:** **a baseline's value is that it makes drift measurable.** Without a declared
target, "is this hardened?" has no answer; with one, it is a number you can trend. And an
**exception without an expiry is a silent revision of the baseline** — the expired-exception
register is nearly always the fastest finding in an assessment.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Difference between a benchmark, a baseline, and drift?
2. What does `enforcementMode: DoNotEnforce` mean, and why does it matter in a customer conversation?
3. CIS Level 1 versus Level 2 — when is each appropriate?
4. Five things an exception record must contain?
5. Why deploy in rings?
6. Why is adopting a new baseline version a project rather than a refresh?
7. What happens when an Intune baseline and a GPO configure the same setting?
8. Why is refusing all exceptions counterproductive?
9. What is the fastest finding available in a baseline assessment?

<details>
<summary>Answers</summary>

1. **Benchmark** = the standard (CIS, MCSB). **Baseline** = a deployable implementation of it.
   **Drift** = actual current configuration versus the declared target.
2. **Audit mode** — evaluated but not enforced. A customer claiming to "apply CIS" with every
   assignment on `DoNotEnforce` is measuring it, not applying it.
3. **Level 1** for general estates — sensible security, minimal functional impact. **Level 2** for
   high-security enclaves; expect breakage and budget testing.
4. **Setting, system, reason, compensating control, approver — and an expiry date** (plus a review
   cadence).
5. To limit blast radius. One bad setting applied estate-wide affects everyone at once.
6. Settings are added, removed and changed between versions, so it requires re-testing and re-exception.
7. **Non-deterministic results.** Migrate rather than overlay, and check for overlapping settings.
8. It produces **shadow IT and a baseline everyone ignores**, which is worse than a documented,
   time-bounded deviation.
9. **Expired exceptions.** The register is nearly always non-empty.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — assign an MCSB or CIS initiative in audit mode, capture the compliance summary, then
  enforce one policy in `Deny` and prove a non-compliant deployment is blocked. ✗ Requires an Azure
  subscription.
- **`break-fix/`** ⭐ — apply a `Deny` policy without auditing first and break a legitimate
  deployment; recover via a scoped exemption. **The "watch first" lesson, learned once.**
- **`security/`** — exception register with expiries, and expired entries flagged; baseline version
  currency against the current publication.
- **`operations/`** — ring deployment plan; drift monitoring cadence and owner.
- **`architecture-decisions/`** — ADR: chosen benchmark and level, with the rationale for Level 1
  versus Level 2 per environment.
- **`customer-use-cases/`** — §7 answered with real `az policy assignment list` output attached.
