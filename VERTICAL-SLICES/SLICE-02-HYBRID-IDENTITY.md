# Slice 2 — Hybrid Identity Recovery

Scenario: synchronize a multi-forest directory to Entra ID, operate active/staging sync, and recover from object collisions.

## Required layers

AD/DNS/Kerberos dependencies, source anchor, PHS/PTA/federation decision, Connect/Cloud Sync, filtering, health, staging, monitoring, rollback, customer impact, and support model.

## Failure scenario

Duplicate proxy address or UPN conflicts block synchronization. Diagnose from logs, remediate safely, verify object state, and document blast radius and prevention.

## Evidence

Identity-flow diagram, sync decision record, remediation script, incident timeline, recovery runbook, validation output, and customer explanation.
