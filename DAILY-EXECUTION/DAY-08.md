# Day 8 — Migration Factory 2: Tenant-to-Tenant and Exchange Hybrid

> Standard set by [DAY-01](DAY-01.md). `✅ verified` / `⚠ check` convention applies.

**Outcome:** a design for the M&A scenario — two M365 tenants becoming one company — plus the
Exchange hybrid mechanics that sit underneath it.

**Why this is the highest-value day commercially:** tenant-to-tenant is **harder than
cross-platform** and pays accordingly. Google→M365 (Day 7) has a clean boundary. T2T has two
tenants running the *same* platform, with colliding identities, colliding domains, and executives
who expect to share a calendar on day one.

---

## 1. Day one is not migration day

The executive ask is *"make them one company."* The engineering answer is: **collaboration first,
consolidation later, and possibly never.**

**Deliver collaboration in week one without moving any data:**

| Capability | Mechanism | Depth |
|---|---|---|
| Cross-tenant access + **trust the other tenant's MFA** | Cross-tenant access settings | [Layer 2 §1.3](../30-identity-and-nhi/entra-users-and-groups/LAYER-2-DOMAIN-1-USER-IDENTITIES.md) |
| Users visible in each other's directory | Cross-tenant synchronization | Layer 2 §1.3 |
| Shared channels | B2B direct connect | Layer 2 §1.3 |
| Free/busy across tenants | Organization relationships | Exchange |

> **The trust settings are the whole trick.** Without them, your CA policy demands MFA and partner
> users must **re-register MFA in your tenant** — a second authenticator entry for the same human,
> thousands of times. With them, their home-tenant MFA satisfies your policy. On an acquisition
> that is the difference between day-one collaboration and a helpdesk queue.

**Then ask whether consolidation is actually required.** A multi-tenant organisation is a
legitimate end state. Consolidation costs a lot and is justified by licensing efficiency,
regulatory need, or genuine operational simplification — not by tidiness.

---

## 2. The collisions

| Collision | Why it bites | Resolution |
|---|---|---|
| **Same UPN** in both tenants | Cannot exist twice; someone gets renamed | Renaming policy decided **before** migration |
| **Same SMTP domain** | A domain lives in exactly one tenant at a time | Domain move is a **hard cutover with downtime** |
| **Duplicate source anchors** | Soft match misses; duplicate objects | Matching strategy first — [Layer 2 §1.4](../30-identity-and-nhi/entra-users-and-groups/LAYER-2-DOMAIN-1-USER-IDENTITIES.md) |
| Overlapping Teams/site names | Confusion, not breakage | Naming policy pre-migration |
| Conflicting CA / compliance policies | Users blocked post-move | Reconcile policy sets before, not after |

**The domain move is the schedule.** A verified domain must be **removed from the source tenant
before it can be verified in the target**, and removal requires that no object in the source still
references it. In practice: rename every user, group, and shared mailbox off the domain, then
remove, then verify at the target. **There is downtime, it must be scheduled, and it is the item
executives least expect.**

---

## 3. Exchange hybrid — the mechanics underneath

Hybrid is the bridge that makes cross-org mail behave as one organisation.

```powershell
Get-HybridConfiguration                                            # ⚠ check
Get-OrganizationRelationship | Format-Table Name,DomainNames,FreeBusyAccessEnabled   # ✅
Get-IntraOrganizationConnector | Format-Table Name,TargetAddressDomains,Enabled      # ✅
Get-MigrationEndpoint | Format-Table Identity,EndpointType,RemoteServer              # ✅
Get-MigrationBatch     | Format-Table Identity,Status,TotalCount,SyncedCount         # ✅
```

**The four things that break hybrid, in the order they break:**

1. **Autodiscover** — clients find their mailbox through it. Wrong DNS or a stale SCP and Outlook
   cannot connect even though the mailbox is fine.
2. **Certificates** — expiry breaks hybrid silently and completely. **Track expiry dates.**
3. **OAuth / IntraOrganizationConnector** — free/busy and cross-premises features depend on it.
4. **Throttling** — large batches slow to a crawl; the fix is smaller concurrent batches, not
   retrying harder.

**Cross-tenant mailbox migration** moves mailboxes between tenants while preserving the user
experience, using a migration application with consented permissions in both tenants. **Log which
permissions were consented and revoke them at project close** — the Day 6 NHI discipline applies
directly.

---

## 4. What migrates, what does not

**Set this expectation in writing, early.** It is the most common source of post-migration
disappointment.

| Generally migrates | Generally does **not** |
|---|---|
| Mailbox content, folders, calendar, contacts | **Teams chat history** (limited at best) |
| OneDrive files | Some permission fidelity and inheritance |
| SharePoint documents and libraries | Workflows, Power Automate flows |
| Basic group membership | Power Platform environments |
| | Retention/eDiscovery holds and their history |
| | Device compliance state — devices usually **re-enrol** |

> **Device re-enrolment is the hidden cost of T2T.** Every managed endpoint must be re-enrolled
> into the new tenant's MDM. At scale that is a logistics project with user downtime, not a
> checkbox — and it rarely appears in the first version of the plan.

---

## 5. Reconciliation and cutover

Same discipline as Day 7, with an added dimension: **you are reconciling against a tenant that is
still live and changing.** Freeze windows matter more.

Gates before the domain cutover:
- All users renamed off the domain in the source — **verify with a query, not a belief**
- Target tenant ready: licences assigned, CA policies aligned, mail routing tested
- Rollback plan documented **and its limits accepted in writing**

---

## 6. Failure exercises

| Cause it | Lesson |
|---|---|
| Try to verify a domain still present in the source tenant | Verification fails; read the exact error |
| Two users with the same UPN across tenants | Understand which fails and when |
| Let a hybrid certificate expire in the lab | Watch free/busy and mail flow break; note there is no obvious alert |
| Run a migration batch far too large | Observe throttling; measure the actual effective rate |
| Migrate a user without checking their delegates | Delegated access breaks; discovered by the executive, not by you |

---

## 7. Teach-back

1. **Why deliver collaboration before consolidation?** It is fast, low-risk, and often sufficient.
2. **What makes the domain move a hard cutover?** A domain lives in one tenant at a time and cannot
   be removed while referenced.
3. **Why do cross-tenant trust settings matter so much?** They prevent mass MFA re-registration.
4. **Name three things that don't migrate.** Teams chat history, workflows, device compliance state.
5. **What breaks hybrid first, and why is it silent?** Certificate expiry — no obvious alert.
6. **Why is T2T harder than cross-platform?** Identical namespaces collide; cross-platform ones
   don't.

---

## 8. Deliverables

| Facet | Artifact |
|---|---|
| `lab/` | Cross-tenant access + sync configured between two lab tenants; free/busy proven |
| `break-fix/` | The five failures with exact errors |
| `security/` | Migration app permissions in both tenants; CA policy reconciliation; revocation evidence |
| `operations/` | Domain cutover runbook with downtime window; reconciliation report; hypercare |
| `architecture-decisions/` | ADR: consolidate vs multi-tenant organisation, with the cost of each |
| `customer-use-cases/` | **M&A** — [Layer 7 §9](../80-customer-scenarios/LAYER-7-INDUSTRY-VERTICALS.md) |

**Cleanup:** remove cross-tenant access settings, delete synced guests, revoke migration app
consent in **both** tenants.
