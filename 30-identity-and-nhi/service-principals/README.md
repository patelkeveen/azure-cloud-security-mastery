# Service Principals

> **Concept facet.** Full depth in
> **[LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md](LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md)** in this
> folder.

## What it is

The **local instance** of an application in a specific tenant. Where the
[application object](../app-registrations/) is the blueprint, the service principal is the thing
that actually holds permissions, gets assigned roles, and appears in sign-in logs.

**A service principal is a security principal**, exactly like a user is. That is why it can be
granted RBAC, assigned app roles, targeted by Conditional Access, and — this is the part people
forget — **compromised**.

## Three types

| Type | Has an app object? | Notes |
|---|---|---|
| **Application** | Yes | The normal case — an instance of a registered app |
| **Managed identity** | **No** | Can be granted permissions; **cannot be modified directly** |
| **Legacy** | No | Pre-registration-era; tenant-local only |

## Why the per-tenant model matters

One application object, **one service principal per tenant where the app is used**. A single-tenant
app has one; a multi-tenant app gets one in every tenant that consents.

Consequences that show up in real work:

- **Permissions consented in Contoso's tenant have no effect in Fabrikam's.** Each tenant's admin
  consents for their own SP.
- **Deleting the app object deletes its home-tenant SP — and restoring the app object does not
  restore the SP.** Every role assignment and consent is gone with it.
- **Prefer deactivation over deletion** during an incident: it stops token issuance while preserving
  both objects as evidence.

## The permission asymmetry that defines the risk

| | Delegated | **Application** |
|---|---|---|
| Acts as | The signed-in user | **Itself** |
| Effective access | **Intersection** of app permission AND the user's rights | **The full permission. No intersection.** |
| Consent | User or admin | **Admin only** |

**`Mail.Read` as an application permission reads every mailbox in the organisation.**
`Directory.ReadWrite.All` is effectively tenant admin.

> **When auditing a tenant, sort service principals by application-permission blast radius and start
> there.** Over-privileged application permissions are the standard critical finding, and the
> finding customers cannot produce themselves.

## Where they hide

Service principals accumulate from places nobody tracks: SaaS integrations consented by users,
migration tools granted broad access and never revoked, CI/CD pipelines, monitoring agents,
Microsoft first-party apps, and — increasingly — **agent identities**
([Layer 6](../../60-ai-and-secure-ai/ai-agent-identity/LAYER-6-SC500-BRIDGE-AI-SECURITY.md)).

They **outnumber human identities in most tenants** and almost none of them have a recorded owner.

## Monitoring — and the table most people never query

Service principal sign-ins are **not** in `SigninLogs`:

```kusto
AADServicePrincipalSignInLogs
| where TimeGenerated > ago(30d) and ResultType == 0
| summarize Countries = make_set(LocationDetails.countryOrRegion), Signins = count()
    by ServicePrincipalName, AppId
| where array_length(Countries) > 1
```

**Investigating a compromise with `SigninLogs` alone misses this entirely** — which is exactly why
modern attackers persist here. Risky workload identity detections (P2) surface the anomalies.

## The traps

1. **Treating an SP as "just config."** It is a principal with permissions and a credential.
2. **Granting application permissions when delegated would do.** Ask whether a user is present.
3. **No owner recorded** — so nobody can authorise disabling it during an incident.
4. **Long-lived secrets.** See [`../secrets-and-certificates/`](../secrets-and-certificates/) and
   prefer [`../managed-identities/`](../managed-identities/) or federation.
5. **Assuming deletion is recoverable.**

## Evidence this topic needs

- `lab/` — register an app, find its SP, confirm same `appId` and different object IDs; run the
  same Graph call with delegated and application permissions as a non-privileged user and compare.
- `break-fix/` — delete and restore an app registration; prove the SP did not return.
- `security/` — the NHI register ([`../nhi-incident-response/`](../nhi-incident-response/)); SPs
  ranked by application-permission blast radius; multi-country sign-in detection deployed.
