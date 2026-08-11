# Posture Management

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> The discipline, across the whole stack. Product depth in
> [`../defender-for-cloud/`](../defender-for-cloud/); the graph in
> [`../attack-path-analysis/`](../attack-path-analysis/).
> **SC-200 and SC-500** — see [`CERT-MAP.md`](../../CERT-MAP.md).

---

## 1. What it is

Continuously measuring **how your environment is configured** against a standard, and closing the
gap — as opposed to detecting attacks, which is what everything else in this domain does.

```
Posture   "is this configured safely?"      ← before anything happens
Detection "is something happening now?"     ← during
Response  "how do we get them out?"         ← after
```

Posture is the only one of the three that reduces the number of incidents rather than shortening them.

---

## 2. ⭐ Three different things are called "secure score"

The most common confusion in Microsoft security, and getting it wrong in a customer meeting is
memorable for the wrong reason.

| Score | Where | Measures |
|---|---|---|
| **Microsoft Secure Score** | Defender portal (XDR) | **M365**: identity, devices, apps, data |
| **Secure Score in Defender for Cloud** | Azure / Defender portal | ⭐ **Azure, AWS, GCP resources** |
| **Identity Secure Score** | Entra admin centre | Identity configuration specifically |

They are **different products with overlapping names and no shared number**. A customer saying "our
secure score is 64%" has told you almost nothing until you ask which one.

> **Ask "which secure score, and against which standard?"** That single clarifying question marks
> you out immediately — most people nod and carry on.

---

## 3. How it works underneath

Every posture product runs the same loop:

```
STANDARD          MCSB, CIS, NIST 800-53, PCI DSS, your own baseline
    │
    ▼
ASSESSMENT        continuously evaluate every resource against every control
    │
    ▼
RECOMMENDATION    per-resource pass/fail, weighted
    │
    ▼
SCORE             a proxy for aggregate posture
    │
    ▼
REMEDIATION       owner, date, verification    ← the step that is usually missing
```

**The standard is the part people skip.** A recommendation is not an opinion — it is a **control
failure traceable to a named benchmark**. Microsoft's default is **MCSB** (Microsoft cloud security
benchmark), mapped to CIS, NIST and PCI DSS across Azure, AWS and GCP.

**Weighting is why the score moves unintuitively.** Controls carry different point values, and each
control is scored on the *proportion* of healthy resources. Remediating 400 resources under a
1-point control barely moves the number; fixing 14 under a 10-point control moves it a lot.

---

## 4. Worked example — turning a score into a plan

```bash
# Where are the points actually being lost?
az security secure-score-control list \
  --query "sort_by([].{Control:displayName, Current:score.current, Max:score.max, Unhealthy:unhealthyResourceCount}, &Max)[::-1]" -o table
```

```
Control                                    Current  Max  Unhealthy
-----------------------------------------  -------  ---  ---------
Enable MFA                                       0   10         14
Secure management ports                          2    8         31
Remediate vulnerabilities                        3    6        127
Apply system updates                             1    6         89
Encrypt data in transit                          4    4          0
```

**The plan writes itself once sorted by `Max`:**

| Rank | Control | Gain | Effort | Verdict |
|---:|---|---:|---|---|
| 1 | Enable MFA | **+10** | 14 accounts | ⭐ Do first — smallest effort, largest gain |
| 2 | Secure management ports | +6 | 31 NSG rules | Do second; JIT access solves it wholesale |
| 3 | Remediate vulnerabilities | +3 | **127 resources** | Longest list, **least gain per hour** |

> ⭐ **The longest list is almost never the best first move.** Teams gravitate to
> "Remediate vulnerabilities" because 127 feels urgent. Fourteen MFA registrations are worth more
> than three times as much score and take an afternoon.

**Now make it real** — a backlog with owners, not a dashboard:

```bash
az security assessment list \
  --query "[?status.code=='Unhealthy'].{Control:displayName, Resource:resourceDetails.id}" -o tsv \
  > posture-backlog.tsv
```

**Governance rules** (Defender CSPM, paid) automate exactly this: assign a recommendation to the
resource owner, set a grace period, and track it. Without them, remediation depends on someone
manually chasing — which is why scores plateau.

---

## 5. Exemptions and drift — the two things that decide whether this works

**Exemptions.** Some findings are genuinely accepted risk or false positives. An exemption must
carry **who approved it, why, and when it expires**. An exemption without an expiry is not a risk
decision — it is a permanent blind spot with paperwork.

```
✅  "Storage account st-legacy-01 exempt from 'require HTTPS' until 2026-11-30.
     Approved: J. Okafor (CISO). Reason: vendor appliance pending replacement, ticket CH-4821."

✗   "Exempted — false positive."
```

**Drift is the real enemy.** A remediated resource becomes non-compliant again the moment a pipeline
redeploys it from an unfixed template.

```
Fix the RESOURCE    →  compliant today, non-compliant at the next deployment
Fix the TEMPLATE    →  ⭐ compliant permanently, and for every future resource
Enforce with POLICY →  non-compliant resources cannot be created at all
```

**Azure Policy with `Deny` is the only durable answer.** Posture management tells you what is wrong;
Policy stops it recurring. A programme that only remediates is running up a down escalator — and the
score will sit flat forever while everyone works hard.

⚠ Use `Audit` before `Deny` — the "watch first" pattern in [`RETENTION.md`](../../RETENTION.md) §3b.
A `Deny` policy deployed without auditing blocks legitimate deployments on day one.

---

## 6. What breaks

**Confusing the three secure scores.** §2.

**Chasing the score instead of the risk.** A tenant can score 85% and still have one internet-facing
VM with an Owner-privileged managed identity. See [`../attack-path-analysis/`](../attack-path-analysis/).

**Remediating by list length.** §4.

**Exemptions with no expiry or approver.**

**Fixing resources, not templates.** Drift returns everything to baseline-fail.

**No owner per recommendation.** Findings that belong to everyone belong to nobody.

**Deploying `Deny` policies without `Audit` first.** Broken pipelines and a reputation for obstruction.

**Comparing scores between tenants.** Different resource mixes and standards make the numbers
non-comparable. Track **your own** trend instead.

**Treating a point-in-time report as posture.** Posture is a trend line, not a screenshot.

---

## 7. Customer discovery questions

1. **Which** secure score are you quoting, and against which standard?
2. What was the score six months ago? *(Trend beats absolute value.)*
3. Are recommendations assigned to **owners with dates**, or reviewed ad hoc?
4. How many exemptions exist, who approved them, and how many have **expired**?
5. Are fixes pushed back into **IaC templates**?
6. Is Azure Policy used in `Deny` mode anywhere, or only `Audit`?
7. Which regulatory standard is the customer audited against, and is it loaded?
8. Is AWS/GCP posture measured too, or only Azure?
9. Who is accountable for the score — a named person, or "security"?

---

## 8. Remember it

**Hook — "Which secure score?"** There are three. And: **standard → assessment → recommendation →
score → remediation**, where the last step is the one that is missing.

**Analogy — a health check, not a diagnosis.** A secure score is a **cholesterol number**: useful as
a trend for one person, meaningless compared between two people, and it tells you nothing about the
tumour. **Attack path analysis is the scan that finds the tumour.** Optimising the score while
ignoring the paths is treating the number instead of the patient.

**The one thing:** **fix the template, not the resource** — and enforce with Azure Policy `Deny`
(after `Audit`). Remediation alone is running up a down escalator: the pipeline recreates the
misconfiguration faster than people can close tickets, and the score sits flat while everyone works hard.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Name the three "secure scores" and what each measures.
2. Why sort controls by `Max` rather than by unhealthy resource count?
3. What three things must an exemption record?
4. Why does a score plateau even when a team remediates constantly?
5. What is the only durable fix for drift?
6. Why must `Deny` policies be preceded by `Audit`?
7. Why is comparing scores between two tenants meaningless?
8. What does posture management not tell you, and which feature fills that gap?
9. What does MCSB give you beyond a recommendation list?

<details>
<summary>Answers</summary>

1. **Microsoft Secure Score** (M365 — identity, devices, apps, data), **Secure Score in Defender for
   Cloud** (Azure/AWS/GCP resources), **Identity Secure Score** (Entra identity config).
2. The score is **weighted** — a 10-point control with 14 unhealthy resources beats a 1-point
   control with 400.
3. **Who approved it, why, and when it expires.**
4. **Drift.** Pipelines redeploy from unfixed templates as fast as tickets are closed.
5. Fix the **IaC template** and enforce with **Azure Policy `Deny`**.
6. `Deny` without auditing blocks legitimate deployments immediately — the "watch first" pattern.
7. Different resource mixes and standards. Track **your own trend** instead.
8. **Reachability and consequence** — a high score can coexist with a live internet-to-data path.
   **Attack path analysis** fills it.
9. **Traceability to a named benchmark** mapped to CIS/NIST/PCI across Azure, AWS and GCP — so
   findings are control failures, not opinions.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — capture the §4 control table, build the weighted plan, and re-measure after
  remediating the top control. ✗ Requires an Azure subscription.
- **`break-fix/`** ⭐ — remediate a resource, then redeploy from the original IaC template and watch
  it go non-compliant again. Then fix the template and prove it stays. **Drift demonstrated in ten
  minutes.**
- **`security/`** — exemption register with approver, reason and expiry; expired exemptions flagged.
- **`operations/`** — score trend over time with owners per control; governance rules configured.
- **`architecture-decisions/`** — ADR: which policies move from `Audit` to `Deny`, and the audit
  evidence behind each.
- **`customer-use-cases/`** — §7 answered, plus the §4 plan delivered as a prioritised backlog.
