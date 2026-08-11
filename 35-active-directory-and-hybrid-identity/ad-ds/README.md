# Active Directory Domain Services (AD DS)

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> The substrate everything else in this domain sits on. If AD DS is shaky, hybrid identity,
> Conditional Access and PIM all become guesswork.
> ⚠ Fundamentals here are stable across versions; anything version-specific is marked.

---

## 1. What it is

Two things fused into one product, which is why people talk past each other about it:

1. A **directory** — a replicated, hierarchical database of objects, queried over **LDAP**.
2. An **authentication authority** — it issues **Kerberos** tickets that prove who you are.

The database is `NTDS.dit`, a single file on every domain controller. Everything else is machinery
around keeping copies of that file agreeing with each other.

---

## 2. Why it exists

Before it, every server held its own account list. Fifty servers meant fifty passwords per person
and fifty places to forget to remove a leaver.

AD DS made **one account authenticate everywhere** — and in doing so made itself the thing an
attacker wants most. Domain Admin is not "an admin account"; it is *every* machine in the estate,
simultaneously. That single fact drives the entire security model in §7.

---

## 3. How it works underneath

### The hierarchy, and the boundary people get wrong

```
FOREST  ──────────  the SECURITY boundary
  │                 one schema, one configuration partition, one global catalog
  │
  ├── DOMAIN  ────── a replication and POLICY boundary  ✗ NOT a security boundary
  │     │            own password policy, own DCs, own SIDs
  │     │
  │     └── OU  ──── a management/delegation container. GPOs link here.
  │                  ✗ NOT a security boundary either
  │
  └── DOMAIN (child)
```

> **The forest is the security boundary. The domain is not.** ⭐ This is the most consequential
> misconception in AD, and it is asked in interviews specifically because so many people get it
> wrong. A Domain Admin in *any* domain of a forest can, through the schema and configuration
> partitions and the Enterprise Admins path, reach the whole forest. **Two organisations that must
> not reach each other need two forests, not two domains.**

### The physical layer

| Thing | What it is |
|---|---|
| `NTDS.dit` | The database file. Contains every object — and every password hash. |
| `SYSVOL` | Replicated share holding GPOs and scripts. Replicated by **DFSR** (FRS is long dead). |
| **Site** | An IP-subnet grouping that tells AD what is "network-close" — drives DC selection and replication scheduling. |
| **KCC** | Knowledge Consistency Checker — builds the replication topology automatically. |
| **Global Catalog** | A partial, forest-wide read-only index. Needed for UPN logon and universal group membership. |

### Multi-master replication

Every DC is writable, and there is no primary. Conflicts resolve by **version number**, then
timestamp, then GUID. Each DC tracks changes with a **USN** and remembers what it has seen from
peers via an **up-to-dateness vector**, so it only pulls deltas.

**Consequence that matters daily:** a change made on `DC01` is not instantly on `DC02`. Intra-site
replication is near-immediate (seconds); inter-site follows a **site link schedule**, default
**180 minutes**. "I reset the password but it didn't work" is usually a user hitting a different DC.

### The five FSMO roles

Multi-master breaks for operations that must be serialised, so five roles are single-master:

| Role | Scope | If it is down |
|---|---|---|
| **Schema Master** | Forest | Cannot modify the schema — blocks Exchange/Entra Connect schema extensions |
| **Domain Naming Master** | Forest | Cannot add or remove domains |
| **RID Master** | Domain | DCs eventually **cannot create new objects** (RID pool exhaustion) |
| **PDC Emulator** | Domain | ⭐ Biggest blast radius — see below |
| **Infrastructure Master** | Domain | Cross-domain references go stale |

**PDC Emulator** is the one to know cold. It is the authoritative **time source** for the domain,
handles **account lockout** processing, gets **password changes replicated urgently**, and is the
default target for **GPO edits**. Since Kerberos rejects tickets with more than **5 minutes** of
clock skew, a broken PDCe time hierarchy presents as "nobody can log in" — and almost nobody
diagnoses that as a time problem on the first pass.

---

## 4. Worked example — decoding a SID

Authorization is by **SID**, never by name. Rename an account and its access follows, because the
SID did not change. Delete and recreate it with the same name and **all access is gone**, because
the SID did.

```
S-1-5-21-3623811015-3361044348-30300820-512
│ │ │  └──────── domain identifier ────────┘ └┬┘
│ │ │                                       RID
│ │ └─ authority 21 = "not built-in; a real domain"
│ └─── revision 5 = NT authority
└───── SID revision level 1
```

Everything left of the last hyphen identifies the **domain**. The **RID** identifies the principal
within it. Well-known RIDs are constant everywhere:

| RID | Principal | Note |
|---:|---|---|
| 500 | Administrator | **Renaming it changes nothing** — the RID is what attackers enumerate |
| 501 | Guest | |
| 502 | **krbtgt** | ⭐ The account whose hash signs every Kerberos ticket. Golden Ticket target. |
| 512 | Domain Admins | |
| 513 | Domain Users | |
| 518 | Schema Admins | |
| 519 | **Enterprise Admins** | Forest-wide. The real crown jewels. |
| 520 | Group Policy Creator Owners | |

Some SIDs have no domain part at all — they are universal. ✅ Verified, real output:

```powershell
@('S-1-5-32-544','S-1-5-32-545','S-1-5-11','S-1-5-18','S-1-1-0') | ForEach-Object {
  "{0,-16} -> {1}" -f $_, ([System.Security.Principal.SecurityIdentifier]$_).Translate([System.Security.Principal.NTAccount]).Value
}
```

```
S-1-5-32-544     -> BUILTIN\Administrators
S-1-5-32-545     -> BUILTIN\Users
S-1-5-11         -> NT AUTHORITY\Authenticated Users
S-1-5-18         -> NT AUTHORITY\SYSTEM
S-1-1-0          -> Everyone
```

> `S-1-5-32-*` is **BUILTIN** — local to each machine, not the domain. `S-1-5-11` is
> **Authenticated Users**, which includes every domain computer as well as every human. Granting
> something to "Authenticated Users" because it "sounds restrictive" is a recurring finding.

**Why this connects to the cloud:** the SID flows to Entra ID as `onPremisesSecurityIdentifier`,
and a SID collision is one of the `AttributeValueMustBeUnique` causes in
[`../source-anchor-and-matching/`](../source-anchor-and-matching/).

---

## 5. Groups — scope is the part people never learn properly

Two orthogonal properties: **type** (Security vs Distribution) and **scope**.

| Scope | Can contain | Can be used for permissions |
|---|---|---|
| **Domain Local** | Anything, from any domain in the forest | **Only in its own domain** |
| **Global** | Only principals **from its own domain** | Anywhere in the forest |
| **Universal** | Anything from any domain | Anywhere. **Membership lives in the Global Catalog.** |

The classic pattern, **AGDLP**:

```
Accounts → Global group → Domain Local group → Permission
```

Put people in a Global group ("Finance Staff"), put that group into a Domain Local group
("Read-Finance-Share"), and grant the permission to the Domain Local group. The ACL never changes
again; you only edit membership.

**Why Universal groups deserve care:** their full membership replicates to every Global Catalog in
the forest. Changing one member republishes the whole list. On very large groups this is a real
replication cost — and it is why the 50,000-member ceiling in
[`../entra-cloud-sync/`](../entra-cloud-sync/) has an on-premises cousin.

**Group scope is the reason a cross-forest permission "mysteriously" fails.** A Global group cannot
hold a principal from another domain.

---

## 6. Useful commands, with output shape

**Where are the FSMO roles?**

```powershell
Get-ADForest | Select-Object SchemaMaster, DomainNamingMaster
Get-ADDomain | Select-Object PDCEmulator, RIDMaster, InfrastructureMaster
```

**Is replication healthy?** The first command in any AD incident:

```powershell
repadmin /replsummary
```

```
Source DSA          largest delta    fails/total %%   error
 DC01                      00m:12s      0 /   5    0
 DC02                      02h:41s      3 /   5   60  (1256) The remote system is not available
```

Non-zero `fails` or a delta beyond the **tombstone lifetime** is an emergency, not a ticket.

**Tombstone lifetime** — how long a deleted object's marker survives, and therefore how long a DC
can be offline before it must be rebuilt rather than resurrected:

```powershell
(Get-ADObject "CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,$((Get-ADRootDSE).rootDomainNamingContext)" `
  -Properties tombstoneLifetime).tombstoneLifetime
```

Modern default is **180 days** ⚠ check — domains upgraded from very old versions can still carry
**60**. A DC restored from a backup older than this reintroduces deleted objects — **lingering
objects** — including deleted user accounts. That is both a correctness and a security problem.

**Find the risky things** — accounts whose password never expires, and unconstrained delegation:

```powershell
Get-ADUser -Filter 'PasswordNeverExpires -eq $true -and Enabled -eq $true' -Properties PasswordNeverExpires |
  Select-Object SamAccountName, DistinguishedName

Get-ADComputer -Filter 'TrustedForDelegation -eq $true' -Properties TrustedForDelegation |
  Select-Object Name, DistinguishedName
```

Any **non-DC** returned by the second command is a critical finding. See §7.

---

## 7. The security model, and what breaks it

AD's weaknesses are mostly *design consequences*, not bugs — which is why they persist.

| Attack | Mechanism | Defence |
|---|---|---|
| **DCSync** | Any principal with *Replicate Directory Changes* **+ All** can ask a DC to hand over password hashes — **without touching the DC's disk**. It is the legitimate replication API. | Audit who holds those rights. ⚠ Note the Entra Connect connector account **needs them** — see [`../entra-connect-sync/`](../entra-connect-sync/) §6. That account is a top-tier target. |
| **Golden Ticket** | With the **krbtgt** hash (RID 502), forge a TGT for anyone, valid until krbtgt is reset. | Reset krbtgt **twice**, separated by more than one replication cycle. Once is not enough — the previous key stays valid. |
| **Silver Ticket** | With a service account's hash, forge a service ticket. Never contacts a DC, so **no DC log entry.** | Managed service accounts (gMSA); monitor at the service. |
| **Kerberoasting** | Any authenticated user can request a service ticket for any SPN, then crack it offline. | **gMSA** (128-char machine-managed passwords) for every SPN account. |
| **AS-REP roasting** | Accounts with pre-authentication disabled leak a crackable blob to **anyone, unauthenticated**. | Audit `DoesNotRequirePreAuth` and clear it. |
| **Unconstrained delegation** | The server caches the *user's TGT*. Compromise it, get every TGT that touched it — including a Domain Admin's. | Eliminate it. Use constrained or resource-based constrained delegation. Put admins in **Protected Users**. |

**The structural defence is tiering.** Tier 0 (DCs, AD, PKI, the Connect Sync server) credentials
must never be typed on Tier 1 or 2 machines. One Domain Admin logon to a compromised workstation
puts that hash in memory and ends the forest. Tiering is an operational discipline, not a product,
which is why so few organisations actually do it.

**`Protected Users`** blocks NTLM, blocks unconstrained delegation, and forbids DES/RC4 for its
members — ⚠ and will break legacy applications, so test before adding anyone.

**`AdminSDHolder` / SDProp** re-stamps ACLs on protected groups roughly **every 60 minutes**. If a
permission you granted on Domain Admins keeps reverting, this is why — it is a feature, and an
attacker who modifies `AdminSDHolder` gains persistence that *reapplies itself*.

---

## 8. Customer discovery questions

1. How many **forests**, and why? *(Answers "who must not reach whom".)*
2. Who holds **Domain Admins**, **Enterprise Admins**, **Schema Admins** — and how many are
   service accounts or people who left?
3. Who holds **Replicate Directory Changes All**? *(DCSync path. Expect surprises beyond the
   Connect account.)*
4. When was **krbtgt** last reset, and was it reset **twice**?
5. Any **non-DC** computers trusted for unconstrained delegation?
6. Is there a **tier model**, and do admins use separate accounts — actually, or on paper?
7. `repadmin /replsummary` — clean? How long has any failure been failing?
8. **Tombstone lifetime**, and are there DCs offline longer than it?
9. Which accounts have **SPNs** and are not gMSAs? *(Kerberoasting surface.)*

Questions 3, 4 and 5 usually produce the findings that justify the engagement.

---

## 9. Remember it

**Hook — "Domains share plumbing."** Shared schema means shared trust.

**Analogy — a building, not flats.** The **forest** is the building; domains are flats inside it.
Separate front doors, but shared plumbing, wiring, and a caretaker holding every key. Two
organisations that must not reach each other need **separate buildings**.

**The one thing:** the **forest** is the security boundary, not the domain. This is the most
consequential misconception in AD, and it is asked in interviews precisely because so many people
get it wrong.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 10. Self-test

1. Is the domain a security boundary? What is?
2. Two organisations must be unable to reach each other's data. Domains or forests?
3. What breaks first if the RID Master is offline for weeks?
4. Nobody can log in this morning. What FSMO-related cause should you check early, and why?
5. Why must krbtgt be reset twice?
6. You rename a user account. Does their access change? What if you delete and recreate it?
7. Why can a Global group not hold a user from another domain, and what is the AGDLP fix?
8. An attacker holds *Replicate Directory Changes All*. What can they do, and do they need to log
   on to a DC?
9. A DC has been offline for 200 days with tombstone lifetime 180. Can you just plug it back in?

<details>
<summary>Answers</summary>

1. **No.** The **forest** is. Domain Admins in any domain can reach the forest.
2. **Separate forests.** Separate domains do not isolate them.
3. DCs exhaust their RID pools and **cannot create new objects** — no new users or computers.
4. **PDC Emulator** time. Kerberos rejects skew over **5 minutes**, so a broken time hierarchy
   looks like a total authentication outage.
5. The previous krbtgt key remains valid after one reset, so a forged Golden Ticket still works.
   Reset twice, more than one replication cycle apart.
6. Rename: **no change** — authorization is by SID. Delete and recreate: **all access lost**, new SID.
7. Global scope may only contain principals from its own domain. **AGDLP**: put them in a Global
   group, nest that into a **Domain Local** group, grant the permission there.
8. **DCSync** — request every password hash, including **krbtgt**, via the replication API. **No
   logon to a DC required.**
9. **No.** It must be rebuilt. Reconnecting it reintroduces **lingering objects**, including
   previously deleted accounts.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — build a DC; create the AGDLP chain and prove a Global group rejects a foreign-domain
  member; decode a real SID from your own lab domain.
- **`break-fix/`** — skew a member server's clock past 5 minutes and observe the Kerberos failure;
  seize a FSMO role and document the difference between transfer and seize.
- **`security/`** — DCSync-rights audit; SPN accounts that are not gMSA; unconstrained-delegation
  sweep; krbtgt reset date. This set **is** an AD security assessment.
- **`operations/`** — `repadmin /replsummary` baseline; tombstone lifetime recorded; DC recovery runbook.
- **`architecture-decisions/`** — ADR: forest count and the isolation requirement that drives it.
- **`customer-use-cases/`** — §8 answered against a real estate.
