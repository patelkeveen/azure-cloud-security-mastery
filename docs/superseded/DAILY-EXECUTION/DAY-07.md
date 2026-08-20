# Day 7 — Migration Factory 1: Google Workspace → Microsoft 365

> Standard set by [DAY-01](DAY-01.md). `✅ verified` / `⚠ check` convention applies.

**Outcome:** a complete, defensible migration design — identity, data, coexistence, cutover,
rollback, hypercare — for the most common cross-platform move in the market.

**"Factory" is the right word.** A one-off migration is a project. A factory is a repeatable
process with waves, gates, runbooks and reconciliation, so migration 400 goes like migration 4.

---

## 1. Sequence — identity first, always

```
1. Identity        ← foundation. Everything else depends on it
2. Domain          ← the routing decision, and the point of no return
3. Coexistence     ← how the two worlds talk while both are live
4. Data            ← mail, drive, sites, in waves
5. Endpoints/apps  ← clients, mobile, integrations
6. Cutover         ← MX flip
7. Decommission    ← only after reconciliation passes
```

**Never migrate data before identity is stable.** Content migrated to an account that later gets
recreated is content you migrate twice — and the second pass is the one you do at your own cost.

---

## 2. Identity design

**The matching key.** Decide the immutable attribute that ties a Google account to an M365 account
— usually primary email, sometimes an HR employee ID. Write it down before touching anything.

**Collisions to resolve before day one:** users existing in both, differing UPN vs primary SMTP,
aliases, shared/delegated mailboxes, resource accounts, and service accounts nobody owns.

```powershell
# Baseline the target before you add anything
Get-MgUser -All -Property UserPrincipalName,Mail,ProxyAddresses,UserType |
    Export-Csv .\target-baseline.csv -NoTypeInformation      # ✅
```

**Password strategy.** Choose one deliberately:

| Option | Trade-off |
|---|---|
| Reset all, distribute via TAP | Cleanest; needs a comms plan and a helpdesk surge |
| Google as IdP during transition | Least user disruption; adds federation complexity |
| Provision from HR/IdM | Best at scale; needs that system to exist |

**Set MFA up front, not after.** Migrating users into a tenant with no Conditional Access and
"tightening later" means the tightening never happens, or happens as an outage. Day 9 covers the
policy set; the decision belongs here. See
[Layer 3](../../../30-identity-and-nhi/conditional-access/LAYER-3-DOMAIN-2-AUTH-AND-ACCESS.md).

---

## 3. Domain and the point of no return

**The MX record is the cutover.** Before it flips, Google is authoritative for mail. After, M365
is. There is no partial state — mail follows MX.

Pre-cutover, in this order:
1. Verify the domain in M365 (TXT), **without** changing MX
2. Set the domain to **`InternalRelay`** if unmigrated users must still receive mail
   ([Day 2](DAY-02.md) — `Authoritative` will NDR them)
3. Pre-stage SPF to include both platforms during coexistence
4. **Lower MX TTL to 300 seconds at least 48 hours before cutover** — this is the single most
   commonly forgotten step, and without it a rollback takes hours instead of minutes

```powershell
Resolve-DnsName yourdomain.com -Type MX     # ✅ verify TTL has actually propagated
```

---

## 4. Coexistence — the hard part

While both platforms are live, users expect these to work across the boundary:

| Capability | Reality |
|---|---|
| **Mail routing** | Solvable — dual delivery or forwarding, driven by MX + domain type |
| **Free/busy** | Hardest. Cross-platform calendar lookup is limited; set expectations early |
| Contacts / GAL | Sync a directory of the not-yet-migrated so people are findable |
| Drive ↔ SharePoint | Generally not live-shared; migrate together or accept a gap |
| Chat | Google Chat and Teams do not federate. Plan a hard switch date |

> **Tell the customer the truth about free/busy early.** It is the number-one migration
> complaint, it is a platform limitation rather than a configuration error, and discovering it at
> week six destroys trust. Say it in the design review.

**Minimise coexistence duration.** Every week of dual-running is a week of double administration,
double licensing and confused users. Short waves, tight schedule.

---

## 5. Wave planning

**Wave by dependency, not by alphabet.** Move people who work together, together — otherwise their
shared calendars and files straddle the boundary and both halves degrade.

Sequence: **Pilot (IT, ~5)** → **Early adopters (~25, one friendly department)** → **Production
waves** → **Long tail** (executives, edge cases, the person on sabbatical).

Each wave has a **gate**: reconciliation passed, error rate below threshold, helpdesk volume
acceptable. **A gate you never fail is not a gate** — define the number that stops the next wave
before you start.

Per wave: pre-checks → notify (T-7, T-1, T-0) → migrate → delta → validate → reconcile → confirm.

---

## 6. Reconciliation — proof, not vibes

The question at project close is *"did everything arrive?"* Answer it with numbers.

| Check | Method |
|---|---|
| Mailbox item count | Source count vs `Get-MailboxStatistics` target count, per user |
| Data volume | Source GB vs target GB, with an explained tolerance |
| Folder structure | Spot-check nested hierarchy depth and naming |
| Permissions | Sample delegated access and shared calendars |
| Drive → OneDrive | File count and total size per user |
| Sites | Library item counts, versions retained, permission groups |

```powershell
Get-MailboxStatistics -Identity user@domain.com |
    Select-Object DisplayName,ItemCount,TotalItemSize      # ✅
```

**Define an acceptable variance in advance and justify it.** Counts rarely match exactly — system
folders, duplicates, and filtered item types all shift the number. An unexplained variance is a
defect; an explained one is a documented decision.

---

## 7. Cutover and rollback

**Cutover day runbook** — one page, timestamped, with a named owner per step, an explicit go/no-go,
and a rollback trigger stated *before* you start.

**Rollback is MX.** Point it back to Google, and mail flows there again — which is precisely why
the TTL had to be lowered in advance. **What does not roll back is data written to M365 after
cutover.** That gap must be stated in the plan and accepted by the customer in writing, because it
is the real cost of a rollback and nobody wants to hear it for the first time at 11pm.

**Hypercare:** 1–2 weeks of elevated support, a daily issue log, a named escalation path, and a
defined exit criterion. "Hypercare ends when X" — otherwise it never ends.

---

## 8. Failure exercises

| Cause it | Lesson |
|---|---|
| Flip MX with TTL still at 3600 | Feel how long rollback actually takes |
| Leave the domain `Authoritative` with unmigrated users | NDRs for real people mid-migration |
| Migrate a user whose manager is not yet migrated | Broken delegation, split calendars |
| Skip the delta pass before cutover | Data written after the last pass is silently lost |
| Migrate data before identity is final | Recreate the account; migrate everything twice |

---

## 9. Teach-back

1. **Why identity before data?** Content follows the account; an unstable account means migrating
   twice.
2. **What actually is cutover?** The MX flip — the moment authority for mail changes.
3. **Why lower TTL in advance?** Rollback speed is bounded by DNS propagation.
4. **Why is free/busy the hardest coexistence problem?** Cross-platform calendar lookup is a
   platform limitation, not a setting.
5. **Why wave by dependency?** Shared calendars and files degrade when collaborators straddle the
   boundary.
6. **What does rollback not recover?** Anything written to the target after cutover.

---

## 10. Deliverables

| Facet | Artifact |
|---|---|
| `lab/` | Pilot migration of ~5 accounts, end to end, with timings |
| `break-fix/` | The five failures with exact symptoms and remediation |
| `security/` | Permissions granted to the migration tool; MFA/CA posture at go-live; revocation plan |
| `operations/` | Cutover runbook, comms plan, hypercare plan, reconciliation report |
| `architecture-decisions/` | HLD + LLD; ADRs for password strategy, coexistence duration, tooling |
| `customer-use-cases/` | Education (Workspace-heavy) vs SaaS (fast, technical users) — [Layer 7](../../../80-customer-scenarios/LAYER-7-INDUSTRY-VERTICALS.md) |

**Cleanup:** revoke migration tool consent in both tenants, remove migration service accounts,
restore DNS TTLs, delete pilot data.
