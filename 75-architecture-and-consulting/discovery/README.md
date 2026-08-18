# Discovery (engagement)

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **Boundary:** this is **engagement** discovery — people, drivers, constraints, decision rights.
> The **technical estate** inventory is
> [`../../45-m365-migration-engineering/discovery-and-assessment/`](../../45-m365-migration-engineering/discovery-and-assessment/).
> ⭐ **Run both. They answer different questions and fail in different ways.**

---

## 1. What it is

The structured first phase of an engagement: who the stakeholders are, what is actually driving the
work, what constrains it, who can decide, and what "done" looks like. It produces the inputs to
[`../requirements/`](../requirements/) and the context that makes [`../hld/`](../hld/) defensible.

⭐ **Technical discovery tells you what exists. Engagement discovery tells you why anyone cares, and
who can say yes.**

---

## 2. Why it exists

⭐ **Most failed engagements were technically successful.** The pattern is consistent:

| What was missed | What happened |
|---|---|
| ⭐ **The real driver** | built for efficiency; ⭐ the driver was an **insurance renewal** — wrong priorities |
| Decision rights | design approved by someone who could not approve it; ⭐ **redone** |
| ⭐ **The blocker nobody owns** | DNS controlled by a parent company in another timezone |
| The political constraint | ⭐ replacing a product the sponsor's colleague selected |
| Who does the work after | ⭐ built for an ops team that does not exist |

⭐ **The last one is the most common and the most damaging.** A design the customer cannot operate
is a design that fails six months after you leave, and your name is on it.

---

## 3. How it works underneath — four passes, in order

```
① DRIVER      ⭐ WHY NOW? audit · breach · renewal · merger · a person left
                 (⭐ "why now" beats "why" — it dates the deadline)
      │
② STAKEHOLDER Sponsor · decision-maker · operator · ⭐ BLOCKER
      │       RACI, with human names
      │
③ CONSTRAINT  budget · deadline · residency · politics · ⭐ skills after handover
      │
④ SUCCESS     ⭐ "how will you know this worked?" ──► acceptance criteria
      │
      ▼
   INPUT TO  ../requirements/  ──►  ../hld/
```

⭐ **Ask ① first and everything else reorders.** *"We're modernising identity"* and *"our cyber
insurer requires MFA by 30 June or the premium triples"* produce completely different projects from
the same technical scope — different sequence, different evidence, different definition of done.

---

## 4. Worked example — the stakeholder map that prevents the rework

Names, roles, and — ⭐ **the column everyone omits** — what each person can *stop*:

```
NAME            ROLE              RACI  ⭐ CAN BLOCK BY            AVAILABILITY
J. Okafor       Head of IT Sec    A     ⭐ refusing design sign-off  weekly, Tue
S. Fernandes    Sponsor / CFO     A     ⭐ funding                   monthly
D. Mwangi       IT Manager        R     day-to-day resource         daily
L. Petrov       Service Desk Lead C     ⭐ REFUSING HANDOVER         daily
Parent Co. NOC  DNS owner         C     ⭐ NOT MAKING DNS CHANGES    ⭐ ticket, 5-day SLA
Works Council   Employee reps     C     ⭐ MONITORING OBJECTIONS     ⭐ meets monthly
```

⭐ **Two rows there are the entire risk register.**

⭐ **Parent Co. NOC with a five-day DNS SLA destroys any cutover plan built on a 30-minute change
window** — and it is invisible unless you ask *"who actually types the DNS change, and how do they
receive the request?"* See [`../../45-m365-migration-engineering/cutover-and-rollback/`](../../45-m365-migration-engineering/cutover-and-rollback/) §3.

⭐ **A works council that meets monthly can delay any change touching employee monitoring** — sign-in
logs, Identity Protection, Insider Risk. In much of Europe this is a legal consultation, not a
courtesy. ⭐ **Discovering it in month three costs a month; discovering it in week one costs an
email.**

**The `A` column is the one to get right.** In RACI there is ⭐ **exactly one Accountable per
decision**. Two people in the `A` column is not thoroughness — it is an unresolved argument you have
written down and will inherit.

---

## 5. Commands — arrive already knowing

⭐ **Never spend a workshop asking what a script can answer.** Pull the facts first; spend the human
hour on the things only humans know.

```powershell
Connect-MgGraph -Scopes 'Directory.Read.All','Policy.Read.All','Reports.Read.All'

[pscustomobject]@{
  Users       = @(Get-MgUser -All -Property UserType).Count
  Guests      = @(Get-MgUser -All -Filter "userType eq 'Guest'").Count
  Groups      = @(Get-MgGroup -All).Count
  CAPolicies  = @(Get-MgIdentityConditionalAccessPolicy -All).Count
  ReportOnly  = @(Get-MgIdentityConditionalAccessPolicy -All |
                  Where-Object State -eq 'enabledForReportingButNotEnforced').Count
  Apps        = @(Get-MgServicePrincipal -All).Count
}
```

```
Users Guests Groups CAPolicies ReportOnly Apps
  517    204    189          6          4  312
```

⭐ **Four of six CA policies in report-only is a finding you can open the workshop with**, and it
lands very differently from *"tell me about your Conditional Access."* It says you did the work
before the meeting.

⭐ **204 guests against 517 members is the second question**, and *"who reviews these?"* usually has
no answer — which is your access-review conversation, ready made.

**Who actually holds privilege — the question customers cannot answer from memory:**

```powershell
Get-MgDirectoryRole -All | ForEach-Object {
  $m = @(Get-MgDirectoryRoleMember -DirectoryRoleId $_.Id -All)
  if ($m.Count) { [pscustomobject]@{ Role = $_.DisplayName; Members = $m.Count } }
} | Sort-Object Members -Descending | Select-Object -First 5
```

```
Role                    Members
Global Administrator          9
Exchange Administrator        4
User Administrator            3
```

⭐ **Nine Global Administrators in a 517-user tenant is a discovery finding, a requirement, and a
quick win in one line** — and it is the single best opening slide you can have.

---

## 6. When and where

| Engagement | Discovery shape |
|---|---|
| Small, well-defined | ⭐ one 90-minute workshop + the §5 pull |
| Migration | ⭐ **both** discoveries — engagement **and** technical estate |
| Security assessment | heavier on constraints, compliance and evidence obligations |
| ⭐ Managed-service onboarding | ⭐ heaviest on **operations after handover** — [`../handover/`](../handover/) |

⭐ **Timebox it and publish the findings within 48 hours.** Discovery that runs long stops being
discovery and becomes unpaid consulting; a findings document delivered fast is also the fastest way
to demonstrate value before any build has happened.

---

## 7. What breaks

| Symptom | Root cause | Fix |
|---|---|---|
| Design rejected late | ⭐ wrong person approved it | RACI with one `A`, agreed in writing |
| Deadline slips on someone else's task | ⭐ external dependency not mapped | §4 blocker column |
| Solution nobody uses | driver was assumed | ⭐ ask **"why now"**, not "why" |
| Handover refused | ⭐ operator never consulted | ⭐ put the service desk lead in discovery, not handover |
| Workshop wastes an hour on facts | no pre-pull | §5, before the meeting |
| "We told you that in April" | ⭐ not written down | ⭐ publish findings in 48 h and ask for corrections |

⭐ **The 48-hour findings document is also your defence.** Anything the customer does not correct
within a week becomes the agreed baseline — and that is a professional norm, not a trick.

---

## 8. Customer discovery questions

1. ⭐ **"Why now? What happens if this slips six months?"**
2. "Who signs off the design, and who else could stop it?"
3. ⭐ **"Who will run this after we leave, and what are they trained on today?"**
4. "Which third parties must act for us to succeed, and how do we raise a request?"
5. "Is there anything you cannot do for legal, contractual or employee-relations reasons?"
6. ⭐ **"What has been tried before, and why did it stop?"** — the political history, obtained safely
7. "How will you know this worked?" → [`../requirements/`](../requirements/)

⭐ **Question 6 is the highest-yield question in consulting.** It surfaces the failed predecessor
project, the vendor who was fired, and the sponsor's personal stake — none of which anyone will
volunteer, and all of which will otherwise shape the engagement invisibly.

---

## 9. Remember it

**Hook — `D S C S`: Driver, Stakeholders, Constraints, Success.** In that order; each reorders the
next.

**Analogy — a doctor's consultation, not a lab test.** ⭐ **The blood panel (technical discovery)
tells you the values; the consultation tells you the patient is a nightshift worker who cannot take
this at 8 a.m.** The analogy predicts the failures: **a clinically perfect prescription the patient
cannot follow is a failed treatment** — which is exactly the design handed to an ops team that
cannot run it, and exactly why the service desk lead belongs in week one.

**The one line:** ⭐ **Find the driver, the one Accountable name, the blockers you do not control,
and who runs it after you leave.**

---

## 10. Self-test

1. Difference between engagement discovery and technical discovery?
   → ⭐ People, drivers and decision rights vs the estate inventory. Both required.
2. Why "why now" rather than "why"?
   → ⭐ It dates the deadline and exposes the real driver.
3. How many people are Accountable for one decision?
   → ⭐ Exactly one. Two is an unresolved argument.
4. Which stakeholder is most often missing, and what does that cost?
   → ⭐ The operator/service desk — handover is refused at the end.
5. Why pull tenant facts before the workshop?
   → ⭐ Human time is for what only humans know; it also demonstrates competence immediately.
6. What does a 5-day DNS SLA at a parent company do to a cutover plan?
   → ⭐ Invalidates any short change window; must be designed around.
7. Why publish findings within 48 hours?
   → ⭐ It sets an agreed baseline and shows value before build.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | the §5 pre-pull output from a real tenant |
| `operations` | the RACI with the "can block by" column completed |
| `customer-use-cases` | a findings document published within 48 h of a workshop |
| `architecture-decisions` | ⭐ one decision that changed because of a discovery finding |
| `break-fix` | one external dependency that would have derailed the plan, caught early |
