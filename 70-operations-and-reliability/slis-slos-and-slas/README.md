# SLIs, SLOs and SLAs

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The measurement, the target, and the contract — three different things people use as
> synonyms.** Pairs with [`../performance-engineering/`](../performance-engineering/) and
> [`../root-cause-analysis/`](../root-cause-analysis/).

---

## 1. What it is

| Term | Is | Owned by | ⭐ If breached |
|---|---|---|---|
| ⭐ **SLI** | the **measurement** | engineering | nothing — it is a number |
| ⭐ **SLO** | the **internal target** | engineering + product | ⭐ **engineering effort shifts** |
| ⭐ **SLA** | the **external contract** | legal / commercial | ⭐ **money changes hands** |

⭐ **SLO must always be stricter than SLA.** If your contract promises 99.9 % and your internal
target is also 99.9 %, you have zero warning: the first time you notice a problem is the moment you
owe a refund.

---

## 2. Why it exists

⭐ **Without an SLO, "reliable enough" is decided by whoever complained most recently.** That
produces two opposite pathologies, and both are expensive:

| Pathology | Symptom | Cost |
|---|---|---|
| ⭐ **Chasing 100 %** | every incident is a crisis | ⭐ **no features ship**; engineers burn out |
| No target at all | ⭐ reliability work is never prioritised | ⭐ outages until a customer leaves |

⭐ **An SLO is a *permission* as much as a constraint.** A 99.9 % target explicitly permits ~43
minutes of unavailability each month — ⭐ **and that permission is what makes it safe to deploy on a
Thursday.**

---

## 3. How it works underneath — the error budget

```
SLO = 99.9 %  ──►  ⭐ ERROR BUDGET = 100 % − 99.9 % = 0.1 %

over 30 days:  0.001 × 30 × 24 × 60  =  ⭐ 43.2 minutes

    ┌──────────────────────── 43.2 min ────────────────────────┐
    │████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
     ▲ 14 min spent (incident, 8 Aug)         ⭐ 29 min remaining
                                    │
                    ⭐ ERROR BUDGET POLICY - agreed in advance:
                    ▸ >50 % remaining  → ⭐ ship freely
                    ▸ <25 % remaining  → ⭐ risky changes need approval
                    ▸ ⭐ EXHAUSTED      → ⭐ FEATURE FREEZE.
                                          reliability work only
```

⭐ **The error budget converts an argument into arithmetic.** "Should we ship this risky change?"
stops being a matter of seniority or confidence and becomes ⭐ *"we have 29 minutes left this month;
what does this change risk?"*

⭐ **The policy must be agreed before it is needed** — the same principle as the abort criteria in
[`../../75-architecture-and-consulting/cutover-playbooks/`](../../75-architecture-and-consulting/cutover-playbooks/) §4.
A freeze proposed *during* a budget overrun is a political fight; a freeze agreed in January is a
rule that executes itself.

**The numbers, memorised:**

| SLO | ⭐ Per month | Per year |
|---|---|---|
| 99 % | ⭐ **7.2 hours** | 3.65 days |
| 99.5 % | 3.6 hours | 1.83 days |
| 99.9 % | ⭐ **43.2 minutes** | ⭐ 8.76 hours |
| 99.95 % | 21.6 minutes | 4.38 hours |
| 99.99 % | ⭐ **4.32 minutes** | 52.6 minutes |

⭐ **99.99 % is 4.32 minutes a month — less time than a reboot.** When someone asks for "four
nines", ⭐ **the correct response is to say that number out loud**: it means no single-instance
component, no manual failover, and no maintenance window. Most people asking have not costed that.

---

## 4. Worked example — composing an SLA, which is where promises break

Your service depends on three things, each with its own availability:

```
User ─► Front Door ─► App Service ─► SQL Database
        99.99 %       99.95 %        99.99 %

⭐ SERIAL dependencies MULTIPLY:
   0.9999 × 0.9995 × 0.9999  =  ⭐ 0.99930  =  99.93 %

⭐ You cannot promise 99.95 % on top of a 99.93 % composite.
```

⭐ **This calculation is the single most useful thing in this topic**, and it is routinely skipped.
A team promises 99.95 % because their app tier offers it, ⭐ **without multiplying through the
chain** — and then discovers the promise was arithmetically impossible from day one.

⭐ **Redundancy adds in the opposite direction.** Two independent instances at 99.9 % each:

```
⭐ both fail  =  0.001 × 0.001  =  0.000001
   available  =  ⭐ 99.9999 %      ⭐ IF the failures are truly independent
```

⭐ **"If independent" is doing all the work in that sentence.** Two VMs in the same rack, same
region, same subscription, behind the same misconfigured NSG, ⭐ **share failure modes — and the
correlated failure is what actually takes you down.** This is why availability zones exist and why
"we have two of everything" is not an availability argument by itself.

⚠ `⚠ check` — Microsoft's published SLAs vary by tier, configuration and region (many require
zone-redundant or multi-instance deployment to reach the headline figure). **Read the SLA for the
exact SKU before quoting it.**

---

## 5. Choosing an SLI — measure what the user feels

⭐ **The most common mistake is measuring the server instead of the user.**

| ✗ Weak SLI | ⭐ Strong SLI |
|---|---|
| "server uptime" | ⭐ **% of requests returning < 500 in under 800 ms** |
| "CPU below 80 %" | ⭐ % of logins completing successfully |
| "the ping test passed" | ⭐ **% of successful sign-ins from a real client path** |
| ⭐ average latency | ⭐ **p95 / p99 latency** — [`../performance-engineering/`](../performance-engineering/) |

⭐ **A server can be 100 % up while every request fails.** The SLI must be expressed as a ratio of
*good events to valid events*, from as close to the user as you can measure.

```kusto
// ⭐ Availability SLI from real traffic, not from a health probe
requests
| where timestamp > ago(30d)
| summarize Total = count(),
            Good  = countif(success == true and duration < 800)
| extend SLI = round(100.0 * Good / Total, 3)
```

```
Total    Good     SLI
1284401  1283190  99.906
```

⭐ **99.906 % against a 99.9 % SLO: you are inside the budget with almost nothing to spare.** That is
a sentence a steering committee can act on, and it is worth more than any dashboard screenshot.

**Burn rate — the alert that actually matters:**

```
⭐ Burn rate = how fast you are consuming the budget vs the sustainable pace

  1x  → budget lasts exactly the window. Fine.
  ⭐ 14.4x over 1 hour → ⭐ 2 % of a 30-day budget gone in an hour → ⭐ PAGE
  6x over 6 hours     → ⭐ 5 % gone → ticket, not a page
```

⭐ **Alert on burn rate, not on individual errors.** A handful of 500s at 3 a.m. is within budget and
should wake nobody; ⭐ **the same errors arriving fast enough to exhaust a month's budget in a day is
the emergency** — and that distinction is invisible to a simple error-count alert. See
[`../alerts-and-action-groups/`](../alerts-and-action-groups/) §2.

---

## 6. When and where

| Situation | Approach |
|---|---|
| Internal tool, few users | ⭐ an SLO is probably overhead — ⭐ say so |
| Customer-facing, revenue-bearing | ⭐ **SLI + SLO + error budget policy** |
| Contractual SLA exists | ⭐ SLO must be **stricter**, with margin |
| ⭐ Brand-new service | ⭐ measure for a month **before** committing to a number |

⭐ **Never set an SLO before you have measured the SLI.** A target chosen from ambition rather than
data is either trivially met (and meaningless) or permanently breached (and ignored) — ⭐ **and both
outcomes destroy the credibility of the whole practice.**

⭐ **Set the SLO slightly below current measured performance**, so it is achievable, then tighten it
deliberately as the system improves.

---

## 7. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| Every incident is a crisis | ⭐ implicit 100 % target | ⭐ set an SLO; ⭐ the budget is permission |
| SLA breached with no warning | ⭐ SLO equals SLA | ⭐ SLO must be stricter |
| Promise arithmetically impossible | ⭐ dependencies not multiplied | §4 composition |
| "We have redundancy" but still down | ⭐ **correlated failure** | independence must be real |
| ⭐ Green dashboard, angry users | server-side SLI | ⭐ measure the user's path |
| Budget exhausted, nothing changes | ⭐ no error budget **policy** | agree it in advance |
| Alert noise from every error | ⭐ no burn-rate concept | ⭐ alert on burn rate |

⭐ **"Green dashboard, angry users" is the definitive sign of a server-side SLI.** Uptime measured at
the load balancer says nothing about the authentication dependency that is timing out for a third of
sign-ins — ⭐ **and the users are right.**

---

## 8. Customer discovery questions

1. ⭐ **"What availability have you promised anyone in writing?"**
2. "How do you measure it today — and from where?"
3. ⭐ **"What is an acceptable amount of downtime per month?"** (⭐ then convert it to a number)
4. "What happens, concretely, when you breach?"
5. ⭐ **"Which dependencies are in the path, and what are their SLAs?"**
6. "Who decides whether to ship when reliability is poor?"
7. ⭐ **"Is anyone woken up for this service? Should they be?"**

---

## 9. Remember it

**Hook — `I O A`: **I**ndicator measures, **O**bjective targets, **A**greement costs money.**
⭐ Strictness increases in the opposite direction: **SLO stricter than SLA, always.**

**Analogy — a household budget, not a speed limit.** ⭐ **The error budget is money you are *allowed*
to spend: spend it on a bold deployment, or waste it on an avoidable outage — but you cannot spend
it twice, and running out means no discretionary purchases until next month.** The analogy predicts
the practice: ⭐ **"we have 29 minutes left" ends an argument the way "we have £40 left" does**, and
⭐ **a budget with no rule about running out is not a budget.**

**The one line:** ⭐ **The error budget turns "is it reliable enough?" into arithmetic — and serial
dependencies multiply.**

---

## 10. Self-test

1. Difference between SLO and SLA, and which is stricter?
   → ⭐ SLO is the internal target, SLA the contract with penalties. ⭐ SLO must be stricter.
2. Monthly downtime allowed by 99.9 %? By 99.99 %?
   → ⭐ 43.2 minutes; 4.32 minutes.
3. Three serial dependencies at 99.99 %, 99.95 %, 99.99 %. Composite?
   → ⭐ ~99.93 % — multiply, do not take the lowest.
4. When does redundancy fail to add availability?
   → ⭐ When failures are correlated — same rack, zone, config or dependency.
5. Why is "server uptime" a weak SLI?
   → ⭐ A server can be up while every request fails; measure good/valid events at the user.
6. What should you alert on instead of error count?
   → ⭐ Burn rate — how fast the budget is being consumed.
7. Why measure before setting an SLO?
   → ⭐ An unmeasured target is either meaningless or permanently breached; both kill credibility.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | the SLI query run over 30 days of real traffic |
| `operations` | ⭐ the error budget tracked across a month, with an incident deducted |
| `architecture-decisions` | ⭐ the composite SLA calculation for a real dependency chain |
| `break-fix` | one incident measured in budget minutes rather than adjectives |
| `customer-use-cases` | the error budget policy, agreed and dated before it was needed |
