# Start Here

Use this repository as an implementation portfolio, not as passive notes.

## Before anything else: know what is real

Run this, or read the file it writes:

```powershell
.\tools\Build-CoverageRegister.ps1
```

[`COVERAGE.md`](COVERAGE.md) is generated from the filesystem. It states, per topic, whether
anything is actually written and **which of the six evidence facets are missing**. The
directory tree is an *intended* curriculum — most of it is scaffold. Trust the register, not
the folder names.

## The only track with real content today: SC-300 → SC-500 identity

Read in this order. Each layer assumes the previous one.

1. **[Layer 1 — Identity protocols](30-identity-and-nhi/oauth-oidc-saml-and-api-auth/LAYER-1-IDENTITY-PROTOCOLS.md)**
   OAuth flow selection, JWT claim-by-claim, SAML, SCIM, the consent framework.
   *Nothing downstream makes sense without this, and it appears in no Microsoft study guide.*
2. **[Layer 2 — User identities](30-identity-and-nhi/entra-users-and-groups/LAYER-2-DOMAIN-1-USER-IDENTITIES.md)** — including hybrid identity, the deepest well of real-world work
3. **[Layer 3 — Authentication & Conditional Access](30-identity-and-nhi/conditional-access/LAYER-3-DOMAIN-2-AUTH-AND-ACCESS.md)**
4. **[Layer 4 — Workload identities](30-identity-and-nhi/service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md)**
5. **[Layer 5 — Identity governance](30-identity-and-nhi/pim-and-access-reviews/LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md)**
6. **[Layer 6 — SC-500 bridge: Agent ID and AI security](60-ai-and-secure-ai/ai-agent-identity/LAYER-6-SC500-BRIDGE-AI-SECURITY.md)**
7. **[Layer 7 — Industry verticals](80-customer-scenarios/LAYER-7-INDUSTRY-VERTICALS.md)**

Map: [SC-300-MASTERY-SYLLABUS.md](SC-300-MASTERY-SYLLABUS.md) ·
Sources: [SC-300-RESOURCE-LIBRARY.md](SC-300-RESOURCE-LIBRARY.md)

## Prerequisite: a tenant of your own

Every lab in every layer needs one. Reading without a tenant produces recall, not capability.

```powershell
.\30-identity-and-nhi\entra-users-and-groups\Seed-LabTenant.ps1          # plan
.\30-identity-and-nhi\entra-users-and-groups\Seed-LabTenant.ps1 -Apply   # build
```

Seeds 16 users with a manager chain, dynamic groups, a break-glass pair, and a lab app
registration — enough for access reviews, PIM and dynamic-membership labs to mean something.

## What "done" means for a topic

A topic is complete when its folder carries **concept prose plus evidence in the six facets**:

| Facet | Contains |
|---|---|
| `lab/` | Reproducible build, with commands and expected output |
| `break-fix/` | A failure caused **on purpose**, diagnosed, and fixed |
| `security/` | Threat model, attack path, hardening, detection |
| `operations/` | Monitoring, alerting, runbook, rollback |
| `customer-use-cases/` | Two or more industry scenarios with the trap named |
| `architecture-decisions/` | The trade-off, the alternatives, why this one |

Anything less stays marked as research. `COVERAGE.md` enforces this by counting facets — a
topic cannot be marked WRITTEN by asserting it.

## Daily rhythm

- Learn the official concept from primary documentation, not a blog
- Build the smallest useful implementation
- Record commands, permissions, and expected output
- **Break one dependency on purpose** — this is where the learning is
- Diagnose from logs, metrics, and admin portals
- Fix, roll back, or redeploy cleanly
- Explain customer value, risk, cost, and support model

## Honesty rule

Do not claim a tool, migration, or workload is mastered until this repo contains personally
verified evidence. Research is valuable and must be labelled as research.

The corollary, which is easier to violate: **do not let structure imply coverage.** An empty
folder is a plan. `COVERAGE.md` exists so the difference stays visible.
