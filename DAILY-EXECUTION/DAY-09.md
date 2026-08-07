# Day 9 — SecOps, Intune, NHI, and Automation

## Outcome

Connect identity, endpoint, workload identity, monitoring, and security operations.

## Tasks

1. Implement or document managed identities, user-assigned identities, Key Vault, workload federation, owner review, expiry, rotation, and revocation.
2. Build safe Conditional Access policy design: phishing-resistant admin MFA, compliant device, legacy-auth block, risk-based controls, exclusions, report-only, and emergency access.
3. Review Intune compliance, configuration profiles, Autopilot, device identity, and Conditional Access signal flow.
4. Send appropriate Entra, Azure, M365, and Defender signals to Log Analytics/Sentinel; write KQL detections for sign-in anomalies, consent abuse, and NHI risk.
5. Automate only with least privilege, testing, dry-run, blast-radius limits, logging, and rollback.

## Failure exercises

- OIDC subject mismatch.
- Key Vault permission failure.
- Conditional Access lockout risk.
- Missing Sentinel connector.
- Noisy or incomplete KQL detection.

## Deliverables

NHI register, federation lab, CA matrix, Intune baseline, KQL detection pack, incident runbook, RCA, and automation test record.

## Teach-back

Explain why an NHI is an identity, how its token is issued, what it can access, and how to contain it during compromise.
