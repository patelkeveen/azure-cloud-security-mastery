# Lab — KQL: pick the right table, then make it answer a question

**Exam:** SC-200, *Perform threat hunting* (20–25%). The first bullet of that group is
literally *"Identify the appropriate table to use in a KQL query"* — table selection is
examined before syntax.
**Tenant needed:** yes, for the second half. **Before 2026-09-10.**

You finish able to answer an auditor's question rather than merely enable logging.

---

## 0. Setup

Two surfaces, and they are not the same:

| Surface | Where | Tables |
| --- | --- | --- |
| **Advanced hunting** | Microsoft Defender portal | `DeviceEvents`, `IdentityLogonEvents`, `EmailEvents`, `AlertInfo`… |
| **Log Analytics / Sentinel** | Azure portal, on a workspace | `SigninLogs`, `AuditLogs`, `SecurityEvent`, `Heartbeat`… |

They share the language and almost nothing else. A query written for one usually does
not run on the other, and the exam gives you the surface in the question stem.

For the practice half you need no tenant at all — use the
**[KQL playground](https://aka.ms/lademo)**, a read-only workspace with real data.

---

## 1. Table selection, before any syntax

Answer these from memory, then verify:

| Question | Table |
| --- | --- |
| Interactive user sign-ins | `SigninLogs` |
| A service principal authenticating | `AADServicePrincipalSignInLogs` |
| A managed identity authenticating | `AADManagedIdentitySignInLogs` |
| Token refresh, no user present | `AADNonInteractiveUserSignInLogs` |
| Someone changed a Conditional Access policy | `AuditLogs` |
| Provisioning to a SaaS app failed | `AADProvisioningLogs` |
| A process ran on a managed device | `DeviceProcessEvents` (Defender) |
| A user opened a suspicious mail | `EmailEvents` (Defender) |

Verify what exists in your own workspace:

```kusto
union withsource=Table *
| where TimeGenerated > ago(7d)
| summarize Rows = count() by Table
| order by Rows desc
```

Anything absent from that list cannot be queried, no matter how correct the syntax.

---

## 2. The operators that carry the exam

Run each and read the shape, do not skim:

```kusto
// where / project / take -- narrowing
SigninLogs
| where TimeGenerated > ago(1d) and ResultType != 0
| project TimeGenerated, UserPrincipalName, IPAddress, ResultType, ResultDescription
| take 20

// summarize -- the one that turns rows into an answer
SigninLogs
| where TimeGenerated > ago(7d)
| summarize Attempts = count(), Failed = countif(ResultType != 0) by UserPrincipalName
| extend FailRate = round(100.0 * Failed / Attempts, 1)
| where Attempts > 10
| order by FailRate desc

// bin -- time series
SigninLogs
| where TimeGenerated > ago(24h)
| summarize Failures = countif(ResultType != 0) by bin(TimeGenerated, 1h)
| render timechart

// mv-expand -- unpack the array the CA answer hides in
SigninLogs
| where TimeGenerated > ago(7d)
| mv-expand ca = ConditionalAccessPolicies
| extend Policy = tostring(ca.displayName), Result = tostring(ca.result)
| summarize count() by Policy, Result
```

That last one matters: **Conditional Access results are a nested array**, so a plain
`where` against them silently matches nothing. `mv-expand` is how report-only evidence
is actually read.

---

## 3. Deliberate failure — the join that returns nothing

```kusto
SigninLogs
| where TimeGenerated > ago(1d)
| join kind=inner AuditLogs on UserPrincipalName
```

Expected: an error, or zero rows.

**Why:** `AuditLogs` has no `UserPrincipalName` column — the actor is nested inside
`InitiatedBy`. The fix names the key on each side and unpacks the nesting:

```kusto
let signins = SigninLogs
  | where TimeGenerated > ago(1d)
  | project TimeGenerated, User = tolower(UserPrincipalName), IPAddress;
let audits = AuditLogs
  | where TimeGenerated > ago(1d)
  | extend User = tolower(tostring(InitiatedBy.user.userPrincipalName))
  | project AuditTime = TimeGenerated, User, OperationName;
signins
| join kind=inner audits on User
| project TimeGenerated, User, IPAddress, OperationName
| take 20
```

Two lessons the exam leans on: **`join ... on X` requires a column literally named `X`
on both sides**, and JSON columns need `tostring(...)` before they compare.

Capture the error text verbatim. That is your artifact.

---

## 4. Result codes worth knowing cold

```kusto
SigninLogs
| where TimeGenerated > ago(7d) and ResultType != 0
| summarize count() by ResultType, ResultDescription
| order by count_ desc
```

| Code | Means |
| --- | --- |
| `0` | Success |
| `50126` | Invalid username or password |
| `50053` | Account locked — **smart lockout**, often an attack you already stopped |
| `50074` | Strong auth required — MFA demanded and not completed |
| `53003` | **Blocked by Conditional Access** |
| `50076` / `50079` | MFA required / MFA registration required |

`53003` on a legitimate user is a policy problem. `50126` in volume from one IP is a
password spray. Reading the code tells you which incident you are in.

---

## 5. Two hunts to write yourself

Give each a real answer, not a screenshot of a query:

1. **Password spray.** One source IP, many distinct accounts, mostly `50126`, in a short
   window. Hint: `summarize dcount(UserPrincipalName) by IPAddress, bin(TimeGenerated, 1h)`.
2. **Impossible travel by hand.** Same user, two sign-ins, distant `Location` values,
   minutes apart. Hint: `prev()` after `order by UserPrincipalName, TimeGenerated asc`.
   Then compare your result with what Identity Protection flagged — and note what it
   caught that you did not.

---

## 6. Verification — you have finished when

- [ ] You can name the right table for all eight rows in §1 without looking
- [ ] You have used `mv-expand` to read a Conditional Access result
- [ ] You made the broken join fail, and you can explain *why* in one sentence
- [ ] You can say what `53003` means and what you would do about it
- [ ] Both hunts return a real answer from real data

---

## 7. Evidence

Into `50-security-operations/kql/lab/evidence/`:

- The verbatim join error from §3, with the query that caused it
- Your two hunting queries and their output
- The `summarize count() by ResultType` table from your own tenant
- A note of anything Identity Protection caught that your manual hunt missed

---

## 8. Cleanup

Nothing to remove — every query here is read-only. If you saved hunting queries into
Sentinel, they die with the workspace on 07 Sep, so **export the `.kql` text into this
folder now** rather than trusting the portal to keep them.

---

## Remember it

**Table first, syntax second.** Most zero-row results are the wrong table, not the wrong
filter — and the four sign-in tables (interactive, non-interactive, service principal,
managed identity) are the classic trap.

The line that regenerates the topic: *find the table, narrow with `where`, turn rows
into an answer with `summarize`, and unpack anything nested with `mv-expand` or
`tostring` before you compare it.*
