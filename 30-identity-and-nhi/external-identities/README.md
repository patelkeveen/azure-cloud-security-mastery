# External Identities

> **Concept facet.** Depth in
> [Layer 2 §1.3](../entra-users-and-groups/LAYER-2-DOMAIN-1-USER-IDENTITIES.md).

## What it is

Letting people who are not your employees use your resources — partners, contractors, customers —
**without you managing their credentials**.

## The idea that makes B2B work

**The guest's home tenant holds the credential.** You never manage their password, their MFA, or
their lifecycle. You grant access to a **stub object** that points at an identity someone else
authenticates.

That is the entire value proposition, and it is also why *"reset the guest's password"* is not a
thing you can do. If their home tenant disables them, your access dies with it — which is exactly
what you want and is strictly better than the alternative of issuing them your own account.

## The three models

| Model | Object in your directory? | Use |
|---|---|---|
| **B2B collaboration** | **Yes** — guest user | General resource access |
| **B2B direct connect** | **No** | Teams shared channels |
| **Entra External ID** (CIAM) | Separate tenant type | **Customer**-facing apps |

**Direct connect creating no object is genuinely surprising the first time** — the user has access
but you cannot find them in the user list.

**External ID is the successor to Azure AD B2C**, which is closed to new tenants. Any customer with
a consumer-facing application is now an External ID conversation, and "we have a B2C tenant" is a
migration discussion. Not on SC-300; unavoidable on the job.

## Cross-tenant access settings — the M&A workhorse

Per-partner inbound and outbound controls. The feature that earns its keep is **trust settings**:

- Trust **MFA** from the home tenant
- Trust **compliant device** claims
- Trust **hybrid joined device** claims

> Without this, your CA policy demanding MFA forces partner users to **register MFA again in your
> tenant** — a second authenticator entry for the same human, multiplied by thousands. With it,
> their home-tenant MFA satisfies your policy. On an acquisition this is the difference between
> day-one collaboration and a helpdesk queue.

**Cross-tenant synchronization** then provisions users from one tenant into another automatically,
powering multi-tenant organizations.

## How it works underneath

Redemption: invite → email → consent → guest object activates. Falls back to **email OTP** when the
partner has no Entra tenant.

The UPN is mangled: `priya_contoso.com#EXT#@yourtenant.onmicrosoft.com`. **Scripts filtering on UPN
will not match what you expect** — filter on `mail` or `userType`.

## The traps

1. **Guests never expire.** The default is permanent. Bring guests in through
   [access packages](../entitlement-management/) so expiry is structural, not a cleanup project.
2. **Guest permission defaults are permissive** — guests can enumerate directory objects unless
   restricted. Set `Guest user access restrictions` deliberately.
3. **Forgetting guests are in scope for CA.** They must be targeted explicitly, and trust settings
   decide whether that means re-registration.
4. **A tenant that is 40% guests has a governance problem**, and a migration problem, and nobody has
   noticed.

## Evidence this topic needs

- `lab/` — invite a personal email; walk the redemption; inspect `userType`, `#EXT#` UPN, `mail`.
- `break-fix/` — script a filter on UPN and watch it miss every guest.
- `security/` — guest inventory ordered by age and last sign-in; permission-restriction posture.
- `customer-use-cases/` — M&A cross-tenant trust; education parent/alumni access.
