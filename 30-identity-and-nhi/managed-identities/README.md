# Managed Identities

> **Concept facet.** Depth in
> [Layer 4 §3](../service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md).

## What it is

An identity for an Azure resource where **Azure creates, rotates, and destroys the credential** —
so no credential exists for you to leak, expire, or commit to git.

Underneath, a managed identity **is a service principal** (`servicePrincipalType = ManagedIdentity`)
with **no application object behind it**. It can be granted permissions but **cannot be modified
directly** — which is the point.

## The two kinds

| | System-assigned | User-assigned |
|---|---|---|
| Lifecycle | Tied to one resource; **deleted with it** | Independent Azure resource |
| Relationship | 1:1 | **N:M** — many resources, many identities |
| Pre-creatable | No | **Yes** — grant RBAC before the resource exists |
| Survives redeploy | **No — new object ID** | Yes |

**Choose user-assigned when** a fleet needs the same access, IaC ordering requires granting RBAC
before deployment, or redeploys must not break access. **System-assigned** for single-resource,
tightly-scoped cases where the identity should die with the workload.

> **The redeploy trap.** A system-assigned identity gets a **new object ID** on resource
> recreation, orphaning every role assignment referencing the old one. Terraform
> destroy/apply cycles hit this constantly, and it is the strongest practical argument for
> user-assigned identities in IaC-managed estates.

## How the token is actually obtained

The resource calls the **Instance Metadata Service** at a link-local address
(`169.254.169.254`), reachable only from inside the VM, with a required header. It returns an
access token for the requested resource.

**No secret is transmitted or stored, because the platform's proof is "you are running on this
compute."** The network boundary *is* the authentication. That is why a managed identity cannot be
used from your laptop — and why that limitation is a feature.

In code you rarely call IMDS directly; `DefaultAzureCredential` walks a chain of sources until one
succeeds. **That chain order differs between SDK languages and versions** — check the version you
are on rather than assuming. It is also why code works locally under your own login and fails in
Azure, or the reverse: a different link answered.

## When and where

**Default to a managed identity whenever the workload runs on Azure compute that supports one** —
VMs, App Service, Functions, Container Apps, AKS, Logic Apps, Data Factory, and more.

If the workload runs **outside** Azure, the equivalent is
[workload identity federation](../workload-identity-federation/) — also credential-free.

Only fall back to an [app registration](../app-registrations/) with a certificate or secret when
neither applies.

## The traps

1. **Assigning the identity but forgetting the RBAC on the target.** The identity exists and has
   access to nothing — a `403` that reads like an authentication failure but is authorisation.
2. **RBAC propagation lag** after assignment. Retry before concluding the config is wrong.
3. **Expecting a managed identity to work off-Azure.** IMDS is not reachable; that is by design.
4. **System-assigned in IaC.** See the redeploy trap.
5. **Over-scoping.** A managed identity with `Contributor` at subscription scope has removed the
   benefit of having a narrow identity in the first place.

## Evidence this topic needs

- `lab/` — VM with system-assigned identity retrieves a Key Vault secret **with no credential in
  code**; then curl IMDS directly and decode the raw token (Layer 1 §4).
- `break-fix/` — destroy and recreate the VM; watch the role assignment orphan; redo with
  user-assigned and watch it survive.
- `security/` — inventory managed identities and their role assignments, ranked by scope breadth.
- `architecture-decisions/` — ADR: system- vs user-assigned for this estate, and why.
