# Performance Engineering

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Averages lie, and they lie in a specific, predictable direction.** Pairs with
> [`../application-insights/`](../application-insights/) and
> [`../capacity-planning/`](../capacity-planning/).

---

## 1. What it is

Measuring, understanding and improving how fast a system responds under real load — using
distributions rather than averages, identifying the actual bottleneck rather than the suspected
one, and validating with load tests that reflect real usage.

⭐ **Performance work without measurement is decoration. Nearly all of the discipline is choosing
the right number to look at.**

---

## 2. Why it exists

⭐ **Because the average is the most misleading statistic in operations, and it is the default
everywhere.**

```
100 requests:  99 return in 100 ms,  1 returns in 10,000 ms

  ⭐ AVERAGE  = (99 × 100 + 10,000) / 100  =  ⭐ 199 ms   ← "we're fast!"
  ⭐ p99      =                               ⭐ 10,000 ms ← ⭐ the truth
```

⭐ **The average is 199 ms and one customer in a hundred waited ten seconds.** ⭐ **On a page making
20 API calls, a p99 of 10 s means roughly one page load in five hits it** — the tail is not rare from
the user's point of view, it is routine.

| ✗ Metric | ⭐ Use instead |
|---|---|
| Average latency | ⭐ **p50, p95, p99** |
| "the server is fast" | ⭐ time measured at the client |
| Peak CPU | ⭐ **saturation** — queue depth, wait time |
| Total requests | ⭐ rate, errors and duration together |

---

## 3. How it works underneath — two laws worth knowing by heart

⭐ **Little's Law** — relates the three quantities you can actually measure:

```
   L = λ × W
   ⭐ concurrency = arrival rate × time in system

   Example: 200 requests/sec, ⭐ 250 ms average
            L = 200 × 0.25 = ⭐ 50 requests in flight simultaneously
   ⭐ If your thread pool is 32, ⭐ you are queueing. That is the bottleneck.
```

⭐ **This one calculation tells you whether your concurrency limit is the problem — before you touch
a profiler**, and it needs only two numbers you already have.

⭐ **The utilisation curve** — why 80 % is the number everyone quotes:

```
   ⭐ wait time ∝  ρ / (1 − ρ)        ρ = utilisation

   ρ = 0.50  →  wait ≈ 1.0 × service time
   ρ = 0.80  →  wait ≈ 4.0 ×        ⭐ ← the knee
   ρ = 0.90  →  wait ≈ 9.0 ×
   ⭐ ρ = 0.95  →  wait ≈ 19.0 ×      ⭐ ← ⭐ the cliff
```

⭐ **Latency does not degrade linearly with load — it degrades hyperbolically.** ⭐ **Going from 80 %
to 95 % utilisation does not cost 19 % more latency; it costs roughly 5× more.** This is why
"the server is only at 90 % CPU, it's fine" is wrong, and why capacity headroom is a latency
decision rather than a cost inefficiency. See [`../capacity-planning/`](../capacity-planning/).

⭐ **Two method acronyms worth carrying:**

| Method | Applies to | Ask |
|---|---|---|
| ⭐ **USE** | ⭐ resources (CPU, disk, pool) | ⭐ **U**tilisation, **S**aturation, **E**rrors |
| ⭐ **RED** | ⭐ services / endpoints | ⭐ **R**ate, **E**rrors, **D**uration |

⭐ **Saturation is the one people omit, and it is the leading indicator.** ⭐ **CPU at 100 % with an
empty run queue is healthy — the work fits. CPU at 70 % with a deep queue is failing.** Utilisation
tells you how busy; ⭐ **saturation tells you how far behind.**

---

## 4. Worked example — reading a percentile table properly

```kusto
requests
| where timestamp > ago(24h)
| summarize Count = sum(itemCount),
            p50 = round(percentile(duration, 50)),
            p95 = round(percentile(duration, 95)),
            p99 = round(percentile(duration, 99))
    by name
| order by Count desc | take 4
```

```
name                 Count    p50    p95     p99
GET /api/products   412,880     42    118     201
POST /api/checkout   18,204    310  4,820  11,400   ⭐
GET /api/search      88,110     95  2,940   3,100
GET /health         120,400      2      4       6
```

⭐ **Read the checkout row as an engineer, not a reporter.** ⭐ **p50 of 310 ms and p95 of 4,820 ms is
a 15× spread** — that is not "sometimes slow", it is **two different behaviours** sharing one
endpoint name. Something bimodal is happening: a cache hit versus a miss, a code path taken only for
certain baskets, or a lock.

⭐ **A wide p50→p95 spread means look for two populations, not one slow system.** That single reading
habit redirects investigations that would otherwise spend a day optimising the fast path.

⭐ **Contrast the search row: p95 2,940 and p99 3,100 are close.** ⭐ **Uniformly slow — that is a
genuine single bottleneck** (probably an unindexed query), and it is a different kind of fix
entirely.

⭐ **And note `/health` at 120,400 calls — 22 % of all traffic is the health probe.** Harmless here,
but ⭐ **health probes routinely distort aggregate latency figures downward and should be excluded
from any user-facing SLI.**

**Then split the suspicious endpoint and prove the hypothesis:**

```kusto
requests
| where timestamp > ago(24h) and name == "POST /api/checkout"
| extend Bucket = case(duration < 500, "fast", duration < 3000, "medium", "slow")
| summarize Count = sum(itemCount) by Bucket, tostring(customDimensions.PaymentProvider)
```

```
Bucket  PaymentProvider  Count
fast    internal-wallet  14,900
slow    ⭐ external-psp     3,180
medium  external-psp         124
```

⭐ **Two populations confirmed: internal wallet payments are fast, the external provider is slow.**
⭐ **The fix is now a conversation about a third party — a timeout, a circuit breaker, an
asynchronous flow — not a code optimisation.** Two queries, and the work is correctly scoped.

---

## 5. Load testing — and the trap that invalidates most of it

```
⭐ COORDINATED OMISSION — ⭐ the reason most load-test results are optimistic

A test client sends a request, ⭐ WAITS for the response, then sends the next.
When the system stalls for 2 seconds, ⭐ the client simply sends fewer requests.
⭐ The stall is never measured as latency for the requests that WOULD have
   arrived during it - ⭐ they were never sent.

⭐ Real users do not wait politely. They arrive on their own schedule.

⭐ FIX: use a tool that models a fixed ARRIVAL RATE (open model),
       ⭐ not a fixed number of looping virtual users (closed model).
```

⭐ **Coordinated omission systematically understates tail latency, often by an order of magnitude** —
and it is invisible in the report, which shows a confident p99. ⭐ **Being able to name this in an
interview is a strong senior signal**, because it demonstrates you have questioned your own tooling.

**Other load-test requirements that matter more than the tool choice:**

| Requirement | Why |
|---|---|
| ⭐ Realistic data volumes | ⭐ a query is fast on 1,000 rows and fatal on 10 million |
| ⭐ Realistic cache state | ⭐ a warm cache flatters everything |
| Realistic mix of endpoints | ⭐ 100 % of one endpoint tests nothing real |
| ⭐ Measure from the client | server-side timing excludes queueing at the front door |
| ⭐ Run to failure at least once | ⭐ you need to know **how** it breaks, not just that it holds |

⭐ **"Run to failure at least once" is the most under-used practice here.** ⭐ **Knowing whether your
system degrades gracefully or collapses is a design fact you cannot obtain any other way** — and it
is what makes the capacity conversation concrete.

---

## 6. Commands — find the bottleneck before optimising anything

```kusto
// ⭐ Is it us, or a dependency?  ⭐ Answer this FIRST, always.
dependencies
| where timestamp > ago(1h)
| summarize Calls = sum(itemCount), p95 = round(percentile(duration,95)) by target
| order by p95 desc | take 3
```

```
target                Calls   p95
api.payments.example  8,412  4,180
sql-contoso-prod     41,003    118
```

⭐ **Four seconds in one dependency and 118 ms in the database ends the guessing.** ⭐ **The most
common wasted week in performance work is optimising the component the team already suspected**,
while the actual cost sits in a downstream call nobody measured.

```kusto
// ⭐ The N+1 query pattern - one request, hundreds of tiny calls
dependencies
| where timestamp > ago(1h) and type == "SQL"
| summarize CallsPerRequest = count() by operation_Id
| summarize p95 = percentile(CallsPerRequest, 95), Max = max(CallsPerRequest)
```

```
p95   Max
  4   ⭐ 312
```

⭐ **312 database calls to serve one request is the classic N+1 pattern** — a loop issuing a query
per row. ⭐ **Each call is fast, so nothing looks slow individually, and the total is catastrophic.**
This query finds it in seconds and it is one of the most reliably present defects in any ORM-based
application.

---

## 7. When and where

| Situation | Approach |
|---|---|
| "It feels slow" | ⭐ measure percentiles **first** — ⭐ do not accept the adjective |
| Intermittent slowness | ⭐ look for **two populations** (§4) |
| Consistent slowness | single bottleneck — USE method on resources |
| Before a known peak | ⭐ load test with realistic data, ⭐ run to failure once |
| ⭐ After any optimisation | ⭐ **re-measure** — ⭐ intuition about performance is unreliable |

⭐ **Never optimise without a measurement before and after.** ⭐ **Experienced engineers are
routinely wrong about where time goes** — that is not a knock on experience, it is why profilers
exist.

---

## 8. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| "Average is fine, users complain" | ⭐ average hides the tail | ⭐ p95/p99 |
| Fine in test, slow in prod | ⭐ unrealistic data volume | test with production-scale data |
| ⭐ Load test passed, prod fell over | ⭐ **coordinated omission** | open-model load generator |
| Optimised, no improvement | wrong bottleneck | ⭐ measure dependencies first |
| ⭐ Latency exploded at 95 % CPU | ⭐ the utilisation curve | ⭐ hold headroom; §3 |
| Endpoint bimodal | two code paths | ⭐ split by dimension (§4) |
| ⭐ Metrics look great, SLI does not | ⭐ health probes in the aggregate | exclude probe traffic |

⭐ **"Latency exploded at 95 % CPU" is not a mystery and not a bug** — it is queuing theory doing
exactly what it does. ⭐ **The fix is capacity, and the argument for capacity is the curve, not a
feeling.**

---

## 9. Customer discovery questions

1. ⭐ **"What latency do your users actually experience — p95, not average?"**
2. "Is there a written performance target, and is it in the SLO?"
3. ⭐ **"Which endpoint is slowest, and do you know why?"**
4. "What utilisation do you run at during peak?"
5. ⭐ **"Have you ever load tested to the point of failure?"**
6. "Does your load test use production-scale data?"
7. ⭐ **"Do your dashboards include health-probe traffic?"**

---

## 10. Remember it

**Hook — `p50 p95 p99`, and ⭐ **USE** for resources, **RED** for services.** ⭐ **Never a single
average.**

**Analogy — a motorway at rush hour.** ⭐ **At 50 % occupancy traffic flows freely; at 80 % it is
still moving but any small disturbance ripples backwards; at 95 % a single brake light creates a
ten-minute jam.** The analogy is load-bearing: ⭐ **it predicts the hyperbolic curve, it explains why
headroom is not waste, and it explains the tail — the *average* car took 20 minutes, but the one
that arrived at the wrong moment took an hour, and that driver is your p99.**

**The one line:** ⭐ **Measure percentiles, find the dependency before optimising, and remember
latency degrades hyperbolically past ~80 % utilisation.**

---

## 11. Self-test

1. Why is average latency misleading, and in which direction?
   → ⭐ It hides the tail; it always flatters the system.
2. State Little's Law and one practical use.
   → ⭐ L = λW. 200 rps × 0.25 s = 50 in flight; a 32-thread pool means queueing.
3. What happens to wait time between 80 % and 95 % utilisation?
   → ⭐ Roughly 4× → 19× service time. Hyperbolic, not linear.
4. Difference between utilisation and saturation?
   → ⭐ Utilisation = how busy; saturation = how far behind (queue depth). Saturation leads.
5. p50 310 ms, p95 4,820 ms — what does the spread suggest?
   → ⭐ Two populations, not one slow system. Split by a dimension.
6. What is coordinated omission and why does it matter?
   → ⭐ A closed-model client stops sending during stalls, so the stall never appears as latency; tail is understated.
7. Why exclude health probes from an SLI?
   → ⭐ They are fast and high-volume, dragging aggregates down and hiding user experience.

---

## 12. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | the percentile table for a real workload, with the bimodal split investigated |
| `operations` | ⭐ dependency p95 ranking, and the bottleneck it identified |
| `break-fix` | ⭐ one N+1 query found and the before/after measurement |
| `architecture-decisions` | the headroom decision, justified by the utilisation curve |
| `customer-use-cases` | a load test run to failure, with the failure mode described |
