# Coexistence

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The state you live in for months, not the state you pass through.** Pairs with
> [`../exchange-migrations/`](../exchange-migrations/) and
> [`../../35-active-directory-and-hybrid-identity/entra-connect-sync/`](../../35-active-directory-and-hybrid-identity/entra-connect-sync/).

---

## 1. What it is

The period when some users are in the source system and some are in Microsoft 365, and **both
populations must behave as one organisation**: mail routes correctly in both directions, free/busy
lookups work across the boundary, the global address list contains everyone, and delegates keep
working. Coexistence is a *designed state*, not a side effect.

---

## 2. Why it exists

⭐ **Migration takes weeks; a business day takes eight hours.** Between the first wave and the last,
somebody in the cloud will invite somebody on-premises to a meeting, and the answer to "is she
free?" must not be "I can't see her calendar."

Without designed coexistence, each of these fails on day one of wave one:

| Interaction | Failure without coexistence |
|---|---|
| Cloud user books on-prem colleague | ⭐ **free/busy shows hatched "no information"** |
| On-prem user emails cloud user | ⭐ **NDR, or mail leaves the org and comes back** |
| Cloud user searches the GAL | migrated colleagues missing |
| Delegate opens a boss's mailbox | ⭐ **access lost until both are in the same place** |
| Shared mailbox used by both | ⭐ **cannot be shared across the boundary** |

⭐ **The last two are the ones that generate tickets**, and they are scheduling problems, not
technology problems — which is why the wave plan is a coexistence artifact.

---

## 3. How it works underneath

Four separate mechanisms, commonly mistaken for one:

```
① MAIL ROUTING     connectors both ways; on-prem MailUser objects carry
                   ⭐ TargetAddress → user@contoso.mail.onmicrosoft.com
                      so on-prem SMTP re-routes internally, ⭐ never via the internet

② DIRECTORY        Entra Connect sync (⭐ default 30 min delta cycle)
                   on-prem AD ──► Entra ──► EXO GAL
                   ⭐ AD stays authoritative while sync is enabled

③ FREE/BUSY        Organization relationship + OAuth
                   EXO ──Autodiscover──► on-prem EWS ──► availability service
                   ⭐ this is a REAL-TIME lookup, not synced data

④ AUTODISCOVER     one DNS name, one answer — ⭐ points at the source until
                   the last mailbox moves, and it is what redirects clients
```

⭐ **③ is the one that surprises people: free/busy is fetched live, per query.** Nothing is
replicated. So the moment the on-prem EWS endpoint is unreachable — a certificate expiry, a firewall
change, a decommissioned server — ⭐ **calendar lookups break instantly and silently for the entire
migrated population**, with no error anywhere except the user's screen.

---

## 4. Worked example — tracing one cross-boundary message

`onprem.user@contoso.com` (on-premises) emails `cloud.user@contoso.com` (already migrated).

```
① On-prem transport resolves cloud.user
      Recipient object type: ⭐ MailUser  (not Mailbox — she moved)
      TargetAddress: cloud.user@contoso.mail.onmicrosoft.com

② Accepted domain check
      contoso.com                     = Authoritative   ⭐ do NOT relay out
      contoso.mail.onmicrosoft.com    = Internal Relay / remote routing

③ Send connector "Outbound to Office 365"
      Address space: contoso.mail.onmicrosoft.com
      TLS: required, certificate-authenticated  ⭐ this keeps it "internal"

④ EXO inbound connector (OnPremises type) accepts it
      ⭐ Message retains internal status: no external-sender warning,
         no re-scan as inbound internet mail, DLP/transport rules still apply
```

⭐ **Step ④ is why you build connectors instead of just letting mail go out and come back.** Mail
that leaves the organisation and re-enters is treated as external: it hits anti-spam differently,
picks up the "external sender" banner, and — most damagingly — ⭐ **can fail your own DMARC checks
on your own domain.**

**Verify the object type is right:**

```powershell
Get-Recipient cloud.user@contoso.com |
  Format-List RecipientType, RecipientTypeDetails, ExternalEmailAddress
```

```
RecipientType        : MailUser
RecipientTypeDetails : RemoteUserMailbox
ExternalEmailAddress : SMTP:cloud.user@contoso.mail.onmicrosoft.com
```

⭐ **`RemoteUserMailbox` on-premises + a real mailbox in EXO = coexistence is correct for this
user.** Anything else — a lingering `UserMailbox` on-prem, or a `MailContact` — is a
misconfiguration that will route mail to the wrong place.

---

## 5. Commands

**Prove free/busy works, from the cloud side, for a specific pair:**

```powershell
Test-OrganizationRelationship -Identity 'On-premises' -UserIdentity cloud.user@contoso.com
```

```
Identity              Result   Message
On-premises           Success  Test steps completed successfully
```

**Check the sync heartbeat — a stale directory looks like a routing fault:**

```powershell
Get-MgOrganization | Select-Object -ExpandProperty OnPremisesLastSyncDateTime
```

```
2026-08-18T09:41:12Z
```

⭐ **If that timestamp is more than ~1 hour old, stop diagnosing mail flow.** The default Entra
Connect delta cycle is **30 minutes**; a stale value means the sync server is the fault and every
downstream symptom is noise.

**Enumerate the boundary — who is where, right now:**

```powershell
Get-Recipient -ResultSize Unlimited |
  Group-Object RecipientTypeDetails | Select-Object Name, Count
```

```
Name                 Count
UserMailbox            288   ⭐ still on-premises
RemoteUserMailbox      229   ⭐ migrated
MailUniversalSecurityGroup  74
```

⭐ **Those two numbers are the migration progress report** — measured, not asserted, and worth more
than any project dashboard.

---

## 6. When and where

| Duration of coexistence | Design implication |
|---|---|
| A weekend (cutover) | ⭐ **skip most of this** — accept a short outage instead |
| 2–8 weeks | full coexistence: connectors, org relationship, GAL sync |
| ⭐ **Months to permanent** | ⭐ treat as production architecture: monitor free/busy, renew certificates, document it |
| Tenant-to-tenant | different mechanisms — [`../tenant-to-tenant/`](../tenant-to-tenant/) §5 |

⭐ **The rule that keeps coexistence short: migrate by *relationship*, not by department.** Move a
manager, their delegates, and the shared mailboxes they open in the **same wave**. An org chart is
a worse wave plan than a delegation map.

---

## 7. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| Free/busy hatched for migrated users only | ⭐ org relationship or on-prem **EWS/Autodiscover unreachable** | `Test-OrganizationRelationship`; check certificate expiry |
| "External sender" banner on internal mail | ⭐ mail routed via the internet | connectors missing or address space wrong |
| ⭐ **Your own domain fails DMARC** | same root cause | fix the connector, not the DMARC record |
| Delegate lost access mid-project | boss and delegate in different waves | ⭐ re-plan waves from the delegation map |
| New user missing from the cloud GAL | Entra Connect not run / filtered out | check `OnPremisesLastSyncDateTime` **first** |
| Mail loops between on-prem and EXO | accepted domain set to `Authoritative` on both | ⭐ exactly one authoritative owner per domain |

⭐ **The certificate expiry case deserves its own alarm.** Hybrid free/busy depends on a publicly
trusted certificate on the on-premises endpoint. When it expires, ⭐ **nothing logs an error in
Exchange Online** — users simply see no calendar data. Put the expiry date in the runbook.

---

## 8. Customer discovery questions

1. ⭐ **"Who opens someone else's mailbox?"** — this builds the wave plan
2. "Which shared mailboxes are used by more than one department?"
3. "When does the certificate on your Exchange endpoint expire?"
4. ⭐ **"How long are you prepared to run in a hybrid state?"**
5. "Do you have conference rooms booked more than a month ahead?"
6. "Which applications relay mail through Exchange, and from which IPs?"
7. "Is there a third-party mail hygiene service in front of Exchange today?"

---

## 9. Remember it

**Hook — `M D F A`: Mail routing, Directory, Free/busy, Autodiscover.** Four mechanisms; only one
of them (free/busy) is real-time.

**Analogy — two branch offices of one company.** ⭐ **The internal courier (connectors) keeps post
internal; the shared staff directory (sync) is printed twice a day; but "is Aisha in a meeting?"
requires phoning the other branch right now (free/busy).** The analogy predicts the failure mode:
**cut the phone line and the directory still looks fine** — which is exactly why a certificate
expiry breaks calendars while mail keeps flowing.

**The one line:** ⭐ **Coexistence is three synced mechanisms and one live one; the live one is
free/busy, and it is the one that breaks.**

---

## 10. Self-test

1. Which coexistence mechanism is real-time rather than replicated?
   → ⭐ Free/busy, via the organization relationship and EWS.
2. Why route cross-boundary mail through connectors instead of the internet?
   → ⭐ It preserves internal status: no external banner, correct policy application, no self-DMARC failure.
3. What object type should a migrated user be on-premises?
   → `RemoteUserMailbox` (a MailUser with `TargetAddress`).
4. Default Entra Connect delta sync interval?
   → **30 minutes**.
5. Calendars stopped working for migrated staff; mail is fine. First hypothesis?
   → ⭐ On-prem EWS endpoint or its certificate — not mail flow.
6. Why is a delegation map a better wave plan than an org chart?
   → Delegate and mailbox must move together, and delegation crosses departments.
7. Mail loops between the two systems. What is misconfigured?
   → ⭐ Both sides claim the domain as `Authoritative`.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | `Test-OrganizationRelationship` success output, plus a cross-boundary message header trace |
| `security` | the connector's TLS/certificate configuration, showing authenticated internal relay |
| `operations` | the `RecipientTypeDetails` progress count, captured weekly |
| `break-fix` | one free/busy failure diagnosed to its actual cause |
| `architecture-decisions` | ⭐ the wave plan derived from the delegation map, with the reasoning |
