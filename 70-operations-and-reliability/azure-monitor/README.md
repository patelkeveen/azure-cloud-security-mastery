# Azure Monitor

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Two data types with completely different physics — metrics and logs — behind one brand name.**
> Pairs with [`../log-analytics/`](../log-analytics/) and
> [`../alerts-and-action-groups/`](../alerts-and-action-groups/).

---

## 1. What it is

The platform-wide telemetry service: it collects **metrics** (cheap, numeric, pre-aggregated
time series) and **logs** (expensive, structured, queryable records) from every Azure resource, and
feeds alerting, dashboards, workbooks and autoscale.

⭐ **Almost every Azure Monitor mistake is treating one data type as if it were the other.**

---

## 2. Why it exists

Before it, every resource type had its own diagnostics, its own retention, and its own answer to
"was it up?" — and none of them agreed. The consolidation matters because ⭐ **an incident spans
resource types**: the app is slow, the database is fine, the network is fine, and someone has to
compare three timelines on one axis.

| Without a single platform | With it |
|---|---|
| Per-service diagnostics | ⭐ one query language across everything |
| ⭐ No shared clock | ⭐ `TimeGenerated` on one axis |
| Alerting bolted on per service | one alert model, one action group |
| ⭐ Telemetry off by default, silently | ⭐ still off by default — but ⭐ **now measurable** |

⭐ **The last row is the trap that never goes away: diagnostic settings are opt-in per resource.**
A resource with no diagnostic setting produces **no logs at all**, and nothing warns you. ⭐ **The
gap is only visible on the day you need the data — which is always after the incident.**

---

## 3. How it works underneath — the two pipelines

```
                    ┌──────────── AZURE MONITOR ────────────┐
                    │                                        │
   RESOURCE ──┬────►│  ⭐ METRICS   platform, automatic       │
              │     │    numeric · pre-aggregated · 1-min    │
              │     │    ⭐ retention 93 days · ⭐ CHEAP/free  │
              │     │    → alerts in ⭐ SECONDS-to-minutes    │
              │     │                                        │
              └────►│  ⭐ LOGS      ⭐ OPT-IN per resource     │
                    │    ⭐ diagnostic setting REQUIRED       │
   (nothing without │    structured rows · KQL · ⭐ PER-GB    │
    the setting) ⭐  │    → alerts in ⭐ minutes (query-based) │
                    └────────────────────────────────────────┘
                                   │
        Log Analytics workspace ◄──┘   → ../log-analytics/
```

⭐ **Metrics are free and instant; logs cost money and lag.** That single sentence drives every
design decision here:

| Question | Answer |
|---|---|
| *"Is CPU above 80 %?"* | ⭐ **metric alert** — fast, free, no workspace needed |
| *"Which user deleted the policy?"* | ⭐ **log query** — only if the diagnostic setting existed **at the time** |
| *"Alert me in 60 seconds"* | ⭐ metric. A log alert cannot reliably do this |
| *"Correlate across five services"* | ⭐ logs. Metrics cannot join |

⭐ **Logs capture forward only.** Turning on a diagnostic setting today gives you nothing about
yesterday — the same *"telemetry has to be running before the thing you want to see"* constraint as
the unified audit log in
[`../../SC-300-SPRINT/DAY-1.md`](../../SC-300-SPRINT/DAY-1.md).

---

## 4. Worked example — finding the resources with no logs at all

⭐ **This is the highest-value single query in the topic**, and almost nobody runs it:

```powershell
Get-AzResource | ForEach-Object {
  $ds = Get-AzDiagnosticSetting -ResourceId $_.ResourceId -ErrorAction SilentlyContinue
  if (-not $ds) {
      [pscustomobject]@{ Name = $_.Name; Type = $_.ResourceType; Diagnostics = 'NONE' }
  }
}
```

```
Name              Type                              Diagnostics
kv-contoso-prod   Microsoft.KeyVault/vaults         NONE
nsg-app-prod      Microsoft.Network/networkSecurityGroups  NONE
```

⭐ **A Key Vault with no diagnostic setting means you cannot answer "who read that secret?" — ever,
retroactively.** That is a finding you can hand a customer in the first week, and it costs one
query.

**Turning it on, correctly:**

```powershell
$ws = (Get-AzOperationalInsightsWorkspace -ResourceGroupName rg-monitor -Name law-contoso).ResourceId

New-AzDiagnosticSetting -Name 'to-law' `
  -ResourceId (Get-AzKeyVault -VaultName kv-contoso-prod).ResourceId `
  -WorkspaceId $ws `
  -Log @(New-AzDiagnosticSettingLogSettingsObject -CategoryGroup allLogs -Enabled $true) `
  -Metric @(New-AzDiagnosticSettingMetricSettingsObject -Category AllMetrics -Enabled $true)
```

⭐ **`-CategoryGroup allLogs` future-proofs it.** Naming individual categories means a category
Microsoft adds next year is silently not collected — a slow, invisible coverage gap.

⚠ `⚠ check` — cmdlet parameter shapes for diagnostic settings changed between Az module versions.
Confirm with `Get-Help New-AzDiagnosticSetting -Full` against the module you have.

---

## 5. The agent story — and the 2026 currency point

```
⭐ Log Analytics agent (MMA/OMS)   ── RETIRED 31 August 2024 ⭐
        │
        ▼
⭐ Azure Monitor Agent (AMA)       ── the only supported agent
        │
        └── configured by ⭐ DATA COLLECTION RULES (DCR)
              ▸ ⭐ what to collect, from which machines, to which workspace
              ▸ ⭐ filtering happens at the SOURCE - before you pay to ingest
              ▸ one machine can have many DCRs
```

⭐ **DCRs are the cost control, not just the config mechanism.** With the old agent you collected
everything and paid for it; ⭐ **a DCR with a transform can drop the noisy 60 % of a log stream
before ingestion.** On a real workspace that is the difference between a defensible and an
indefensible monitoring bill.

✅ The MMA retirement date is a real, dated milestone worth knowing. ⚠ **Verify current AMA feature
parity for the specific workload** — parity gaps existed at retirement and closed over time.

---

## 6. Commands — read a metric without a workspace

```powershell
Get-AzMetric -ResourceId $vmId -MetricName 'Percentage CPU' `
  -TimeGrain 00:05:00 -StartTime (Get-Date).AddHours(-2) -AggregationType Maximum |
  Select-Object -ExpandProperty Data | Select-Object TimeStamp, Maximum -First 4
```

```
TimeStamp             Maximum
14/08/2026 09:00:00     34.21
14/08/2026 09:05:00     91.87
14/08/2026 09:10:00     93.02
14/08/2026 09:15:00     41.55
```

⭐ **`-AggregationType Maximum`, not `Average`.** A five-minute average of 40 % hides a 93 % spike
that timed out every request in it. ⭐ **Averaging is how monitoring lies to you**, and it is the
same lesson as percentiles in
[`../performance-engineering/`](../performance-engineering/).

**Check what a resource can even emit, before designing an alert:**

```powershell
Get-AzMetricDefinition -ResourceId $vmId |
  Select-Object Name, Unit, PrimaryAggregationType -First 3
```

```
Name              Unit     PrimaryAggregationType
Percentage CPU    Percent  Average
Network In Total  Bytes    Total
Available Memory  Bytes    Average
```

⭐ **Note what is missing on an Azure VM: disk space and memory pressure are not platform
metrics** — they are guest-OS metrics requiring the agent and a DCR. ⭐ **"We monitor our VMs" while
having no disk-full alert is extremely common**, and disk-full is one of the most frequent causes of
an unplanned outage.

---

## 7. When and where

| Need | Use |
|---|---|
| Fast threshold on a platform value | ⭐ metric alert — no workspace |
| Anything needing correlation or history | logs → [`../log-analytics/`](../log-analytics/) |
| Application-level tracing | [`../application-insights/`](../application-insights/) |
| Security detections | ⭐ Sentinel on the same workspace |
| Guest OS (disk, memory, processes) | ⭐ **AMA + a DCR** — not automatic |

⭐ **Design retention by question, not by policy.** *"How long might I need to answer 'who did
this?'"* is usually **1 year** for security and **30 days** for troubleshooting — ⭐ and paying
Analytics-tier prices for a year of debug logs is the single most common Azure monitoring
overspend.

---

## 8. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| ⭐ "There are no logs for that day" | ⭐ diagnostic setting never created | §4 sweep; ⭐ **unrecoverable retroactively** |
| Alert never fired | metric exists but ⭐ wrong aggregation | ⭐ `Maximum`, not `Average` |
| Alert fired late | ⭐ log alert used where a metric would do | metric alerts evaluate faster |
| Bill tripled | verbose categories at Analytics tier | ⭐ DCR filtering + table plans |
| Disk full, no warning | ⭐ guest metric, no agent | AMA + DCR |
| Data arrives minutes late | ⭐ **normal ingestion latency** | ⭐ do not design a 30-second log alert |
| Old agent stopped reporting | ⭐ MMA retired 2024-08-31 | migrate to AMA |

⭐ **Ingestion latency is a design constraint, not a fault.** Log data typically becomes queryable
within a few minutes; ⚠ check current documented targets. ⭐ **An alert whose required response time
is shorter than ingestion latency cannot work** — that is a metric alert or a different
architecture.

---

## 9. Customer discovery questions

1. ⭐ **"If I asked who deleted a resource last Tuesday, could you answer?"**
2. "Which resources have diagnostic settings, and who decided that list?"
3. ⭐ **"What is your monthly Log Analytics spend, and what drives it?"**
4. "Do you monitor guest-OS disk and memory, or only platform metrics?"
5. "How long must you keep security-relevant logs, and who mandates it?"
6. ⭐ **"Are you still running the Log Analytics agent anywhere?"**
7. "Which alerts fired last month, and what did anyone do about them?"

---

## 10. Remember it

**Hook — `M L`: Metrics are free, fast and forgetful; Logs are paid, slow and permanent.**

**Analogy — a car dashboard versus the flight recorder.** ⭐ **The dashboard shows speed right now,
costs nothing extra, and remembers nothing (metrics). The black box records everything, is expensive,
and is the only thing that can answer "what happened?" afterwards — but only if it was switched on
before the flight (logs).** The analogy predicts every failure here: ⭐ **you cannot retrofit a black
box recording after the crash**, and nobody notices it was off until then.

**The one line:** ⭐ **Metrics for "is it bad now", logs for "what happened" — and logs capture
forward only, so the diagnostic setting must exist before the incident.**

---

## 11. Self-test

1. Two data types, and the key difference in cost and speed?
   → ⭐ Metrics: free, pre-aggregated, fast, 93-day retention. Logs: per-GB, queryable, higher latency.
2. A resource has no diagnostic setting. What can you learn about yesterday?
   → ⭐ Nothing. Logs capture forward only.
3. Why prefer `Maximum` over `Average` for a CPU alert?
   → ⭐ An average hides the spike that actually timed out requests.
4. Which two common VM problems are *not* platform metrics?
   → ⭐ Disk space and memory pressure — guest OS, needing AMA + DCR.
5. What replaced the Log Analytics agent, and when?
   → ⭐ Azure Monitor Agent; MMA retired **2024-08-31**.
6. What is a DCR's underrated role?
   → ⭐ Filtering at source — cost control before ingestion.
7. Why can't you build a 30-second log alert?
   → ⭐ Ingestion latency exceeds it. Use a metric alert.

---

## 12. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | the §4 sweep output, plus one diagnostic setting created and verified |
| `security` | ⭐ Key Vault / NSG logging enabled, with the "who read the secret" query proven |
| `operations` | a DCR that filters at source, with the before/after ingestion volume |
| `break-fix` | one alert that did not fire, diagnosed to aggregation or type |
| `architecture-decisions` | ⭐ the retention decision per table, justified by the question it answers |
