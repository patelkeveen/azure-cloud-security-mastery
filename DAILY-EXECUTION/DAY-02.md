# Day 2 — Exchange Online, Mail Flow, and Email Security

## Outcome

Understand and document Exchange Online mail flow, connectors, transport rules, relay, authentication, and security controls using synthetic domains and test mailboxes.

## Tasks

1. Map accepted domains, internal relay versus authoritative behavior, connectors, transport rules, and mail-flow path.
2. Review SPF syntax and lookup limits; configure DKIM and DMARC only for a domain you control.
3. Study MTA-STS and TLS-RPT as design topics unless a safe test domain is available.
4. Review anti-phishing, impersonation, Safe Links, Safe Attachments, quarantine, and policy priority.
5. Use Exchange PowerShell to inspect configuration; avoid bulk changes until the expected result and rollback are known.

## Failure exercises

- Connector scope mismatch.
- SPF failure or excessive lookup chain.
- DKIM selector mismatch.
- DMARC alignment failure.
- Transport-rule priority conflict.

## Deliverables

Mail-flow diagram, DNS verification matrix, transport-rule audit, email-security decision record, troubleshooting tickets, and SOP.

## Teach-back

Trace an email from sender to recipient, explain authentication versus authorization, and explain why changing MX, SPF, DKIM, or DMARC can affect delivery.
