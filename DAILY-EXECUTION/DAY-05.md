# Day 5 — M365 Discovery and Assessment

> Standard set by [DAY-01](DAY-01.md). `✅ verified` / `⚠ check` convention applies.

**Outcome:** a repeatable discovery process that turns an unknown tenant into an inventory, a
dependency map, and a risk register — in a day, without breaking anything.

**Why this day matters commercially:** discovery is the **first paid engagement** most consultants
land, it is entirely read-only, and it produces the artifact every later phase depends on. A
migration priced without discovery is a guess, and guesses lose money.

---

## 1. The discovery principle

**Read-only, evidence-first, assumption-labelled.**

Every number you report must be reproducible by re-running a command. Every number you *cannot*
verify must be labelled an assumption. A discovery report that mixes measured facts with
plausible-sounding estimates is worse than no report — it gets used for pricing.

```powershell
Connect-MgGraph -Scopes 'Directory.Read.All','User.Read.All','Group.Read.All',
    'Reports.Read.All','AuditLog.Read.All','Policy.Read.All'                # ✅
Connect-ExchangeOnline
Connect-SPOService -Url https://<tenant>-admin.sharepoint.com
```

**Ask for the least privilege that works: Global Reader.** It reads everything and can change
nothing — which protects both you and the customer, and it is the correct ask in a discovery SOW.

---

## 2. Identity inventory

```powershell
# Population shape
$u = Get-MgUser -All -Property Id,UserPrincipalName,UserType,AccountEnabled,
     CreatedDateTime,OnPremisesSyncEnabled,AssignedLicenses                 # ✅
$u.Count
$u | Group-Object UserType        | Select-Object Name,Count               # Member vs Guest
$u | Group-Object AccountEnabled  | Select-Object Name,Count               # enabled vs disabled
$u | Group-Object OnPremisesSyncEnabled | Select-Object Name,Count         # synced vs cloud-only
```

**What each split tells you:**

- **Guest ratio** — a tenant that is 40% guests has a governance problem and a migration problem.
- **Disabled but licensed** — direct, immediate cost saving. Usually the first money you find.
- **Synced vs cloud-only** — decides whether Day 4's hybrid work is in scope at all.

```powershell
# Licensing - the fastest ROI finding in any assessment
Get-MgSubscribedSku | Select-Object SkuPartNumber,
    @{n='Total';e={$_.PrepaidUnits.Enabled}},
    ConsumedUnits,
    @{n='Available';e={$_.PrepaidUnits.Enabled - $_.ConsumedUnits}} |
    Sort-Object Available -Descending                                       # ✅

# Licensed accounts that are disabled - pure waste
$u | Where-Object { -not $_.AccountEnabled -and $_.AssignedLicenses.Count -gt 0 } |
    Select-Object UserPrincipalName                                         # ✅
```

```powershell
# Privileged population - the security headline
Get-MgDirectoryRole -All | ForEach-Object {
    $r = $_
    Get-MgDirectoryRoleMember -DirectoryRoleId $r.Id -All -ErrorAction SilentlyContinue |
      ForEach-Object { [pscustomobject]@{ Role=$r.DisplayName; MemberId=$_.Id } }
} | Group-Object Role | Select-Object Name,Count | Sort-Object Count -Descending   # ✅ pattern
```

**Global Administrator count is the number every CISO reacts to.** Microsoft's guidance is a small
number — typically fewer than five. Finding twenty-three is a headline finding, and PIM (Day 9,
[Layer 5 §4](../30-identity-and-nhi/pim-and-access-reviews/LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md))
is the remedy.

---

## 3. Workload inventory

```powershell
# Exchange
Get-Mailbox -ResultSize Unlimited | Select-Object DisplayName,RecipientTypeDetails,
    PrimarySmtpAddress,ArchiveStatus | Group-Object RecipientTypeDetails    # ✅
Get-MailboxStatistics -Identity user@domain.com |
    Select-Object DisplayName,TotalItemSize,ItemCount                       # ✅

# SharePoint / OneDrive volume - the number that drives migration duration
Get-SPOSite -Limit All -IncludePersonalSite $true |
    Measure-Object StorageUsageCurrent -Sum                                 # ✅ result in MB

# Teams
Get-Team | Measure-Object                                                   # ✅
```

**Data volume is the migration schedule.** Total gigabytes ÷ realistic throughput = wall-clock
time, and throughput is throttled by the *source*, not your ambition. Never quote a cutover date
before you have measured volume **and** item count — a million small files migrate far slower than
the same gigabytes in large ones.

---

## 4. Configuration and security posture

```powershell
Get-MgIdentityConditionalAccessPolicy | Select-Object DisplayName,State      # ✅
Get-SPOTenant | Select-Object SharingCapability,DefaultSharingLinkType       # ✅ (Day 3)
Get-OrganizationConfig | Select-Object Name,IsDehydrated                     # ✅
Get-AcceptedDomain | Format-Table DomainName,DomainType,Default              # ✅
```

**Legacy authentication usage — measure before you propose blocking it.** This is the highest-value
KQL query in a discovery, and it needs a Log Analytics workspace fed by diagnostic settings:

```kusto
SigninLogs
| where TimeGenerated > ago(30d)
| where ClientAppUsed in ("Exchange ActiveSync","IMAP4","POP3","SMTP",
                          "Other clients","Authenticated SMTP")
| summarize Count=count(), Apps=make_set(AppDisplayName) by UserPrincipalName, ClientAppUsed
| sort by Count desc
```

> **If diagnostic settings were never configured, this returns nothing — and the history is
> unrecoverable.** Entra keeps sign-in logs 7 days on Free and 30 days on P1/P2, and **retention
> changes are not retroactive.** Configuring log export is therefore a discovery *finding*, not a
> later task. See [Layer 5 §5](../30-identity-and-nhi/pim-and-access-reviews/LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md).

---

## 5. Dependency mapping — the part juniors skip

Inventory is *what exists*. Dependency mapping is *what breaks if you move it*. The second is
where the value is.

For each workload record: **what authenticates to it**, **what it authenticates to**, **hardcoded
endpoints**, **service accounts**, **scheduled jobs**, **third-party integrations**.

The three that reliably bite during migration:

1. **Hardcoded SMTP endpoints** in scanners, ERP and line-of-business apps
2. **Service accounts with no owner** — nobody knows what breaks if you disable them
3. **App registrations with expiring secrets** — see the expiry report in
   [Layer 4 §5](../30-identity-and-nhi/service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md)

---

## 6. The output: four artifacts

| Artifact | Contains |
|---|---|
| **Inventory** | Counts and volumes, every one reproducible from a recorded command |
| **Dependency map** | What talks to what; what breaks if it moves |
| **Risk register** | Finding, likelihood, impact, owner, remediation — ranked |
| **Current-state report** | Executive summary; measured facts and assumptions **clearly separated** |

**Rank the risk register by business impact, not technical severity.** "23 Global Admins" outranks
"TLS 1.0 enabled on one endpoint" in every conversation with a decision-maker, even when the
CVSS says otherwise.

---

## 7. Failure exercises

| Cause it | Expected / lesson |
|---|---|
| Run a report without `-All` / `-ResultSize Unlimited` | Silently truncated at the default page — **your inventory is simply wrong** |
| Query `SignInActivity` without the right scope/licence | Property returns null; conclusions about "inactive users" are false |
| Use `Where-Object` instead of server-side `-Filter` on 50k users | Works, but pulls everything over the wire — time it, feel the difference |
| Report a count from the portal and from Graph | They can differ (guests, soft-deleted). Explain which is authoritative and why |

**Exercise 1 is the career-relevant one.** A truncated inventory produces a confident, wrong number
that gets used for pricing. Always paginate explicitly.

---

## 8. Teach-back

1. **Why Global Reader for discovery?** Reads everything, changes nothing; protects both parties.
2. **Why is item count as important as data volume?** Throughput is per-item bound as well as
   per-byte; many small files are slower than the same size in few large ones.
3. **Why must legacy auth be measured before it's blocked?** Blocking it breaks whatever still uses
   it — and something always does.
4. **What makes a finding a "headline"?** Business impact and executive legibility, not CVSS.
5. **Why is missing log retention a finding in itself?** Without diagnostic settings, history is
   gone and unrecoverable — you cannot investigate what you never stored.
6. **Inventory vs dependency map?** What exists vs what breaks when it moves.

---

## 9. Deliverables

| Facet | Artifact |
|---|---|
| `lab/` | Full inventory scripts, re-runnable, with output |
| `break-fix/` | The truncation and scope failures, with proof of the wrong numbers |
| `security/` | Privileged-account report; legacy auth; sharing posture; risk register |
| `operations/` | Discovery runbook and questionnaire; least-privilege access request template |
| `architecture-decisions/` | ADR: what was excluded from scope and why |
| `customer-use-cases/` | Discovery differences by vertical — [Layer 7 §1](../80-customer-scenarios/LAYER-7-INDUSTRY-VERTICALS.md) |

**Cleanup:** nothing to remove — this day is read-only by design. **Do delete the exported
inventory data**, which is customer PII, or store it under the handling rules the engagement
specifies.
