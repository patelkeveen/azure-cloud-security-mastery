# Conditional Access

> **Concept facet.** Full depth in
> **[LAYER-3-DOMAIN-2-AUTH-AND-ACCESS.md](LAYER-3-DOMAIN-2-AUTH-AND-ACCESS.md)** in this folder.

## What it is

The policy engine that sits between a successful first-factor authentication and the issuing of a
token. It evaluates signals — user, device, location, application, risk — and decides **grant,
block, or grant with conditions**.

## Where it actually sits — the thing that is mis-taught

```
1. User submits credentials
2. Entra validates the FIRST FACTOR      ← identity established
3. ══ CONDITIONAL ACCESS EVALUATES ══
4. Grant / block / require more
5. Token issued (amr, acr claims)
```

**CA runs *after* initial authentication.** Two consequences almost nobody internalises:

- **CA does not stop a password from being tested.** Under a phishing-resistant policy a user can
  still type a password — they simply cannot finish. An attacker with valid credentials still
  learns they are valid. Protecting the credential is a *different* job: password protection,
  smart lockout, leaked-credential detection.
- **"Blocked by Conditional Access" means the password was correct.** That distinction matters in
  an incident.

## Why it exists

The network perimeter stopped being a meaningful boundary. CA is the replacement: **identity as
the control plane**, evaluated per sign-in with live signals rather than per subnet.

## How the decision is made

1. **Every enabled policy is evaluated on every sign-in.** There is no first-match-wins.
2. Assignments decide whether a policy *applies*.
3. **Block beats everything.**
4. **Multiple grant controls default to "Require ALL the selected controls."** You must explicitly
   choose *"Require one of the selected"* to get OR.
5. Conditions are AND across categories, OR within a category.

> ⚠ **Point 4 is the trap that produces real outages.** Getting it backwards builds a policy far
> stricter than intended — MFA **and** compliant device **and** hybrid join at once — locking out
> anyone missing any one. Lab it deliberately before you write a real policy.

Controls validate in a fixed order: **MFA → device state → terms of use.** That is why users see a
ToU *failure* in logs despite having accepted it months ago — MFA had not yet been satisfied.

## When and where

Every tenant, from day one. The baseline that earns its keep:

1. **Block legacy authentication** — the highest-value single policy. Basic auth cannot do MFA, so
   it bypasses every other policy you write.
2. MFA for all users
3. Phishing-resistant strength for admins
4. Risk-based policies (P2)

Design by **persona**, not by app — otherwise the policy set becomes unmaintainable at ~30 policies.

## The traps

1. **No break-glass exclusion.** The classic self-inflicted outage: *All users* + require compliant
   device, in a tenant without Intune fully deployed. Everyone is locked out including every admin.
   See [`../pim-and-access-reviews/`](../pim-and-access-reviews/).
2. **"Require compliant device" ≠ "Require Hybrid Entra joined."** One is an Intune verdict, the
   other a join-state fact. A device can be hybrid-joined and non-compliant.
3. **Report-only is not optional.** Build every policy there first and read the results for a day.
4. **Device code flow cannot satisfy device-state controls** — the authenticating device is not the
   one receiving the code.

## Evidence this topic needs

- `lab/` — baseline in report-only, then enabled one at a time; the AND/OR experiment; What-If
  compared against a real sign-in log.
- `break-fix/` — **lock a test user out on purpose and recover via break-glass.** Once, in a lab,
  so you never do it accidentally in production.
- `security/` — CA gap analysis; legacy auth still in use; policies without break-glass exclusion.
- `operations/` — CA change runbook; report-only promotion procedure.
