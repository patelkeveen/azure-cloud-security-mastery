# SCIM and Provisioning

> **Concept facet.** Depth in
> [Layer 4 §6](../service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md).

## What it is

**SCIM 2.0** — System for Cross-domain Identity Management — is the standard REST protocol for
pushing user and group lifecycle into an application. Entra acts as the source; the app exposes
`/Users` and `/Groups` endpoints.

## Why it exists

SSO solves *authentication*. It does nothing about *existence*. Without provisioning, a leaver who
loses their Entra account still has a live account in Salesforce, Zoom, Slack and thirty other
applications — they just cannot SSO into them. **If any of those allows a local password, access
survives offboarding entirely.**

**Provisioning is how leavers actually lose access.** An offboarding process that disables the
Entra account but does not deprovision is leaving live accounts behind everywhere.

## How it works underneath

```
Entra provisioning service
   ├── SCOPE     which users are in scope (assignment or filter)
   ├── MAPPING   Entra attribute → app attribute, with expressions
   └── CYCLE     initial (walks everything) then incremental (deltas)
```

- **Initial cycle** walks the entire scope — hours at scale, and it is *supposed* to be slow.
- **Incremental cycles** run periodically thereafter, typically every ~40 minutes.
- **Attribute mappings** support expressions — `Join`, `Replace`, `Mid`, `IIF` — for shaping values
  the target expects.
- **Matching attribute** decides how an existing app account is linked to an Entra user. Usually
  `userPrincipalName` → `userName`. **Get this wrong and you create duplicates rather than linking**
  — the same failure class as soft match in [hybrid identity](../hybrid-identity/).

## The trap that silently breaks offboarding: quarantine

**Repeated failures put the provisioning job into quarantine.** Provisioning stops. No error
appears in anyone's inbox. Weeks later, someone notices that new joiners never appeared — or worse,
that leavers never disappeared.

> **When someone says "the new starter never showed up in Salesforce," check provisioning status
> *before* anything else.** Quarantine is the answer more often than mapping is.

## Deprovisioning semantics — decide deliberately

What should happen when a user leaves scope? The options differ per application:

| Behaviour | Consequence |
|---|---|
| **Disable** | Account remains, cannot sign in. Data preserved. Usually correct |
| **Delete** | Account and often its data are gone. Rarely what you want first |
| **Do nothing** | The default in some connectors — **the silent failure** |

**Removing a user from the assigned group is what triggers deprovisioning.** Which means group
membership automation and offboarding automation are the same system, and a mistake in one is an
outage in the other.

## When and where

- **Any SaaS application with more than a handful of users.** Manual account creation does not scale
  and never gets cleaned up.
- **On-premises applications** via the provisioning agent (LDAP directories, SQL-backed apps).
- **Cross-tenant synchronization** is the same engine pointed at another Entra tenant — the M&A
  pattern in [`../external-identities/`](../external-identities/).

## The traps

1. **Quarantine going unnoticed.** Alert on provisioning job status; do not rely on discovery.
2. **Wrong matching attribute** → duplicate accounts instead of linked ones.
3. **Assuming SSO implies provisioning.** They are independent; configuring one does not configure
   the other.
4. **Not testing deprovisioning.** Everyone tests that joiners appear. Almost nobody tests that
   leavers disappear — which is the half that matters for audit.
5. **Attribute mapping to a field the app treats as immutable** — the update fails per-user, quietly.

## Evidence this topic needs

- `lab/` — configure SCIM to a gallery app; provision a test user; change an attribute and watch the
  incremental cycle carry it.
- `break-fix/` — **deliberately quarantine a job** (bad credential), observe that provisioning stops
  silently, then recover it. Then remove a user from scope and **prove** deprovisioning occurred.
- `operations/` — provisioning status monitoring and alerting; the quarantine recovery runbook.
- `security/` — which apps have provisioning, which do not, and what that means for offboarding.
