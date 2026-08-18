# Configuration Checklists

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **A checklist is not a design and not a tutorial. It is a defence against the competent person
> having a bad day.** Pairs with [`../lld/`](../lld/) and [`../sop-and-runbooks/`](../sop-and-runbooks/).

---

## 1. What it is

A short, ordered list of the steps that must happen and be **verified** during a build or a change
— written for someone who already knows how to do the work, and exists only to stop them skipping
something under time pressure.

⭐ **Checklists are for experts, not beginners.** A beginner needs the SOP; an expert needs the
five items that are catastrophic to omit.

---

## 2. Why it exists

⭐ **Failure in configuration work is almost never ignorance. It is omission.** The engineer knew
about the break-glass exclusion; they were on their fourth policy at 22:40 and did not add it.

| Without a checklist | With one |
|---|---|
| ⭐ Steps skipped under pressure | ⭐ **omission becomes visible** |
| "I'm sure I did that" | ⭐ initialled, timestamped |
| ⭐ Verification skipped when tired | ⭐ verification **is** the item |
| No evidence a step happened | the completed list **is** evidence |
| Every engineer works differently | ⭐ same sequence, comparable results |

⭐ **The verification column is the entire value.** *"Enable the policy"* is a step; ⭐ *"enable the
policy **and read it back**"* is a control. A checklist without verification is a to-do list, and a
to-do list has never caught anything.

---

## 3. How it works underneath — two kinds, and using the wrong one fails

```
⭐ READ-DO        read the item, then do it
                  ▸ unfamiliar, high-stakes, rarely performed
                  ▸ ⭐ emergency procedures, first-time builds, cutover
                  ▸ example: break-glass account creation

⭐ DO-CONFIRM     do the work from expertise, THEN confirm against the list
                  ▸ familiar, routine, done under time pressure
                  ▸ ⭐ pre-flight before enabling a policy set
                  ▸ example: "before I enable these six policies…"

        ⭐ WRONG TYPE = IGNORED CHECKLIST
        read-do for a routine task feels patronising → skipped
        do-confirm for an emergency → ⭐ steps missed before you reach the list
```

⭐ **This distinction comes from aviation and surgery, and it transfers exactly.** ⭐ **Length is the
tell: a do-confirm checklist longer than about nine items stops being used.** If yours is longer, it
is an SOP wearing a checklist's clothes — move it to
[`../sop-and-runbooks/`](../sop-and-runbooks/).

⭐ **The other borrowed idea worth keeping: the *pause point*.** A checklist runs at a defined
moment — *before enabling*, *before cutover*, *before handover* — not continuously. Naming the pause
point is what makes it happen at all.

---

## 4. Worked example — the pause point before enabling Conditional Access

⭐ **Do-confirm. Eight items. Run once, immediately before enforcement.**

```
CHECKLIST CA-ENABLE       Pause point: before moving any policy to 'enabled'
Operator ______________   Date/Time ______________   Tenant ______________

#  Item                                     ⭐ Verified by            ✓
─────────────────────────────────────────────────────────────────────────
1  Two break-glass accounts exist,          Get-MgUser filter          ☐
   enabled, ⭐ passwords in sealed custody
2  ⭐ BOTH excluded from EVERY policy         ⭐ script below - ZERO rows  ☐
   about to be enabled
3  ⭐ Break-glass sign-in TESTED today        ⭐ private window, screenshot☐
   (not "last month")
4  Report-only impact reviewed,             workbook / sign-in logs    ☐
   ⭐ zero unexpected blocks in 7 days
5  Legacy authentication blocked FIRST      CA policy state = enabled  ☐
6  ⭐ Rollback command ready & pasted         Set-...-State 'disabled'   ☐
   in the change ticket
7  Named person available for 60 min        name: ______________       ☐
   after enabling
8  ⭐ Service accounts / relay identified     list attached              ☐
   and excluded or exempted
─────────────────────────────────────────────────────────────────────────
⭐ STOP if any box is unticked. An unticked box is a decision to accept
   risk, and it needs a name against it: _______________
```

⭐ **Item 3 is the one that saves you.** A break-glass account that exists but has never been signed
into is a *belief*, not a control — the credential may be wrong, the account may be blocked by an
earlier policy, the MFA registration may be required. ⭐ **Untested recovery is not recovery**, and
this is exactly the failure recorded in
[`../../SC-300-SPRINT/TROUBLESHOOTING.md`](../../SC-300-SPRINT/TROUBLESHOOTING.md) §5.

⭐ **Item 5 encodes a real ordering dependency, not a preference:** legacy authentication protocols
cannot carry an MFA challenge, so an MFA policy enabled before legacy auth is blocked is silently
bypassable. **Order matters, and a checklist is where ordering knowledge survives.**

⭐ **The footer matters as much as the items.** *"An unticked box is a decision to accept risk, and
it needs a name"* converts a skipped step from an accident into an accountable choice — which is the
only mechanism that reliably stops it.

---

## 5. Commands — the checklist as code

⭐ **Any item that can be a script should be a script.** Human attention is scarce; spend it on
judgement, not on eyeballing.

**Item 2, executable — the highest-value five lines in this domain:**

```powershell
$bg = @(Get-MgUser -All -Property Id,UserPrincipalName |
        Where-Object UserPrincipalName -match 'breakglass').Id
Get-MgIdentityConditionalAccessPolicy -All |
  Where-Object State -ne 'disabled' | ForEach-Object {
    $miss = @($bg | Where-Object { $_ -notin @($_.Conditions.Users.ExcludeUsers) })
    if ($miss) { [pscustomobject]@{ Policy=$_.DisplayName; NotExcluded=$miss.Count } }
  }
```

```
(no output)
```

⭐ **Zero rows is the pass condition, and "no output" is the correct, boring result.** ⭐ **Design
checks so that silence means safe** — a check that prints something on success trains people to
ignore its output.

**Item 4 — read the report-only impact rather than assuming it:**

```powershell
$since = (Get-Date).AddDays(-7)
Get-MgAuditLogSignIn -Filter "createdDateTime ge $($since.ToString('yyyy-MM-ddTHH:mm:ssZ'))" -All |
  ForEach-Object { $_.AppliedConditionalAccessPolicies } |
  Where-Object Result -eq 'reportOnlyFailure' |
  Group-Object DisplayName | Select-Object Name, Count
```

```
Name                          Count
CA-004-Admin-PhishResistant       3
```

⭐ **Three report-only failures in seven days means three real users would have been blocked.**
Identify them before enabling, or you have scheduled three incidents. ⭐ **This is the whole reason
report-only exists**, and skipping this reading is the most common way a "careful" rollout still
causes an outage.

---

## 6. When and where

| Use a checklist | Use something else |
|---|---|
| ⭐ Before an irreversible step | teaching someone the task → ⭐ SOP |
| ⭐ Repeated builds that must match | one-off exploration → notes |
| Handover acceptance | complex branching logic → ⭐ runbook |
| ⭐ Anything done at 23:00 | design decisions → ⭐ HLD |

⭐ **The three highest-value checklists in this whole repo:** *before enabling any CA policy*
(§4), *before a cutover*
([`../cutover-playbooks/`](../cutover-playbooks/)), and *before handover*
([`../handover/`](../handover/)). ⭐ **All three sit immediately before an irreversible step** — that
is not a coincidence, it is the selection rule.

---

## 7. What breaks

| Symptom | Root cause | Fix |
|---|---|---|
| Checklist ignored | ⭐ too long, or wrong type | ⭐ ≤ 9 items for do-confirm; split the rest into an SOP |
| Boxes ticked without doing | no verification method | ⭐ every item names **how** it was verified |
| Same mistake recurs | checklist never updated | ⭐ **every incident adds or changes one item** |
| Checklist is a tutorial | written for a beginner | ⭐ that is an SOP — different document, different reader |
| Used at the wrong moment | no pause point named | ⭐ state the trigger in the title |
| Passed, still failed | item was belief, not test | ⭐ item 3 problem — test, do not assume |

⭐ **"Every incident adds or changes one item" is the maintenance rule**, and it is also the reason
a checklist earns trust. A list that grows only from real failures stays short and stays credible.
⭐ **A list that grows from imagination becomes forty items and gets ignored** — at which point it
protects nothing while looking like governance.

---

## 8. Customer discovery questions

1. ⭐ **"What is the last change that went wrong, and what step was missed?"** — ⭐ your first item
2. "Do you have a change window, and who must be present?"
3. ⭐ **"Which accounts must never be locked out, and when were they last tested?"**
4. "Who signs off that a change completed successfully?"
5. "Is there an existing pre-flight or change checklist we should extend?"
6. ⭐ **"What is your rollback, and has anyone performed it?"**
7. "Where are completed checklists stored, and for how long?" (⭐ they are audit evidence)

---

## 9. Remember it

**Hook — `P V S`: Pause point, Verification, Short.** Three properties; ⭐ **drop any one and the
checklist stops being used.**

**Analogy — the surgical safety checklist, not the shopping list.** ⭐ **A shopping list reminds you
what you do not know; the surgical checklist confirms what everyone already knows — that this is the
right patient and the right side — because the catastrophic failures are the obvious ones performed
under pressure.** The analogy predicts everything here: it runs at a pause point (before the first
incision), it is short enough to be read aloud, ⭐ **it requires spoken confirmation rather than a
silent tick, and it is shortest for the most experienced teams.**

**The one line:** ⭐ **A short list, at a named pause point, where every item states how it was
verified.**

---

## 10. Self-test

1. Read-do versus do-confirm — when is each correct?
   → ⭐ Read-do for unfamiliar/high-stakes/emergency; do-confirm for routine work under pressure.
2. Practical maximum length for a do-confirm list?
   → ⭐ About nine items. Longer becomes an SOP.
3. What makes an item a control rather than a task?
   → ⭐ It states how it was verified.
4. Why is "no output" the right pass condition for a script check?
   → ⭐ Silence means safe; output on success trains people to ignore it.
5. Why must break-glass sign-in be tested *today*, not last month?
   → ⭐ An untested recovery path is a belief. Policy, credentials or MFA state may have changed.
6. Why block legacy authentication before enabling MFA policies?
   → ⭐ Legacy protocols cannot carry an MFA challenge, so MFA is silently bypassable.
7. What is the maintenance rule?
   → ⭐ Every incident adds or changes exactly one item; nothing is added from imagination.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | a completed, initialled checklist from a real change |
| `security` | the item-2 script run, showing zero rows before enablement |
| `operations` | the report-only impact reading (§5) with the users identified |
| `break-fix` | ⭐ one incident, and the single checklist item it produced |
| `customer-use-cases` | the checklist adapted to a customer's own change process |
