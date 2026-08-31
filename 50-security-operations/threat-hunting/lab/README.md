# Lab — Threat hunting on the July 2026 surface

**Exam:** SC-200, *Perform threat hunting* (20–25%).
**Tenant needed:** yes, for advanced hunting. **Before 2026-09-10.**

⭐ **Read this first.** Microsoft **restructured the SC-200 blueprint on 28 July 2026**.
This group gained material that almost no existing study resource covers, because most
were written against the previous outline:

- **Hunting graphs, including blast radius**
- **Sentinel Graph** — analysing relationships between entities
- **KQL jobs in Data lake**
- **Summary rule tables** for querying
- **Notebooks, including connection to the Sentinel MCP Server**

If your preparation predates late July, these are your blind spots. Prioritise them over
re-drilling KQL syntax you already have.

The KQL lab next door covers table selection and operators. This one covers the
*surfaces*.

---

## 0. Two hunting surfaces, again

| | Advanced hunting | Sentinel hunting |
| --- | --- | --- |
| Portal | Microsoft Defender | Azure / Defender unified |
| Tables | `Device*`, `Identity*`, `Email*`, `Alert*`, `Cloud*` | `SigninLogs`, `SecurityEvent`, custom |
| Retention | 30 days by default | Whatever the workspace and tier give you |
| Saves as | Custom detection rule | Hunting query, or an analytics rule |

The exam names the surface. Answer for that one.

---

## 1. Advanced hunting — the tables that matter

```kusto
// what ran, where
DeviceProcessEvents
| where Timestamp > ago(24h)
| where FileName in~ ("powershell.exe","cmd.exe","wscript.exe","mshta.exe")
| project Timestamp, DeviceName, AccountName, FileName, ProcessCommandLine
| take 50

// encoded PowerShell -- a durable, low-false-positive hunt
DeviceProcessEvents
| where Timestamp > ago(7d)
| where FileName =~ "powershell.exe"
| where ProcessCommandLine has_any ("-enc","-EncodedCommand","FromBase64String")
| project Timestamp, DeviceName, AccountName, ProcessCommandLine

// identity side
IdentityLogonEvents
| where Timestamp > ago(24h)
| where LogonType == "Failed"
| summarize Failures = count() by AccountUpn, DeviceName
| where Failures > 5
```

`has_any` over a small list beats a regex here: it is faster, and it reads as the intent.

---

## 2. Deliberate failure — the 30-day wall

```kusto
DeviceProcessEvents
| where Timestamp > ago(90d)
| take 10
```

Expected: nothing older than roughly 30 days, whatever you ask for.

**Why:** advanced hunting retains ~30 days. Asking for 90 does not error — it quietly
returns less. That silence is the trap: a hunt that "found nothing" over a quarter may
simply have had no data to search. Longer questions need the data exported to a
workspace, which is what the retention and Data lake bullets on the blueprint are for.

Record the row count and the oldest `Timestamp` you actually got back.

---

## 3. Custom detection rule — turn a hunt into a control

Take the encoded-PowerShell query, add the columns a detection needs, and save it:

```kusto
DeviceProcessEvents
| where Timestamp > ago(1h)
| where FileName =~ "powershell.exe"
| where ProcessCommandLine has_any ("-enc","-EncodedCommand","FromBase64String")
| extend ReportId = ReportId, DeviceId = DeviceId, Timestamp = Timestamp
```

**Save → Create detection rule.** A custom detection rule must return `Timestamp`,
`ReportId` and at least one entity id (`DeviceId`, `AccountObjectId`, …) or the save is
rejected. That rejection is the lesson: a hunt becomes a detection only when it names
what it found in a way the platform can act on.

Set frequency, severity, and the impacted entities. Confirm it appears under
**Detection rules** and note the difference from a Sentinel analytics rule: this one
lives in Defender XDR and can take **automated actions on the entity directly**.

---

## 4. The new surfaces — look at each once

Even ten minutes on each beats meeting the name first in the exam.

**Hunting graph / blast radius.** From an incident or an entity, open the graph view and
read what it is claiming: which accounts, devices and resources are reachable from the
compromised one. *Blast radius* is the answer to "if this identity is owned, what else
is?" Note whether it surfaces something your query did not.

**Sentinel Graph.** Relationships between entities across the workspace rather than a
single incident. Ask it one question you already know the answer to, so you can judge it.

**Summary rules.** A scheduled aggregation that writes into its own table, so expensive
hunts run once and are queried cheaply thereafter. Check whether one exists; if you
create one, record the source query, the destination table and the cadence.

**KQL jobs in Data lake.** Long-running queries over the cheaper, longer-retention tier —
the answer to the 30-day wall in §2. Note the latency difference against interactive
hunting.

**Notebooks and the Sentinel MCP Server.** Notebooks give you Python over the same data
for anything KQL cannot express. The **MCP Server** connection is new on this blueprint;
at minimum know that it exists, what it connects, and that it is how an agent reaches
Sentinel data.

For each of the five, write two lines in your journal: *what it is for*, and *the
question it answers that a plain KQL query does not*. That is what the exam asks.

---

## 5. MITRE ATT&CK coverage

**Sentinel → MITRE ATT&CK (Preview)** shows which techniques your analytics cover.

Find one technique with zero coverage that your tenant could plausibly see, and say what
rule would close it. The blueprint bullet is *"Analyze attack vector coverage by using
the MITRE ATT&CK matrix"* — the verb is analyse, not enable.

---

## 6. Verification — you have finished when

- [ ] You ran three advanced hunting queries and read the output, not just the row count
- [ ] You hit the 30-day wall deliberately and recorded the real oldest timestamp
- [ ] A custom detection rule exists, and you know which three columns it required
- [ ] You can state the difference between a custom detection rule and a Sentinel analytic
- [ ] You have two lines written on each of the five new surfaces in §4
- [ ] You named one uncovered MITRE technique and the rule that would cover it

---

## 7. Evidence

Into `50-security-operations/threat-hunting/lab/evidence/`:

- The three queries and their output
- The 90-day query result, with the oldest timestamp actually returned
- The verbatim rejection when a detection rule is missing a required column
- Your ten lines on the five new surfaces — **this is the highest-value artifact here**,
  because it is the material least likely to be in any other resource you own
- A screenshot of the MITRE coverage matrix

---

## 8. Cleanup

- Delete the custom detection rule, or it keeps firing after the lab
- Delete any summary rule you created — it consumes ingestion
- Export every query into this folder as text. Queries saved in the portal die with the
  tenant on 10 Sep; a `.kql` file in the repo does not

---

## Remember it

**Hunting is a question; a detection is a question that runs on a schedule and names
what it found.**

The line that regenerates the topic: *advanced hunting is 30 days of Defender data for
interactive questions; Sentinel and the Data lake are where longer questions live;
graphs answer "what else is reachable"; and a hunt becomes a control the moment it can
return `Timestamp`, `ReportId` and an entity.*
