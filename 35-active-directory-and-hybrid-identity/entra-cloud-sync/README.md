# Entra Cloud Sync

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Feature table verified against Microsoft Learn **2026-08-10** (doc updated 2026-06-15).
> Compare with [`../entra-connect-sync/`](../entra-connect-sync/) — read that one first.

---

## 1. What it is

A **lightweight provisioning agent** on-premises whose configuration lives entirely in Entra ID.
It does the same job as Connect Sync — users, groups and contacts from AD into Entra ID — with the
brain moved to the cloud and only the hands left on your server.

**Microsoft's stated strategic direction: Cloud Sync replaces Connect Sync.** New synchronization
features are being built on Cloud Sync only.

---

## 2. Why it exists

Connect Sync's design has three structural problems that no version could fix:

| Problem | Consequence |
|---|---|
| **Configuration lives on the server** | Managing sync requires VPN and server access. Configuration drifts and nobody can diff it. |
| **One active server** | A **single point of failure**. If it dies, synchronization stops until someone rebuilds it — and the staging server only helps if failover was actually tested. |
| **Heavyweight install** | Full SQL, a real server, manual patching, maintenance windows. |

Cloud Sync inverts all three: configuration is a cloud object, **multiple agents run active-active**
with automatic failover, and agents **self-update** from Microsoft.

> "We have a staging server" is not high availability — it is a manual failover you have probably
> never rehearsed. **Multiple active Cloud Sync agents are the first genuine HA** in this space.

---

## 3. How it works underneath

```
   ┌──────────────────────── ENTRA ID (the brain) ────────────────────────┐
   │  Sync configuration · scoping filters · attribute mappings           │
   │  stored as a cloud object, edited in the Entra admin center          │
   └────────────────────────────────┬─────────────────────────────────────┘
                                    │  outbound HTTPS 443 only
                     ┌──────────────┼──────────────┐
                     ▼              ▼              ▼
              ┌───────────┐  ┌───────────┐  ┌───────────┐
              │  Agent 1  │  │  Agent 2  │  │  Agent 3  │   active-active
              └─────┬─────┘  └─────┬─────┘  └─────┬─────┘   auto-failover
                    └──────────────┼──────────────┘          self-updating
                                   ▼
                        ON-PREM ACTIVE DIRECTORY
```

**No inbound firewall rule.** Agents make outbound 443 connections only — the same pattern as the
Application Proxy connector. This removes an entire class of security review objection.

**No metaverse.** This is the deep architectural difference. Connect Sync assembles identities in
an intermediate model (see [`../entra-connect-sync/`](../entra-connect-sync/) §3). Cloud Sync does
not, which is precisely *why* it supports **disconnected forests** and Connect Sync does not — with
no shared metaverse to reconcile into, each forest is simply an independent source.

It is also why it cannot **merge attributes from multiple domains** or resolve **cross-forest
references**. The same design choice buys one capability and costs the other. Understanding this
trade-off — rather than memorising the table — is what the interview question is testing.

---

## 4. The comparison table

✅ Verified 2026-08-10. **This is the reference — most blog comparisons are years stale.**

| Capability | Connect Sync | Cloud Sync | Note |
|---|:---:|:---:|---|
| Users, groups, contacts | ✓ | ✓ | Full parity |
| Single / multiple **connected** forests | ✓ | ✓ | Parity |
| **Disconnected forest support** | ✗ | **✓** | M&A without forest consolidation |
| **Device sync (Hybrid Entra Join)** | **✓** | ✗ | ⭐ the usual blocker |
| **Multiple active sync instances** | ✗ | **✓** | Real HA |
| Scale per domain | Unlimited | **150,000 objects** | ⭐ hard ceiling |
| Large group support | 250,000 members | **50,000 members** | ⭐ hard ceiling |
| Password hash sync | ✓ | ✓ | Parity |
| Password writeback (SSPR) | ✓ | ✓ | Parity |
| **Exchange hybrid attributes** | ✓ | **✓** | ⭐ **both** — widely misreported |
| Directory extensions (1–15), custom AD attributes | ✓ | ✓ | Parity |
| PTA configuration | ✓ | ✗ | PTA keeps working; configured separately |
| AD FS integration setup | ✓ | ✗ | Separate tooling |
| **Advanced sync rules** | **✓** | ✗ | Cloud Sync has an expression builder, not the rule engine |
| OU-based filtering | ✓ | ✓ | Parity |
| Attribute-based filtering | ✓ | **Limited** | Check before committing |
| **Device writeback** | ✓ | ✗ | Discontinued in favour of **Cloud Kerberos Trust** |
| Group writeback V1 | ✓ | ✓ | Parity |
| **Group provisioning to AD** | ✗ | **✓** | Cloud Sync only |
| User provisioning to AD | ✗ | ✗ | Neither |
| **Cross-forest references** | **✓** | ✗ | See §3 |
| **Merge attributes from multiple domains** | **✓** | ✗ | See §3 |
| **Reconciliation** (out-of-band correction) | **✓** | ✗ | Matters for large messy estates |
| **On-demand provisioning** | ✗ | **✓** | ⭐ test one user instantly — see §5 |
| Cloud configuration management | ✗ | ✓ | The headline benefit |
| Seamless SSO | ✓ | ✓ | Parity |
| US Government cloud | ✓ | ✓ | Parity |

**Six rows decide almost every real engagement:** device sync, the two scale ceilings, advanced
sync rules, cross-forest references, and reconciliation. Everything else is parity or rarely
binding.

---

## 5. Worked example — the readiness assessment

A customer asks "can we move to Cloud Sync?" Do not answer from the table. Measure first.

**Step 1 — objects per domain** (ceiling: 150,000):

```powershell
Get-ADDomain | ForEach-Object {
  [pscustomobject]@{
    Domain  = $_.DNSRoot
    Objects = (Get-ADObject -Filter * -SearchBase $_.DistinguishedName -ResultSetSize $null).Count
  }
}
```

```
Domain              Objects
------              -------
corp.contoso.com      84213      <-- under 150,000, OK
```

**Step 2 — any group over 50,000 members?**

```powershell
Get-ADGroup -Filter * -Properties member |
  Select-Object Name, @{n='Members';e={($_.member).Count}} |
  Where-Object Members -gt 50000 | Sort-Object Members -Descending
```

Empty output is the answer you want. One row here is a blocker.

**Step 3 — is Hybrid Entra Join in use?** The single most common disqualifier:

```powershell
Get-MgDevice -Filter "trustType eq 'ServerAd'" -CountVariable c -ConsistencyLevel eventual -Top 1
$c
```

Any non-zero count means devices are hybrid-joined. That is not a hard stop — the modern answer is
**Cloud Kerberos Trust** — but it converts a sync migration into a device project, which is a
different budget and a different conversation. Say so early.

**Step 4 — advanced sync rules?** Any custom rule is a redesign, not a migration:

```powershell
Get-ADSyncRule | Where-Object { -not $_.IsStandardRule } |
  Select-Object Name, Direction, Precedence
```

**Reading the result:** all four clear → *ready for immediate migration*. Device sync only →
*near-term, gated on the Cloud Kerberos Trust project*. Scale or custom rules → *evaluate on the
business planning cycle*, and be honest that it may be years.

---

## 6. On-demand provisioning — the feature that changes daily work

Cloud Sync can provision **one named user immediately** and show you the attribute-by-attribute
result, without waiting for a cycle.

In Connect Sync, testing a scoping change means: edit, run a delta, wait, inspect, repeat — with a
30-minute floor and blast radius across the whole directory. On-demand provisioning turns that into
seconds, scoped to one object.

> **This is the single best argument for Cloud Sync in a change-averse organisation.** You can
> demonstrate the result of a filter change on one user before applying it to 84,000.

Available in the Entra admin center under the provisioning configuration → **Provision on demand**.

---

## 7. When and where

**Default to Cloud Sync in 2026 unless a specific row in §4 blocks it.** Leading with Connect Sync
out of habit signals someone who stopped reading in 2019.

They also **coexist** — a supported and underused pattern:

```
  Connect Sync  ──►  the main forest (needs device sync)
  Cloud Sync    ──►  the acquired, disconnected forest
                     both into the SAME tenant
```

That is often the *correct* answer during an acquisition, and it is not what most people propose.

**⚠ check — two timing items to verify at source before quoting to a customer:**

- Reports indicate **all customers must upgrade Connect Sync to 2.5.79.0 or later by
  30 September 2026**, and that Microsoft began notifying customers of individual transition
  timelines in **July 2026** via the M365 Message Center, Connect Health and email.
- I verified the feature table above at source; **I did not verify these two dates at source.**
  Confirm against Microsoft Learn and the Message Center before putting them in a customer plan.
  If accurate, the upgrade deadline is close and belongs at the top of any Connect Sync estate's
  risk register.

---

## 8. What breaks

**The 150,000 ceiling is per *domain*, not per tenant.** A 400,000-object tenant made of four
120,000-object domains is fine. Reading it as a tenant limit rules out migrations that would work.

**The 50,000-member group limit bites in education and retail** — "All Students", "All Store
Staff". One oversized group blocks the whole migration until it is restructured, and restructuring
a group that drives licensing and access is a project of its own.

**Device writeback is gone, not moved.** Anyone looking for it in Cloud Sync is solving the wrong
problem: the answer is **Cloud Kerberos Trust**, which removes the need for it. Time is regularly
wasted searching for a feature that was deliberately retired.

**PTA and Seamless SSO keep working after migration** — they are simply configured elsewhere. This
causes real hesitation in customers who read the `✗` as "will break". It does not break; it moves.

**No reconciliation.** Connect Sync can correct out-of-band drift. Cloud Sync cannot. On a large
estate with a long history of manual cloud edits, that gap is the real migration risk, and it is
the row most people skip past.

---

## 9. Customer discovery questions

1. Objects **per domain**, and largest group membership? *(§5 steps 1–2 — measure, don't ask.)*
2. Hybrid Entra Join in use? Any appetite for Cloud Kerberos Trust?
3. Any non-standard sync rules? *(§5 step 4. Each one is redesign work.)*
4. Disconnected forests now, or an acquisition in flight? *(Flips the recommendation to Cloud Sync
   outright.)*
5. Who can currently reach the Connect server, and how? *(Often the honest answer is "one person,
   who left." Cloud-managed configuration solves an organisational problem, not just a technical one.)*
6. Has staging-server failover ever been **tested**?
7. What Connect Sync version is running, and against the §7 deadline — how long would an upgrade take?

---

## 10. Remember it

**Hook — "No metaverse, no merge."** One design choice explains both the capability and the gap.

**Analogy — independent translators versus one shared notebook.** Connect Sync reconciles everything
into a single master notebook, so it can merge attributes across domains and resolve cross-forest
references — but every source must fit that one notebook. Cloud Sync gives each forest its own
translator: disconnected forests work fine, and nothing can be cross-referenced.

**The one thing:** **150,000 objects is per domain, not per tenant.** Reading it as a tenant limit
rules out migrations that would work.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 11. Self-test

1. Why does Cloud Sync support disconnected forests when Connect Sync cannot?
2. Two hard numeric ceilings, and are they per tenant or per domain?
3. Customer uses Hybrid Entra Join. Can they migrate, and what does it turn into?
4. Which is true for Exchange hybrid attributes — Connect only, Cloud only, or both?
5. What replaced device writeback, and why is that not a downgrade?
6. Why is on-demand provisioning more than a convenience?
7. When is running both tools simultaneously the right answer?
8. Which capability gap is riskiest for a large estate with years of manual cloud edits?

<details>
<summary>Answers</summary>

1. **No metaverse.** Nothing has to reconcile into a shared intermediate model, so each forest is
   an independent source. The same design costs cross-forest references and multi-domain attribute merge.
2. **150,000 objects per domain** and **50,000 members per group** — the first is **per domain**,
   not per tenant.
3. Not immediately. Device sync is Connect-only. It becomes a **Cloud Kerberos Trust** project —
   different budget, different timeline.
4. **Both.** ✅ verified. Widely misreported as Connect-only.
5. **Cloud Kerberos Trust**, which removes the need for device writeback rather than replacing it.
6. It lets you validate a scoping change on **one user in seconds** instead of a 30-minute
   full-directory cycle — which is what makes change-averse organisations willing to proceed.
7. Coexistence: Connect Sync on the main forest (device sync), Cloud Sync on a disconnected
   acquired forest, both into one tenant.
8. **No reconciliation** — no out-of-band correction of drift.

</details>

---

## 12. Evidence this topic needs

- **`lab/`** — install a provisioning agent, scope one OU, use **provision on demand** on a single
  user and capture the attribute-by-attribute result. ✗ unrunnable without an AD instance.
- **`break-fix/`** — exceed the 50,000-member group limit deliberately and capture the failure;
  stop one agent and prove another takes over with no gap.
- **`security/`** — agent service account permissions; proof that only outbound 443 is required;
  who holds sync-configuration rights in the cloud now that it is no longer a server ACL.
- **`operations/`** — the §5 readiness assessment run against a real domain, with output.
- **`architecture-decisions/`** — ADR: Cloud Sync vs Connect Sync vs coexistence, naming the
  specific §4 row that decides it.
- **`customer-use-cases/`** — an M&A scenario: acquired disconnected forest onto Cloud Sync while
  the main forest stays on Connect Sync.
