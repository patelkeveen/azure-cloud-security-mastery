# Tenant to Tenant

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The hardest migration Microsoft sells, because of one immovable constraint: a domain can
> exist in exactly one tenant.** Pairs with [`../coexistence/`](../coexistence/),
> [`../../80-customer-scenarios/mergers-and-acquisitions/`](../../80-customer-scenarios/mergers-and-acquisitions/)
> and [`../../30-identity-and-nhi/external-identities/`](../../30-identity-and-nhi/external-identities/).

---

## 1. What it is

Moving users, mailboxes, files, Teams and identity from one Microsoft 365 tenant to another —
the standard outcome of a merger, an acquisition, a divestiture, or a company splitting from its
parent's tenant. ⭐ **Unlike an on-premises migration, there is no hybrid state for the vanity
domain: `contoso.com` is verified in one tenant or the other, never both.**

---

## 2. Why it exists, and why it is hard

⭐ **A verified domain is globally unique across all of Microsoft 365.** That single fact produces
every constraint in this topic:

| Consequence | Practical effect |
|---|---|
| ⭐ **No shared namespace** | you cannot run `@contoso.com` in both tenants during the project |
| The domain move is a ⭐ **hard cutover** | remove from source, then add + verify in target |
| ⭐ Removal requires **zero references** | every mailbox, group, alias and app must stop using it first |
| Verification is not instant | ⚠ **allow hours, not minutes** — plan the window accordingly |

⭐ **Everything else in a tenant-to-tenant migration is scheduling around that one atomic event.**

The interim addressing pattern that makes it survivable:

```
BEFORE   a.khan@contoso.com          (source tenant)
DURING   a.khan@contoso.onmicrosoft.com     ⭐ source, released the vanity domain
         a.khan@target.onmicrosoft.com      ⭐ target, pre-staged and pre-seeded
AFTER    a.khan@contoso.com          (target tenant — domain moved)
```

---

## 3. How it works underneath — cross-tenant mailbox migration

Microsoft's native path uses **MRS across tenants**, authorised by an app registration rather than
a username and password:

```
TARGET tenant                                  SOURCE tenant
  ┌──────────────────────┐                     ┌──────────────────────┐
  │ MRS                  │                     │  Migration app       │
  │  reads endpoint ─────┼── OAuth token ─────►│  ⭐ Mailbox.Migration │
  │                      │   (app-only)        │     permission        │
  │ MailUser objects     │                     │                       │
  │  ⭐ ExchangeGuid must │◄── mailbox data ────│  Mail-enabled security│
  │     match source     │                     │  group = ⭐ WHO may   │
  └──────────────────────┘                     │  be moved             │
        ▲                                      └──────────────────────┘
        │ Organization relationship on BOTH sides
        └── names the app, the group, and the partner tenant
```

⭐ **Three objects must agree or nothing moves:** the **organization relationship** (trust), the
**mail-enabled security group** (scope — which mailboxes are permitted to leave), and the
**`ExchangeGuid`** on the pre-staged target `MailUser` (identity — which mailbox this *is*).

⭐ **The security group is the safety control.** It means the target tenant cannot pull an arbitrary
mailbox out of the source; the source explicitly enumerates who may go. Name this in an interview
and you have demonstrated you understand the trust model rather than the click path.

---

## 4. Worked example — pre-staging one user in the target

The target object must be a **MailUser**, not a mailbox, and it must carry the source mailbox's
identity attributes:

```powershell
# TARGET tenant
New-MailUser -Name 'Aisha Khan' `
  -MicrosoftOnlineServicesID 'a.khan@target.onmicrosoft.com' `
  -ExternalEmailAddress   'a.khan@contoso.mail.onmicrosoft.com' `
  -PrimarySmtpAddress     'a.khan@target.onmicrosoft.com'

# ⭐ The attribute that makes MRS treat this as the SAME mailbox
Set-MailUser 'a.khan@target.onmicrosoft.com' `
  -ExchangeGuid   '8f3d1a20-4c7e-4b19-9f2a-1d5c7e0b4a63' `
  -ArchiveGuid    'c21b7e94-0a55-4d38-b6f7-93e4d2a1f508' `
  -EmailAddresses @{Add='x500:/o=Contoso/ou=Exchange Administrative Group.../cn=akhan'}
```

⭐ **The `x500:` address is the one everybody omits, and it produces the most-reported post-migration
complaint.** Outlook caches recipients by their legacy X.500 address (`LegacyExchangeDN`). Without
it carried forward as a proxy address, ⭐ **every reply to an old message and every autocomplete
entry bounces** with:

```
IMCEAEX-_O=CONTOSO_OU=EXCHANGE+20ADMINISTRATIVE+20GROUP...@target.onmicrosoft.com
550 5.1.1 RESOLVER.ADR.ExRecipNotFound; not found
```

⭐ **`IMCEAEX` in an NDR always means one thing: a missing X.500 proxy address.** Recognising that
string on sight is a genuine field skill.

**Verify before moving:**

```powershell
Get-MailUser 'a.khan@target.onmicrosoft.com' |
  Format-List ExchangeGuid, ArchiveGuid, ExternalEmailAddress
```

```
ExchangeGuid         : 8f3d1a20-4c7e-4b19-9f2a-1d5c7e0b4a63
ArchiveGuid          : c21b7e94-0a55-4d38-b6f7-93e4d2a1f508
ExternalEmailAddress : SMTP:a.khan@contoso.mail.onmicrosoft.com
```

⭐ **A GUID of all zeros means the attribute did not stick** — the move will fail with a recipient
lookup error, not a permission error, which sends people down the wrong diagnostic path.

**The move itself:**

```powershell
New-MigrationBatch -Name 'T2T-Wave-01' `
  -SourceEndpoint $endpoint `
  -CSVData ([System.IO.File]::ReadAllBytes('C:\mig\t2t-wave01.csv')) `
  -TargetDeliveryDomain 'target.onmicrosoft.com' `
  -AutoStart -AutoComplete:$false
```

---

## 5. The other three workstreams

| Workstream | Native path | Reality |
|---|---|---|
| **Identity** | ⭐ **Entra cross-tenant synchronization** (B2B provisioning, requires **P1**) | good for coexistence, ⭐ **not a migration** — it creates B2B guests, not members |
| **SharePoint / OneDrive** | SharePoint cross-tenant content move (`Start-SPOCrossTenant*` cmdlets) | ⚠ check current GA scope and prerequisites |
| **Teams** | ⭐ no native path for messages | third party, or Graph import — [`../teams-migrations/`](../teams-migrations/) |

⭐ **Cross-tenant synchronization solves "we merged and need one address book on Monday". It does
not solve "we merged and need one tenant."** Confusing the two is the most common architecture
error in M&A work: guests can collaborate, but they are not licensed members, and their mailboxes
stay where they are.

---

## 6. When and where

| Scenario | Approach |
|---|---|
| Acquisition, keep both tenants indefinitely | ⭐ **cross-tenant sync + B2B**. No migration at all |
| Full absorption, one tenant survives | ⭐ full T2T with a domain cutover |
| Divestiture — carve users out | T2T *outbound*, ⭐ plus a data-retention decision for what stays |
| Tiny (< 25 users) | ⭐ export/import and manual rebuild is often genuinely cheaper — say so |

⭐ **The honest consultant's answer is often "do not migrate".** Two tenants with cross-tenant sync
is a supported permanent architecture, and it costs less than a migration. Recommending it when it
fits is what distinguishes an architect from an implementer.

---

## 7. What breaks

| Error text | Cause | Fix |
|---|---|---|
| `The domain cannot be removed because it is in use by...` | ⭐ residual references | strip aliases from every mailbox, group, and app first |
| `IMCEAEX-_O=... RESOLVER.ADR.ExRecipNotFound` | ⭐ **missing X.500 proxy** | add the `x500:` address from `LegacyExchangeDN` |
| `MigrationPermanentException: target mailbox ... ExchangeGuid` mismatch | pre-staging wrong | §4 verification |
| `The user isn't a member of the migration scope group` | ⭐ **not in the mail-enabled security group** | add, then wait for replication |
| Guests appear instead of users | ⭐ cross-tenant **sync** used instead of migration | different tool, different outcome |
| Free/busy broken during the project | organization relationship absent | [`../coexistence/`](../coexistence/) §3 |

---

## 8. Customer discovery questions

1. ⭐ **"Which tenant survives, and who decides?"** — this is a governance answer, not a technical one
2. "How many domains, and are any shared with a parent company?"
3. ⭐ **"What is the acceptable duration of the interim `.onmicrosoft.com` addressing?"**
4. "Are there app registrations, service principals or SaaS SSO integrations bound to the source tenant?"
5. "Is anything on litigation hold in the source?" (⭐ it cannot simply be deleted afterwards)
6. "Do you have Entra ID P1 in both tenants?" (cross-tenant sync prerequisite)
7. ⭐ **"What happens to the source tenant afterwards — kept, or decommissioned?"**

---

## 9. Remember it

**Hook — `D I C T`: Domain, Identity, Content, Teams.** The domain is atomic; the other three are
incremental.

**Analogy — changing the registered address of a company.** ⭐ **Only one company can be registered
at an address at a time**, so the day you move is a single instant, not a phase. Everything else —
staff, filing cabinets, phone lines — can be moved before or after. The analogy predicts the design:
**pre-seed everything you can, so the atomic event is as short as possible.** It also predicts the
X.500 problem: **old letters addressed to the previous registration still need to be forwarded**,
and that is exactly what the `x500:` proxy is.

**The one line:** ⭐ **One domain, one tenant, one moment — everything else is pre-staging around
that moment.**

---

## 10. Self-test

1. Why can a vanity domain not be shared between tenants during a migration?
   → ⭐ Domain verification is globally unique across Microsoft 365.
2. Name the three objects that must agree for a cross-tenant mailbox move.
   → Organization relationship, mail-enabled security group (scope), matching `ExchangeGuid`.
3. What does the migration security group protect against?
   → ⭐ The target pulling arbitrary mailboxes; the source enumerates who may leave.
4. An NDR contains `IMCEAEX`. What is wrong?
   → ⭐ Missing X.500 proxy address from the source `LegacyExchangeDN`.
5. Difference between cross-tenant synchronization and cross-tenant migration?
   → Sync creates **B2B guests** for collaboration; migration moves **members and their data**.
6. Target `MailUser` shows `ExchangeGuid` of all zeros. Consequence?
   → ⭐ MRS cannot match the mailbox; the move fails on recipient lookup.
7. When is "do not migrate" the right recommendation?
   → ⭐ When both tenants persist and collaboration — not consolidation — is the actual requirement.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | a pre-staged `MailUser` with matching GUIDs, shown side by side with the source mailbox |
| `security` | the app registration's permission set and the migration scope group membership |
| `operations` | the domain-cutover runbook with the interim addressing window |
| `break-fix` | one `IMCEAEX` NDR and the X.500 remediation that fixed it |
| `architecture-decisions` | ⭐ the memo deciding *migrate* vs *cross-tenant sync*, with cost |
