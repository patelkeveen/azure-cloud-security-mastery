# App Registrations

> **Concept facet.** Depth lives in
> [Layer 4 §5](../service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md).
> Evidence facets (`lab/`, `break-fix/`, `operations/`) are yours to produce in the tenant.

## What it is

An **application object** — the globally unique definition of an application in its home tenant.
It declares how tokens may be issued to the app, what resources it needs, and what it can do.
It is a **blueprint**, not a running identity.

## The distinction that governs everything

```
APPLICATION OBJECT  (one, home tenant only)   →  App registrations blade
        │ template for
        ▼
SERVICE PRINCIPAL   (one PER TENANT)          →  Enterprise applications blade
```

An app object has a **1:1** relationship with the software and **1:many** with service principals.
A single-tenant app has one SP; a multi-tenant app gets one in every tenant that consents.

**This is the source of "I registered the app, why isn't it in Enterprise Applications?"** — and
of the more dangerous confusion, where an engineer grants a permission in the home tenant and
expects it to apply everywhere. Consent is per-tenant because the *service principal* is per-tenant.

## Why it exists

Before app registrations, applications authenticated with service accounts — user objects with
passwords, no MFA, no lifecycle, and a licence cost. The app registration exists to give software
a first-class identity with its own credential model, its own permission grants, and its own
audit trail, separable from any human.

## How it works underneath

Registering in the **portal** creates both the application object and its home-tenant service
principal. Registering via the **Graph API creates the SP as a separate step** — script a
registration and forget that, and you have an app that cannot be assigned anything.

Credentials attach to the app object in three forms, in descending order of safety:

| Credential | Notes |
|---|---|
| **Federated credential** | No secret exists at all — see [`workload-identity-federation/`](../workload-identity-federation/) |
| **Certificate** | Private key can live in Key Vault/HSM |
| **Client secret** | A bearer string. Expires. Gets committed to git |

Permissions declared on the app object are *requested*; they do nothing until **consented** in a
tenant, which materialises as grants on that tenant's service principal.

## When and where

Register an app when software must call an API **as itself** or **on behalf of a user** and it is
not running on Azure compute. If it *is* running on Azure compute, prefer a
[managed identity](../managed-identities/) — there is no credential to leak.

## The traps

1. **Deleting the app object deletes its home-tenant service principal — and restoring the app
   object does *not* restore the SP.** Every role assignment and consent that hung off it is gone.
   Treat app deletion as effectively irreversible; prefer **deactivation** during an incident,
   which stops token issuance while preserving both objects as evidence.
2. **Secret expiry is a scheduled outage nobody schedules.** It is the most common cause of
   "it worked yesterday." Run the expiry report in Layer 4 §5 on a timer.
3. **`Users can register applications` defaults to Yes.** Any user can create an app registration,
   which is the substrate for the illicit consent grant attack (Layer 1 §6).
4. **App roles beat group claims.** Groups hit the overage limit (~150–200) and the claim silently
   vanishes; app roles do not.

## Evidence this topic needs

- `lab/` — register an app; find its SP; confirm same `appId`, different object IDs. Create one via
  Graph *without* the SP and observe what breaks.
- `break-fix/` — delete an app registration, restore it, prove the SP did not come back.
- `security/` — inventory application permissions across the tenant, ranked by blast radius.
- `operations/` — the secret-expiry report, scheduled.
