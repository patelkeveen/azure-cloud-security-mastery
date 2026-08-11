# Mail Flow and Hygiene

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Email is still the primary initial-access vector, and the controls are DNS records plus a
> handful of settings people set once and never revisit.**
> Pairs with [`../exchange-online/`](../exchange-online/) and
> [`../../10-networking/dns/`](../../10-networking/dns/).

---

## 1. ⭐ SPF, DKIM, DMARC — what each actually proves

**Three records, three different claims, and only one of them protects what users see.**

| | Checks | ⭐ Against | Survives forwarding? |
|---|---|---|---|
| **SPF** | sending **IP** | ⭐ the **envelope** sender (`MAIL FROM`) | ⭐ **No** — breaks on forward |
| **DKIM** | ⭐ **signature** over headers/body | the signing **domain** (`d=`) | ⭐ **Yes** |
| ⭐ **DMARC** | ⭐ **alignment** of SPF/DKIM with the **visible** `From:` | ⭐ **what the user sees** | via DKIM |

⭐ **This is the point of the whole section: SPF and DKIM validate domains the recipient never sees.**
A message can pass SPF perfectly while the `From:` header displayed in Outlook says
`ceo@yourcompany.com`. ⭐ **DMARC is the only one of the three that ties the technical check to the
human-visible address**, and that is why "we have SPF and DKIM" is not an answer.

```
Envelope MAIL FROM:  bounce@attacker.example      ← SPF checks THIS ✅ passes
Header From:         ceo@contoso.com              ← ⭐ the user sees THIS
                                                    ⭐ DMARC checks alignment between them
```

**And the policy ladder that most organisations never finish climbing:**

```
p=none        ⭐ monitor only — reports, no protection
p=quarantine  suspicious mail to junk
⭐ p=reject   ⭐ the only value that stops domain spoofing
```

⭐ **`p=none` is where DMARC deployments go to die.** It is correct as a starting point — you need the
reports to find your legitimate senders — but an organisation sitting at `p=none` for three years has
**telemetry, not a control**. It is the *"watch first"* pattern (`RETENTION.md` §3b) with nobody ever
performing step two.

---

## 2. Worked example — read a domain's posture in three commands

```powershell
# ⭐ Run this for the customer's domain before the meeting. It takes ten seconds.
$domain = 'contoso.com'

Resolve-DnsName -Name $domain -Type TXT |
  Where-Object Strings -match 'v=spf1' | Select-Object -Expand Strings

Resolve-DnsName -Name "_dmarc.$domain" -Type TXT |
  Where-Object Strings -match 'v=DMARC1' | Select-Object -Expand Strings

'selector1','selector2' | ForEach-Object {
  Resolve-DnsName -Name "$_._domainkey.$domain" -Type CNAME -EA SilentlyContinue |
    Select-Object Name, NameHost
}
```

```
v=spf1 include:spf.protection.outlook.com include:_spf.vendor.example ~all
                                                                      ▲
                                          ⭐ ~all = SOFTFAIL, not enforcing

v=DMARC1; p=none; rua=mailto:dmarc@contoso.com
          ▲
   ⭐ monitoring only — spoofing your own domain still lands
```

⭐ **Two findings in ten seconds, from public DNS, before you have any tenant access.** That is the
fastest credible opening a consultant has, and it works on any prospect.

| Marker | ⭐ Meaning |
|---|---|
| `-all` | ⭐ hard fail — enforcing |
| `~all` | ⚠ soft fail — "probably not us, deliver anyway" |
| `?all` | ⚠⚠ neutral — ⭐ **the record is decorative** |
| ⭐ >10 `include:` | ⚠ **SPF permerror** — the whole record stops evaluating |

⭐ **The 10-lookup limit is the classic operational failure.** Add one more SaaS sender and SPF starts
returning `permerror` — **and a permerror is not a fail, so mail often still flows and nobody
notices the control has switched itself off.**

---

## 3. ⭐ The connector and the exemption — where filtering is bypassed

**These are the two places an organisation quietly turns off its own protection:**

```
① ⭐ INBOUND CONNECTOR from a third-party gateway / "scanner" / on-prem relay
      → ⭐ mail arrives pre-authenticated and often SKIPS filtering
② ⭐ TRANSPORT RULE that sets SCL = -1
      → ⭐ "bypass spam filtering" for a sender, a domain, or an IP
```

```powershell
# ⭐ Find every rule that bypasses filtering. This is the query that finds the hole.
Get-TransportRule | Where-Object {
  $_.SetSCL -eq -1 -or $_.SetHeaderName -match 'SCL' -or $_.State -eq 'Enabled' -and $_.Description -match 'bypass'
} | Select-Object Name, State, SetSCL, SenderDomainIs, SenderIpRanges, FromAddressContainsWords
```

```
Name                        State    SetSCL  SenderDomainIs        SenderIpRanges
--------------------------  -------  ------  --------------------  --------------
Allow marketing platform    Enabled      -1  {mailer.example}                     <-- ⚠⚠ domain-only
Legacy scanner relay        Enabled      -1                        {203.0.113.7}  ✅ narrow
Allow simulated phishing    Enabled      -1  {phishsim.example}                   ⚠ verify still needed
```

⭐ **Row one is the finding.** A rule that bypasses spam filtering **based only on the sender domain**
is trivially abusable: **the sender domain is a header an attacker controls.** Anyone can put
`mailer.example` in a `From:` and land unfiltered in every inbox.

> ⭐ **A filtering exemption must be pinned to something the sender cannot forge** — an IP range, or
> a verified DKIM signature. **A domain name in a `From:` header is not evidence of anything**, which
> is exactly §1's argument arriving as an operational finding.

⚠ **Also audit connectors:**

```powershell
Get-InboundConnector | Select-Object Name, Enabled, ConnectorType, SenderIPAddresses,
                                     RestrictDomainsToIPAddresses, TlsSenderCertificateName
```

⭐ **`RestrictDomainsToIPAddresses = False` on a partner connector means the connector's trust can be
claimed by anyone who can assert those domains.**

---

## 4. Outbound — the half nobody reviews

```powershell
# ⭐ Is external auto-forwarding blocked at the tenant level?
Get-HostedOutboundSpamFilterPolicy |
  Select-Object Name, AutoForwardingMode, RecipientLimitExternalPerHour, ActionWhenThresholdReached
```

```
Name     AutoForwardingMode  RecipientLimitExternalPerHour  ActionWhenThresholdReached
-------  ------------------  -----------------------------  --------------------------
Default  Automatic           0                              BlockUser
         ▲
  ⚠ "Automatic" = ⭐ allowed unless something else blocks it
```

⭐ **`AutoForwardingMode = Off` is the tenant-wide control that closes the exfiltration path from
[`../exchange-online/`](../exchange-online/) §2** — one setting, and it defeats the most common BEC
persistence mechanism at the platform level rather than per mailbox.

⭐ **And outbound limits are a compromise detector**: a mailbox that suddenly sends to hundreds of
external recipients per hour is a compromised account or an internal spam incident, and
`ActionWhenThresholdReached = BlockUser` contains it automatically. **It is the cheapest automated
response in M365** and it needs no product beyond what is already licensed.

---

## 5. Filtering policies and the "who is exempt" question

| Policy | ⭐ Ask |
|---|---|
| **Anti-spam (inbound)** | ⭐ who is on the **allow list**, and why? |
| **Anti-phishing** | is ⭐ **impersonation protection** on for executives and your own domains? |
| **Safe Links / Safe Attachments** | ⚠ licence-dependent — [`../licensing-and-service-limits/`](../licensing-and-service-limits/) |
| ⭐ **Priority accounts** | are executives actually tagged? |

⭐ **Impersonation protection for your own domain and your executives is the control that maps
directly to the SendAs risk** in [`../exchange-online/`](../exchange-online/) §1 — same attack goal
(a message that appears to be from the CFO), reached from outside instead of inside.

⚠ **Allow lists are the mirror of policy exemptions in
[`../../20-azure-platform/azure-policy/`](../../20-azure-platform/azure-policy/) §3** — added for a
reason, never expired, and invisible on any dashboard. ⭐ **Audit them the same way: who, why, and
when does it end?**

---

## 6. What breaks

**"We have SPF and DKIM."** §1 — ⭐ neither checks what the user sees.

**DMARC stuck at `p=none`.** §1 — ⭐ telemetry, not a control.

**`~all` or `?all` in SPF.** §2 — soft or decorative.

**More than 10 `include:` lookups.** §2 — ⭐ permerror, and mail still flows.

**Filtering bypass keyed on sender domain.** §3 — ⭐ the attacker controls that header.

**Connectors without IP restriction.** §3.

**`AutoForwardingMode = Automatic`.** §4 — the exfiltration path stays open.

**No outbound recipient limit.** §4 — ⭐ the cheapest automated containment, unused.

**Allow lists never reviewed.** §5 — policy exemptions in another product.

**Impersonation protection off for executives.** §5.

---

## 7. Customer discovery questions

1. What is your **DMARC policy value** — and how long has it been `p=none`? *(§2 — check publicly.)*
2. Does SPF end in **`-all`**, and is it within the **10-lookup** limit?
3. ⭐ Which transport rules **bypass filtering**, and are any keyed on **sender domain**? *(§3.)*
4. Do inbound connectors **restrict domains to IP addresses**? *(§3.)*
5. Is **`AutoForwardingMode`** set to **Off**? *(§4.)*
6. Is there an **outbound recipient limit** with automatic blocking? *(§4.)*
7. Who is on the **anti-spam allow list**, and when was it last reviewed? *(§5.)*
8. Is **impersonation protection** configured for executives and your own domains?
9. Are executives tagged as **priority accounts**?

---

## 8. Remember it

**Hook — "SPF and DKIM check what the user never sees. DMARC checks what they do."**

**Analogy — the envelope, the wax seal, and the letterhead.** ⭐ **SPF inspects the postmark on the
envelope** — useful, and the envelope goes in the bin before anyone reads the letter. ⭐ **DKIM is a
wax seal proving the letter was not altered and came from a particular sealing ring.** ⭐ **DMARC is
the clerk who checks that the name on the letterhead matches the seal and the postmark** — and the
letterhead is the only part the reader ever looks at. **An organisation with SPF and DKIM but
`p=none` has a postmark and a seal, and no one comparing them to the letterhead.**

**The one thing:** ⭐ **a filtering exemption keyed on the sender domain is not a control, because the
sender domain is a header the attacker writes.** Every tenant accumulates these — for a marketing
platform, a legacy scanner, a phishing-simulation vendor — and each one is an open, unfiltered path
into every inbox that anyone in the world can use by typing the right address in a `From:` field.
**Pin exemptions to an IP range or a verified DKIM signature, or do not grant them.** One query finds
them, and the finding is usually immediate and severe.

**Runner-up:** ⭐ **`AutoForwardingMode = Off`** closes the BEC exfiltration path tenant-wide, in one
setting.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. What does each of SPF, DKIM and DMARC check, and against which address?
2. ⭐ Which is the only one tied to what the user sees, and why does that matter?
3. Which survives forwarding, and which does not?
4. Interpret `-all`, `~all`, `?all`.
5. ⭐ What happens past 10 SPF lookups, and why is that dangerous rather than merely broken?
6. Why is `p=none` for three years a finding?
7. ⭐ Why is a filtering bypass keyed on sender domain worthless?
8. What must an exemption be pinned to instead?
9. Which one setting closes tenant-wide auto-forwarding?
10. What is the cheapest automated containment in M365 mail flow?

<details>
<summary>Answers</summary>

1. **SPF** → sending **IP** against the ⭐ **envelope** sender; **DKIM** → a **signature** against the
   signing domain (`d=`); ⭐ **DMARC** → **alignment** with the visible **`From:`**.
2. ⭐ **DMARC** — SPF and DKIM validate addresses the recipient never sees, so a message can pass both
   while displaying `ceo@yourcompany.com`.
3. ⭐ **DKIM survives** forwarding; ⭐ **SPF breaks** on it.
4. `-all` hard fail (enforcing), `~all` soft fail, ⭐ `?all` neutral — **decorative**.
5. ⭐ **`permerror`** — and because a permerror is not a fail, ⭐ **mail often still flows and nobody
   notices the control switched itself off.**
6. ⭐ It is **monitoring only** — telemetry with no protection. The "watch first" pattern with step two
   never performed.
7. ⭐ Because the **sender domain is a header the attacker controls** — anyone can claim it.
8. ⭐ An **IP range** or a **verified DKIM signature** — something the sender cannot forge.
9. ⭐ **`AutoForwardingMode = Off`** in the hosted outbound spam filter policy.
10. ⭐ An **outbound external recipient limit** with **`ActionWhenThresholdReached = BlockUser`**.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — the §2 DNS check against your own domain and two others. **Runnable right now with
  no tenant access and no licence at all** — the only lab in the repo that needs nothing.
- **`break-fix/`** ⭐ — create a transport rule bypassing filtering **keyed on sender domain**, then
  send a message from an unrelated system asserting that domain and watch it land unfiltered. **Then
  re-key the exemption to an IP range and show the same message filtered.** That contrast is §3.
- **`security/`** — SPF/DKIM/DMARC posture per domain with the policy value and lookup count; transport
  rules that bypass filtering with justification and expiry; connector IP restrictions; allow-list
  review with dates; impersonation protection coverage.
- **`operations/`** — DMARC rollout plan from `none` → `quarantine` → ⭐ `reject` with dates and an
  owner; allow-list expiry review; outbound limit alerting.
- **`architecture-decisions/`** — ADR: exemptions pinned to IP or DKIM only, never to a sender domain;
  auto-forwarding off tenant-wide.
- **`customer-use-cases/`** — §7 answered; ⭐ the ten-second public DNS check used as the opening of a
  first meeting.
