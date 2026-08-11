# Private AI Networking

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> Applies [`../../10-networking/private-endpoints/`](../../10-networking/private-endpoints/) to AI
> workloads. Pairs with [`../azure-openai/`](../azure-openai/) and
> [`../model-access-control/`](../model-access-control/).

---

## 1. What it is

Removing AI endpoints from the public internet so they are reachable **only from your networks** —
and doing it for **every component**, not just the model.

⭐ **The mistake is scoping this to the model endpoint.** A RAG system has at least four:

```
┌─ Foundry / model endpoint      ⭐ the one everyone remembers
├─ AI Search service            the index — holds copies of your documents
├─ Storage account              source documents, embeddings, uploads
└─ Key Vault                    keys, connection strings
```

**Any one left public is the way in.** The model endpoint is the *least* interesting of the four to
an attacker: **the search index and the storage account hold the actual data.**

---

## 2. Why it matters more here than elsewhere

Two reasons specific to AI:

1. ⭐ **Prompts and completions are the most sensitive traffic in the estate** — they contain whatever
   the user pasted and whatever retrieval surfaced. This is not API telemetry; it is the data itself,
   in transit.
2. **The regulatory question is "where is it processed?"** Private networking is a large part of the
   answer to a data-residency reviewer, and one of the strongest arguments against staff using
   consumer AI tools.

---

## 3. The pattern

```
                      ┌──────────── HUB ────────────┐
   on-prem ─ ER/VPN ─▶│  Azure Firewall             │
                      │  Private DNS Zones          │
                      └──────────┬──────────────────┘
                            peering │
                      ┌──────────▼──────────────────┐
                      │  SPOKE: AI workload         │
                      │   app subnet                │
                      │   PE → Foundry              │
                      │   PE → AI Search            │
                      │   PE → Storage              │
                      │   PE → Key Vault            │
                      └─────────────────────────────┘
```

**Each private endpoint needs its own Private DNS Zone**, and the zone names differ per service:

| Service | Private DNS Zone |
|---|---|
| Foundry / Azure OpenAI | `privatelink.openai.azure.com` ⚠ verify current |
| AI Search | `privatelink.search.windows.net` |
| Storage (blob) | `privatelink.blob.core.windows.net` |
| Key Vault | `privatelink.vaultcore.azure.net` |

⭐ **Four services, four zones, and every one must be linked to the VNet.** Miss one and that service
silently resolves publicly — the failure from
[`../../10-networking/private-endpoints/`](../../10-networking/private-endpoints/) §4, repeated four
times over.

---

## 4. Worked example — the audit that finds the gap

**Private endpoint deployed ≠ public access disabled.** Both must be true, for all four:

```bash
# Model / AI services
az cognitiveservices account list --query "[].{Name:name, Public:properties.publicNetworkAccess, \
    LocalAuth:properties.disableLocalAuth}" -o table

# Search
az search service list --query "[].{Name:name, Public:publicNetworkAccess, \
    AuthOptions:authOptions}" -o table

# Storage
az storage account list --query "[].{Name:name, Public:publicNetworkAccess, \
    DefaultAction:networkRuleSet.defaultAction, SharedKey:allowSharedKeyAccess}" -o table

# Key Vault
az keyvault list --query "[].{Name:name, Public:properties.publicNetworkAccess, \
    RBAC:properties.enableRbacAuthorization}" -o table
```

```
Name             Public    LocalAuth/SharedKey
---------------  --------  -------------------
foundry-prod     Disabled  True (local auth off)   ✅
srch-prod        Enabled   —                        <-- ⚠⚠ the index is on the internet
stai-prod        Disabled  SharedKey: True          <-- ⚠ key access still allowed
kv-prod          Disabled  RBAC: True               ✅
```

⭐ **Two findings in one screen.** The **search service is publicly reachable** — and it holds
copies of every indexed document, so it is the highest-value target of the four. And storage still
permits **shared key access**, which is the same anonymous-credential problem as API keys in
[`../azure-openai/`](../azure-openai/) §3.

**Then prove resolution from inside the VNet** — configuration is not evidence:

```powershell
# From a VM in the app subnet — must return PRIVATE addresses
'my-foundry.openai.azure.com','srch-prod.search.windows.net',
'stai-prod.blob.core.windows.net','kv-prod.vault.azure.net' |
  ForEach-Object { Resolve-DnsName $_ | Where-Object Type -eq 'A' |
                   Select-Object Name, IPAddress }
```

⭐ **A public IP in that output means a Private DNS Zone is not linked** — and traffic is leaving your
network while every portal blade shows "private endpoint: connected."

---

## 5. Egress is the other half

Inbound privacy without egress control is half a design:

```
AI workload subnet
   └─ UDR → Azure Firewall → ⭐ FQDN rules
        allow:  your Foundry endpoint, your Search, your Storage
        deny:   everything else — including other AI providers
```

⭐ **Egress filtering is what stops a compromised AI workload calling out to an attacker's model
endpoint or exfiltrating retrieved documents.** It is also the technical control behind "we do not
use consumer AI tools" — see
[`../../10-networking/nat-and-firewalls/`](../../10-networking/nat-and-firewalls/) §5.

⚠ **Beware over-broad FQDN rules.** Allowing `*.openai.azure.com` permits **any** Azure OpenAI
resource in the world, including the attacker's. Scope to your own endpoints.

---

## 6. What breaks

**Only the model endpoint made private.** §1 — search and storage hold the data.

**Private endpoint without disabling public access.** Not a control.

**Private DNS Zone not linked.** §4 — resolves publicly, silently.

**Shared key access left enabled on storage.** Anonymous credential path.

**No egress filtering.** Exfiltration and shadow-model calls unrestricted.

**`*.openai.azure.com` allow rule.** Permits every Azure OpenAI resource globally.

**On-premises clients resolving publicly.** Needs conditional forwarders to the Private Resolver —
[`../../10-networking/dns/`](../../10-networking/dns/) §6.

**Indexer connectivity forgotten.** ⚠ The indexer must reach the data source; locking down storage
without configuring the indexer's access path breaks ingestion, usually days later.

---

## 7. Customer discovery questions

1. Which of the **four** components are private — model, search, storage, Key Vault?
2. Is **public network access disabled** on each, or just private endpoints added?
3. Are **all four Private DNS Zones** linked to the VNet? *(§4 — resolve from inside.)*
4. Is **shared key access** disabled on storage, and **local auth** on the model?
5. Is egress **filtered by FQDN**, and are the rules scoped to your own endpoints?
6. Can on-premises clients resolve the private names?
7. How does the **indexer** reach the data source under lockdown?
8. Where are prompts and completions logged, and is that store private too?

---

## 8. Remember it

**Hook — "Four endpoints, four DNS zones, and public access off on all of them."**

**Analogy — a soundproofed meeting room with the windows open.** Everyone concentrates on the **door**
(the model endpoint) and installs an impressive lock. **Meanwhile the filing cabinet is by the open
window** (the search index), **and the photocopies are on the fire escape** (storage). ⭐ **The model
endpoint is the least interesting of the four to an attacker** — it computes; the others *hold the
data*.

**The one thing:** ⭐ **the search index is the highest-value target, and it is the one most often
left public.** It contains copies of every indexed document, it is queryable, and it is not what
people picture when they say "we secured our AI endpoint."

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Name the four components that need private networking.
2. Which is the highest-value target, and why?
3. Why is a private endpoint alone insufficient?
4. How do you prove Private DNS Zones are linked?
5. What is the storage equivalent of an API key, and which setting disables it?
6. Why does egress filtering matter for AI workloads specifically?
7. What is wrong with an `*.openai.azure.com` firewall rule?
8. What commonly breaks days after locking down storage?

<details>
<summary>Answers</summary>

1. **Model/Foundry endpoint, AI Search, Storage, Key Vault.**
2. ⭐ **AI Search** — it holds **copies of every indexed document** and is queryable.
3. The **public endpoint stays live** unless public network access is explicitly disabled.
4. **Resolve the names from a VM inside the VNet** and confirm **private** IP addresses are returned.
5. **Shared key access** — disable with `allowSharedKeyAccess: false`.
6. It stops a compromised workload **calling an attacker's model endpoint or exfiltrating retrieved
   documents**, and it is the technical control behind banning consumer AI tools.
7. It permits **every Azure OpenAI resource in the world**, including an attacker's.
8. **Indexer connectivity** — ingestion fails once the data source is locked down.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — build the §3 pattern; run the §4 audit and the DNS resolution test from inside the
  VNet. ✗ Requires an Azure subscription.
- **`break-fix/`** ⭐ — deploy a private endpoint **without linking the DNS zone**, prove traffic
  still resolves publicly, then link it and prove the change. Then lock down storage and **break the
  indexer**, and fix its access path.
- **`security/`** — the §4 four-service audit; egress FQDN rules reviewed for over-breadth;
  prompt/completion log store confirmed private.
- **`operations/`** — DNS zone link register; indexer connectivity documented.
- **`architecture-decisions/`** — ADR: all four components private, public access disabled, egress
  scoped to owned endpoints.
- **`customer-use-cases/`** — §7 answered against a real AI deployment.
