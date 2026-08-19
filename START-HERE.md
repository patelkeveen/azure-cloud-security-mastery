# Start Here

> ⭐ **This is the map.** What is where, why it exists, and when to read it. Everything else in this
> repo is reachable from here in two clicks.
> **Last revised 2026-08-18.**

---

## 1. ⭐ Know what is real before you trust anything

```powershell
.\tools\Build-CoverageRegister.ps1
```

[`COVERAGE.md`](COVERAGE.md) is **generated from the filesystem** — it cannot overstate the
repository. Two independent measures, and ⭐ **conflating them is how 123 placeholder topics once
went unnoticed:**

| Measure | Today | Means |
|---|---|---|
| ⭐ **Depth** | ⭐ **144/144 DEEP** | every topic teaches its concept, with worked examples |
| ⭐ **Evidence** | ⭐ **0/144 WRITTEN** | ⭐ **no lab artifacts exist yet** |

⭐ **So: everything here has been written; nothing here has been performed.** That is the honest
state, and closing the second gap is the current work — see §6.

---

## 2. ⭐ The reading spine — seven Layers, in order

⭐ **If you read nothing else, read these.** Each assumes the previous.

| Layer | Document | Why |
|---|---|---|
| 1 | [Identity protocols](30-identity-and-nhi/oauth-oidc-saml-and-api-auth/LAYER-1-IDENTITY-PROTOCOLS.md) | ⭐ OAuth, OIDC, SAML, SCIM, consent. ⭐ **Nothing downstream makes sense first — and it is in no Microsoft study guide** |
| 2 | [User identities](30-identity-and-nhi/entra-users-and-groups/LAYER-2-DOMAIN-1-USER-IDENTITIES.md) | tenant, identities, external, hybrid |
| 3 | [Authentication & Conditional Access](30-identity-and-nhi/conditional-access/LAYER-3-DOMAIN-2-AUTH-AND-ACCESS.md) | ⭐ largest exam domain; where the daily job lives |
| 4 | [Workload identities](30-identity-and-nhi/service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md) | ⭐ app/SP model, managed identities, secretless federation |
| 5 | [Identity governance](30-identity-and-nhi/pim-and-access-reviews/LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md) | entitlement management, PIM, access reviews, KQL |
| 6 | [SC-500 bridge — AI security](60-ai-and-secure-ai/ai-agent-identity/LAYER-6-SC500-BRIDGE-AI-SECURITY.md) | ⭐ Entra Agent ID; ⭐ an agent is an NHI you can talk into things |
| 7 | [Industry verticals](80-customer-scenarios/LAYER-7-INDUSTRY-VERTICALS.md) | nine sectors: driver, design, trap |

---

## 3. ⭐ The twelve domains — what each is for, and when

⭐ **Every domain README carries its own reading order, one line per topic, and a generated state
table.** That is the navigation layer; use it.

**Before the main event**
[`00-foundations/`](00-foundations/) — ⭐ read once, first ·
[`10-networking/`](10-networking/) — before Azure ·
[`20-azure-platform/`](20-azure-platform/) — ⭐ RBAC is a union, Policy is an intersection

**⭐ The main event**
⭐ [`30-identity-and-nhi/`](30-identity-and-nhi/) — Layers 1–5 ·
[`35-active-directory-and-hybrid-identity/`](35-active-directory-and-hybrid-identity/) — ⭐ the deepest well of real-world work ·
[`40-microsoft-365-platform/`](40-microsoft-365-platform/) — where users actually live

**Doing the job**
⭐ [`45-m365-migration-engineering/`](45-m365-migration-engineering/) — ⭐ the most employable domain ·
[`75-architecture-and-consulting/`](75-architecture-and-consulting/) — ⭐ turns labs into engagements ·
[`80-customer-scenarios/`](80-customer-scenarios/) — nine verticals ·
[`70-operations-and-reliability/`](70-operations-and-reliability/) — ⭐ read the monitoring topics **before** your first lab

**The next certifications**
[`50-security-operations/`](50-security-operations/) — ⭐ SC-200 ·
[`60-ai-and-secure-ai/`](60-ai-and-secure-ai/) — ⭐ SC-500

⭐ **Priority order for this track: SC-300 → SC-200 → SC-500.**

---

## 4. ⚠ Six names that mean two different things

⭐ **Answering the wrong one in an interview is a real failure. Ask which they mean.**

| Name | One place | The other |
|---|---|---|
| ⭐ **Change management** | [`75-`](75-architecture-and-consulting/change-management/) = **adoption**, ADKAR | [`70-`](70-operations-and-reliability/change-management/) = **change control**, RFC/CAB |
| ⭐ **Discovery** | [`75-`](75-architecture-and-consulting/discovery/) = people, drivers, decision rights | [`45-`](45-m365-migration-engineering/discovery-and-assessment/) = estate inventory |
| ⭐ **Runbooks** | [`75-`](75-architecture-and-consulting/sop-and-runbooks/) = handed to the customer | [`70-`](70-operations-and-reliability/runbooks/) = internal + automated |
| ⭐ **Cutover** | [`75-`](75-architecture-and-consulting/cutover-playbooks/) = who decides | [`45-`](45-m365-migration-engineering/cutover-and-rollback/) = the mechanism |
| ⭐ **Root cause** | [`70-`](70-operations-and-reliability/root-cause-analysis/) = the retrospective | [`00-`](00-foundations/troubleshooting-method/) = the live technique |
| ⭐ **"Break the glass"** | ⭐ clinical = **patient record** access, in the EHR | identity = two Entra emergency accounts |

---

## 5. ⭐ You need a tenant. Reading without one produces recall, not capability

```powershell
.\30-identity-and-nhi\entra-users-and-groups\Seed-LabTenant.ps1          # plan (dry run)
.\30-identity-and-nhi\entra-users-and-groups\Seed-LabTenant.ps1 -Apply   # build
```

Seeds 16 users with a manager chain, dynamic groups, a break-glass pair and a lab app registration
— ⭐ enough for access reviews, PIM and dynamic-membership labs to *mean* something.

⭐ **Then check yourself, any time, without asking anyone:**

```powershell
.\SC-300-SPRINT\Invoke-SprintCheck.ps1
```

⭐ **Every FAIL prints its own fix.** Anything unexpected: [`SC-300-SPRINT/TROUBLESHOOTING.md`](SC-300-SPRINT/TROUBLESHOOTING.md).

---

## 6. ⭐ The current gap: evidence

A topic is **WRITTEN** only when ⭐ **three of these six folders carry real artifacts:**

| Facet | Contains |
|---|---|
| `lab/` | reproducible build, commands, expected output |
| `break-fix/` | ⭐ a failure caused **on purpose**, diagnosed, fixed |
| `security/` | threat model, attack path, hardening, detection |
| `operations/` | monitoring, alerting, runbook, rollback |
| `customer-use-cases/` | two or more industry scenarios, ⭐ with the trap named |
| `architecture-decisions/` | ⭐ the trade-off, the alternatives, why this one |

⭐ **Capture as you go**, or you will not go back:

```powershell
.\SC-300-SPRINT\New-LabEvidence.ps1
```

⭐ **The 7-day runnable track is [`SC-300-SPRINT/`](SC-300-SPRINT/)** — day files, an official-lab
map, a self-check and a troubleshooting guide. ⭐ **Start with [`DAY-1.md`](SC-300-SPRINT/DAY-1.md)**;
[`DAY-2.md`](SC-300-SPRINT/DAY-2.md) is the merged-runbook exemplar.

---

## 6b. ⚠ There is an exam on 2026-08-28. That changes the order

⭐ **Evidence capture is deferred until 29 August.** Between now and the exam, three files govern:

| File | What it does |
|---|---|
| ⭐ [`SC-300-SPRINT/EXAM-COUNTDOWN.md`](SC-300-SPRINT/EXAM-COUNTDOWN.md) | ⭐ **the date-anchored plan** — lab triage, the daily drill, two revision days |
| ⭐ [`SC-300-SPRINT/GAP-DRILL.md`](SC-300-SPRINT/GAP-DRILL.md) | ⭐ **what the labs never cover and the exam tests** — AUs, hybrid identity, connected orgs, cross-tenant access |
| [`SC-300-SPRINT/EXAM-DAY.md`](SC-300-SPRINT/EXAM-DAY.md) | question formats, time budget, the morning of |

⚠ **The Azure subscription that appeared on 2026-08-19 is not SC-300 material.** Sentinel is
SC-200, Foundry is SC-500. ⭐ **Neither scores a mark on 28 August.**

---

## 7. ⭐ How to actually remember it

[`RETENTION.md`](RETENTION.md) is the interleaved memory layer — numbers, mnemonics, load-bearing
analogies, symptom→cause reflexes and interview answers. ⭐ **It covers four of the twelve domains so
far; the rest have their own § Remember it and § Self-test.**

⭐ **Three rules, and they are the whole method:**

1. ⭐ **Cover the answer column and say it out loud.** Recognition is not recall.
2. ⭐ **Interleave.** Jump between domains. It feels worse and works better.
3. ⭐ **Space it.** Same day, next day, three days, a week.

> ⭐ **The single best technique for this material: explain the mechanism to an imaginary junior
> engineer, out loud, without notes.** ⭐ **Every place you say "and then it sort of…" is a gap** —
> and that is the same test an interviewer applies.

---

## 8. The honesty rule

⭐ **Do not claim a tool, migration or workload is mastered until this repo contains personally
verified evidence.** Research is valuable and must be labelled as research.

⭐ **The corollary, which is easier to violate: do not let structure imply coverage.** A written
README is a plan for a lab. [`COVERAGE.md`](COVERAGE.md) exists so the difference stays visible, and
it is generated so it cannot flatter.

**The standard everything is written to:** [`CONTENT-STANDARD.md`](CONTENT-STANDARD.md) ·
**exemplar:** [`35-active-directory-and-hybrid-identity/entra-connect-sync/`](35-active-directory-and-hybrid-identity/entra-connect-sync/)
