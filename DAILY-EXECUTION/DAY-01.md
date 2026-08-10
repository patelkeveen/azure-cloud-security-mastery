# Day 1 — Platform Baseline and Governance

> **This file is the exemplar.** Days 2–10 are written to this standard: real commands with real
> parameters, the permission each needs, what you should see, what breaks and the **actual error
> text**, what it costs, and how to clean up. If a later day drops below this bar, it is unfinished.
>
> **Verification convention used throughout:** `✅ verified` = run and confirmed. `⚠ check` = correct
> to the best of current knowledge but **not** re-verified today — confirm against `az <group> --help`
> or current docs before relying on it. Never paste a `⚠ check` command into a customer tenant unread.

**Outcome:** a governed lab you own, with cost controls, naming discipline, a working toolchain,
and a documented way to destroy everything. Nothing here claims production deployment.

---

## 0. The blocker: you need a tenant

Everything downstream is theoretical without one. This is the whole of Day 1's first hour.

**The advice you will find online is stale.** The Microsoft 365 Developer Program now requires a
Visual Studio Professional/Enterprise subscription (or ISV / partner / Premier standing), and
**personal Microsoft accounts are no longer accepted**. If a guide says "get a free E5 dev
tenant," it predates that change.

Working options:

| Option | Gets you | Watch out for |
|---|---|---|
| **Microsoft Entra ID P2 trial** | CA, PIM, Identity Protection, access reviews, entitlement management | Requires payment details; **auto-converts to paid** |
| **Microsoft 365 E5 trial** | The above **plus** Intune, Defender for Cloud Apps, Purview | Far higher conversion cost if forgotten |
| **Azure free account** | The resource plane — managed identities, Key Vault, Log Analytics | Separate from the above; bind it to the *same* tenant |

**Three decisions to make deliberately, because two are irreversible:**

1. **Tenant country/region is permanent.** It sets data residency and billing currency and can
   never be changed. Signup often defaults to wherever the CDN thinks you are.
2. **Your `*.onmicrosoft.com` prefix is permanent.** Pick something you would screen-share.
3. **Quantity.** Licences are free during the trial, and P2 features only apply to *licensed*
   users — so one licence means your test users are unlicensed and most labs silently do nothing.

**Order matters:** create the M365/Entra tenant **first**, then sign up for Azure *using the admin
account you just made*. Reversing this leaves you with two tenants and an afternoon of untangling.

**Before you click the final button:** set two calendar reminders for ~3 and ~7 days before the
trial ends, titled with the actual cancellation path — *M365 admin center → Billing → Your
products → [subscription] → Cancel subscription*. Future-you at 11pm will not go hunting.

---

## 1. Verify the toolchain

Do not assume an installed tool works. Verify the artifact, not the installer's exit code.

```powershell
az version                                   # ✅ verified
$PSVersionTable.PSVersion                    # ✅ verified — want 7.x, not 5.1
Get-Module Az -ListAvailable | Select-Object -First 1 Name,Version           # ✅
Get-Module Microsoft.Graph -ListAvailable | Select-Object -First 1 Name,Version  # ✅
git --version; bicep --version; terraform version                            # ✅
```

**What good looks like:** `az version` returns JSON with `azure-cli`, `azure-cli-core` and an
`extensions` object. PowerShell reports `7.x`. `Az` and `Microsoft.Graph` both return a version.

**Behind the scenes:** `az` is Python; `Az` is a PowerShell module set; they authenticate
*separately* and keep separate token caches. Signing into one does **not** sign you into the other.
This surprises people constantly.

> **Retired modules — know the names so you can reject stale tutorials.** `MSOnline`
> (`Connect-MsolService`) and `AzureAD` (`Connect-AzureAD`) are **retired**. `Microsoft.Graph` is
> the only supported path. A tutorial using `Get-AzureADUser` is stale, and so is the rest of it.

```powershell
foreach ($m in 'MSOnline','AzureAD','AzureADPreview') {
    if (Get-Module $m -ListAvailable) { "$m  <-- RETIRED, still installed" } else { "$m  clean" }
}
```

---

## 2. Sign in — and understand what a sign-in actually is

```powershell
az login                                     # ✅ opens a browser; device code with --use-device-code
az account show --output table               # ✅
az account list --output table               # ✅ all subscriptions you can see

Connect-AzAccount                            # ✅ separate token cache from az CLI
Get-AzContext | Select-Object Name,Account,Tenant,Subscription

Connect-MgGraph -Scopes 'User.Read.All','Directory.Read.All'   # ✅
Get-MgContext | Select-Object Account,TenantId,Scopes
```

**Permission required:** any authenticated user can sign in. What you can *do* is the intersection
of the **delegated scopes** you requested and your **directory role** — two independent limits.

**Behind the scenes:** `Connect-MgGraph` runs the **Authorization Code flow with PKCE** and caches
a refresh token. `-Scopes` are delegated permissions. When a cmdlet returns
`Insufficient privileges to complete the operation`, the cause is exactly one of two things — a
missing scope or a missing role — and telling them apart is the skill. See
**[Layer 1 §2 and §8](../30-identity-and-nhi/oauth-oidc-saml-and-api-auth/LAYER-1-IDENTITY-PROTOCOLS.md)**.

**Failure to cause on purpose:** connect with only `User.Read`, then try
`Get-MgUser -All`. Read the error. Reconnect with `User.Read.All`. That is the scope-vs-role
distinction in ninety seconds.

---

## 3. Naming and tagging — an actual convention, not an instruction to invent one

Most repos say "establish naming conventions." Here is one. Use it or replace it deliberately.

```
<workload>-<environment>-<region-short>-<resource-type>-<nn>
sc300-lab-cin-rg-01
sc300-lab-cin-kv-01
sc300-lab-cin-law-01
```

**Why this shape:** workload first so alphabetical listing groups by project; environment second
so `prod` is never one keystroke from `lab`; region because quota and latency are regional;
type abbreviation because portal filters are weak; number because there is always a second one.

**Mandatory tags** — these are the ones that answer real questions:

| Tag | Answers |
|---|---|
| `owner` | Who do I call before deleting this? |
| `environment` | Is this safe to break? |
| `expires` | When does this become garbage? |
| `costCenter` | Who pays? |
| `purpose` | Why does this exist? |

```powershell
az group create `
  --name sc300-lab-cin-rg-01 `
  --location centralindia `
  --tags owner=keveen environment=lab expires=2026-09-30 costCenter=personal purpose=sc300-lab
# ✅ verified command shape. Returns the resource-group JSON with provisioningState: Succeeded
```

**Control plane vs data plane — the distinction that governs everything:**

- **Control plane** = Azure Resource Manager. Creating, tagging, deleting, RBAC. Audited in the
  **Activity Log**.
- **Data plane** = the contents. Reading a Key Vault secret, writing a blob. Audited in the
  **resource's own diagnostic logs**.

`Owner` on a Key Vault lets you *delete the vault* (control) but does not, under RBAC mode,
automatically let you *read a secret* (data). Engineers lose hours to this. The `expires` tag is
control plane; nothing enforces it — **a tag is documentation, not a control.**

---

## 4. Cost guardrails — before you build anything

The lab that bankrupts you is the one you forgot. Set the ceiling first.

```powershell
az consumption budget list --output table    # ⚠ check — budget CLI surface has moved between versions
```

> **Honest note:** Azure's budget CLI has changed shape across releases. **Set the budget in the
> portal** (*Cost Management → Budgets*) with an alert at 50/80/100%, and verify the CLI syntax
> against `az consumption --help` on your installed version before scripting it. Recording an
> unverified command as verified is the exact failure this repo exists to avoid.

Cheaper and more reliable than any budget: **delete things.** Put the teardown in the same commit
as the build.

```powershell
az group delete --name sc300-lab-cin-rg-01 --yes --no-wait     # ✅
```

`--no-wait` returns immediately; deletion continues server-side. **Deleting a resource group
deletes everything in it, without a second prompt.** That is the intended blast radius of a lab
resource group and the reason one workload gets one group.

---

## 5. Management groups and subscriptions — design on paper first

```powershell
az account management-group list --output table       # ⚠ check — needs MG reader rights
az account subscription list --output table           # ⚠ check
```

A trial account will usually have **one** subscription and no management-group hierarchy, so
design the target on paper and implement only what the account supports:

```
Tenant Root Group
├── Platform            (identity, connectivity, management)
├── Landing Zones
│   ├── Corp            (internal)
│   └── Online          (internet-facing)
├── Sandbox             (permissive; time-boxed; auto-delete)
└── Decommissioned      (policy: deny all new resources)
```

**Why the hierarchy exists at all:** Azure Policy and RBAC **inherit downward**. Assigning at
management-group scope covers every subscription beneath it, including ones created next year.
This is also the hierarchy **PIM for Azure resources** scopes against — see
**[Layer 5 §4](../30-identity-and-nhi/pim-and-access-reviews/LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md)**.

---

## 6. Break-glass accounts — do not improvise this

Day 1 is when they get created, before any Conditional Access exists to lock you out.

**Do not re-derive the design.** It is specified, with the reason for every property, in
**[Layer 5 §4](../30-identity-and-nhi/pim-and-access-reviews/LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md)** —
two accounts, cloud-only on `*.onmicrosoft.com`, **permanent active Global Admin and *not*
PIM-eligible**, excluded from every CA policy, credentials split, sign-in alerting.

The property people get wrong: **not PIM-eligible.** The situations where you need break-glass are
exactly the situations where PIM is unavailable or its licence has lapsed.

```powershell
# Seeds the lab org AND a compliant break-glass pair. Dry-run by default.
..\30-identity-and-nhi\entra-users-and-groups\Seed-LabTenant.ps1
..\30-identity-and-nhi\entra-users-and-groups\Seed-LabTenant.ps1 -Apply
```

---

## 7. Failure exercises — cause these deliberately, record the exact text

Reading an error you caused teaches more than ten successful commands.

| Cause it | What you should see | Why |
|---|---|---|
| `az group create` into a region your subscription lacks quota for | `LocationNotAvailableForResourceType` or a quota error | Regions are not uniform; quota is per-subscription per-region |
| Deploy to a resource group that doesn't exist | `ResourceGroupNotFound` | ARM resolves the RG before the resource |
| `Connect-MgGraph -Scopes 'User.Read'` then `Get-MgUser -All` | `Insufficient privileges to complete the operation` | Scope, not role |
| Assign a role at the wrong scope, then act | `AuthorizationFailed` naming the scope | RBAC evaluates at the requested scope, not where you *think* you assigned |
| `terraform plan` with no credentials | `building AzureRM Client: ... unable to obtain a credential` | Terraform uses its own auth chain, not `az login` by default |

**For each: record the command, the full error, what you changed, and how you confirmed the fix.**
That log is the deliverable — not the successful run.

---

## 8. Cleanup — and prove it

```powershell
az group list --tag purpose=sc300-lab --output table      # ✅ what did I create?
az group delete --name sc300-lab-cin-rg-01 --yes --no-wait
az group list --tag purpose=sc300-lab --output table      # prove it's gone
```

**Cleanup is not tidiness; it is a tested capability.** A consultant who cannot reliably remove
what they deployed will not be allowed to deploy in a customer tenant.

Directory objects are separate: the seed script's `-Remove -Apply` tears down its users and
groups, and deleted Entra users sit in a **30-day soft-delete bin** before permanent purge.

---

## 9. Teach-back — answer without looking

1. **Management group vs subscription?** MG is a policy/RBAC inheritance container; subscription
   is the billing and quota boundary that resources actually live in.
2. **RBAC vs Azure Policy?** RBAC says *who may act*. Policy says *what may exist*. An Owner still
   cannot create a resource a policy denies.
3. **Control plane vs data plane?** Managing the resource vs using its contents. Different
   permissions, different logs.
4. **Why must a lab have cost and deletion controls?** Because an unbounded lab is an unbounded
   bill, and because reliable teardown is the skill that makes deployment trustworthy.
5. **Why is break-glass not PIM-eligible?** Because PIM may be the thing that is broken.
6. **Delegated scope vs directory role?** Two independent limits; effective access is the
   intersection. `Insufficient privileges` means one of them, and you must determine which.

---

## 10. Deliverables — into the six-facet contract

Evidence goes in the topic's facet folders, which is what `COVERAGE.md` measures:

| Facet | Day 1 artifact |
|---|---|
| `lab/` | Toolchain verification output; resource group created and destroyed |
| `break-fix/` | The five failure exercises with **exact** error text and fixes |
| `security/` | Break-glass design and the CA exclusion it will need |
| `operations/` | Naming/tagging standard; cleanup procedure; budget config |
| `architecture-decisions/` | ADR: chosen MG hierarchy and why; region choice and why |
| `customer-use-cases/` | How this baseline differs for a regulated customer — see [Layer 7](../80-customer-scenarios/LAYER-7-INDUSTRY-VERTICALS.md) |

---

## Closeout

- What was built and **verified** — not merely attempted?
- Which commands, and what happened behind the scenes?
- What broke, and how did you diagnose it from the error rather than by guessing?
- Security, cost, reliability, compliance implications?
- What changes for a larger or regulated customer?
- Is the work reproducible and **safely cleanable**?

> **Scope note.** Days 1–10 are an **M365 / Azure / migration engineering** track. They are *not*
> an SC-300 study plan — that is Layers 1–7, indexed in
> [SC-300-MASTERY-SYLLABUS.md](../SC-300-MASTERY-SYLLABUS.md). Day 1 is shared ground because both
> tracks need a governed tenant. Do not mistake finishing this sprint for exam readiness.
>
> `10-DAY-SPRINT.md` currently describes a different Day 2–3 ordering than these files. The
> `DAY-*` files are authoritative; the sprint file needs reconciling.
