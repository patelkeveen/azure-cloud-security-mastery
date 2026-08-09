# Layer 6 — The SC-500 Bridge: Agent Identity and AI Security `[BEYOND]`

> **This is the layer that matches the target role.** AZ-500 retires **2026-08-31**; its
> successor **SC-500 — Implementing End-to-End Security Controls for Cloud and AI Workloads**
> (*Cloud and AI Security Engineer Associate*) tests exactly this material.
>
> Almost nobody holds it yet. That is the asymmetry.
>
> **Verification note:** the Agent ID sections below are verified in depth against Microsoft
> documentation on **2026-08-09**. The Defender for AI / Foundry / Purview sections are mapped
> from the published SC-500 skills outline but **not** individually verified to the same depth —
> treat those as a study map, not as authority, and check the docs before quoting them.

---

## 1. Why this exists: the third identity population

You've now covered two populations. There is a third, and it behaves like neither.

| | **Human identity** | **Workload identity** (Layer 4) | **Agent identity** |
|---|---|---|---|
| Lifespan | Years | Years | **Minutes to days** |
| Creation | HR process | Deliberate, by an engineer | **Dynamically, by users and automation** |
| Volume | Headcount | Hundreds | **Thousands created and destroyed per day** |
| Authenticates with | Password, passkey, MFA | Secret, cert, federation | Blueprint-managed credentials |
| Designed for | Permanence | Stability, known ownership | **Scale and ephemerality** |

Microsoft's own framing: service principals *"carry the expectation of long-term stability,
known ownership, and managed lifecycle."* Agents break every one of those assumptions. An agent
may exist for the duration of one task. Managing that with app registrations produces orphaned
credentials and permission sprawl at machine speed.

**Agent identities exist to solve four problems**, stated by Microsoft:

1. Distinguish AI-agent operations from workforce, customer, and workload operations
2. Give agents **right-sized** access
3. **Prevent agents reaching the most critical roles and systems**
4. Scale identity management to huge numbers of short-lived identities

> **Licensing, verified:** **Entra Agent ID — the platform for creating and managing agent
> identities and blueprints — is available to all Microsoft Entra customers.** But *extending
> Entra security features to agents* requires **Microsoft Agent 365**. Conditional Access for
> agents needs **P1/P2 + Agent 365 per user**; network controls for agents need **Entra Internet
> Access**. Agent 365 ships with **Microsoft 365 E7** and is an add-on to E5/A5/Business Premium
> (or Defender Suite + Purview Suite).

---

## 2. The three agent access patterns ⭐⭐

**This is the core of the layer.** Each pattern puts a *different subject* in the token, and
therefore each is targeted by Conditional Access completely differently. Getting this wrong
means writing policies that silently don't apply.

Recall from Layer 1 §4: every access token has **exactly one subject and one audience**. CA
evaluates on both.

### Pattern A — Agent on behalf of a user (OBO / delegated)

The most common pattern. A user signs in to an agent; the agent reaches downstream resources
using the *user's* identity and delegated permissions.

The agent **cannot reuse the user's original token** — wrong audience (Layer 1 §4). It performs
an **on-behalf-of exchange** (Layer 1 §2) to get a token scoped to the target resource. **That
exchange is itself evaluated by Conditional Access**, which is what gives you per-resource
control over what an agent may do for a user.

> **Subject = the user.** Therefore **Conditional Access policies target users and groups, not
> agent identities.** Writing a policy against the agent identity to control this flow does
> nothing.

### Pattern B — Agent as an application (autonomous / client credentials)

No user present. The agent uses its own identity and credentials managed through its **agent
identity blueprint**. Applies to background/scheduled agents, interactive agents calling a
backend the user can't reach, and public web agents.

> **Subject = the agent identity.** CA is scoped to the agent identity.

### Pattern C — Agent as a user (agent's user account)

An admin creates a **real Entra user account** linked **1:1** to an agent identity. From there
it behaves like any user: it can hold licences, a **mailbox and calendar**, join security groups
and administrative units, and participate as a team member. A digital colleague.

> **Subject = the agent's user account.** Policy is evaluated against **the user account, not
> the agent identity.**

**Summary — memorise this table:**

| Pattern | Token subject | CA targets |
|---|---|---|
| A — on behalf of user | The **user** | Users / groups |
| B — autonomous app | The **agent identity** | Agent identity (or blueprint) |
| C — agent's user account | The **agent's user account** | That user account |

### Agent identity blueprints

Every agent identity derives from a **blueprint** defining its configuration and governance
model. Target a CA policy at the blueprint and it **automatically covers every agent derived
from it, including ones created in future.** For a project spinning up dozens of collaborating
agents under one blueprint, that's a single policy governing the whole fleet.

> ⚠ **Blueprint targeting covers the agent identity only — never the agent's user account.**

### Attribute-driven Conditional Access ⭐

At scale, naming individual agents in policies is unsustainable. **Custom security attributes**
(Layer 2 §1.2 — the feature with its own separate RBAC model) let you tag agent identities and
resources with business labels and target *those* in CA. Policies then apply automatically to
every matching agent, including future ones.

This is the killer use case for custom security attributes, and it's why that quiet corner of
Domain 1 is suddenly load-bearing.

---

## 3. Boundaries and limitations — where CA does **not** apply ⚠

**Verified, and this is the security-review content.** Conditional Access does not apply when:

- A blueprint acquires a token to **create** an agent identity or agent's user account
- A blueprint or agent identity performs an intermediate exchange at the **AAD Token Exchange
  Endpoint: Public** (`fb60f99c-7a34-4190-8149-302f77469936`). Tokens scoped there cannot call
  Microsoft Graph, so the flow stays protected — CA guards the *acquisition* by the agent
  identity or user account
- **Security defaults are enabled** — they and CA are mutually exclusive
- **The resource isn't secured by Microsoft Entra ID**

Not currently supported:

- **Policies targeting "All users" do NOT include agents' user accounts**
- **You cannot scope a policy to include/exclude agents' user accounts by group membership**
- A policy targeting agent identities **does not apply to the agent's user account**
- Blueprint-targeted policies cover the agent identity only

> ### The finding that matters most
>
> **"Conditional Access only protects resources secured by Microsoft Entra ID. If an agent
> accesses resources using an API key, it bypasses the Microsoft Entra authentication and token
> issuance pipeline entirely, and Conditional Access policies won't apply."**
>
> Most real agents today authenticate to *something* with a raw API key — a model endpoint, a
> vector database, a third-party SaaS API. **Every one of those calls is invisible to your entire
> identity control plane.** Your CA policies, your risk detections, your sign-in logs see none of it.
>
> This is the single most important sentence in this layer. It reframes the job from "configure
> CA for agents" to **"find every API key an agent holds and get those integrations behind Entra
> or behind an inspecting gateway."** That's the actual work, and it's why the AI Gateway in §5
> matters more than it first appears.

Second-order finding: **"All users" not covering agents' user accounts** means every existing
baseline policy in every tenant has a gap the moment someone creates a digital worker. Nobody's
2025-era CA baseline anticipated this.

---

## 4. Agent identity in practice

Two shipping examples, verified:

- **Entra Conditional Access optimization agent** — has its own agent identity; every query it
  makes is recorded as performed by an AI agent, and it is subject to policies enforced on agent
  identities. Visible under **Agent identities** in the Entra admin center.
- **Copilot Studio agents** — every agent created gets an agent identity, and **the creating
  user is recorded as its sponsor**. Sponsorship is the accountability primitive: a human is
  attached to each agent.

**Governance tie-in (Layer 5):** Microsoft Agent 365 brings agents into entitlement management
and Lifecycle Workflows — access packages assignable to agents and service principals, sponsors
approving on their behalf, and agent-sponsorship tasks in LCW. Joiner/mover/leaver, for software.

**Detection tie-in:** Entra **ID Protection for Agents** produces risk detections for agents.
Defender XDR assesses posture risk for AI agents including local agents discovered on endpoints,
and the **`AgentsInfo`** advanced-hunting table (preview) provides a unified agent inventory
schema. Defender XDR's *Observed in organization* view is what the SC-500 objective means by
**blast radius** — where an identity appears across the estate and what lateral movement is
possible from it.

**Why blast radius is the right frame:** agents accumulate broad API permissions across Graph
and custom APIs, precisely because they're built to be useful. Layer 4's lesson applies with
force — an *application* permission has no intersection with any user's rights.

---

## 5. The rest of the SC-500 surface

> Mapped from the published skills outline; **not verified to the depth of §§2–4.** Use as a
> study index.

### Secure compute — AI (the new domain)

| Objective | Notes |
|---|---|
| Data overexposure in SharePoint | Copilot surfaces what a user *could already* reach. Oversharing becomes visible instantly — the #1 real Copilot risk, and it's a permissions problem, not an AI problem |
| **Purview DSPM for AI** | Discover and assess risk from Copilot and AI apps |
| Copilot Studio agent real-time protection | Runtime guardrails |
| **CA for Entra Agent ID** | §§2–3 above |
| **Blast radius analysis in Defender XDR** | §4 above |
| Manage Entra Agent ID access | Entitlement management, sponsors |
| **AI Gateway in Azure API Management for Microsoft Foundry** | Token-based rate limiting, semantic caching, centralised policy for model calls. **This is the control that puts model traffic behind something inspectable** — see the API-key finding in §3 |
| **Defender for AI Services** in Cloud Workload Protection | Threat protection for AI workloads |
| Guardrails for agent security in Foundry | Content filters, groundedness, prompt-injection defences |
| Data and AI security dashboard in Defender for Cloud | Posture view |
| Manage agents in M365 admin center | Inventory and lifecycle |

### Identity, access, governance
Extends Layers 3–5 into the resource plane: **Key Vault** (deploy, RBAC vs access policies,
firewall, key/secret/cert management, rotation, Defender for Key Vault, **secret scanning via
Defender CSPM**), Azure Policy, regulatory compliance in Defender for Cloud, resource locks,
**remediating over-privileged RBAC**, backup protection, IaC security controls.

> Key Vault is where Layer 4's credentials belong. If an app must hold a secret, it should
> retrieve it from Key Vault using a **managed identity** — not carry it in config.

### Storage, databases, networking
Storage account security and Defender for Storage; Azure SQL platform security, auditing,
Defender for Databases; NSG/ASG, **Azure Virtual Network Manager**, Virtual WAN, VPN,
**Entra Private Access** (Layer 3 §6), private endpoints, Private Link, Azure Firewall, Network
Watcher effective rules.

### Posture and monitoring
**Defender CSPM**, compliance frameworks, workload protection plans, multicloud connectors
(**AWS and GCP**), Defender Vulnerability Management, **EASM**.

**Microsoft Sentinel** — workspaces, roles, content hub, data connectors, **DCRs**, syslog/CEF,
Windows Event Forwarding, custom log tables, automation rules and playbooks, retention. This is
where Layer 5's diagnostic settings terminate, and where your KQL becomes detection engineering.

**Microsoft Security Copilot** — workspaces, permissions, plugins, Microsoft and Security Store
agents. Note the recursion: you use agents to secure agents, and those agents have agent
identities governed by §§2–4.

---

## 6. Hands-on gate

Requires your own tenant. Agent-specific labs need Agent 365 licensing — **check entitlement
before planning them.**

**Lab 1 — Find the agent identities you already have.** Look under **Agent identities** in the
Entra admin center. If the CA optimization agent or any Copilot Studio agent exists, you already
have this population. Most tenants do and don't know it.

**Lab 2 — Prove the subject rule.** For an OBO agent, write a CA policy targeting the *agent
identity* and confirm it does **not** apply. Then target the *user* and watch it fire. This is
the mistake to make in a lab rather than in production.

**Lab 3 — The "All users" gap.** Create an agent's user account. Confirm your All-users baseline
policy does **not** cover it. **Then fix your baseline.** Every tenant has this gap right now.

**Lab 4 — Blueprint-scoped policy.** One policy at blueprint level; verify it governs agents
derived from it and confirm it does *not* reach agents' user accounts.

**Lab 5 — Attribute-driven CA.** Define a custom security attribute (e.g. `AgentTier = Tier0`),
tag agents, target the attribute. Add a new agent with the tag and confirm the policy applies
with no policy edit.

**Lab 6 — The API-key audit ⭐.** For any agent you run, enumerate **every credential it holds
that is not an Entra token.** That inventory is your CA blind spot, and producing it is a
consulting deliverable in its own right.

**Lab 7 — Sentinel.** Ship Entra logs to a workspace, enable a connector, write one analytics
rule from a Layer 5 KQL query, attach a playbook.

---

## 7. Study path from here

1. **SC-300 first.** Layers 1–5. Agent identity only makes sense once tokens, subjects and CA are automatic.
2. **AZ-500 content, not the exam.** It retires 2026-08-31. ~80% of its material survives inside SC-500 — learn it, don't sit it.
3. **SC-500.** This layer, plus the resource-plane material in §5.
4. **Publish.** A write-up on the API-key blind spot, or agent CA targeting rules, would be genuinely novel content right now. Very few people have operated this.

---

## 8. Cross-references

| Concept here | Built on |
|---|---|
| One subject, one audience per token | Layer 1 §4 |
| OBO flow, client credentials | Layer 1 §2 |
| Custom security attributes | Layer 2 §1.2 |
| CA evaluation, grant controls, CAE | Layer 3 §§2–3 |
| Application permissions have no intersection | Layer 4 §5 |
| Entitlement management, sponsors, LCW | Layer 5 §§2–4 |
| KQL → analytics rules | Layer 5 §5 |
