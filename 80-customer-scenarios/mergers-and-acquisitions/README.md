# Mergers and Acquisitions

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **Boundary:** the **mechanics** of moving between tenants are
> [`../../45-m365-migration-engineering/tenant-to-tenant/`](../../45-m365-migration-engineering/tenant-to-tenant/).
> [`../LAYER-7-INDUSTRY-VERTICALS.md`](../LAYER-7-INDUSTRY-VERTICALS.md) §9 is the brief.
> ⭐ **This topic is the business scenario: Day 1, the deal clock, and deciding whether to migrate at
> all.**

---

## 1. What it is

Identity work driven by a corporate transaction — an acquisition, a merger, a divestiture or a
carve-out. It is defined by two things that no other engagement has: ⭐ **a legally fixed date you
cannot move**, and ⭐ **a scope that is confidential until shortly before that date.**

⭐ **The technical work is ordinary. The constraints are not.**

---

## 2. Why it is different

| Ordinary project | ⭐ M&A |
|---|---|
| Deadline negotiable | ⭐ **completion date is in a legal agreement** |
| Requirements gathered openly | ⭐ **under NDA; ⭐ you may not talk to the users** |
| One IT organisation | ⭐ **two, ⭐ one of which may be hostile to the outcome** |
| Discovery before design | ⭐ **you may see the other tenant days before Day 1** |
| Success = migrated | ⭐ **success = ⭐ people can email each other on Day 1** |
| No external clock | ⭐ **a TSA with an expiry and a per-month cost** |

⭐ **The Transitional Services Agreement is the constraint that makes divestitures urgent.** ⭐ **The
seller agrees to provide IT services to the divested business for a fixed period — often 6–18
months — usually at a price that rises**, and when it expires the divested entity must be standing
alone. ⭐ **The TSA end date, not the technical scope, is what sets the plan.**

---

## 3. How it works underneath — Day 1 versus Day 100

⭐ **The most valuable distinction in this topic, and the one that stops teams over-committing:**

```
   ⭐ DAY 1  ⭐ "can they work together?"     ← ⭐ the legal/PR deadline
   ─────────────────────────────────────────────────────────
   ▸ ⭐ email each other and RESOLVE in the address book
   ▸ see free/busy, book meetings
   ▸ ⭐ share a file without emailing an attachment
   ▸ ⭐ chat / Teams federation
   ⭐ ACHIEVED WITH: ⭐ cross-tenant sync + B2B + external access settings
   ⭐ NO MIGRATION REQUIRED. ⭐ Weeks, not months.

   ⭐ DAY 100+  ⭐ "are they one organisation?"  ← ⭐ the real project
   ─────────────────────────────────────────────────────────
   ▸ one tenant, one domain, one identity per person
   ▸ mailboxes, files, Teams history moved
   ⭐ ACHIEVED WITH: ⭐ full tenant-to-tenant migration
   ⭐ Months. ⭐ And it may never be justified.
```

⭐ **Separating these two is the highest-value contribution you can make in the first meeting.**
⭐ **Executives ask for "integration by Day 1" and mean the first list**; a team that hears "migrate
1,400 mailboxes in three weeks" will either fail or refuse. ⭐ **Reframing the ask correctly is what
turns an impossible deadline into a deliverable one.**

⭐ **And the genuinely senior position: sometimes Day 100 never comes, and that is fine.**
⭐ **Two tenants with cross-tenant synchronisation is a supported permanent architecture** — cheaper,
lower-risk, and appropriate when the acquired business will keep operating independently.
⭐ **Recommending it costs you migration revenue and buys you the customer's trust.**

---

## 4. Worked example — the Day 1 minimum, built

⭐ **Four things, in this order. Each is independently verifiable.**

```
① ⭐ ADDRESS BOOK       users of each org resolve in the other's GAL
   → ⭐ Entra cross-tenant synchronization (⭐ B2B members/guests)
   → ⭐ requires Entra ID P1 in both tenants

② MAIL FLOW           internal-looking mail between the two
   → ⭐ organization relationship + connectors, ⭐ NOT via the internet

③ ⭐ FREE/BUSY          calendar lookups across the boundary
   → ⭐ organization relationship, ⭐ REAL-TIME (⭐ see the coexistence topic)

④ ⭐ COLLABORATION      Teams federation + external access + file sharing
   → ⭐ cross-tenant access settings: ⭐ inbound AND outbound, BOTH sides
```

⭐ **Step ④ catches people out because cross-tenant access settings are directional and must be
configured in both tenants.** ⭐ **Tenant A allowing inbound from B does nothing until B allows
outbound to A** — and the symptom is a silent failure that looks like a licensing problem.

**Configuring one direction, with the partner named explicitly:**

```powershell
# ⭐ In the ACQUIRING tenant: trust the target tenant's MFA and device claims
# ⭐ so acquired staff are not double-prompted on every access.
Update-MgPolicyCrossTenantAccessPolicyPartner -CrossTenantAccessPolicyConfigurationPartnerTenantId $targetTenantId `
  -InboundTrust @{
      isMfaAccepted                     = $true    # ⭐ trust their MFA
      isCompliantDeviceAccepted         = $true
      isHybridAzureADJoinedDeviceAccepted = $true }
```

⭐ **`isMfaAccepted = $true` is a real security decision, not a convenience toggle.** ⭐ **You are
accepting another organisation's authentication assurance as equivalent to your own** — which is
reasonable when the deal has closed and their standards are known, and unreasonable during due
diligence. ⭐ **Say which, in writing, and make the customer own it.**

**Verify Day 1 actually works — ⭐ four checks, one per capability:**

```powershell
# ① Do their users resolve here?
Get-MgUser -Filter "userType eq 'Guest'" -Top 3 |
  Select-Object DisplayName, UserPrincipalName, ExternalUserState
```

```
DisplayName    UserPrincipalName                                ExternalUserState
Aisha Khan     a.khan_target.com#EXT#@acquirer.onmicrosoft.com  Accepted
```

```powershell
# ③ Free/busy across the boundary
Test-OrganizationRelationship -Identity 'TargetCo' -UserIdentity user@acquirer.com
```

```
Identity  Result   Message
TargetCo  Success  Test steps completed successfully
```

⭐ **`ExternalUserState: Accepted` and a free/busy `Success` are the two pieces of evidence that
Day 1 is real** — and they are what you show the integration steering committee instead of a status
percentage.

---

## 5. Divestiture — ⭐ harder than acquisition, and less discussed

⭐ **Acquisitions add; divestitures must *separate*, and separation is a harder problem.**

| Question | ⭐ Why it is difficult |
|---|---|
| ⭐ Which data goes with the divested unit? | ⭐ shared mailboxes, shared sites, ⭐ mixed history |
| ⭐ Who keeps the email history? | ⭐ a mailbox contains both businesses' correspondence |
| ⭐ Shared applications | ⭐ one tenant's app registration, two businesses using it |
| ⭐ Records under retention | ⭐ may be legally required to stay with the seller |
| ⭐ Identities of dual-role staff | ⭐ someone who worked for both |
| ⭐ TSA expiry | ⭐ **a hard date with a cost attached** |

⭐ **"Who keeps the email history?" has no technical answer** — it is a legal and commercial
decision, and ⭐ **your job is to surface it early enough that lawyers can decide before the
engineering depends on it.** Discovering in week eight that nobody has decided is a schedule
failure, and it is preventable with one question in week one.

⭐ **The dual-role staff problem is the sharpest edge:** a person who spent 60 % of their time on the
divested business and 40 % on the retained one has one mailbox, one OneDrive and one identity.
⭐ **There is no clean split, only a decided one** — and it must be decided by someone with the
authority to accept the consequences.

---

## 6. Design reference

| Phase | Approach |
|---|---|
| ⭐ **Due diligence** | ⭐ read-only assessment; ⭐ assume **no** trust; ⭐ often a redacted view |
| ⭐ **Day 1** | ⭐ cross-tenant sync + B2B + org relationship. ⭐ **No migration** |
| Day 2–100 | ⭐ decide: consolidate, or stay federated permanently |
| ⭐ Migration (if chosen) | [`../../45-m365-migration-engineering/tenant-to-tenant/`](../../45-m365-migration-engineering/tenant-to-tenant/) |
| ⭐ Divestiture | ⭐ separation first, ⭐ TSA clock, ⭐ legal decisions before engineering |
| Throughout | ⭐ **confidentiality** — ⭐ the deal may not be public |

⭐ **Due diligence deserves its own caution.** ⭐ **Before completion you may be given access to
assess a tenant you do not own, belonging to a company that may not complete the deal.** Treat it as
strictly read-only, document what you accessed, and ⭐ **do not configure anything** — ⭐ a change
made to a target that is subsequently not acquired is a serious problem for everyone.

⭐ **Confidentiality also constrains discovery technique.** ⭐ **You may not be permitted to ask the
target's staff anything**, which means the tenant queries in
[`../../75-architecture-and-consulting/discovery/`](../../75-architecture-and-consulting/discovery/) §5
carry more weight than usual — ⭐ **the data is all you have.**

---

## 7. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| ⭐ "Full integration by Day 1" promised | ⭐ Day 1 vs Day 100 not separated | ⭐ §3 — reframe in the first meeting |
| ⭐ Collaboration silently fails | ⭐ cross-tenant settings one-directional | ⭐ configure **both** tenants |
| Users double-prompted for MFA | inbound trust not configured | ⭐ `isMfaAccepted` — ⭐ a decision, not a default |
| ⭐ Schedule slips on a legal question | ⭐ data-ownership never decided | ⭐ surface it in week one |
| ⭐ TSA expires, not ready | ⭐ plan built on scope, not the clock | ⭐ plan backwards from the TSA date |
| ⭐ Change made to a target that did not complete | due diligence not read-only | ⭐ strict read-only, logged |
| Guests everywhere, ⭐ nobody removes them | no expiry on B2B | ⭐ access packages with expiry |

⭐ **"Plan backwards from the TSA date" is the scheduling discipline this vertical demands.**
⭐ **Every other project plans forward from what must be done; here you start at the immovable date
and subtract** — and if the arithmetic does not fit, that is a finding to escalate immediately, not
a problem to absorb.

---

## 8. Customer discovery questions

1. ⭐ **"What must be true on Day 1 for the announcement to be credible?"**
2. ⭐ **"Is the intention to consolidate to one tenant, or to keep both?"**
3. "What is the completion date, and can it move?" (⭐ it cannot)
4. ⭐ **"For a divestiture: when does the TSA expire, and what does it cost per month?"**
5. ⭐ **"Who decides which business keeps a shared mailbox's history?"**
6. "Are there staff who work for both entities?"
7. ⭐ **"Am I permitted to speak to the other organisation's IT team, and when?"**

---

## 9. Remember it

**Hook — ⭐ `D1 / D100`: Day 1 is *collaborate*; Day 100 is *consolidate*.** ⭐ **Only the first has a
legal deadline, and it needs no migration.**

**Analogy — two households becoming one.** ⭐ **On the wedding day you need a shared address for the
post and each other's phone numbers — you do not need to have merged the furniture.** The analogy
predicts the whole engagement: ⭐ **the deadline applies to the announcement, not the removals van**,
⭐ **some couples keep two houses permanently and that is a valid outcome**, and — for divestiture —
⭐ **separating is harder than joining, because you must decide who keeps the photographs.**

**The one line:** ⭐ **Day 1 is collaboration and needs no migration; separate it from consolidation
in the first meeting, and plan backwards from the immovable date.**

---

## 10. Self-test

1. What does Day 1 actually require?
   → ⭐ Address book resolution, mail flow, free/busy, collaboration. No migration.
2. Which technology delivers Day 1?
   → ⭐ Cross-tenant synchronization, B2B, organization relationship, cross-tenant access settings.
3. Why do cross-tenant access settings fail silently?
   → ⭐ They are directional; both tenants must be configured.
4. What is `isMfaAccepted` really saying?
   → ⭐ That you accept another organisation's authentication assurance as equivalent to your own.
5. What is a TSA and why does it dominate a divestiture?
   → ⭐ Transitional services from the seller, fixed expiry, rising cost — it sets the deadline.
6. Which M&A question has no technical answer?
   → ⭐ Who keeps a shared mailbox's history. Legal and commercial; surface it in week one.
7. When is "do not migrate" the right recommendation?
   → ⭐ When both entities keep operating independently — cross-tenant sync is a valid permanent architecture.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | ⭐ the four Day 1 checks, each with output |
| `security` | ⭐ the inbound-trust decision, written and owned by the customer |
| `operations` | the Day 1 runbook, and the backwards-planned schedule from the fixed date |
| `customer-use-cases` | ⭐ the Day 1 vs Day 100 scope, agreed in the first meeting |
| `architecture-decisions` | ⭐ the consolidate-or-stay-federated decision, with cost |
