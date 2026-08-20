# D4 — Plan and automate identity governance · 20–25%

> ⭐ **Domains 1–3 control who gets in. This one controls who *keeps* getting in.**
> ⭐ **That is where real organisations actually fail** — access is granted correctly, then never
> removed, and eight years later everyone can see everything.

---

## 1. PIM — eligible vs active

**Age 8** — You're **allowed** to use the art cupboard, but you don't carry the key around all day.
When you need it you ask, they hand it over, and it goes back at four o'clock. ⭐ **You're still
"the person allowed" the whole time — you just aren't holding the key.**

**Any adult** — Privileged Identity Management separates **being entitled** to a role from
**currently having** it. An admin is *eligible* all year and *active* for the two hours a month
they actually need it.

⭐ **The business case in one sentence: PIM does not change who can do what — it changes for how
long.** Same people, same capability, exposure window collapses from permanent to hours. ⭐ **That
is the answer to "won't this slow us down?"**

**Technical** — The 2×2 that gets tested:

```
                TIME-BOUND (has an end date)      PERMANENT (no end date)
ELIGIBLE        can activate, until <date>        can activate, forever
ACTIVE          holds it now, until <date>        ⭐ holds it now, forever  <- the thing you are removing
```

⭐ **Exam** — ⭐ **"Standing privilege" means permanent + active — that is the anti-pattern.**
⭐ **"Just-in-time" means eligible + activate on demand.**

⚠ **Licence expiry is a security event, and it is examinable and real:** when P2 lapses,
**eligible assignments are DELETED** and ⭐ **time-bound *active* assignments become PERMANENT.**
The lapse silently converts your JIT model into standing privilege — a security event dressed as a
billing event.

⭐ **Hook** — **Eligible = allowed. Active = holding it. Permanent + active = the thing you're removing.**

---

## 2. PIM activation — approval, justification, MFA

**Age 8** — To get the cupboard key you have to **say why**, and sometimes a **teacher has to nod**.
And they check it's really you first.

**Any adult** — Activating a privileged role can require: MFA at activation, a written business
justification, a ticket number, and another human's approval. ⭐ **Each of these turns "an attacker
with your session" into "an attacker who must also convince a second person."**

**Technical** — Per-role activation settings: maximum duration, require MFA, require justification,
require ticket info, require approval (with named approvers), and notification rules.

⭐ **Exam** — ⭐ **"Require approval" is the control that defeats a compromised admin session**,
because the approver is out of band. ⭐ **Notifications matter too**: an activation nobody is told
about is an activation nobody can challenge.

⚠ **Watch the wording:** *"require MFA to activate"* is a PIM setting; *"require MFA to sign in"*
is Conditional Access. ⭐ **Different controls, different blades, and the exam mixes them
deliberately.**

⭐ **Hook** — **Approval beats a stolen session, because the approver is a different human.**

---

## 3. Access reviews

**Age 8** — Once a term, the teacher reads out the art-cupboard list and asks **"do you still need
this?"** Anyone who doesn't answer loses it.

**Any adult** — A scheduled re-confirmation that people still need what they have. ⭐ **The design
question that matters is what happens when nobody replies** — and the honest answer is that most
people never reply.

**Technical** — Reviews target group members, app assignments, or directory/Azure roles. Reviewers
can be the resource owner, the users' managers, self-review, or a named group.

⭐ **Exam — the settings that carry the marks:**

| Setting | Why it's tested |
|---|---|
| ⭐ **"If reviewers don't respond"** | **No change** · **Remove access** · **Approve access** · Take recommendations. ⭐ **This single dropdown decides whether the review does anything** |
| Auto-apply results | Without it, decisions are recorded and ⭐ **never enforced** |
| Recommendations | Based on last sign-in (e.g. 30 days inactive) |
| Reviewer choice | ⭐ **Self-review is the weakest** — everyone approves themselves |

⭐ **"The review that changes nothing"** — set to *No change* with auto-apply off — ⭐ **is a
compliance artifact, not a control**, and it is exactly the scenario the exam describes to see if
you notice. ⭐ **It is the same "deployed is not enforced" pattern as report-only CA.**

⭐ **Hook** — **A review with "no change" and no auto-apply is theatre. Check the dropdown.**

---

## 4. Entitlement management — catalog, access package, policy

**Age 8** — Instead of asking five different teachers for five different things, there's **one
form**: *"I'm joining the school play."* Tick it, and you automatically get the costume cupboard,
the rehearsal room and the group chat — ⭐ **and it all goes away when the play ends.**

**Any adult** — Bundle everything a role needs into **one requestable package** with an approval
workflow and an **automatic expiry**. ⭐ **The expiry is the point** — it is the only mechanism here
that removes access without anyone remembering to.

**Technical**

```
CATALOG          a container of resources (groups, apps, SharePoint sites)
ACCESS PACKAGE   a bundle of those resources + the policies to obtain them
POLICY           WHO may request · WHO approves · HOW LONG it lasts · review on renewal
```

Multiple policies per package let internal staff, and partners, follow different rules for the
same bundle. Requires **Entra ID Governance / P2**.

⭐ **Exam** — ⭐ *"New joiners in Sales should get everything they need without raising five
tickets"* → **access package**. ⭐ **Catalog owners can delegate** — a business owner manages their
own catalog without being a directory admin, which is the delegation answer.

⚠ **Access packages grant through groups and apps — they do not grant directory roles.** ⭐ **Role
assignment is PIM's job.** Mixing those two up is a trap.

⭐ **Hook** — **Catalog = the shelf. Package = the bundle. Policy = who may take it and for how long.**

---

## 5. Connected organizations

**Age 8** — Children from the **partner school down the road** can ask for a package themselves,
and **their own** teacher approves it. They only get a badge **after** they're approved.

**Any adult** — A way to let people from a named external company request access **before they
exist in your directory**. ⭐ **The guest account is created on approval, not invited up front** —
governance first, guest object second.

**Technical** — A connected organization represents an external Entra tenant or domain, with
**sponsors** (internal and/or external) who can act as approvers. State is **configured**
(deliberately added) or **proposed** (auto-discovered because a user from that domain already
exists). Policies target *specific* connected organizations, **all configured** ones, or **all
users including new external users**.

⭐ **Exam** — ⭐ *"Partner staff request access themselves, their own manager approves, an account
is created only if approved"* → **access package + connected organization with an external
sponsor**. ⭐ **Contrast with a plain B2B invite:** the invite creates the object immediately with
**no lifecycle, no expiry, no review**. ⭐ **That difference is the answer.**

⭐ **Hook** — **Invite = object first, governance never. Connected org = governance first, object on approval.**

---

## 6. Lifecycle workflows

**Age 8** — On your **first day** the school automatically gives you a locker, a login and a
lunch card. On your **last day** it automatically takes them all back — nobody has to remember.

**Any adult** — Automation triggered by dates on the user record: joiner, mover, leaver. ⭐ **The
leaver half is what auditors actually check**, because "we forgot to disable him" is the finding
that appears in every breach report.

**Technical** — Workflows run on **`employeeHireDate`** and **`employeeLeaveDateTime`**, with
offsets (e.g. 7 days before hire, on the leave date, 30 days after). Tasks include enable/disable
account, add/remove group and Teams membership, generate a TAP, send a manager email, remove all
licences. ⭐ **Requires the Entra ID Governance SKU — not plain P2.**

⭐ **Exam** — ⚠ **The attributes must actually be populated.** ⭐ **A lifecycle workflow with an
empty `employeeLeaveDateTime` fires for nobody**, and that is the tested failure. It usually means
HR is the real source of truth and nobody wired HR into the directory.

⭐ *"Generate a TAP seven days before the hire date and email the manager"* → **joiner workflow**,
and it ties straight back to [`D2`](D2-AUTH-AND-ACCESS.md) §4.

⭐ **Hook** — **No `employeeLeaveDateTime`, no leaver workflow. Check the attribute before the automation.**

---

## 7. Separation of duties and role-assignable groups

**Age 8** — The person who **counts** the sweets shouldn't also be the person who **buys** them.
And the list of who's allowed near the sweets is kept in a **special locked book** that only the
head teacher can edit.

**Any adult** — **Separation of duties** stops one person holding two roles that together let them
act unchecked — requesting *and* approving, for instance. **Role-assignable groups** are protected
groups whose membership grants directory roles, so they get extra locks.

**Technical** — Entitlement management supports **incompatible access packages**: holding package A
blocks requesting package B. For groups:

```
isAssignableToRole = true   ⭐ MUST be set AT CREATION. Cannot be added later.
membership type             ⭐ MUST be Assigned. Dynamic is FORBIDDEN.
who can manage it           Privileged Role Administrator / Global Administrator only
```

⭐ **Exam** — ⭐ **"Create a dynamic group that receives the Helpdesk role" is impossible**, and it
is offered. ⭐ **The reason is a security boundary:** dynamic membership would let anyone who can
edit a user attribute grant themselves a privileged role.

⭐ **PIM for Groups** extends eligible/active to **group membership and ownership** — so a user can
be *eligible* to become a member of a privileged group. ⭐ **It is P2, and it is the answer for
making SaaS-app admin access just-in-time** when the app has no Entra role of its own.

⭐ **Hook** — **Role-assignable: set at birth, Assigned only, Privileged Role Admin owns it.**

---

## Say it back — cover the right column

| Prompt | Answer |
|---|---|
| Eligible vs active | Eligible = can activate. Active = holds it now |
| Standing privilege | Permanent + active — the anti-pattern |
| P2 licence lapses | Eligible assignments **deleted**; time-bound active become **permanent** |
| Defeats a compromised admin session | Require **approval** on activation |
| Review where nobody responds | Depends entirely on the "if reviewers don't respond" setting |
| Review recorded but never enforced | Auto-apply was off |
| Weakest reviewer type | Self-review |
| Joiner needs 5 things, no tickets | Access package |
| Partner requests before existing in directory | Connected organization + external sponsor |
| Access packages grant roles? | ⚠ No — groups and apps. Roles are PIM |
| Leaver workflow fires for nobody | `employeeLeaveDateTime` not populated |
| Dynamic group for a privileged role | Impossible — role-assignable must be Assigned |
| JIT admin for a SaaS app with no Entra role | PIM for Groups |

> ⭐ **The pattern across all four domains, and worth saying out loud once:**
> **deployed is not enforced.** Report-only CA, audit-mode password protection, a review with
> auto-apply off, a lifecycle workflow with no source attribute, a risk policy nobody actions.
> ⭐ **Every one of them looks like a control on a slide and does nothing in production.**

> **Back to:** [`README.md`](README.md) · **Labs:** [`../DAY-4.md`](../DAY-4.md), [`../DAY-5.md`](../DAY-5.md)
