# Operating Model

## How work moves through the repository

1. **Select** — choose a capability based on certification coverage, market demand, customer value, and current gap.
2. **Frame** — define the business problem, constraints, success metrics, risk, and Decision Stack.
3. **Learn** — use official sources first; record useful unofficial explanations separately.
4. **Build** — execute a reproducible lab with safe setup and cleanup.
5. **Inspect** — verify configuration, permissions, data flow, logs, and expected output.
6. **Break** — introduce controlled failures and record symptoms.
7. **Fix** — diagnose from evidence, repair, verify, and document prevention.
8. **Operate** — add monitoring, alerts, runbook, backup, recovery, and escalation.
9. **Deliver** — produce customer-facing design, implementation, test, migration, and handover artifacts.
10. **Defend** — teach it at child, new-engineer, customer, and expert levels.
11. **Publish** — link only sanitized and verified evidence to portfolio and resume surfaces.

## Completion gates

### Indexed

The capability is named and mapped.

### Researched

Official sources and carefully labeled supplemental sources are recorded.

### Lab-planned

Prerequisites, setup, steps, verification, cleanup, and expected results exist.

### Lab-verified

The lab was personally executed and evidence was retained.

### Operated

The system was monitored, deliberately broken, repaired, and documented with an RCA and runbook.

### Customer-ready

The capability has a customer case, HLD/LLD, risks, testing, change/cutover, rollback, operations, and handover artifacts.

### Production-verified

Use only for genuine professional experience. Never infer it from a personal lab.

## Quality review

Every completed item is reviewed for correctness, reproducibility, security, cost, operational realism, customer usefulness, and honest status.

## AI-assisted work rule

AI may accelerate research, scaffolding, and drafting. The learner must still understand the implementation, inspect permissions and data flow, test failure cases, review security, and explain every important line or command without hiding behind the tool.

## Continuous review rule

After every task — lab, command, failure exercise, migration step, or document — the repository is reviewed and updated before the task is considered done:

1. Re-read the affected files and check they still match reality.
2. Update the stage gate (INDEXED → RESEARCH → LAB-PLANNED → LAB-VERIFIED → OPERATED → CUSTOMER-READY) only when evidence supports it.
3. Update `COMPLETENESS-REGISTER.md`, the command journal, the evidence index, and the gap log.
4. Record what broke, what was learned, what remains unverified, and what the next task is.
5. Commit with a message that states what was verified, not just what was written.

A task is not finished when the work is done; it is finished when the repository reflects the work accurately.
