# Exchange Hybrid

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> Builds on
> [`../../35-active-directory-and-hybrid-identity/hybrid-coexistence/`](../../35-active-directory-and-hybrid-identity/hybrid-coexistence/)
> and [`../exchange-online/`](../exchange-online/).
> ⭐ **The recurring theme: on-premises stays authoritative for longer than anyone expects.**

---

## 1. What hybrid actually is

**Two Exchange organisations behaving as one, joined by trust and DNS rather than by merging.**

```
On-premises Exchange ◀── ⭐ free/busy, mail flow, mailbox moves ──▶ Exchange Online
        │                                                                │
        └──────── ⭐ ONE address space, ONE GAL, ONE user experience ─────┘
```

**What makes it work, and each is a thing that can break:**

| Component | ⭐ Security relevance |
|---|---|
| **Hybrid Configuration Wizard** | ⭐ writes connectors, ⚠ and its choices persist long after |
| ⭐ **OAuth / hybrid auth** | ⭐ the trust that lets each side act for the other |
| **Send/receive connectors** | ⭐ certificate-authenticated mail path — §3 |
| **Autodiscover** | the on-prem endpoint stays load-bearing |
| ⭐ **Directory sync** | [`../../35-active-directory-and-hybrid-identity/entra-connect-sync/`](../../35-active-directory-and-hybrid-identity/entra-connect-sync/) |

---

## 2. ⭐ On-premises AD remains the source of truth

> **In a hybrid with directory synchronisation, ⭐ Exchange-related attributes are mastered
> on-premises.** Many mail properties of a cloud mailbox cannot be changed in the cloud — they are
> overwritten by the next sync cycle.

⭐ **This is the single most confusing thing about hybrid for cloud-first engineers**, and it produces
a recurring incident shape:

```
① Admin changes an attribute in Exchange Online admin centre
② It appears to work
③ ⭐ Next sync cycle: reverted
④ Ticket: "the change doesn't stick"     ⭐ nobody suspects sync
```

⭐ **The "delta between environments" from
[`../../00-foundations/troubleshooting-method/`](../../00-foundations/troubleshooting-method/) §3, and
the fix is to know where the object is mastered before you change it.**

⚠ **The security consequence is larger than the annoyance:** on-premises AD compromise reaches cloud
mail. **An attacker with the right on-prem AD rights can modify mail attributes — including
delegation and forwarding-adjacent properties — and those changes flow up.** Cloud-only hardening does
not protect an object whose master is on-premises, which is the argument for tiered administration in
[`../../35-active-directory-and-hybrid-identity/ad-ds/`](../../35-active-directory-and-hybrid-identity/ad-ds/).

⚠ **The tooling matters and it moves.** Exchange attribute management on-premises has historically
required Exchange management tools or the Exchange Management Tools-only install. ⭐ **Verify the
currently supported method in the target environment** rather than assuming raw ADSI edits are
acceptable — unsupported attribute edits are a classic source of half-broken mail objects.

---

## 3. ⭐ The hybrid connector is a trusted, unfiltered path

**The connectors the wizard creates authenticate with a certificate and are trusted by both sides.**

```
On-prem Exchange ──TLS + certificate──▶ ⭐ EXO inbound connector (OnPremises type)
                                        ⭐ mail arrives INTERNAL, often filtered less
```

⭐ **So compromise of the on-premises Exchange server yields an authenticated, trusted path into the
tenant** — messages that appear internal, from your own domain, arriving on a connector configured to
trust them. **This is the same finding as §3 in
[`../mail-flow-and-hygiene/`](../mail-flow-and-hygiene/), with a certificate instead of an IP range,
and it is the reason hybrid Exchange servers are high-value targets.**

```powershell
Connect-ExchangeOnline

# ⭐ What does the hybrid connector actually trust?
Get-InboundConnector | Where-Object ConnectorType -eq 'OnPremises' |
  Select-Object Name, Enabled, SenderIPAddresses, TlsSenderCertificateName,
                RestrictDomainsToIPAddresses, RequireTls
```

```
Name                          Enabled  SenderIPAddresses  TlsSenderCertificateName  RestrictDomains…
----------------------------  -------  -----------------  ------------------------  ---------------
Inbound from on-premises         True  {203.0.113.0/24}   mail.contoso.com                    True   ✅
```

⭐ **Both `SenderIPAddresses` and `TlsSenderCertificateName` populated, with
`RestrictDomainsToIPAddresses = True`, is the healthy state.** Certificate alone is weaker than
certificate plus IP — ⚠ and a wildcard or long-expired certificate name here is a real finding.

⭐ **And the exposure that survives decommissioning:** an organisation that has "finished" migrating
often leaves the hybrid connectors, the on-prem server and the certificate in place. **A trusted,
authenticated inbound path maintained by nobody is the mail-flow equivalent of the orphaned ring-0
driver** in [`../../00-foundations/computing-and-operating-systems/`](../../00-foundations/computing-and-operating-systems/) §2.

---

## 4. ⭐ The last Exchange server, and why it stays

**Even after every mailbox has moved, most organisations keep one on-premises Exchange server**, for
attribute management (§2) and because the recipient objects are AD-mastered.

⭐ **That server is a problem shaped like a solution:**

| Property | ⭐ Consequence |
|---|---|
| Internet-facing, historically | ⭐ **the most exploited on-prem product of the last five years** |
| Holds high AD privilege by design | ⭐ Exchange's AD permissions are extensive |
| ⭐ Nobody's priority to patch | it "does nothing" — so it is unmonitored and unpatched |
| Trusted by the tenant | §3 |

> ⭐ **"We only keep it for attribute management" describes the business case, not the risk.** The
> server is unpatched precisely *because* it appears to do nothing, and it holds both extensive AD
> rights and a trusted path into the tenant.

⭐ **The correct posture if it must remain:** not internet-facing, patched on the same cadence as a
domain controller, monitored, and **removed from the mail path if it is only there for attributes.**
⚠ **Verify Microsoft's current guidance on Exchange management tools and recipient management before
committing to a decommission plan** — this area has changed and continues to.

---

## 5. Worked example — the coexistence audit

```powershell
# ① ⭐ Which mailboxes are still on-premises, and which are cloud?
Get-EXOMailbox -ResultSize Unlimited -Properties RecipientTypeDetails |
  Group-Object RecipientTypeDetails | Select-Object Count, Name
```

```
Count Name
----- ----
 4210 UserMailbox
  318 MailUser                 <-- ⭐ still on-premises (remote objects in cloud)
   47 SharedMailbox
    9 ⚠ (unrecognised)
```

```powershell
# ② ⭐ Objects synced from on-prem — remember these are AD-mastered (§2)
Get-EXOMailbox -ResultSize Unlimited -Properties IsDirSynced,WhenChanged |
  Where-Object { -not $_.IsDirSynced } |
  Select-Object UserPrincipalName, RecipientTypeDetails, WhenChanged
```

⭐ **Cloud-only mailboxes in a hybrid tenant are worth listing.** They are usually legitimate (service
accounts, shared mailboxes created in the cloud) — ⭐ **and they are also what an attacker creates,
because a cloud-only object is not visible to anyone watching on-premises AD.** Knowing which ones
*should* exist is the point; the list is short and reviewable.

```powershell
# ③ Free/busy and OAuth trust health
Get-IntraOrganizationConnector | Select-Object Name, TargetAddressDomains, DiscoveryEndpoint, Enabled
```

---

## 6. What breaks

**Changing mail attributes in the cloud on a synced object.** §2 — ⭐ reverted at next sync.

**Assuming cloud-only hardening protects synced mail objects.** §2 — ⭐ on-prem is the master.

**Hybrid connectors left after migration completes.** §3 — ⭐ a trusted path maintained by nobody.

**Connector trusting a certificate with no IP restriction.** §3.

**Expired or wildcard certificate on the connector.** §3.

**The last Exchange server unpatched.** §4 — ⭐ unpatched *because* it seems to do nothing.

**Exchange server internet-facing without need.** §4.

**Not reviewing cloud-only objects in a hybrid tenant.** §5 — ⭐ invisible to on-prem monitoring.

**Raw attribute edits with unsupported tooling.** §2 — half-broken mail objects.

**Treating hybrid as temporary.** ⭐ It is usually permanent; plan and secure it accordingly.

---

## 7. Customer discovery questions

1. Which objects are **mastered on-premises**, and does the team know before they change something?
   *(§2.)*
2. Is the hybrid **inbound connector** restricted by **IP as well as certificate**? *(§3.)*
3. When does that **certificate expire**, and who renews it?
4. Do connectors still exist for a **migration that finished**? *(§3.)*
5. ⭐ Is the last **Exchange server** internet-facing, patched, and monitored? *(§4.)*
6. What is it still **needed for**, specifically?
7. How many **cloud-only** mailboxes exist, and are they all expected? *(§5.)*
8. Does on-prem AD compromise reach cloud mail — and is that in the threat model? *(§2.)*
9. What is the **decommission plan**, and what is blocking it?

---

## 8. Remember it

**Hook — "On-prem is still the master."** Change it there, or it reverts.

**Analogy — the annex you meant to knock down.** ⭐ **The building was extended years ago and everyone
moved into the new wing.** The old annex is empty, but it still has the mains connection, ⭐ **a door
that opens into the new building without a badge**, and the only working copy of the key register.
Nobody cleans it, nobody patches it, ⭐ **nobody is even sure who has keys to it** — and it is
connected to everything, precisely because it "isn't used any more".

**The one thing:** ⭐ **the last on-premises Exchange server is unpatched *because* it appears to do
nothing.** It holds extensive Active Directory permissions by design, it maintains a certificate-trusted
inbound path into your tenant, it has been the most exploited on-premises product of recent years, and
it sits outside every patch cadence because no application team owns it. **"We only keep it for
attribute management" is a business case, not a risk assessment** — and pointing that out, with the
three specific properties that make it dangerous, is the contribution a senior engineer makes to a
hybrid review.

**Runner-up:** ⭐ **connectors from a completed migration are a trusted path maintained by nobody.**

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. What joins the two organisations in a hybrid?
2. ⭐ Where are Exchange attributes mastered in a synced hybrid, and what is the visible symptom of
   getting this wrong?
3. What is the security consequence of that mastering?
4. ⭐ Why is the hybrid inbound connector a security-relevant object?
5. What is the healthy connector configuration?
6. Name four properties that make the last Exchange server dangerous.
7. ⭐ Why is it typically unpatched?
8. What should you check about cloud-only mailboxes in a hybrid tenant, and why?
9. What is the mail-flow equivalent of an orphaned ring-0 driver?
10. Should hybrid be treated as temporary?

<details>
<summary>Answers</summary>

1. **Trust and DNS** — hybrid configuration, OAuth, connectors, Autodiscover and directory sync — not
   a merge.
2. ⭐ **On-premises AD.** Symptom: ⭐ a cloud change **appears to work and reverts at the next sync**,
   and nobody suspects sync.
3. ⭐ **On-premises AD compromise reaches cloud mail** — cloud-only hardening cannot protect an object
   whose master is on-prem.
4. ⭐ It is an **authenticated, trusted path** where mail arrives looking internal and is often filtered
   less — so compromise of the on-prem server yields trusted delivery into the tenant.
5. ⭐ **Both `SenderIPAddresses` and `TlsSenderCertificateName` set, with
   `RestrictDomainsToIPAddresses = True`** and a current certificate.
6. **Historically internet-facing, extensive AD privilege by design, ⭐ unpatched, and trusted by the
   tenant.**
7. ⭐ Because it **appears to do nothing**, so no application team owns it and it falls outside every
   patch cadence.
8. ⭐ Whether each is **expected** — a cloud-only object is **invisible to on-premises monitoring**,
   which is why an attacker would create one.
9. ⭐ **Hybrid connectors left in place after a completed migration** — trusted, authenticated,
   maintained by nobody.
10. ⭐ **No** — it is usually permanent, and should be planned and secured as a permanent state.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — the §5 coexistence audit and the §3 connector inspection. ⚠ Requires a hybrid tenant;
  the connector query alone runs on any tenant with EXO.
- **`break-fix/`** ⭐ — change a mail attribute on a **synced** object in Exchange Online, force a sync
  cycle, and watch it revert. **Then make the change on-premises and watch it hold.** ⭐ **Five
  minutes, and it permanently fixes the mental model of where objects are mastered** — which is the
  single most common source of hybrid tickets.
- **`security/`** — connector inventory with IP restriction, certificate name and expiry; Exchange
  server patch level, internet exposure and monitoring status; cloud-only mailbox register;
  on-prem AD rights that reach mail attributes.
- **`operations/`** — certificate renewal owner and date; decommission plan with named blockers;
  attribute-change procedure stating where each object is mastered.
- **`architecture-decisions/`** — ADR: the last Exchange server removed from the mail path and patched
  on the domain-controller cadence, or decommissioned, ⭐ with the §4 risk properties recorded.
- **`customer-use-cases/`** — §7 answered; "the connectors from a migration you finished in 2022" as a
  standalone finding.
