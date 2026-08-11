# KQL — Kusto Query Language

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The highest-leverage skill in this entire domain.** Sentinel, Defender, Log Analytics,
> Resource Graph and Application Insights all speak it. Learn it once, use it in every product —
> and it is the skill that visibly separates operators from analysts in an interview.

---

## 1. What it is

A read-only query language for **large, append-only, time-series datasets**. You start with a table
and pipe it through operators, each transforming the result.

```kusto
SigninLogs
| where TimeGenerated > ago(1d)
| where ResultType != 0
| summarize Failures = count() by UserPrincipalName
| top 10 by Failures desc
```

If you can read that, you already have the model. Everything else is vocabulary.

---

## 2. Why it exists, and why SQL habits hurt

SQL was designed for **normalised, mutable, relational** data. Security telemetry is the opposite:
enormous, **append-only**, semi-structured, and almost always filtered by time first.

KQL is built for that shape:

- **Pipeline, not nested.** You read left to right, top to bottom, in execution order. SQL reads
  inside-out.
- **Time is a first-class citizen.** `ago()`, `bin()`, `between()` are core, not add-ons.
- **Schema-on-read.** Dynamic columns are parsed at query time, so log shapes can vary.

> **The mental shift from SQL: stop composing a single statement, start building a conveyor belt.**
> Write one line, run it, look, add the next line. Beginners write twenty lines then debug; experts
> run the query twenty times.

---

## 3. How it works underneath — the operators that cover 90% of real work

| Operator | Does | Note |
|---|---|---|
| `where` | Filter rows | ⭐ **Always filter time first** |
| `project` / `project-away` | Choose / drop columns | Reduces data moved |
| `extend` | Add a computed column | |
| `summarize` | Aggregate **by** groups | The workhorse |
| `join` | Combine tables | Expensive — see §5 |
| `union` | Stack tables | `union withsource=Table *` searches everything |
| `sort` / `top` | Order / order + limit | `top` is cheaper than `sort` + `take` |
| `mv-expand` | One row per array element | Essential for `AuthenticationDetails` |
| `parse_json()` / `todynamic()` | Read nested JSON | |
| `let` | Name a value or subquery | Readability and reuse |
| `bin()` | Round time into buckets | `bin(TimeGenerated, 1h)` |
| `make-series` | Time series with gaps filled | For anomaly detection |
| `externaldata` | Pull a remote list | Threat-intel indicators |

### The performance rule that matters more than all the others

```kusto
// ✗ SLOW - scans everything, then filters
SigninLogs
| where UserPrincipalName == "priya@contoso.com"
| where TimeGenerated > ago(7d)

// ✅ FAST - time first, so most data is never read
SigninLogs
| where TimeGenerated > ago(7d)
| where UserPrincipalName == "priya@contoso.com"
```

> ⭐ **Filter on time first, always.** Log Analytics partitions by time; a time predicate lets the
> engine skip entire partitions. Every other optimisation is rounding error next to this one.

**Then:** filter before `summarize`, `project` before `join`, and use `has` rather than `contains` —
`has` matches whole terms and uses the index; `contains` is a substring scan.

---

## 4. Worked example — building a real detection, one line at a time

**Goal:** find accounts where a failed-password burst is followed by a success — the signature of a
successful password-spray or brute-force.

**Step 1 — look at the data before assuming its shape.** Always start here:

```kusto
SigninLogs
| where TimeGenerated > ago(1h)
| take 10
```

**Step 2 — understand the field that matters.** `ResultType` is a string, and `0` means success:

```kusto
SigninLogs
| where TimeGenerated > ago(1d)
| summarize Count = count() by ResultType, ResultDescription
| top 15 by Count desc
```

```
ResultType  ResultDescription                                    Count
----------  -------------------------------------------------    -----
0           (blank - success)                                     48213
50126       Invalid username or password                           1043
50053       Account locked / IP blocked due to repeated attempts     87
50076       MFA required (Conditional Access)                       412
50158       External security challenge not satisfied                19
```

⭐ **Learn these codes; they turn a wall of failures into a story.** `50126` is a wrong password.
**`50053` means the smart-lockout defended you.** `50076` is not a failure at all — it is CA
correctly demanding MFA, and counting it as "failed sign-ins" is how dashboards mislead people.

**Step 3 — the detection:**

```kusto
let window = 1h;
let failThreshold = 8;
SigninLogs
| where TimeGenerated > ago(1d)
| where ResultType in ("50126", "50053")                  // wrong password / lockout
| summarize Failures    = count(),
            FirstFail   = min(TimeGenerated),
            LastFail    = max(TimeGenerated),
            SourceIPs   = make_set(IPAddress, 10),
            Countries   = make_set(LocationDetails.countryOrRegion, 5)
        by UserPrincipalName
| where Failures >= failThreshold
| join kind=inner (
    SigninLogs
    | where TimeGenerated > ago(1d)
    | where ResultType == 0                                // then a SUCCESS
    | summarize SuccessTime = min(TimeGenerated), SuccessIP = anyif(IPAddress, true)
            by UserPrincipalName
) on UserPrincipalName
| where SuccessTime between (LastFail .. LastFail + window)
| project UserPrincipalName, Failures, FirstFail, LastFail, SuccessTime, SuccessIP, SourceIPs, Countries
| sort by Failures desc
```

**Why each clause earns its place** — this is the part worth internalising:

- `let` at the top makes thresholds tunable without hunting through the query
- `in (...)` beats chained `or` for readability and speed
- `make_set` collapses many rows into one reviewable cell — an analyst sees the whole picture per row
- `join kind=inner` keeps only users who failed **and then** succeeded
- `between (LastFail .. LastFail + window)` enforces **causality** — success *after* the failures,
  not merely on the same day. Without it you match every normal user who mistyped once.

**Step 4 — reduce false positives.** Real detections are mostly exclusions:

```kusto
| where not(SuccessIP in (SourceIPs))          // same IP = probably just a forgetful user
| where Countries !has "United Kingdom"        // or exclude your own corporate egress IPs
```

---

## 5. `join` — where queries go to die

`join` is the most expensive operator and the most misused.

```kusto
// The default is kind=innerunique - it DEDUPLICATES the left side and surprises everyone
T1 | join       (T2) on Key      // innerunique - silently drops duplicate left rows
T1 | join kind=inner (T2) on Key // true inner join - what you usually meant
```

> ⭐ **KQL's default join is `innerunique`, not `inner`.** It de-duplicates the left table first.
> Counts that are mysteriously too low are usually this. **Always write `kind=` explicitly.**

**Put the smaller table on the left** — the opposite of the SQL instinct — because KQL broadcasts
the left side.

**Often you do not need a join at all.** This is the trick that separates fast queries from slow:

```kusto
// Instead of joining two tables to correlate, union and summarize
union
  (SigninLogs | where TimeGenerated > ago(1d) | extend Src = "Signin"),
  (AuditLogs  | where TimeGenerated > ago(1d) | extend Src = "Audit")
| summarize Events = make_set(Src), Count = count() by UserPrincipalName
| where array_length(Events) > 1
```

---

## 6. Unpacking dynamic columns — the skill nobody teaches

Security tables are full of nested JSON, and this trips up everyone at first.

```kusto
SigninLogs
| where TimeGenerated > ago(1d)
| extend City    = tostring(LocationDetails.city),
         Country = tostring(LocationDetails.countryOrRegion),
         OS      = tostring(DeviceDetail.operatingSystem),
         Browser = tostring(DeviceDetail.browser)
| project TimeGenerated, UserPrincipalName, City, Country, OS, Browser
```

⭐ **Always wrap dynamic field access in `tostring()`.** Without it the column stays `dynamic`, and
`==` comparisons quietly fail to match — the query runs, returns nothing, and you assume there is no
data.

**Arrays need `mv-expand`.** This is how you find which authentication methods were actually used:

```kusto
SigninLogs
| where TimeGenerated > ago(1d)
| mv-expand AuthDetail = AuthenticationDetails
| extend Method    = tostring(AuthDetail.authenticationMethod),
         Succeeded = tostring(AuthDetail.succeeded)
| summarize Count = count() by Method, Succeeded
| sort by Count desc
```

```
Method                          Succeeded  Count
------------------------------  ---------  -----
Password                        true       41022
Microsoft Authenticator push    true       12877
Windows Hello for Business      true        6431
Password                        false        983
```

**That output is a real MFA-adoption report** — and it is exactly how you prove whether an External
Authentication Method is satisfying the MFA claim, per
[`../../35-active-directory-and-hybrid-identity/okta-and-third-party-idp/`](../../35-active-directory-and-hybrid-identity/okta-and-third-party-idp/).

---

## 7. The tables worth memorising

| Table | Contains | Trap |
|---|---|---|
| `SigninLogs` | Interactive user sign-ins | ⭐ **Not service principals** |
| `AADNonInteractiveUserSignInLogs` | Token refreshes, background | Huge volume; where quiet abuse hides |
| **`AADServicePrincipalSignInLogs`** | ⭐ **Workload identity sign-ins** | Missing this misses NHI compromise entirely |
| `AADManagedIdentitySignInLogs` | Managed identity usage | |
| `AuditLogs` | Directory changes — who changed what | Consent grants, role assignments |
| `SecurityEvent` | Windows events from agents | Needs data collection rules |
| `DeviceLogonEvents`, `DeviceProcessEvents` | Defender for Endpoint | Advanced hunting schema |
| `IdentityLogonEvents`, `IdentityDirectoryEvents` | Defender for Identity | On-prem AD activity |
| `AzureActivity` | Control-plane operations | Resource creation/deletion |
| `AzureDiagnostics` | Legacy catch-all | Resource-specific tables are better |

> ⭐ **Investigating a compromise using `SigninLogs` alone misses every service principal.**
> Non-human identities outnumber humans in most tenants, and attackers know which table you are
> watching. `AADServicePrincipalSignInLogs` is the one people forget.

**Discover the schema when you land in an unfamiliar tenant:**

```kusto
search *
| where TimeGenerated > ago(1d)
| summarize Rows = count() by $table
| sort by Rows desc
```

---

## 8. What breaks

**No time filter.** Scans everything, times out, costs money.

**Implicit `innerunique` join.** Silently deduplicated results and undercounts.

**Comparing a `dynamic` field without `tostring()`.** No matches, no error.

**`contains` instead of `has`.** Substring scan versus indexed term match.

**Assuming `ResultType == 0` is the only success.** `50076`/`50079` are CA doing its job, not failures.

**Querying `SigninLogs` for service principals.** Wrong table entirely.

**Retention surprises.** Analytics tier is limited; older data may be in a cheaper tier and needs
different access. ⚠ Confirm the workspace retention before promising a 12-month hunt.

**Time zones.** `TimeGenerated` is UTC. Incident timelines drift by hours when someone forgets.

---

## 9. Customer discovery questions

1. What is the workspace **retention**, and what falls off when?
2. Are **`AADServicePrincipalSignInLogs`** and non-interactive sign-ins being collected? *(Often not
   — and that is the finding.)*
3. Which tables are actually connected versus assumed?
4. Are detections written as saved queries with tunable thresholds, or hard-coded?
5. Does anyone review false-positive rates, or are noisy rules just muted?
6. Is there a query library under source control?
7. What is the monthly ingestion cost, and which table dominates it?

---

## 10. Remember it

**Hook — "Time first, always."** Then: **filter before summarize, project before join.**

**Analogy — a conveyor belt, not a paragraph.** SQL asks you to compose one nested statement and
read it inside-out. KQL is a belt: each `|` is a station that transforms what passes through. Build
it one station at a time, running after each — experts run the query twenty times, beginners write
twenty lines and then debug.

**The one thing:** **the default join is `innerunique`, not `inner`.** It silently de-duplicates the
left table, and it is the reason a count comes back mysteriously low. Always write `kind=` explicitly.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 11. Self-test

1. Why must the time filter come first?
2. Difference between `join`, `join kind=inner`, and why it matters?
3. Which side of a join should hold the smaller table, and why?
4. `ResultType` `50126` versus `50053` versus `50076` — what does each tell you?
5. You compare a dynamic field with `==` and get zero rows though data exists. Why?
6. Which table holds service principal sign-ins, and why does it matter?
7. `has` versus `contains`?
8. How do you find which authentication methods actually succeeded?
9. What makes a failed-then-succeeded query a detection rather than noise?

<details>
<summary>Answers</summary>

1. Log Analytics **partitions by time**, so a time predicate lets the engine skip whole partitions.
   It dominates every other optimisation.
2. Bare `join` defaults to **`innerunique`**, which de-duplicates the left table. `kind=inner` is a
   true inner join. The default silently undercounts.
3. **The smaller table on the left** — KQL broadcasts the left side. Opposite of the SQL instinct.
4. `50126` = wrong password. `50053` = **smart lockout fired** (a defence working). `50076` = CA
   requiring MFA — **not a failure**.
5. The column is still **`dynamic`**. Wrap it in `tostring()`.
6. **`AADServicePrincipalSignInLogs`.** `SigninLogs` contains no workload identities, so an
   investigation using it alone misses NHI compromise completely.
7. `has` matches **whole terms** using the index; `contains` is a substring scan.
8. `mv-expand AuthenticationDetails`, then extract `authenticationMethod` and `succeeded`.
9. **Causality** — constrain the success to a window *after* the last failure
   (`between (LastFail .. LastFail + window)`), plus exclusions such as a different source IP.

</details>

---

## 12. Evidence this topic needs

- **`lab/`** — run the §4 detection end to end against real sign-in data; produce the §6 MFA-method
  report. ✗ Needs a tenant with logs; the Cobuman read-only tenant is genuinely useful here because
  it has **populated** data an empty trial never will.
- **`break-fix/`** — write the same query with bare `join` and with `kind=inner`; capture the
  differing row counts. Then compare a dynamic field with and without `tostring()`.
- **`security/`** — confirm `AADServicePrincipalSignInLogs` is being collected; a detection for
  multi-country service principal sign-ins.
- **`operations/`** — a query library in source control with tunable `let` thresholds; ingestion
  cost by table.
- **`architecture-decisions/`** — ADR: retention tier per table, balancing hunt depth against cost.
- **`customer-use-cases/`** — the §9 questions answered against a real workspace.
