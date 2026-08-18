# Log Analytics

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The workspace is a cost decision, a security boundary and a query surface — in that order of
> how often people get it wrong.** Pairs with [`../azure-monitor/`](../azure-monitor/) and
> [`../../50-security-operations/`](../../50-security-operations/).

---

## 1. What it is

The store and query engine behind Azure Monitor logs: a **workspace** holds tables of structured
records, queried with **KQL** (Kusto Query Language). Microsoft Sentinel, Defender for Cloud, VM
Insights and Application Insights all sit on top of workspaces.

⭐ **You do not design a workspace for queries. You design it for who may read the data and who pays
for it** — the query language is the easy part.

---

## 2. Why it exists

⭐ **Because the alternative is grep on ten machines during an incident.** But the reason it needs
*design* is less obvious:

| Decision | Gets made by accident | ⭐ Consequence |
|---|---|---|
| ⭐ How many workspaces | one per team, organically | ⭐ **cannot correlate across them cheaply** |
| ⭐ Who can read it | workspace Contributor to all | ⭐ sign-in logs are personal data |
| Retention per table | ⭐ one global setting | ⭐ paying Analytics prices for debug noise |
| Table plan | default Analytics | 3–5x the necessary ingestion cost ⚠ check |

⭐ **The workspace count decision is the one that is expensive to reverse.** Cross-workspace queries
work, but they add friction to every query, complicate RBAC, and split Sentinel's analytics. ⭐ **Two
workspaces need a reason — data residency, a hard security boundary, or separate billing owners —
not "different teams".**

---

## 3. How it works underneath — plans, retention, and where the money goes

```
INGEST ──► TABLE ──► ⭐ TABLE PLAN decides price and capability
                      │
                      ├─ ⭐ ANALYTICS   full KQL · alerts · ⭐ full price
                      ├─ ⭐ BASIC       ⭐ cheap ingest · ⭐ limited KQL ·
                      │                 ⭐ short interactive retention ·
                      │                 ⭐ pay-per-query
                      └─ AUXILIARY     ⭐ cheapest · high-volume/verbose
                              │
                              ▼
              INTERACTIVE RETENTION  (queryable now)
                              │
                              ▼
              ⭐ LONG-TERM / ARCHIVE  ⭐ cheap to keep, ⭐ PAY TO SEARCH
                              │
                              └─ ⭐ search job / restore to query it
```

⭐ **The trade is always the same: cheap to store, expensive to ask.** Archive is correct for logs
you must *retain* and rarely *read* (compliance); it is wrong for logs you troubleshoot with weekly.

⭐ **Basic/Auxiliary plans do not support all alert types.** Putting a table on a cheap plan can
silently disable the alert built on it — ⭐ **a cost optimisation that removes a detection is a
security regression, and nothing warns you.**

⚠ `⚠ check` — table-plan names, per-plan retention floors, query limitations and pricing have
changed repeatedly. **Verify each against current Microsoft documentation before writing them into a
design.** The *shape* of the trade-off is stable; the numbers are not.

---

## 4. Worked example — one KQL query, read line by line

⭐ **Failed sign-ins grouped by error code — the query that starts most identity investigations:**

```kusto
SigninLogs
| where TimeGenerated > ago(24h)                       // ⭐ ALWAYS first — see below
| where ResultType != 0                                 // 0 = success
| summarize Attempts = count(),
            Users    = dcount(UserPrincipalName)
    by ResultType, ResultDescription
| order by Attempts desc
| take 5
```

```
ResultType  ResultDescription                            Attempts  Users
50126       Invalid username or password                     1841     37
50053       ⭐ Account is locked (smart lockout)                412      9
50076       ⭐ MFA required, user did not complete              208     61
50158       External security challenge not satisfied           44      6
0           —                                                    —      —
```

⭐ **Read the third row as an operator, not a reporter: 208 attempts across 61 users means MFA
prompts are being abandoned.** That is either a usability problem or an attack in progress, and the
next query — ⭐ same users, grouped by location — tells you which.

⭐ **`| where TimeGenerated > ago(24h)` must come first, and it is not stylistic.** The time filter
selects which partitions are read; ⭐ **placing it after a `summarize` makes the engine scan the
full retention window** — the difference between a two-second query and a timeout on a large
workspace. **Filter early, filter on time first, project only what you need.**

**The cost query — run this monthly, it pays for itself:**

```kusto
Usage
| where TimeGenerated > ago(30d) and IsBillable == true
| summarize GB = round(sum(Quantity)/1000, 1) by DataType
| order by GB desc
| take 5
```

```
DataType             GB
AzureDiagnostics  412.7
ContainerLog       88.4
SigninLogs         31.2
AuditLogs           9.8
Perf                7.1
```

⭐ **`AzureDiagnostics` at 412 GB is 78 % of this bill from one table**, and it is nearly always a
handful of chatty categories on a handful of resources. ⭐ **Find them, decide whether anyone has
ever queried them, and filter at the DCR** — see [`../azure-monitor/`](../azure-monitor/) §5.

⭐ **"Has anyone ever queried this table?" is the right question, and it is answerable** — workspace
query audit logs will tell you. ⭐ **A table nobody has queried in six months, retained for a year at
Analytics prices, is pure waste.**

---

## 5. Commands — workspace facts you should know before designing

```powershell
Get-AzOperationalInsightsWorkspace |
  Select-Object Name, Location, Sku, RetentionInDays, PublicNetworkAccessForQuery
```

```
Name          Location   Sku            RetentionInDays  PublicNetworkAccessForQuery
law-contoso   westeurope PerGB2018                   90  Enabled
```

```powershell
# Per-table retention - where the real savings are
Get-AzOperationalInsightsTable -ResourceGroupName rg-monitor -WorkspaceName law-contoso |
  Select-Object Name, Plan, RetentionInDays, TotalRetentionInDays |
  Where-Object RetentionInDays -gt 90 | Select-Object -First 3
```

```
Name              Plan       RetentionInDays  TotalRetentionInDays
SigninLogs        Analytics              365                  730
AuditLogs         Analytics              365                  730
ContainerLog      Analytics              365                  365
```

⭐ **`ContainerLog` at 365 days is almost certainly an accident** — container stdout retained for a
year at full price. Sign-in and audit logs at 365 days are deliberate and defensible; ⭐ **the skill
is telling the two apart, per table, and writing down why.**

⚠ `⚠ check` — table-level retention cmdlet and property names vary by Az module version.

---

## 6. When and where

| Situation | Workspace design |
|---|---|
| Single tenant, one team | ⭐ **one workspace**. Resist splitting |
| Data residency requirement | one per region — ⭐ a real reason |
| ⭐ Sentinel in use | ⭐ **same workspace as the security logs**, or detections cannot correlate |
| MSP with many customers | one per customer, ⭐ Azure Lighthouse for cross-query |
| Dev vs prod | ⭐ separate — ⭐ different retention, different readers, different noise |

⭐ **RBAC is the part people skip.** Sign-in logs contain IP addresses, locations and device
identifiers — ⭐ **personal data under GDPR.** *Log Analytics Reader* on a workspace containing
`SigninLogs` grants visibility into where every employee was; ⭐ **use table-level RBAC and resource-
context access rather than granting workspace-wide read to a whole team.**

---

## 7. What breaks

| Symptom / error | Cause | Fix |
|---|---|---|
| `Query exceeded the maximum allowed time` | ⭐ time filter late or missing | ⭐ `where TimeGenerated` **first** |
| Table empty but resource is running | ⭐ no diagnostic setting | [`../azure-monitor/`](../azure-monitor/) §4 |
| Alert stopped firing after a cost review | ⭐ **table moved to a cheap plan** | ⭐ verify alert support per plan |
| Cannot query data from last year | ⭐ archived, not deleted | ⭐ search job / restore — **and it costs** |
| Cross-workspace query fails | permission on the *other* workspace | grant read on both |
| ⭐ Bill grew 4x with no new resources | verbose category enabled by a template | ⭐ the §4 `Usage` query |
| Everyone can read `SigninLogs` | workspace-wide RBAC | ⭐ table-level / resource-context |

⭐ **"Alert stopped firing after a cost review" is the most dangerous row in this file**, because the
cost saving is visible and the lost detection is not. ⭐ **Any table-plan change must be checked
against the alerts built on that table, in the same change.**

---

## 8. Customer discovery questions

1. ⭐ **"How many workspaces, and why more than one?"**
2. "What is your monthly ingestion, and which table is the largest?"
3. ⭐ **"Which tables has anyone actually queried in the last 90 days?"**
4. "How long must security logs be retained, and who mandates that?"
5. ⭐ **"Who can read sign-in logs, and is that a deliberate decision?"**
6. "Is Sentinel on this workspace or a different one?"
7. "Have you ever restored archived data, and do you know what it cost?"

---

## 9. Remember it

**Hook — `T P R` per table: Table, Plan, Retention.** Three decisions, made per table, not once
globally.

**Analogy — a warehouse with three storage rates.** ⭐ **Shelf space by the door is expensive and
you can grab anything instantly (Analytics); the back racks are cheaper but you can only do simple
retrieval (Basic); the offsite depot is nearly free to keep and you pay a fee every time you send a
van (archive).** The analogy predicts each failure: ⭐ **moving something to the depot to save money
and then discovering the alarm system needed to see it hourly** is exactly the table-plan
regression, and ⭐ **paying door-shelf rates for boxes nobody has opened in six months** is the
retention overspend.

**The one line:** ⭐ **Filter on time first, decide retention per table by the question it answers,
and never change a table's plan without checking the alerts built on it.**

---

## 10. Self-test

1. Why must the time filter come first in KQL?
   → ⭐ It selects partitions; late filtering scans the whole retention window.
2. Trade-off of archive/long-term retention?
   → ⭐ Cheap to store, pay per search, not instantly queryable.
3. Hidden risk of moving a table to a cheaper plan?
   → ⭐ Alerts built on it may silently stop working.
4. When is a second workspace justified?
   → ⭐ Data residency, a hard security boundary, or separate billing ownership — not team structure.
5. Why is `SigninLogs` access a privacy decision?
   → ⭐ IPs, locations and devices are personal data; workspace-wide read exposes employee movement.
6. One query to find the top cost driver?
   → ⭐ `Usage | where IsBillable | summarize sum(Quantity) by DataType`.
7. `ContainerLog` retained 365 days — deliberate or accident?
   → ⭐ Almost certainly accident. Ask what question it answers at month eleven.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | the failed-sign-in query with real output, and the follow-up query it prompted |
| `security` | table-level RBAC applied to `SigninLogs`, with the before/after permission set |
| `operations` | ⭐ the monthly `Usage` output and one filtering change made because of it |
| `break-fix` | one query timeout fixed by filter placement |
| `architecture-decisions` | ⭐ retention and plan per table, each with the question it answers |
