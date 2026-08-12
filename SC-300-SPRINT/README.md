# SC-300 Sprint — 7 days of labs on a 30-day clock

> **Trial:** Microsoft 365 E5 (Trial) on `KWin.onmicrosoft.com`, purchased **2026-08-11**,
> ⚠ **expires 2026-09-10**.
> **This sprint:** SC-300 labs, **2026-08-12 → 2026-08-19** — ⭐ **29 days left on the trial as of
> day 1**, so the sprint consumes a quarter of it and leaves room for SC-200.
> Theory lives in the topic READMEs — this directory is *execution only*.
>
> ⚠ Dates in this pack are absolute on purpose. `Day0-Verify-Tenant.ps1` recomputes days-remaining
> live — trust the script over any number written here.

---

## 1. ⭐ The principle that orders everything

> **The constraint on a trial is DATA LATENCY, not difficulty.**

Identity Protection, Defender for Endpoint, ASR audit mode, Defender for Cloud Apps discovery,
Defender for Identity, Insider Risk, the unified audit log and `MailItemsAccessed` **capture from
the moment you enable them forward**, and several need days of baseline before they say anything.

⭐ **Follow a syllabus linearly and you reach Defender for Cloud Apps on day 22 with eight days of
telemetry instead of thirty.** So Day 1 enables everything that *learns*, and the remaining days
do instant work while data accumulates in the background.

**Second principle:**

> ⭐ **A pristine tenant generates no signal.** You cannot practise detection in an empty
> environment. **Create the mess before you practise cleaning it.**

**Third principle, and the reason this directory exists:**

> ⭐ **The trial is not 30 days of access. It is 30 days to produce artifacts that outlive it.**
> On 10 September the licence lapses and the configuration disappears. What remains is what you
> filed. `New-LabEvidence.ps1` is how you file it.

---

## 1b. ⭐ Exam weightings — revise in proportion

✅ Verified against the SC-300 study guide **2026-08-12** (skills measured as of 27 April 2026):

| Domain | Weight | Sprint days |
|---|---|---|
| Implement and manage user identities | 20–25% | 1, 7 |
| ⭐ **Implement authentication and access management** | ⚠ **25–30%** | ⭐ **2, 3** |
| Plan and implement workload identities | 20–25% | 6 |
| Plan and automate identity governance | 20–25% | 4, 5 |

⚠ **Microsoft's page contradicts itself** — "Skills at a glance" says 25–30% for authentication
and access management; that section's heading says 20–25%. ⭐ Either way it is the largest or
joint-largest domain, and **Days 2–3 are where the marks are.**

⭐ **Objectives added after verification** (they were missing from both plans): **authentication
context**, **protected actions**, **continuous access evaluation**, and **Global Secure Access** —
now in [`DAY-3.md`](DAY-3.md) §3.5.

**Commercial layer:** [`../7-DAY-SC-300-E5-AZURE-TRIAL-SPRINT.md`](../7-DAY-SC-300-E5-AZURE-TRIAL-SPRINT.md)
owns buyer problems, fixed-scope offers, outreach and interview narratives. ⭐ **This directory owns
the schedule; that file owns what you sell afterwards.** Its day table is superseded by this one.

---

## 2. Why this is not another daily pack

`DAILY-EXECUTION/` is the **10-day M365 migration-engineering** track — a different subject.
This directory is the **SC-300 identity** track, and it is deliberately thin:

⭐ **Each lab links to the already-written topic README for theory and contains only the
executable steps and the evidence it must produce.** The repo has 101 DEEP topics; duplicating
them into runbooks would create a second source of truth that drifts. **Read the topic, run the
lab, file the artifact.**

---

## 3. The scripts

| Script | When | Safety |
|---|---|---|
| [`Day0-Verify-Tenant.ps1`](Day0-Verify-Tenant.ps1) | ⭐ **first, before anything** | read-only |
| [`Day1-New-BreakGlass.ps1`](Day1-New-BreakGlass.ps1) | ⭐ **before the first CA policy** | dry-run default |
| [`Day1-Enable-Telemetry.ps1`](Day1-Enable-Telemetry.ps1) | Day 1, then leave it running | dry-run default, ⭐ refuses without break-glass |
| [`../30-identity-and-nhi/entra-users-and-groups/Seed-LabTenant.ps1`](../30-identity-and-nhi/entra-users-and-groups/Seed-LabTenant.ps1) | Day 1, after telemetry | dry-run default |
| [`New-LabEvidence.ps1`](New-LabEvidence.ps1) | ⭐ **after every lab** | write to repo only |

```powershell
# The exact Day 1 order. Do not reorder — the gate exists for a reason.
cd C:\IT\azure-cloud-security-mastery\SC-300-SPRINT

.\Day0-Verify-Tenant.ps1 -OutFile ..\SC-300-SPRINT\evidence\day0-licence-state.json
.\Day1-New-BreakGlass.ps1                      # dry run
.\Day1-New-BreakGlass.ps1 -Apply               # store the passwords offline NOW
.\Day1-Enable-Telemetry.ps1                    # dry run
.\Day1-Enable-Telemetry.ps1 -Apply
..\30-identity-and-nhi\entra-users-and-groups\Seed-LabTenant.ps1 -Apply
```

---

## 4. The seven days

Each day maps to topics that are **already written to `CONTENT-STANDARD.md`**. Read the topic
first; the lab assumes it.

| Day | Focus | Topics (theory) | ⭐ Evidence that must exist by end of day |
|---|---|---|---|
| **[1](DAY-1.md)** | Baseline, break-glass, telemetry on, seed the org | [entra-users-and-groups](../30-identity-and-nhi/entra-users-and-groups/), [pim-and-access-reviews](../30-identity-and-nhi/pim-and-access-reviews/) | licence state JSON · break-glass design + CA exclusion proof · seeded org |
| **[2](DAY-2.md)** | Authentication methods, passwordless, SSPR | [authentication-methods](../30-identity-and-nhi/authentication-methods/), [passwordless-and-passkeys](../30-identity-and-nhi/passwordless-and-passkeys/) | auth method policy export · registration campaign · ⭐ a *failed* legacy-auth sign-in |
| **[3](DAY-3.md)** | ⭐ Conditional Access — the domain's core | [conditional-access](../30-identity-and-nhi/conditional-access/) | policy set export · What-If results · ⭐ **a deliberate lockout, recovered with break-glass** |
| **[4](DAY-4.md)** | PIM, roles, least privilege | [pim-and-access-reviews](../30-identity-and-nhi/pim-and-access-reviews/), [service-principals](../30-identity-and-nhi/service-principals/) | eligible-vs-active matrix · activation with approval · ⭐ standing-privilege before/after |
| **[5](DAY-5.md)** | Governance: access reviews, entitlement management, lifecycle | [entitlement-management](../30-identity-and-nhi/entitlement-management/), [lifecycle-workflows](../30-identity-and-nhi/lifecycle-workflows/) | access package · a completed review · ⭐ leaver workflow fired |
| **[6](DAY-6.md)** | Apps, consent, workload identity | [app-registrations](../30-identity-and-nhi/app-registrations/), [oauth-oidc-saml-and-api-auth](../30-identity-and-nhi/oauth-oidc-saml-and-api-auth/), [workload-identity-federation](../30-identity-and-nhi/workload-identity-federation/) | ⭐ decoded token showing `scp` vs `roles` · consent policy · federated credential |
| **[7](DAY-7.md)** | External identities, Identity Protection, ⭐ **prove it all** | [external-identities](../30-identity-and-nhi/external-identities/), [identity-protection](../30-identity-and-nhi/identity-protection/) | guest review · risk detections (⭐ *because Day 1 turned it on*) · ⭐ full evidence sweep |

⭐ **Day 7's risk detections only exist because Day 1 enabled Identity Protection.** That is the
data-latency principle paying off, and it is why the order is not negotiable.

---

## 5. The daily contract

Non-negotiable, per day:

```
[] Read the topic README first — the lab assumes it
[] Run the lab
[] ⭐ BREAK something deliberately, and record the verbatim error
[] File evidence with New-LabEvidence.ps1
[] Re-run tools/Build-CoverageRegister.ps1
[] Commit — the repo is the deliverable, not the tenant
```

⭐ **The deliberate failure is the part that transfers.** Anyone can follow a happy path; the
value is knowing what the error *looks like* and which layer produced it —
[`00-foundations/troubleshooting-method`](../00-foundations/troubleshooting-method/) §5:
**reproduce the failure, not the success.**

---

## 6. ⭐ Rehearse the expiry — the lab nobody gets to run

Before **2026-09-10**, deliberately observe what a licence lapse does. Most engineers never see
this and it is a real customer scenario:

```
⭐ PIM licence expiry:
    eligible assignments      → DELETED
    time-bound ACTIVE         → converted to PERMANENT
⭐ CA policies with P2 risk conditions → stop evaluating
```

⭐ **That is a security event dressed as a billing event**, and it produces a
`break-fix` artifact you cannot manufacture any other way. Capture the before/after.

⚠ **Set a cancellation reminder for 2026-09-05** or the trial converts to paid at M365 E5 rates.

---

## 7. What this sprint cannot cover

⭐ **There is no Azure subscription**, so these stay blocked regardless of E5:

```
Microsoft Sentinel · Defender for Cloud · attack path analysis
Azure Policy · resource locks · landing zones · budgets
Key Vault · private endpoints · Bicep / Terraform
⭐ all of 60-ai-and-secure-ai (Foundry, AI Search, Content Safety)
```

⭐ **An Azure free account ($200 / 30 days) run in parallel is the only window in which
Sentinel + Defender XDR integration labs are possible** — which is SC-200's core. Sequential
gives 60 days of separate learning and **zero days of the integration**.

---

## 8. Where the artifacts go

`New-LabEvidence.ps1` files into the topic's facet folders. **COVERAGE.md counts a topic
WRITTEN at ≥3 of 6 facets filled** — currently **0/144**, for licensing reasons rather than
effort.

⭐ **This sprint is the path to the repo's first WRITTEN topics**, and the count at the end of it
is the honest measure of the week — not how many labs were "done".

> Related: [`../CONTENT-STANDARD.md`](../CONTENT-STANDARD.md) ·
> [`../COVERAGE.md`](../COVERAGE.md) · [`../RETENTION.md`](../RETENTION.md) ·
> [`../CERT-MAP.md`](../CERT-MAP.md)
