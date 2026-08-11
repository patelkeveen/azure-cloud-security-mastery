# Microsoft Sentinel

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> The SIEM/SOAR layer. Hard prerequisite: [`../kql/`](../kql/) — Sentinel *is* KQL with a workflow
> around it.

---

## 1. What it is

A cloud-native **SIEM** (collect, correlate, alert) and **SOAR** (automate the response) built on a
Log Analytics workspace.

Strip the marketing and Sentinel is four things:

```
CONNECT  →  DETECT  →  INVESTIGATE  →  RESPOND
data        analytics    incidents      playbooks
connectors  rules (KQL)  + entities     (Logic Apps)
```

Everything you do in the product is one of those four.

---

## 2. Why it exists — and the cost model that shapes every design

Traditional SIEMs were licensed and sized by **hardware**, so the instinct was to collect everything
and worry later. Sentinel is billed by **gigabytes ingested**, which inverts the incentive.

> ⭐ **In Sentinel, "collect everything" is not thoroughness — it is a budget failure.** The design
> question is *"what would I actually query, and to answer which question?"* An engineer who can
> justify each connector by the detections it enables is worth more than one who enables all of them.

This is why the tiering model matters:

| Tier | Use | Trade-off |
|---|---|---|
| **Analytics** | Detections, frequent hunting | Full price, full query |
| **Basic / Auxiliary** | High-volume, low-value (firewall, proxy) | Much cheaper, **limited query**, short retention |
| **Archive** | Compliance retention | Cheapest; needs a **search job** to access |

⚠ Tier names, retention limits and pricing have changed more than once. Verify current options
before designing a retention plan — but the *principle* (match tier to how you will actually use the
data) is stable.

**The cost trap:** verbose sources — firewall, proxy, DNS — dominate ingestion and are rarely the
basis of a detection. Put them in a cheap tier, keep identity and endpoint telemetry in Analytics.

---

## 3. How it works underneath

### Analytics rules — the four kinds

| Type | What it does |
|---|---|
| **Scheduled** | Runs a KQL query on a schedule. The workhorse — you write these. |
| **Microsoft Security** | Promotes alerts from Defender products into Sentinel incidents |
| **Fusion** | ⭐ ML correlation across signals — **cannot be tuned**, low volume, high fidelity |
| **Anomaly** | Behavioural baselines, tunable thresholds |

### Entity mapping — the step people skip, and the one that makes Sentinel useful

An alert that says *"8 failed sign-ins then a success"* is a row of text. An alert with **entities
mapped** — account, IP, host — becomes clickable, correlatable, and can be grouped with other alerts
about the same account.

```yaml
entityMappings:
  - entityType: Account
    fieldMappings:
      - identifier: FullName
        columnName: UserPrincipalName
  - entityType: IP
    fieldMappings:
      - identifier: Address
        columnName: SourceIP
```

> ⭐ **Without entity mapping there is no investigation graph, no UEBA correlation, and playbooks
> have nothing to act on.** It is a few lines of configuration that determines whether the whole
> platform works, and it is the most common thing missing in a mediocre deployment.

### Incident grouping

Rules can create one incident per alert, or group alerts within a time window by matching entities.
**Group by entity**, or a password spray against 400 accounts creates 400 incidents and buries the
analyst — the classic way a SOC drowns in its own tooling.

---

## 4. Worked example — a complete analytics rule

The detection from [`../kql/`](../kql/) §4, turned into a production rule:

```yaml
id: 5f2c9d10-3a7b-4e21-9c88-b1d4e6f70a33
name: Password spray followed by successful sign-in
severity: High
queryFrequency: 1h          # how often it runs
queryPeriod: 24h            # how far back it looks   <-- period >= frequency, always
triggerOperator: gt
triggerThreshold: 0
tactics: [CredentialAccess]
techniques: [T1110.003]     # ⭐ MITRE - password spraying
query: |
  let window = 1h;
  let failThreshold = 8;
  SigninLogs
  | where TimeGenerated > ago(24h)
  | where ResultType in ("50126", "50053")
  | summarize Failures = count(), LastFail = max(TimeGenerated),
              SourceIPs = make_set(IPAddress, 10)
          by UserPrincipalName
  | where Failures >= failThreshold
  | join kind=inner (
      SigninLogs
      | where TimeGenerated > ago(24h)
      | where ResultType == 0
      | summarize SuccessTime = min(TimeGenerated), SuccessIP = any(IPAddress)
              by UserPrincipalName
  ) on UserPrincipalName
  | where SuccessTime between (LastFail .. LastFail + window)
  | where not(SuccessIP in (SourceIPs))
entityMappings:
  - entityType: Account
    fieldMappings: [{ identifier: FullName, columnName: UserPrincipalName }]
  - entityType: IP
    fieldMappings: [{ identifier: Address, columnName: SuccessIP }]
incidentConfiguration:
  createIncident: true
  groupingConfiguration:
    enabled: true
    lookbackDuration: 4h
    matchingMethod: AllEntities        # group by account+IP, not one incident per alert
```

**Three details that make this production-grade rather than a demo:**

1. **`queryPeriod` ≥ `queryFrequency`**, with overlap. If the rule runs hourly but only looks back
   an hour, events landing late are **never evaluated** — a silent detection gap that nobody notices
   because the rule reports healthy.
2. **MITRE `tactics`/`techniques`** — drives coverage reporting. "Which ATT&CK techniques can we
   actually detect?" is a board-level question and this field is what answers it.
3. **Grouping** — turns a 400-account spray into one incident.

---

## 5. Automation — SOAR without the danger

**Automation rules** are the cheap, safe layer: change severity, assign an owner, add a tag, close
known false positives. No code.

**Playbooks** are Logic Apps and can act — disable an account, revoke sessions, isolate a device,
post to Teams, open a ticket.

```
Incident created
   └─ Automation rule: severity == High and entity is a privileged account
        └─ Playbook:
             1. Post to the SOC Teams channel with the entity details
             2. Revoke-MgUserSignInSession for the account
             3. Create a ServiceNow ticket
             4. Comment the ticket number back onto the incident
```

> ⭐ **Start automation with enrichment and notification, not remediation.** A playbook that
> disables accounts is one bad detection away from an outage of its own making — and the first
> false positive it acts on will end the organisation's appetite for automation entirely. Earn
> trust with read-only actions, measure the false-positive rate, then escalate.

**The playbook identity is a real attack surface.** It runs as a managed identity or a connection
with standing permissions to disable users and isolate devices. Whoever can edit the Logic App
inherits that power. Treat playbook edit rights as **Tier 0** — this is the finding almost nobody
raises.

---

## 6. What breaks

**`queryPeriod` shorter than `queryFrequency`.** Silent detection gap; the rule looks healthy.

**No entity mapping.** No investigation graph, no correlation, playbooks have nothing to act on.

**No incident grouping.** One spray produces hundreds of incidents.

**Ingesting everything.** Cost explosion, usually driven by one verbose connector nobody queries.

**Data connector silently stopped.** ⭐ Nothing alerts you that logs *stopped arriving* — the
absence of alerts looks identical to a quiet week. Build a rule that fires when a critical table
has **no** rows:

```kusto
let expected = dynamic(["SigninLogs","AuditLogs","AADServicePrincipalSignInLogs","SecurityEvent"]);
union withsource=TableName *
| where TimeGenerated > ago(2h)
| summarize Rows = count() by TableName
| where TableName in (expected)
| join kind=rightanti (
    print TableName = expected | mv-expand TableName to typeof(string)
  ) on TableName
```

**That query is the most important rule in the workspace and almost nobody writes it.**

**Timezone confusion.** `TimeGenerated` is UTC; incident timelines drift.

**Rules never tuned.** Analysts mute noisy rules instead of fixing them, and the muted rule is the
one that eventually matters.

---

## 7. Customer discovery questions

1. What is monthly ingestion, and **which table dominates**?
2. Are verbose sources in a cheaper tier, or all in Analytics?
3. Do rules have **entity mappings** and **MITRE technique** tags?
4. Is `queryPeriod` ≥ `queryFrequency` on every scheduled rule? *(Check — it is often wrong.)*
5. Is there a rule detecting a **connector that stopped sending data**?
6. Do playbooks take remediation actions? Who can edit them, and is that Tier 0?
7. What is the false-positive rate per rule, and who reviews it?
8. Are rules in source control and deployed as code, or clicked into the portal?
9. Is `AADServicePrincipalSignInLogs` connected?

---

## 8. Remember it

**Hook — "Connect, detect, investigate, respond."** Everything in the product is one of those four.
And **"period ≥ frequency, always."**

**Analogy — a newsroom, not a filing cabinet.** A SIEM is not storage; it is a newsroom deciding
what is worth reporting. Ingesting everything is like assigning every reporter to transcribe police
radio — expensive, and nobody reads it. **Entity mapping is what turns a wire report into a named
story** you can follow across days.

**The one thing:** **nothing tells you when logs stop arriving.** Silence looks exactly like a quiet
week. The "expected table has no rows" rule in §6 is the most valuable detection in the workspace
and it is almost always missing.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Four things Sentinel does?
2. Why does the ingestion-based cost model change SIEM design?
3. `queryFrequency` 1h, `queryPeriod` 30m. What is wrong?
4. What breaks without entity mapping?
5. Password spray hits 400 accounts. What stops 400 incidents?
6. Which rule type cannot be tuned, and why is that acceptable?
7. Why start automation with notification rather than remediation?
8. How do you detect that a data connector stopped?
9. Why are playbook edit rights a Tier 0 concern?

<details>
<summary>Answers</summary>

1. **Connect** (data connectors), **detect** (analytics rules), **investigate** (incidents +
   entities), **respond** (playbooks).
2. Billing is per **GB ingested**, so collecting everything is a budget failure. Each connector must
   be justified by the detections it enables, and verbose sources belong in a cheaper tier.
3. The rule looks back **less time than the gap between runs** — late-arriving events are never
   evaluated. A silent detection gap while the rule reports healthy.
4. No investigation graph, no UEBA correlation, and playbooks have no entity to act on.
5. **Incident grouping** by matching entities within a lookback window.
6. **Fusion.** It is ML-based cross-signal correlation — low volume, high fidelity, so the lack of
   tuning is an acceptable trade.
7. One false positive acting destructively causes an outage and destroys organisational trust in
   automation. Earn it with enrichment first.
8. A rule that fires on the **absence** of rows in expected tables — `join kind=rightanti` against a
   list of expected table names.
9. The playbook identity holds standing permissions to disable accounts and isolate devices.
   Whoever edits it inherits that power.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — deploy the §4 rule with entity mapping and grouping; trigger it and inspect the
  incident graph. ✗ Needs a workspace with sign-in data.
- **`break-fix/`** — set `queryPeriod` below `queryFrequency` and demonstrate the missed events;
  remove entity mapping and show the investigation graph collapse.
- **`security/`** ⭐ — the connector-health rule from §6 deployed; playbook edit permissions
  reviewed as Tier 0; MITRE coverage map.
- **`operations/`** — ingestion by table with tier assignment; false-positive rate per rule.
- **`architecture-decisions/`** — ADR: table tiering and retention; automation scope (what may a
  playbook do unattended).
- **`customer-use-cases/`** — §7 answered against a real workspace.
