# Lab — a real domain controller in Azure

> ⭐ **First, the terminology.** There is nothing "fake" about this. It is a **real** AD DS forest,
> real Kerberos, real LDAP, real replication topology — running on a **non-production** tenant.
> ⭐ **"Fake" and "lab" are not synonyms, and the difference matters in an interview:** a lab
> forest teaches you the same mechanics a 40,000-seat forest does. What it does not teach you is
> *scale* — multi-site replication, DFS-R SYSVOL bloat, a 15-year-old schema nobody dares extend.
> ⭐ **Say "lab", know which lessons transfer, and you sound like someone who has thought about it.**

---

## 1. ⚠ The trap I want you to not fall into

⭐ **Do not build this before 28 August.**

You asked for production-level hybrid experience. You should have it — it is the strongest part
of your moat. But right now you are **8 days from an identity exam**, and:

- Hybrid identity is roughly **5–8% of SC-300**, and the exam tests the **decision model**
  (which auth method satisfies which requirement), ⭐ **not your ability to run `Install-ADDSForest`**.
- Conditional Access is **25–30%** and your Day 3 is tomorrow.
- Building DC + Connect + fixing what breaks is realistically **4–8 hours**. That is a lab day you
  do not have.

⭐ **The scheduling insight that makes this a non-problem: your Azure credit expires 2026-09-10,
and your E5 trial expires 2026-09-10. The two clocks are identical.** So **29 August – 10
September is 13 clear days with both live** — that is the hybrid window, and nothing is lost by
waiting for it.

⭐ **Optional, if you want one concrete anchor before the exam:** on **Day 6 evening**, deploy and
promote only (**~90 min, mostly waiting**), sync one user, watch PHS actually happen, then
`-Stop`. Reading *"PHS syncs a hash of a hash every 2 minutes"* and **watching it** are different
memories. ⭐ **That is a want, not a need. If Day 6 runs long, skip it without guilt.**

---

## 2. ⭐ Money is not your constraint. Stop optimising it

Live retail prices, `centralindia`, pulled **2026-08-20** from the Azure Retail Prices API — not
estimated:

| SKU | vCPU / RAM | Linux ₹/hr | **Windows ₹/hr** |
|---|---|---|---|
| B2s | 2 / 4 GB | 4.2851 | ⭐ **5.0503** |
| B2ms | 2 / 8 GB | 8.5702 | 9.3354 |

```
2x B2s Windows, 24/7, 21 days   =  INR 5,091   ⭐ 27% of your INR 19,130
2x B2s Windows, 8h/day, 21 days =  INR 1,697        9%
+ ~INR 50/day for two StandardSSD OS disks (these bill even when deallocated)
```

⭐ **You could run this lab continuously for the entire remaining credit window and spend about a
quarter of it.** Auto-shutdown is still on by default — good hygiene, not financial necessity.

### ⚠ What *is* the constraint

⭐ **vCPU quota.** Per [Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/5838392/why-cant-i-upgrade-my-vcpu-quota),
**Free Trial subscriptions cannot request a quota increase.** This lab needs **4 vCPU**. Check
before you build anything — `Deploy-HybridLab.ps1` does it for you and exits rather than half-building:

```powershell
az vm list-usage --location centralindia --output table
```

⭐ **If you are capped below 4:** run **one** VM and put Entra Connect on the DC. Not production
shape, but it labs correctly. Or upgrade to Pay-As-You-Go — ⭐ **your credit carries over** and the
cap lifts.

### ⚠ The wrong tool, which is expensive and everybody reaches for it

⭐ **Microsoft Entra Domain Services is NOT this.** It is a *managed* domain **synced downward
from** Entra ID. ⭐ **The arrow points the wrong way** — you cannot run Entra Connect from it into
Entra ID, because that is the direction it already flows. It exists for lift-and-shift apps that
need LDAP/Kerberos, not for learning hybrid identity. ⭐ **It also costs roughly ₹9,000+/month,
which would eat your whole credit for the one thing it cannot teach you.**

---

## 3. The architecture, and why each choice

```
        Internet
           |  RDP 3389, from YOUR /32 only
           v
   [ sync01 ]  public IP  ---- jump host + Entra Connect
       |  private
       v
   [ dc01 ]    10.50.1.4  ---- NO public IP. AD DS + DNS.
```

| Choice | ⭐ Why |
|---|---|
| ⭐ **DC has no public IP** | A domain controller is never internet-facing. You reach it *through* sync01. This is the jump-host pattern and it costs nothing to do right |
| ⭐ **RDP from one /32** | Exposed 3389 is still among the most reliably exploited things on the internet. The NSG is the control; re-run `-SetMyIp` when your ISP rotates |
| ⭐ **Static IP at the Azure layer** | A DC must have a stable address. ⚠ **Set it in Azure, never inside the Windows guest** — hard-coding it in the guest is a classic way to lose all connectivity to a cloud DC |
| **VNet DNS set *after* promotion** | Point DNS at the DC before it answers and sync01 can resolve nothing and install nothing. ⭐ **Order is the lesson** |
| **StandardSSD, not Premium** | A lab DC does not need P-tier IOPS. Premium roughly doubles the disk line for zero learning |
| **Connect on sync01, not dc01** | ⭐ Connect brings SQL Express, its own patch cadence and reboots. A DC's cadence is different. Separating them is the production answer |
| `deleteOption: Delete` | Orphaned managed disks bill quietly forever after you delete a VM |
| Everything tagged `expires` | Untagged lab resources are how personal cloud bills happen |

---

## 4. Run order — the order *is* the content

```powershell
# On your laptop
$env:LAB_ADMIN_PASSWORD = 'Choose-Something-Strong!2026'

.\Deploy-HybridLab.ps1                     # plan. checks quota + prints real cost. builds nothing
.\Deploy-HybridLab.ps1 -Apply              # ~8 min

# RDP to sync01 (FQDN is printed), then RDP from there to 10.50.1.4
# ON dc01:
.\Initialize-LabForest.ps1 -Promote -Apply  # reboots

.\Deploy-HybridLab.ps1 -SetDnsToDC -Apply   # ⭐ skip this and nothing joins the domain

# ON dc01, after reboot:
.\Initialize-LabForest.ps1 -Seed -Apply

# End of day
.\Deploy-HybridLab.ps1 -Stop
```

---

## 5. ⭐ The one thing this lab is really about

The forest is **`kwinlab.local`** — deliberately non-routable, ⭐ **because that is what you will
actually walk into at a customer.**

⭐ **A `.local` UPN cannot sync usefully.** Entra will not accept the suffix, so Connect stamps
every user `@KWin.onmicrosoft.com` — and nobody can sign in with the username they already know.

⭐ **The fix is not to rename the forest.** It is to add a **verified, routable domain as an
alternative UPN suffix** and restamp user UPNs onto it. `Initialize-LabForest.ps1` §2.1 does
exactly that. ⭐ **This is the most common hybrid identity remediation in the field**, and it is
why *"we'll just install Connect on Friday"* becomes a weekend.

### Matching — soft vs hard

```
SOFT MATCH   joins on UPN or primary SMTP. Automatic, no admin action.
HARD MATCH   joins on immutableId / sourceAnchor. You set it deliberately.
```

The seeded AD users **deliberately mirror the UPNs** created by
[`Seed-LabTenant.ps1`](../../../30-identity-and-nhi/entra-users-and-groups/Seed-LabTenant.ps1),
so Connect **soft-matches** them to the existing cloud objects instead of creating duplicates.
⭐ **If they did not match, the lab would teach you nothing about matching** — you would just get
16 new users.

⚠ **Since 2026-07-01, hard match is blocked** against cloud accounts that hold *or are eligible
for* a privileged role, or that already carry `onPremisesObjectIdentifier`. Enforced cloud-side.
⭐ **Test it against one of your PIM-eligible users and capture the refusal** — that is a
break-fix artifact with a date on it, which is worth more than a screenshot of success.

---

## 6. The objects that exist to fail

⭐ **A lab that only succeeds teaches you nothing you can use at 2am.** The seed creates four:

| Object | What it proves |
|---|---|
| `Excluded User` in `OU=NoSync` | ⭐ OU filtering actually excludes. Verify it is **absent** from Entra |
| `Legacy Local` with a `.local` UPN | Watch Entra **restamp** it to `@onmicrosoft.com` — §5 made concrete |
| ⭐ `Dupe Address` | Duplicate `proxyAddresses`. ⭐ **The single most common Connect error in production** |
| `svc-entraconnect` | The connector account. ⭐ **Least privilege — not Domain Admin**, which is what most people wrongly do |

⚠ **The duplicate proxyAddress surfaces as an *export* error, not an import one** — so people look
in the wrong place for an hour. In Synchronization Service Manager it reads
`AttributeValueMustBeUnique`. ⭐ **Capture that string verbatim.**

⭐ Also seeded: `fatima.al-rashid` is 16 characters. `sAMAccountName` caps at **20** — longer names
truncate silently and then collide. **Real migrations die on this.**

---

## 7. ⭐ Why this one resource is worth the credit

⭐ **A domain controller is the highest-leverage thing you can build**, because it unblocks four
domains at once — not one:

| Unlocks | Where |
|---|---|
| PHS / PTA / federation, Connect, writeback | ⭐ SC-300 D1 — **and your biggest employability gap** |
| ⭐ **Defender for Identity sensor** | Your `Day1-Enable-Telemetry.ps1` §3 literally says *"only if you have a domain controller to sensor"* — SC-200 |
| Windows Security Events → Sentinel | SC-200 core |
| Connect break-fix, coexistence, cutover | [`45-m365-migration-engineering`](../../../45-m365-migration-engineering/) — ⭐ the repo's "most employable domain" |

⭐ **That is the argument for spending the credit here rather than anywhere else.** One VM,
four domains.

---

## 8. What this still will not teach you

⭐ **Be precise about this in interviews — the precision is the credential.**

- ⭐ **Scale.** One DC, one site, 14 users. Not multi-site replication, not SYSVOL bloat, not a
  schema nobody dares extend.
- ⭐ **Consequence.** Nothing breaks for anyone when you get it wrong. Production judgement is
  partly built by having been frightened.
- **ADFS.** Not deployed here. Federation stays theory — see [`GAP-DRILL.md`](../../../SC-300-SPRINT/GAP-DRILL.md) §3.
- **Legacy.** No 15 years of accumulated GPOs, no undocumented dependencies.

> **Related:** [`../../entra-connect-sync/`](../../entra-connect-sync/) ·
> [`../../source-anchor-and-matching/`](../../source-anchor-and-matching/) ·
> [`../../adfs-and-federation/`](../../adfs-and-federation/) ·
> [`../../../SC-300-SPRINT/EXAM-COUNTDOWN.md`](../../../SC-300-SPRINT/EXAM-COUNTDOWN.md) ·
> [`../../../SC-300-SPRINT/GAP-DRILL.md`](../../../SC-300-SPRINT/GAP-DRILL.md) §3
