# Security Automation

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> The final topic in this domain, and the one that determines whether the other thirteen scale.
> Builds on [`../sentinel/`](../sentinel/) §5 and [`../incident-response/`](../incident-response/).

---

## 1. What it is

Making the response to a security event happen **without a human**, or with a human only at the
decision point.

Three tiers, and conflating them is where automation programmes fail:

| Tier | Does | Risk if wrong |
|---|---|---|
| **Enrichment** | Adds context — who owns this device, is this IP known bad | ⭐ **None.** Read-only |
| **Orchestration** | Routes, tickets, notifies, assigns | Low — noise |
| **Remediation** | ⭐ **Disables accounts, isolates devices, blocks IPs** | **High — self-inflicted outage** |

---

## 2. Why it exists — and the honest limit

Analyst time is the binding constraint in every SOC. An analyst spends most of an investigation
**gathering context that a machine could have attached to the alert**: who owns this device, is this
user privileged, has this IP appeared before, what else did this account do.

**Enrichment alone can halve time-to-triage and carries no risk at all.** That is where the return
is, and it is where most programmes never start because remediation is more exciting.

> ⭐ **The limit worth stating out loud: automation multiplies whatever your detection quality
> already is.** Automate a 95%-precision detection and you save time. Automate a 60%-precision
> detection and you have built a machine for disabling innocent users at scale. **Precision is the
> prerequisite, not the automation.**

---

## 3. How it works underneath — where automation lives in Azure

| Mechanism | Where | Use for |
|---|---|---|
| **Automation rules** | Sentinel | Cheap, no-code: assign, tag, change severity, close known FPs |
| **Playbooks (Logic Apps)** | Sentinel / Defender | Real actions and integrations |
| **Workflow automation** | Defender for Cloud | Trigger on recommendations and alerts |
| **Automated investigation & response** | Defender XDR | Microsoft's own triage and remediation |
| **Attack disruption** | Defender XDR | ⭐ Autonomous containment mid-attack |
| **Azure Automation / Functions** | Azure | Scheduled hygiene, custom logic |
| **Azure Policy `DeployIfNotExists`** | Azure | ⭐ Remediating configuration automatically |

**Start with automation rules, not playbooks.** A rule that closes a known false positive or assigns
by severity costs nothing, breaks nothing, and removes measurable analyst load on day one.

**`DeployIfNotExists` deserves particular attention** — it is automation that fixes posture rather
than responding to alerts. Diagnostic settings missing on a new resource? Policy deploys them. That
closes the [`../sentinel/`](../sentinel/) §6 blind spot — *logs silently not arriving* — permanently,
rather than by someone noticing.

---

## 4. Worked example — a playbook that earns trust

**Design it as enrichment first, with remediation gated behind a human.**

```
TRIGGER: Sentinel incident created, severity High, entity = user account
   │
   ├─ ENRICH  (no risk, always runs)
   │    ├─ Graph: is this user privileged? PIM-eligible? recently changed MFA?
   │    ├─ MDI:   any identity alerts for this account in 7 days?
   │    ├─ TI:    is the source IP known bad?
   │    └─ HR:    is this account within its notice period?
   │
   ├─ COMMENT the enrichment back onto the incident   ⭐ the analyst now starts warm
   │
   ├─ IF privileged AND known-bad IP AND MDI alert:
   │       └─ POST to Teams with an ADAPTIVE CARD:
   │             "Revoke sessions and disable priya@contoso.com?  [Approve] [Reject]"
   │                     │
   │                     └─ on Approve → Revoke-MgUserSignInSession, disable, comment back
   │
   └─ ELSE: assign to the on-call analyst, tag, stop
```

**Why this shape and not full automation:**

- **Enrichment always runs.** Zero risk, immediate value, and it builds the case for more.
- **Remediation requires approval.** The adaptive card takes the analyst ten seconds and preserves
  accountability — a human made the decision, and there is a record of who.
- **The condition is deliberately narrow.** Three independent signals must agree. That is what keeps
  precision high enough to justify acting at all.

**Graduate to unattended remediation only when you have the numbers:**

```
Track per playbook:  times triggered · times approved · times rejected
   → rejection rate consistently ~0 over a meaningful sample
       → THEN consider removing the approval step for that specific condition
```

⭐ **That is the promotion criterion, and it is evidence-based rather than confidence-based.** "We
have approved this 200 times and rejected it twice" is an argument. "The detection is good" is not.

**Measure it, or the criterion is decorative:**

```kusto
// Playbook outcomes - the numbers that justify expanding or retiring automation
SecurityIncident
| where TimeGenerated > ago(90d)
| where Labels has "auto-remediation-proposed"
| extend Outcome = case(
      Comments has "Approved by",  "approved",
      Comments has "Rejected by",  "rejected",
                                   "no response")
| summarize Count = count() by Outcome, bin(TimeGenerated, 7d)
| render timechart
```

⚠ Tagging incidents from the playbook is what makes this queryable — the label and comment format
above are a convention you must set deliberately, not something that exists by default.

---

### Posture remediation — the higher-volume, lower-risk win

`DeployIfNotExists` fixes configuration automatically instead of raising a ticket. This one closes
the [`../sentinel/`](../sentinel/) §6 blind spot permanently — diagnostic settings that were never
enabled, so logs silently never arrived:

```json
{
  "if": {
    "field": "type",
    "equals": "Microsoft.KeyVault/vaults"
  },
  "then": {
    "effect": "deployIfNotExists",
    "details": {
      "type": "Microsoft.Insights/diagnosticSettings",
      "existenceCondition": {
        "allOf": [
          { "field": "Microsoft.Insights/diagnosticSettings/logs.enabled", "equals": "true" },
          { "field": "Microsoft.Insights/diagnosticSettings/workspaceId", "equals": "[parameters('workspaceId')]" }
        ]
      },
      "roleDefinitionIds": [
        "/providers/Microsoft.Authorization/roleDefinitions/749f88d5-cbae-40b8-bcfc-e573ddc772fa"
      ],
      "deployment": { "properties": { "mode": "incremental", "template": { "...": "..." } } }
    }
  }
}
```

**Two things to notice, because both are exam-relevant and interview-relevant:**

1. **`roleDefinitionIds`** — the policy needs a **managed identity** with permission to deploy. Same
   §5 principle: this is a standing privilege you are creating, so scope it deliberately.
2. **`existenceCondition`** — defines what "already compliant" means. Get it wrong and the policy
   redeploys endlessly, or never fires at all.

Remediate what already exists with a remediation task:

```bash
az policy remediation create --name fix-kv-diag \
  --policy-assignment <assignmentId> --resource-discovery-mode ExistingNonCompliant
```

---

## 5. The identity of the automation is a Tier 0 asset

The point almost nobody raises, and it is the strongest thing you can say in a review.

A playbook that can disable accounts and isolate devices runs as a **managed identity or a stored
connection with standing permissions**. Therefore:

```
Whoever can EDIT the Logic App can make it do anything that identity can do.
```

That is **remote account disablement and device isolation across the estate**, available to anyone
with Contributor on the resource group. Consequences:

- Playbook edit rights are **Tier 0** — the same tier as domain controllers and AD FS signing keys
- The managed identity must hold **least privilege**, not Owner "to make it work"
- Changes to playbooks belong in **source control with review**, not the portal
- ⚠ **Attack disruption and AIR are Microsoft-operated automation with real containment power** —
  know what they are authorised to do in a given tenant before an incident, not during one

> **This is the automation expression of the "two identities" pattern** in
> [`RETENTION.md`](../../RETENTION.md) §3b: the playbook is a **separate principal** with its own
> permissions, and nothing you do to user accounts governs it.

---

## 6. What breaks

**Automating remediation on a noisy detection.** Mass account disablement from a bad rule. The
organisation will withdraw the mandate, and it will not come back.

**No approval gate on high-impact actions**, before precision is proven.

**Over-privileged playbook identity.** Owner "to make it work" is a standing compromise.

**Playbooks edited in the portal.** No review, no history, no rollback.

**No failure handling.** The playbook errors halfway, having disabled the account but not notified
anyone — worse than no automation.

**Automating around a broken process.** If ticket assignment is unclear, automating it just routes
faster to the same confusion.

**No metrics.** Without trigger/approve/reject counts there is no basis to expand or retire anything.

**Forgetting `DeployIfNotExists`.** Teams automate response and leave posture remediation manual,
which is the higher-volume, lower-risk win.

**Ignoring what Microsoft's own automation already does**, then being surprised when a device
self-isolates.

---

## 7. Customer discovery questions

1. What is automated today — enrichment, orchestration, or remediation?
2. Do any playbooks take **destructive actions unattended**? On which detections, and what is their
   precision?
3. What identity do playbooks run as, and **what permissions does it hold**?
4. **Who can edit playbooks**, and is that treated as Tier 0?
5. Are playbooks in **source control** with review?
6. Are trigger/approve/reject counts tracked per playbook?
7. Is **attack disruption** enabled, and does the team know what it can do autonomously?
8. Is `DeployIfNotExists` used for posture remediation, or is that all manual?
9. What happens when a playbook fails halfway?

---

## 8. Remember it

**Hook — "Enrich, orchestrate, remediate"** — in that order, and **earn** each step.

**Analogy — a junior analyst you are training.** You would not hand a new starter the power to
disable executive accounts on day one. You would have them **gather context and write it up**
(enrichment), then **route and prioritise** (orchestration), and only after months of watching their
judgement would you let them **act alone** (remediation). Automation deserves exactly the same
probation — and the promotion criterion is the same: a track record you can point to.

**The one thing:** **the playbook is a separate identity with standing power.** Whoever can edit the
Logic App inherits remote account-disablement and device-isolation across the estate — so edit
rights are **Tier 0**, and the managed identity gets least privilege, not Owner. Almost nobody
raises this, which is exactly why raising it lands.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Three tiers of automation, and which carries no risk?
2. Why does automation multiply detection quality rather than substitute for it?
3. Why start with automation rules rather than playbooks?
4. What shape should a first high-impact playbook take?
5. What is the evidence-based criterion for removing an approval gate?
6. Why are playbook edit rights Tier 0?
7. What does `DeployIfNotExists` automate, and why is it under-used?
8. What is worse than no automation?
9. Which Microsoft-operated automation can contain autonomously?

<details>
<summary>Answers</summary>

1. **Enrichment** (no risk, read-only), **orchestration** (low risk), **remediation** (high risk).
2. It applies the detection's decision at machine speed. A 60%-precision detection automated becomes
   a machine for disabling innocent users at scale.
3. They are **no-code, zero-risk** and remove measurable analyst load immediately — assign, tag,
   close known false positives.
4. **Enrichment always runs; remediation is gated behind an approval** (e.g. a Teams adaptive card),
   with a deliberately narrow multi-signal condition.
5. A tracked record of **triggers, approvals and rejections** showing a rejection rate near zero over
   a meaningful sample.
6. The playbook identity can **disable accounts and isolate devices**. Whoever edits it inherits that.
7. **Posture remediation** — e.g. deploying missing diagnostic settings automatically. Under-used
   because teams focus on incident response, though this is higher-volume and lower-risk.
8. A playbook that **fails halfway** — account disabled, nobody notified.
9. **Attack disruption** and **automated investigation and response** in Defender XDR.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — build the §4 playbook: enrichment always, remediation behind a Teams approval card.
  Capture the enriched incident comment. ✗ Requires Sentinel and a tenant with alerts.
- **`break-fix/`** ⭐ — run an unattended remediation playbook against a deliberately noisy
  detection in a lab and watch it disable a legitimate test account. **Then rebuild it with the
  approval gate.** The cheapest possible way to learn this lesson.
- **`security/`** — playbook identity permissions reviewed for least privilege; edit rights treated
  as Tier 0 with membership documented; attack disruption scope understood and recorded.
- **`operations/`** — per-playbook trigger/approve/reject metrics; failure handling and alerting on
  playbook errors.
- **`architecture-decisions/`** — ADR: what automation may do unattended, and the precision evidence
  required to promote an action from gated to unattended.
- **`customer-use-cases/`** — §7 answered against a real SOC.
