# Day 4 — AD, Hybrid Identity, and Federation

## Outcome

Understand the dependencies and failure modes of AD DS, Entra Connect, Cloud Sync, PHS, PTA, ADFS, and federation.

## Tasks

1. Build or simulate a safe AD lab with DNS, OUs, UPNs, test users, groups, and service accounts.
2. Compare PHS, PTA, and federation using availability, security, dependency, and migration criteria.
3. Study Entra Connect source anchor, ms-DS-ConsistencyGuid, soft match, hard match, filtering, staging, and health.
4. Compare Entra Connect Sync and Cloud Sync for topology, agents, filtering, and recovery.
5. Document ADFS claims, certificates, endpoints, and failure dependencies without treating a design note as production evidence.

## Failure exercises

- Duplicate proxy address.
- UPN mismatch.
- Soft-match failure.
- Sync rule or filtering error.
- Certificate or ADFS endpoint failure.
- Active-to-staging swing and rollback design.

## Deliverables

Hybrid decision tree, identity-flow diagram, failure tickets, remediation scripts in a sandbox, and migration/rollback runbook.

## Teach-back

Explain how a directory object becomes an Entra object, why DNS and certificates matter, and how you prevent a synchronization mistake from affecting thousands of users.
