# Day 5 — M365 Discovery and Assessment

## Outcome

Build a professional-services assessment process for users, identity, data, applications, permissions, licenses, dependencies, and risk.

## Tasks

1. Define inventory schema for domains, users, groups, licenses, mailboxes, forwarding, delegates, sites, OneDrive, Teams, guests, apps, devices, and service identities.
2. Use Graph and workload-specific tools with least privilege, pagination, throttling handling, retries, and sanitized output.
3. Identify applications relying on SMTP relay, NTLM, Kerberos, LDAP, ADFS, legacy auth, or expired credentials.
4. Create migration complexity scoring based on data volume, permissions, dependencies, users, external access, and deadlines.

## Failure exercises

- Graph throttling.
- Insufficient permission.
- Pagination bug.
- Incomplete inventory.
- Stale owner or service identity.

## Deliverables

Discovery questionnaire, inventory scripts, CSV/JSON schema, dependency map, risk register, complexity scorecard, and assessment report.

## Teach-back

Explain why discovery is not just collecting object counts; it is identifying migration dependencies, business owners, risk, and acceptance criteria.
