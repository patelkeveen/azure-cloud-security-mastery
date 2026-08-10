# Day 4 — AD, Hybrid Identity, and Federation

> Standard set by [DAY-01](DAY-01.md). `✅ verified` / `⚠ check` convention applies.
>
> **This day has a companion document with far more depth:**
> **[Layer 2 §1.4 — Hybrid identity](../30-identity-and-nhi/entra-users-and-groups/LAYER-2-DOMAIN-1-USER-IDENTITIES.md)**.
> Read it first. This file is the *execution* plan; that file is the *mechanism*. Do not duplicate.

**Outcome:** you can draw the Connect Sync data flow from memory, choose an authentication method
and defend it, and repair a duplicate-object soft-match failure. **More consulting revenue lives
in hybrid identity than anywhere else in the Microsoft identity stack**, because it is where
everything breaks and few people can debug it.

**Lab requirement:** a Windows Server VM promoted to a domain controller, plus your Day 1 tenant.
This is the most infrastructure-heavy day. Budget the VM cost and **tag it with an `expires` date.**

---

## 1. Build the on-premises side

```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools           # ✅
Install-ADDSForest -DomainName lab.local -InstallDns                        # ⚠ check parameters; reboots

Get-ADDomain | Select-Object DNSRoot,NetBIOSName,DomainMode                 # ✅
Get-ADForest | Select-Object Name,ForestMode,GlobalCatalogs                 # ✅
New-ADOrganizationalUnit -Name "SyncScope" -Path "DC=lab,DC=local"          # ✅
```

**Use a routable domain name you control** (e.g. `lab.yourdomain.com`), not `.local`. `.local`
collides with mDNS and cannot be verified as a custom domain in Entra, which forces UPN
suffix work you would otherwise avoid. If you inherit `.local` at a customer, adding an
**alternative UPN suffix** is the standard remedy.

```powershell
Get-ADForest | Set-ADForest -UPNSuffixes @{Add="yourdomain.com"}            # ⚠ check
```

---

## 2. Install Entra Connect — the two decisions you cannot undo

**Choose custom install, not Express.** Express hides both decisions below.

### Decision 1 — source anchor

Choose **`ms-DS-ConsistencyGuid`**, never `objectGUID`.

**The one-line reason, worth memorising verbatim:** *it lets you migrate or rebuild the forest
without re-creating every cloud identity.* `objectGUID` is forest-specific; move an object between
forests and Entra sees a different person, orphaning the old object and everything attached to it.

### Decision 2 — authentication method

| | PHS | PTA | Federation |
|---|---|---|---|
| Auth happens | **Cloud** | On-prem agent | On-prem AD FS |
| On-prem outage | **Users still sign in** | Sign-in fails | Sign-in fails |
| Extra infrastructure | None | Agents (**≥3 for HA**) | AD FS farm + WAP + certs |
| Leaked-credential detection | **Requires this** | No | No |

**Recommend PHS unless there is a hard requirement against it.** PTA and federation make cloud
sign-in depend on on-premises availability — a datacentre problem becomes a Microsoft 365 outage.

**PHS is a hash of a hash.** MD4/NTLM hash → hex → **10-byte per-user salt** → **PBKDF2,
1,000 iterations of HMAC-SHA256**. Microsoft's own words: *"if the hash stored in Microsoft Entra ID
is obtained, it can't be used in an on-premises pass-the-hash attack."* Quote that, don't paraphrase
it — you will need it in a security review. PHS also runs on its **own 2-minute cycle**, separate
from the 30-minute directory sync.

---

## 3. Operate the sync engine

```powershell
Import-Module ADSync                                                        # ✅
Get-ADSyncScheduler | Select-Object SyncCycleEnabled,CurrentlyInProgress,
    NextSyncCyclePolicyType,AllowedSyncCycleInterval                        # ✅

Start-ADSyncSyncCycle -PolicyType Delta                                     # ✅ normal
Start-ADSyncSyncCycle -PolicyType Initial                                   # ✅ full - expensive, only after rule changes

Get-ADSyncConnector | Format-Table Name,Type                                # ✅
Get-ADSyncConnectorRunStatus                                                # ✅
```

> **First question in any "user isn't syncing" ticket: is the scheduler even enabled, and when did
> the last cycle run?** Someone disables it for maintenance and forgets. Check that before you open
> the sync rules editor.

**The three-stage model** — memorise it, because it turns "the attribute is wrong in Entra" from a
guess into a bisect:

```
AD → [connector space] → METAVERSE → [connector space] → Entra
      inbound rules                    outbound rules
```

Ask **which stage did it stop at**, then look at the rule governing that transition. Never edit an
out-of-box rule; clone it, adjust precedence, disable the original.

---

## 4. The failure that defines this day: soft match vs hard match

**Cause it deliberately.** This single exercise teaches more hybrid identity than any course.

1. Create a **cloud-only** user `priya@yourdomain.com` in Entra. Give them a licence.
2. Create an on-prem AD user with a **different** primary SMTP / UPN, in the sync scope.
3. Run a delta sync.
4. Observe: **two objects for one human.** One holds the mailbox and licence; the new one is now
   authoritative and empty.

**Why:** soft match links a new synced object to an existing cloud object by **primary SMTP or
UPN**. If those don't align, no match, and Entra creates a second object.

**Fix — hard match:** set the cloud object's `immutableId` to the base64 form of the on-prem
`ms-DS-ConsistencyGuid`, forcing the link.

```powershell
# Get the on-prem anchor and convert to the base64 immutableId Entra expects
$u = Get-ADUser priya -Properties 'ms-DS-ConsistencyGuid'
[Convert]::ToBase64String($u.'ms-DS-ConsistencyGuid')                       # ✅ conversion pattern
```

**Duplicate attribute resiliency** stops this from failing the whole export — the conflicting
attribute is quarantined and sync continues. Good behaviour, and it means **the error is silent
unless you look.** Check the sync errors report; "sync completed" does not mean "sync correct."

---

## 5. Seamless SSO — and the maintenance nobody does

Creates a computer account holding a Kerberos decryption key. Domain-joined machines on the
corporate network then sign in with no prompt.

**Microsoft "highly recommends" rolling that key at least every 30 days. It is not automatic.**

```powershell
cd "$env:ProgramFiles\Microsoft Azure Active Directory Connect"
Import-Module .\AzureADSSO.psd1
New-AzureADSSOAuthenticationContext          # prompts for Hybrid Identity Admin
Get-AzureADSSOStatus | ConvertFrom-Json      # which forests have it enabled
$creds = Get-Credential                      # domain admin, SAM format: contoso\admin
Update-AzureADSSOForest -OnPremCredentials $creds
```

> ⚠ **Do not run `Update-AzureADSSOForest` more than once per forest per rollover.** Doing so
> breaks Seamless SSO until every existing Kerberos ticket naturally expires. The domain admin
> account must also **not** be in the Protected Users group.

Asking a customer *"when did you last roll the Seamless SSO Kerberos key?"* marks you instantly.
The usual answer is "the what?"

---

## 6. Staging mode, migration, and rollback

**Staging mode** = a second Connect server that imports and syncs but **exports nothing**. It is
how you validate a version upgrade or config change against real data before it touches the
tenant, and how you fail over: disable staging on the standby, disable the primary.

**AD FS → managed** uses **staged rollout** to move selected groups to cloud auth while the domain
stays federated. That is the only gradual path; the domain-level conversion is all-or-nothing.

**What breaks when AD FS is decommissioned** — budget for rebuilding these, not just flipping the
switch: claims rules (recreate as Entra claims-mapping policies), on-prem MFA adapters (gone; move
to Entra MFA), and AD FS access control policies (become Conditional Access policies).

---

## 7. Failure exercises

| Cause it | Expected |
|---|---|
| UPN suffix in AD not verified in Entra | Users sync with `...@tenant.onmicrosoft.com` — explain why |
| Duplicate primary SMTP across two AD objects | Sync error; attribute quarantined; export continues |
| Disable the scheduler, then change an attribute | Nothing syncs; no error anywhere |
| Filter an OU out of scope while users are in it | Users are **deleted** in Entra — this is the scary one |
| Sign in during a simulated PTA agent outage | Auth fails. Repeat with PHS — auth succeeds |

**Exercise 4 is the one to internalise.** Narrowing sync scope deletes cloud objects. In production
that is a mass-deprovisioning incident. This is precisely why staging mode exists.

---

## 8. Teach-back

1. **Why `ms-DS-ConsistencyGuid` over `objectGUID`?** It survives forest migration/rebuild.
2. **Why is PHS not "passwords in the cloud"?** Salted, key-stretched hash of the NTLM hash;
   unusable for on-prem pass-the-hash.
3. **Soft match vs hard match?** SMTP/UPN vs immutableId; the latter forces the link after the
   former fails.
4. **What is the metaverse for?** One object per real person, joined across sources; the place
   attribute precedence is resolved.
5. **Why does PHS enable leaked-credential detection?** Microsoft can compare your hashes against
   breach corpora; federated/PTA-only tenants get nothing.
6. **What does staging mode protect you from?** Exporting a bad configuration to the live tenant.

---

## 9. Deliverables

| Facet | Artifact |
|---|---|
| `lab/` | DC + Connect installed; sync working; screenshots of the sync rules editor |
| `break-fix/` | The duplicate-object failure **caused and repaired**, with exact error text |
| `security/` | PHS defence write-up; Seamless SSO key rotation schedule |
| `operations/` | Sync troubleshooting runbook; staging-mode failover procedure |
| `architecture-decisions/` | ADR: source anchor and auth method, with alternatives rejected |
| `customer-use-cases/` | **M&A** — cross-tenant sync, UPN collisions, matching strategy — [Layer 7 §9](../80-customer-scenarios/LAYER-7-INDUSTRY-VERTICALS.md) |

**Cleanup:** disable the scheduler, uninstall Connect, delete synced objects from Entra (30-day
soft-delete), **then** delete the VM resource group. Order matters — deleting the VM first leaves
orphaned synced objects with no way to manage them.
