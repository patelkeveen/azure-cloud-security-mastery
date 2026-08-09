# Layer 4 — SC-300 Domain 3: Plan and Implement Workload Identities (20–25%)

> **Non-human identities now outnumber human ones in most tenants, and they are the dominant
> breach path.** This domain is also the bridge to SC-500 and the "Security AI Infrastructure
> Engineer" role — Entra Agent ID is a direct extension of everything here.
>
> **Gate:** you own this layer when you can explain the application-object / service-principal
> relationship without hedging, choose a credential type and defend it, and configure workload
> identity federation so a CI/CD pipeline holds **no secret at all**.
>
> Product behaviour verified against Microsoft documentation on **2026-08-09**.

---

## 1. The object model — get this right and half the domain follows

The most common confusion in Entra, and the source of "I registered the app, why isn't it in
Enterprise Applications?"

```
        ┌──────────────────────────────┐
        │      APPLICATION OBJECT      │   ONE, globally unique
        │   lives in the HOME tenant   │   the blueprint / class
        │   (App registrations blade)  │
        └───────────────┬──────────────┘
                        │ template for
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
  ┌───────────┐   ┌───────────┐   ┌───────────┐
  │    SP     │   │    SP     │   │    SP     │   ONE PER TENANT
  │ Adatum    │   │ Contoso   │   │ Fabrikam  │   the instance / object
  │ (home)    │   │           │   │           │   (Enterprise apps blade)
  └───────────┘   └───────────┘   └───────────┘
```

- **Application object** — one per software application, in its home tenant only. Defines how
  tokens are issued, what resources it needs, what it can do. *App registrations* blade.
- **Service principal** — the local instance in a specific tenant. Defines what the app can
  actually do *here*, who can access it, what it can reach. *Enterprise applications* blade.

Relationship: app object has a **1:1** relationship with the software, and **1:many** with
service principals.

| App type | Service principals |
|---|---|
| Single-tenant | One, in the home tenant |
| Multi-tenant | One per tenant where someone consented |

**Three types of service principal:**

| Type | Has an app object? | Notes |
|---|---|---|
| **Application** | Yes | The normal case — an instance of a registered app |
| **Managed identity** | **No** | Can be granted permissions but **cannot be modified directly** |
| **Legacy** | No | Pre-registration-era apps; editable but tenant-local only |

### Four consequences that show up in real tenants

1. **Registering in the portal creates both objects. Creating an app via the Graph API creates
   the service principal as a *separate step*.** Script an app registration and forget the SP,
   and you have an app that cannot be assigned anything.
2. **Deleting the application object deletes its home-tenant service principal — and restoring
   the app object does *not* restore the service principal.** Restoration through the
   App registrations UI brings back the blueprint, not the instance, along with every role
   assignment and consent that hung off it. Treat app deletion as effectively irreversible.
3. **Prefer deactivation over deletion** when you need to stop an app temporarily.
   Deactivation halts new token issuance while preserving both objects for investigation or
   reactivation. This is the correct move during an incident — you stop the bleeding without
   destroying the evidence.
4. Permissions consented in Contoso's tenant have no effect in Fabrikam's. Each tenant's admin
   consents for their own service principal.

---

## 2. Choosing an identity for a workload — the decision tree

**This is the interview question for this domain.** Decide from the topology and defend it.

```
Does the workload run on an Azure resource that supports managed identity?
├── YES → MANAGED IDENTITY. Azure manages the credential. No secret exists.
│    ├── Used by exactly one resource, dies with it?  → system-assigned
│    └── Shared across resources / pre-created / survives the resource? → user-assigned
│
└── NO  → Does it run somewhere with an OIDC-capable identity provider?
     │      (GitHub Actions, any Kubernetes, AWS, GCP, Azure Pipelines, SPIFFE)
     ├── YES → WORKLOAD IDENTITY FEDERATION. Still no secret.  ⭐
     └── NO  → App registration with a credential:
          ├── CERTIFICATE  (preferred — harder to exfiltrate, harder to misuse)
          └── CLIENT SECRET (last resort — a bearer string in someone's config)
```

**The ordering is a security hierarchy, not a preference.** Managed identity and federation
eliminate the credential entirely. Certificates make theft harder. Secrets are a password for
a robot, sitting in a pipeline variable, waiting to be committed to git.

> **Never use a user account as a service account.** No MFA, no CA that makes sense, a licence
> cost, and it breaks the moment someone enforces password policy. If you inherit one, migrating
> it to a service principal or managed identity is a quick, visible win.

---

## 3. Managed identities

**A managed identity *is* a service principal** (`servicePrincipalType = ManagedIdentity`) with
no application object behind it. Azure creates, rotates, and destroys the credential.

| | System-assigned | User-assigned |
|---|---|---|
| Lifecycle | Tied to one resource; deleted with it | Independent Azure resource |
| Relationship | 1:1 | **N:M** — many resources, many identities |
| Pre-creatable | No | **Yes** — so RBAC can be granted before deployment |
| Survives redeploy | **No** (new identity, new object ID) | Yes |

**Choose user-assigned when** you have a fleet of resources needing the same access, you need
to grant RBAC before the resource exists (IaC ordering), or redeploys must not break access.
**System-assigned** for single-resource, tightly-scoped cases where the identity should die with
the workload.

> **The redeploy trap.** A system-assigned identity gets a *new object ID* on resource
> recreation. Every role assignment referencing the old one is now orphaned. Terraform
> destroy/apply cycles hit this constantly — and it's the strongest practical argument for
> user-assigned identities in IaC-managed estates.

### How the token is actually obtained

The resource calls the **Instance Metadata Service** — a link-local address
(`169.254.169.254`) reachable only from inside the VM, requiring a specific header — and gets
back an access token for the requested resource. No secret is ever transmitted or stored,
because the platform's proof is *"you are running on this compute."*

In code you rarely call IMDS directly. `DefaultAzureCredential` walks a chain of credential
sources (environment variables, managed identity, developer tooling sign-in, and others) until
one succeeds. **That chain order differs between SDK languages and versions — check the version
you're on rather than assuming.** It's also why code works locally under your own login and
fails in Azure, or vice versa: a different link in the chain answered.

---

## 4. Workload identity federation ⭐ `[BEYOND]` — secretless CI/CD

Not on SC-300. **Asked in every senior platform/security interview**, and the single highest-value
thing in this layer for your target role.

### The problem

A GitHub Actions pipeline deploying to Azure traditionally holds a client secret in repo
secrets. That secret can leak, gets copied between repos, expires at the worst moment, and is
the most common real breach path in modern estates.

### The mechanism

Configure a **federated identity credential** on a **user-assigned managed identity** or an
**app registration**, declaring which external tokens to trust.

```
1. Pipeline asks GitHub for an OIDC token
2. GitHub issues a short-lived JWT   (sub = repo:org/repo:ref:refs/heads/main, etc.)
3. Pipeline sends that JWT to Entra's token endpoint
4. Entra checks the federated identity credential and validates the token
   against the external IdP's published OIDC issuer URL
5. Entra issues an access token
6. Pipeline uses it. No secret existed at any point.
```

### The three values that must match — and the failure mode

> **`issuer`, `subject`, and `audience` on the federated identity credential must match the
> corresponding values in the incoming token *case-sensitively*.**

That sentence is the whole troubleshooting guide. Nearly every WIF failure is a `subject`
mismatch, because GitHub's subject format **changes with the trigger type**:

| Trigger | Subject shape |
|---|---|
| Branch push | `repo:<org>/<repo>:ref:refs/heads/<branch>` |
| Tag | `repo:<org>/<repo>:ref:refs/tags/<tag>` |
| Pull request | `repo:<org>/<repo>:pull_request` |
| Environment | `repo:<org>/<repo>:environment:<name>` |

A credential configured for `main` **will not work from a pull request**. You need one
federated credential per subject pattern you intend to allow — which is a feature, not a
limitation: it's how you stop a PR from any fork deploying to production.

The audience is conventionally Entra's token-exchange value; **read it off your own
configuration rather than trusting any blog, including this file.**

### Supported platforms — this is multi-cloud, which matters for your goals

- **Any Kubernetes** — AKS, EKS, GKE, on-prem
- **GitHub Actions**
- **Azure Pipelines** service connections
- **AWS** — via IAM Outbound Identity Federation
- **Google Cloud**
- **SPIFFE / SPIRE** — the vendor-neutral workload identity standard
- Any other OIDC-capable compute platform

Being able to say *"we can federate your EKS workloads to Entra without secrets"* is a
differentiating sentence in a multi-cloud shop.

### Two limits worth knowing

- **Entra-issued tokens cannot be used in federated identity flows.** You cannot chain Entra to
  itself.
- Entra stores only the **first 100 signing keys** from the external IdP's OIDC endpoint. An IdP
  exposing more will produce intermittent failures.

---

## 5. App registrations

### Credentials, in order of preference

| Type | Notes |
|---|---|
| **Federated credential** | No secret. Always first choice where supported |
| **Certificate** | Private key can live in Key Vault / HSM. Preferred over secrets |
| **Client secret** | A bearer string. Max lifetime is capped; treat as a liability |

**Secret expiry is a genuine production hazard** and one of the most common "it worked
yesterday" outages. Make expiry visible:

```powershell
Connect-MgGraph -Scopes 'Application.Read.All'
Get-MgApplication -All | ForEach-Object {
    $app = $_
    $app.PasswordCredentials + $app.KeyCredentials | Where-Object {
        $_.EndDateTime -and $_.EndDateTime -lt (Get-Date).AddDays(60)
    } | ForEach-Object {
        [pscustomobject]@{
            App     = $app.DisplayName
            AppId   = $app.AppId
            Type    = if ($_.Key) { 'Certificate' } else { 'Secret' }
            Expires = $_.EndDateTime
            Days    = [int]($_.EndDateTime - (Get-Date)).TotalDays
        }
    }
} | Sort-Object Days | Format-Table -AutoSize
```

Run it on a schedule. It's a five-minute artifact that prevents a whole class of incident, and
it's the kind of thing that makes you look operationally serious in a first week.

### API permissions

Covered mechanically in **Layer 1 §6**; here's what matters operationally:

| | Delegated | Application |
|---|---|---|
| Acts as | The signed-in user | Itself |
| Effective access | **Intersection** of app permission AND user's own rights | **The full permission. No intersection.** |
| Consent | User or admin | **Admin only** |

**Over-privileged application permissions are the standard critical finding in a tenant
review.** `Mail.Read` as an *application* permission reads every mailbox in the organisation.
`Directory.ReadWrite.All` is effectively tenant admin. When auditing, sort service principals by
application-permission blast radius and start there.

`/.default` requests everything already consented — required for client credentials.

### App roles vs groups

Define roles in your app (`roles` claim) instead of leaning on `groups`. Three reasons:
they're app-scoped rather than tenant-wide, they're assignable to users *and* service
principals, and they **sidestep the group claim overage trap from Layer 1 §4** — the one that
silently breaks authorisation for your most group-joined users.

### Token configuration `[BEYOND]`

Optional claims and claims-mapping policies let you shape the token. Most common real use:
resolving group overage by restricting the `groups` claim to *groups assigned to this
application*, rather than all groups.

---

## 6. Enterprise applications

### Settings that decide the security posture

- **Assignment required** — when *Yes*, only assigned users can access. When *No*, anyone in
  the tenant can. Default varies by app; check it.
- **Visibility** in MyApps.
- **Self-service access** — user-requestable, optionally with approval.

**Least-privilege roles for managing apps:** Cloud Application Administrator (all apps, no
app proxy), Application Administrator (adds app proxy), or **app ownership** for a single app.
Handing out Global Administrator to manage one SaaS integration is the anti-pattern.

### Application Proxy vs Private Access

| | Application Proxy | **Global Secure Access — Private Access** |
|---|---|---|
| Protocols | **HTTP(S) only** | **TCP / UDP** |
| Model | Reverse proxy per app | ZTNA |
| Pre-auth | Entra or passthrough | Entra |
| Backend SSO | **KCD**, header-based, SAML | Broader |

**Recommend Private Access for anything non-HTTP** — RDP, SSH, SMB, database ports — and for
replacing legacy VPN. App Proxy remains fine for classic internal web apps, and its **Kerberos
Constrained Delegation** support is the specific reason it still wins for older Windows-auth
intranet applications.

Connectors are **outbound-only** — no inbound firewall holes. Group them for HA and for routing
by network segment.

### SaaS integration and SCIM provisioning

Gallery apps ship pre-configured; non-gallery apps you wire by hand. SAML config is Layer 1 §5
in practice.

**SCIM provisioning** deserves more attention than it gets:

- **Attribute mappings** with expressions (`Join`, `Replace`, `Mid`, `IIF`) for shaping values
- **Scoping filters** so you provision only the right population
- **Initial cycle** walks everything (slow, hours at scale); **incremental cycles** run
  periodically thereafter
- **Quarantine** — repeated failures suspend the job. Provisioning silently stops. **Check
  provisioning status when someone says "the new joiner never appeared in Salesforce."**

Provisioning is how leavers actually lose SaaS access. An offboarding process that disables the
Entra account but doesn't deprovision is leaving live accounts behind in every connected app.

### Consent

- **User consent** — restrict to verified publishers and low-risk permissions, or disable.
- **Admin consent workflow** — the important half. Disabling user consent *without* enabling
  the request workflow doesn't stop people needing apps; it pushes them to shadow IT.
- Hunt `Consent to application` in `AuditLogs` (Layer 5).

---

## 7. Defender for Cloud Apps

| Capability | What it does |
|---|---|
| **Cloud discovery** | Ingests firewall/proxy logs to surface shadow IT with risk scores |
| **App connectors** | API connection to sanctioned SaaS — visibility and control over data at rest |
| **Conditional Access App Control** | CA hands the session to MDA as a reverse proxy for real-time control |
| **Access & session policies** | Block download, inline DLP, block copy/paste on unmanaged devices |
| **OAuth app policies** | **Detect and revoke malicious OAuth grants** — the remediation for Layer 1 §6 |
| **App catalog** | Risk scoring across ~90 factors; custom scores |

**The CA ↔ MDA handoff is the bit to understand.** Conditional Access decides *whether* the
session proceeds; session control hands it to MDA, which then governs *what happens inside* it.
That's how you allow access from an unmanaged device while blocking downloads — an outcome CA
alone cannot produce.

**OAuth app policies are the operational answer to illicit consent.** Detection plus one-click
revoke of the service principal's grants. Remember: remediation is revoking the grant and
sessions, **not** resetting the user's password.

---

## 8. Troubleshooting

**"App can't authenticate"**
```
Client secret or certificate expired?      → the most common cause, check first
├── NO → correct tenant endpoint? (single- vs multi-tenant, /common vs /{tenant})
     └── YES → permissions consented IN THIS TENANT? (SP is per-tenant)
          └── YES → delegated vs application mismatch for the flow being used?
```

**"Managed identity gets 403"**
```
Is the identity assigned to the resource?
└── YES → is there an Azure RBAC assignment on the TARGET?
     └── YES → correct scope? correct role? RBAC propagation can lag
          └── still failing → system-assigned identity recreated by a redeploy?
             (new object ID ⇒ every old role assignment is orphaned)
```

**"Workload identity federation fails"**
→ Decode the external token. Compare `iss`, `sub`, `aud` **character by character, case
sensitive**, against the federated credential. It is almost always `sub` — usually because the
trigger type changed.

**"SCIM provisioning stopped"**
→ Check quarantine status before anything else.

---

## 9. Hands-on gate

**Lab 1 — Prove the object model.** Register an app. Find it in *App registrations*, then find
its service principal in *Enterprise applications*. Confirm the same `appId`, different object
IDs. Then create an app via Graph **without** creating the SP and observe what breaks.

**Lab 2 — Delegated vs application.** Same Graph call, both permission types, as a
non-privileged user. Delegated returns what that user can see; application returns the whole
tenant. **This is the lesson of the domain.**

**Lab 3 — Managed identity end to end.** Give a VM a system-assigned identity, grant it Key
Vault access, retrieve a secret with no credential in code. Then curl IMDS directly and read the
raw token (Layer 1 §4).

**Lab 4 — The redeploy trap.** Destroy and recreate the VM. Watch the role assignment orphan.
Redo it with a user-assigned identity and watch it survive.

**Lab 5 — Workload identity federation ⭐.** Federate a GitHub Actions workflow to Azure with
**zero secrets**. Then break it deliberately: run the same workflow from a pull request and watch
the `sub` mismatch fail it. **This is the portfolio artifact of this layer.**

**Lab 6 — Secret expiry report.** Run the §5 script. Add a secret expiring in 30 days and
confirm it surfaces.

**Lab 7 — Illicit consent, safely.** In your own tenant, register an app requesting
`Mail.Read offline_access`, consent as a test user, then find the grant in Enterprise
applications and revoke it. **Do this only in a tenant you own.**

---

## 10. Cross-references

| Concept here | Connects to |
|---|---|
| Delegated vs application, `/.default`, consent | Layer 1 §6 |
| `roles` claim, group overage | Layer 1 §4 |
| Service principal risk detections | Layer 3 §4 |
| CA App Control session handoff | Layer 3 §3.4 |
| Workload identities as CA targets | Layer 3 §3.1 |
| Private Access vs App Proxy | Layer 3 §6 |
| SP sign-in logs (`AADServicePrincipalSignInLogs`) | Layer 5 — monitoring |
| **Entra Agent ID** — identity for AI agents | Layer 6 — SC-500 |
