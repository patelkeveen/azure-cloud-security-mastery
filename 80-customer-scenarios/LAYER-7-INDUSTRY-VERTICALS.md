# Layer 7 — Industry Verticals: The Same Product, Nine Different Constraints

> **This is the layer that makes you portable.** Layers 1–6 taught the product. This teaches
> what changes when you walk into a hospital versus a bank versus a factory — and, more useful,
> **what to stop yourself promising.**
>
> **Nature of this content — read this first.** Layers 1–6 are verified product behaviour.
> **This layer is engineering and consulting judgement**: recurring patterns, common failure
> modes, and the questions worth asking. Regulatory frameworks are named for orientation only.
> **I am not qualified to tell you what any regulation requires, and neither are you** — the
> customer's compliance and legal functions own that. Your job is to translate *their* stated
> control requirement into Entra configuration, and to say clearly when it can't be met.

---

## 1. The universal method

Before the verticals, the method that works in all of them.

### The translation chain

Consultants who struggle try to map regulation → product. The chain has more links:

```
Regulation  →  Control objective  →  Technical requirement  →  Entra feature  →  Evidence artifact
```

Only the customer can supply the first two links. **You own the last three.** Insisting on that
boundary is what stops you from making commitments you can't verify — and it's also what makes
you useful, because most vendors skip straight from regulation to product demo.

**The evidence artifact is the deliverable.** Not the config — the *proof*. An access review
that ran, with recorded decisions and applied results (Layer 5 §3). A PIM activation history.
A CA gap-analysis workbook. Assessors don't audit your policy JSON; they ask what happened and
who checked.

### Discovery questions that work anywhere

Ask these in week one, in this order. The answers determine the entire design:

1. **"Which Microsoft cloud instance?"** Commercial, GCC, GCC High, DoD, or a sovereign cloud.
   This is first because it constrains *everything* — feature parity is not guaranteed.
2. **"What licences do you actually own, per population?"** Not what they plan to buy. P1 vs P2
   vs ID Governance vs Agent 365 decides which of Layers 3–6 you can even use.
3. **"Do you have on-premises Active Directory, and is it staying?"** Splits the engagement in
   half (Layer 2 §1.4).
4. **"How long must you retain sign-in and audit logs?"** Defaults are 7 days Free / 30 days
   P1–P2 (Layer 5 §5). Almost every regulated answer exceeds that, which means diagnostic
   settings are a **compliance requirement**, not a nice-to-have.
5. **"What's the oldest system that must authenticate?"** Finds the legacy-auth problem before
   you promise to block legacy auth.
6. **"Who are your break-glass accounts, and when were they last tested?"** The fastest read on
   operational maturity. "What's a break-glass account?" tells you where to start.
7. **"How long from termination to access revoked — measured, not intended?"** Nobody knows.
   Finding out is often the first real deliverable.
8. **"What holds an API key?"** Increasingly the highest-value question (Layer 6 §3).

### The universal baseline

Before vertical specialisation, almost every tenant needs the same first six things:

1. Break-glass accounts, excluded from all CA, alerted on (Layer 5 §4)
2. Block legacy authentication — **after** measuring usage with KQL (Layer 5 §5)
3. MFA for all users, phishing-resistant for admins (Layer 3 §3.3)
4. PIM for privileged roles, eligible + time-bound (Layer 5 §4)
5. Diagnostic settings to Log Analytics (Layer 5 §5)
6. Restrict user consent + enable the admin consent workflow (Layer 4 §6)

If a customer has these, they're ahead of most. If they don't, do them before anything clever.

---

## 2. Financial services and banking

**Drivers.** Segregation of duties, auditable privileged access, change control, long evidence
retention. Frameworks vary by jurisdiction — SOX, PCI-DSS where cards are handled, and regional
regimes such as FFIEC, FCA, OSFI, RBI, or DORA. *Let the customer tell you which apply.*

**Identity design.**
- **PIM everywhere**, with approval and justification on activation, plus **authentication
  context requiring phishing-resistant strength** (Layer 5 §4). Elevation to a privileged role
  demands a passkey.
- **Protected actions** on directory-changing operations — deleting a CA policy should itself
  require step-up (Layer 3 §3.2).
- **Access reviews quarterly with auto-apply ON** and no-response = Remove.
- **Separation of duties in entitlement management** — packages marked incompatible.
- Long-horizon log export to Sentinel or storage.

**The trap — two of them.**

*SoD is an entitlement problem, not a role problem.* Engineers try to express "nobody submits
and approves payments" through custom directory roles. It doesn't fit: the conflict is between
*business entitlements*, not directory permissions. Use entitlement management's incompatible
packages, which enforces at request time.

*Retention defaults are a compliance failure.* A bank required to keep authentication records
for years, running on the 30-day default with no diagnostic settings, has a finding — and it's
**unrecoverable retroactively** (Layer 5 §5). Check this in week one.

**Discovery:** *"When your auditor asks who approved a privileged elevation last March, what do
you show them?"*

---

## 3. Healthcare

**Drivers.** Patient data protection (HIPAA, PHIPA, NHS DSPT and equivalents), shared clinical
workstations, and — dominating everything — **clinical workflow speed**.

**Identity design.**
- **Shared device mode** and fast user switching on ward workstations.
- **Passkeys / FIDO2 over SMS.** Gloves, sterile fields, and no personal phone at the bedside
  make phone-based MFA actively unusable.
- **Short sign-in frequency** on shared devices, long on personal ones.
- **Entitlement management** for rotating residents, locums and agency staff — high-churn,
  time-bounded access is exactly what access packages are for.

**⚠ Terminology collision.** In healthcare, *"break the glass"* means **emergency clinician
access to a patient record they wouldn't normally see**, with retrospective audit. That is not
an Entra break-glass account. **Establish which one is meant before designing anything**, or you
will build the wrong control and discover it late.

**The trap.** *Clinicians will defeat any authentication that costs more than a few seconds at
the bedside* — shared logins, propped-open sessions, a password on a sticky note under the
keyboard. This is not a training problem; it's a design problem. **Test with a real clinician
doing a real task before rollout.** A control that gets bypassed is worse than a weaker one that
gets used, because it produces false assurance.

**Discovery:** *"Walk me through a nurse starting a shift on a shared workstation — every tap."*

---

## 4. Government and public sector

**Drivers.** Authorisation frameworks (FedRAMP, IRAP, ITSG-33 and equivalents), **data
sovereignty**, and smartcard credentials (PIV/CAC or national ID cards).

**Identity design.**
- **Certificate-based authentication** with the PKI trust store configured, username binding
  rules, and multi-factor CBA affinity (Layer 3 §5).
- **Sovereign cloud boundaries** respected in the architecture.
- **No consumer social identity providers** for guests.
- **Tenant restrictions v2** to stop cross-tenant data movement (Layer 3 §6).

**The trap — the expensive one.** **Sovereign and government clouds have feature-parity gaps.**
A feature GA in commercial may be preview, delayed, or absent in GCC High, DoD, or a regional
sovereign cloud. Designing from commercial documentation and discovering the gap at
implementation is the single most costly mistake in this vertical.

**Verify every feature against the target cloud's availability documentation before it enters a
design document.** Not after. This is why "which cloud instance?" is discovery question #1.

**Discovery:** *"Which cloud instance, and who signs off the authorisation boundary?"*

---

## 5. Manufacturing and operational technology

**Drivers.** Shop-floor shared accounts, intermittent or air-gapped networks, legacy HMI and
SCADA systems, safety systems that cannot be interrupted. IEC 62443 is the common reference.

**Identity design.**
- **Entra Private Access** for legacy line-of-business apps over TCP/UDP; **Application Proxy**
  where it's HTTP and needs Kerberos Constrained Delegation (Layer 4 §6).
- **Device-bound passkeys** or smartcards for shared terminals — no personal phones on a factory
  floor.
- **Named locations** for plant networks, used as CA conditions.
- Clear separation between IT identity and OT identity. They are not the same estate.

**The trap.** *Many OT systems cannot do modern authentication at all* — no MFA, no OAuth, no
SAML, and sometimes a hardcoded shared credential that a vendor support contract depends on.
**The honest answer is network segmentation plus a controlled jump path, not "we'll bring it
into SSO."** Promising SSO for a twenty-year-old HMI destroys your credibility the moment
someone opens its manual.

Say it plainly: *"That system can't be secured at the identity layer. We secure the path to it
instead."* That sentence marks you as someone who has actually been on a plant floor.

**Discovery:** *"What's the oldest thing on this network, and who is allowed to touch it?"*

---

## 6. Retail

**Drivers.** Enormous seasonal churn, POS terminals, franchise or multi-brand tenancy, PCI-DSS
where card data is in scope.

**Identity design.**
- **Lifecycle Workflows** for joiner/mover/leaver at volume — but note this **requires the Entra
  ID Governance SKU** (Layer 5 §1). Confirm entitlement before designing around it.
- **Entitlement management** for seasonal onboarding waves.
- **Cross-tenant access settings** for franchisees operating their own tenants (Layer 2 §1.3).
- Shared-device and kiosk patterns for POS.

**The trap.** **Deprovisioning latency at scale.** Hiring 3,000 seasonal staff in six weeks
means offboarding 3,000 in another six. If the leaver path takes days — or depends on a manager
remembering — you accumulate thousands of live accounts with store access.

**Measure it end to end**: termination in HR → account disabled → sessions revoked → SaaS
deprovisioned via SCIM (Layer 4 §6). Every one of those is a separate delay, and SCIM quarantine
can silently stop the last step entirely.

**Discovery:** *"In your peak month, how many people leave — and how long until their access is
actually gone?"*

---

## 7. SaaS and technology

**Drivers.** Engineer velocity versus least privilege, heavy CI/CD, multi-cloud, and usually
SOC 2 or ISO 27001 as the commercial gate.

**Identity design.**
- **Workload identity federation** for every pipeline (Layer 4 §4) — GitHub Actions, Azure
  Pipelines, Kubernetes, and cross-cloud to AWS and GCP. **No secrets.**
- **PIM for production access**, eligible + time-bound, tied to a change ticket.
- **SCIM provisioning to every SaaS app**, so leavers actually lose access.
- **Risky workload identity monitoring** (Layer 3 §4) and service principal sign-in hunting
  (Layer 5 §5).

**The trap.** **Long-lived service principal secrets in pipelines.** It is the most common real
breach path in modern estates: a secret in a repo variable, copied to three other repos, shared
in chat once, never rotated, valid for two years.

This is also your fastest visible win. Migrating one pipeline to federated credentials and
deleting the secret is a same-day deliverable with a clear before/after. Run the secret-expiry
report (Layer 4 §5) on day one — it usually finds something alarming.

**Discovery:** *"Show me how your deployment pipeline authenticates to production."*

---

## 8. Education

**Drivers.** Very large student populations, annual cohort churn, BYOD everything, minors with
additional legal protections, and constrained budgets.

**Identity design.**
- **Dynamic groups keyed on enrolment attributes** (Layer 2 §1.2) — cohort, faculty, year.
  Rebuilding group membership manually each September is not viable.
- **SSPR at scale** — students are the highest-volume password-reset population in any sector.
- **Guest access** for parents, alumni and external examiners.
- **Entra External ID** for applicant-facing portals (Layer 2 §1.3).

**The trap.** **Academic licensing (A1/A3/A5) differs from commercial, and governance features
may simply not be licensed for the student population.** Designing access reviews and PIM around
a population that only holds A1 produces a beautiful architecture the institution cannot deploy.

And remember the counting rule (Layer 5 §1): access reviews are licensed by the **reviewed
population**, not the reviewers. A review of 40,000 students is 40,000 licences.

**Discovery:** *"Which A-SKU, for which populations, and what's covered for students versus
staff?"*

---

## 9. Mergers and acquisitions ⭐

The highest-skill vertical, and where hybrid identity knowledge pays best.

**Drivers.** Two tenants, one company, and an executive expectation of day-one collaboration.

**Identity design — in this order.**
1. **Cross-tenant access settings** with **trust MFA / compliant device / hybrid join** from the
   other tenant (Layer 2 §1.3). This is what delivers day-one collaboration *without* forcing
   thousands of people to re-register MFA in a second tenant.
2. **Cross-tenant synchronization** so users appear in each other's directories.
3. **Multi-tenant organization** configuration.
4. **Entra Cloud Sync** for the acquired forest — chosen over Connect Sync precisely because it
   handles **disconnected forests with no trust** (Layer 2 §1.4).
5. Only later: tenant consolidation, if it's justified at all.

**The trap.** **UPN collisions and source-anchor conflicts.** Two `j.smith@` accounts. Two
directories where `ms-DS-ConsistencyGuid` was never consistently populated. Sync starts, soft
match misses, and you get duplicate objects for real humans — one holding the mailbox, one
holding nothing but now authoritative (Layer 2 §1.4).

**Plan the matching strategy before you sync a single object.** Recovering afterwards means hard
matches, quarantined attributes, and a bad week. This single piece of knowledge is worth more in
an M&A engagement than everything else in this document.

**Discovery:** *"Do the two directories share any SMTP domain or UPN suffix? And has either ever
been migrated between forests?"*

---

## 10. Nonprofit

**Drivers.** Minimal or zero budget, volunteer and transient identity, donated licence grants,
often no dedicated IT security function.

**Identity design.**
- Maximise the **free and P1 tiers**.
- **Security Defaults** where CA isn't licensed — genuinely better than nothing.
- Guest-heavy collaboration models.
- Simple, documented, self-running processes — there may be nobody to operate anything complex.

**The trap — two.**

*Designing for features they'll never afford.* A P2/Governance architecture for an organisation
running on a donated grant is a document that gets filed and ignored.

*Security Defaults and Conditional Access are mutually exclusive* (Layer 6 §3). Moving from one
to the other requires P1 and a deliberate migration — you must recreate as CA policies what
Security Defaults provided automatically, and there's a window where you have neither if you do
it carelessly.

**Discovery:** *"What's in your grant allocation, and what happens if it isn't renewed?"*

---

## 11. Cross-vertical patterns

**Where every sector converges:**
- Break-glass accounts, always
- Legacy authentication is the biggest single risk everywhere
- Deprovisioning is slower than anyone believes
- Log retention defaults are shorter than anyone assumes
- Nobody knows what holds an API key

**Where they genuinely diverge:**

| Dimension | Loosest | Tightest |
|---|---|---|
| Authentication friction tolerance | Government, finance | **Healthcare, manufacturing** |
| Identity volume and churn | Nonprofit | **Education, retail** |
| Evidence/audit burden | Nonprofit, SaaS | **Finance, government** |
| Legacy system drag | SaaS | **Manufacturing, government** |
| Budget | Finance | **Nonprofit, education** |

**The transferable insight:** the product is identical in all nine. What changes is **which
constraint binds first** — friction, volume, evidence, legacy, or budget. Identify the binding
constraint in the first week and the design follows from it. Design without identifying it and
you produce something technically correct that nobody can operate.

---

## 12. How to say no

More engagements are damaged by overpromising than by under-delivering. Three sentences worth
having ready:

> *"That system can't be secured at the identity layer. We'll secure the path to it instead."*

> *"That feature isn't available in your cloud instance. Here's what is, and here's the gap."*

> *"You're not licensed for that today. Here's what your current licences do achieve, and
> here's what the upgrade would buy."*

Saying any of these early costs you nothing. Saying them late, after they're in a design
document, costs the engagement.

---

## 13. Syllabus complete

Layers 1–7 now cover: the protocol substrate, all four SC-300 exam domains, the SC-500 bridge,
and the vertical application.

**What the syllabus cannot do is make you competent.** Every layer ends with a hands-on gate for
a reason — roughly forty labs across the set, and none of them run without a tenant. The reading
is the map; the labs are the territory.

**Suggested order from here:** tenant → Layer 1 labs (decode a real JWT) → Layer 3 labs (CA in
report-only) → Layer 2 §1.4 (build a DC, break sync deliberately) → Layer 5 (PIM and KQL) →
Layer 4 §4 (federate a pipeline with zero secrets) → Layer 6.

---

## 14. Cross-references

| Vertical | Leans hardest on |
|---|---|
| Financial services | Layer 5 §4 (PIM), §3 (reviews), §5 (retention) |
| Healthcare | Layer 3 §5 (auth methods), Layer 5 §2 (entitlement management) |
| Government | Layer 3 §5 (CBA), §6 (tenant restrictions) |
| Manufacturing | Layer 3 §6 (Private Access), Layer 4 §6 (App Proxy + KCD) |
| Retail | Layer 5 §§1–2 (Governance SKU, packages), Layer 4 §6 (SCIM) |
| SaaS / tech | **Layer 4 §4 (workload identity federation)**, Layer 5 §4 (PIM) |
| Education | Layer 2 §1.2 (dynamic groups), §1.3 (External ID) |
| **M&A** | **Layer 2 §§1.3–1.4 (cross-tenant, source anchor, soft/hard match)** |
| Nonprofit | Layer 3 (Security Defaults vs CA), Layer 5 §1 (licensing) |
