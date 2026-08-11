# Deployment Strategies

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **How a change reaches production — and therefore how a *bad* change reaches production.**
> Closes this domain: [`../bicep/`](../bicep/) and [`../terraform/`](../terraform/) describe *what*
> is deployed; this is *how*.

---

## 1. The strategies, read as blast-radius control

| Strategy | Mechanism | ⭐ Security reading |
|---|---|---|
| **Recreate** | stop old, start new | downtime; ⭐ no rollback but restore |
| **Rolling** | replace instances gradually | ⚠ two versions live at once |
| **Blue/green** | two environments, switch traffic | ⭐ **rollback is a traffic switch — seconds** |
| ⭐ **Canary** | small % first, then widen | ⭐ **bounds exposure of a bad change** |
| **Rings** | internal → early adopters → all | ⭐ time to detect before full exposure |

⭐ **Every one of these is a blast-radius decision wearing an availability costume.** Canary asks
*"how many users see this if it is wrong?"* — which is the same question as scoping a role assignment
or setting a quota, and this domain has now asked it four times in four disguises.

⭐ **Blue/green's security property is underrated: rollback in seconds.** A change that turns out to
be a security regression — a disabled filter, a widened NSG, a broken auth check — can be withdrawn
faster than the incident process can convene. **Mean time to *undo* is a security metric.**

⚠ Note the rolling caveat: **two versions live simultaneously** means both must be safe. A rolling
deployment of a security fix leaves the vulnerable version serving traffic throughout.

---

## 2. ⭐ Deployed is not enforced

> **A control that has been deployed, licensed, configured and reported as complete may still be
> stopping nothing.**

This repo's recurring pattern (`RETENTION.md` §3b), and deployment is where it originates:

```
DEPLOYED     the artifact exists            ✅ the pipeline said "success"
CONFIGURED   it has settings                ✅ someone filled the form
⭐ ENFORCING  it is in blocking mode        ⭐ ← the only state that stops anything
PROVEN       ⭐ you watched it stop something ⭐ ← the only state that is evidence
```

⭐ **A green pipeline proves the artifact was applied. It proves nothing about effect.** Which is why
every topic in this repo asks for an error string — `RequestDisallowedByPolicy`
([`../azure-policy/`](../azure-policy/) §4), `ScopeLocked`
([`../resource-locks/`](../resource-locks/) §4). **The pipeline is the deployment; the error is the
proof.**

⭐ **So a deployment pipeline should end with a verification step that attempts the thing that must
fail** — not with "apply succeeded".

---

## 3. ⭐ The pipeline is the most privileged principal you have

**It can change production. It runs unattended. It authenticates non-interactively.**

| Control | Why |
|---|---|
| ⭐ **OIDC federation, no stored secret** | [`../../30-identity-and-nhi/workload-identity-federation/`](../../30-identity-and-nhi/workload-identity-federation/) |
| ⭐ **Environment approvals for prod** | a human between the merge and production |
| **Least privilege per environment** | ⭐ the prod identity is not the dev identity |
| **Pinned actions / providers** | [`../../00-foundations/git-and-github/`](../../00-foundations/git-and-github/) §4 |
| ⭐ **Separate plan from apply** | the reviewed artifact is the applied artifact |
| **Branch protection + CODEOWNERS** | the change was reviewed before it could deploy |

```yaml
jobs:
  plan:
    permissions: { id-token: write, contents: read }     # ⭐ read-only credential
  apply:
    needs: plan
    environment: production                              # ⭐ approval gate lives here
    permissions: { id-token: write, contents: read }
```

⭐ **`environment: production` is where the approval gate attaches**, and it is the cheapest
human-in-the-loop control in the estate — the same **AI-5** idea from
[`../../60-ai-and-secure-ai/ai-governance/`](../../60-ai-and-secure-ai/ai-governance/) §3, arriving in
a pipeline instead of an AI agent.

⚠ **A pipeline with Owner at subscription scope and a standing secret is a bigger finding than most
"critical" vulnerabilities**, and it usually appears on nobody's risk register because it is
infrastructure, not an application.

---

## 4. Worked example — a deployment that proves itself

```yaml
- name: Deploy
  run: az deployment group create -g rg-prod -f ./main.bicep -p ./prod.bicepparam

# ⭐ The step almost nobody writes: attempt what MUST fail.
- name: Verify the guardrail is enforcing
  shell: pwsh
  run: |
      $out = az storage account create -n tstverify$env:GITHUB_RUN_ID `
               -g rg-prod --sku Standard_LRS --allow-shared-key-access true 2>&1
      if ($out -match 'RequestDisallowedByPolicy') {
          Write-Host "✅ policy is ENFORCING"
      } else {
          Write-Host "❌ policy did not block - control is not enforcing"
          az storage account delete -n tstverify$env:GITHUB_RUN_ID -g rg-prod --yes 2>$null
          exit 1
      }
```

⭐ **This converts the pipeline from "we applied a policy" to "we demonstrated the policy blocks".**
It is a handful of lines, it runs on every deploy, and **it catches the case where somebody added an
exemption** ([`../azure-policy/`](../azure-policy/) §3) — a change that otherwise leaves every
dashboard green.

**And the rollback rehearsal, which is the other half:**

```bash
# ⭐ Rollback is a capability, not a hope. Time it.
time az deployment group create -g rg-prod -f ./main.bicep \
     -p ./prod.bicepparam --parameters version=$PREVIOUS_VERSION
```

⭐ **An untested rollback is not a rollback.** Measure it, publish the number, and treat it as a
security SLO — because it bounds how long a security regression stays in production.

---

## 5. Change and the security review

⭐ **The security question is not "was this change safe?" but "would we have caught it if it wasn't?"**

```
Which changes get security review?      ⭐ usually: application code
Which changes reach production fastest? ⭐ usually: infrastructure and config
```

⭐ **That inversion is the finding.** A one-line NSG change, a policy exemption, a disabled diagnostic
setting or a flipped `publicNetworkAccess` can be merged and deployed in minutes, often with lighter
review than a UI copy change — **and every one of them is a security control changing state.**

**The fix is cheap: make a defined set of paths and properties require a named approver.**

```
CODEOWNERS
  /infra/policy/**        @security-team     ⭐ policy definitions and exemptions
  /infra/network/**       @security-team     NSGs, firewall rules, public IPs
  /infra/identity/**      @security-team     role assignments
  /.github/workflows/**   @security-team     ⭐ the pipeline can change itself
```

⭐ **That last line matters most and is the one people forget.** A pipeline that can edit its own
workflow file can remove its own approval gate — **the change-control equivalent of an identity that
can grant itself rights** ([`../azure-rbac/`](../azure-rbac/) §3). **Same shape, fourth appearance in
this repo.**

---

## 6. What breaks

**"Pipeline green" treated as evidence.** §2 — ⭐ it proves application, not effect.

**No verification step.** §4 — nothing detects an exemption that disabled a control.

**Untested rollback.** §4 — ⭐ a capability nobody has measured.

**Standing secret on the deploy identity.** §3 — federate instead.

**One identity across dev and prod.** §3 — dev compromise is prod compromise.

**No environment approval on production.** §3.

**Plan and apply as separate unlinked steps.** [`../terraform/`](../terraform/) §3.

**Infrastructure changes bypassing security review.** §5 — ⭐ the fastest path is the least reviewed.

**Workflow files without CODEOWNERS.** §5 — ⭐ the pipeline can remove its own gate.

**Rolling deployment of a security fix.** §1 — the vulnerable version keeps serving.

---

## 7. Customer discovery questions

1. Does the pipeline **verify** a control blocks, or only that it applied? *(§4.)*
2. When did you last **rehearse a rollback**, and how long did it take? *(§4.)*
3. Does the deploy identity hold a **stored secret**, and what scope does it have? *(§3.)*
4. Is there an **approval gate** before production?
5. Are dev and prod deployed by **different identities**?
6. ⭐ Which paths require **security review** — and do infrastructure and workflow files? *(§5.)*
7. Can the pipeline **modify its own workflow** without review? *(§5.)*
8. If a change turned out to be a security regression, ⭐ **how long until it is out of production?**
9. Are canaries or rings used, and is the percentage a **blast-radius** decision or an availability
   one? *(§1.)*

---

## 8. Remember it

**Hook — "Deployed is not enforced. Prove it blocks."**

**Analogy — a fire drill versus a fire certificate.** ⭐ **The certificate says the alarm was
installed and tested on the date of installation.** The drill is you pulling the handle this morning
and watching the building empty. **A green pipeline is the certificate**; the deliberate failed
deployment returning `RequestDisallowedByPolicy` is the drill. ⭐ **And the reason to run it every
deploy is that somebody can quietly file an exemption, and the certificate on the wall does not
change.**

**The one thing:** ⭐ **end the pipeline with a step that attempts what must fail.** Deploying a
control and observing "success" tells you the artifact was applied; **it tells you nothing about
whether an exemption, a scope change or a precedence conflict has left it inert.** A dozen lines that
try to create a non-compliant resource and require `RequestDisallowedByPolicy` turn every deployment
into continuous evidence — and it is the only thing in this domain that catches a control being
switched off after it was correctly turned on.

**Runner-up:** ⭐ **put CODEOWNERS on the workflow files.** A pipeline that can edit its own workflow
can remove its own approval gate — the same self-elevation shape as User Access Administrator.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Read each deployment strategy as a blast-radius decision.
2. ⭐ Which strategy's security property is rollback speed, and why does that matter?
3. What is the caveat of a rolling deployment for a security fix?
4. Name the four states from deployed to proven.
5. ⭐ What does a green pipeline actually prove?
6. What does a verification step look like, and what does it catch that nothing else does?
7. Why is an untested rollback not a rollback?
8. Name four controls on the deploy identity.
9. ⭐ Why is the infrastructure change path a security finding? *(§5.)*
10. ⭐ Why do workflow files need CODEOWNERS, and which earlier finding is that the same shape as?

<details>
<summary>Answers</summary>

1. Recreate (downtime, restore-only), rolling (⚠ two versions live), blue/green (⭐ instant rollback),
   canary (⭐ bounded exposure), rings (⭐ time to detect) — ⭐ all are *"how many are affected if this
   is wrong?"*
2. ⭐ **Blue/green** — a security regression can be withdrawn in seconds, faster than the incident
   process convenes. **Mean time to undo is a security metric.**
3. ⚠ **Both versions serve traffic simultaneously**, so the vulnerable version keeps serving
   throughout.
4. **Deployed → configured → ⭐ enforcing → ⭐ proven.**
5. ⭐ **That the artifact was applied.** Nothing about effect.
6. A step that ⭐ **attempts a non-compliant action and requires the block error**
   (`RequestDisallowedByPolicy`). ⭐ It catches a **control switched off after being correctly turned
   on** — typically by an exemption.
7. ⭐ Because it is an **unmeasured capability**; it bounds how long a security regression stays in
   production, so the number matters.
8. **OIDC federation, environment approvals, least privilege per environment, pinned actions, and
   plan/apply linkage.**
9. ⭐ **Infrastructure and config changes reach production fastest with the lightest review**, and
   each one is a security control changing state.
10. ⭐ Because the pipeline can **edit its own workflow and remove its own approval gate** — the same
    self-elevation shape as **User Access Administrator assigning itself Owner**.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — add the §4 verification step to a real pipeline and watch it pass. ✗ Requires an
  Azure subscription.
- **`break-fix/`** ⭐ — with the verification step in place, **add a policy exemption** and re-run the
  pipeline: it should fail, loudly, while every compliance dashboard stays green. **That is the entire
  argument for §4 in one run.** Then rehearse a rollback and record the elapsed time.
- **`security/`** — deploy identity credential type and scope per environment; environment approval
  configuration; CODEOWNERS coverage including ⭐ workflow files; measured rollback time.
- **`operations/`** — rollback rehearsal schedule with published timings; verification step as a
  required stage in every infrastructure pipeline.
- **`architecture-decisions/`** — ADR: OIDC-only deploy identities, separate per environment;
  ⭐ every control deployment ships with a test that proves it blocks.
- **`customer-use-cases/`** — §7 answered; "your pipeline can remove its own approval gate" as a
  standalone finding.
