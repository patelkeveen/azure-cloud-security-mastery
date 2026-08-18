# Capacity Planning

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Capacity is a latency decision and a lead-time decision — the cost conversation comes third.**
> Pairs with [`../performance-engineering/`](../performance-engineering/) and
> [`../../20-azure-platform/budgets-and-cost-controls/`](../../20-azure-platform/budgets-and-cost-controls/).

---

## 1. What it is

Deciding how much of each resource you need, when you will need it, and how long it takes to get —
across compute, storage, throughput, **licences**, **service quotas** and **people**. The output is a
dated plan, not a spreadsheet of current usage.

⭐ **"The cloud is elastic" removed the procurement lead time, not the limits.** Quotas, regional
capacity, licence counts and SKU availability are all still finite, and each has its own lead time.

---

## 2. Why it exists

⭐ **Because the thing that runs out is never the thing you were watching.** Real examples of what
actually blocks:

| Resource | ⭐ Where it bites |
|---|---|
| ⭐ **vCPU quota per region/family** | ⭐ scale-out fails at 3 a.m. with a quota error, not a cost error |
| ⭐ **Public IP addresses** | subscription limit reached mid-deployment |
| ⭐ **Licences** | ⭐ **onboarding stops** — no E5 seats left |
| ⭐ **Storage account IOPS** | throttling that presents as application latency |
| ⭐ **People** | ⭐ one person knows the system; ⭐ capacity is their calendar |
| ⭐ **Log ingestion budget** | monitoring silently capped |

⭐ **The licence row is the one most likely to affect an identity engineer directly**, and it has a
real lead time: procurement, not an API call. ⭐ **"We can't onboard the new team because there are
no Entra ID P2 seats" is a capacity failure**, and it is invisible on every infrastructure
dashboard.

---

## 3. How it works underneath — three inputs, one date

```
① ⭐ CURRENT USAGE      measured, not estimated
② ⭐ GROWTH RATE        from history — ⭐ NOT from the business plan
③ ⭐ LEAD TIME          how long to obtain more
                          quota increase   ⭐ hours-to-days (a support case)
                          ⭐ licences       ⭐ days-to-weeks (procurement)
                          ⭐ new region     ⭐ weeks (design + test)
                          ⭐ a trained person ⭐ MONTHS
        │
        ▼
   ⭐ ORDER DATE = date-you-hit-the-limit MINUS lead time MINUS safety margin
```

⭐ **The output of capacity planning is a *date to act*, not a number.** ⭐ **Knowing you will exhaust
quota in 90 days is useless if the increase takes 5 days and nobody diarised it.**

⭐ **Use measured growth, not planned growth.** The business plan says 40 %; the trailing six months
say 6 % per month. ⭐ **Plan on the measurement and hold the plan as an upside scenario** — and say
explicitly which you used.

---

## 4. Worked example — from a measurement to a date

```
RESOURCE   Entra ID P2 licences
Current    ⭐ 47 of 50 assigned          (⭐ 94 % utilised)
Growth     ⭐ measured: +3 per month over the trailing 6 months
Lead time  ⭐ 10 business days (procurement + PO + activation)
⭐ Safety   1 month

  Headroom = 50 − 47 = 3 seats
  ⭐ Months to exhaustion = 3 / 3 = ⭐ 1 month  →  ⭐ ~2026-09-18
  ⭐ ORDER BY = 2026-09-18 − 10 business days − 1 month
             = ⭐ 2026-08-04   ⭐ ← ⭐ ALREADY PASSED. Order today.
```

⭐ **The arithmetic converts "94 % used" — which sounds like a warning — into "you are already
late", which is an action.** ⭐ **That transformation is the whole value of this topic**, and it takes
four lines.

**The same method for compute, where the utilisation curve sets the ceiling:**

```
RESOURCE   App Service plan, ⭐ P2v3 × 4 instances
Peak CPU   ⭐ 72 % at 10:00 weekdays
Growth     ⭐ +4 % relative per month (measured)

⭐ CEILING is NOT 100 %. ⭐ Past ~80 % latency degrades hyperbolically
   (../performance-engineering/ §3) — ⭐ so 80 % IS the limit.

  72 → 80 %  at  +11 % relative growth  ≈ ⭐ 2.7 months
  ⭐ Scale-out lead time: minutes (autoscale) — ⭐ BUT
  ⭐ the vCPU QUOTA increase behind it: ⭐ 1-3 days
  ⭐ → verify quota headroom NOW, not when autoscale fires
```

⭐ **This is the trap that catches people who believe elasticity is unconditional: autoscale is
instant, and the quota behind it is not.** ⭐ **An autoscale rule that cannot obtain the vCPUs fails
silently under exactly the load it was created for** — and the error appears in the activity log, not
in the application.

⭐ **Treat 80 % as the ceiling for anything latency-sensitive**, not 100 %. The remaining 20 % is not
waste; ⭐ **it is the difference between degraded and collapsed.**

---

## 5. Commands — measure headroom, including the limits nobody watches

```powershell
# ⭐ vCPU quota by family - the limit behind every autoscale rule
Get-AzVMUsage -Location westeurope |
  Where-Object { $_.Limit -gt 0 -and ($_.CurrentValue / $_.Limit) -gt 0.6 } |
  Select-Object @{n='Resource';e={$_.Name.LocalizedValue}}, CurrentValue, Limit,
                @{n='Pct';e={[math]::Round(100*$_.CurrentValue/$_.Limit)}}
```

```
Resource                       CurrentValue  Limit  Pct
Standard DSv3 Family vCPUs               74    100   74
Total Regional vCPUs                    120    200   60
⭐ Public IP Addresses                    58     60   ⭐ 97
```

⭐ **97 % of the public IP quota is the finding, and nobody has an alert on it.** ⭐ **The next
deployment that needs a public IP fails**, and the error will be read as a deployment bug for an
hour before anyone checks a quota.

**Licences — the identity engineer's capacity metric:**

```powershell
Get-MgSubscribedSku | Select-Object SkuPartNumber,
  @{n='Enabled';e={$_.PrepaidUnits.Enabled}}, ConsumedUnits,
  @{n='Free';e={$_.PrepaidUnits.Enabled - $_.ConsumedUnits}},
  @{n='Pct';e={[math]::Round(100*$_.ConsumedUnits/$_.PrepaidUnits.Enabled)}}
```

```
SkuPartNumber        Enabled  ConsumedUnits  Free  Pct
SPE_E5                    50             47     3   94
AAD_PREMIUM_P2            25             25     0  100   ⭐
EMS                      100             62    38   62
```

⭐ **`AAD_PREMIUM_P2` at 100 % with zero free seats means PIM cannot be extended to one more
administrator today.** ⭐ **That is a capacity constraint expressed as a security constraint** — and
it is the kind of finding that connects operations work to the SC-300 material directly.

⭐ **Put both of these queries on a monthly schedule with an 80 % threshold.** ⭐ **A capacity alert
is cheap; a blocked deployment during a launch is not.**

⚠ `⚠ check` — quota names, limits and the exact cmdlets differ by subscription type and region;
verify against your own subscription rather than assuming defaults.

---

## 6. When and where

| Situation | Approach |
|---|---|
| Steady-state service | ⭐ quarterly review of the §5 queries |
| ⭐ Known event (launch, enrolment, Black Friday) | ⭐ model it, ⭐ raise quotas **weeks** before |
| ⭐ Rapid growth | monthly, ⭐ with an alert at 80 % |
| ⭐ Migration project | ⭐ **licences and quotas are a project dependency** — [`../../45-m365-migration-engineering/discovery-and-assessment/`](../../45-m365-migration-engineering/discovery-and-assessment/) |
| Cost pressure | ⭐ right-size **down** — capacity planning works both ways |

⭐ **Seasonal businesses need the plan built around their calendar, not the year's average.** A
retailer whose December is 8× November has a capacity plan with a date on it — ⭐ **and a change
freeze to match** ([`../change-management/`](../change-management/) §6).

⭐ **The people dimension belongs in the plan and is almost always omitted.** ⭐ **If one engineer is
the only person who can operate a system, capacity is bounded by their availability** — and the lead
time to fix that is months, which makes it the longest lead time on the list.

---

## 7. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| ⭐ Autoscale fails under load | ⭐ **quota, not capacity** | ⭐ check quota headroom in advance |
| Deployment fails, "limit exceeded" | ⭐ an unwatched limit (IPs, NICs) | §5 sweep |
| ⭐ Onboarding blocked | ⭐ no licences | ⭐ licence capacity in the monthly review |
| Latency degrades before CPU is "full" | ⭐ ceiling assumed to be 100 % | ⭐ plan to 80 % |
| Plan wrong by 3× | ⭐ used the business plan | ⭐ use measured growth |
| ⭐ Knew the limit, still hit it | ⭐ **lead time not subtracted** | ⭐ the order date, diarised |
| Only one person can operate it | people not in the plan | cross-train — ⭐ months of lead time |

⭐ **"Knew the limit, still hit it" is the most frustrating and most common failure**, and it is
purely procedural. ⭐ **A capacity report with no date and no owner changes nothing** — the artifact
must be a diary entry, not a chart.

---

## 8. Customer discovery questions

1. ⭐ **"What runs out first — compute, licences, or people?"**
2. "What is your measured growth rate, and over what period?"
3. ⭐ **"How long does a quota increase take in your organisation?"**
4. "Do you have alerts on quota and licence utilisation?"
5. ⭐ **"What is your peak, and when is it?"**
6. "Has autoscale ever failed to scale?"
7. ⭐ **"Which systems can only one person operate?"**

---

## 9. Remember it

**Hook — `U G L`: Usage, Growth, Lead time → ⭐ **a date**.** ⭐ Not a number — a date to act.

**Analogy — a hospital's oxygen supply.** ⭐ **You do not order more when the tank is empty; you
order when the level, the consumption rate and the delivery time say to** — and the delivery time is
the part that kills you. The analogy predicts every rule here: ⭐ **you monitor consumption rather
than remaining volume, you keep reserve because demand spikes without warning, and — the part
everyone forgets — ⭐ having the tank means nothing if nobody is trained to change it over.**

**The one line:** ⭐ **Order date = exhaustion date − lead time − safety margin, and the ceiling is
80 %, not 100 %.**

---

## 10. Self-test

1. What is the output of capacity planning?
   → ⭐ A dated action, not a utilisation number.
2. Why plan to 80 % rather than 100 % for latency-sensitive workloads?
   → ⭐ Latency degrades hyperbolically past the knee; the last 20 % is protection, not waste.
3. Why can autoscale fail even though the cloud is "elastic"?
   → ⭐ The vCPU quota behind it is finite and takes days to raise.
4. Measured growth or the business plan?
   → ⭐ Measured. Hold the plan as an upside scenario, and say which you used.
5. Which capacity limit blocks onboarding, and what is its lead time?
   → ⭐ Licences; procurement, so days-to-weeks.
6. Which resource has the longest lead time of all?
   → ⭐ A trained person — months.
7. You know the limit and still hit it. What failed?
   → ⭐ Lead time was not subtracted and no date was diarised with an owner.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | the quota and licence sweeps, with any item over 80 % identified |
| `operations` | ⭐ one capacity calculation ending in an **order date** |
| `break-fix` | one deployment or scale event blocked by a limit, and the resolution |
| `architecture-decisions` | the headroom target chosen, justified by the utilisation curve |
| `customer-use-cases` | ⭐ the seasonal or event capacity plan, with dates |
