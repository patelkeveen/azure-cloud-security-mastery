# SC-300 Sprint — 7 days of labs on a 30-day clock

> ⚠ **EXAM BOOKED: Friday 28 August 2026. This README's pacing is superseded.**
> ⭐ **Go to [`EXAM-COUNTDOWN.md`](EXAM-COUNTDOWN.md)** — it re-triages these seven days against a
> real exam date, cuts ~6 hours of portfolio work that scores zero marks, and adds the revision
> days this sprint never had.
> **Supporting:** [`GAP-DRILL.md`](GAP-DRILL.md) — ⭐ the exam-tested material these labs never
> touch · [`EXAM-DAY.md`](EXAM-DAY.md) — technique and the morning of.

> **Trial:** Microsoft 365 E5 (Trial) on `KWin.onmicrosoft.com`, purchased **2026-08-11**,
> ⚠ **expires 2026-09-10**.
> **This sprint:** SC-300 labs, **2026-08-12 → 2026-08-19** — ⭐ **29 days left on the trial as of
> day 1**, so the sprint consumes a quarter of it and leaves room for SC-200.
> Theory lives in the topic READMEs — this directory is *execution only*.
>
> ⚠ Dates in this pack are absolute on purpose. `Day0-Verify-Tenant.ps1` recomputes days-remaining
> live — trust the script over any number written here.

---

## 0. ⭐ Run this sprint without asking anyone

**Everything you need is in this directory. There is no step that requires an AI, a forum, or me.**

```powershell
cd C:\IT\azure-cloud-security-mastery\SC-300-SPRINT
.\Invoke-SprintCheck.ps1          # ⭐ start and end EVERY day with this
```

It reports PASS/FAIL on connection, break-glass, licensing, telemetry, seeded org, Azure and
evidence — and **every FAIL prints its own fix**. No interpretation needed.

| You need | Read |
|---|---|
| What do I do today? | [`DAY-1`](DAY-1.md) … [`DAY-7`](DAY-7.md) |
| Which official Microsoft labs? | [`OFFICIAL-LABS-MAP.md`](OFFICIAL-LABS-MAP.md) |
| ⭐ **Something broke** | ⭐ [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) |
| Why does this control exist? | the topic README linked from each lab |
| What do I sell afterwards? | [`../7-DAY-SC-300-E5-AZURE-TRIAL-SPRINT.md`](../7-DAY-SC-300-E5-AZURE-TRIAL-SPRINT.md) |

⭐ **When something fails, the answer is almost always one of five things:** a missing **scope**, an
un-**activated** role, an un-**assigned** licence, a **token** older than your change, or a control
sitting in **report-only**. `TROUBLESHOOTING.md` §11 has the general method for everything else.

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

## 1c. ⭐ Official Microsoft labs — 28 of them, mapped

[`OFFICIAL-LABS-MAP.md`](OFFICIAL-LABS-MAP.md) maps every lab in
`MicrosoftLearning/SC-300-Identity-and-Access-Administrator` onto these seven days.

⭐ **They are Microsoft's own, not generated — trust them above any walkthrough.** ✅ Currency
checked 2026-08-12: 255 "Microsoft Entra" vs 71 "Azure AD", and 60 of those 71 are in Lab_07.

⚠ **But they lag the April 2026 skills-measured update by seven objectives** — Global Secure
Access, authentication context, protected actions, CAE, cross-tenant sync, custom security
attributes and Temporary Access Pass are **all uncovered**. ⭐ **Doing all 28 and stopping leaves
you having never touched an entire exam subsection.** [`DAY-2`](DAY-2.md) and [`DAY-3`](DAY-3.md)
close the gap.

⭐ **Use the official labs for coverage; use this sprint for depth, deliberate failure and
evidence.**

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
| [`New-SprintTodo.ps1`](New-SprintTodo.ps1) | ⭐ **at the start of a sprint day** — pushes the day's tasks into **Microsoft To Do** and reviews the rest of your list | ⭐ **review-only until `-Apply`**; ⭐ never deletes |

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

⚠ **These seven days are a *capability* track, not an *exam* track.** Measured against the
sprint's own text: `administrative unit`, `password hash sync`, `connected organization` and
`B2B direct connect` appear **zero times** — and all four are examinable. ⭐ **The labs teach what
a trial tenant can build; [`GAP-DRILL.md`](GAP-DRILL.md) covers the rest.**

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

⭐ **UNBLOCKED 2026-08-19** — subscription `912ac3b8-d003-48d1-8266-e4d029ba1fd7`
("Azure subscription 1", tenant `K-Win`) now exists, so Sentinel, Defender for Cloud, Azure
Policy, Key Vault, private endpoints, Bicep/Terraform and all of `60-ai-and-secure-ai` are
**technically runnable**.

> ⚠ **Do not touch any of it before 2026-08-28.**
>
> ⭐ **None of it is on SC-300.** SC-300 is four identity domains; Sentinel is SC-200 and
> Foundry is SC-500. A newly-unblocked subscription 8 days before an identity exam is the most
> expensive distraction available to you — it *feels* like progress and scores zero marks.
>
> ⭐ **The correct move: bank it, then use it.** The subscription is the SC-200 runway, and it
> is the one window in which Sentinel + Defender XDR **integration** labs are possible while the
> E5 trial is still live. Sequential trials give you two separate products and zero days of the
> integration. **Diarise it for 2026-08-29, not today.**

⭐ **What SC-300 still cannot cover, subscription or not:** on-prem AD DS, Entra Connect sync
and ADFS federation need a domain controller. Those are exam-relevant as *concepts* — read
[`35-active-directory-and-hybrid-identity`](../35-active-directory-and-hybrid-identity/); you
will answer them from theory, not from your tenant.

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
