# Day 1 — Platform Baseline and Governance

## Outcome

Create a safe, governed lab foundation for Azure and Microsoft 365 work without claiming enterprise production deployment.

## Tasks

1. Confirm tenant/subscription ownership, regions, quotas, billing visibility, and cleanup authority.
2. Install and verify Azure CLI, PowerShell 7, Az, Microsoft Graph, ExchangeOnlineManagement, SharePoint tooling, Bicep, Terraform, Git, and VS Code extensions.
3. Establish resource-group, tags, budget, logging, and naming conventions.
4. Design management groups and subscriptions on paper first; implement only what the lab account supports.
5. Create test identities and break-glass design documentation. Never disable safeguards in a real tenant.
6. Create baseline RBAC and Policy examples in a sandbox.

## Command journal

For each command record purpose, parameters, required permission, expected output, control-plane effect, data-plane effect, cost, failure mode, and cleanup.

```text
az version
az account show
az group create ...
az resource list ...
az policy definition list ...
Get-AzContext
Get-MgContext
Connect-ExchangeOnline
terraform init
terraform plan
```

Use exact parameters only after checking current official documentation and account scope.

## Failure exercises

- Wrong subscription or resource group.
- Policy denial caused by an unapproved region.
- Missing RBAC permission.
- Terraform state or provider authentication failure.

## Deliverables

Baseline verification log, naming/tagging standard, budget record, governance ADR, cleanup procedure, and first architecture diagram.

## Teach-back

Explain management groups versus subscriptions, RBAC versus Policy, control plane versus data plane, and why a lab must have cost and deletion controls.
