# Lab — Microsoft Sentinel: workspace, ingestion, and a detection that fires

**Exam:** SC-200, *Manage a security operations environment* (40–45%) — the heaviest
functional group on the 28 July 2026 blueprint.
**Tenant needed:** yes. **Do this before 2026-09-07**, when the lab resource group
`sc-300-lab-cin-rg-01` is tagged to expire, and before the E5 trial ends 2026-09-10.

You finish this lab able to say, without notes, what happens between a sign-in on a
machine and an incident appearing in the queue — and where it breaks.

---

## 0. Setup

```powershell
az login
az account set --subscription 912ac3b8-d003-48d1-8266-e4d029ba1fd7
az group create -n sc200-lab-rg -l centralindia --tags expires=2026-09-07
az monitor log-analytics workspace create -g sc200-lab-rg -n sc200-law -l centralindia
```

Expected shape:

```
{ "name": "sc200-law", "provisioningState": "Succeeded",
  "retentionInDays": 30, "sku": { "name": "PerGB2018" } }
```

Note `retentionInDays: 30`. That number is the whole of the retention objective on the
blueprint — write it down before you change it.

Then onboard Sentinel onto that workspace in the portal
(**Microsoft Sentinel → Create → select `sc200-law`**). Sentinel is a *solution on a
workspace*, not a separate store: everything you query later is Log Analytics.

---

## 1. Ingest something real

Connect **Microsoft Entra ID** as a data connector and enable `SigninLogs` and
`AuditLogs`. This is the same diagnostic-settings mechanism as the SC-300 monitoring
objective — the connector writes a diagnostic setting on the tenant.

Verify ingestion has actually started rather than assuming it:

```kusto
union withsource=Table *
| where TimeGenerated > ago(1h)
| summarize Rows = count(), Latest = max(TimeGenerated) by Table
| order by Rows desc
```

Expected shape:

```
Table         Rows   Latest
SigninLogs    142    2026-08-29T11:58:03Z
AuditLogs      17    2026-08-29T11:54:11Z
```

**If `Rows` is 0 and you have signed in:** you have hit the single most common Sentinel
misunderstanding. Ingestion is **forward-only**. The connector records nothing from
before it was enabled, and first rows typically appear within about 15 minutes, not
instantly. Wait, sign in again, re-run. Do not start debugging the connector.

---

## 2. Deliberate failure — query the wrong table

Run this and watch it return nothing:

```kusto
SigninLogs
| where TimeGenerated > ago(1d)
| where AppDisplayName == "Azure Portal"
| where ResultType == 0
| take 10
```

…then sign in with a service principal or run a script that uses one, and re-run. Still
nothing.

**Why:** `SigninLogs` holds **interactive user sign-ins only**. Service principal
sign-ins are in `AADServicePrincipalSignInLogs`, managed identities in
`AADManagedIdentitySignInLogs`, and non-interactive user sign-ins in
`AADNonInteractiveUserSignInLogs`. Choosing the wrong table is the number-one reason a
hunting query returns zero rows, and the exam tests exactly this.

Record the empty result set in your journal. An empty table is evidence.

---

## 3. A scheduled analytics rule that actually fires

Create **Analytics → Scheduled query rule**:

```kusto
SigninLogs
| where TimeGenerated > ago(1h)
| where ResultType != 0
| summarize Failures = count() by UserPrincipalName, IPAddress
| where Failures >= 5
```

- Run frequency 5 minutes, lookup period 1 hour
- Entity mapping: `Account` → `UserPrincipalName`, `IP` → `IPAddress`
- MITRE ATT&CK: **Credential Access → T1110 Brute Force**

Now trigger it: fail a sign-in six times with a deliberately wrong password on a test
account. Within two run cycles an incident appears.

**Verify the entity mapping worked.** Open the incident and confirm the account and IP
appear as *entities*, not just as text in the description. Unmapped entities are the
difference between an incident you can pivot from and a log line with extra steps — and
entity mapping is what makes the investigation graph work at all.

---

## 4. Automation rule

Add an **Automation rule** that, when an incident is created by this analytic, sets
severity to Medium and assigns it to you.

Then check the difference the blueprint cares about:

| | Runs on | Does |
|---|---|---|
| **Automation rule** | Incident create/update, or on demand | Assign, tag, change severity, close, run a playbook |
| **Playbook** (Logic App) | Called by an automation rule, or its own trigger | Anything Logic Apps can do — Teams message, ticket, isolate a device |

An automation rule is the *trigger and the simple actions*; a playbook is the *arbitrary
work*. The exam asks you to pick between them.

---

## 5. Retention, and where the blueprint moved

The 28 July 2026 outline says *"Manage data retention for XDR and Microsoft Sentinel
tables, including Analytics, Data lake, and XDR tiers."* Look at the workspace's table
list and note that retention is now set **per table**, and that a table can sit in the
Analytics tier (fast, queryable, expensive) or a cheaper tier for long retention.

```powershell
az monitor log-analytics workspace table show `
  -g sc200-lab-rg --workspace-name sc200-law -n SigninLogs `
  --query "{name:name, plan:plan, retention:retentionInDays, total:totalRetentionInDays}"
```

Expected shape:

```
{ "name": "SigninLogs", "plan": "Analytics", "retention": 30, "total": 30 }
```

---

## 6. Verification — you have finished when

- [ ] `union withsource=Table *` returns rows for `SigninLogs` **and** `AuditLogs`
- [ ] You can state, unprompted, which table holds service principal sign-ins
- [ ] An incident exists that your own rule created, with **mapped** Account and IP entities
- [ ] That incident carries the severity and owner your automation rule set
- [ ] You can name one thing an automation rule cannot do that a playbook can

---

## 7. Evidence to capture

Into `50-security-operations/sentinel/lab/evidence/`:

| Artifact | Why it cannot be reconstructed later |
| --- | --- |
| Screenshot of the incident with entities mapped | Dies with the workspace on 07 Sep |
| The `union withsource` output showing 0 rows, then rows | The forward-only proof |
| The empty result from §2 with the query beside it | Your own wrong-table evidence |
| Verbatim text of any error you hit | The one artifact that cannot be regenerated |

---

## 8. Cleanup

Do this **after** capturing evidence, not before.

```powershell
az group delete -n sc200-lab-rg --yes --no-wait
```

Removing the resource group removes the workspace and the Sentinel solution on it. The
Entra **diagnostic setting** the connector created is a tenant-level object and is not
in that group — remove it separately in **Entra ID → Diagnostic settings**, or it will
sit there pointing at a workspace that no longer exists.

That orphan is itself worth seeing once.

---

## Remember it

**Sentinel is a solution on a workspace, not a database.** Everything you query is Log
Analytics; Sentinel adds incidents, entities, analytics rules and automation on top.

The line that regenerates the topic: *connector writes a diagnostic setting → rows land
in a table → a scheduled query over that table raises an alert → entity mapping turns
the alert into something you can pivot from → an automation rule decides what happens
next.* Break any link and the queue stays empty for a different reason at each step.
