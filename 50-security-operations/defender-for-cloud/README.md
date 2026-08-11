# Microsoft Defender for Cloud

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (updated 2026-07-07).
> **SC-200 and SC-500 core** — see [`CERT-MAP.md`](../../CERT-MAP.md).
> The umbrella product; [`../posture-management/`](../posture-management/) and
> [`../attack-path-analysis/`](../attack-path-analysis/) go deeper on its two hardest features.

---

## 1. What it is

A **CNAPP** — Cloud Native Application Protection Platform — with **three** components ✅:

```
CSPM       Cloud Security Posture Management   ← are my resources CONFIGURED safely?
DevSecOps  code, pipelines, IaC                ← is the misconfiguration in the TEMPLATE?
CWPP       Cloud Workload Protection Platform  ← is something ATTACKING my workloads?
```

Most people know it as "the thing with the secure score" — that is CSPM, one third of it, and the
free third.

It covers **Azure, AWS, GCP and on-premises** ✅. It is not an Azure-only product, and saying so in
an interview is a tell.

⚠ **Defender for Cloud is being surfaced in the Microsoft Defender portal** alongside the Azure
portal ✅ — documentation now carries a portal pivot. Expect screenshots in any course older than
this year to be wrong.

---

## 2. Why it exists

Three failures that traditional security tooling cannot address in cloud:

**Misconfiguration, not malware, is the dominant cloud breach cause.** A public storage container, an
NSG open to `0.0.0.0/0`, a key vault without purge protection. Nothing is *infected* — everything is
*wrong*. Antivirus has no opinion on any of it.

**The estate changes faster than review cycles.** A subscription can gain two hundred resources in an
afternoon via a pipeline. Quarterly manual review is arithmetic that does not work.

**The misconfiguration is usually in a template.** Fixing the resource fixes one instance; the Bicep
or Terraform module recreates it tomorrow. That is why DevSecOps is a first-class component and not
an afterthought.

---

## 3. ⭐ The free/paid boundary — the most useful thing to know

This is the fact that makes you useful in week one, because most organisations do not know what they
already have.

**Foundational CSPM is free on every Azure subscription** ✅:

| Free — Foundational CSPM | Paid — Defender CSPM |
|---|---|
| Security recommendations | **Attack path analysis** |
| **Secure score** | **Cloud security explorer** (the security graph) |
| **Microsoft cloud security benchmark** (MCSB) | **Data security posture management** (DSPM) |
| **Multicloud** connection (AWS, GCP) | Governance rules — assign owners, track remediation |
| CSPM dashboard | Regulatory compliance standards |
| DevOps code pipeline insights | Agentless vulnerability scanning |
| | **AI security posture management (AI SPM)** |

> ⭐ **Every Azure customer already has secure score, MCSB recommendations and multicloud posture at
> no cost, and a large share have never opened it.** "You are paying for nothing and receiving
> nothing" is a five-minute conversation that produces a remediation backlog. It is the highest
> value-per-effort finding available in an Azure assessment.

**The CWPP plans are separate, per-resource-type, per-hour charges** ✅:

| Plan | Protects |
|---|---|
| **Defender for Servers** (P1/P2) | Windows/Linux VMs — Azure, AWS, GCP, on-prem. **P2 includes MDE** |
| **Defender for Containers** | Kubernetes hardening, image scanning, runtime |
| **Defender for Storage** | Malware scanning, sensitive-data exfiltration, **SAS token misuse** |
| **Defender for Databases** | Azure SQL, SQL on machines, open-source relational, Cosmos DB |
| **Defender for Key Vault** | Anomalous access to secrets |
| **Defender for Resource Manager** | ⭐ Suspicious **control-plane** operations |
| **Defender for App Service** | Attacks against web apps and APIs |
| **Defender for APIs** | API inventory, posture, runtime threats |
| **AI Services** | ⭐ Threats against **generative AI** workloads |

⚠ **Defender for DNS changed** ✅: since **1 August 2023**, existing standalone subscriptions
continue, but **new subscriptions receive DNS alerts as part of Defender for Servers P2**. Protection
scope is unchanged — only the bundling and billing. Material predating this describes a plan you
cannot buy.

---

## 4. Worked example — what am I actually paying for, and what is it telling me?

**Step 1 — which plans are enabled, and at what tier?** Run this before any assessment conversation:

```bash
az security pricing list --query "value[].{Plan:name, Tier:pricingTier, SubPlan:subPlan}" -o table
```

```
Plan                     Tier      SubPlan
-----------------------  --------  -------
CloudPosture             Free
VirtualMachines          Standard  P2
StorageAccounts          Free
KeyVaults                Free
Containers               Standard
Arm                      Free
```

**Read that like a consultant.** `CloudPosture: Free` means **no attack path analysis, no cloud
security explorer, no DSPM** — the features people assume they have. `StorageAccounts: Free` with
regulated data present is a finding. `VirtualMachines: Standard P2` means MDE is included on those
servers, which frequently surprises the endpoint team.

**Step 2 — the secure score, and the honest way to read it:**

```bash
az security secure-score list --query "[].{Name:displayName, Current:score.current, Max:score.max, Pct:score.percentage}" -o table
```

```
Name     Current  Max   Pct
-------  -------  ----  ----
ascScore    28.5    56  0.51
```

**Step 3 — where the score is actually lost.** The score is a distraction; the controls are the work:

```bash
az security secure-score-control list \
  --query "sort_by([].{Control:displayName, Current:score.current, Max:score.max, Unhealthy:unhealthyResourceCount}, &Max)[::-1]" -o table
```

```
Control                                    Current  Max  Unhealthy
-----------------------------------------  -------  ---  ---------
Enable MFA                                       0   10         14
Secure management ports                          2    8         31
Remediate vulnerabilities                        3    6        127
Encrypt data in transit                          4    4          0
```

> ⭐ **Sort by `Max`, not by percentage.** "Enable MFA" at 0/10 with 14 unhealthy resources is worth
> more than perfecting a 1-point control across 400 resources. The score is weighted, and most teams
> remediate whatever produces the longest list — which is precisely backwards.

**Step 4 — export recommendations so they become a backlog, not a dashboard:**

```bash
az security assessment list --query "[?status.code=='Unhealthy'].{Name:displayName, Resource:resourceDetails.id}" -o tsv > findings.tsv
```

A dashboard nobody owns changes nothing. **A CSV with owners and dates changes things** — which is
exactly what the paid *governance rules* feature automates.

---

## 5. The Microsoft cloud security benchmark, and compliance

**MCSB** is the built-in default standard ✅ — Microsoft's own control set, mapped to CIS, NIST and
PCI DSS, with technical implementation guidance for **Azure, AWS and GCP**.

**Every recommendation you see comes from a standard.** That framing matters: you are not receiving
opinions, you are receiving control failures traceable to a named benchmark. Regulatory compliance
standards (paid) let you add the specific framework a customer is audited against and produce
evidence per control.

> **The consulting sentence that lands:** *"Your secure score is 51%. Against the specific standard
> your auditor uses, here are the twelve controls currently failing, and here is which team owns
> each."* That is a deliverable. A screenshot of a gauge is not.

---

## 6. What breaks

**Assuming Defender CSPM is on.** Attack path analysis and the security explorer are **paid**.
Check `az security pricing list` before promising a customer either.

**Enabling every plan everywhere.** Costs scale per resource per hour. Enable by data sensitivity and
exposure, not uniformly.

**Treating secure score as the goal.** It is a proxy. A tenant can score well and still have one
internet-facing unpatched VM with a managed identity holding Owner — which is the thing that
actually kills you. See [`../attack-path-analysis/`](../attack-path-analysis/).

**Remediating by list length instead of weight.** §4 step 3.

**Fixing the resource, not the template.** It reappears at the next deployment. Push the fix into the
IaC module — that is what DevSecOps integration is for.

**Ignoring Defender for Resource Manager.** Control-plane attacks — mass role assignment, resource
deletion — are invisible to workload-level plans.

**Forgetting multicloud.** AWS and GCP connectors are **free** at Foundational CSPM. Leaving them
unconnected is leaving free visibility on the table.

**Assuming Defender for Servers P2 and MDE are separate purchases.** P2 includes MDE on those servers.

---

## 7. Customer discovery questions

1. `az security pricing list` — which plans, which tiers? **Is `CloudPosture` Free or Standard?**
2. What is the secure score, and **when did anyone last act on it**?
3. Are AWS/GCP connected? *(Free — if not, why not?)*
4. Which regulatory standard is the customer audited against, and is it loaded?
5. Are recommendations assigned to owners with dates, or reviewed ad hoc?
6. Are findings fed back into **IaC templates**, or fixed per resource?
7. Is Defender for Resource Manager on? Who watches control-plane alerts?
8. Are Defender for Cloud alerts flowing into Sentinel and Defender XDR?
9. If AI workloads exist — are **AI SPM** and **AI threat protection** enabled?

---

## 8. Remember it

**Hook — CNAPP = CSPM + DevSecOps + CWPP.** *Configured safely · built safely · under attack.*
And: **"Foundational CSPM is free; Defender CSPM is the one with the graph."**

**Analogy — building control versus a burglar alarm.** CSPM is the **inspector** who checks the
locks, the wiring and the fire doors against a code (MCSB). CWPP is the **alarm** that goes off when
someone is inside. DevSecOps is catching it **on the architect's drawing**, before the building
exists — which is the only one of the three that scales, because the drawing is reused a hundred times.

**The one thing:** **every Azure subscription already has secure score, MCSB recommendations and
multicloud posture for free**, and most organisations have never looked. The paid tier buys the
*graph* — attack paths and the security explorer — not the basics.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. What does CNAPP stand for and what are its three components?
2. Which posture features are free, and which require Defender CSPM?
3. `CloudPosture: Free` in the pricing output — what can the customer *not* do?
4. Why sort secure score controls by `Max` rather than by unhealthy count?
5. Which plan covers control-plane attacks like mass role assignment?
6. What changed about Defender for DNS, and when?
7. Does Defender for Servers P2 include Defender for Endpoint?
8. Why is fixing a resource often the wrong remediation?
9. Which clouds does Defender for Cloud cover?
10. What does MCSB give you beyond a list of recommendations?

<details>
<summary>Answers</summary>

1. **Cloud Native Application Protection Platform** — **CSPM**, **DevSecOps**, **CWPP**.
2. **Free:** secure score, recommendations, MCSB, multicloud connection, DevOps insights.
   **Paid (Defender CSPM):** attack path analysis, cloud security explorer, DSPM, governance rules,
   regulatory compliance, agentless vulnerability scanning, AI SPM.
3. No **attack path analysis**, no **cloud security explorer**, no **DSPM** — the features most
   people assume are included.
4. The score is **weighted**. A 10-point control with 14 unhealthy resources outranks a 1-point
   control with 400.
5. **Defender for Resource Manager.**
6. Since **1 August 2023**, new subscriptions get DNS alerts within **Defender for Servers P2**;
   existing standalone subscriptions continue. Scope unchanged, bundling changed.
7. **Yes** — P2 includes MDE on those servers.
8. The misconfiguration usually originates in an **IaC template**, which will recreate it.
9. **Azure, AWS, GCP and on-premises.**
10. Traceability to a **named benchmark** mapped to CIS/NIST/PCI — so findings are control failures,
    not opinions.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — run all four §4 commands against a real subscription; produce the weighted
  remediation backlog. ✗ **Requires an Azure subscription** — the current tenant has none.
- **`break-fix/`** — create a deliberately public storage account, watch the recommendation appear,
  remediate the **Bicep template** rather than the resource, and redeploy to prove it stays fixed.
- **`security/`** — plan/tier inventory with justification per plan; findings mapped to the
  customer's audited standard.
- **`operations/`** — governance rules with owners and dates; secure score tracked over time, not
  as a snapshot.
- **`architecture-decisions/`** — ADR: which CWPP plans, scoped by data sensitivity and exposure
  rather than enabled uniformly.
- **`customer-use-cases/`** — §7 answered against a real subscription.
