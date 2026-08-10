# Secrets and Certificates

> **Concept facet.** Related:
> [`../key-vault/`](../key-vault/) · [`../app-registrations/`](../app-registrations/) ·
> [`../workload-identity-federation/`](../workload-identity-federation/).

## What it is

The credential material that non-human identities use to authenticate — and the lifecycle problem
that comes with anything having an expiry date.

## The hierarchy — this is a security ranking, not a preference

| | Credential | Why |
|---|---|---|
| 1 | **Managed identity** | **No credential exists.** Nothing to leak, rotate or expire |
| 2 | **Workload identity federation** | **No credential exists.** Trust an external IdP's token |
| 3 | **Certificate** | Private key can live in an HSM/Key Vault; harder to exfiltrate and reuse |
| 4 | **Client secret** | A bearer string. Copy it and you *are* the application |

**The correct engineering goal is to move up this list, not to manage the bottom of it better.**
Rotation tooling for client secrets is treating the symptom. Migrating one pipeline to federated
credentials and deleting its secret is a same-day deliverable with a clean before/after.

## Why a secret is worse than a certificate

A client secret is a **bearer** credential: possession is sufficient. It appears in config files,
CI variables, chat messages and screenshots, and it is indistinguishable from any other string, so
secret-scanning is the only thing standing between it and a public repository.

A certificate's **private key can be non-exportable** — generated in and never leaving an HSM or
the platform key store. An attacker who reads your configuration gets a *reference*, not the key.

## The lifecycle problem

**Everything here expires, and expiry is a scheduled outage that nobody schedules.**

- App registration secrets and certificates
- SAML **token-signing certificates** — expiry breaks SSO for **every user of that app
  simultaneously**, with no warning unless someone configured the notification address
- Entra Connect and AD FS certificates
- TLS certificates on custom domains and Application Proxy

**Make expiry visible or it will find you.** The report belongs on a schedule, not in someone's head:

```powershell
Connect-MgGraph -Scopes 'Application.Read.All'
Get-MgApplication -All | ForEach-Object {
    $app = $_
    $app.PasswordCredentials + $app.KeyCredentials |
      Where-Object { $_.EndDateTime -and $_.EndDateTime -lt (Get-Date).AddDays(60) } |
      ForEach-Object {
        [pscustomobject]@{
            App = $app.DisplayName; AppId = $app.AppId
            Type = if ($_.Key) { 'Certificate' } else { 'Secret' }
            Expires = $_.EndDateTime
            Days = [int]($_.EndDateTime - (Get-Date)).TotalDays
        }
      }
} | Sort-Object Days | Format-Table -AutoSize
```

## Rotation done properly

The mature pattern is **overlap, not swap**:

1. Add the **new** credential alongside the old
2. Deploy the application change to use it
3. Verify in production
4. **Then** remove the old one

Swapping in place guarantees an outage window. Overlapping means the rollback is "keep using the
old credential," which requires no deployment.

**Applications should reference secrets without a version** so rotation is picked up automatically.
Hardcoding a versioned Key Vault URI silently breaks the app at the next rotation.

## The traps

1. **Managing secrets better instead of eliminating them.** Ask first whether a managed identity or
   federated credential applies.
2. **Calendar-reminder rotation.** It fails at exactly the wrong moment.
3. **Swap-in-place rotation** with no overlap window.
4. **Unowned credentials.** No owner recorded means nobody can authorise rotation, so nobody does.
5. **Secrets in CI variables copied between repositories** — one leak becomes many.
6. **Forgetting SAML signing certificates**, which are not in the app registration credential list
   and are therefore missed by the report above.

## Evidence this topic needs

- `lab/` — create an app with a secret and with a certificate; authenticate with each; compare what
  is stored where.
- `break-fix/` — **let a secret expire** and watch the integration fail; read the exact error. Then
  perform an overlap rotation with no downtime.
- `security/` — the expiry report, scheduled; a secret-scanning check (Gitleaks) over the repo.
- `operations/` — rotation runbook per credential type, including SAML signing certificates.
