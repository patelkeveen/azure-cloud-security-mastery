# Workload Identity for AKS

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (updated 2026-07-14).
> Builds on [`../workload-identity-federation/`](../workload-identity-federation/) and
> [Layer 4 §4](../service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md).

---

## 1. What it is

Giving a **Kubernetes pod** an Entra identity so it can reach Key Vault, Storage, SQL or Graph
**without a secret in the cluster**. It is workload identity federation with **Kubernetes as the
external identity provider** — the AKS cluster acts as the token issuer, and Entra validates its
tokens over OIDC.

⭐ ✅ **On AKS Automatic, workload identity and the OIDC issuer are preconfigured by default.** On
AKS Standard you enable both yourself. Knowing which cluster type you are looking at saves an hour.

---

## 2. Why this specific problem is hard

A Kubernetes cluster is a multi-tenant compute environment. Historically credentials were handed to
the **node**, so **every pod on that node inherited them** — including a compromised sidecar in an
unrelated namespace. Kubernetes `Secret` objects are worse than the name suggests: base64-encoded,
not encrypted, readable by anything with the right RBAC in that namespace.

> **Workload identity moves the boundary from the node to the pod**, which is where the trust
> boundary actually belongs.

---

## 3. How it works underneath

```
AKS cluster with OIDC issuer enabled
   └── Kubernetes ServiceAccount   annotated: azure.workload.identity/client-id
        └── Pod                    labelled:  azure.workload.identity/use: "true"
             → mutating webhook injects env vars + projected SA token volume
             → projected token (short-lived, audience-scoped)
             → exchanged at Entra for an access token
             → calls Key Vault / Storage / Graph
```

**Entra verifies the cluster's tokens via two OIDC endpoints** ✅:

| Endpoint | Purpose |
|---|---|
| `{IssuerURL}/.well-known/openid-configuration` | Discovery document |
| `{IssuerURL}/openid/v1/jwks` | ⭐ Public signing keys Entra uses to verify the SA token |

**The federated credential's `subject`** is `system:serviceaccount:<namespace>:<serviceaccount-name>`.
⭐ **That string is the authorisation boundary** — a pod in a different namespace, or using a
different service account, produces a different subject and is refused. Same case-sensitive matching
rule as GitHub Actions.

---

## 4. ⭐ The pod label is not optional, and the reason matters ✅

```yaml
metadata:
  labels:
    azure.workload.identity/use: "true"     # ⭐ REQUIRED
```

Only pods carrying this label are mutated by the webhook. ✅ Microsoft's own wording: the label moves
AKS to a **"Fail Close"** scenario for consistent behaviour — **"otherwise, the pods fail after they
are restarted."**

> ⭐ **That is the nastiest failure mode in this topic.** The pod deploys, runs, and works. It fails
> *after a restart* — which happens at 3am during a node upgrade, long after the change that caused
> it. Deploy-time success proves nothing here.

**And the companion rule** ✅: **if you update service account annotations, you must restart the
pod.** The webhook injects at admission; an existing pod never re-reads them.

---

## 5. Worked example — the full wiring

```bash
# 1. Cluster: enable OIDC issuer + workload identity (AKS Standard only)
az aks update -g rg-prod -n aks-prod --enable-oidc-issuer --enable-workload-identity
ISSUER=$(az aks show -g rg-prod -n aks-prod --query oidcIssuerProfile.issuerUrl -o tsv)

# 2. User-assigned managed identity (NOT system-assigned)
az identity create -g rg-prod -n mi-app
CLIENT_ID=$(az identity show -g rg-prod -n mi-app --query clientId -o tsv)

# 3. Federated credential — subject encodes namespace AND service account
az identity federated-credential create \
  --identity-name mi-app -g rg-prod --name aks-app \
  --issuer "$ISSUER" \
  --subject "system:serviceaccount:apps:sa-app" \
  --audiences api://AzureADTokenExchange
```

```yaml
# 4. ServiceAccount + Pod
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sa-app
  namespace: apps
  annotations:
    azure.workload.identity/client-id: "<CLIENT_ID>"
---
apiVersion: v1
kind: Pod
metadata:
  name: app
  namespace: apps
  labels:
    azure.workload.identity/use: "true"      # ⭐ or it breaks on restart
spec:
  serviceAccountName: sa-app
  containers:
    - name: app
      image: myapp:1.0
```

**Verify the webhook actually injected — the first diagnostic:**

```bash
kubectl describe pod app -n apps | grep -A5 "Environment"
```

```
AZURE_CLIENT_ID:            aaaabbbb-0000-cccc-1111-dddd2222eeee
AZURE_TENANT_ID:            b6464ac2-0b24-4e5f-be10-b4270b90d4ce
AZURE_FEDERATED_TOKEN_FILE: /var/run/secrets/azure/tokens/azure-identity-token
AZURE_AUTHORITY_HOST:       https://login.microsoftonline.com/
```

⭐ **No `AZURE_*` variables means the label is missing or the webhook did not run.** That single check
separates "identity misconfigured" from "webhook never fired", and they have completely different fixes.

---

## 6. ⭐ The scope gotcha that is unique to this topic ✅

```csharp
// ✅ CORRECT — workload identity uses the Entra v2 token endpoint
scope: "https://management.azure.com/.default"

// ✗ CAN FAIL — raw resource URI is the IMDS `resource` flow used by MANAGED identity
resource: "https://management.azure.com/"
```

> ⭐ **Managed identity and workload identity acquire tokens by different mechanisms.** Managed
> identity calls **IMDS** with a `resource`; workload identity exchanges a projected token at the
> **v2 endpoint** with a `<resource>/.default` scope. **Code migrated from a VM to a pod fails on
> exactly this**, and the error rarely points at the scope format.

⚠ Minimum Azure Identity library versions apply (.NET 1.9.0, Go 1.3.0, Java 1.9.0, Node 3.2.0,
Python 1.13.0, C++ 1.6.0). Older versions do not know how to do the exchange.

---

## 7. Token lifetimes — two clocks, uncorrelated ✅

| Token | Default | Range |
|---|---|---|
| Projected **Kubernetes** SA token | **3600 s** | 3600–86400 (`service-account-token-expiration`) |
| **Entra** access token | ⭐ **24 hours** | — |

✅ **"Kubernetes service account token expiry isn't correlated with Microsoft Entra tokens."** Two
independent clocks. Lengthening the SA token expiry is the documented mitigation for downtime caused
by refresh errors — ⚠ and pod annotations **take precedence over** service account annotations.

---

## 8. Limits and unsupported scenarios ✅

- ⭐ **Maximum 20 federated identity credentials per managed identity**
- Propagation takes **a few seconds** after adding a credential
- ⭐ **Virtual nodes (Virtual Kubelet) are not supported**
- FIC creation is **unsupported on user-assigned managed identities in certain regions** — verify
  before designing

⚠ **Identity bindings (preview)** address the 20-FIC ceiling at scale: multiple clusters share one
user-assigned identity through a single FIC, via an identity binding proxy webhook. It uses audience
**`api://AKSIdentityBinding`**, whereas direct federation uses **`api://AzureADTokenExchange`** —
mixing the token files fails with **`AADSTS700212`**. Verify preview status before recommending it.

---

## 9. What it replaces

| Approach | Problem |
|---|---|
| Secret in a Kubernetes `Secret` | Not encrypted; readable in-namespace; must be rotated |
| **Pod-managed identity (`aad-pod-identity`)** | ⭐ Node-level; superseded by workload identity |
| Node-assigned managed identity | **Every pod on the node inherits it** |

✅ **Migration paths:** annotate the service account using the same identity configuration, **or**
upgrade to a supported Azure Identity library. Microsoft also ships a **migration sidecar** that
proxies the application's IMDS calls to OIDC — ⚠ explicitly *"not intended to be a long-term
solution"*, just a way to move quickly.

**If you find `aad-pod-identity` in a customer cluster, that is a migration item, not a working design.**

---

## 10. What breaks

**Missing the pod label.** §4 — works until restart, then fails.

**Changed SA annotations without restarting the pod.** The webhook injects at admission only.

**Subject string mismatch.** `system:serviceaccount:default:myapp` ≠ `…:Default:myapp`.

**Raw resource URI instead of `/.default`.** §6 — the VM-to-pod migration failure.

**Old Azure Identity library version.** It cannot perform the exchange.

**Missing RBAC on the target.** The identity authenticates and reaches nothing — a `403` that reads
like authentication.

**Using a system-assigned identity.** Federated credentials attach to **user-assigned** identities
or app registrations.

**Leaving the old Kubernetes `Secret` in place** after migrating. The risk is still there.

**One identity for the whole cluster.** Recreates the node-level problem you just fixed.

**Virtual nodes.** Unsupported.

---

## 11. Customer discovery questions

1. **AKS Automatic or Standard?** *(Decides whether cluster setup is already done.)*
2. Is `aad-pod-identity` still present anywhere?
3. Are there Kubernetes `Secret` objects holding Azure credentials?
4. Is it **one identity per workload**, or one shared cluster-wide?
5. Are pods labelled `azure.workload.identity/use: "true"` — **all of them**?
6. Any managed identity approaching the **20 FIC** limit?
7. Are subjects scoped to namespace **and** service account, or broadly?
8. Which Azure Identity library versions are in the images?
9. Are virtual nodes in use anywhere?

---

## 12. Remember it

**Hook — "Label the pod, annotate the service account, subject the namespace."** Three places, three
different jobs.

**Analogy — a building pass tied to the desk, not the floor.** Node-assigned identity is a pass that
opens the door for **everyone on that floor** — including the contractor you never vetted. Workload
identity issues the pass **to the specific desk**: the namespace and service account in the subject
are the desk number. **And the pod label is the lanyard — without it, security waves you through
today and stops you tomorrow**, which is precisely the restart failure.

**The one thing:** ⭐ **the missing pod label fails *after a restart*, not at deploy.** It works, it
ships, and then it breaks during a 3am node upgrade with no recent change to blame. **Deploy-time
success proves nothing here** — check for the injected `AZURE_*` environment variables instead.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 13. Self-test

1. What acts as the token issuer, and how does Entra verify its tokens?
2. What does the federated credential's `subject` encode, and why is that the security boundary?
3. What happens if the pod label is missing — and *when*?
4. You changed a service account annotation. What else must you do?
5. Why does code that worked on a VM fail in a pod with a scope error?
6. Are the Kubernetes SA token and Entra token lifetimes related?
7. How many federated identity credentials per managed identity?
8. Which identity type can a federated credential attach to?
9. First command to distinguish "webhook never fired" from "identity misconfigured"?
10. What is the status of `aad-pod-identity`?

<details>
<summary>Answers</summary>

1. **The AKS cluster.** Entra fetches the discovery document and **JWKS** from the cluster's OIDC
   issuer URL and verifies the service account token's signature.
2. **`system:serviceaccount:<namespace>:<sa-name>`** — a different namespace or service account
   produces a different subject and is refused.
3. The pod is **not mutated** by the webhook. It **fails after it is restarted**, not at deploy.
4. **Restart the pod.** Injection happens at admission.
5. Workload identity uses the **v2 endpoint with `<resource>/.default`**; managed identity uses
   **IMDS with a raw `resource`**. The raw URI can fail.
6. **No — uncorrelated.** SA token default 3600 s (up to 86400); **Entra tokens expire in 24 hours**.
7. **20.**
8. A **user-assigned managed identity** or an **app registration** — never system-assigned.
9. `kubectl describe pod` and look for the injected **`AZURE_*`** environment variables.
10. **Superseded** by workload identity. Finding it in a cluster is a migration item.

</details>

---

## 14. Evidence this topic needs

- **`lab/`** — AKS with OIDC issuer + workload identity; a pod retrieves a Key Vault secret with
  **no Kubernetes `Secret` anywhere**; inspect and decode the projected token. ✗ Requires an Azure
  subscription.
- **`break-fix/`** ⭐ — deploy the pod **without the label**, confirm it works, then **restart it and
  capture the failure**. Then deploy into the **wrong namespace** and read the subject-mismatch error.
  Two failures, two completely different causes.
- **`security/`** — one identity per workload proven; namespace isolation demonstrated; audit for
  remaining `Secret` objects holding Azure credentials; `aad-pod-identity` sweep.
- **`operations/`** — FIC count per identity against the 20 limit; Azure Identity library versions
  in images.
- **`architecture-decisions/`** — ADR: workload identity over node-assigned identity, and the
  migration path from `aad-pod-identity`.
- **`customer-use-cases/`** — §11 answered against a real cluster.
