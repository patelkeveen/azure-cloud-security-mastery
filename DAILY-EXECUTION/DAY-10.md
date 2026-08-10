# Day 10 — Architecture, Customer Delivery, and Defense

> Standard set by [DAY-01](DAY-01.md). `✅ verified` / `⚠ check` convention applies.

**Outcome:** the nine previous days become **artifacts a customer would pay for** and **answers you
can defend under questioning**. Nothing new is built today. Today is where the work becomes
sellable.

**The uncomfortable premise:** engineering skill that cannot be communicated is worth very little
commercially. The gap between "I configured Conditional Access" and "here is the design, the
trade-offs I rejected, the risk register, and how we roll back" is most of the difference between
an engineer and a consultant.

---

## 1. The document set — and what each is actually for

| Artifact | Audience | Answers |
|---|---|---|
| **Executive summary** | Sponsor | What did we do, what did it cost, what risk remains? |
| **HLD** | Architects, IT leadership | *What* and *why* — components, boundaries, decisions |
| **LLD** | Implementers | *How* — exact settings, names, IPs, policies |
| **ADRs** | Future engineers | Why this, what we rejected, what would change it |
| **Risk register** | Sponsor + delivery | What could go wrong, who owns it |
| **Test plan** | Delivery | How we prove it works |
| **Cutover runbook** | Cutover team | Minute-by-minute, with rollback triggers |
| **Handover / SOPs** | Operations | How to run it after we leave |

**The distinction people get wrong: HLD says *why*, LLD says *how*.** An HLD containing IP
addresses is an LLD wearing the wrong title, and it will be circulated to executives who cannot
read it. An LLD without exact values is not implementable and will be improvised — differently by
each engineer.

**The ADR is the highest-value, least-written document.** In two years nobody remembers why PHS
was chosen over federation. The ADR is the only thing standing between your successor and
re-litigating a settled decision:

```markdown
# ADR-004: Password Hash Synchronization over Federation
Status: Accepted   Date: 2026-08-XX   Decision owner: <name>

## Context
Customer has on-prem AD, an ageing AD FS farm, and a stated goal of reducing
on-premises dependency. 2,400 users, single forest.

## Decision
Password Hash Synchronization with Seamless SSO. AD FS decommissioned after
staged rollout.

## Alternatives considered
- Pass-through authentication: rejected - retains on-prem dependency for cloud
  sign-in; requires >=3 agents for HA; no leaked-credential detection.
- Retain federation: rejected - AD FS farm is EOL, certificate management burden,
  and a datacentre outage becomes an M365 outage.

## Consequences
+ Cloud sign-in survives on-prem outage.
+ Enables leaked-credential detection in ID Protection.
- Claims rules must be rebuilt as Entra claims-mapping policies.
- On-prem MFA adapter is lost; migrate to Entra MFA.

## Revisit if
The customer acquires a regulated subsidiary requiring on-prem credential
validation, or a third-party IdP becomes the strategic direction.
```

---

## 2. Risk register — ranked by business impact, not CVSS

| Risk | Likelihood | Impact | Owner | Mitigation | Residual |
|---|---|---|---|---|---|
| Legacy auth blocked breaks the scanner fleet | High | Medium | IT Ops | Measure first; connector with IP allow-list | Low |
| Migration tool retains tenant-wide app permissions | Medium | **High** | Security | Time-bound consent; revoke at close; NHI register | Low |
| Domain cutover overruns the window | Medium | High | Project | Rehearse; lower TTL; rollback rehearsed | Medium |
| 23 standing Global Admins | High | **High** | Security | PIM eligible + time-bound; access reviews | Low |

**Ranking by executive legibility is not dishonesty — it is translation.** "23 Global Admins"
outranks "TLS 1.0 on one endpoint" in every conversation with a decision-maker, and the
decision-maker is who funds remediation.

**Always state residual risk.** A register with no residual column implies every risk was
eliminated, which is never true and destroys credibility with anyone experienced.

---

## 3. The cutover runbook

One page. Timestamped. A named owner per step. It should be usable by a competent engineer who was
not in the design meetings — because at 2am, that is who is holding it.

```
T-7d   Comms to users                              Owner: PM         [ ]
T-48h  Lower MX TTL to 300                         Owner: Network    [ ]
T-24h  Final delta sync                            Owner: Migration  [ ]
T-2h   GO / NO-GO CHECKPOINT                       Owner: Lead       [ ]
T-0    Flip MX                                     Owner: Network    [ ]
T+15m  Verify inbound mail from external           Owner: Messaging  [ ]
T+30m  Verify free/busy, mobile, desktop clients   Owner: Support    [ ]
T+2h   ROLLBACK DECISION POINT                     Owner: Lead       [ ]
T+24h  Reconciliation report                       Owner: Migration  [ ]
```

**The rollback trigger must be written before cutover starts**, in objective terms: *"if inbound
mail has not flowed for 30 minutes after the MX flip, we revert."* Deciding what constitutes
failure while failing is how teams talk themselves into pressing on.

**State what rollback does not recover** — anything written to the target after cutover — and get
that accepted in writing.

---

## 4. Handover — the test of whether you actually finished

Handover fails when the customer still needs you. That feels flattering and is a delivery failure.

Required: SOPs for routine tasks, the runbook set, the risk register with owners, credentials
transferred through a proper process (**never email**), a known-issues list, and a defined support
boundary with an end date.

> **The evidence that handover worked:** the operations team performs a routine task from the SOP
> **without you in the room**. If that has not been demonstrated, handover has not happened —
> a document has merely been delivered.

---

## 5. Interview defense

Everything above is also the answer to *"tell me about a project."*

**Structure any technical answer in four beats:**

1. **Context** — constraint, scale, why it mattered commercially
2. **Decision** — what you chose *and what you rejected*
3. **Mechanism** — how it works underneath
4. **Evidence** — what you measured, what broke, what you'd change

Beat 2 is what separates senior from mid. Anyone can say what they built. Naming the rejected
alternative and why proves you evaluated rather than defaulted.

**Use the claim ladder from [Day 6](DAY-06.md) precisely.** Researched / trialled / delivered.
*"I've researched BitTitan and run a pilot in my lab; I haven't delivered with it at scale"* is
stronger than a vague claim, because it is checkable and the rest of your answers become credible.

**Questions you should be able to answer cold** — with the layer that contains the answer:

| Question | Source |
|---|---|
| Why does this token lack the `groups` claim? | [Layer 1 §4](../30-identity-and-nhi/oauth-oidc-saml-and-api-auth/LAYER-1-IDENTITY-PROTOCOLS.md) — overage |
| I disabled the account; why is he still in? | Layer 1 §4 — token lifetime vs CAE |
| Why `ms-DS-ConsistencyGuid` over `objectGUID`? | [Layer 2 §1.4](../30-identity-and-nhi/entra-users-and-groups/LAYER-2-DOMAIN-1-USER-IDENTITIES.md) |
| Two grant controls — AND or OR? | [Layer 3 §2](../30-identity-and-nhi/conditional-access/LAYER-3-DOMAIN-2-AUTH-AND-ACCESS.md) — AND by default |
| How do you get secrets out of CI/CD? | [Layer 4 §4](../30-identity-and-nhi/service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md) — federation |
| Why must break-glass not be PIM-eligible? | [Layer 5 §4](../30-identity-and-nhi/pim-and-access-reviews/LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md) |
| How is an AI agent's identity governed? | [Layer 6](../60-ai-and-secure-ai/ai-agent-identity/LAYER-6-SC500-BRIDGE-AI-SECURITY.md) — Agent ID |

**And the one that decides the interview: "what went wrong, and what did you do?"** The `break-fix/`
folders exist for this. An engineer with no failure stories has either not done the work or is not
being straight — and both readings are bad.

---

## 6. The customer workshop

Running a discovery workshop is a distinct, learnable skill. Structure: current state (they talk,
you listen and write), constraints, options with trade-offs, decision, next steps and owners.

**Ask the eight discovery questions from [Layer 7 §1](../80-customer-scenarios/LAYER-7-INDUSTRY-VERTICALS.md).**
The first — *"which Microsoft cloud instance?"* — constrains everything downstream, which is why it
goes first.

**Practise saying no**, out loud, before you need it:

> *"That system can't be secured at the identity layer. We'll secure the path to it instead."*
> *"That feature isn't available in your cloud instance. Here's what is, and here's the gap."*
> *"You're not licensed for that today. Here's what your current licences achieve."*

Said early, these cost nothing. Said after they are in a design document, they cost the engagement.

---

## 7. Final gap log — the most valuable document you produce

Close the sprint by writing down what you **cannot** yet do. Honestly.

| Area | Level | Evidence | Gap |
|---|---|---|---|
| Entra Connect Sync | Trialled | Lab build; duplicate-object repair | No multi-forest; no production scale |
| Conditional Access | Trialled | Baseline built; lockout recovered via break-glass | No large-tenant rollout |
| T2T migration | Researched | Design only | No delivery |

**This document is what makes everything else believable.** A portfolio claiming uniform mastery is
not credible. A portfolio with a precise, self-authored gap log is the work of someone who can be
trusted with a customer — because they will tell you when they are out of depth.

---

## 8. Deliverables

| Facet | Artifact |
|---|---|
| `lab/` | — (no build today) |
| `break-fix/` | Consolidated failure catalogue from Days 1–9, with symptoms and fixes |
| `security/` | Risk register with residual risk; NHI register; posture summary |
| `operations/` | Runbook set, SOPs, handover pack, support boundary |
| `architecture-decisions/` | HLD, LLD, and the ADR set |
| `customer-use-cases/` | One case pack per vertical — [Layer 7](../80-customer-scenarios/LAYER-7-INDUSTRY-VERTICALS.md) |

---

## Closeout — the honest one

- What can you now **do**, with evidence, that you could not on Day 1?
- What did you only **read** about?
- What broke, and could you diagnose it from the error alone?
- Which artifact would you be comfortable handing a paying customer **tomorrow**?
- What is the next gap, and what is the smallest experiment that closes it?

> **Reminder.** Finishing this sprint is not SC-300 readiness — that is Layers 1–7, indexed in
> [SC-300-MASTERY-SYLLABUS.md](../SC-300-MASTERY-SYLLABUS.md). This track is M365/Azure/migration
> engineering. They share Day 1 and they share the identity layers. They are not the same
> qualification, and conflating them in a CV is the overclaiming this repo exists to prevent.
