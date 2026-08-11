# Azure Key Vault

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> Where credentials live when they must exist. Consumes
> [`../managed-identities/`](../managed-identities/) and
> [`../../10-networking/private-endpoints/`](../../10-networking/private-endpoints/).
> ⚠ Verify SKU and feature specifics against current docs before quoting to a customer.

---

## 1. What it is

A managed store for three distinct object types, with **different security properties**:

| Object | Contains | Key property |
|---|---|---|
| **Secret** | Any string | Retrievable in full |
| **Key** | A cryptographic key | ⭐ **Never leaves the vault** — you send data to *it* |
| **Certificate** | Cert + its private key | Combines both; supports lifecycle/renewal |

⭐ **The key/secret distinction is the one that matters.** Store a private key **as a key** and the
vault performs sign and decrypt operations on your behalf — the key material never leaves. Store the
same thing **as a secret** and anyone with read access downloads it.

---

## 2. Why it exists

Credentials otherwise live in config files, environment variables, deployment pipelines and
developer laptops — in plaintext, in several copies, with no audit trail and no rotation story.

Key Vault gives one place with **RBAC, logging, versioning, soft delete and HSM options**.

> ⭐ **But note the trap this creates:** teams put a secret in Key Vault and declare the problem
> solved. **A secret in Key Vault is still a secret** — see
> [`../secrets-and-certificates/`](../secrets-and-certificates/). The vault protects storage, not
> the credential class. **Key Vault is the answer to "where does the certificate live", not to
> "should this be a credential at all".**

---

## 3. ⭐ The access model — two systems, and the migration nobody finishes

| Model | Granularity | Status |
|---|---|---|
| **Access policies** (legacy) | Per-vault, per-principal, per-operation | Original model |
| ⭐ **Azure RBAC** | Azure roles, **inheritable, PIM-able, at scope** | **Recommended** |

**Why RBAC wins, concretely:**

- Access policies are **flat and per-vault** — no inheritance, no management-group scope
- ⭐ **Access policies cannot be PIM'd**; Azure RBAC role assignments can be made **eligible**
- RBAC assignments appear in the same audit and review surface as everything else in Azure

⚠ **Mixed estates are common and confusing:** some vaults on access policies, some on RBAC, and the
portal shows different blades depending on which. **Check the permission model per vault before
debugging any access failure.**

```bash
az keyvault list --query "[].{Name:name, RBAC:properties.enableRbacAuthorization, \
    SoftDelete:properties.enableSoftDelete, Purge:properties.enablePurgeProtection}" -o table
```

```
Name          RBAC   SoftDelete  Purge
------------  -----  ----------  -----
kv-prod-app   True   True        True
kv-legacy     False  True        False    <-- ⚠ access policies, no purge protection
```

---

## 4. ⭐ Soft delete and purge protection — the recoverability trap

| Setting | Effect |
|---|---|
| **Soft delete** | Deleted objects recoverable for a retention period |
| ⭐ **Purge protection** | **Nobody can permanently delete before retention expires — not even an owner** |

**Purge protection is what makes deletion survivable against a malicious or mistaken administrator.**
Without it, a compromised owner can delete the vault *and purge it*, and the keys are unrecoverable —
which for an encryption key means **the data encrypted with it is gone**.

⚠ **Purge protection cannot be disabled once enabled.** That is the point, and it means it is a
deliberate decision rather than a default to flip on casually — though for anything holding
encryption keys, the answer is almost always yes.

⭐ **This is the highest-value Key Vault finding in an assessment**, and it appears in the §3 query
above as a single boolean.

---

## 5. Worked example — retrieving a secret with no credential in code

**The pattern this whole domain has been building toward:**

```bash
# 1. Grant the workload's managed identity a data-plane role (RBAC model)
az role assignment create --assignee <managedIdentityPrincipalId> \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/<sub>/resourceGroups/rg-prod/providers/Microsoft.KeyVault/vaults/kv-prod-app
```

```csharp
// 2. No secret, no connection string, no config entry
var client = new SecretClient(
    new Uri("https://kv-prod-app.vault.azure.net/"),
    new DefaultAzureCredential());

KeyVaultSecret secret = await client.GetSecretAsync("Db-ConnectionString");
```

⭐ **Note what is absent: any credential for Key Vault itself.** The managed identity authenticates,
and the "secret to reach the secrets" problem — the usual infinite regress — disappears. **That is
the entire argument for managed identity plus Key Vault as a pair.**

**Least-privilege data-plane roles, in order:**

| Role | Grants |
|---|---|
| **Key Vault Secrets User** | ⭐ Read secret *values* — what an application needs |
| Key Vault Secrets Officer | Full secret management |
| Key Vault Crypto User | Use keys (sign/decrypt) **without reading them** |
| Key Vault Reader | Metadata only, **not values** |
| Key Vault Administrator | Everything — rarely correct for a workload |

⭐ **"Key Vault Reader" does not read secret values.** People assign it expecting an application to
work, and get a confusing 403.

**Audit who can actually read production secrets:**

```bash
az role assignment list --scope /subscriptions/<sub>/resourceGroups/rg-prod/providers/Microsoft.KeyVault/vaults/kv-prod-app \
  --query "[].{Principal:principalName, Role:roleDefinitionName, Type:principalType}" -o table
```

```
Principal                Role                        Type
-----------------------  --------------------------  ---------------
mi-web-prod              Key Vault Secrets User      ServicePrincipal   ✅
platform-team            Key Vault Administrator     Group              <-- ⚠ standing
j.okafor@contoso.com     Key Vault Secrets Officer   User               <-- ⚠ standing
```

⭐ **Standing human access to production secrets is the finding.** Make those assignments **PIM
eligible** — which is only possible because the vault uses RBAC, per §3.

---

## 6. Network exposure

**A Key Vault is internet-reachable by default.** The controls, in increasing strength:

```
firewall + selected networks   →  private endpoint  →  public access DISABLED
```

⚠ **A private endpoint without disabling public network access is not a control** — the same lesson
as [`../../10-networking/private-endpoints/`](../../10-networking/private-endpoints/) §4. And the
Private DNS Zone must be **linked to the VNet**, or clients resolve the public IP and everything
silently keeps working over the internet.

---

## 7. What breaks

**Storing a private key as a secret** instead of a key. §1 — it becomes downloadable.

**Access policies where RBAC was needed.** §3 — no inheritance, no PIM.

**Debugging access without checking the permission model.** Two systems, different blades.

**No purge protection.** §4 — an owner can destroy keys irrecoverably.

**Assigning "Key Vault Reader" to an application.** Metadata only; confusing 403.

**Standing human access to production secrets.** §5.

**Private endpoint without disabling public access.** §6.

**Treating "it's in Key Vault" as the end of the credential conversation.** §2.

**Throttling.** Key Vault has request limits; applications that fetch a secret **per request**
instead of caching will hit them under load.

---

## 8. Customer discovery questions

1. Which vaults use **RBAC** and which still use **access policies**?
2. Is **purge protection** on for every vault holding encryption keys?
3. Who has **standing** Secrets Officer or Administrator on production vaults?
4. Are those assignments **PIM eligible**?
5. Are private keys stored **as keys** or as secrets?
6. Is **public network access disabled**, and are Private DNS Zones linked?
7. Do applications **cache** secrets, or fetch per request?
8. Are Key Vault **diagnostic logs** flowing to Log Analytics, and does anyone alert on them?
9. Could any of these secrets be eliminated with managed identity or federation?

---

## 9. Remember it

**Hook — "Secrets come out. Keys never do."** And: **RBAC over access policies, purge protection on.**

**Analogy — a bank with safe deposit boxes and a signing room.** A **secret** is a document in a
deposit box: you show ID, they hand you the document, and now you have a copy. A **key** is kept in
the bank's **signing room** — you bring the document *to it*, the bank stamps it, and the key never
crosses the counter. **Purge protection is the rule that not even the branch manager can incinerate
the vault before the retention period ends.**

**The one thing:** ⭐ **a secret in Key Vault is still a secret.** The vault fixes storage, audit and
rotation — it does not change the credential class. **Key Vault plus managed identity is the real
win**, because it removes the "secret needed to fetch the secrets" regress entirely.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 10. Self-test

1. Difference between storing something as a key versus a secret?
2. Two access models — which is recommended, and name two concrete reasons?
3. What does purge protection prevent, and can it be turned off?
4. Which role lets an application read secret *values*?
5. Why does "Key Vault Reader" produce a confusing 403?
6. In the §5 pattern, what authenticates the application to Key Vault?
7. Why is a private endpoint alone insufficient?
8. Why is "it's in Key Vault" an incomplete answer?
9. What happens to an application that fetches a secret on every request?

<details>
<summary>Answers</summary>

1. A **key never leaves the vault** — operations are performed inside it. A **secret is returned in
   full** to anyone with read access.
2. **Azure RBAC.** It supports **inheritance/scope** and can be made **PIM eligible**; access
   policies are flat, per-vault, and cannot be PIM'd.
3. Permanent deletion before the retention period expires — **by anyone, including an owner**. ⚠ It
   **cannot be disabled** once enabled.
4. **Key Vault Secrets User.**
5. It grants **metadata only**, not secret values.
6. Its **managed identity** — there is no Key Vault credential anywhere, which removes the regress.
7. The **public endpoint stays live** unless public network access is disabled — and the Private DNS
   Zone must be linked or clients resolve publicly.
8. The vault protects **storage**; it does not change the fact that a **secret is still a secret**.
9. It hits **throttling limits** under load. Cache with a sensible refresh.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — the §5 pattern end to end: managed identity retrieves a secret with **no credential in
  code**. ✗ **Requires an Azure subscription.**
- **`break-fix/`** ⭐ — assign **Key Vault Reader** to a workload, capture the 403, then assign
  **Secrets User** and prove it works. Then create a vault **without purge protection**, delete and
  purge it, and demonstrate the keys are unrecoverable.
- **`security/`** — the §3 and §5 audits: permission model per vault, purge protection state,
  standing human access; public network access disabled.
- **`operations/`** — secret caching and rotation approach; diagnostic logs to Log Analytics with
  alerting on `SecretGet` anomalies.
- **`architecture-decisions/`** — ADR: RBAC over access policies, purge protection mandatory for
  key-holding vaults, and PIM for human data-plane access.
- **`customer-use-cases/`** — §8 answered against a real subscription.
