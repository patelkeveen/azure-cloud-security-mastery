# Execution Roadmap

## Sprint principle

Do not add more topic lists until the active vertical slice has a working lab, a deliberate failure, operational evidence, and customer documentation.

## Priority order

1. Baseline, cost controls, evidence standards, and networking.
2. Microsoft 365 assessment, Exchange mail flow, SharePoint/OneDrive/Teams governance.
3. AD, Entra Connect, Cloud Sync, ADFS, hybrid identity and rollback.
4. NHI, Key Vault, managed identity, workload federation, OAuth/OIDC/SAML.
5. M365 migration factory and tool-selection matrix.
6. Security operations, Sentinel/KQL, Defender, Purview and incident response.
7. Resilience, monitoring, backup, restore, DR and service handover.
8. Secure AI workload and agent identity.
9. Industry cases and customer delivery.
10. Portfolio and interview defense.

## Ten-day exit criteria

At the end of the intensive sprint, do not claim mastery of everything. Claim only what is supported by evidence. The target exit is:

- One working Azure networking/IaC vertical slice.
- One working identity/NHI vertical slice.
- One M365 assessment and mail-flow case.
- One migration factory design with pilot, cutover, rollback, and reconciliation.
- One security incident with KQL/Defender/Purview evidence.
- One secure AI design with threat model and data-flow.
- One complete customer-delivery pack.
- A verified gap list for all remaining items in `COMPLETENESS-REGISTER.md`.

## Definition of done for the sprint

- Evidence is reproducible and sanitized.
- Cleanup was completed and cost was reviewed.
- At least three failures were diagnosed from evidence.
- Commands and permissions are understood.
- Architecture decisions and alternatives are written.
- Customer artifacts are usable by another engineer.
- Unverified areas remain explicitly labeled.
