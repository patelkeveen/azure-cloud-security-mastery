# Seven-Day SC-300 E5 + Azure Trial Sprint to Paid Remote Work

> ## ⭐ Read this first — how this file relates to `SC-300-SPRINT/`
>
> The repo now has **two** seven-day SC-300 plans, and their day numbers **conflict** (this file
> puts external identities on Day 4 and PIM on Day 6; [`SC-300-SPRINT/`](../../SC-300-SPRINT/) puts PIM
> on Day 4 and governance on Day 5). ⚠ **Two sources of truth is the exact anti-pattern this repo
> already fixed once** — see the supersession banner on `COMPLETENESS-REGISTER.md`.
>
> **The split, decided 2026-08-12:**
>
> | | This file | [`SC-300-SPRINT/`](../../SC-300-SPRINT/) |
> |---|---|---|
> | Owns | ⭐ **the commercial layer** — buyer problems, offers, pricing, outreach, interview narratives | ⭐ **execution** — runnable scripts, day-by-day labs, evidence capture |
> | Day numbering | ⚠ **superseded** — ignore the day table below for sequencing | ⭐ **authoritative** |
> | Use it for | deciding what to sell and how to reach buyers | deciding what to do tomorrow morning |
>
> ⭐ **Follow `SC-300-SPRINT/` for the schedule. Use this file for everything after the lab.** The
> commercial content here is the genuinely valuable half and does not exist anywhere else in the
> repo — [`feedback-redirect-to-income-not-tooling`] applies: the labs are only worth doing if
> they convert into income.
>
> ### ✅ Verified against Microsoft Learn 2026-08-12 — and what was missing
>
> The exam claims in this document check out: **skills measured as of 27 April 2026**, page
> **updated 27 March 2026**, prerequisites Azure / M365 / AD DS / PowerShell / KQL — all confirmed
> verbatim from the audience profile.
>
> ⭐ **Domain weightings, which this document omits and you should know:**
>
> | Domain | Weight |
> |---|---|
> | Implement and manage user identities | 20–25% |
> | Implement authentication and access management | ⚠ **25–30%** (see note) |
> | Plan and implement workload identities | 20–25% |
> | Plan and automate identity governance | 20–25% |
>
> ⚠ **Microsoft's own page is internally inconsistent**: "Skills at a glance" says **25–30%** for
> authentication and access management, while that section's own heading says **20–25%**. Either
> way it is the **largest or joint-largest** domain — weight your revision accordingly.
>
> ⭐ **Gap in BOTH plans: Global Secure Access is an exam objective** — deploy GSA clients, Private
> Access, Internet Access, and Internet Access for Microsoft 365. Neither this file nor
> `SC-300-SPRINT/` covers it. Added to [`SC-300-SPRINT/DAY-3.md`](../../SC-300-SPRINT/DAY-3.md).
>
> ⚠ **Market figures below ($60–90/hr, the Indeed/Dice/LinkedIn observations) are NOT verified.**
> They are plausible and they are unsourced. Treat them as a hypothesis to test with your own
> outreach, not as a rate card — [`feedback-verify-dates-and-current-data`].
>
> ⚠ The directory layout proposed below (`portfolio/`, `labs/sc-300/`, `incidents/`,
> `customer-delivery/`) is a **third** structure. The repo already files evidence into the
> **six facets** per topic (`lab`, `break-fix`, `security`, `operations`,
> `architecture-decisions`, `customer-use-cases`) via
> [`SC-300-SPRINT/New-LabEvidence.ps1`](../../SC-300-SPRINT/New-LabEvidence.ps1). **Use the facets.**
> The customer-facing deliverables in this file map cleanly onto `customer-use-cases/`.

---

> **Mission:** use the Microsoft 365 E5 trial and Azure trial credits to become **SC-300-ready,
> job-interview-ready, and contract-offer-ready in seven days**. The sprint is designed for a Senior
> IAM / Identity Engineer positioning: Microsoft Entra ID, Conditional Access, Identity Governance,
> workload identities, Microsoft 365 security, evidence automation, and customer delivery.
>
> **Verified exam baseline:** Microsoft Learn SC-300 study guide, skills measured as of
> **2026-04-27**; page last updated **2026-03-27**. Microsoft states the role designs,
> implements, operates, troubleshoots, monitors, and reports identity and access using Microsoft
> Entra; prerequisites include Azure, Microsoft 365, AD DS, PowerShell, and KQL.
>
> **Market baseline checked 2026-08-12:** current remote postings repeatedly ask for Entra ID,
> Active Directory or hybrid identity, SSO, MFA, Conditional Access, RBAC/PIM, identity governance,
> app integrations, monitoring/SIEM, PowerShell, Microsoft 365 security, Defender, Purview, Intune,
> documentation, and client-facing troubleshooting. Contract rates visible in public postings cluster
> around **USD $60-$90/hour** for Microsoft Entra/IAM contract work, with higher rates requiring
> senior troubleshooting, architecture, regulated-customer delivery, or multi-tenant consulting.
>
> **Official SC-300 source:** <https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/sc-300>

---

## The money thesis

You do not get paid for memorizing SC-300. You get paid for reducing identity risk and operational
pain quickly. In 2026, the high-value buyer problems are:

1. **Remote workforce risk:** phishing-resistant MFA, Conditional Access, device compliance,
   risky sign-in response, break-glass safety, and executive protection.
2. **Audit and cyber-insurance pressure:** access reviews, PIM, least privilege, evidence exports,
   policy documentation, Secure Score improvement, and SOC 2 / ISO 27001 / NIST-aligned controls.
3. **SaaS sprawl and startup growth:** SSO, SCIM provisioning, app registrations, consent governance,
   JML automation, guest lifecycle, and non-human identity inventory.
4. **Nonprofit underconfiguration:** donated or discounted Microsoft 365 tenants often have weak MFA,
   stale guests, excessive Global Admins, unmanaged sharing, no logging story, and limited IT staff.
5. **Incident response:** compromised accounts, legacy authentication, OAuth consent abuse, risky
   admin behavior, and missing sign-in/audit log retention.

Your seven-day output must therefore be a **sellable identity security assessment and remediation
kit**, not just a study notebook.

### Current market signals to mirror in your proof

Public remote-role samples checked on 2026-08-12 show these repeated asks:

- Indeed remote Entra ID listings: hybrid identity, Entra ID, AD, SSO, MFA, Conditional Access,
  SAML/OAuth/OIDC, RBAC, PIM, access reviews, monitoring, SIEM, documentation, and federal or
  Zero Trust alignment.
- Dice remote Entra ID listings: senior consulting, Microsoft Entra ID, Active Directory, hybrid
  administration, Saviynt/IGA adjacency, and hourly rates shown around USD $60-$90 for some roles.
- LinkedIn contract-style M365 security listings: Entra ID, Conditional Access, Zero Trust, Defender,
  Purview, Secure Score, and Intune as common bundled expectations.
- Microsoft nonprofit security pages: nonprofits need identity, device, app, data, and AI security,
  making low-cost E5 hardening and adoption a practical solo-consulting wedge.

---

## Target roles and offer angles

| Buyer / role | What they care about | Proof you must show by day 7 | Pitch angle |
|---|---|---|---|
| Remote Senior IAM Engineer | Entra ID, AD DS, SSO, MFA, CA, PIM, governance, tickets, documentation | Tenant baseline, CA policies, PIM/access review evidence, KQL investigations | “I can operate and harden Microsoft identity while documenting every control.” |
| Microsoft 365 Security Engineer | M365 E5 security posture, Defender, Purview, Intune adjacency, Secure Score | Secure Score before/after, identity-risk backlog, Defender/Purview control map | “I turn E5 licensing into measurable security outcomes.” |
| Startup fractional IT/security lead | Speed, low ceremony, SaaS onboarding/offboarding, audit readiness | JML workflow, app/consent inventory, access package, SOC 2 evidence register | “I can get you investor/customer-audit ready without enterprise overhead.” |
| Nonprofit M365 security consultant | Low budget, donated licensing, high phishing risk, limited staff | MFA/CA rollout plan, guest cleanup, admin reduction, simple SOPs | “I secure your mission with practical Microsoft 365 controls your team can run.” |
| Contract Entra specialist | Clear scope, fast delivery, no hand-holding | Fixed-price packages, runbooks, screenshots, Graph exports | “I deliver a defined identity-hardening outcome in one to two weeks.” |

---

## Non-negotiable operating model

1. **Spend control first.** Create an Azure budget alert before deploying anything; delete all paid
   Azure resources at the end of each lab day unless they are needed for tomorrow's evidence.
2. **One production-grade lab tenant story.** Treat the E5 tenant as a customer: executives,
   helpdesk, HR, engineering, finance, external partners, break-glass, privileged admins, SaaS apps,
   workload identities, and audit requirements.
3. **Evidence or it did not happen.** Each day ends with screenshots or exports, command history,
   before/after state, failure notes, rollback, and a one-page customer explanation.
4. **Portal + PowerShell + Graph.** For every major control, do it once in the portal, inspect or
   repeat it with Microsoft Graph PowerShell, and record the least-privilege permission used.
5. **No resume inflation.** Claims become resume-proof only after the exact artifact exists in
   `portfolio/`, `labs/`, `incidents/`, or `customer-delivery/`.
6. **Every lab becomes a sales asset.** Package the output as a customer deliverable: assessment,
   remediation plan, SOP, detection query, executive summary, or fixed-scope service.

---

## Seven-day pass, job, and contractor readiness plan

| Day | SC-300 domain focus | Build in the E5/Azure trial | Evidence that proves resume value | Monetizable deliverable |
|---|---|---|---|---|
| 1 | Tenant, roles, users, groups, domains, licenses | Baseline tenant; admin units; custom role; users/groups; license assignment report; emergency access accounts; budget alert | Tenant baseline report, role matrix, break-glass SOP, cost-control screenshot/export | “M365/Entra tenant baseline and admin-risk assessment” |
| 2 | Authentication methods, SSPR, MFA, passwordless, device registration | Auth methods policy; Temporary Access Pass; FIDO2/passkey plan; SSPR; password protection; device settings | Authentication rollout plan, test matrix, failed sign-in analysis, user comms template | “Phishing-resistant MFA and SSPR rollout plan” |
| 3 | Conditional Access, session controls, CAE, ID Protection | Named locations; report-only CA; require phishing-resistant MFA for admins; block legacy auth; risky sign-in/user remediation | CA policy design sheet, What If results, sign-in logs, rollback plan | “Conditional Access hardening pack” |
| 4 | External identities, cross-tenant access, lifecycle | B2B collaboration settings; guest invite; access package for partner; lifecycle expiration; cross-tenant sync design | Partner onboarding runbook, guest governance evidence, ToU/access package exports | “External collaboration and guest cleanup project” |
| 5 | Workload identities, app registrations, enterprise apps, consent, MDCA | App registration; service principal; delegated vs application permission demo; admin consent workflow; OAuth app review; managed identity to Key Vault | Token/JWT explanation, consent risk register, app access review, NHI inventory | “OAuth/app consent and non-human identity risk review” |
| 6 | PIM, access reviews, entitlement management, logs/KQL | PIM for Entra roles; PIM for groups; access reviews; diagnostic settings to Log Analytics; KQL workbook queries | Privileged access model, review results, KQL detections, audit-ready evidence pack | “PIM/access review/SOC 2 evidence implementation” |
| 7 | Mock exam + incident/customer defense | Full SC-300 practice assessment; timed weak-domain drill; identity incident tabletop; executive readout; cleanup | Final gap register, architecture diagram, incident RCA, portfolio index, cleanup proof | “Identity incident tabletop and executive risk readout” |

---

## Daily rhythm

### Morning: exam precision

- Read only the Microsoft Learn objectives for that day's domain.
- Convert each bullet into: **what it is, why it exists, how to configure it, how it fails, how to
  prove it works, and how to roll it back**.
- Do 20-30 practice questions only after the concept map is written; update the gap register.

### Afternoon: tenant implementation

- Build the feature in the E5 tenant or Azure trial.
- Export configuration through Graph PowerShell where possible.
- Generate at least one failure condition intentionally, such as a blocked CA sign-in, missing
  consent, unlicensed user, stale guest, or PIM activation denied by policy.

### Evening: job-ready packaging

- Write a short customer-facing explanation.
- Write an operator SOP.
- Capture screenshots/exports.
- Add a resume-proof bullet only if the artifact exists.
- Convert the day into one LinkedIn post, one portfolio artifact, and one outreach paragraph.

---

## Resume-proof evidence backlog

Create or update these artifacts during the sprint:

- `portfolio/sc-300-evidence-index.md` — links every resume claim to screenshots, exports, scripts,
  and runbooks.
- `portfolio/offer-menu-identity-security.md` — fixed-scope service menu for startups, nonprofits,
  and remote contract buyers.
- `portfolio/outreach-target-list.md` — target buyer list, pain point, offer, contact channel,
  follow-up date, and status.
- `labs/sc-300/tenant-baseline/` — tenant configuration, users, groups, roles, licenses, and budget.
- `labs/sc-300/conditional-access/` — CA design, report-only output, What If tests, sign-in logs,
  rollback commands.
- `labs/sc-300/workload-identities/` — app registration, service principal, managed identity,
  Key Vault access, token notes.
- `labs/sc-300/governance/` — PIM, access reviews, entitlement management, external user lifecycle.
- `incidents/sc-300-identity-compromise-tabletop.md` — detection, containment, eradication,
  recovery, lessons learned.
- `customer-delivery/sc-300-executive-readout.md` — one-page business summary for a CIO/CISO.
- `customer-delivery/nonprofit-m365-security-assessment-template.md` — lightweight assessment that
  maps nonprofit risk to practical Microsoft 365 controls.
- `customer-delivery/startup-identity-audit-sow.md` — statement of work for a one-week startup
  identity hardening engagement.

---

## Fixed-scope offers to sell after day 7

These are small enough for a solo contractor and concrete enough for startups or nonprofits to buy.
Adjust pricing by market, urgency, and buyer size.

| Offer | Duration | Output | Buyer | Suggested positioning |
|---|---:|---|---|---|
| Entra/M365 Security QuickScan | 2-3 days | Secure Score snapshot, Global Admin review, MFA/CA gaps, guest/app risk list, top 10 remediation plan | Nonprofits, startups, small SaaS | Low-friction assessment before audit, renewal, or board review |
| Conditional Access Hardening Sprint | 3-5 days | Report-only policies, What If tests, staged rollout plan, break-glass SOP, rollback | Any remote-first org | Reduce account-takeover risk without locking users out |
| PIM and Admin Least Privilege Sprint | 3-5 days | Role inventory, PIM activation settings, admin unit model, access review | Regulated startups, nonprofits with board oversight | Replace standing admin access with auditable just-in-time access |
| SaaS SSO + SCIM Onboarding | 2-5 days per app | SAML/OIDC SSO, SCIM provisioning, group assignment, test evidence, admin handover | Startups with app sprawl | Faster onboarding/offboarding and fewer orphaned accounts |
| Identity Incident Readiness Tabletop | 1-2 days | Compromise scenario, containment runbook, KQL queries, executive readout | Lean security teams | Know exactly what to do when an account is compromised |
| SOC 2 Identity Evidence Pack | 5-10 days | Access-control evidence, JML process, access reviews, privileged access evidence | SaaS startups | Turn Entra controls into auditor-ready proof |

---

## Outreach engine for global remote work

Run this every day during the sprint, even before you feel ready. The goal is signal generation.

1. **Build a list of 25 targets per day.** Mix remote IAM postings, Microsoft partners, MSPs,
   nonprofit technology providers, fractional CTOs, cybersecurity recruiters, and funded startups.
2. **Send 10 highly specific messages per day.** Lead with one problem you can solve, not your need
   for a job.
3. **Post one artifact daily.** Examples: Conditional Access rollout checklist, PIM decision tree,
   guest cleanup risk model, OAuth consent attack explainer, KQL sign-in investigation.
4. **Offer a diagnostic call.** “I can review your Entra/M365 identity posture and send a prioritized
   top-five risk list.”
5. **Track every conversation.** Use `portfolio/outreach-target-list.md`; follow up after 2, 5, and
   10 business days.

### Outreach message template

> Hi `<Name>` — I noticed `<company/nonprofit>` is likely dealing with remote workforce and Microsoft
> 365 identity risk: MFA rollout, Conditional Access, guest access, app consent, and admin privilege.
> I recently built a practical Entra ID evidence pack covering CA, PIM, access reviews, workload
> identities, KQL sign-in investigation, and audit-ready documentation. If useful, I can do a small
> fixed-scope Entra/M365 QuickScan and send a top-five risk/remediation summary. Would a 20-minute
> call next week be useful?

---

## Interview and contract proof narratives

Prepare these seven stories from your artifacts:

1. **Account compromise:** how you detect suspicious sign-ins, revoke sessions, reset auth methods,
   review OAuth grants, preserve logs, and prevent recurrence.
2. **Conditional Access rollout:** how you avoid lockouts using report-only, exclusions, What If,
   break-glass accounts, pilot groups, and rollback.
3. **Privileged access:** why standing Global Admin is dangerous; how PIM, admin units, role groups,
   access reviews, and alerts reduce blast radius.
4. **Workload identity:** difference between app registration and service principal; delegated vs
   application permissions; secret rotation vs managed identity vs workload identity federation.
5. **External collaboration:** guest lifecycle, cross-tenant access, terms of use, access packages,
   owner accountability, and stale guest cleanup.
6. **Audit evidence:** how SC-300 controls map to SOC 2, ISO 27001, NIST SP 800-171, and customer
   assurance without claiming unverified compliance.
7. **Business communication:** how to explain identity risk to a CEO, CFO, auditor, helpdesk, and
   engineer differently.

---

## Azure trial credit guardrails

Use Azure credits only for SC-300-relevant infrastructure:

- Log Analytics workspace for Entra diagnostic settings and KQL.
- Key Vault for managed identity and secret governance labs.
- One minimal VM or App Service only if needed for managed identity or Application Proxy-style
  architecture explanation; shut it down or delete it immediately after evidence capture.
- Storage account only for diagnostic export or evidence retention tests.

Avoid Kubernetes, premium networking, high-SKU databases, GPU, always-on VMs, and anything not tied
explicitly to SC-300 evidence.

---

## Passing bar on day 7

You are ready to schedule SC-300 and sell small identity engagements when all are true:

- Microsoft Learn practice assessment is consistently above 85% with explanations for wrong answers.
- You can draw the four SC-300 domains from memory and map each domain to a tenant artifact.
- You can explain Conditional Access evaluation, token issuance, refresh/revocation, and CAE without
  notes.
- You can create and defend an app registration permission model, including why admin consent is
  dangerous.
- You can operate PIM, access reviews, entitlement management, and logs/KQL as an audit story.
- Your portfolio index proves at least five Senior IAM resume claims with artifacts.
- You have one offer menu, one assessment template, one SOW, one executive readout, and at least 50
  targeted outreach attempts logged.
