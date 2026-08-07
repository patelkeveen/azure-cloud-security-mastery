# Day 7 — Migration Factory 1

## Outcome

Design a complete Google Workspace-to-M365 and M365 tenant-to-tenant migration factory using synthetic data and documented assumptions.

## Tasks

1. Inventory source users, groups, domains, Gmail, Drive, shared drives, calendars, aliases, permissions, and applications.
2. Model Google API/OAuth/domain-wide-delegation requirements; do not commit service-account keys.
3. Design target identities, licenses, coexistence, source-to-target mapping, pilot waves, pre-stage, delta, cutover, rollback, and hypercare.
4. Design tenant-to-tenant cross-tenant access, domain release/attach sequence, UPN transition, application re-registration, devices, permissions, and validation.

## Failure exercises

- OAuth scope or consent error.
- Invalid grant or expired credential.
- Domain cannot be released.
- Mapping collision.
- Delta reconciliation mismatch.

## Deliverables

HLD, LLD, migration plan, wave chart, domain-transition timeline, communication plan, cutover checklist, rollback SOP, and reconciliation report template.

## Teach-back

Explain why identity and domain sequencing often determines whether a migration succeeds, not merely the data-copy tool.
