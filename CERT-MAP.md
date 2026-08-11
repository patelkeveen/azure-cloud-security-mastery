# Certification Map

> **Corrected 2026-08-10.** This repo is not an SC-300 repo. It is a **mastery track for Azure cloud
> security roles**, spanning six certifications plus the tooling those roles actually require.
> SC-300 is the *entry point*, not the scope.
>
> Earlier revisions framed `50-security-operations` as an "SC-500 bridge." **That was wrong — it is
> SC-200**, a certification the repo had not been tracking. Corrected below.

---

## The six certifications, and what each is for

| Cert | Role | Status here |
|---|---|---|
| **AZ-900** | Azure Fundamentals | Prereq substrate — cloud concepts, pricing, governance |
| **AZ-104** | Azure Administrator | Prereq — networking, storage, compute, governance, monitoring |
| **SC-900** | Security, Compliance & Identity Fundamentals | Prereq — vocabulary and the product map |
| **SC-200** | ⭐ **Security Operations Analyst** | **Defender XDR, Sentinel, Defender for Cloud, KQL, hunting, IR** |
| **SC-300** | ⭐ **Identity & Access Administrator** | **The current target** |
| **SC-500** | Cloud & AI Security Engineer | Successor to AZ-500 (retires **2026-08-31**) |

⚠ Exam skills outlines change. Verify domain weightings against the current outline before planning
study time; the **mapping** below is stable, the **percentages** are not.

---

## Which repo domain serves which certification

A domain usually serves several certs. That is the point — this is a role track, not six separate
study plans.

| Repo domain | Topics | AZ-900 | AZ-104 | SC-900 | **SC-200** | **SC-300** | SC-500 |
|---|---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `00-foundations` | 7 | ✅ | ✅ | | | | |
| `10-networking` | 14 | ✅ | ✅ | | ○ | ○ | ○ |
| `20-azure-platform` | 11 | ✅ | ✅ | | ○ | ○ | ✅ |
| `30-identity-and-nhi` | 20 | ○ | ✅ | ✅ | ○ | ⭐ | ✅ |
| `35-active-directory-and-hybrid-identity` | 8 | | ✅ | ○ | ○ | ⭐ | ○ |
| `40-microsoft-365-platform` | 13 | | ○ | ✅ | ✅ | ○ | ○ |
| `45-m365-migration-engineering` | 11 | | ○ | | | ○ | |
| `50-security-operations` | 14 | | ○ | ✅ | ⭐ | ○ | ✅ |
| `60-ai-and-secure-ai` | 14 | | | ○ | ○ | ○ | ⭐ |
| `70-operations-and-reliability` | 13 | ○ | ✅ | | ○ | | ○ |
| `75-architecture-and-consulting` | 10 | | ○ | | | ○ | ○ |
| `80-customer-scenarios` | 9 | | | | ○ | ○ | ○ |

⭐ = core for that exam · ✅ = substantially tested · ○ = touched or assumed

---

## What this changes

**1. `50-security-operations` is a certification domain in its own right.**
The seven topics written there — KQL, Sentinel, Defender for Identity, Defender for Endpoint,
Defender for Cloud Apps, threat hunting, incident response — are **SC-200 core**, not supporting
material for something else. The remaining seven complete an exam domain.

**2. SC-200 and SC-300 are complementary, and the pairing is the actual job.**
SC-300 builds the identity plane; SC-200 detects and responds when it is attacked. Most "Azure cloud
security engineer" roles want both, and very few candidates have both. Someone who can configure
Conditional Access **and** hunt the sign-in logs afterwards is a materially different hire.

**3. The prerequisite claim is now testable rather than asserted.**
`10-networking` is not general interest — DNS, TLS and private endpoints are AZ-104 content that
SC-300 and SC-200 both silently assume. The completed networking domain serves three exams.

---

## Suggested order, given the SC-300 goal

```
NOW      35-active-directory-and-hybrid-identity  ✅ complete (8/8)
         10-networking                            ✅ complete (14/14)
              │  both are prerequisite substrate for everything below
              ▼
NEXT     30-identity-and-nhi     ⭐ SC-300 CORE — 20 topics, currently THIN not DEEP
              │                     the layer documents exist; the topic files do not meet standard
              ▼
THEN     50-security-operations  ⭐ SC-200 — 7 of 14 done
              │
              ▼
THEN     20-azure-platform       AZ-104 + SC-500 (RBAC, Policy, landing zones, IaC)
              │
              ▼
LATER    60-ai-and-secure-ai     ⭐ SC-500 core — 14 topics, all placeholder
```

> ⭐ **The largest gap against the stated goal is `30-identity-and-nhi`.** It is **SC-300 core** —
> the exam being taken first — and its 20 topics are **THIN**: concept prose without worked
> examples, commands with expected output, or verbatim error text. The seven layer documents cover
> the theory; the topic files do not yet meet
> [`CONTENT-STANDARD.md`](CONTENT-STANDARD.md).
>
> Finishing `50-security-operations` closes an exam domain. Upgrading `30-identity-and-nhi` closes
> the gap on **the exam actually being sat first**. That ordering decision belongs to the person
> studying, not to me — but the asymmetry should be visible.

---

## Honest coverage against this map

Regenerate with `tools/Build-CoverageRegister.ps1`; see [`COVERAGE.md`](COVERAGE.md) for the
measured state.

| Domain | DEEP | Of |
|---|---:|---:|
| `35-active-directory-and-hybrid-identity` | **8** | 8 ✅ |
| `10-networking` | **14** | 14 ✅ |
| `50-security-operations` | **7** | 14 |
| `30-identity-and-nhi` | **0** | 20 ⚠ *(20 THIN)* |
| Everything else | **0** | 88 |

**Related:** [`CONTENT-STANDARD.md`](CONTENT-STANDARD.md) ·
[`RETENTION.md`](RETENTION.md) · [`SC-300-MASTERY-SYLLABUS.md`](SC-300-MASTERY-SYLLABUS.md)
