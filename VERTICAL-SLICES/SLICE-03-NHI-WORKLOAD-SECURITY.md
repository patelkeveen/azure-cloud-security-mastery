# Slice 3 — NHI and Workload Security

Scenario: replace long-lived deployment credentials with managed identity and workload identity federation.

## Required layers

App registration, federated credential, OIDC claims, GitHub/Azure DevOps trust, Key Vault, managed identity, permissions, token flow, logging, rotation, revocation, and least privilege.

## Failure scenario

Issuer or subject mismatch prevents federation. Capture the error, inspect claims, correct the trust condition, verify token scope, and demonstrate that unauthorized secret retrieval fails.

## Evidence

NHI inventory, token-flow diagram, deployment configuration, permissions review, failed run, corrected run, revocation procedure, detection, and RCA.
