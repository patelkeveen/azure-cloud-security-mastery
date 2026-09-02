# Terraform Resource Library — and the artifact that makes the quarter work

> Built 2026-09-03. Every link verified live that day.
> This exists because a search of `C:\IT` found **no Terraform material at all** — while K-WIN §1.4
> names Terraform as the quarter's single committed skill, with an artifact due **30 Sep 2026**.
> 27 days, employed, with two exams in between. So this is not a syllabus. It is a shipping plan
> with the reading attached.

---

## First: the version correction

**The current exam is Terraform Associate (004), not 003.** `developer.hashicorp.com/terraform/tutorials/certification-003`
now **redirects** to `…/certification-004`. Anything you find that says "003" is a version behind,
and most third-party courses still say 003.

Verified from HashiCorp's certification page on 2026-09-03:

| | Terraform Associate (004) |
|---|---|
| Format | Multiple choice, online proctored |
| Duration | **1 hour** |
| Price | **$70.50 USD** + local tax |
| Language | English |
| **Product version tested** | **Terraform 1.12** |

The version tested matters more than it looks: material written against Terraform 0.x or early 1.x
predates `moved` blocks, `import` blocks, `check` blocks, and provider-defined functions. That is
most of the free content on the internet.

### But you probably should not sit it this quarter

§1.4 commits you to shipping an **artifact**, not to collecting a certificate. You already have two
exams booked and paid inside 15 days. A third exam would be the third cert this quarter and the
*first* thing to be cut when the evenings run out.

**The artifact is the deliverable. The cert is optional and almost certainly wrong for Q3.**
Revisit it in Q4 if a job description demands it — and by then the artifact below is your study
material, which is the right order anyway.

---

## The leverage point: one artifact, two objectives

There is a real conflict on the board. `kno1` (Terraform artifact, 30 Sep) and `rep1` (clean-room
SOC 2 evidence collector, 30 Sep) are due the same day and draw on the same six-to-eight evenings.
The plan's own rule (§1.4: the quarter's skill gets priority) says Terraform wins and the repo slips.

**That is a false choice, and taking it would be the expensive mistake.** The two deliverables can be
the same deliverable:

> ### `terraform-azure-evidence-vault`
> **The Azure landing zone that the clean-room evidence collector writes into.**

The collector (see [`SOC2-CLEANROOM-SPEC.md`](../OS/UI/plan/SOC2-CLEANROOM-SPEC.md)) produces
evidence files and a `New-EvidenceManifest` index with a SHA-256 per file. A hash proves a file has
not changed *since you hashed it*. It does not prove the file could not have been changed. The thing
that closes that gap is **immutable (WORM) blob storage** — and standing that up correctly, with
least-privilege identity and audit logging, is exactly a Terraform job.

**Hash + WORM = a tamper-evident evidence chain.** That is the sentence that makes the consulting
offer credible to an auditor, and neither half delivers it alone.

### What the module actually contains

Every resource here is real, current, and documented — links go to the exact `azurerm` resource page.

| Component | Why an auditor cares | Reference |
|---|---|---|
| Resource group + tagging convention | Scope and ownership | [azurerm docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) |
| Storage account, versioning on | Evidence lands somewhere durable | [Immutable storage overview](https://learn.microsoft.com/en-us/azure/storage/blobs/immutable-storage-overview) |
| **Container immutability policy (WORM)** | **Evidence cannot be altered or deleted inside the retention window** — the differentiator | [`azurerm_storage_container_immutability_policy`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container_immutability_policy) · [time-based policy config](https://learn.microsoft.com/en-us/azure/storage/blobs/immutable-policy-configure-container-scope) |
| Key Vault for collector secrets | No credentials in code | [`azurerm_key_vault`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) |
| User-assigned managed identity + **scoped role assignments** | Least privilege, provably | [`azurerm_role_assignment`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) |
| Log Analytics workspace + diagnostic settings | Who touched the evidence store | Azure Monitor docs |
| Scheduled runner (Container App Job) | Evidence collection on a cadence, not by hand | [`azurerm_container_app_job`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app_job) |
| **Remote state in Azure Storage** | You practise what you preach about state | [Backend: azurerm](https://developer.hashicorp.com/terraform/language/backend/azurerm) · [MS guidance](https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage) |

**This is also a near-complete tour of the 004 exam objectives** — providers, state and backends,
variables and outputs, module authoring and composition, data sources, `for_each`, lifecycle rules,
and secret handling. You learn the exam by building the artifact, not instead of it.

### Why this is the right artifact rather than a tutorial repo

A `terraform-azure-webapp` demo proves you followed a tutorial. This one proves you understood a
*problem domain* that you are already selling into — and it is the only Terraform artifact you could
build that makes `rep1` and `fin_stream1` more likely to land rather than less.

---

## Tier 0 — The language, from the source

HashiCorp's docs are unusually good. There is no reason to learn Terraform from a video.

| Resource | Use it for |
|---|---|
| [Terraform language docs](https://developer.hashicorp.com/terraform/language) | The reference. Configuration syntax, expressions, functions, meta-arguments |
| [State](https://developer.hashicorp.com/terraform/language/state) | **Read this properly.** State is where every real Terraform incident begins |
| [CLI commands](https://developer.hashicorp.com/terraform/cli/commands) | `plan` / `apply` / `import` / `state mv` / `taint` semantics |
| [Module development](https://developer.hashicorp.com/terraform/language/modules/develop) | Inputs, outputs, composition — this is what separates a script from an artifact |
| [azurerm provider registry](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) | The provider reference you will live in |

---

## Tier 1 — Azure-specific, because that is the cloud that pays you

§1.4 says "on the cloud that pays you." Generic AWS-flavoured Terraform content is a detour.

| Resource | Use it for |
|---|---|
| [Terraform on Azure (Microsoft Learn)](https://learn.microsoft.com/en-us/azure/developer/terraform/) | Microsoft's own hub — the authoritative Azure-side view |
| [Authenticate Terraform to Azure](https://learn.microsoft.com/en-us/azure/developer/terraform/authenticate-to-azure) | Service principal vs managed identity vs Azure CLI. **The security question in every Terraform interview** |
| [Store state in Azure Storage](https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage) | Remote state with locking, done properly |
| [Get started on Azure (HashiCorp)](https://developer.hashicorp.com/terraform/tutorials/azure-get-started) | The official Azure tutorial track |
| [**Azure Verified Modules**](https://azure.github.io/Azure-Verified-Modules/) | Microsoft's own module standard. **Read AVM before writing your module** — matching its interface conventions is free credibility |
| [AVM Key Vault module (example)](https://github.com/Azure/terraform-azurerm-avm-res-keyvault-vault) | A production-grade module to read as a worked example of structure |

---

## Tier 2 — Craft, so the artifact does not read like a first attempt

| Resource | What it teaches |
|---|---|
| [terraform-best-practices.com — Anton Babenko](https://www.terraform-best-practices.com/) | Naming, structure, module layout. The de facto community reference |
| [Its GitHub source](https://github.com/antonbabenko/terraform-best-practices) | Same content, diffable, with issues showing where opinions changed |

**The three judgements a reviewer looks for**, and none of them are syntax:

1. **Module boundaries.** A module should have one reason to change. A "kitchen sink" module with
   40 variables is a script wearing a costume.
2. **State strategy.** Where does state live, who can read it, what happens when two people apply?
   State contains secrets in plaintext — that is why the backend needs the same protection as the
   resources it describes.
3. **What you refuse to manage.** Mature Terraform code has explicit `lifecycle { ignore_changes }`
   and a written note on what is deliberately out of band. Pretending Terraform owns everything is
   the classic tell of inexperience.

---

## Tier 3 — Exam prep, only if you decide to sit it

| Resource | |
|---|---|
| [Associate Prep (004) collection](https://developer.hashicorp.com/terraform/tutorials/certification-004) | The hub |
| [Associate learning path (004)](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-study-004) | Guided, longer |
| [Associate exam content list (004)](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-review-004) | Objective-by-objective review — **the better one if you already know the material** |
| [Associate sample questions (004)](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-questions-004) | Calibrate question style |

---

## Tier 4 — The fork in the road you should know about

| Resource | Why you need an opinion |
|---|---|
| [OpenTofu](https://opentofu.org/) | The Linux Foundation fork created after HashiCorp's 2023 licence change from MPL to BUSL. It is a drop-in for most Terraform configurations |

This is an interview question, not trivia. **Have a two-sentence answer:** BUSL does not affect
you using Terraform to manage your own or a client's infrastructure — it targets companies selling
competing Terraform-based services. OpenTofu matters when a client has a policy against BUSL
software or wants no single-vendor dependency. Knowing the distinction signals you read licences,
which in compliance consulting is exactly the signal you want to send.

---

## How to sequence 27 days

Two exams sit inside this window (12 and 18 Sep). Realistically Terraform gets the evenings **before
12 Sep in small slices** and then a concentrated run **19–30 Sep**. Plan for that shape rather than
pretending the whole month is available.

| # | Do this | Time | When |
|---|---|---|---|
| 1 | Language docs: configuration, expressions, meta-arguments | 2 hrs | Now, in slices |
| 2 | **State docs, properly** | 1 hr | Now |
| 3 | `terraform init/plan/apply` against a throwaway resource group | 2 hrs | **Before 10 Sep — the lab RG expires** |
| 4 | Remote state in Azure Storage, with locking | 1 hr | Before 10 Sep |
| 5 | *Exams: 12 Sep and 18 Sep. Terraform pauses.* | — | 11–18 Sep |
| 6 | Read the AVM Key Vault module end to end | 1 hr | 19 Sep |
| 7 | **Build `terraform-azure-evidence-vault` v0.1**: RG + storage + WORM container + outputs | 4 hrs | 20–22 Sep |
| 8 | Add managed identity + scoped role assignments + Key Vault | 3 hrs | 23–25 Sep |
| 9 | Add diagnostics, README with an architecture diagram, `terraform-docs` output | 2 hrs | 26–28 Sep |
| 10 | **Ship it public. Wire it to the collector's README.** | 1 hr | 29–30 Sep |

**Steps 7–10 are the artifact.** Steps 1–6 exist to make them possible; if time compresses, cut
reading, not shipping. A public repo that stands up a real evidence vault beats a private folder of
tutorial exercises by an enormous margin, and it is the only version of this work that a client or
a hiring manager can see.

---

## Currency check — the staleness tells

- **"Terraform Associate 003"** → superseded by **004**; the 003 URL redirects
- **`terraform.io` links** → moved to `developer.hashicorp.com` in 2023
- **No mention of BUSL or OpenTofu** → predates August 2023
- **`azurerm` 2.x / 3.x syntax** → the provider has had breaking changes across majors; always read
  the version-pinned page from the registry, not a blog
- **No `required_providers` block** → predates Terraform 0.13
- **Never mentions `moved`, `import` or `check` blocks** → predates the 1.x features the 004 exam
  tests against **Terraform 1.12**
- **"Terraform Cloud"** → rebranded **HCP Terraform**
