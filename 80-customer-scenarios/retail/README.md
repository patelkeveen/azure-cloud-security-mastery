# Retail

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **Boundary:** [`../LAYER-7-INDUSTRY-VERTICALS.md`](../LAYER-7-INDUSTRY-VERTICALS.md) §6 is the
> brief. ⭐ **This is engagement depth — the vertical defined by churn, shared devices and a
> workforce with no email address.** Pairs with
> [`../../30-identity-and-nhi/lifecycle-workflows/`](../../30-identity-and-nhi/lifecycle-workflows/).

---

## 1. What it is

Identity engineering for retailers: head office behaves like any other business, and ⭐ **the store
estate behaves like nothing you have designed for.** Thousands of frontline staff, high turnover,
shared point-of-sale and stockroom devices, seasonal surges, and PCI-DSS obligations wherever cards
are handled.

⭐ **The design problem is not security depth. It is scale, churn and the fact that most of the
workforce has no desk, no PC and often no work email.**

---

## 2. Why it is different

| Standard assumption | ⭐ Retail reality |
|---|---|
| Every user has a mailbox | ⭐ **frontline staff often have no email** |
| Users have a work phone | ⭐ **personal phones only — ⭐ and asking to install an app is contentious** |
| One device per user | ⭐ **shared tablet on the shop floor**, 12 users a day |
| Joiners are a trickle | ⭐ **800 seasonal hires in three weeks** |
| Leavers are processed | ⭐ **someone simply stops turning up** |
| IT can visit the site | ⭐ **400 stores, no local IT, ⭐ and a manager who is not technical** |

⭐ **Churn is the defining property.** ⭐ **A retailer with 30 % annual turnover and 8,000 staff
processes roughly 2,400 joiners and leavers a year — about ten every working day** — and the leaver
half is where the security exposure sits, because nobody has an incentive to report it.

⭐ **"How long from termination to access revoked — measured, not intended?"** is the single most
productive question here, and the answer is usually unknown. ⭐ **Finding out is often the first real
deliverable.**

---

## 3. How it works underneath — HR as the source of truth

```
⭐ THE ONLY DESIGN THAT SURVIVES RETAIL CHURN IS AN AUTOMATED ONE.

  ⭐ HR SYSTEM (Workday / SAP SF / etc.)   ⭐ ← the authoritative source
        │  ⭐ hire date · termination date · store · role
        ▼
  ⭐ Inbound provisioning to Entra
        │
        ├─ ⭐ JOINER  account created ⭐ BEFORE day one,
        │            ⭐ dynamic group membership by store + role
        │            ⭐ → licence, apps and access follow automatically
        │
        ├─ MOVER   ⭐ store changes → ⭐ old store access REMOVED
        │            ⭐ (the step manual processes always miss)
        │
        └─ ⭐ LEAVER  ⭐ termination date in HR
                     ⭐ → disable + REVOKE SESSIONS, same day
```

⭐ **The mover case is the one manual processes get wrong.** ⭐ **A colleague transferring from
Store 214 to Store 087 gets the new access and keeps the old** — and after three transfers they can
open four stores' systems. ⭐ **Attribute-based dynamic groups fix this by construction**, because
membership is recomputed from the current attribute rather than added by a human.

⭐ **Disabling is not enough on its own.** ⭐ **An existing token remains valid until it expires**, so
a leaver disabled at 09:00 may still be working in an app at 10:30. ⭐ **Revoke sessions as part of
the same action** — this is the same token-lifetime lesson that appears throughout
[`../../30-identity-and-nhi/conditional-access/`](../../30-identity-and-nhi/conditional-access/).

---

## 4. Worked example — measuring the leaver gap

⭐ **Do not ask what the process is. Measure what happened.**

```powershell
# ⭐ Accounts still enabled with no sign-in for 60+ days.
# ⭐ In retail these are overwhelmingly unprocessed leavers.
$cut = (Get-Date).AddDays(-60)
Get-MgUser -All -Property UserPrincipalName,AccountEnabled,SignInActivity,Department `
  -Filter "accountEnabled eq true" |
  Select-Object UserPrincipalName, Department,
    @{n='LastSignIn';e={$_.SignInActivity.LastSignInDateTime}} |
  Where-Object { $_.LastSignIn -and $_.LastSignIn -lt $cut } |
  Sort-Object LastSignIn | Select-Object -First 5
```

```
UserPrincipalName          Department      LastSignIn
s.begum@contoso.com        Store 214       2025-11-03   ⭐ 9 MONTHS
t.oyelaran@contoso.com     Store 087       2026-01-22
k.nowak@contoso.com        Seasonal        2026-02-04   ⭐ ← ⭐ last Christmas
```

⭐ **`Seasonal`, last active in February, still enabled in August.** ⭐ **That is a live credential
for someone who left eight months ago**, and there will not be one of them — there will be several
hundred.

⭐ **Turn it into the number that gets budget:**

```powershell
$stale = @(...)   # the query above, unfiltered by Select-First
"Enabled accounts, no sign-in 60d+ : $($stale.Count)"
"Licensed among those             : $(@($stale | Where-Object {...}).Count)"
```

```
Enabled accounts, no sign-in 60d+ : 612
Licensed among those              : 588
```

⭐ **Two arguments in one output.** ⭐ **612 live credentials belonging to people who have left is a
security finding; 588 of them consuming licences is a cost finding with a monthly figure attached**
— and the cost argument is usually what funds the automation project that fixes the security one.

⭐ **Present both. Lead with whichever the person in the room owns.**

---

## 5. The frontline authentication problem

⭐ **Standard MFA guidance assumes a phone the user will install an app on. In retail, that
assumption fails on three grounds at once:** many staff will not install a work app on a personal
phone, phones are frequently not permitted on the shop floor, and the device is shared anyway.

| Option | ⭐ Fit for a store |
|---|---|
| Authenticator app | ⭐ **personal-device objection**; ⭐ contentious with unions/works councils |
| SMS | ⭐ weak, ⭐ and costs money at scale |
| ⭐ **FIDO2 security key** | ⭐ good — ⭐ but ⭐ per-user cost × 8,000 |
| ⭐ **Shared device mode + strong device identity** | ⭐ often the practical answer |
| ⭐ Temporary Access Pass | ⭐ **excellent for onboarding day one** |

⭐ **Temporary Access Pass deserves specific mention here** because retail onboarding is exactly the
problem it solves: ⭐ **a new starter with no credential, no device and no time can be issued a
time-limited pass by a store manager and complete registration in minutes.** See
[`../../30-identity-and-nhi/authentication-methods/`](../../30-identity-and-nhi/authentication-methods/).

⭐ **And the honest position on personal devices: "install our app on your phone" is a
labour-relations question, not just a technical one.** ⭐ **In several jurisdictions you cannot
require it**, and designing as though you can produces a rollout that stalls in consultation. Ask
early — the same works-council question as
[`../../75-architecture-and-consulting/discovery/`](../../75-architecture-and-consulting/discovery/) §4.

---

## 6. Design reference

| Control | Setting | ⭐ Retail reason |
|---|---|---|
| ⭐ Joiner/leaver | ⭐ **HR-driven inbound provisioning** | ⭐ ten a day; manual cannot keep up |
| Group membership | ⭐ **dynamic, by store + role attribute** | ⭐ fixes the mover case by construction |
| Leaver action | ⭐ disable **+ revoke sessions** | ⭐ tokens outlive the disable |
| ⭐ Frontline licensing | ⭐ frontline SKUs where they fit | ⭐ E-tier for 8,000 store staff is unaffordable |
| Shared devices | shared device mode, ⭐ short session | shop floor reality |
| Onboarding credential | ⭐ **Temporary Access Pass** | day-one, no device |
| Cardholder environment | ⭐ **separate, MFA-enforced, scoped** | PCI-DSS — [`../fintech-and-banking/`](../fintech-and-banking/) §5 |
| Seasonal peak | ⭐ **pre-provision + a change freeze** | ⭐ nobody changes anything in December |

⚠ `⚠ check` — frontline (F-series) licence contents and what identity features they include have
changed; ⭐ **verify per-SKU entitlements before designing around them.** Getting this wrong at 8,000
seats is a large and visible error.

⭐ **The December change freeze is not optional at a retailer.** ⭐ **Peak trading is a
capacity, change-control and staffing constraint simultaneously** — see
[`../../70-operations-and-reliability/change-management/`](../../70-operations-and-reliability/change-management/) §6.
Agree the dates in January.

---

## 7. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| ⭐ Hundreds of live leaver accounts | ⭐ manual offboarding at scale | ⭐ HR-driven deprovisioning |
| Leaver "disabled" but still working | ⭐ sessions not revoked | ⭐ revoke in the same action |
| ⭐ Staff can access their old store | ⭐ mover case | ⭐ dynamic groups on the store attribute |
| Seasonal hires get access in week 3 | manual provisioning | ⭐ pre-provision from the HR feed |
| ⭐ MFA rollout stalls | ⭐ personal-device objection | ⭐ ask about it in discovery, not after |
| Licence spend inexplicable | ⭐ licences on departed staff | ⭐ the §4 query, monthly |
| Change broke a store in December | ⭐ no freeze | ⭐ published freeze dates |

⭐ **"Staff can access their old store" is the finding most likely to interest a loss-prevention
team**, and loss prevention often holds budget that IT security does not. ⭐ **Knowing which
department cares about which finding is how consulting work gets funded.**

---

## 8. Customer discovery questions

1. ⭐ **"How long from termination to access revoked — measured, not intended?"**
2. "Which system is authoritative for who works here, and does it hold a termination date?"
3. ⭐ **"How many people join in your peak month?"**
4. "Do frontline staff have work email? A work phone?"
5. ⭐ **"Can you require staff to install an app on a personal phone?"** (⭐ often a legal answer)
6. "How does a new starter get their first credential, on day one, in a store?"
7. ⭐ **"When is your change freeze, and who enforces it?"**

---

## 9. Remember it

**Hook — ⭐ `J M L` at scale: Joiner, Mover, Leaver** — ⭐ **and Mover is the one everybody gets
wrong.**

**Analogy — keys to 400 shops.** ⭐ **Cut a physical key for every new starter and take it back when
they leave, and within two years you have no idea how many keys exist or who holds them — and the
person who transferred between branches kept both.** The analogy predicts the design: ⭐ **you stop
issuing keys and fit a badge system driven by the staff roster**, so that leaving the roster removes
access automatically, ⭐ **and moving branch changes which door opens rather than adding one.**

**The one line:** ⭐ **Drive joiner-mover-leaver from HR, revoke sessions when you disable, and
measure the leaver gap rather than asking about the process.**

---

## 10. Self-test

1. Which of joiner/mover/leaver do manual processes handle worst, and why?
   → ⭐ Mover — new access is added, old access is never removed.
2. Why is disabling a leaver insufficient?
   → ⭐ Existing tokens remain valid until expiry; revoke sessions too.
3. Why present both a security and a cost figure for stale accounts?
   → ⭐ The cost argument usually funds the automation that fixes the security problem.
4. What makes Temporary Access Pass a good fit for retail onboarding?
   → ⭐ Day-one credential with no existing device, issuable locally, time-limited.
5. Why is "install the app on your phone" not purely a technical question?
   → ⭐ It is a labour-relations and sometimes legal question; in some jurisdictions you cannot require it.
6. What fixes the mover case by construction?
   → ⭐ Dynamic group membership computed from the current store/role attribute.
7. Why does December matter?
   → ⭐ Peak trading — a simultaneous capacity, change-freeze and staffing constraint.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | ⭐ the stale-enabled-account query, with both counts |
| `security` | one leaver traced end to end: HR date → disable → session revoke, timed |
| `operations` | ⭐ the dynamic group rule that handles the mover case, with a transfer tested |
| `customer-use-cases` | the frontline authentication decision, including the personal-device answer |
| `architecture-decisions` | ⭐ the licence-tier decision for the store estate, with the cost model |
