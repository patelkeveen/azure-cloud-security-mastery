# Entitlement Management

> **Concept facet.** Depth in
> [Layer 5 §2](../pim-and-access-reviews/LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md).

## What it is

Self-service access, governed. Resources are grouped into **access packages**; users **request**
them; **approvers** decide; assignments **expire**. IT stops being a ticket queue for access.

```
CATALOG            container of resources + delegation boundary
  └─ ACCESS PACKAGE  a bundle of resource roles = one job function
       └─ POLICY       who may request · who approves · how long it lasts
```

## Why it exists

Because the alternative is group membership granted by a helpdesk ticket, never reviewed, never
expiring. Entitlement management inverts that: access has an **owner, an approval trail, and an
end date** by construction.

The delegation is the point. A **catalog owner** — usually a business owner, not IT — curates what
exists. IT builds the machine; the business runs it.

## How it works underneath

An access package is a **bundle of resource roles**: security groups, Teams, enterprise
applications, SharePoint sites. Assigning the package assigns every underlying role atomically;
expiry removes them the same way.

Multiple **policies** per package let different populations request the same thing under different
rules — employees auto-approved, contractors requiring manager sign-off, partners requiring a
sponsor.

## When and where

- **High-churn populations** — seasonal retail staff, rotating clinical residents, student cohorts
- **External collaboration** — a guest brought in *via* an access package is **automatically
  blocked and deleted when the assignment expires**, which closes the standard finding of partner
  guests from a project that ended two years ago
- **Anywhere an auditor will ask "who approved this, and when does it end?"**

## Separation of duties — the control that answers audit

Packages can be marked **incompatible**: holding one makes you *unable to request* the other,
enforced at request time rather than discovered in an audit.

> **Reach for this rather than trying to express SoD through custom directory roles.** Engineers
> keep attempting that and it does not fit — the conflict is between *business entitlements*, not
> directory permissions. "Nobody can hold both Payments-Submit and Payments-Approve" is an
> entitlement statement.

## Licensing — check before designing

| Capability | Needs |
|---|---|
| Core EM, access packages, multi-stage approval, **separation of duties**, expiry, external user lifecycle | **P2** |
| Auto-assignment policies, custom extensions (Logic Apps), Entra roles in packages, Verified ID / ID Protection / Insider Risk integration | **Entra ID Governance** |

**Licence counting is by population in scope, not by administrator.** A package that 2,000
employees *can request* needs 2,000 licences even if 150 request it. Guests are billed on a
**Monthly Active User** model requiring an Azure subscription.

## The traps

1. **Designing around Governance-SKU features the customer only licenses at P2.** Confirm
   entitlement before the design review, not after.
2. **Packages that mirror the org chart rather than job functions.** Reorganisations then break
   every package. Model the *function*.
3. **No expiry.** A package without an end date is a group with extra steps.
4. **Catalog sprawl.** One catalog per business domain with a named owner; not one per package.

## Evidence this topic needs

- `lab/` — catalog, package containing a group and an app, policy with manager approval and 90-day
  expiry. Request as a test user, approve, watch it expire.
- `break-fix/` — mark two packages incompatible; hold one, request the other, read the refusal.
- `security/` — SoD matrix; guest lifecycle proof.
- `customer-use-cases/` — retail seasonal onboarding; healthcare locums.
