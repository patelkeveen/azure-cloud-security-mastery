# Model Access Control

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10**.
> Builds on [`../azure-openai/`](../azure-openai/) and
> [`../../30-identity-and-nhi/managed-identities/`](../../30-identity-and-nhi/managed-identities/).

---

## 1. What it is

Deciding **which identities may invoke which models, at what scope, at what rate** — and being able
to prove afterwards who did.

Four independent layers, and most estates implement one:

```
1. NETWORK     can the endpoint be reached at all?         private endpoint, public access
2. IDENTITY    ⭐ who is calling — and is it a WHO or a WHAT?  Entra ID vs API key
3. AUTHZ       what may that identity do?                   Azure RBAC data-plane roles
4. RATE        how much may it consume?                     quota, TPM, gateway policy
```

---

## 2. Why the identity layer dominates

⭐ **An API key answers "does the caller know the secret", not "who is the caller".** Everything
downstream — audit, least privilege, Conditional Access, revocation of one consumer — depends on
having a real principal.

| With an API key you cannot | With Entra ID you can |
|---|---|
| Say **who** called | Read the principal from the token and the logs |
| Apply **Conditional Access** | ⭐ CA applies |
| Revoke **one** consumer | Remove that role assignment |
| Grant **different scopes** to different callers | Scope per identity |

> ⭐ **This is the same lesson as service principals and secrets, arriving in a new product.** The
> repo has now made this argument three times in three domains — which is itself the point: the
> identity model does not change because the workload is AI.

---

## 3. The authorisation layer ✅

| Role | Grants | Correct for |
|---|---|---|
| **Cognitive Services OpenAI User** | ⭐ Inference only | **Applications** |
| Cognitive Services OpenAI Contributor | Inference + create deployments/fine-tunes | Platform team |
| **Foundry User / Project Manager** | Foundry platform operations | Builders |
| Cognitive Services Contributor | Control plane — ⚠ **can read keys** | ⭐ Almost never a workload |

**Scope matters as much as role.** A role assignment at **subscription** scope grants access to
every model resource in it; at **resource** scope it grants one.

```bash
az role assignment list --all \
  --query "[?contains(roleDefinitionName,'Cognitive Services') || contains(roleDefinitionName,'Foundry')].{
     Principal:principalName, Role:roleDefinitionName, Type:principalType, Scope:scope}" -o json |
  ConvertFrom-Json | Sort-Object { $_.Scope.Length }
```

```
Principal            Role                                Type              Scope
-------------------  ----------------------------------  ----------------  ---------------------------
ai-platform-team     Cognitive Services Contributor      Group             /subscriptions/xxxx        <-- ⚠
mi-chat-frontend     Cognitive Services OpenAI User      ServicePrincipal  /.../foundry-prod          ✅
```

⭐ **Shortest scope first, same technique as everywhere else in this repo.** A group holding
Contributor at subscription scope can **read the keys of every AI resource** — which reopens the
key path you closed in [`../azure-openai/`](../azure-openai/) §3.

---

## 4. ⭐ Rate limiting is an access control

Two attacks that identity alone does not stop:

| Attack | Mechanism | Control |
|---|---|---|
| **Denial of wallet** | Uncapped consumption; attacker's cost is zero, yours is per token | ⭐ **Quota / TPM ceilings** |
| **Model extraction** | Systematic querying to reconstruct behaviour or training data | Rate limits + anomaly detection |

⭐ **Set a quota ceiling per deployment even where cost is not a concern**, because the ceiling is
what converts a leaked credential from an unbounded bill into a bounded incident. **A control that
caps blast radius is a security control regardless of which budget line it sits on.**

---

## 5. ⭐ The gateway pattern — where this becomes an architecture

At more than a couple of consumers, per-resource RBAC stops being enough. **Azure API Management in
front of Foundry** is the standard answer:

```
Consumers  →  APIM (AI Gateway)  →  Foundry / model endpoints
                 │
                 ├─ authenticate the CALLER (Entra ID, subscription key per consumer)
                 ├─ ⭐ per-consumer TOKEN QUOTAS and rate limits
                 ├─ route/load-balance across deployments and regions
                 ├─ log prompts and completions centrally
                 └─ inject the BACKEND credential (managed identity) — consumers never hold it
```

**Why it is worth the hop:**

1. ⭐ **Consumers never see a model credential.** The gateway holds a managed identity to the backend;
   each consumer authenticates to the gateway. **One place to revoke, one place to audit.**
2. **Per-consumer quotas** — one team cannot exhaust capacity for everyone
3. **Central logging** of prompts and completions, once, rather than per application
4. **Failover across regions and deployments** without changing any client

> ⭐ **This is the SC-500 architecture answer**, and it generalises: the gateway pattern is how you
> impose identity, quota and audit on *any* backend that has weak native controls. Being able to
> draw it — and say *why* each line exists — is the difference between naming a product and
> designing a system.

⚠ APIM AI-specific policy names and capabilities are evolving. **Verify the current policy set**
before quoting specifics to a customer.

---

## 6. What breaks

**API keys distributed to consumers.** No attribution, no per-consumer revocation.

**Cognitive Services Contributor at subscription scope.** §3 — reopens the key path everywhere.

**No quota ceiling.** §4 — denial of wallet.

**Gateway that forwards the caller's key** instead of injecting its own backend credential — you have
added a hop and kept the problem.

**Public network access enabled** alongside keys. Globally reachable, unattributable.

**No per-consumer identity behind the gateway.** "The gateway called it" is not attribution.

**Assuming Conditional Access protects the endpoint.** It does not apply to key-based access.

**Rate limits only at the gateway** while the backend remains directly reachable — the bypass.

---

## 7. Customer discovery questions

1. Do consumers hold **API keys**, or authenticate as themselves?
2. Is there an **AI gateway**, and does it inject the backend credential or forward the caller's?
3. Can the model endpoint be reached **directly**, bypassing the gateway?
4. Who holds **Cognitive Services Contributor**, and at what scope?
5. Are **per-consumer quotas** set, or is capacity shared and uncapped?
6. Is there a bounded worst case if a credential leaks?
7. Are prompts and completions logged **centrally**, or per application, or not at all?
8. Can you answer "which team made these 40,000 calls last Tuesday"?

---

## 8. Remember it

**Hook — "Network, identity, authorisation, rate."** Four layers; most estates build one.

**Analogy — a bar with a tab, not a vending machine.** An **API key is a vending machine token**:
whoever holds it gets served, the machine never learns their name, and if tokens leak you replace
the whole machine. **Entra ID plus a gateway is a bar with named tabs** — the bartender knows who
you are, each person has their own limit, one tab can be closed without shutting the bar, and
**there is a record of every round**. ⭐ **Quota is the limit on the tab, and it is why one team
cannot drink the budget.**

**The one thing:** ⭐ **the gateway's job is to hold the backend credential so consumers never do.**
A gateway that forwards the caller's key has added latency and solved nothing. Once the gateway owns
the managed identity, you get per-consumer identity, per-consumer quota, and one place to revoke and
audit — which is the entire architecture in one sentence.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Name the four access control layers.
2. What question does an API key answer, and what question does it not?
3. Which role can read keys, and why is that significant at subscription scope?
4. Which data-plane role is correct for an inference-only application?
5. Why is quota a security control?
6. What is denial of wallet?
7. Name four things an AI gateway gives you beyond a single endpoint.
8. What is the single most important property of the gateway's credential handling?
9. What defeats a gateway's rate limits entirely?

<details>
<summary>Answers</summary>

1. **Network, identity, authorisation, rate.**
2. It answers **"does the caller know the secret"** — not **"who is the caller"**.
3. **Cognitive Services Contributor.** At subscription scope it can read the keys of **every** AI
   resource, reopening the key path everywhere.
4. **Cognitive Services OpenAI User.**
5. It **bounds the blast radius** of a leaked credential — an unbounded bill becomes a bounded incident.
6. Abuse of an uncapped consumption endpoint: the **attacker's cost is zero and yours is per token**.
7. **Per-consumer identity, per-consumer quotas, central prompt/completion logging, failover across
   deployments and regions** — plus consumers never holding a backend credential.
8. ⭐ It **injects its own backend credential** (managed identity) rather than forwarding the
   caller's key.
9. **The backend being directly reachable**, bypassing the gateway entirely.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — put APIM in front of a Foundry endpoint; authenticate a consumer to the gateway while
  the gateway uses a **managed identity** to the backend; apply a per-consumer token quota.
  ✗ Requires an Azure subscription.
- **`break-fix/`** ⭐ — exhaust one consumer's quota and prove **other consumers are unaffected**;
  then call the backend directly and demonstrate the **gateway bypass**, and close it with private
  networking.
- **`security/`** — the §3 role/scope audit sorted shortest-scope-first; `disableLocalAuth` state;
  direct-reachability test of every model endpoint.
- **`operations/`** — per-consumer quota register; central prompt/completion logging with retention.
- **`architecture-decisions/`** — ADR: the gateway pattern, and the rule that consumers never hold a
  backend credential.
- **`customer-use-cases/`** — §7 answered; a multi-team AI platform design as a deliverable.
