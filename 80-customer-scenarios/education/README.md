# Education

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **Boundary:** [`../LAYER-7-INDUSTRY-VERTICALS.md`](../LAYER-7-INDUSTRY-VERTICALS.md) §8 is the
> brief. ⭐ **This is engagement depth — the vertical where the users are children, the churn is
> annual and total, and the budget is close to zero.** Pairs with
> [`../../30-identity-and-nhi/entra-users-and-groups/`](../../30-identity-and-nhi/entra-users-and-groups/).

---

## 1. What it is

Identity engineering for schools, colleges and universities: two populations (staff and students)
with completely different rules, ⭐ **an entire cohort arriving and leaving on the same day each
year**, minors as end users, and an IT team of two people supporting thirty thousand accounts.

⭐ **Everything here is decided by scale-per-administrator, not by scale alone.**

---

## 2. Why it is different

| Standard assumption | ⭐ Education reality |
|---|---|
| Users are adults | ⭐ **users may be 8 years old** — ⭐ consent and privacy law differ |
| Gradual churn | ⭐ **a whole year group leaves in July, another arrives in September** |
| Helpdesk can handle resets | ⭐ **30,000 students in week one** — ⭐ it cannot |
| Users have phones | ⭐ **primary pupils do not; ⭐ policy may forbid them on site** |
| Security wins arguments | ⭐ **a lesson that cannot start is a bigger problem** |
| There is a budget | ⭐ ⭐ **A1 is free; A3/A5 are a business case** |

⭐ **The under-13 population changes the legal frame, not just the tone.** ⭐ **Parental consent
requirements, restrictions on data processing and limits on what may be collected apply to children
in most jurisdictions** — ⚠ names and thresholds vary (COPPA in the US, UK/EU age-of-consent rules,
and local equivalents), so ⭐ **the customer's data protection officer owns the interpretation and
you own the implementation** — the same boundary as
[`../fintech-and-banking/`](../fintech-and-banking/) §3.

---

## 3. How it works underneath — the academic year is the lifecycle

```
  ⭐ THE ENTIRE IDENTITY LIFECYCLE RUNS ON ONE CALENDAR

  ⭐ JULY        cohort leaves ──► ⭐ what happens to their data?
                                   ⭐ ← decide this BEFORE the first September
                ▸ delete? archive? ⭐ convert to alumni?
                ▸ ⭐ mailbox, OneDrive, coursework - ⭐ retention obligations

  AUG/SEP     ⭐ new cohort arrives, ⭐ ALL AT ONCE
                ▸ ⭐ roster feed (SIS/MIS) → provisioning
                ▸ ⭐ first credential problem × thousands, in one week

  ⭐ IN-YEAR    class changes, ⭐ group membership by timetable
                ▸ ⭐ dynamic groups from the roster attribute

  ⭐ EXAM TIME  ⭐ absolute peak, ⭐ zero tolerance for outage
                ▸ ⭐ change freeze - ⭐ same principle as retail's December
```

⭐ **The July decision is the one that is expensive to defer.** ⭐ **A university that has never
decided what happens to leavers' accounts accumulates every cohort forever** — licences, storage,
and thousands of dormant credentials that are perfect for credential stuffing.

⭐ **Alumni are a *third* population**, and treating them as either staff or students is wrong: they
need mail forwarding or a lightweight identity, no licence, and no access to systems. ⭐ **Deciding
the alumni model is an architecture decision with a recurring cost attached.**

---

## 4. Worked example — the September credential problem

⭐ **Ten thousand new students, one week, two support staff. Arithmetic decides the design:**

```
  10,000 new students
  ⭐ Assume 15 % need help with first sign-in     = 1,500 contacts
  ⭐ At 6 minutes each                            = 150 hours
  ⭐ Two support staff × 37.5 h                   = 75 hours available

  ⭐ SHORTFALL: 2× the entire team's week, ⭐ on top of everything else.
  ⭐ → SELF-SERVICE IS NOT A NICE-TO-HAVE. It is the only viable design.
```

⭐ **This calculation is the business case, and it takes four lines.** ⭐ **Present the hours, not the
feature** — "self-service password reset" is a product; "150 hours you do not have" is a decision.

**The design that follows, and the check that proves it is ready:**

```powershell
# ⭐ Are students actually registered for self-service reset?
# ⭐ Registration BEFORE September is the whole game - after, it is too late.
Get-MgReportAuthenticationMethodUserRegistrationDetail -All |
  Where-Object { $_.UserType -eq 'Member' } |
  Group-Object IsSsprRegistered |
  Select-Object @{n='Registered';e={$_.Name}}, Count
```

```
Registered  Count
False       8,214   ⭐ ← ⭐ September will fail
True        1,786
```

⭐ **8,214 unregistered users is a support incident scheduled for the first week of term.** ⭐ **The
fix is to force registration at first sign-in during induction, while the student is sitting in
front of someone who can help** — not in week three when they have forgotten their password and the
queue is out of the door.

⭐ **Combine with Temporary Access Pass for induction:** ⭐ **issue a time-limited pass, have the
student register their method during the session, and the credential problem is solved once rather
than repeatedly.** See
[`../../30-identity-and-nhi/authentication-methods/`](../../30-identity-and-nhi/authentication-methods/).

**The roster feed — ⭐ automation is not optional at this scale:**

```powershell
# ⭐ Dynamic group from the roster attribute: class of 2030, automatically
$rule = '(user.userType -eq "Member") -and (user.department -eq "Y7") ' +
        '-and (user.extensionAttribute1 -eq "Student")'
New-MgGroup -DisplayName 'GRP-Students-Y7' -MailEnabled:$false `
  -SecurityEnabled -MailNickname 'grp-students-y7' `
  -GroupTypes 'DynamicMembership' -MembershipRule $rule `
  -MembershipRuleProcessingState 'On'
```

⭐ **Year-group promotion then becomes an attribute update in the student information system**, and
every group, licence and access assignment follows. ⭐ **A school that promotes year groups by
editing group membership by hand will spend August doing it and will make mistakes.**

---

## 5. Design reference

| Control | Setting | ⭐ Education reason |
|---|---|---|
| ⭐ Provisioning | ⭐ **from the SIS/MIS roster**, automated | ⭐ whole cohorts, one day |
| Groups | ⭐ dynamic, by year/class attribute | ⭐ promotion is an attribute change |
| ⭐ SSPR | ⭐ **mandatory registration at induction** | ⭐ §4 arithmetic |
| Student MFA | ⭐ risk-based where licensing allows; ⭐ mind young pupils | ⭐ no phones for primary |
| ⭐ Staff MFA | ⭐ **enforced, phishing-resistant for admins** | ⭐ staff hold the sensitive data |
| ⭐ Leavers | ⭐ **a written July policy**: delete / archive / alumni | ⭐ decide before the first September |
| Guests | ⭐ restricted — ⭐ pupils must not invite | safeguarding |
| ⭐ Exam period | ⭐ change freeze | zero tolerance |
| ⭐ Licensing | A1 free / A3 / A5 — ⭐ **verify per population** | ⚠ check current SKU contents |

⭐ **The staff/student split is the most important line in the design.** ⭐ **Staff hold safeguarding
records, exam material and payroll; students hold their own coursework.** Applying one policy to
both either over-restricts 30,000 children or under-protects the people with the sensitive data —
⭐ **and the second is the one that appears in the news.**

⭐ **Safeguarding is a genuine, non-negotiable requirement in schools** and it constrains identity
design: ⭐ **pupils must not be able to invite external guests, and staff-to-pupil communication
channels are usually policy-controlled.** ⚠ The specific obligations vary by jurisdiction; ⭐ ask,
and let the safeguarding lead own the answer.

---

## 6. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| ⭐ Support collapses in September | ⭐ no self-service registration | ⭐ force registration at induction |
| ⭐ Every cohort still in the tenant | ⭐ no leaver policy | ⭐ decide the July action, in writing |
| Year promotion takes all August | ⭐ manual group membership | ⭐ dynamic groups on a roster attribute |
| MFA rollout blocked for pupils | ⭐ no phones, ⭐ age rules | ⭐ different design per population |
| ⭐ Pupil invited an external guest | guest settings unrestricted | ⭐ restrict who can invite |
| Change broke logins during exams | ⭐ no freeze | published freeze dates |
| ⭐ A5 assumed, A1 in place | licence not verified per population | ⭐ check before designing |

⭐ **"A5 assumed, A1 in place" is worth its own note because education licensing is unusually
layered.** ⭐ **A tenant can hold different SKUs for staff and students simultaneously**, so
"we have A5" may be true of forty staff and false of ten thousand students — ⭐ **and the risk-based
policy you designed will silently apply to nobody.** Verify per population, not per tenant.

---

## 7. Customer discovery questions

1. ⭐ **"What happens to a student's account and data when they leave?"**
2. ⭐ **"How many accounts are created in September, and over how many days?"**
3. "Which system is authoritative for enrolment, and does it feed Entra?"
4. ⭐ **"What licence does each population actually hold — staff and students separately?"**
5. "What is the youngest age of a user, and who owns the consent question?"
6. ⭐ **"Do you have an alumni population, and what do they get?"**
7. ⭐ **"When are exams, and what is frozen during them?"**

---

## 8. Remember it

**Hook — ⭐ `S S A`: Staff, Students, Alumni** — ⭐ **three populations, three designs, and the third
one is always forgotten.**

**Analogy — a school building at the start of term.** ⭐ **You do not issue keys to eight hundred new
pupils one at a time at the front desk; you set up the entry system before the holiday ends, and the
roster decides who gets in.** The analogy predicts each rule: ⭐ **the work happens in August, not
September** (pre-registration), ⭐ **the roster drives the door, not a person with a clipboard**
(dynamic groups), and ⭐ **you decide in advance what happens to the leavers' keys** — because
otherwise you have eight hundred more keys in circulation every year.

**The one line:** ⭐ **Automate from the roster, force self-service registration before term starts,
and write the July leaver policy before the first September.**

---

## 9. Self-test

1. Name the three populations and why the third matters.
   → ⭐ Staff, students, alumni. Alumni accumulate forever without a decided model.
2. Why is self-service registration a design requirement rather than a feature?
   → ⭐ The support arithmetic: 15 % of 10,000 new users exceeds the team's entire week, twice over.
3. When must self-service registration happen, and why?
   → ⭐ At induction, with help present — not in week three when the queue has formed.
4. What makes year-group promotion cheap?
   → ⭐ Dynamic groups driven by a roster attribute; promotion is an attribute update.
5. Why must staff and student policies differ?
   → ⭐ Staff hold safeguarding, exam and payroll data; one blanket policy either over-restricts pupils or under-protects staff.
6. Why verify licences per population?
   → ⭐ Staff and students commonly hold different SKUs; a P2-dependent design may apply to nobody.
7. What changes when users are children?
   → ⭐ Consent and data-processing rules; the DPO owns the interpretation, you own the implementation.

---

## 10. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | ⭐ the SSPR registration query, before and after an induction push |
| `operations` | ⭐ the September support arithmetic, and the design it justified |
| `security` | the staff-vs-student policy split, and guest-invite restrictions |
| `customer-use-cases` | ⭐ the written July leaver policy: delete, archive or alumni |
| `architecture-decisions` | ⭐ licence entitlement verified **per population**, with the date |
