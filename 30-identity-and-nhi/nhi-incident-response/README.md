# Non-Human Identity Incident Response

> **Concept facet.** Builds on
> [Layer 4](../service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md) and
> [Layer 5 §5](../pim-and-access-reviews/LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md).

## What it is

Responding to the compromise of a **service principal, managed identity, app registration, or
agent identity** — rather than a human account. Non-human identities now outnumber humans in most
tenants and are the dominant breach path.

## Why the human playbook does not transfer

Almost every step of standard account-compromise response is wrong here:

| Human response | Why it fails for NHI |
|---|---|
| Reset the password | There is no password — there is a secret, a certificate, or no credential at all |
| Force MFA re-registration | Non-human identities do not do MFA |
| Disable the account | **Disabling a service principal breaks production**, often immediately and widely |
| Contact the user | There may be **no owner recorded** |
| Revoke sessions | App-only tokens are stateless; revocation semantics differ |

**The blast radius is also inverted.** A compromised user has that user's rights. A compromised
service principal holding **application permissions** has *no intersection with any user's rights* —
`Mail.Read` as an application permission reads every mailbox in the organisation.

## The response sequence

1. **Scope it.** What permissions does this identity hold — delegated or **application**? What
   Azure RBAC? At what scope?
2. **Determine blast radius before acting**, because step 3 causes an outage.
3. **Contain.** Options in increasing disruption:
   - **Revoke the specific consent grant** (targeted; often enough for illicit consent)
   - **Rotate the credential** (secret/cert) — breaks anything using the old one
   - **Disable the service principal** (`accountEnabled = false`) — stops everything
   - **Delete** — last resort, and remember restoring the app object does **not** restore the SP
4. **Hunt.** `AADServicePrincipalSignInLogs` and `AADManagedIdentitySignInLogs` — **not**
   `SigninLogs`, which contains none of this.
5. **Eradicate.** Remove the persistence: added credentials, added owners, granted permissions.
6. **Recover** with a *better* credential — federated or managed identity rather than a new secret.

## The attacker techniques to recognise

- **Illicit consent grant** — a malicious app requests delegated permissions; the user genuinely
  authenticates, so **MFA passes and CA passes**. No password was stolen; **a password reset does
  not remediate it.** Revoke the grant. See Layer 1 §6.
- **Credential addition to an existing app** — an attacker with sufficient rights adds a *second*
  client secret or certificate to a legitimate, trusted app registration. Quiet, durable, and
  invisible unless you are watching `AuditLogs` for credential additions.
- **Owner addition** — adding themselves as an app owner grants durable control.
- **Over-permissioned consent** — asking for far more than the app needs, and being granted it.

## Detection — build these before you need them

```kusto
// New credential added to an application
AuditLogs
| where OperationName has_any ("Update application", "Add service principal credentials")
| project TimeGenerated, OperationName,
          Actor = InitiatedBy.user.userPrincipalName, TargetResources
```

```kusto
// Service principal signing in from more than one country
AADServicePrincipalSignInLogs
| where TimeGenerated > ago(30d) and ResultType == 0
| summarize Countries = make_set(LocationDetails.countryOrRegion) by ServicePrincipalName
| where array_length(Countries) > 1
```

## The prerequisite nobody has: the NHI register

You cannot respond to a compromise of an identity you cannot describe. The register — **identity,
owner, purpose, permissions, credential type, expiry, last used, rotation method, revocation
procedure** — is what turns a two-day investigation into a two-hour one.

**Building it is a deliverable customers pay for**, because they cannot produce it themselves.

## The traps

1. **Disabling first and scoping second.** You will cause an outage and still not know the blast
   radius.
2. **Querying `SigninLogs`** and concluding there was no activity.
3. **Rotating the credential without finding the persistence** — the attacker adds another.
4. **No owner recorded**, so nobody can authorise the disruptive action at 2am.
5. **Recovering with a new secret** instead of removing the credential class entirely.

## Evidence this topic needs

- `lab/` — build the NHI register for your tenant; add a second credential to a test app and detect
  it from `AuditLogs`.
- `break-fix/` — consent to a test app requesting `Mail.Read`, then revoke the grant and sessions.
- `security/` — application permissions ranked by blast radius; detection rules deployed.
- `operations/` — the NHI IR runbook, with the containment decision tree.
