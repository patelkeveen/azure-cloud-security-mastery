# Requirements

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **A requirement that cannot be tested is not a requirement — it is a wish with a reference
> number.** Pairs with [`../discovery/`](../discovery/) and [`../hld/`](../hld/).

---

## 1. What it is

The written, numbered, testable statement of what the solution must do — captured before design,
agreed by a named person, and traceable through design, build and acceptance. Requirements are the
contract between "what you asked for" and "what I am going to be paid for."

⭐ **Every requirement must have an acceptance test written at the same moment as the requirement
itself.** If you cannot write the test, you do not yet understand the requirement.

---

## 2. Why it exists

Without numbered, testable requirements, three specific things happen — and all three are billing
disputes, not engineering problems:

| Failure | What it sounds like at the end |
|---|---|
| ⭐ **Scope creep** | *"We assumed MFA included the contractors."* |
| ⭐ **Untestable acceptance** | *"It doesn't feel secure enough."* |
| ⭐ **Orphan work** | you built something nobody can point to a requirement for |
| No traceability | ⭐ **you cannot prove you delivered** |

⭐ **The third one is the expensive one for a consultant.** Work with no requirement behind it was
unpaid by definition, and it is usually the work you were proudest of.

---

## 3. How it works underneath — the traceability chain

```
BUSINESS DRIVER      "we failed an insurance audit on MFA coverage"
      │
      ▼
REQUIREMENT  REQ-014  ⭐ testable, numbered, owned
      │
      ├──► DESIGN     HLD §4.2 decision  ─►  LLD §7 parameter values
      │
      ├──► BUILD      the actual policy object
      │
      └──► ⭐ ACCEPTANCE TEST  AT-014  ─►  evidence  ─►  SIGN-OFF
```

⭐ **Every arrow must be walkable in both directions.** Forwards proves you built what was asked;
⭐ **backwards proves nothing was built that nobody asked for** — and backwards is the direction
that protects your margin.

---

## 4. Worked example — the same requirement, badly and well

**As the customer says it:**

```
"All users should have MFA."
```

⭐ **Four unanswered questions, each of which changes the build:** *All* — including guests, service
accounts, break-glass? *Users* — members only? *MFA* — any second factor, or phishing-resistant?
*Should* — by when, and enforced or reported?

**Written properly:**

```
REQ-014   Multi-factor authentication coverage
Priority  MUST (MoSCoW)
Owner     J. Okafor, Head of IT Security
Source    Cyber insurance renewal, clause 4.2, dated 2026-06-30

STATEMENT
  All licensed member accounts, excluding two named break-glass accounts,
  shall be required to complete multi-factor authentication when accessing
  Microsoft 365 from outside the corporate network.

⭐ ACCEPTANCE TEST  AT-014
  1. Conditional Access policy is in state "enabled" (not report-only)
  2. Query returns ZERO licensed member accounts not in scope,
     excluding breakglass1@ and breakglass2@
  3. A test sign-in from outside the corporate egress IP prompts for MFA
  4. Evidence: policy JSON export + query output + sign-in log entry

⭐ EXPLICITLY OUT OF SCOPE
  Guest (B2B) accounts - covered separately by REQ-021
  Service principals and managed identities - REQ-022
  ⭐ Phishing-resistant methods - NOT required by REQ-014; see REQ-019
```

⭐ **The out-of-scope block is the most valuable part of the document**, and the part juniors omit.
It is the sentence you will point at in month three, and it costs thirty seconds to write.

⭐ **Note `MUST` from MoSCoW, not "high priority".** *High / medium / low* degrades into everything
being high. **MoSCoW forces a real decision:** `MUST` (no solution without it), `SHOULD` (painful to
omit, still shippable), `COULD` (if time allows), `WON'T` (⭐ **explicitly excluded this phase** —
the category that prevents the argument).

---

## 5. Functional vs non-functional — where projects actually fail

| Type | Asks | Example |
|---|---|---|
| **Functional** | *what it does* | "MFA is required from outside the network" |
| ⭐ **Non-functional** | ⭐ *how well* | ⭐ "sign-in adds no more than **5 seconds** at the 95th percentile" |
| **Constraint** | *what you may not do* | "no data may transit a non-EU region" |
| **Assumption** | *what you are relying on* | ⭐ "customer provides DNS changes within 4 business hours" |

⭐ **Non-functional requirements are where delivery fails, because they are the ones nobody writes
down.** The system does exactly what was specified and is still rejected — too slow, too noisy, too
many prompts. Write the number: *5 seconds*, *99.9 %*, *4 hours*, *zero standing admin*.

⭐ **Assumptions are requirements pointed at the customer.** An unmet assumption is their delay, not
yours — but only if it was written before the project started.

---

## 6. Commands — traceability as a file, not a feeling

Keep requirements in a CSV so the matrix is generated, never maintained by hand:

```powershell
$req = Import-Csv .\requirements.csv     # Id,Statement,Priority,Owner,Design,Test,Status
$req | Where-Object { -not $_.Design -or -not $_.Test } |
       Select-Object Id, Priority, Statement
```

```
Id      Priority  Statement
REQ-019 SHOULD    Administrators shall use phishing-resistant authentication
REQ-022 MUST      Service principals shall not hold standing Directory roles
```

⭐ **Two `MUST`/`SHOULD` requirements with no design and no test — found by a query, not by
memory.** Run this at every weekly checkpoint; ⭐ **a requirement without a test is the leading
indicator of a disputed sign-off.**

**Coverage, as a number you can put in a status report:**

```powershell
$total = $req.Count
$done  = @($req | Where-Object Status -eq 'Accepted').Count
"Accepted {0}/{1} ({2}%)" -f $done, $total, [math]::Round(100*$done/$total)
```

```
Accepted 17/23 (74%)
```

⭐ **"74 %" beats "nearly done" in every conversation you will ever have with a steering committee.**

---

## 7. When and where

| Engagement type | Requirements rigour |
|---|---|
| Fixed-price | ⭐ **maximum. The requirements list *is* the contract** |
| Time and materials | lighter, but ⭐ **still numbered** — it is how you show value |
| Internal project | ⭐ still write them; "internal" is where scope creep lives |
| Break-fix / incident | not applicable — ⭐ say so rather than inventing paperwork |

⭐ **Requirements are gathered in [`../discovery/`](../discovery/) and *frozen* before
[`../hld/`](../hld/) begins.** A requirement that arrives after design is a **change request**, and
naming it that — politely, in writing, the same day — is the single most valuable professional habit
in this domain.

---

## 8. What breaks

| Symptom | Root cause | Fix |
|---|---|---|
| "That's not what we meant" at UAT | untestable statement | ⭐ acceptance test written **with** the requirement |
| Endless additions | no freeze, no change process | freeze at design start; ⭐ everything after is a CR |
| Everything is "high priority" | ⭐ priority scale with no forcing function | ⭐ MoSCoW, with a `WON'T` list |
| Built something unrequested | no backward traceability | the §6 query, run weekly |
| Delay blamed on you | assumption never written | ⭐ assumptions are numbered requirements too |
| Sign-off stalls | no named owner per requirement | one human name per row — ⭐ not a department |

⭐ **"One human name, not a department."** *"IT Security will approve"* has never approved anything.
A row owned by *"J. Okafor"* can be chased; a row owned by *"the business"* cannot.

---

## 9. Customer discovery questions

1. ⭐ **"How will you decide this project succeeded?"** — the answer is your acceptance criteria
2. "Who can approve a requirement, and who can veto one?"
3. ⭐ **"What must NOT change?"** — constraints surface faster than requirements
4. "What is driving the deadline — an audit, a contract, a renewal?"
5. "What did you try before, and why did it stop?"
6. ⭐ **"What are you assuming we will handle, that we have not discussed?"**
7. "If we can only deliver half of this, which half?" (⭐ this *is* MoSCoW, asked conversationally)

---

## 10. Remember it

**Hook — `T O N T`: Testable, Owned, Numbered, Traceable.** Four properties; a statement missing any
one of them is not a requirement.

**Analogy — a builder's quote versus a conversation.** ⭐ **"A nice kitchen" cannot be inspected;
"worktop 3.2 m, quartz, installed by 14 March" can.** The analogy is load-bearing: it predicts why
the out-of-scope list matters (⭐ *"I assumed the quote included the tiling"*), why non-functional
requirements are where disputes happen (*the kitchen is exactly as specified and the drawers stick*),
and why assumptions are requirements pointed the other way (*we assumed you'd clear the room*).

**The one line:** ⭐ **Write the acceptance test at the same moment as the requirement, or you have
not written a requirement.**

---

## 11. Self-test

1. What makes a statement a requirement rather than a wish?
   → ⭐ It is testable, numbered, owned by a named person, and traceable to design and acceptance.
2. Why MoSCoW instead of high/medium/low?
   → ⭐ It forces a real decision and provides `WON'T` — an explicit exclusion.
3. Which requirement type most often causes rejection at UAT?
   → ⭐ Non-functional — performance, prompt frequency, noise. Nobody wrote the number.
4. What is an assumption, in contract terms?
   → ⭐ A requirement pointed at the customer; unmet, it is their delay, not yours.
5. A new requirement arrives after design starts. What is it called?
   → ⭐ A change request — named the same day, in writing.
6. Why does backward traceability protect margin?
   → ⭐ It surfaces work built against no requirement, which was unpaid by definition.
7. What is wrong with "IT Security will approve"?
   → ⭐ A department cannot be chased. One human name per row.

---

## 12. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | a real `requirements.csv` with ≥10 rows, and the coverage query output |
| `operations` | the weekly gap query, run and dated |
| `customer-use-cases` | one requirement rewritten from a customer's own words, with its acceptance test |
| `architecture-decisions` | ⭐ the frozen baseline, and the change requests raised against it |
| `break-fix` | one disputed item and how traceability resolved it |
