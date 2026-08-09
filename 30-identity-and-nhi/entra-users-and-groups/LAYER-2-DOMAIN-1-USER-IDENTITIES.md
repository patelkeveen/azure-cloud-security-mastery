# Layer 2 — SC-300 Domain 1: Implement and Manage User Identities (20–25%)

> Companion to `LAYER-1-IDENTITY-PROTOCOLS.md`. Layer 1 gave you the protocol machinery;
> this is the object model that machinery operates on.
>
> **Gate:** you own this layer when you can draw the Connect Sync data flow from AD to Entra
> from memory, explain what `ms-DS-ConsistencyGuid` protects you from, and pick the right
> device join type for a described scenario without hesitating.

---

## First principles: what an identity actually *is* here

An Entra identity is a row in a directory with an **immutable object ID** (`oid`), a set of
attributes, and a **source of authority** — the system permitted to change it.

That last concept governs everything in this domain:

| Source of authority | Where it's edited | Consequence |
|---|---|---|
| **Cloud** | Entra directly | Fully editable in the portal |
| **Windows Server AD** | On-premises AD | **Most attributes are read-only in Entra.** Editing must happen on-prem |
| **External / B2B** | The partner's home tenant | You hold a stub; they own the credential |

Half of all "why can't I change this field?" tickets are a source-of-authority answer. When a
synced user shows greyed-out fields in the portal, nothing is broken — Entra is refusing to
let you create a divergence it cannot reconcile.

---

## 1.1 Configure and manage a Microsoft Entra tenant

### Built-in and custom Entra roles `[CORE]`

Entra roles ≠ Azure RBAC roles. **Two separate systems**, and conflating them is the single
most common beginner error:

| | Entra roles | Azure RBAC |
|---|---|---|
| Governs | Directory objects (users, groups, apps, CA policies) | Azure resources (VMs, storage, subscriptions) |
| Scope | Tenant, or Administrative Unit | Management group → subscription → RG → resource |
| Example | Global Administrator, User Administrator | Owner, Contributor, Reader |
| Assigned in | Entra admin center | Azure portal IAM blade |

**Global Administrator can elevate itself** to User Access Administrator over all Azure
subscriptions with one toggle (`Access management for Azure resources`). So the boundary is
real but crossable in one direction — worth knowing when you're asked "is Entra admin separate
from Azure admin?" The honest answer is *yes, until a Global Admin decides otherwise.*

**Custom roles** require P1, are built from `microsoft.directory/*` action strings, and exist
because the built-ins are frequently too broad. Least privilege in practice means reaching for
the narrowest built-in first (Groups Administrator, Authentication Administrator, User
Administrator) and only building custom when nothing fits.

> **Deep dive `[BEYOND]`:** roles can be assigned to **role-assignable groups**, but a group
> must be created with `isAssignableToRole = true` **at creation time** and this can never be
> changed afterwards. Discovering that after building your entire group structure is a
> genuinely painful afternoon.

### Administrative units `[CORE]`

An AU is a **container that scopes a role assignment** to a subset of the directory. "Priya
administers users in the Mumbai AU, and nowhere else."

**The decision framework** — this is the consulting answer, and it's what "recommend when to
use administrative units" is really testing:

```
Does a group of admins need to manage only SOME objects?
├── NO  → tenant-scoped role. Done.
└── YES → Do they need to be blocked from each other's objects too?
     ├── NO  → Administrative Unit
     └── YES → Restricted Management AU  [BEYOND]
          (protects objects even from tenant-level admins like User Administrator)

Do they need completely separate policy, branding, and billing?
└── YES → separate TENANT, not an AU. AUs do not partition CA policy or licensing.
```

That last line matters. AUs scope **administration**, not **policy**. A customer asking for
"separate environments" often needs separate tenants, and telling them an AU will do it is a
promise you cannot keep.

AUs support **dynamic membership** (rule-based) and can contain users, groups, and devices.

### Domains `[CORE]`

Adding a custom domain = prove ownership via a **TXT** (or MX) record, then verify. Until
verified, everyone is `user@tenant.onmicrosoft.com`.

Two states that change everything downstream:

- **Managed** — Entra authenticates. Password hash sync, pass-through auth, or cloud-only.
- **Federated** — an external IdP (AD FS, Okta, Ping) authenticates; Entra trusts its token.

Converting managed ↔ federated is a **tenant-wide, per-domain** operation that changes the
sign-in path for every user on that domain simultaneously. It is not a per-user setting and
there is no gradual rollout without **staged rollout** (see §1.4).

> **Security note:** the initial `*.onmicrosoft.com` domain can never be removed. Break-glass
> accounts live there deliberately — it survives a custom-domain or federation misconfiguration.

### Tenant, user, group, and device settings `[CORE]`

The settings with real blast radius:

| Setting | Why it matters |
|---|---|
| `Users can register applications` | Default **Yes**. Any user can create app registrations, which is the substrate for the illicit consent attack (Layer 1 §6). Most mature tenants set this to No |
| `Users can consent to apps` | Same attack path. Restrict to verified publishers, or disable and enable the admin consent workflow |
| `Restrict access to Entra admin center` | Stops non-admins enumerating the directory through the portal |
| `Guest user access restrictions` | Three tiers — the most restrictive stops guests enumerating other objects |
| `Users can create security groups / M365 groups` | Default Yes. Ungoverned group sprawl starts here |
| `Device settings → users may join devices` | Governs who can Entra-join hardware |

---

## 1.2 Create, configure, and manage Entra identities

### Users `[CORE]`

Three kinds, and the differences are operational not cosmetic:

| Type | `onPremisesSyncEnabled` | UPN shape | Editable in cloud |
|---|---|---|---|
| Cloud-only | `null` | `user@domain.com` | Fully |
| Synced | `true` | mirrors on-prem UPN | **Mostly read-only** |
| Guest (B2B) | `null`, `userType=Guest` | `user_partner.com#EXT#@tenant.onmicrosoft.com` | Limited |

Field traps worth knowing cold:

- **`UserPrincipalName` ≠ `mail` ≠ `proxyAddresses`.** Sign-in uses UPN. Mail routing uses
  `proxyAddresses`. They frequently differ, and assuming they match causes the classic
  "user can't sign in but receives email fine."
- **`UsageLocation` is mandatory before licensing.** No usage location → licence assignment
  fails with an error that doesn't say "set usage location." It's a legal/export-control field.
- **Soft delete is 30 days.** Deleted users are restorable for 30 days, then purged
  irreversibly. `Get-MgDirectoryDeletedItemAsUser` finds them. This is your first move in any
  "I deleted the wrong account" incident.

### Groups `[CORE]`

| | Security group | Microsoft 365 group |
|---|---|---|
| Purpose | Access control | Collaboration (mailbox, SharePoint, Teams) |
| Membership | Assigned or dynamic | Assigned or dynamic |
| Has a mailbox | No | Yes |
| Nesting | Yes (security in security) | **No** |

**Dynamic membership** `[SHALLOW]` — one exam bullet, real depth:

```
(user.department -eq "Engineering")
(user.department -eq "Sales") -and (user.country -eq "India")
(user.userPrincipalName -match ".*@contoso\.com")
(user.extensionAttribute1 -startsWith "CONTRACTOR")
(user.accountEnabled -eq true) -and (user.userType -eq "Member")
```

Four things that bite people:

1. **Evaluation is asynchronous.** Minutes at small scale, considerably longer at tens of
   thousands of users. People conclude the rule is broken while it is merely pending — check
   `membershipRuleProcessingState` and the group's processing status before debugging syntax.
2. **You cannot manually add or remove members.** The rule is the only authority. Requests to
   "just add one person" mean the rule is wrong, or the group should be assigned.
3. **Requires P1** per member evaluated.
4. **Attributes must actually be populated.** A perfect rule over an empty `department` field
   returns an empty group. In hybrid environments this usually means the attribute isn't
   flowing from AD — a §1.4 problem wearing a §1.2 costume.

### Group-based licensing `[CORE]`

Assign licences to a group; members inherit. Elegant, with sharp edges:

- **Conflicts** arise when two licences grant the same service plan. Entra reports an error
  state per user rather than silently resolving it.
- **Service plans can be selectively disabled** — assign E5 but turn off Yammer, for example.
- **Removing a user from the group removes the licence**, which deletes service data after the
  grace period. Offboarding automation that drops group membership is also deleting mailboxes.
- **No usage location = failure**, as above.

### Devices `[CORE]` `[SHALLOW]` ⭐

**The most-confused topic in Domain 1**, and it's asked constantly on the job because
Conditional Access grant controls depend on it.

| | Entra **registered** | Entra **joined** | **Hybrid** Entra joined |
|---|---|---|---|
| Owned by | User (BYOD) | Organisation | Organisation |
| Signs in with | Personal account, work account added | **Work account** | **On-prem AD account** |
| On-prem AD member | No | No | **Yes** |
| Requires AD Connect | No | No | **Yes** |
| Typical case | Personal phone/laptop | Cloud-first corporate | Existing AD estate |

**Decision tree:**

```
Is the device joined to on-premises Active Directory?
├── YES → Hybrid Entra joined   (requires Connect Sync + SCP configuration)
└── NO  → Is it corporate-owned and corporate-managed?
     ├── YES → Entra joined
     └── NO  → Entra registered  (BYOD)
```

The **Primary Refresh Token (PRT)** is issued to joined and registered devices and is what
makes SSO across apps work without re-prompting. It's also why device state can be used as a
Conditional Access signal — the PRT carries device claims.

> **Critical distinction for Layer 3:** CA's *"Require Hybrid Entra joined device"* and
> *"Require device to be marked as compliant"* are **different controls**. Hybrid-joined is a
> join-state fact; compliant is an **Intune** verdict. A device can be hybrid-joined and
> non-compliant. Customers conflate these constantly, and a policy requiring compliance in a
> tenant without Intune blocks everyone.

### Custom security attributes `[CORE]`

Tenant-scoped key/value metadata (attribute sets → attribute definitions) with **its own
separate RBAC model** — Attribute Definition Administrator, Attribute Assignment Administrator.
Global Admin does **not** get access by default. That surprises people, and it's deliberate:
these attributes often carry sensitive classification data. Used for ABAC and for dynamic
group/AU rules that shouldn't rely on repurposed `extensionAttribute` fields.

### Bulk operations via Graph PowerShell `[CORE]` `[SHALLOW]`

```powershell
Connect-MgGraph -Scopes 'User.ReadWrite.All','Group.ReadWrite.All'

# Idempotent create — check first, don't blindly New-MgUser
Import-Csv .\users.csv | ForEach-Object {
    $existing = Get-MgUser -Filter "userPrincipalName eq '$($_.UPN)'" -ErrorAction SilentlyContinue
    if ($existing) { Write-Host "skip $($_.UPN)"; return }
    New-MgUser -UserPrincipalName $_.UPN -DisplayName $_.Name `
        -MailNickname $_.Alias -UsageLocation $_.Country -AccountEnabled `
        -PasswordProfile @{ Password = (New-Guid).Guid; ForceChangePasswordNextSignIn = $true }
}
```

Production concerns the exam never mentions and every customer does:

- **Throttling.** Graph returns **429** with a `Retry-After` header. Honour it; do not
  hammer-retry. Bulk loops without backoff fail at scale.
- **Idempotency.** Scripts get re-run. Design for it, as above.
- **`-Filter` runs server-side; `Where-Object` runs client-side.** Filtering 50,000 users with
  `Where-Object` pulls all 50,000 across the wire first. This one habit is the difference
  between a 4-second script and a 20-minute one.
- **Eventual consistency.** Some queries need `-ConsistencyLevel eventual` plus `-CountVariable`.

---

## 1.3 External identities

### The B2B model `[CORE]`

**The guest's home tenant holds the credential.** You never manage their password, MFA, or
lifecycle — you grant access to a stub object. That is the entire value proposition, and it's
also why "reset the guest's password" is not a thing you can do.

Redemption flow: invite → email → consent → guest object activates. Falls back to **email OTP**
when the partner has no Entra tenant.

The `#EXT#` UPN mangling (`priya_contoso.com#EXT#@yourtenant.onmicrosoft.com`) matters because
scripts filtering on UPN will not match what you expect. Filter on `mail` or `userType`.

### Cross-tenant access settings `[CORE]` ⭐ — the M&A workhorse

Per-partner-tenant inbound and outbound controls. The feature that earns its keep:

**Trust settings** — you can trust the partner tenant's claims rather than re-challenging:

- Trust **MFA** from the home tenant
- Trust **compliant device** claims
- Trust **hybrid Entra joined device** claims

Without this, your CA policy demanding MFA forces partner users to register MFA *again in your
tenant* — a second authenticator entry for the same human. With it, their home-tenant MFA
satisfies your policy. On a merger with thousands of users, this is the difference between
day-one collaboration and a helpdesk queue.

**B2B collaboration vs B2B direct connect:**

| | B2B collaboration | B2B direct connect |
|---|---|---|
| Guest object created | **Yes** | **No** |
| Appears in your directory | Yes | No |
| Use case | General resource access | Teams Connect shared channels |

Direct connect creating no object is genuinely surprising the first time — the user has access
but you cannot find them in the user list.

### Cross-tenant synchronization `[CORE]`

Automatically provisions users **from** one tenant **into** another as B2B guests. Powers
**multi-tenant organizations**. The M&A pattern is: cross-tenant sync for identity presence,
cross-tenant access settings for trust, then a longer-term consolidation decision.

### External identity providers `[CORE]`

Direct federation via **SAML/WS-Fed**, plus Google and Facebook for guests. Ties directly to
Layer 1 §5 — configuring this *is* a SAML integration, with metadata exchange and certificate
management.

> **`[BEYOND]` — Microsoft Entra External ID.** The CIAM product, successor to Azure AD B2C
> (closed to new tenants). Customer-facing identity: user flows, custom branding, social IdPs,
> self-service sign-up. **Not on SC-300**, but any customer with a consumer-facing app needs it,
> and "we have a B2C tenant" is now a migration conversation.

---

## 1.4 Hybrid identity `[SHALLOW]` ⭐⭐ — the highest-value section in Domain 1

> Seven exam bullets. Weeks of real depth. **More consulting revenue lives here than anywhere
> else in SC-300**, because hybrid identity is where everything breaks and almost nobody can
> debug it properly.

### The mental model

```
On-prem AD  ──[connector space: staging area, per-connector]──┐
                                                              ▼
                                                       ┌─────────────┐
                                                       │  METAVERSE  │  ← the joined,
                                                       │ (single view│    authoritative
                                                       │  per person)│    identity
                                                       └─────────────┘
                                                              │
              ┌──[connector space: outbound staging]──────────┘
              ▼
          Entra ID
```

Objects are imported from each source into a **connector space**, projected or joined into the
**metaverse** (one object per real person, even across multiple forests), then exported out.
**Sync rules** govern every transition: inbound (connector → metaverse), outbound (metaverse →
connector).

Understanding this three-stage model is what lets you answer *"the attribute is right in AD but
wrong in Entra"* — you can now ask *which stage did it stop at?* rather than guessing.

Sync rules have a **precedence** value; lower numbers win. Out-of-box rules occupy a reserved
band, and custom rules take a range that overrides them — **check the current documented ranges
before authoring**, as Microsoft has adjusted them. Never edit an out-of-box rule; clone it,
adjust precedence, and disable the original.

### Source anchor — the decision you cannot undo `[SHALLOW]` ⭐

The **source anchor** (`immutableId`) is the permanent link between an on-prem object and its
cloud object. Change it and Entra sees a *different person*: the old object orphans, a duplicate
appears, and the user loses access to everything tied to their old `oid`.

| Source anchor | Consequence |
|---|---|
| `objectGUID` (legacy default) | Breaks if the object is **ever** moved between forests or the forest is rebuilt — `objectGUID` is forest-specific |
| **`ms-DS-ConsistencyGuid`** (current recommendation) | Connect stamps `objectGUID` into it once, then it travels with the object. Survives forest migration |

**Always use `ms-DS-ConsistencyGuid`.** The one-line reason: *it lets you migrate or rebuild the
forest without re-creating every cloud identity.* That sentence is worth memorising verbatim —
it answers the question in a customer meeting and demonstrates you've done this before.

The `immutableId` in Entra is the **base64-encoded** form of that GUID. Converting between them
by hand is a standard hybrid troubleshooting move.

### Soft match vs hard match `[SHALLOW]` ⭐

How a newly synced on-prem object gets connected to an *existing* cloud object instead of
creating a duplicate:

| | Matches on | When it fires |
|---|---|---|
| **Soft match** | Primary SMTP address, or UPN | First sync, when no source anchor is set on the cloud object |
| **Hard match** | `immutableId` / source anchor | You explicitly set the anchor to force the link |

**The classic failure:** a cloud-only user exists as `priya@contoso.com`. AD sync starts. If the
addresses don't align, soft match misses, and you now have **two** objects for one human — one
holding her mailbox and licences, one holding nothing but now authoritative. The fix is a hard
match: set the cloud object's `immutableId` to the on-prem `ms-DS-ConsistencyGuid`.

**Duplicate attribute resiliency** stops this from failing the whole export — the conflicting
attribute is quarantined on the offending object and sync continues. Good behaviour, but it
means **the error is silent unless you look**. Check the sync errors report; do not assume
"sync completed" means "sync correct."

### The three authentication methods `[CORE]`

| | Password Hash Sync | Pass-through Auth | Federation (AD FS) |
|---|---|---|---|
| Auth happens | **In the cloud** | On-prem via agent | On-prem via AD FS |
| On-prem outage | **Users still sign in** | Sign-in fails | Sign-in fails |
| Infrastructure | None extra | Lightweight agents (**≥3 for HA**) | AD FS farm + WAP + certs |
| Leaked-credential detection | **Requires this** | No | No |
| Complexity | Lowest | Low | Highest |

**Recommend PHS unless there's a hard requirement against it.** It's the most resilient, needs
the least infrastructure, and it's a prerequisite for Identity Protection's leaked-credential
detection. PTA and federation both make cloud sign-in dependent on on-prem availability — which
means a datacentre problem becomes a Microsoft 365 outage.

**PHS: the argument you will have to win.** A security team will say "we're not putting our
passwords in the cloud." They're wrong, and here is the exact mechanism (verified against
Microsoft's implementation doc, 2026-08-09):

1. **Every 2 minutes** the sync agent requests the `unicodePwd` attribute — the **MD4 (NTLM)
   hash** — from a DC over the **MS-DRSR** replication protocol. Note this is a *separate,
   faster cycle* than the 30-minute directory sync. Password changes propagate in minutes.
2. The DC encrypts that hash with a key derived from the RPC session key plus a salt; the agent
   decrypts it back to MD4. **The agent never sees the clear-text password.**
3. The agent expands the 16-byte hash to 64 bytes (hex string → UTF-16 binary).
4. It adds a **10-byte per-user salt**.
5. It runs the result through **PBKDF2 with 1,000 iterations of HMAC-SHA256**.
6. The resulting 32-byte hash — plus the salt and iteration count — is sent to Entra over TLS.

So the cloud holds a **salted, key-stretched hash of a hash**. Microsoft's own documentation
states it plainly, and this is the sentence to quote in the meeting:

> *"if the hash stored in Microsoft Entra ID is obtained, it can't be used in an on-premises
> pass-the-hash attack."*

Two further facts that win the argument: the value is **never written to SQL** (processed in
memory only), and the SHA256 data in Entra is arguably *more* secure than what already sits in
your own AD database.

> **FIPS gotcha:** a FIPS-locked-down server disables MD5, which PHS needs for the DC
> replication step. Requires `<enforceFIPSPolicy enabled="false" />` in `miiserver.exe.config`.
> Regulated customers hit this during deployment.

### Connect Sync vs Cloud Sync `[CORE]`

| | Connect Sync | Cloud Sync |
|---|---|---|
| Runs on | A Windows server you maintain | Lightweight agents |
| Configuration | Local, in the sync engine | **Cloud-managed** |
| Multi-forest | Yes, with complexity | **Yes, natively — including disconnected forests** |
| Filtering | Very granular (sync rules editor) | Simpler scoping |
| Feature coverage | Full — device writeback, exchange hybrid, etc. | **Narrower** |

**Choose Cloud Sync when:** disconnected forests, M&A with no forest trust, or you want no
sync server to maintain. **Choose Connect Sync when:** you need device writeback, Exchange
hybrid writeback, or complex attribute transformation. They can coexist for different OUs.

### Seamless SSO `[CORE]`

Creates a computer account in AD called **`AZUREADSSOACC$`** holding a Kerberos decryption key.
Domain-joined machines on the corporate network get a Kerberos ticket for
`autologon.microsoftazuread-sso.com` and sign in with no prompt.

**The maintenance item everyone forgets.** Microsoft "highly recommends" rolling that Kerberos
decryption key **at least every 30 days**. It is **not automatic**. An organisation that
enabled Seamless SSO in 2023 and never rolled it has a stale Kerberos key sitting in AD.
Asking about this in a discovery session marks you immediately.

```powershell
cd "$env:ProgramFiles\Microsoft Azure Active Directory Connect"
Import-Module .\AzureADSSO.psd1
New-AzureADSSOAuthenticationContext          # prompts for Hybrid Identity Admin
Get-AzureADSSOStatus | ConvertFrom-Json      # which forests have it enabled
$creds = Get-Credential                      # domain admin, SAM format: contoso\admin
Update-AzureADSSOForest -OnPremCredentials $creds
```

> **⚠ Do not run `Update-AzureADSSOForest` more than once per forest per rollover.** Doing so
> breaks Seamless SSO until every user's existing Kerberos ticket naturally expires and is
> reissued. Also: the domain admin account must **not** be in the Protected Users group, and
> this is not needed on servers in staging mode.

### Staging mode and migration `[CORE]`

**Staging mode** runs a second Connect server that imports and syncs but **exports nothing**.
It's how you validate a new server, a version upgrade, or a config change against real data
before it touches the tenant — and how you fail over: disable staging on the standby, disable
the primary.

**AD FS → managed migration** uses **staged rollout**, which moves selected groups to
cloud auth while the domain remains federated. That's the only way to do this gradually; the
domain-level conversion is all-or-nothing.

What breaks when you decommission AD FS: **claims rules** (custom claims must be recreated as
Entra claims-mapping policies), **MFA adapters** (third-party on-prem MFA is gone; move to
Entra MFA or a CA-integrated provider), and **access control policies** (become CA policies).
Budget for rebuilding those, not just flipping the switch.

### Connect Health `[CORE]`

Agent-based monitoring for sync, AD DS, and AD FS. **Sync error reporting is the part you'll
actually use** — it surfaces the quarantined duplicate-attribute objects that otherwise sit
silently.

### Operational commands

```powershell
# Delta sync (normal). Full sync only when rules changed — it's expensive.
Start-ADSyncSyncCycle -PolicyType Delta
Start-ADSyncSyncCycle -PolicyType Initial

Get-ADSyncScheduler                      # is sync even enabled? default cycle is 30 min
Set-ADSyncScheduler -SyncCycleEnabled $false   # pause during maintenance
Get-ADSyncConnectorRunStatus
```

**First question in any "user isn't syncing" ticket:** is the scheduler enabled and when did
the last cycle run? Someone disables it for maintenance and forgets. Check that before you open
the sync rules editor.

---

## Troubleshooting decision trees

**"User can't sign in"**
```
Does the account exist and is it enabled?
├── NO  → check soft-deleted items (30-day window)
└── YES → Is the domain federated?
     ├── YES → is the IdP up? are its certificates valid?
     └── NO  → PHS or PTA?
          ├── PTA → are ≥1 agents healthy? (Connect Health)
          └── PHS → has the hash ever synced? check last password sync time
```

**"Attribute is wrong in Entra but right in AD"**
```
Is the user actually synced?  (onPremisesSyncEnabled = true)
└── YES → has a sync cycle run since the change?
     └── YES → is the attribute in the sync scope / OU filter?
          └── YES → is a sync rule transforming it?
               └── check inbound rule → metaverse → outbound rule, in that order
```

**"Duplicate user objects appeared"**
→ Soft match failed. Compare the on-prem `ms-DS-ConsistencyGuid` against the cloud
`immutableId`. Resolve with a hard match. Check the sync errors report for quarantined attributes.

---

## Hands-on gate

Requires your own tenant (Global Admin). Run `Seed-LabTenant.ps1` first.

**Lab 1 — Dynamic groups.** Create `(user.department -eq "Engineering")`. Watch membership
populate. Time it. Then change a user's department and time the update. **Internalise that this
is not instant.**

**Lab 2 — Administrative unit.** Create an AU, add the Finance users, assign someone User
Administrator scoped to it. Sign in as them and confirm they cannot touch Engineering users.

**Lab 3 — Group-based licensing.** Assign a licence to a group. Remove a user. Observe the
licence detach. Then try assigning without `UsageLocation` and read the actual error.

**Lab 4 — Soft delete recovery.** Delete a user. Find them via
`Get-MgDirectoryDeletedItemAsUser`. Restore. Confirm the `oid` is unchanged — that's why
restore works and recreate doesn't.

**Lab 5 — Guest invite.** Invite a personal email. Walk the full redemption. Inspect the
resulting object's `userType`, `#EXT#` UPN, and `mail`.

**Lab 6 (hardest, highest value) — Hybrid.** Build a Windows Server VM, promote to a DC, install
Entra Connect with **`ms-DS-ConsistencyGuid`** as source anchor and PHS. Sync an OU. Then
deliberately break it: create a cloud-only user with a colliding UPN, sync, and produce the
duplicate. Fix it with a hard match. **That single exercise teaches more hybrid identity than
any course.**

---

## Cross-references

| Concept here | Where it's used |
|---|---|
| Device join state, PRT | Layer 3 — CA device controls |
| Groups, dynamic membership | Layer 3 CA assignment · Layer 5 access packages |
| PHS | Layer 3 — Identity Protection leaked-credential detection |
| Cross-tenant access settings | Layer 7 — M&A vertical |
| Source anchor, soft/hard match | Layer 7 — M&A, and every hybrid engagement |
| `oid` immutability | Layer 1 §4 — claims · Layer 5 — KQL correlation |
| App registration tenant setting | Layer 1 §6 — illicit consent grant |
