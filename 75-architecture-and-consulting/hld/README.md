# HLD — High Level Design

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The HLD records decisions and the reasons for them. The LLD records values.** Confusing the
> two produces a document nobody can approve and nobody can build from.
> Pairs with [`../lld/`](../lld/) and [`../requirements/`](../requirements/).

---

## 1. What it is

The design document written for **people who approve**, not people who build: what approach was
chosen, what alternatives were considered, why this one, what it costs, what it risks, and what it
depends on. It is read by a sponsor, a security lead and an architect — ⭐ **none of whom needs a
parameter value, and all of whom need the reasoning.**

---

## 2. Why it exists

⭐ **An HLD exists so that a decision survives the person who made it.** Eighteen months later,
someone asks *"why is it built this way?"* and there are only two possible outcomes:

| Without an HLD | With one |
|---|---|
| ⭐ *"I don't know, that's how the consultant did it"* | the decision, with the rejected options |
| Rework because the reason is lost | ⭐ **constraint still documented** |
| Approver signed something they could not read | ⭐ a document at their altitude |
| ⭐ Design defended by seniority | ⭐ **design defended by reasoning** |

⭐ **The rejected options are the most valuable content in the document.** They prove the decision
was a choice rather than a default, and they are what protect you when circumstances change: the
next engineer can see that option B was rejected for a reason that may no longer hold.

---

## 3. How it works underneath — the altitude test

```
BUSINESS DRIVER                        ← discovery
      │
REQUIREMENTS  (testable, numbered)     ← ../requirements/
      │
      ▼
⭐ HLD   "WHAT approach, and WHY"      ← ⭐ decisions · options · risks · cost
      │        audience: approvers
      │        ⭐ NO parameter values
      ▼
   LLD   "WHICH values, exactly"       ← ../lld/
             audience: implementers
      │
      ▼
   BUILD  ─►  ../configuration-checklists/  ─►  acceptance
```

⭐ **The altitude test, applied to one sentence:**

> *"Conditional Access will enforce phishing-resistant authentication for privileged roles."*
> ⭐ **HLD** — it is a decision, and it can be argued with.

> *"Policy `CA-004-AdminPhishResistant`, grant control `authenticationStrength`, strength ID
> `00000000-0000-0000-0000-000000000004`, excluding `breakglass1@…`."*
> ⭐ **LLD** — it is a value, and it can only be typed in or mistyped.

⭐ **If a sentence can be wrong in a way an approver could detect, it belongs in the HLD. If it can
only be wrong in a way an implementer would detect, it belongs in the LLD.** That single test
resolves nearly every "which document does this go in?" argument.

---

## 4. Worked example — one decision record, complete

⭐ **This is the unit of an HLD.** Everything else is context around records like this.

```
HLD §4.2   DECISION: Privileged access model

REQUIREMENT   REQ-022 (MUST) - no standing Directory role assignments
DRIVER        Cyber insurance clause 4.2; audit finding AUD-11

OPTIONS CONSIDERED
┌───┬────────────────────────────┬──────────────────────┬──────────────────────┐
│   │ Option                     │ Pros                 │ ⭐ Why rejected       │
├───┼────────────────────────────┼──────────────────────┼──────────────────────┤
│ A │ Permanent roles, reviewed  │ no licence cost      │ ⭐ standing privilege │
│   │ quarterly                  │ zero change for ops  │ fails REQ-022        │
│ B │ ⭐ PIM, eligible + approval │ ⭐ meets REQ-022      │ ⭐ CHOSEN             │
│   │ + justification            │ full audit trail     │                      │
│ C │ Separate admin tenant      │ strongest isolation  │ ⭐ cost + 6-8 weeks;  │
│   │                            │                      │ deadline is 8 weeks  │
└───┴────────────────────────────┴──────────────────────┴──────────────────────┘

⭐ DECISION   Option B - Privileged Identity Management

RATIONALE     Only B satisfies REQ-022 within the insurance deadline.
              ⭐ C is architecturally superior and is recorded as a Phase 2
              candidate rather than discarded.

⭐ IMPLICATIONS  (the section that makes an HLD honest)
  - Requires Entra ID P2 for every eligible admin  ⭐ 9 users, licence cost
  - Activation adds ⭐ up to 5 minutes to emergency admin access
  - ⭐ Break-glass accounts remain PERMANENT and excluded - by design
  - Approvers must be reachable; ⭐ single-approver risk noted as RISK-07

DEPENDENCIES  Entra ID P2 procured; approver group agreed by J. Okafor
```

⭐ **The `IMPLICATIONS` block is what separates a design from a slide.** *"Activation adds up to 5
minutes to emergency admin access"* is the sentence that will be quoted back at you during the first
real incident. ⭐ **Writing it yourself, in advance, converts a future complaint into a decision the
customer already accepted.**

⭐ **Notice that option C is recorded as Phase 2, not deleted.** Rejected-for-now is different from
rejected-forever, and the distinction is worth a line.

---

## 5. What an HLD contains — and what it must not

| Include | Exclude — ⭐ belongs in the LLD |
|---|---|
| Business drivers and requirement references | ⭐ policy names, GUIDs, IP ranges |
| ⭐ Decisions **with rejected options** | ⭐ exact toggle settings |
| Logical architecture diagram | screenshots of blades |
| ⭐ Risks and mitigations, numbered | step-by-step build instructions |
| Cost and licence implications | ⭐ per-object naming standards |
| Dependencies and assumptions | PowerShell |
| ⭐ Out of scope | — |

⭐ **A screenshot in an HLD is a smell.** It dates the document to a UI that Microsoft will change,
and it signals the author was describing a click path rather than making a decision.

⭐ **Every risk gets a number and an owner**, so it can be tracked after the document is signed:

```
RISK-07  Single approver for PIM activation may be unavailable
         Likelihood  Medium      Impact  High (⭐ delays incident response)
         Mitigation  Approver GROUP of 3, not an individual
         ⭐ Owner    D. Mwangi        Review  at handover
```

---

## 6. Commands — generate the current state so the HLD argues from facts

⭐ **An HLD that states current state from memory is fiction.** Capture it:

```powershell
Get-MgIdentityConditionalAccessPolicy -All |
  Select-Object DisplayName, State,
    @{n='Users';e={ if($_.Conditions.Users.IncludeUsers -contains 'All'){'All'}else{'Scoped'} }},
    @{n='Grant';e={ $_.GrantControls.BuiltInControls -join '+' }} |
  Sort-Object State
```

```
DisplayName                     State                              Users   Grant
Require MFA - all users         enabled                            All     mfa
Block legacy auth               enabledForReportingButNotEnforced  All     block
Admin MFA                       enabledForReportingButNotEnforced  Scoped  mfa
```

⭐ **Two report-only policies is your current-state finding, stated as evidence rather than
opinion** — and it makes the "deployed is not enforced" argument for you.

**Cost, before the sponsor asks:**

```powershell
$p2 = 9        # eligible admins from the discovery role query
$unit = 9.00   # ⚠ check current Entra ID P2 list price for the customer's region
"Entra ID P2: {0} x {1} = {2}/month ({3}/year)" -f $p2,$unit,($p2*$unit),($p2*$unit*12)
```

```
Entra ID P2: 9 x 9 = 81/month (972/year)
```

⚠ `⚠ check` — never state Microsoft list pricing from memory. Pull it from the customer's agreement
or a current price list, and say which.

⭐ **An HLD that names the cost is approved faster than one that does not**, because the approver's
first question has already been answered.

---

## 7. When and where

| Situation | HLD depth |
|---|---|
| Fixed-price, multi-workload | ⭐ **full, with formal sign-off gate** |
| Single-workload change | ⭐ a **decision record or two** — not a 40-page document |
| Internal | lightweight, ⭐ but still record rejected options |
| ⭐ Emergency remediation | ⭐ write it **after**, within a week — the decisions still need a home |

⭐ **Length is not quality.** A 12-page HLD with six real decision records beats a 60-page document
that restates Microsoft documentation. ⭐ **If a paragraph would be true for any customer, delete
it** — that is the same test as [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md) applies to
this repo.

---

## 8. What breaks

| Symptom | Root cause | Fix |
|---|---|---|
| Approver will not sign | document is at LLD altitude | ⭐ move values out; §3 test |
| Implementer keeps asking questions | ⭐ **there is no LLD** | write one — [`../lld/`](../lld/) |
| "Why is it built this way?" 18 months on | no decision records | §4 format |
| Design revisited every meeting | rejected options not written | ⭐ record them; the argument ends |
| Cost challenged at the end | ⭐ implications omitted | the `IMPLICATIONS` block |
| Document out of date in a month | screenshots and UI paths | ⭐ decisions age well; UI does not |

---

## 9. Customer discovery questions

1. ⭐ **"Who reads this document, and what do they need from it?"**
2. "Is there an existing architecture standard or reference we must conform to?"
3. ⭐ **"What has already been decided that I should not reopen?"**
4. "Who has veto over cost?"
5. "Do you need this to satisfy an auditor, and which framework?"
6. ⭐ **"What would make you reject this design?"**
7. "Is there a Phase 2, and what is being deliberately deferred to it?"

---

## 10. Remember it

**Hook — `D O R I`: Decision, Options, Rationale, Implications.** Four blocks per record; the last
one is the one juniors skip.

**Analogy — planning permission versus the builder's drawings.** ⭐ **Planning permission argues that
a two-storey extension is appropriate for the street and shows the neighbours what changes; the
builder's drawings say the joists are 220 mm at 400 mm centres.** The analogy predicts everything:
the committee cannot approve joist specifications, the builder cannot build from a planning
statement, ⭐ **and the objections you record now are what stop the argument being re-run later.**

**The one line:** ⭐ **HLD records the decision and why the alternatives lost; LLD records the
values.**

---

## 11. Self-test

1. State the altitude test in one sentence.
   → ⭐ If an approver could detect the error, HLD; if only an implementer could, LLD.
2. Why record rejected options?
   → ⭐ Proves the decision was a choice, and prevents the argument being re-run.
3. Which HLD block do juniors omit, and what does it cost?
   → ⭐ `IMPLICATIONS` — the future complaint becomes an accepted decision.
4. Why is a screenshot in an HLD a smell?
   → ⭐ It dates the document to a UI, and signals a click path rather than a decision.
5. What does every risk need?
   → ⭐ A number, a likelihood/impact, a mitigation, and a named owner.
6. Emergency remediation happened with no design. What now?
   → ⭐ Write the HLD after, within a week. The decisions still need a home.
7. Test for whether a paragraph belongs at all?
   → ⭐ If it would be true for any customer, delete it.

---

## 12. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | the current-state capture (§6) used as HLD input |
| `architecture-decisions` | ⭐ at least two complete decision records in the §4 format |
| `operations` | the numbered risk register with owners |
| `customer-use-cases` | the cost implication table as presented to a sponsor |
| `break-fix` | one design revisited because a rejected option was not recorded |
