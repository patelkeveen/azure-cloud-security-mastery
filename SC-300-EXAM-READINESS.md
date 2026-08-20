# SC-300 Exam Readiness Hub — August 28, 2026

> **Use this file as the control tower.** The repo already has deep theory, a 7-day SC-300 lab
> sprint, and a separate 10-day M365/migration sprint. This page tells you what to use, what to skip,
> how to avoid duplication, and how to turn every exam objective into something you can explain and
> prove.
>
> **Current official baseline checked 2026-08-20:** Microsoft Learn lists SC-300 skills measured as
> of **2026-04-27** and the study guide page as last updated **2026-03-27**. Passing score remains
> **700+**. The current domain weights are: user identities **20-25%**, authentication and access
> management **25-30%** in the skills-at-a-glance summary, workload identities **20-25%**, and identity
> governance **20-25%**.
>
> Official source: <https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/sc-300>

---

## 1. Repo source-of-truth map

| Need | Use this | Do not duplicate it into |
|---|---|---|
| Exam objective map and topic order | [`SC-300-MASTERY-SYLLABUS.md`](SC-300-MASTERY-SYLLABUS.md) | Daily files |
| Fast exam + money strategy | [`7-DAY-SC-300-E5-AZURE-TRIAL-SPRINT.md`](7-DAY-SC-300-E5-AZURE-TRIAL-SPRINT.md) | Lab runbooks |
| Hands-on execution on the trial tenant | [`SC-300-SPRINT/README.md`](SC-300-SPRINT/README.md) | The 10-day M365 sprint |
| Deep theory for why the lab works | Layer documents under `30-identity-and-nhi/` and `35-active-directory-and-hybrid-identity/` | New summary notes |
| Evidence standard | [`CONTENT-STANDARD.md`](CONTENT-STANDARD.md), [`EVIDENCE-SCHEMA.md`](EVIDENCE-SCHEMA.md), [`COVERAGE.md`](COVERAGE.md) | Resume bullets |
| M365/migration breadth after SC-300 | [`10-DAY-SPRINT.md`](10-DAY-SPRINT.md), [`DAILY-EXECUTION/`](DAILY-EXECUTION/) | SC-300 sprint |

**Rule:** if a file teaches the same concept twice, keep the deeper explanation in the topic layer
and make the sprint file link to it. Sprint files should say **what to do today**, not re-explain the
whole product.

---

## 2. August 20-28 exam attack plan

This plan assumes the exam is on **2026-08-28** and today is **2026-08-20**. If you start later,
keep the order and compress by cutting breadth, not by skipping Conditional Access, PIM, apps, or logs.

| Date | Goal | Must-do repo path | Output |
|---|---|---|---|
| Aug 20 | Repo orientation, tenant safety, baseline | This hub, `START-HERE.md`, `SC-300-SPRINT/README.md`, `SC-300-SPRINT/DAY-1.md` | Budget guardrail, break-glass proof, telemetry enabled, seeded users |
| Aug 21 | User identities + hybrid mental model | `LAYER-2-DOMAIN-1-USER-IDENTITIES.md`, `SC-300-SPRINT/DAY-1.md` closeout | Users/groups/licensing/admin units/domain/hybrid cheat sheet |
| Aug 22 | Authentication methods | `SC-300-SPRINT/DAY-2.md`, auth/passwordless READMEs | MFA, SSPR, TAP, passkey/FIDO2, password protection explain-back |
| Aug 23 | Conditional Access mastery | `SC-300-SPRINT/DAY-3.md`, Layer 3 | CA policy pack, What If evidence, lockout/recovery story |
| Aug 24 | PIM + privileged access | `SC-300-SPRINT/DAY-4.md`, Layer 5 | Standing-vs-eligible matrix, PIM settings, approval/audit story |
| Aug 25 | Governance + external users | `SC-300-SPRINT/DAY-5.md`, external identities topics | Access package, access review, guest lifecycle, connected org notes |
| Aug 26 | Apps, workload identities, MDCA | `SC-300-SPRINT/DAY-6.md`, Layer 1 and Layer 4 | App/SP diagram, delegated-vs-app permissions, decoded token, consent risk story |
| Aug 27 | Logs, Identity Protection, mock exam | `SC-300-SPRINT/DAY-7.md`, KQL/logging sections | Risk investigation, KQL notes, final wrong-answer register |
| Aug 28 | Exam day | This hub only | One-page recall sheet, calm pass strategy |

---

## 3. SC-300 domain memory model

Remember the exam as four verbs:

1. **Create identities** — tenants, users, groups, devices, external users, hybrid sync.
2. **Control access** — MFA, passwordless, SSPR, Conditional Access, risk, Global Secure Access.
3. **Authorize apps and workloads** — enterprise apps, app registrations, service principals,
   managed identities, consent, Defender for Cloud Apps.
4. **Govern and prove** — entitlement management, access reviews, PIM, logs, KQL, Secure Score.

Mnemonic: **U-A-W-G** — **Users, Access, Workloads, Governance**.

### Conditional Access memory sentence

> **When WHO, using WHAT, from WHERE, accesses WHICH APP, under WHAT RISK, then enforce WHICH
> CONTROLS, for HOW LONG.**

Map that to policy fields:

| Question | Conditional Access concept |
|---|---|
| WHO? | users, groups, roles, guests, workload identities |
| WHAT device/client? | platform, client app, device state, compliance, hybrid join |
| WHERE? | named locations, countries, trusted networks |
| WHICH APP? | cloud apps, user actions, authentication context |
| WHAT RISK? | user risk, sign-in risk, insider risk signals via integrations |
| WHICH CONTROLS? | block, MFA, phishing-resistant MFA, compliant device, approved app, terms of use |
| HOW LONG? | session controls, sign-in frequency, persistent browser, CAE |

---

## 4. Explain-it-to-anyone templates

| Topic | To an 8-year-old | To a nontechnical adult | To a technical adult | To a senior technical reviewer |
|---|---|---|---|---|
| Entra ID | The school list that says who can enter each classroom. | The company identity system that knows employees, guests, devices, and apps. | Microsoft cloud directory and identity provider for users, groups, devices, apps, and tokens. | Cloud IdP and directory plane with role assignments, app objects, service principals, conditional policy evaluation, audit logs, and hybrid sync integration. |
| MFA | A password plus a second proof, like a secret knock. | A second check so a stolen password is not enough. | Additional authentication method enforced by auth methods policy, security defaults, or Conditional Access. | Authentication strength and method policy design with TAP, FIDO2/passkeys, Authenticator, CBA, SSPR registration, and risk-based controls. |
| Conditional Access | A rule that says, “You can enter only if it is really you and it is safe.” | Smart access rules based on person, device, location, app, and risk. | Policy engine evaluated during sign-in/token flows to enforce grant and session controls. | Deterministic policy evaluation with assignments, exclusions, conditions, authentication strengths, session controls, CAE, report-only validation, and break-glass safety. |
| PIM | Borrowing the master key only when a teacher approves it. | Admin rights are temporary and recorded instead of always on. | Just-in-time role activation with approval, MFA, justification, duration, and audit history. | Privileged access lifecycle for Entra roles, Azure resources, and groups, reducing standing privilege and producing audit evidence. |
| App registration vs service principal | A game design vs the copy installed in one classroom. | The app blueprint is global; the enterprise app is its local tenant instance. | App registration is the application object; service principal is the tenant-local security principal. | Distinguish app object, SP object, delegated/app permissions, app roles, consent grants, credentials, certificates, managed identities, and workload federation. |
| Access review | Checking if everyone still needs their keys. | A scheduled review to remove stale access. | Governance control where reviewers approve/deny continued access to groups, apps, packages, or roles. | Evidence-producing control with reviewer selection, recurrence, auto-apply, recommendations, exceptions, and audit reporting. |
| SCIM | A robot that adds/removes names from another school’s list. | Automated user provisioning into SaaS apps. | REST provisioning protocol for users/groups with mappings and lifecycle actions. | SaaS lifecycle integration with attribute mapping, PATCH semantics, matching, deprovisioning behavior, quarantine handling, and provisioning logs. |

---

## 5. Production-readiness rules for every lab

Do not call a lab production-ready unless these are documented:

- **Scope:** who, what app/resource, what tenant/subscription, and what exclusions.
- **Least privilege:** exact role or Graph permission required; no permanent Global Admin unless justified.
- **Pilot path:** test group, report-only mode where supported, and measured result.
- **Break-glass:** two cloud-only emergency accounts, excluded from CA, tested, unlicensed, monitored.
- **Rollback:** exact disable/delete/revert steps and how long token/session effects may persist.
- **Monitoring:** sign-in logs, audit logs, provisioning logs, PIM history, alerts, KQL queries, workbook.
- **Evidence:** screenshots are not enough; export JSON/CSV where possible.
- **Cost:** Azure resource SKU, budget alert, deletion command, and owner tag.
- **Customer language:** business risk, user impact, support model, and executive summary.
- **Failure mode:** at least one deliberate failure with verbatim error and root cause.

---

## 6. Two production-style examples

### Example A — Conditional Access hardening

**Customer problem:** remote staff are phished and attackers reuse passwords from unknown countries.

**Production-safe approach:**

1. Create and test two break-glass accounts before policy work.
2. Inventory current policies, named locations, authentication methods, sign-in logs, and excluded users.
3. Build a report-only policy for a pilot group: require MFA or phishing-resistant MFA for risky/admin access.
4. Use What If and sign-in logs to find false positives.
5. Communicate user impact and support path.
6. Move from report-only to on for the pilot, then expand by group.
7. Monitor failures, lockouts, risk events, and helpdesk tickets.
8. Export final policy JSON and write rollback steps.

**Explain-back:** “We did not just turn on MFA. We changed the access decision engine safely: first
observe, then pilot, then enforce, while preserving emergency access and rollback.”

### Example B — OAuth/app consent risk review

**Customer problem:** users can approve third-party apps that read mail or files.

**Production-safe approach:**

1. Inventory enterprise apps, app registrations, owners, credentials, permissions, and consent grants.
2. Separate delegated permissions from application permissions.
3. Identify high-risk permissions such as mail, files, directory, offline access, or broad Graph scopes.
4. Review publisher verification, owners, sign-in activity, and business justification.
5. Configure admin consent workflow and restrict user consent based on policy.
6. Remove stale grants after owner validation.
7. Document the difference between app registration, service principal, managed identity, and workload
   identity federation.

**Explain-back:** “The dangerous part is not that an app exists. The dangerous part is what the tenant
has consented to let that app do, whether anyone still owns it, and whether its credentials can be abused.”

---

## 7. Recall and spaced repetition loop

Use this every night until the exam:

1. **Blank-page recall:** write the four domains and all major subtopics from memory.
2. **One-child explanation:** explain one topic in three sentences with no product jargon.
3. **One-architect explanation:** explain the same topic with implementation details, logs, rollback,
   and failure modes.
4. **One command or portal path:** write where you configure or verify it.
5. **One failure:** write what breaks and what error/log proves it.
6. **One customer value:** write why a buyer cares.
7. **Wrong-answer register:** every missed practice question becomes a rule, not just a corrected answer.

Memory hooks:

- **CA = Signal + Decision + Control + Session.**
- **PIM = Eligible, Activate, Approve, Audit, Expire.**
- **Apps = Object, Principal, Permission, Consent, Credential, Log.**
- **Governance = Request, Approve, Review, Remove, Prove.**
- **Hybrid = Source, Sync, Sign-in, Seamless SSO, Health, Rollback.**

---

## 8. Known repo gaps and how to handle them before August 28

The repo is broad by design and not all folders are complete. For this exam, do **not** try to finish
the entire repo before August 28. Close or consciously defer gaps like this:

| Gap | Exam impact | Action before exam |
|---|---|---|
| Many scaffold topic READMEs outside identity | Low for SC-300 | Defer until after exam |
| 10-day M365 sprint overlaps identity terminology | Medium confusion risk | Treat it as post-SC-300 breadth; do not run it this week |
| SC-300 7-day strategy overlaps SC-300-SPRINT execution | Medium duplication risk | Use strategy for planning, `SC-300-SPRINT/` for commands |
| Azure/Sentinel/SC-200 areas are tempting | Low SC-300, high distraction | Only use Log Analytics/diagnostic settings needed by SC-300 |
| Production environment wording | High safety risk | Never apply trial runbooks to customer tenants without change control, pilot, rollback, and approvals |
