# Lifecycle Workflows

> **Concept facet.** Depth in
> [Layer 5 §1](../pim-and-access-reviews/LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md).
> ⚠ **Requires the Entra ID Governance SKU — not included in P2.**

## What it is

Automation for **joiner, mover, leaver** — the three moments when access should change and usually
doesn't. Workflows trigger on attribute-driven conditions (hire date, department change,
termination date) and execute a task sequence.

## Why it exists

Because the leaver process is the weakest control in almost every organisation, and it fails
quietly. Nobody notices that someone who left in March still has access in September — until an
audit, or an incident.

The measurable question, from [DAY-05](../../DAILY-EXECUTION/DAY-05.md): **"how long from
termination to access actually revoked — measured, not intended?"** Nobody knows. Finding out is
frequently the first real deliverable of an engagement.

## How it works underneath

```
TRIGGER (attribute-based, e.g. employeeHireDate - 7 days)
  → SCOPE (a rule selecting which users)
    → TASK SEQUENCE (built-in tasks, executed in order)
```

Built-in tasks cover the common needs: enable/disable an account, add to or remove from groups and
Teams, assign or remove licences, generate a Temporary Access Pass, send email, and — via **custom
task extensions** — call a **Logic App** to reach any system with an API.

That extension point is what makes it a real integration platform rather than a checkbox: HR system,
badge access, laptop provisioning, third-party SaaS.

## When and where

- **High-churn populations** — retail seasonal waves, education cohorts, clinical rotations
- **Any regulated environment** where you must *evidence* that leavers lost access on time
- Where onboarding currently depends on a person remembering a checklist

The scenario that sells it: hiring 3,000 seasonal staff in six weeks means offboarding 3,000 in
another six. Manual offboarding at that rate does not happen.

## The licensing reality — check before designing

**Lifecycle Workflows genuinely requires Entra ID Governance.** It is *not* in P2. This is the one
governance feature where the SKU boundary bites hardest, because it is the feature customers most
want after seeing entitlement management.

Licence counting is by **population in scope**, not by administrator — a workflow touching 400 new
hires needs 400 licences plus one for the administrator.

**Do not design a JML programme around this and discover the licensing gap at implementation.**
Confirm entitlement in discovery.

## Relationship to the other governance pieces

| Need | Tool |
|---|---|
| Automatic, time-triggered lifecycle events | **Lifecycle Workflows** |
| Requestable, approved, expiring access | [Entitlement management](../entitlement-management/) |
| Periodic recertification of existing access | Access reviews |
| Just-in-time privilege | [PIM](../pim-and-access-reviews/) |

They compose. A joiner workflow grants baseline access; an access package grants role-specific
access on request; access reviews recertify it; PIM elevates it temporarily.

## The traps

1. **Designing it at P2.** The most common wasted design effort in identity governance.
2. **Triggering on attributes nobody populates.** `employeeHireDate` and `employeeLeaveDateTime`
   must actually flow from HR. In hybrid environments that is a *sync* problem first.
3. **Offboarding that disables the account but does not deprovision SaaS.** SCIM
   ([`../scim-and-provisioning/`](../scim-and-provisioning/)) is the other half; without it, live
   accounts remain in every connected application.
4. **No dry run.** Test with a scoped pilot group before letting a workflow touch the real
   population — a mis-scoped leaver workflow is a mass-disablement incident.

## Evidence this topic needs

- `lab/` — a joiner workflow from a template; scoped to test users; observe execution history.
- `break-fix/` — trigger on an unpopulated attribute; observe silence, then diagnose.
- `operations/` — workflow versioning, scheduling, history reporting.
- `customer-use-cases/` — retail seasonal; education cohort turnover.
