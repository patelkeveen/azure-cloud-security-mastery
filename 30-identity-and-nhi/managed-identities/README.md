# Managed Identities

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (updated 2026-06-15).
> **SC-300 Domain 3 core.** Depth in
> [Layer 4 §3](../service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md).

---

## 1. What it is

An identity for an Azure resource where **Azure creates, rotates and destroys the credential** — so
no credential exists for you to leak, expire, or commit to git.

✅ **"Credentials aren't even accessible to you."** That is the design, not a limitation.

Underneath, a managed identity **is a service principal** (`servicePrincipalType = ManagedIdentity`)
with **no application object behind it**. It can be granted permissions but **cannot be modified
directly** — which is the point. ✅ **And it costs nothing extra.**

---

## 2. The two kinds — and which Microsoft recommends

| Property | **System-assigned** | **User-assigned** |
|---|---|---|
| Creation | Part of an Azure resource | ⭐ **Stand-alone Azure resource** |
| Lifecycle | **Deleted with the parent** | Independent; must be explicitly deleted |
| Sharing | ✗ One resource only | ✅ **Many resources** |
| Pre-creatable | ✗ | ✅ Grant RBAC **before** the resource exists |
| Survives redeploy | ⭐ **No — new object ID** | ✅ Yes |

> ⭐ ✅ **User-assigned is Microsoft's recommended type**: *"provisioned independently from compute
> and can be assigned to multiple compute resources… the recommended managed identity type for
> Microsoft services."*

✅ Microsoft's own use cases for **user-assigned** name the two that matter in practice:

- **Workloads needing preauthorisation to a secure resource as part of a provisioning flow** — you
  can grant RBAC before the VM exists, which is what IaC ordering requires
- ⭐ **Workloads where resources are recycled frequently but permissions should stay consistent**

**The redeploy trap, in Microsoft's own framing.** A system-assigned identity gets a **new object
ID** on recreation, orphaning every role assignment referencing the old one. Terraform
destroy/apply cycles hit this constantly — and it is the strongest practical argument for
user-assigned in any IaC-managed estate.

⭐ **Naming detail worth knowing for log analysis** ✅: a system-assigned identity's service principal
is **always named the same as the Azure resource**. For an App Service deployment slot it is
`<app-name>/slots/<slot-name>`. That is how you identify one in a sign-in log.

---

## 3. ⭐ Managed identity as a credential for an app registration ✅

**This is the bridge topic, and it closes the loop.**

Sometimes you genuinely need an app registration — the workload is multi-tenant, signs in users, or
acts as a web API ([`../app-registrations/`](../app-registrations/) §3). Historically that meant a
certificate or a secret.

Not any more:

```
Workload on Azure compute
    │  has a MANAGED IDENTITY
    ▼
gets a managed identity token
    │  exchanged via WORKLOAD IDENTITY FEDERATION
    ▼
Entra ID APPLICATION token   ← the app registration has NO secret and NO certificate
```

✅ **"Whenever an Entra ID app is required, this is the recommended way to be credential-free."**

⚠ **Limit: 20 federated identity credentials** when using managed identities as FIC on an Entra app.

> ⭐ **So "we need an app registration, therefore we need a secret" is now false.** If the workload
> runs on Azure compute, the app registration can be credential-free too. Very few people know this,
> and it is the answer to the most common objection against eliminating client secrets.
> See [`../workload-identity-federation/`](../workload-identity-federation/).

---

## 4. How the token is actually obtained

The resource calls the **Instance Metadata Service** at the link-local address
**`169.254.169.254`**, reachable only from inside the compute, with a required header:

```bash
curl -s -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net"
```

```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6...",
  "expires_in": "86399",
  "resource": "https://vault.azure.net",
  "token_type": "Bearer"
}
```

⭐ **No secret is transmitted or stored, because the platform's proof is "you are running on this
compute."** The network boundary *is* the authentication.

**Which is exactly why SSRF against a cloud workload is so serious.** An attacker who can make the
server issue that request retrieves a real token for its identity — see
[`../../10-networking/ipv4-ipv6-subnetting/`](../../10-networking/ipv4-ipv6-subnetting/) §5.
`169.254.169.254` should never be reachable from anywhere it does not need to be.

**In code you rarely call IMDS directly** — `DefaultAzureCredential` walks a chain of sources until
one succeeds. ⚠ **That chain order differs between SDK languages and versions.** It is why code
works locally under your own login and fails in Azure, or the reverse: a different link answered.
Check the version you are on rather than assuming.

**With a user-assigned identity you must say which one**, because a resource can hold several:

```csharp
new DefaultAzureCredential(new DefaultAzureCredentialOptions {
    ManagedIdentityClientId = "aaaabbbb-0000-cccc-1111-dddd2222eeee"   // ⭐ required when >1
});
```

---

## 5. Worked example — auditing managed identities by scope

**The finding is never "this identity exists." It is "this identity can do far more than it needs."**

```bash
# Every role assignment held by a managed identity, widest scope first
az role assignment list --all --query "[?principalType=='ServicePrincipal'].{
    Principal:principalName, Role:roleDefinitionName, Scope:scope}" -o json |
  ConvertFrom-Json | Sort-Object { $_.Scope.Length }
```

```
Principal                Role           Scope
-----------------------  -------------  ------------------------------------------------
mi-data-pipeline         Contributor    /subscriptions/xxxx                    <-- ⚠
vmss-web-prod            Reader         /subscriptions/xxxx/resourceGroups/rg-prod
func-invoice             Key Vault Secrets User  /subscriptions/.../vaults/kv-invoice   ✅
```

⭐ **Sort by scope length — shortest scope is widest blast radius.** `Contributor` at subscription
scope on a data pipeline means a compromise of that pipeline is a compromise of the subscription.
That single row is the §5 finding in
[`../../50-security-operations/attack-path-analysis/`](../../50-security-operations/attack-path-analysis/):
the cheapest break in an attack path is usually **removing this role assignment**, not patching the VM.

**Find orphaned assignments from the redeploy trap:**

```bash
# Role assignments whose principal no longer exists
az role assignment list --all --include-inherited --query "[?principalName==null]" -o table
```

Every row is a system-assigned identity that was destroyed and recreated, leaving a dangling
assignment. **Harmless individually; a sign that §2 is biting.**

**Confirm what a managed identity actually is, in Entra:**

```powershell
Get-MgServicePrincipal -Filter "servicePrincipalType eq 'ManagedIdentity'" -All |
  Select-Object DisplayName, Id, AppId, AlternativeNames
```

`AlternativeNames` carries the Azure resource ID — ⭐ the link back from the directory object to the
resource that owns it, which is how you answer "what is this thing?" during an incident.

---

## 6. When and where

**Default to a managed identity whenever the workload runs on Azure compute that supports one** —
VMs, VM Scale Sets, Service Fabric, AKS, App Service, Functions, Container Apps, Logic Apps, Data
Factory and more.

```
Runs on Azure compute?          → MANAGED IDENTITY          (user-assigned by default)
Needs an Entra app anyway?      → managed identity as FIC   (§3 — still credential-free)
Runs outside Azure?             → WORKLOAD IDENTITY FEDERATION
None of the above?              → app registration + CERTIFICATE (never a secret)
```

**That decision tree is the whole of workload identity design**, and it is worth being able to draw
from memory.

---

## 7. What breaks

**Assigning the identity but forgetting RBAC on the target.** The identity exists and can reach
nothing — a `403` that reads like an authentication failure but is authorisation. See
[`../../10-networking/http-and-api-networking/`](../../10-networking/http-and-api-networking/) §3.

**RBAC propagation lag.** Retry before concluding the config is wrong.

**Expecting it to work off-Azure.** IMDS is unreachable; by design.

**System-assigned in IaC.** §2 — new object ID on redeploy, orphaned assignments.

**Over-scoping.** `Contributor` at subscription scope removes the benefit of a narrow identity.

**Multiple user-assigned identities without specifying the client ID.** §4 — ambiguous, and the SDK
cannot guess.

**Assuming `DefaultAzureCredential` behaves identically everywhere.** The chain order varies.

**Exposing `169.254.169.254` to a workload that can be induced to call it.** SSRF → token theft.

**Forgetting managed identities are in scope for governance.** They are service principals; PIM can
target them, and [`../identity-protection/`](../identity-protection/) can flag them with the
Workload Identities Premium licence.

---

## 8. Customer discovery questions

1. Are workloads using managed identities, or **secrets in app settings**?
2. **System-assigned or user-assigned** — and was that a decision or a default?
3. Any managed identity holding **Contributor or Owner at subscription scope**?
4. Are there **orphaned role assignments** from destroyed system-assigned identities?
5. Where an app registration is genuinely required, is it using a **managed identity as FIC**? *(§3.)*
6. Is `169.254.169.254` reachable from anything that processes untrusted input?
7. Are managed identities covered by access reviews or any governance at all?
8. Does anyone monitor managed identity sign-ins? *(`AADManagedIdentitySignInLogs`.)*

---

## 9. Remember it

**Hook — "The network boundary is the authentication."** No secret is sent because the proof is
*"you are running on this compute."*

**Analogy — a staff door with a badge reader you cannot take home.** An app registration secret is a
**key you carry** — it can be copied, dropped, left in a taxi, or committed to git. A managed
identity is a **reader on the inside of the building**: it works only where you are standing, and
there is nothing to hand over. **That is also why it cannot work from your laptop — and why that
limitation is the feature.** SSRF is someone shouting through the letterbox and persuading a member
of staff to badge the door for them.

**The one thing:** ⭐ **"we need an app registration, therefore we need a secret" is now false.** A
managed identity can be a **federated credential on an Entra app** (limit 20), so even multi-tenant
apps and web APIs on Azure compute can be entirely credential-free. Decision order:
**managed identity → managed identity as FIC → workload identity federation → certificate → never a
secret.**

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 10. Self-test

1. What is a managed identity, underneath?
2. System-assigned versus user-assigned — which does Microsoft recommend, and why?
3. What happens to role assignments when a system-assigned identity's resource is recreated?
4. What is a system-assigned identity's service principal named?
5. How is a token obtained, and what proves the caller's identity?
6. Why can't a managed identity be used from your laptop?
7. Why is SSRF against a cloud workload so serious?
8. You need an Entra app registration. Must it have a secret or certificate?
9. What must you specify when a resource has more than one user-assigned identity?
10. In an RBAC audit, which sort order surfaces the worst finding first?

<details>
<summary>Answers</summary>

1. **A service principal** (`servicePrincipalType = ManagedIdentity`) with **no application object**,
   whose credential Azure creates, rotates and destroys.
2. **User-assigned** — independent lifecycle, shareable, pre-creatable, and it **survives redeploys**.
3. They are **orphaned** — the identity gets a **new object ID**, and the old assignments dangle.
4. **The same name as the Azure resource** (for a slot, `<app-name>/slots/<slot-name>`).
5. A call to **IMDS at `169.254.169.254`** with a `Metadata: true` header. **The proof is that the
   code is running on that compute** — the network boundary is the authentication.
6. **IMDS is not reachable** from outside the Azure compute instance. By design.
7. An attacker who makes the server call IMDS **retrieves a real token** for the workload's identity.
8. **No.** Use a **managed identity as a federated identity credential** (limit 20) — the
   recommended credential-free route when an app is genuinely required.
9. **The client ID** of the intended identity — the SDK cannot disambiguate.
10. **Shortest scope first** — the widest blast radius, e.g. Contributor at subscription scope.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — a VM with a system-assigned identity retrieves a Key Vault secret **with no credential
  in code**; then `curl` IMDS directly and decode the raw token. ✗ **Requires an Azure subscription.**
- **`break-fix/`** ⭐ — destroy and recreate the VM, watch the role assignment orphan, then redo it
  with a **user-assigned** identity and watch it survive. **The single most convincing demonstration
  of §2.**
- **`security/`** — the §5 scope audit sorted shortest-scope-first; orphaned assignment sweep;
  confirmation that `169.254.169.254` is not reachable from untrusted-input workloads.
- **`operations/`** — managed identity inventory linked back to Azure resources via
  `AlternativeNames`; monitoring of `AADManagedIdentitySignInLogs`.
- **`architecture-decisions/`** — ADR: user-assigned as the default, with the §6 decision tree
  recorded and the IaC rationale stated.
- **`customer-use-cases/`** — §8 answered against a real subscription.
