# Key Vault

> **Concept facet.** SC-500 scope — see
> [Layer 6 §5](../../60-ai-and-secure-ai/ai-agent-identity/LAYER-6-SC500-BRIDGE-AI-SECURITY.md).
> Related: [`../secrets-and-certificates/`](../secrets-and-certificates/),
> [`../managed-identities/`](../managed-identities/).

## What it is

A managed store for **secrets** (strings), **keys** (cryptographic material that never leaves), and
**certificates** (with lifecycle automation). It exists so applications stop carrying credentials in
configuration files.

## Why it exists, stated precisely

Not "to store secrets" — you can store a secret in a file. It exists so that:

1. The secret is **never in source control or a config file**
2. Access is **authenticated by identity** rather than by possession of the file
3. Every access is **logged**
4. **Keys can be used without being retrieved** — sign and encrypt operations happen inside the
   vault, so the private key is never exposed to the application at all

Point 4 is the one people miss, and it is the difference between a vault and a password manager.

## The pattern that makes it work

```
Azure resource  →  [managed identity]  →  Key Vault  →  secret
                    no credential            RBAC
```

**A secret retrieved using a credential you had to store somewhere has solved nothing.** The vault
is only a real control when the retrieving identity is a **managed identity** — then there is no
bootstrapping credential at all. See [`../managed-identities/`](../managed-identities/).

## Two authorisation models — pick one and be consistent

| | Access policies (legacy) | **Azure RBAC** |
|---|---|---|
| Granularity | Per-vault, per-principal, per-operation | Role-based, inheritable from higher scopes |
| Scope | Vault only | Management group → subscription → RG → **vault → individual secret** |
| Recommended | No | **Yes** |

**Mixing them causes confusion that looks like a bug.** Decide per vault and document it.

> **The control-plane / data-plane trap, in its sharpest form:** `Owner` on the vault lets you
> **delete the vault** (control plane) but does **not**, under RBAC mode, let you **read a secret**
> (data plane). Engineers lose hours here. Being able to explain it instantly is a good signal.

## Protection features that matter

- **Soft delete** — deleted vaults and objects are recoverable for a retention period. On by default
  now; verify.
- **Purge protection** — prevents permanent deletion even by an administrator during the retention
  window. **Irreversible once enabled** — that is the point, and it is why it needs a deliberate
  decision rather than a checkbox.
- **Firewall / private endpoint** — a vault reachable from the public internet is authenticated but
  not isolated.
- **Defender for Key Vault** — anomalous access detection.

## Rotation

Secrets should rotate. The mature pattern is an **event-driven rotation function** triggered by the
near-expiry event, which rotates at the source system and writes the new version to the vault.
Applications reference the secret **without a version** so they pick up the new one.

**The immature pattern — a calendar reminder — fails at exactly the wrong moment**, which is the
same failure mode as app registration secrets.

## The traps

1. **Storing the credential that reads the vault** somewhere else. Use managed identity.
2. **Confusing control-plane and data-plane rights.**
3. **Hardcoding a versioned secret URI**, so rotation silently breaks the app.
4. **No firewall.** Authentication is not isolation.
5. **Enabling purge protection without understanding it is permanent** for the vault's lifetime.

## Evidence this topic needs

- `lab/` — vault with RBAC; VM with a system-assigned managed identity retrieves a secret **with no
  credential in code**.
- `break-fix/` — grant `Owner` and attempt to read a secret; observe the data-plane denial.
- `security/` — firewall and private endpoint; Defender for Key Vault; access logging to Log
  Analytics.
- `operations/` — rotation runbook; soft-delete recovery procedure.
