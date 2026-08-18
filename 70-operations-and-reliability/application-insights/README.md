# Application Insights

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Application performance monitoring — and the one feature that silently makes your numbers
> wrong is on by default.** Pairs with [`../log-analytics/`](../log-analytics/) and
> [`../performance-engineering/`](../performance-engineering/).

---

## 1. What it is

The application-level arm of Azure Monitor: an SDK or auto-instrumentation agent inside your
application sends **requests**, **dependencies**, **exceptions**, **traces**, **customEvents** and
**availabilityResults** to a workspace-based Application Insights resource, where they can be
queried, correlated into end-to-end transactions, and mapped.

⭐ **Infrastructure monitoring tells you the VM is healthy. Application Insights tells you the
checkout is failing for users on Safari.**

---

## 2. Why it exists

⭐ **Because "the servers are fine" and "the application is broken" are both routinely true at the
same time.** Infrastructure telemetry cannot see:

| Question | ⭐ Only answerable in APM |
|---|---|
| Which **dependency** is slow — SQL, Redis, a third-party API? | ⭐ dependency telemetry |
| Is one request type slow, or all of them? | ⭐ per-operation percentiles |
| ⭐ Did this user's request fail, and where? | ⭐ end-to-end transaction by `operation_Id` |
| Which exception, on which line, how often? | exceptions with stack traces |
| ⭐ Is it slow **for users**, or slow in the datacentre? | ⭐ browser + availability telemetry |

⭐ **Dependency telemetry is the highest-value part and the least used.** Most "the app is slow"
incidents resolve to one downstream call, and ⭐ **the dependency view names it in about ninety
seconds** — which is otherwise an hour of guessing.

---

## 3. How it works underneath — correlation is the mechanism

```
BROWSER ──► API ──► SERVICE B ──► SQL
   │         │          │           │
   └─────────┴──────────┴───────────┘
      ⭐ ALL share one  operation_Id
      each span has ⭐ operation_ParentId → its caller

   ⭐ W3C Trace Context:  traceparent header carries it across
      process and service boundaries

  ┌──────────────────────────────────────────────────────┐
  │ requests · dependencies · exceptions · traces        │
  │ customEvents · customMetrics · pageViews             │
  │ availabilityResults                                  │
  └──────────────────────────────────────────────────────┘
                     │
        ⭐ SAMPLING happens HERE  ← §4. Read this before trusting any count
                     │
              workspace-based store → KQL
```

⭐ **`operation_Id` is the join key for everything.** Given one failing request, ⭐ **one query
returns every span, log line and exception across every service for that single user action** —
that is the capability people buy APM for, and it only works if trace context propagates. ⭐ **A
service that drops the `traceparent` header breaks correlation for everything downstream of it**,
and the symptom is a transaction view that simply ends.

⭐ **Classic (non-workspace) Application Insights resources were retired.** ✅ Workspace-based is the
only supported model; ⚠ verify migration status on any resource you inherit.

---

## 4. Worked example — ⭐ the sampling trap

⭐ **This is the single most important thing in this topic, and it makes people confidently wrong.**

Adaptive sampling is **enabled by default** in several SDKs. When the SDK samples, it keeps 1 in *N*
items and records `itemCount = N` on the survivor.

```kusto
// ⭐ WRONG - undercounts by the sampling factor
requests | where timestamp > ago(1d) | summarize count()
```
```
count_
 41,208        ⭐ looks precise. Is not.
```

```kusto
// ⭐ RIGHT - itemCount is the multiplier the SDK left for you
requests | where timestamp > ago(1d) | summarize Actual = sum(itemCount)
```
```
Actual
205,940       ⭐ 5x higher. THIS is the real traffic.
```

⭐ **A five-fold error, reported to a customer with a straight face.** ⭐ **Every count, sum and rate
over sampled data must use `sum(itemCount)`, not `count()`** — and the portal's own charts already
do this, which is exactly why hand-written KQL disagrees with the portal and people assume the
portal is wrong.

⭐ **Percentiles are less affected** — sampling preserves distribution shape reasonably well — ⭐ **but
counts, error rates and "how many customers were affected" are all wrong without `itemCount`.**

**Check whether you are sampled at all, before quoting any number:**

```kusto
requests
| where timestamp > ago(1d)
| summarize Retained = count(), Estimated = sum(itemCount)
| extend SamplingFactor = round(1.0 * Estimated / Retained, 2)
```

```
Retained  Estimated  SamplingFactor
   41208     205940            5.00
```

⭐ **`SamplingFactor 5.00` means four out of five items were discarded at the source and cannot be
recovered.** For a *security* investigation that matters enormously — ⭐ **the request you are
looking for may simply not exist** — which is a genuine reason to disable sampling on
authentication-related paths while leaving it on elsewhere.

---

## 5. Commands — the three queries that resolve most incidents

```kusto
// ① Which dependency is slow?  ⭐ Start here for "the app is slow"
dependencies
| where timestamp > ago(1h)
| summarize Calls = sum(itemCount),
            P95   = round(percentile(duration, 95)),
            Fails = sumif(itemCount, success == false)
    by target, type
| order by P95 desc | take 3
```

```
target                  type   Calls   P95    Fails
api.payments.example    HTTP    8,412  4,180    212
sql-contoso-prod        SQL    41,003    118      0
redis-contoso           Redis  88,220      3      0
```

⭐ **A 4,180 ms p95 on one third-party HTTP dependency, with SQL at 118 ms, ends the "is it the
database?" argument in one query** — and the answer is nearly always the answer nobody expected.

```kusto
// ② ⭐ One user's failing journey, end to end
union requests, dependencies, exceptions, traces
| where operation_Id == "8f3d1a204c7e4b199f2a1d5c7e0b4a63"
| project timestamp, itemType, name, success, duration, outerMessage
| order by timestamp asc
```

```
timestamp             itemType      name              success duration outerMessage
09:14:02.113  request       POST /checkout    False     4231
09:14:02.140  dependency    POST /payments    False     4102
09:14:06.238  exception     TimeoutException                    ⭐ The operation timed out
```

⭐ **Three rows, and the incident is understood: checkout failed because the payments dependency
timed out after 4.1 seconds.** ⭐ **This is what you show a customer instead of a theory.**

```kusto
// ③ ⭐ Failure rate over time - is it getting worse?
requests
| where timestamp > ago(6h)
| summarize Total = sum(itemCount),
            Failed = sumif(itemCount, success == false) by bin(timestamp, 15m)
| extend FailPct = round(100.0 * Failed / Total, 2)
```

```
timestamp             Total   Failed  FailPct
14/08/2026 09:00      12440       21     0.17
14/08/2026 09:15      11980      894     7.46
```

⭐ **`bin(timestamp, 15m)` plus a percentage is how you find the *moment* something changed** — and
that timestamp is the first thing the postmortem needs. See
[`../root-cause-analysis/`](../root-cause-analysis/).

---

## 6. Availability tests — and a 2026 deadline

```
⭐ Classic URL ping tests  ── being RETIRED (announced for 30 September 2026)
        │                     ⚠ check the current date and guidance
        ▼
⭐ STANDARD tests          ── the supported model
        ▸ ⭐ run from multiple regions - ⭐ use at least 5
        ▸ ⭐ alert only when N regions fail, ⭐ not one
```

⭐ **Alerting on a single test location is how you get paged for someone else's network.** ⭐ **Require
failures from multiple locations before firing** — the standard guidance is to run from at least five
and alert on three or more. ⚠ verify current recommended minimums.

⭐ **An availability test is the closest thing you have to an SLI measured outside your own
infrastructure**, which is exactly what
[`../slis-slos-and-slas/`](../slis-slos-and-slas/) §5 argues for.

---

## 7. When and where

| Need | Use |
|---|---|
| Code you own | ⭐ SDK or auto-instrumentation |
| App Service / Functions | ⭐ auto-instrumentation — ⭐ often zero code |
| Third-party black box | ⭐ availability tests only |
| Security investigation | ⭐ **consider disabling sampling** on the relevant paths |
| High-volume, cost-sensitive | ⭐ sampling on — ⭐ and document the factor |

⭐ **Sampling is a cost/fidelity decision that must be written down**, because whoever queries the
data next will not know it was applied. ⭐ **Put the factor in the runbook**; it is the difference
between a correct answer and a confident wrong one.

---

## 8. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| ⭐ KQL disagrees with the portal chart | ⭐ `count()` instead of `sum(itemCount)` | ⭐ §4 |
| Transaction view ends mid-chain | ⭐ `traceparent` not propagated | fix the service that drops it |
| "No telemetry from the app" | SDK not initialised / key wrong | check connection string, not the resource |
| Every request looks fast | ⭐ measuring server time only | add browser/client telemetry |
| Availability alert noise | ⭐ single test location | ⭐ require N of M regions |
| Cost spike | verbose traces at Analytics tier | sampling + [`../log-analytics/`](../log-analytics/) §3 |
| ⭐ Security event not found | ⭐ **sampled away** | disable sampling on auth paths |

⭐ **"Sampled away" deserves emphasis for a security engineer.** ⭐ **Absence of evidence in a sampled
dataset is not evidence of absence** — and stating that distinction during an investigation is the
mark of someone who understands their tooling rather than trusting it.

---

## 9. Customer discovery questions

1. ⭐ **"Is sampling enabled, and what is the factor?"**
2. "Can you trace a single user's request across all services?"
3. ⭐ **"When the app is slow, how long does it take to name the dependency?"**
4. "Do you measure from the browser, or only server-side?"
5. ⭐ **"Are you still on a classic Application Insights resource?"**
6. "How many availability test locations, and what is the alert rule?"
7. "Who looks at exceptions, and how often?"

---

## 10. Remember it

**Hook — `R D E T`: Requests, Dependencies, Exceptions, Traces** — ⭐ **and `itemCount` on all of
them.**

**Analogy — a hospital patient wristband.** ⭐ **`operation_Id` is the wristband: every department —
radiology, pathology, pharmacy — records against the same ID, so the whole journey can be
reconstructed afterwards.** The analogy predicts the failure precisely: ⭐ **one department that
doesn't record the wristband number breaks the chart from that point on** — which is exactly a
service that drops `traceparent`. ⭐ **And sampling is auditing one patient in five: fine for
statistics, useless when you need *that* patient's record.**

**The one line:** ⭐ **`sum(itemCount)`, never `count()` — and `operation_Id` reconstructs the whole
journey.**

---

## 11. Self-test

1. Why does hand-written KQL often disagree with the portal chart?
   → ⭐ The portal multiplies by `itemCount`; `count()` does not.
2. What is `itemCount`?
   → ⭐ The sampling multiplier the SDK stored on each retained item.
3. Which measures are least distorted by sampling?
   → ⭐ Percentiles. Counts, rates and affected-user totals are badly distorted.
4. What joins spans across services?
   → ⭐ `operation_Id`, propagated via the W3C `traceparent` header.
5. First query for "the application is slow"?
   → ⭐ Dependencies by p95 — it names the culprit in one step.
6. Why alert on multiple availability test regions?
   → ⭐ A single location fails for reasons that are not your outage.
7. Why might sampling matter in a security investigation?
   → ⭐ The event may have been discarded at source; absence is not evidence of absence.

---

## 12. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | the sampling-factor query, and a count computed both ways |
| `operations` | one end-to-end transaction reconstructed by `operation_Id` |
| `break-fix` | ⭐ one incident where dependency p95 named the cause |
| `security` | the sampling decision for authentication paths, written down |
| `architecture-decisions` | availability test design: locations, threshold, and why |
