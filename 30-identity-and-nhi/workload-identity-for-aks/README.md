# Workload Identity for AKS

> **Concept facet.** Builds on
> [`../workload-identity-federation/`](../workload-identity-federation/) and
> [Layer 4 §4](../service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md).

## What it is

Giving a **Kubernetes pod** an Entra identity so it can reach Key Vault, Storage, SQL or Graph —
**without a secret in the cluster**. It is workload identity federation with Kubernetes as the
external identity provider.

## Why this specific problem is hard

A Kubernetes cluster is a multi-tenant compute environment. Historically, credentials were handed
to the *node*, which meant **every pod on that node inherited them** — including a compromised
sidecar in an unrelated namespace. Kubernetes `Secret` objects are worse than the name suggests:
base64-encoded, not encrypted, readable by anything with the right RBAC in that namespace.

**Workload identity moves the boundary from the node to the pod**, which is where the trust boundary
actually belongs.

## How it works

```
AKS cluster with OIDC issuer enabled
   └── Kubernetes ServiceAccount  (annotated with the Entra client ID)
        └── Pod (labelled to use workload identity)
             → projected SA token (short-lived, audience-scoped)
             → exchanged at Entra for an access token
             → calls Key Vault / Storage / Graph
```

1. Enable the **OIDC issuer** and the **workload identity** feature on the cluster
2. Create a **user-assigned managed identity** (or app registration) in Entra
3. Create a **federated identity credential** whose `subject` is
   `system:serviceaccount:<namespace>:<serviceaccount-name>`
4. Annotate the ServiceAccount with the identity's client ID
5. Label the pod so the webhook injects the projected token and environment

**The subject encodes namespace and service account name.** That is the authorisation boundary — a
pod in a different namespace, or using a different service account, produces a different subject and
is refused. Same case-sensitive matching rule as GitHub Actions.

## What it replaces

| Approach | Problem |
|---|---|
| Secret in a Kubernetes `Secret` | Not encrypted; readable in-namespace; must be rotated |
| **Pod-managed identity (legacy `aad-pod-identity`)** | Node-level; deprecated in favour of workload identity |
| Node-assigned managed identity | **Every pod on the node inherits it** |

**Workload identity is the current answer.** If you find `aad-pod-identity` in a customer cluster,
that is a migration item, not a working design.

## When and where

- Any AKS workload needing Azure resources
- **Non-AKS Kubernetes too** — EKS, GKE, on-premises — using the same federation mechanism, which is
  what makes this a genuinely multi-cloud skill rather than an Azure one
- Especially anywhere a `Secret` currently holds a connection string

## The traps

1. **Subject string mismatch** — `system:serviceaccount:default:myapp` is not
   `system:serviceaccount:Default:myapp`. Case-sensitive.
2. **Forgetting the pod label**, so the webhook never injects the token. The pod starts fine and
   fails at the first Azure call, which reads like a permissions problem.
3. **Missing RBAC on the target.** The identity authenticates and can reach nothing — a `403` that
   looks like authentication.
4. **Using a system-assigned identity.** Federated credentials attach to **user-assigned** managed
   identities or app registrations.
5. **Leaving the old Kubernetes `Secret` in place** after migrating — the risk is still there.
6. **One identity for the whole cluster**, which recreates the node-level problem you just fixed.
   One identity per workload.

## Evidence this topic needs

- `lab/` — AKS with OIDC issuer + workload identity; a pod retrieves a Key Vault secret with **no
  Kubernetes `Secret` anywhere**; inspect the projected token and decode it (Layer 1 §4).
- `break-fix/` — deploy the pod into the **wrong namespace** and read the subject-mismatch failure;
  then omit the pod label and observe the different failure mode.
- `security/` — one identity per workload; namespace isolation proof; audit for any remaining
  `Secret` objects holding Azure credentials.
- `architecture-decisions/` — ADR: workload identity over node-assigned identity, and the migration
  path from `aad-pod-identity`.
