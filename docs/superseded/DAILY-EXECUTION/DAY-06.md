# Day 6 — Migration Tooling Ecosystem

> Standard set by [DAY-01](DAY-01.md). `✅ verified` / `⚠ check` convention applies.

**Outcome:** a defensible tool-selection method, and an honest register of what you have actually
touched versus what you have only read about.

**⚠ The integrity rule for this day.** Vendor capabilities change quarterly and every vendor's
comparison page is marketing. **This file deliberately contains no feature matrix**, because any
matrix I wrote today would be stale and unverified — and a stale matrix in a portfolio is worse
than none, since it will be quoted at you in an interview. What follows is the *method* for
building your own, plus the evidence standard for claiming experience.

---

## 1. The claim ladder — say exactly where you are

Most candidates damage themselves by overclaiming. Use these words precisely:

| Level | Means | You may say |
|---|---|---|
| **Researched** | Read vendor + independent docs | "I understand the model and its limits" |
| **Trialled** | Ran a trial with test data | "I have run a pilot migration with it" |
| **Delivered** | Used in a real engagement | "I have migrated *n* mailboxes with it" |

**Never let the ladder slip upward in a CV.** An interviewer who has used the tool will find the
gap in two questions, and everything else you said becomes suspect. Saying *"researched, not yet
delivered — here's the pilot I ran"* is stronger than a vague claim, because it is checkable.

---

## 2. The tool landscape — categories, not rankings

| Category | Examples | When it's the answer |
|---|---|---|
| **Microsoft native** | Exchange hybrid / cutover / staged / IMAP, SharePoint Migration Tool, Mover, cross-tenant mailbox migration | Budget is zero; scenario is mainstream; timeline is relaxed |
| **Full-fidelity commercial** | BitTitan MigrationWiz, Quest On Demand, Cloudiway, AvePoint, ShareGate, Xillio | Complex source, tenant-to-tenant, permissions fidelity, coexistence, scale, reporting |

**The honest generalisation:** native tools are free and adequate for the common path; commercial
tools are bought for **coexistence, fidelity, reporting and support** — and the last one is often
what the customer is really paying for, because someone else answers the phone at 3am on cutover
weekend.

---

## 3. Build your own selection matrix

Score each candidate against the customer's constraints. **These dimensions do not go stale**, even
though vendor scores do:

| Dimension | The question that reveals the truth |
|---|---|
| Source/target support | Does it support this *exact* source version and target? |
| **Fidelity** | Permissions, versions, metadata, links, timestamps — what is lost? |
| **Coexistence** | Free/busy, mail routing, cross-platform sharing *during* the move |
| **Throughput** | Realistic per-user and per-TB rates — **under throttling**, not on the datasheet |
| **Delta/incremental** | Can it re-sync changes after the first pass? Non-negotiable at scale |
| Reporting | Can you prove completion to an auditor? |
| Rollback | What happens when wave 3 fails? |
| Licensing model | Per-user, per-GB, per-tenant, term? |
| Support | Hours, escalation, named engineer? |
| **Security** | What permissions does it demand in *both* tenants? |

> **The dimension juniors forget: what permissions does the tool require?** Most migration tools
> ask for **application permissions** in both tenants — which, per
> [Layer 4 §5](../../../30-identity-and-nhi/service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md),
> have **no intersection with any user's rights**. Granting `Mail.ReadWrite` as an application
> permission gives that vendor's service principal access to every mailbox in the organisation.
>
> That is often necessary and legitimate. It must still be **consented deliberately, documented,
> time-bounded, and revoked at project close.** Track it in the NHI register (Day 9). Leaving a
> migration vendor's app registration fully consented two years after the project is a real and
> common finding.

---

## 4. Throughput reality — the number that sinks projects

**Throttling is imposed by the source and target services, not by the tool.** Buying a bigger
migration tier does not raise Microsoft's per-mailbox ceiling.

Plan with:
- A **measured** pilot rate, not a datasheet rate
- Item count as well as byte volume (Day 5)
- Concurrency limits per tenant
- A margin for the long tail — the last 5% of users always take disproportionately long

**Then quote a range, never a single date.** "Six to nine weeks with these assumptions" is
professional. "Six weeks" is a hostage you have given.

---

## 5. Trials — the only way up the claim ladder

Most vendors offer time-limited trials. This is how you legitimately move from *researched* to
*trialled*.

**Pilot protocol** — do it identically for each tool so the comparison means something:
1. Source and target: your own lab tenants only. **Never a customer tenant.**
2. Fixed dataset: ~5 mailboxes, one SharePoint site, one OneDrive, with **deliberately awkward**
   content — nested permissions, versioned files, long paths, unusual characters, a large file, a
   shared calendar.
3. Record wall-clock time, throughput, error count, and **what was silently lost**.
4. Attempt a delta sync after changing source data.
5. Attempt a rollback.
6. **Record the permissions it demanded**, then revoke them.

> **Fidelity loss is what separates a good report from a good engineer.** Anyone can report "it
> completed." Reporting "it completed, but item-level permissions on nested folders were flattened
> and modified-by metadata was reset to the migration account" is the finding that saves a customer
> a post-migration crisis.

---

## 6. Failure exercises

| Cause it | Lesson |
|---|---|
| Migrate a file with a path longer than the target supports | Silent skip or truncation — find where it was *reported*, if at all |
| Migrate content with unique/broken permission inheritance | Observe whether fidelity survives |
| Interrupt a migration mid-pass, then resume | Does it resume, restart, or duplicate? |
| Run a delta after modifying both source and target | Which wins? Is there conflict reporting? |
| Revoke the tool's consent mid-migration | See exactly which permission it actually needed |

**The last one is the most instructive** — vendors ask for broad permissions "to be safe," and this
tells you the real minimum you could have negotiated.

---

## 7. Teach-back

1. **Why does buying a bigger tool tier not fix throughput?** Throttling is enforced by the source
   and target services.
2. **What is the real reason customers buy commercial tools?** Coexistence, fidelity, reporting —
   and someone to call at 3am.
3. **Why are migration tool permissions a security finding?** Application permissions have no
   user-rights intersection and are frequently never revoked.
4. **Why quote a range?** Because the long tail and throttling are variable, and a single date
   becomes a commitment you did not have the data to make.
5. **What separates "researched" from "trialled"?** A pilot with recorded evidence, including what
   was lost.
6. **What is the most valuable thing to report from a pilot?** The fidelity loss nobody asked about.

---

## 8. Deliverables

| Facet | Artifact |
|---|---|
| `lab/` | Pilot results per tool: time, throughput, errors, fidelity loss, delta and rollback behaviour |
| `break-fix/` | The five exercises with exact tool output |
| `security/` | Permissions demanded by each tool; consent record; **revocation evidence** |
| `operations/` | Pilot protocol; wave-planning template; throughput assumptions with sources |
| `architecture-decisions/` | ADR: tool chosen for a stated scenario, alternatives and why rejected |
| `customer-use-cases/` | Budget-constrained nonprofit vs regulated finance — [Layer 7](../../../80-customer-scenarios/LAYER-7-INDUSTRY-VERTICALS.md) |

**Maintain a `limitations register`** — one row per tool per limitation discovered, dated. It ages
into the most valuable document you own, because it is the one thing no vendor will write for you.

**Cleanup:** revoke every trial's consent, delete its app registrations and service accounts, and
remove pilot data from both tenants.
