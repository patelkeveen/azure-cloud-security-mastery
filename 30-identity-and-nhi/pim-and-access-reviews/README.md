# PIM and Access Reviews

> **Concept facet.** Full depth in
> **[LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md](LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md)** in this
> folder. Both features are **P2** — no add-on required.

## What they are

**PIM** removes standing privilege: administrators are *eligible* for a role and **activate** it
when needed, with approval, justification and a time limit. **Access reviews** periodically ask a
human to confirm that existing access is still justified.

Together they answer the two questions every auditor asks: *"who can do this?"* and *"who checked?"*

## PIM — the assignment matrix

Most people think the choice is "eligible vs active." It is a **2×2**:

| | Permanent | Time-bound |
|---|---|---|
| **Eligible** | Can activate any time, indefinitely | Can activate until a date |
| **Active** | **Standing access — the thing PIM exists to eliminate** | Standing, with an expiry |

**Target state for humans: eligible + time-bound.** Permanent active should exist only for
break-glass. Being able to draw this grid is a fast way to show you have operated PIM rather than
read about it.

## The activation setting that impresses

Beyond MFA, justification and approval, PIM activation can **require a Conditional Access
authentication context** — so elevating to Global Administrator demands a **passkey**, not a push.

That configuration is **the single most impressive control you can demo in an interview**, and it
is P2. Bind context `c1` to phishing-resistant strength, attach it to the role.

## PIM for Groups

Make a group PIM-managed and **membership itself becomes just-in-time**. This is the workaround for
everything without native PIM support — a group granting a SaaS app role, an Azure RBAC assignment,
an on-prem-synced group. **Confirmed P2**, not an add-on.

## Licence expiry is a security event, not trivia

When P2 or Governance lapses — **including a trial ending**:

- Active **permanent** assignments — unaffected
- Active **time-bound** assignments — **become permanent**
- **Eligible assignments are removed entirely**

**A lapsed licence silently converts time-bound admin access into standing admin access** while
deleting the just-in-time path everyone relied on. **This will happen in your lab tenant when the
trial ends.** It is also a first-class discovery question: *"what is your PIM renewal date, and who
watches it?"*

## Access reviews — the hard part is the reviewer

| Reviewer | Good for | Failure mode |
|---|---|---|
| Manager | Broad recertification | **Rubber-stamping** — managers rarely know what a group grants |
| Group/app owner | Access to *their* resource | May not know the person |
| Self-review | Cheap, wide | Nobody removes their own access |

Two settings decide whether the exercise is real:

1. **Auto-apply.** Without it, decisions are recorded and **nothing happens**. This is the single
   most common reason an organisation "does access reviews" and access never changes.
2. **If reviewers don't respond.** Setting this to *Approve* makes the whole thing theatre. Choose
   *Remove* or *No change* and mean it.

**Licence counting is by reviewed population, not reviewers.** A 500-member group with 3 reviewers
needs **503** licences.

## Break-glass — specified, not improvised

Two accounts · cloud-only on `*.onmicrosoft.com` · **permanent active Global Admin and NOT
PIM-eligible** · excluded from every CA policy · no single-method MFA dependency · credentials split
and physically secured · **alerting on any sign-in** · tested on a schedule.

> **The property people get wrong is "not PIM-eligible."** The situations where you need
> break-glass are exactly the situations where PIM is unavailable or its licence has lapsed.

## Evidence this topic needs

- `lab/` — make yourself eligible, activate, **decode the token and find `wids`** (Layer 1 §4);
  bind activation to an authentication context requiring a passkey.
- `break-fix/` — an access review with auto-apply ON and no-response = Remove; ignore one decision
  deliberately and watch that user lose access.
- `security/` — standing-privilege report before and after; break-glass alert rule deployed.
- `operations/` — break-glass test procedure; PIM approval workflow; review cadence.
