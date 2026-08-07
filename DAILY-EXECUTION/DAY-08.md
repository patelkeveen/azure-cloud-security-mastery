# Day 8 — Migration Factory 2

## Outcome

Design and test Exchange hybrid, SharePoint/OneDrive/Teams cutover, rollback, and reconciliation procedures.

## Tasks

1. Document hybrid prerequisites: DNS, certificates, Autodiscover, OAuth, connectors, organization relationships, and free/busy.
2. Model mailbox batches, pre-stage, final sync, bad-item handling, monitoring, and acceptance criteria.
3. Model SharePoint, OneDrive, Teams, Groups, public-folder, permissions, links, owners, and app dependencies.
4. Build cutover, communication, fallback, validation, hypercare, and decommission plans.

## Failure exercises

- MRS or batch failure.
- Autodiscover or free/busy failure.
- Mail-flow connector issue.
- Permission/owner mismatch.
- Teams/SharePoint reconciliation failure.

## Deliverables

Hybrid troubleshooting guide, configuration checklist, migration batch plan, final-delta checklist, rollback decision tree, reconciliation report, and operations manual.

## Teach-back

Explain why rollback may not mean simply reversing DNS after data has changed in both environments.
