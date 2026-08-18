# Alerts and Action Groups

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **An alert nobody acts on is worse than no alert — it trains people to ignore the console.**
> Pairs with [`../azure-monitor/`](../azure-monitor/) and
> [`../incident-command/`](../incident-command/).

---

## 1. What it is

The rule that evaluates telemetry and fires (**alert rule**), and the reusable list of who is told
and what is triggered (**action group**). Separating the two is the design: ⭐ **many rules, few
action groups**, so changing the on-call rota is one edit rather than sixty.

---

## 2. Why it exists — and why most implementations fail

⭐ **The failure mode is never "we had no alerts". It is "we had four hundred."**

| Anti-pattern | ⭐ What it produces |
|---|---|
| Alert on everything measurable | ⭐ **alert fatigue** — the real one is on page three |
| ⭐ Alerts to a shared mailbox | ⭐ nobody owns it, so nobody reads it |
| No severity discipline | ⭐ everything Sev1 → ⭐ nothing is Sev1 |
| ⭐ Alert with no runbook | woken at 03:00 with no idea what to do |
| Alert nobody can action | ⭐ *"disk is full on a machine I don't own"* |

⭐ **The test for whether an alert should exist: if it fires at 03:00, is there something a human
must do *right now*?** If the answer is no, it is a dashboard tile or a weekly report — ⭐ **not an
alert.** This single question typically removes 60–80 % of a mature-but-noisy alert estate.

---

## 3. How it works underneath

```
SIGNAL                RULE                       ⭐ ACTION GROUP (reusable)
─────────────────────────────────────────────────────────────────────────────
metric  ──┐                                      ┌─ email / SMS / push / voice
log     ──┤   condition + threshold              ├─ ⭐ webhook → PagerDuty/Teams
activity──┼──► evaluation frequency  ──► FIRES ──┼─ ⭐ Logic App / Function
resource  │   ⭐ window size                      ├─ Automation runbook
health  ──┘   ⭐ auto-mitigate                    └─ ITSM connector
                     │
              ⭐ ALERT PROCESSING RULE
              ⭐ suppress during a maintenance window,
                 or route by resource group ⭐ WITHOUT editing each rule
```

⭐ **Two numbers control every log alert, and confusing them causes both missed and duplicated
alerts:**

| Setting | Meaning | Getting it wrong |
|---|---|---|
| ⭐ **Window size** | how much data each evaluation looks at | ⭐ too small → misses slow-building problems |
| ⭐ **Evaluation frequency** | how often the query runs | ⭐ ≫ window → **gaps you never see** |

⭐ **If frequency is longer than the window, there are blind spots between evaluations.** A 5-minute
window evaluated every 15 minutes examines 5 minutes out of every 15 — ⭐ **two thirds of the time is
simply not looked at**, and nothing in the portal warns you.

⭐ **Rule of thumb: frequency ≤ window.** Overlap is safe; gaps are not.

---

## 4. Worked example — the same signal, right and wrong

**Scenario:** alert when failed sign-ins spike, to catch password spraying.

⭐ **The naive version, and why it is useless:**

```kusto
SigninLogs | where ResultType == 50126 | where TimeGenerated > ago(5m)
```
```
Threshold: > 0 results        ⭐ fires ~40 times a day. Ignored by week two.
```

⭐ **The version that earns its 03:00 page — spray has a shape, and the shape is the detection:**

```kusto
SigninLogs
| where TimeGenerated > ago(15m)
| where ResultType == 50126                       // wrong password
| summarize Targets  = dcount(UserPrincipalName),
            Attempts = count()
    by IPAddress
| where Targets >= 15 and Attempts >= 30          // ⭐ MANY USERS, ONE SOURCE
```

```
IPAddress        Targets  Attempts
198.51.100.77         41       206
```

⭐ **The distinguishing feature of password spray is *one source against many accounts*, not volume
against one account** — that second pattern is brute force, and smart lockout already handles it.
⭐ **Encoding the attack's shape rather than a count is what turns a noisy alert into an actionable
one**, and it is exactly the reasoning an interviewer is listening for.

**The rule, with the two numbers made explicit:**

```powershell
New-AzScheduledQueryRule -Name 'ALRT-SEC-PasswordSpray' -ResourceGroupName rg-monitor `
  -Location westeurope -Scope $workspaceId -Severity 1 -Enabled `
  -WindowSize (New-TimeSpan -Minutes 15) `
  -EvaluationFrequency (New-TimeSpan -Minutes 10) `   # ⭐ <= window: overlap, no gaps
  -CriterionAllOf @($criteria) -ActionGroupResourceId $agSecOnCall `
  -MuteActionsDuration (New-TimeSpan -Hours 1)        # ⭐ one page, not sixty
```

⭐ **`MuteActionsDuration` is the difference between an alert and a denial-of-service on your
on-call engineer.** An ongoing spray re-fires every evaluation; ⭐ **without mute, a single incident
generates dozens of pages and the responder starts deleting notifications** — which is how the
*next* alert gets missed.

---

## 5. Severity — make it mean something

⭐ **Severity is a promise about response, not a description of feeling.** Write it down:

| Sev | Meaning | ⭐ Response promised |
|---|---|---|
| **0** | Critical — service down | ⭐ page immediately, 24×7 |
| **1** | Error — ⭐ degraded or a live security event | page in hours; ⭐ 24×7 if security |
| **2** | Warning — ⭐ will become Sev1 if ignored | next business day |
| **3** | Informational | ⭐ ticket, no page |
| **4** | Verbose | ⭐ **not an alert. Delete it** |

⭐ **The rule that keeps this honest: if nobody would be woken for it, it is not Sev0 or Sev1.**
Once "everything is critical", severity carries no information and the routing built on it is
decoration.

**Action groups, structured by *who responds*, not by *what fired*:**

```
AG-SEC-ONCALL     → PagerDuty (⭐ 24x7 rota)         ← Sev0/1 security
AG-PLATFORM-BH    → Teams channel + email           ← Sev2 business hours
AG-TICKET-ONLY    → ⭐ ITSM connector, no notification ← Sev3
```

⭐ **Three action groups can serve a hundred rules.** The on-call rota changes in one place — and
⭐ **an alert estate where every rule has its own email list is unmaintainable within a year**, which
is usually the state you inherit.

---

## 6. Commands — audit the estate you inherited

```powershell
Get-AzScheduledQueryRule | Select-Object Name, Enabled, Severity |
  Group-Object Severity | Select-Object Name, Count
```

```
Name Count
0        2
1        7
2       14
3       61
```

```powershell
# ⭐ The real question: which fired, and did anyone do anything?
Get-AzAlert -TimeRange 30d -IncludeContext |
  Group-Object Name | Select-Object Name, Count |
  Sort-Object Count -Descending | Select-Object -First 3
```

```
Name                              Count
ALRT-VM-CPU-High                    884
ALRT-Storage-Availability            96
ALRT-SEC-PasswordSpray                1
```

⭐ **884 firings in 30 days is roughly one every 50 minutes — that alert is furniture.** Either the
threshold is wrong or the condition is not actionable. ⭐ **And the one that fired once is the one
that mattered — it was on page nine of the same inbox.**

⭐ **Run this query in the first week of any operations engagement.** *"Your top alert fired 884
times and generated zero tickets"* is a finding the customer cannot argue with, and it opens the
whole alert-hygiene conversation.

⚠ `⚠ check` — `Get-AzAlert` parameters and the alert-management API surface have changed; confirm
against your Az module version.

---

## 7. When and where

| Signal | Alert type |
|---|---|
| Platform numeric threshold | ⭐ metric alert — fastest, cheapest |
| Correlation or "who did what" | log (scheduled query) alert |
| Resource deleted / policy changed | ⭐ activity log alert |
| Azure-side outage | ⭐ **service health alert** — ⭐ everyone should have one |
| ⭐ Planned maintenance | ⭐ alert **processing rule** to suppress — not disabling rules by hand |

⭐ **The service health alert is the cheapest high-value alert in Azure and most tenants do not have
one.** It tells you Microsoft is having an incident in your region — ⭐ **which stops your team from
spending an hour debugging their own code during someone else's outage.**

⭐ **Never disable rules for a maintenance window.** They get re-enabled late, or not at all. ⭐ **An
alert processing rule with a time window expires by itself** — reversible by construction.

---

## 8. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| Real incident missed | ⭐ fatigue from noisy rules | delete the furniture; §6 audit |
| ⭐ Blind spots between evaluations | ⭐ frequency > window | ⭐ frequency ≤ window |
| 60 pages for one incident | ⭐ no `MuteActionsDuration` | set it |
| Alerts stopped after a rota change | rota inside each rule | ⭐ action groups by responder |
| Alert fires, nobody knows what to do | ⭐ no linked runbook | ⭐ every Sev0/1 links a runbook |
| Rules still disabled a week later | manual maintenance suppression | ⭐ alert processing rule |
| Email limit hit during an incident | ⭐ action group rate limits | ⭐ webhook to a paging tool, not email |

⭐ **Action groups are rate-limited** — email, SMS and voice all have caps, ⚠ check current values.
⭐ **During a large incident, email is exactly when you exceed them**, which is why serious on-call
runs through a webhook to a paging platform rather than a mail rule.

---

## 9. Customer discovery questions

1. ⭐ **"Which alert fired most last month, and what did anyone do about it?"**
2. "Who is paged at 03:00, and how — email, or a paging tool?"
3. ⭐ **"Does every Sev0 and Sev1 alert have a runbook link?"**
4. "Do you have a service health alert?"
5. ⭐ **"What do you do to alerts during planned maintenance?"**
6. "How many action groups, and do they map to rotas or to services?"
7. "When did you last delete an alert rule?" (⭐ never = the estate only grows)

---

## 10. Remember it

**Hook — `A A A`: Actionable, Attributable, Acted-on.** ⭐ If an alert fails any one, delete it.

**Analogy — a car with 40 warning lights.** ⭐ **A single amber engine light gets attention; forty
lights, three permanently on because "that sensor's always been like that", means the driver stops
looking at the dashboard entirely.** The analogy predicts everything here: ⭐ **the always-on light
is the 884-firing CPU alert, and its real cost is not itself — it is the fuel-pressure light nobody
noticed underneath it.**

**The one line:** ⭐ **If nobody must act at 03:00, it is a dashboard, not an alert — and keep
frequency ≤ window.**

---

## 11. Self-test

1. The test for whether something should be an alert?
   → ⭐ At 03:00, must a human do something right now?
2. Why must evaluation frequency be ≤ window size?
   → ⭐ Otherwise there are unexamined gaps between evaluations.
3. What shape distinguishes password spray from brute force?
   → ⭐ Many accounts from one source, versus many attempts against one account.
4. What does `MuteActionsDuration` prevent?
   → ⭐ Dozens of pages from one ongoing incident, which trains responders to ignore alerts.
5. Should action groups be organised by service or by responder?
   → ⭐ By responder — the rota changes in one place.
6. Correct way to handle alerts during maintenance?
   → ⭐ An alert processing rule with a time window; never disable rules by hand.
7. Which cheap, high-value alert is usually missing?
   → ⭐ Service health — it stops you debugging Microsoft's outage.

---

## 12. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | one metric and one log alert created, fired deliberately, and observed |
| `security` | ⭐ the password-spray rule with a real firing, and the investigation it triggered |
| `operations` | ⭐ the §6 audit: top-firing alerts vs tickets raised |
| `break-fix` | one alert deleted or retuned, with the reasoning |
| `architecture-decisions` | the severity definitions and the action-group-per-responder map |
