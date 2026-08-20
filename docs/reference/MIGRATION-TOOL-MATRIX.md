# M365 Migration Tool Matrix

This is a research and verification matrix. Tool names are not production claims. Mark each capability as `research`, `trial`, `lab-verified`, or `production-verified` only when evidence supports it.

| Tool | Main scenarios to investigate | Evidence required |
|---|---|---|
| Microsoft native | Migration Manager, Exchange methods, SharePoint, OneDrive, cross-tenant | Executed workflow, limits, reports, errors, rollback |
| Migration Manager | File shares and content into Microsoft 365 | Source scan, task, permissions, validation, failure case |
| BitTitan MigrationWiz | Mailbox, documents, tenant and cross-platform migrations | Trial workflow, mapping, throttling, reporting, reconciliation |
| Quest On Demand | Enterprise tenant and workload migrations | Assessment, coexistence, wave, reporting, support case |
| ShareGate | SharePoint, Teams, OneDrive migration and governance | Inventory, mapping, permissions, links, report |
| Cloudiway | Cross-platform and tenant migration | Scope, identity mapping, migration run, validation |
| AvePoint | Enterprise content, governance and compliance | Tool capability, permission model, reports, limitations |
| Xillio | Content/application migration | Assessment, transformation, mapping, validation |

## Selection criteria

- Source and target workloads.
- Identity and domain support.
- Permissions and ownership fidelity.
- Teams, Groups, SharePoint, OneDrive, public-folder support.
- Coexistence and delta migration.
- Throttling and retry behavior.
- Reporting and reconciliation.
- Data handling and residency.
- Security model and privileged access.
- Licensing and total cost.
- API support and automation.
- Vendor support and escalation.
- Rollback and recovery options.

## Required tool evidence

For every tool personally tested: record tenant type, date, version/state, permissions used, source data, configuration, output, limitations, failed attempt, cleanup, and official documentation checked. Never present vendor marketing as independent validation.
