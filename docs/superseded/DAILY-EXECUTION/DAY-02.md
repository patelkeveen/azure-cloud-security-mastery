# Day 2 — Exchange Online, Mail Flow, and Email Security

> Standard set by [DAY-01](DAY-01.md). `✅ verified` / `⚠ check` convention applies.

**Outcome:** you can trace a message end to end, explain every hop, and defend the three DNS
records that decide whether your mail is trusted. Email is where "it works on my machine" causes
the most customer pain, because failure is *silent* — the sender sees nothing.

**Prerequisite:** a tenant with Exchange Online (Day 1). A custom domain makes this far more real
than `*.onmicrosoft.com`.

---

## 1. Connect and orient

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser   # ✅
Connect-ExchangeOnline -UserPrincipalName admin@yourtenant.onmicrosoft.com   # ✅

Get-OrganizationConfig | Select-Object Name,IsDehydrated     # ✅
Get-AcceptedDomain | Format-Table DomainName,DomainType,Default    # ✅
Get-Mailbox -ResultSize 10 | Format-Table DisplayName,PrimarySmtpAddress,RecipientTypeDetails
```

**Permission:** Exchange Administrator or Global Administrator.

**Behind the scenes:** the module opens a REST-backed remote session. `IsDehydrated: True` means
the tenant still uses shared default config objects — many `Set-*` cmdlets will implicitly
"hydrate" it on first write. Harmless, but it explains why the first change to a setting is
slower than the rest.

**`DomainType` is the whole game:** `Authoritative` means Exchange Online owns every recipient for
that domain and will NDR unknown addresses. `InternalRelay` means unknown recipients get forwarded
on-premises. Getting this wrong during a hybrid migration black-holes mail for real users.

---

## 2. The three DNS records — what each actually proves

This is the highest-value 90 minutes of the day. Most engineers can name them; few can say what
each one *authenticates*.

| Record | Authenticates | Fails when |
|---|---|---|
| **SPF** (TXT) | The **connecting IP** is allowed to send for the envelope-from domain | Mail is forwarded — the forwarder's IP isn't in your SPF |
| **DKIM** (TXT, selector) | The **message body and selected headers** were not altered, via a signature | A gateway rewrites the body (footers, link rewriting) |
| **DMARC** (TXT, `_dmarc`) | **Alignment** — that SPF and/or DKIM pass *for the domain the user sees* | Neither aligned mechanism passes |

**The insight that matters: DMARC checks alignment, not just pass/fail.** A message can pass SPF
for `bounces.mailer.example` while the visible `From:` says `yourcompany.com`. SPF passed. DMARC
still fails, because the domains do not align. That single distinction explains most "but SPF
passes!" tickets.

```powershell
Get-DkimSigningConfig | Format-Table Domain,Enabled,Selector1CNAME,Selector2CNAME   # ✅
New-DkimSigningConfig -DomainName yourdomain.com -KeySize 2048 -Enabled $false      # ⚠ check
```

Publish the two selector CNAMEs **first**, then enable. Enabling before DNS resolves throws
`CNAME record does not exist`.

```powershell
Resolve-DnsName yourdomain.com -Type TXT | Where-Object Strings -match 'v=spf1'     # ✅
Resolve-DnsName _dmarc.yourdomain.com -Type TXT                                     # ✅
```

**SPF has a hard limit of 10 DNS lookups.** Exceed it and the result is `PermError`, which most
receivers treat as a fail. Every `include:` counts. Nesting three SaaS senders will do it. Flatten
or consolidate — do not keep adding.

**Deploy DMARC in this order, never straight to reject:**
`p=none` (observe reports) → `p=quarantine; pct=10` → raise `pct` → `p=reject`. Going to `p=reject`
first is how you discover your payroll provider was sending as you, by breaking payroll.

---

## 3. Mail flow: connectors and transport rules

```powershell
Get-InboundConnector  | Format-Table Name,Enabled,ConnectorType,SenderDomains,SenderIPAddresses
Get-OutboundConnector | Format-Table Name,Enabled,ConnectorType,RecipientDomains,SmartHosts
Get-TransportRule     | Format-Table Name,State,Priority,Description
```

**Behind the scenes — the order of evaluation:** connectors decide *routing* (which path a message
takes in or out). Transport rules run in **priority order, 0 first**, and a rule can stop later
rules from running. So a low-priority rule that never seems to fire is usually being pre-empted,
not misconfigured.

**Anti-spam and quarantine:**

```powershell
Get-HostedContentFilterPolicy | Format-Table Name,SpamAction,HighConfidenceSpamAction,BulkThreshold
Get-QuarantineMessage -PageSize 20 | Format-Table ReceivedTime,SenderAddress,Subject,Type   # ⚠ check
```

**SMTP relay** — the perennial customer ask. Three options: a **connector with IP allow-list**
(devices with static IPs), **direct send** to `yourdomain-com.mail.protection.outlook.com` (no
auth, internal recipients only), or **SMTP AUTH client submission** on port 587.

> ⚠ **SMTP AUTH is legacy authentication and cannot do MFA.** It bypasses every Conditional Access
> policy you will write on Day 9. If a multifunction printer must relay, use a connector with an IP
> restriction — not a service account with a password. See
> [Layer 3 §3.1](../../../30-identity-and-nhi/conditional-access/LAYER-3-DOMAIN-2-AUTH-AND-ACCESS.md).

---

## 4. Trace a real message

```powershell
Get-MessageTrace -StartDate (Get-Date).AddDays(-2) -EndDate (Get-Date) -PageSize 50 |
    Format-Table Received,SenderAddress,RecipientAddress,Subject,Status                 # ✅

Get-MessageTrace -MessageTraceId <guid> -RecipientAddress user@domain.com |
    Get-MessageTraceDetail | Format-Table Date,Event,Detail                             # ⚠ check
```

`Status` values worth knowing: `Delivered`, `Failed`, `Pending`, `Quarantined`, `FilteredAsSpam`,
`Expanded` (distribution group).

**Read the internet headers of a real message** — the deliverable of this section. In Outlook:
*File → Properties → Internet headers*. Find `Authentication-Results` and read the `spf=`,
`dkim=` and `dmarc=` verdicts, then `Received:` headers **bottom-up** — the bottom is the origin.

---

## 5. Failure exercises — cause them, record the exact text

| Cause it | Expected |
|---|---|
| Enable DKIM before publishing the CNAMEs | `CNAME record does not exist` / no valid selector |
| Add `include:` entries past 10 DNS lookups | `PermError` in `Authentication-Results` |
| Set a domain `Authoritative` with an on-prem-only recipient | NDR `550 5.4.1 Recipient address rejected: Access denied` |
| Two transport rules, both matching, first one stops processing | Second rule never appears in the trace |
| Send from an external forwarder | SPF fails, DMARC fails if DKIM doesn't align — the classic forwarding break |

---

## 6. Teach-back

1. **SPF vs DKIM vs DMARC in one sentence each?** SPF authorises the sending IP; DKIM proves the
   message wasn't altered; DMARC requires one of them to pass **and align** with the visible From.
2. **Why does forwarding break SPF?** The forwarder's IP isn't in the original domain's SPF record.
3. **Why not deploy `p=reject` immediately?** You don't yet know which legitimate senders you'd
   break. `p=none` reporting tells you.
4. **Authoritative vs InternalRelay?** Who owns recipient resolution — and therefore who NDRs.
5. **Why is SMTP AUTH a security problem?** Legacy auth: no MFA, bypasses Conditional Access.
6. **Where does a transport rule sit relative to a connector?** Connectors route; rules act on the
   message in transit, in priority order.

---

## 7. Deliverables

| Facet | Artifact |
|---|---|
| `lab/` | Mail-flow diagram from real headers; DKIM enabled; DMARC at `p=none` with reports arriving |
| `break-fix/` | Five failures above with exact NDR / `Authentication-Results` text |
| `security/` | SPF/DKIM/DMARC posture; relay decision and why; legacy-auth exposure list |
| `operations/` | Message-trace runbook; quarantine release SOP; DMARC rollout plan with gates |
| `architecture-decisions/` | ADR: relay method chosen and rejected alternatives |
| `customer-use-cases/` | Retail (high-volume transactional) vs finance (strict DMARC) — [Layer 7](../../../80-customer-scenarios/LAYER-7-INDUSTRY-VERTICALS.md) |

**Cleanup:** disable test transport rules, remove test connectors, set DMARC back to `p=none` if
you raised it. Leaving a stray rule at priority 0 will confuse you for weeks.
