# Cutover and Rollback

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The only part of a migration the customer actually experiences.** Pairs with
> [`../coexistence/`](../coexistence/),
> [`../../75-architecture-and-consulting/cutover-playbooks/`](../../75-architecture-and-consulting/cutover-playbooks/)
> and [`../../70-operations-and-reliability/change-management/`](../../70-operations-and-reliability/change-management/).

---

## 1. What it is

Cutover is the scheduled moment when authoritative service moves from the source system to the
target: MX records change, Autodiscover changes, users are told to restart Outlook. Rollback is the
**pre-decided** path back, with a **pre-decided deadline** for taking it.

⭐ **A rollback plan written after the cutover starts is not a plan — it is an argument held under
pressure.**

---

## 2. Why it exists

Everything before cutover is reversible: data is copied, nothing authoritative has changed, and
abandoning the project costs money but not service. ⭐ **Cutover is the first irreversible step**,
and irreversible steps need a different kind of preparation:

| Without a cutover plan | With one |
|---|---|
| "Is mail flowing?" answered by opinion | ⭐ **a named test with a pass/fail line** |
| DNS change discovered to have a 24 h TTL | ⭐ TTL lowered **72 hours in advance** |
| Rollback debated at 03:00 | ⭐ **a go/no-go time agreed in daylight** |
| Users phone the helpdesk | comms sent before, during and after |

---

## 3. How it works underneath — why DNS timing dominates

```
T-72h   ⭐ Lower TTL on MX and autodiscover:  3600 → 300
           (the OLD TTL must expire before the new one applies —
            ⭐ this is why it is done three days early, not on the night)

T-0     Final delta sync completes; mailboxes finalised
T+0m    ⭐ Change MX  →  contoso-com.mail.protection.outlook.com
T+0m    Change autodiscover CNAME → autodiscover.outlook.com
T+5m    Global resolvers begin returning the new answer
T+30m   ⭐ Long tail: caching resolvers that ignore TTL, and
           Outlook clients that cache Autodiscover per profile
T+24h   Old endpoint still receiving stragglers  ⭐ KEEP IT ALIVE
```

⭐ **The single most common cutover error is decommissioning the source too early.** DNS propagation
has no completion event. ⭐ **Leave the old MX endpoint accepting and forwarding mail for at least
a week** — it costs nothing and it is the difference between "a few late messages" and "lost mail".

---

## 4. Worked example — the cutover runbook, with pass/fail lines

Every row has an **owner**, a **verification**, and a **rollback**. A step without a verification is
a hope.

| # | Time | Step | ⭐ Verification (pass = ) | Rollback |
|---|---|---|---|---|
| 1 | T-72h | Lower TTL to 300 | `dig +noall +answer MX contoso.com` shows `300` | revert TTL |
| 2 | T-24h | Comms sent | send log | — |
| 3 | T-2h | ⭐ **Go/no-go call** | ⭐ **all batches `Synced`, 0 `Failed`** | ⭐ **abort — cost so far: nothing** |
| 4 | T-0 | `Complete-MigrationBatch` | `Status: Completed` for every user | ⭐ point of no return for mailbox data |
| 5 | T+0 | Change MX | `dig MX contoso.com` shows `*.mail.protection.outlook.com` | revert MX (5 min) |
| 6 | T+5 | Change autodiscover CNAME | `nslookup autodiscover.contoso.com` → `autodiscover.outlook.com` | revert CNAME |
| 7 | T+15 | ⭐ **External→internal mail test** | ⭐ **test message from a personal address lands in EXO within 5 min** | revert 5, 6 |
| 8 | T+20 | Internal→external test | received at external address, headers show EXO | as above |
| 9 | T+30 | Client test: 3 users, 3 platforms | ⭐ Outlook reconnects **without a new profile** | see §7 |
| 10 | T+60 | ⭐ **Go/no-go #2** | steps 7–9 all pass | ⭐ **last clean rollback point** |
| 11 | T+24h | Disable inbound on old endpoint | zero new deliveries for 24 h | re-enable |
| 12 | T+7d | Decommission | ⭐ **only after a week of silence** | — |

⭐ **Two go/no-go gates, not one.** The first (step 3) is free to abort. The second (step 10) is the
last moment a revert is clean. After that, mail has been delivered into the new system and rollback
means **reconciling two datasets**, not flipping a record.

**The DNS check, verbatim:**

```bash
dig +noall +answer MX contoso.com
```

```
contoso.com.  300  IN  MX  0 contoso-com.mail.protection.outlook.com.
```

⭐ **Read the TTL column, not just the target.** A correct target with a 3600 TTL means your
rollback takes an hour, and that changes the decision at step 10.

---

## 5. Commands — the verification set, run in this order

```powershell
# ① Did the batches actually finish?  (not "look finished")
Get-MigrationBatch | Select-Object Identity, Status, TotalCount, ActiveCount, FailedCount
```

```
Identity        Status     TotalCount  ActiveCount  FailedCount
Wave-01-Finance Completed          52            0            0
```

⭐ **`FailedCount` must be `0` before step 4.** Not "low". Zero, or a named exception with a written
decision.

```powershell
# ② Is mail actually arriving?  Evidence, not anecdote.
Get-MessageTrace -StartDate (Get-Date).AddMinutes(-30) -EndDate (Get-Date) |
  Select-Object Received, SenderAddress, RecipientAddress, Status | Sort-Object Received -Desc
```

```
Received             SenderAddress        RecipientAddress      Status
18/08/2026 21:14:02  test@gmail.com       j.smith@contoso.com   Delivered
```

```powershell
# ③ Autodiscover is answering for the cloud
Test-OutlookConnectivity -RunFromServerId $null -ProbeIdentity OutlookMapiHttpSelfTestProbe
```

⚠ `⚠ check` — `Test-OutlookConnectivity` parameters differ by Exchange version; the portable
equivalent is the **Microsoft Remote Connectivity Analyzer** (`testconnectivity.microsoft.com`),
which is also the artifact you can hand a customer.

---

## 6. When and where

| Cutover style | Use when |
|---|---|
| ⭐ **Big bang** (all users, one night) | < ~150 mailboxes, single site, tolerant business |
| ⭐ **Waved** (groups over weeks) | anything larger — ⭐ requires [`../coexistence/`](../coexistence/) |
| Pilot-first | always. ⭐ 5–10 friendly users, one week ahead, **including one executive's delegate** |

⭐ **Never schedule a cutover for the last business day of a month at a finance-heavy customer.**
Knowing the customer's calendar is part of the design, and asking about it in the discovery session
signals more experience than any technical question.

---

## 7. What breaks

| Symptom | Cause | Action |
|---|---|---|
| Mail still arriving at the old system after 6 h | ⭐ **TTL was not lowered in advance** | wait it out; ⭐ **do not** turn off the old endpoint |
| `Outlook cannot log on. Verify you are connected` | profile cached the old Autodiscover answer | close Outlook, delete the Autodiscover cache, reopen; ⭐ **do not rebuild the profile first** |
| Some users fine, some not | resolver caching | check per-client DNS, not the service |
| Mobile devices stopped syncing | ⭐ ActiveSync partnership tied to the old endpoint | re-add the account; expected, ⭐ **so put it in the comms** |
| External senders get NDRs | MX changed before EXO accepted the domain | revert MX immediately (step 5 rollback) |
| ⭐ **Shared mailbox inaccessible** | owner and delegate split across the cutover | ⭐ pre-checked at step 3 if the wave plan was built from the delegation map |

⭐ **"Delete the Autodiscover cache" beats "recreate the profile" nine times out of ten**, and it
takes thirty seconds instead of twenty minutes. On Windows the cached XML lives under
`%LOCALAPPDATA%\Microsoft\Outlook\16\` — ⚠ check the exact path for the Outlook build in front of
you before scripting it.

---

## 8. Customer discovery questions

1. ⭐ **"What date must we avoid — month end, payroll, a board meeting?"**
2. "Who signs the go/no-go, and will they be awake at 02:00?"
3. ⭐ **"What is the maximum tolerable mail outage, in minutes?"**
4. "Who controls DNS, and how quickly can they make a change at 23:00?"
5. "Are there mobile devices, and who supports them?"
6. "What is the escalation path if we roll back?"
7. ⭐ **"Who tells the users, and when?"**

---

## 9. Remember it

**Hook — `T G V R`: TTL, Go/no-go, Verify, Rollback window.** Four things; three happen before the
change.

**Analogy — a flight.** ⭐ **The pilot's `V1` speed is the point after which you take off no matter
what**, because stopping has become more dangerous than continuing. Step 10 is your `V1`. The
analogy predicts the practice: **`V1` is computed on the ground with known numbers, not judged in
the moment** — which is exactly why the go/no-go criteria are written days earlier and why "we'll
see how it goes" is not a plan.

**The one line:** ⭐ **Lower the TTL three days early, define two go/no-go gates, and leave the old
endpoint running for a week.**

---

## 10. Self-test

1. Why lower TTL 72 hours before cutover rather than on the night?
   → ⭐ The **old** TTL must expire before the new short one takes effect.
2. What are the two go/no-go gates and what differs between them?
   → Pre-finalise (free abort) and post-DNS verification (⭐ last clean rollback).
3. Why keep the old mail endpoint alive for a week?
   → ⭐ DNS propagation has no completion event; stragglers keep arriving.
4. First response to "Outlook cannot log on" after cutover?
   → Clear the Autodiscover cache — not a profile rebuild.
5. What must `FailedCount` be before finalising?
   → ⭐ Zero, or a named exception with a written decision.
6. Why is mobile re-registration in the comms rather than the fix list?
   → ⭐ It is expected behaviour, and an expected event pre-announced is not an incident.
7. A cutover step has no verification. What is wrong with it?
   → ⭐ It cannot be shown to have succeeded, so it cannot gate the next step.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | `dig` output before and after, with TTLs visible |
| `operations` | ⭐ the completed runbook table with real timestamps and initials |
| `break-fix` | one client that failed to reconnect, and what actually fixed it |
| `customer-use-cases` | the comms pack: T-24h, T-0, T+1d |
| `architecture-decisions` | ⭐ the go/no-go criteria, signed before the night |
