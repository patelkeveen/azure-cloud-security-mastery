# SC-200 Resource Library — what a SOC engineer actually reads

> Companion to `SC-300-RESOURCE-LIBRARY.md`, which covers identity. This one covers operations.
> Built 2026-09-03, **9 days before the exam (Sat 12 Sep 2026)**. Every link verified live that day.
> Sequenced for 9 days, not for a semester. Read "How to sequence 9 days" first and skip the rest
> if you are short on time.

---

## The meta-principle

**The exam no longer tests products. It tests activities. Learn the data, not the blade.**

This is not a stylistic observation — it is a verified structural change. The live study guide reads
*"Skills measured as of July 28, 2026"* and the three domains are:

| Domain | Weight |
|---|---|
| Manage a security operations environment | **40–45%** |
| Respond to security incidents | **35–40%** |
| Perform threat hunting | **20–25%** |

Notice what is *not* there: no "Mitigate threats using Defender for Endpoint" domain, no
"Mitigate threats using Microsoft Sentinel" domain. The old blueprint was a tour of products. The
new one is a tour of *a shift*. **Most SC-200 material on the internet — including video courses
still selling in September 2026 — is organised against the old product-by-product structure.**

The practical consequence: a question does not say *"in Defender for Endpoint, how do you…"*. It
describes a situation and expects you to know **which surface owns the action** and **which table
holds the answer**. So the two things worth memorising are not blade paths:

1. **The table map** — given a question ("did this user run this binary?", "was the mail delivered?"),
   name the table in under three seconds.
2. **The surface map** — given an action ("isolate", "suppress", "tune", "automate"), name where it
   is done and what permission it needs.

Everything below is ordered to build those two maps.

---

## Tier 0 — The blueprint itself

**Read the study guide before any course.** It is the only document that is authoritative about what
is on the exam, it is free, and it is 20 minutes.

| Resource | Why |
|---|---|
| [SC-200 study guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/sc-200) | The skills-measured list *is* the exam outline. It also carries a **change log** showing exactly what the July 2026 revision added and removed — read that table |
| [SC-200 certification page](https://learn.microsoft.com/en-us/credentials/certifications/security-operations-analyst/) | Format, scoring, renewal |
| [Official free practice assessment](https://learn.microsoft.com/en-us/credentials/certifications/security-operations-analyst/practice/assessment?assessment-type=practice&assessmentId=64) | Microsoft-written, free, unlimited. Use it as a **gap finder**, never as a score predictor |

**Exam mechanics** (verified): 100 minutes, ~40–60 questions, scaled score, **700 to pass**,
no penalty for guessing, mark-for-review available, a break is built in. *Answer everything.*

---

## Tier 1 — KQL, which is the whole exam wearing a hat

Threat hunting is 20–25% on paper. In practice KQL runs through all three domains: you tune
analytics rules with it, you triage incidents with it, you build workbooks and detections with it.
**If you have nine days and can only fix one thing, fix KQL.**

| Resource | What it is for |
|---|---|
| [Kusto Query Language reference](https://learn.microsoft.com/en-us/kusto/query/) | The authority. Reference, not tutorial — use it to answer "what are the arguments to `summarize`" |
| [Learn common operators (tutorial)](https://learn.microsoft.com/en-us/kusto/query/tutorials/learn-common-operators) | The one official *pedagogical* KQL doc. Do this end to end |
| [Must Learn KQL — Rod Trent](https://github.com/rod-trent/MustLearnKQL) | 20+ short parts, free, written for SOC people rather than data engineers. The best single KQL learning asset that exists |
| [SentinelKQL — Rod Trent](https://github.com/rod-trent/SentinelKQL) | Query dumps to read as *examples of style* |
| [Sentinel-Queries — Reprise99 (Matt Zorich)](https://github.com/reprise99/Sentinel-Queries) | Written by a Microsoft SOC engineer. Read these for how a professional structures a hunt |

**The operators that carry the exam.** You should be able to write these without lookup:
`where` · `project` / `project-away` · `extend` · `summarize` with `by` · `count()` /
`dcount()` / `make_set()` / `arg_max()` · `join kind=inner|leftouter` · `union` ·
`bin()` for time buckets · `ago()` / `between()` · `let` · `has` vs `contains` vs `==`
(**`has` is token-indexed and fast; `contains` is a substring scan and slow** — that distinction
shows up in performance questions) · `parse_json()` / dynamic field access · `mv-expand`.

> **Drill, don't read.** Open advanced hunting, pick a table, and answer one question per operator
> against real data. Reading KQL produces recognition; writing it produces recall, and the exam
> tests recall.

---

## Tier 2 — The table map

This is the artefact to build. Do it as a single page you can recite. Start from the official
schema references, then compress into your own words.

| Reference | Covers |
|---|---|
| [Advanced hunting overview (Defender XDR)](https://learn.microsoft.com/en-us/defender-xdr/advanced-hunting-overview) | The XDR side: how the schema is organised, quotas, timespans |
| [Azure Monitor table reference](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/) | The Sentinel side: every Log Analytics table, column by column |

**The shape worth memorising** (XDR side): the `Device*` family answers endpoint questions —
`DeviceProcessEvents`, `DeviceNetworkEvents`, `DeviceFileEvents`, `DeviceLogonEvents`,
`DeviceRegistryEvents`, `DeviceImageLoadEvents`. The `Email*` family plus `UrlClickEvents` answers
mail questions. The `Identity*` family answers on-prem/hybrid identity questions.
`CloudAppEvents` answers SaaS questions. `AlertInfo` + `AlertEvidence` join alerts to the entities
in them — **that join is the single most useful two-table pattern in the product**.

**Sentinel side:** `SigninLogs` and `AuditLogs` (Entra), `AzureActivity` (control plane),
`SecurityEvent` (Windows via AMA), `CommonSecurityLog` (CEF), `Syslog`, `SecurityAlert`,
`SecurityIncident`.

---

## Tier 3 — Ranges, where knowledge becomes skill

Reading detections does not teach detection. These are free and hands-on.

| Resource | Why it is worth the evening |
|---|---|
| [**KC7**](https://kc7cyber.com/) | Free gamified KQL threat-hunting range with a real narrative. **The single best time-to-competence asset for SC-200.** You hunt through a synthetic breach in Kusto and it grades you |
| [Microsoft Sentinel Training Lab](https://github.com/Azure/Azure-Sentinel/tree/master/Solutions/Training/Azure-Sentinel-Training-Lab) | Deploys a workspace pre-seeded with incident data. Gets you a working Sentinel without an enterprise tenant |
| [Security-Datasets (OTRF)](https://github.com/OTRF/Security-Datasets) | Pre-recorded telemetry of real attack techniques, mapped to ATT&CK. Ingest and hunt |
| [malware-traffic-analysis.net](https://www.malware-traffic-analysis.net/) | Packet captures with answer keys. Trains the analyst instinct the exam's case studies assume |

> **Tenant expiry warning.** Your E5 trial and Azure lab resource group both expire before the exam
> (07 and 10 Sep). Do the lab-dependent work **first**, in the next week, or you will lose it.

---

## Tier 4 — Detection engineering as a discipline

This is the tier that separates an analyst from an engineer, and it is what an interviewer probes.

| Resource | What it teaches |
|---|---|
| [MITRE ATT&CK](https://attack.mitre.org/) | The shared vocabulary. Every Microsoft alert names techniques; every hunt question is really "which technique" |
| [Azure-Sentinel repo](https://github.com/Azure/Azure-Sentinel) | Microsoft's own production detections and hunting queries. Read `Detections/` and `Hunting Queries/` as **worked examples of the craft** |
| [Microsoft 365 Defender Hunting Queries](https://github.com/microsoft/Microsoft-365-Defender-Hunting-Queries) | XDR-side equivalent |
| [Sigma](https://github.com/SigmaHQ/sigma) | Vendor-neutral detection format. Teaches that a detection is *portable logic*, not a Sentinel rule |
| [detection.fyi](https://detection.fyi/) | Browsable Sigma corpus — fast way to see how a technique is detected across vendors |

**The engineering question to be able to answer out loud:** *"This rule fires 40 times a day and
39 are benign. What do you do?"* The answer is not "suppress it." It is: characterise the benign
population, decide whether to narrow the logic, add an exclusion with an owner and an expiry, or
convert it to a lower-severity hunting query — and then **measure** whether true positives survived.

---

## Tier 5 — Adjacent market, so you can hold a conversation

You are studying this to be hired, not only to pass.

| Category | Microsoft | What the customer probably already owns |
|---|---|---|
| SIEM | Microsoft Sentinel | **Splunk**, Elastic Security, Google SecOps (Chronicle), QRadar |
| EDR/XDR | Defender for Endpoint / XDR | **CrowdStrike Falcon**, SentinelOne, Palo Alto Cortex XDR |
| SOAR | Sentinel automation rules + Logic Apps playbooks | Torq, Tines, Splunk SOAR |
| Case management | Defender portal incidents | ServiceNow SecOps, Jira |
| TIP | Sentinel TI (`ThreatIntelIndicators` / `ThreatIntelObjects`) | Anomali, ThreatConnect, MISP |

**"We already have Splunk — why Sentinel?"** is the single most common real-world question in this
space. Have a real answer that does not insult Splunk: the honest one is data-gravity and licensing,
not features.

---

## How to sequence 9 days

Nine days, employed, with SC-300 six days after this one. This is a triage plan, not a syllabus.

| # | Do this | Time | Why here |
|---|---|---|---|
| 1 | **Study guide + change log** | 30 min | You cannot triage what you have not scoped |
| 2 | **Practice assessment, cold** | 1 hr | A cold baseline is a map of what to study. Do NOT study first |
| 3 | **Must Learn KQL parts 1–10** | 3 hrs | The load-bearing skill |
| 4 | **KC7 — one full scenario** | 3 hrs | Converts KQL reading into KQL writing |
| 5 | **Build the table map, one page, by hand** | 2 hrs | The highest-value artefact you will make this week |
| 6 | **Lab-dependent work in your own tenant** | 4 hrs | **Before 07 Sep** — the trial dies |
| 7 | Incident response flow end to end: triage → investigate → contain → automate | 3 hrs | Domain 2 is 35–40% |
| 8 | Read 20 detections in `Azure-Sentinel/Detections` | 2 hrs | Pattern library for Domain 3 |
| 9 | **Practice assessment again**, then only the misses | 2 hrs | Gap closure, not comfort |
| 10 | Exam-day: last hour on the table map only | 1 hr | Recall, not new material |

**Steps 1–2 before anything else.** Studying before a cold baseline is how people spend nine days
revising what they already knew.

---

## Currency check — the staleness tells

Security operations renames things faster than any other Microsoft surface. If a resource shows any
of these, it predates the current product and **the rest of it is suspect too**:

- **"Azure Sentinel"** → it is *Microsoft Sentinel* (renamed 2021)
- **"Microsoft 365 Defender"** → it is *Microsoft Defender XDR* (renamed 2024)
- **"MCAS" / "Microsoft Cloud App Security"** → *Microsoft Defender for Cloud Apps*
- **"MMA" / "Log Analytics agent"** as current → retired; it is the **Azure Monitor Agent** ([migration guidance](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-migration))
- **A separate Azure portal for Sentinel** presented as the only way → Sentinel now lives inside the **[unified Defender portal](https://learn.microsoft.com/en-us/unified-secops-platform/overview-unified-security)**
- **`ThreatIntelligenceIndicator` only** → the newer `ThreatIntelIndicators` and `ThreatIntelObjects` tables exist alongside it. **Know all three names** — a question can use either
- **A product-by-product course outline** → predates the 28 July 2026 by-activity blueprint
- No mention of the **[Sentinel data lake](https://learn.microsoft.com/en-us/azure/sentinel/datalake/sentinel-lake-overview)** → written before the tiering story changed

**Retention, stated correctly, because it is a common exam trap:** Analytics-tier default retention
is **30 days for both Sentinel and Defender XDR**. The often-quoted "90 days" is the *free extension*
for Sentinel solution tables, not a universal default. Do not carry the folk version into the exam.
