# Verification Checklist

## Workstation

- [ ] Git and repository synchronized.
- [ ] PowerShell 7 verified.
- [ ] Azure CLI verified.
- [ ] Az module verified.
- [ ] Microsoft Graph module verified.
- [ ] ExchangeOnlineManagement verified.
- [ ] SharePoint tooling verified where applicable.
- [ ] Bicep verified.
- [ ] Terraform verified.
- [ ] VS Code extensions installed.
- [ ] Secret scanning and safe credential storage configured.

## Tenant and subscription

- [ ] Lab tenant access confirmed.
- [ ] Azure subscription and billing owner confirmed.
- [ ] Region and quota reviewed.
- [ ] Budget alert configured.
- [ ] Resource tags and naming standard defined.
- [ ] Cleanup authority confirmed.
- [ ] Synthetic users and test data only.
- [ ] No customer secrets or personal data committed.

## Safety

- [ ] Break-glass design reviewed.
- [ ] Report-only before risky Conditional Access enforcement.
- [ ] Exclusions and rollback documented.
- [ ] Destructive commands reviewed before execution.
- [ ] Migration cutover and rollback approved in the lab plan.
- [ ] Cost-impacting resources have deletion/stop procedures.

## Evidence

- [ ] Command journal complete.
- [ ] Expected and actual output recorded.
- [ ] Permissions documented.
- [ ] Control-plane and data-plane behavior explained.
- [ ] At least three failures tested.
- [ ] Logs, screenshots, diagrams, and reports sanitized.
- [ ] Cleanup verified.
- [ ] Official documentation checked.
- [ ] Unofficial resources labeled.
- [ ] Status gate updated honestly.
