# Daily Execution Pack

This directory converts the roadmap into an execution specification. Every day requires: business context, prerequisites, command journal, hands-on implementation, deliberate failure, evidence, cleanup, teach-back, and gap log.

> **Do not use this directory for the August 28 SC-300 exam sprint.** This is the 10-day M365,
> migration, security, and customer-delivery breadth pack. For SC-300, start at
> [`../SC-300-EXAM-READINESS.md`](../SC-300-EXAM-READINESS.md), then run
> [`../SC-300-SPRINT/README.md`](../SC-300-SPRINT/README.md).

## Daily contract

- 8–10 focused hours, with safety breaks and cost controls.
- No production tenant or customer data.
- Use synthetic identities and sanitized evidence.
- Verify every command and permission before applying it.
- Stop before destructive or costly actions and review the rollback plan.
- Do not mark a tool as verified until personally tested.

## Days

- `DAY-01.md` — platform baseline and governance.
- `DAY-02.md` — Exchange Online, mail flow, and email security.
- `DAY-03.md` — SharePoint, OneDrive, Teams, and collaboration governance.
- `DAY-04.md` — AD, hybrid identity, Entra Connect, Cloud Sync, and federation.
- `DAY-05.md` — M365 discovery, inventory, dependency mapping, and assessment.
- `DAY-06.md` — migration tooling ecosystem and benchmarking.
- `DAY-07.md` — Google Workspace-to-M365 and tenant-to-tenant factory.
- `DAY-08.md` — Exchange hybrid, SPO/Teams cutover, rollback, and reconciliation.
- `DAY-09.md` — SecOps, Defender/Sentinel, Intune, NHI, and automation.
- `DAY-10.md` — HLD/LLD, ADRs, customer delivery, and interview defense.

Each day links to a vertical slice and must end with an evidence index update.
