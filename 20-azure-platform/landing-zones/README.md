# Landing Zones

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Governance encoded as deployable artifacts** — the assembly of everything else in this domain.
> Requires [`../subscriptions-and-management-groups/`](../subscriptions-and-management-groups/),
> [`../azure-policy/`](../azure-policy/) and [`../azure-rbac/`](../azure-rbac/).

---

## 1. ⭐ What it actually is

**A landing zone is not a product and not a diagram. It is the answer to one question:**

> ⭐ **"When a team asks for a subscription on Monday, what do they get — and what can they not do?"**

```
WITHOUT             a subscription, an Owner, and good luck
                    ⭐ every guardrail is a conversation nobody has

WITH                a subscription, PARENTED into a governed management group,
                    inheriting policy, RBAC, networking, logging and budget
                    ⭐ before anyone logs in
```

⭐ **The value is that governance arrives by default rather than by discipline** — and the failure the
whole concept exists to prevent is the ungoverned subscription from
[`../subscriptions-and-management-groups/`](../subscriptions-and-management-groups/) §4.

---

## 2. The two halves

```
PLATFORM landing zones           shared, run by the platform team
  ├─ identity      Entra, PIM, break-glass
  ├─ management    Log Analytics, ⭐ the one place logs land
  └─ connectivity  hub VNet, firewall, ⭐ Private DNS Zones, ExpressRoute

APPLICATION landing zones        one per workload/team
  └─ ⭐ a subscription, pre-wired: peered, policy-bound, logging on, budget set
```

⭐ **The split matters because it decides who is accountable for what.** A team that owns an
application landing zone owns its workload; **it does not own the firewall, the DNS zones or the log
workspace** — and it cannot weaken them, because those are enforced above it.

⭐ **The Private DNS Zone placement is the most commonly botched part**, and it is why
[`../../60-ai-and-secure-ai/private-ai-networking/`](../../60-ai-and-secure-ai/private-ai-networking/)
§3 keeps finding unlinked zones: **the zones belong to the platform, centrally, with a
`DeployIfNotExists` policy creating the links** — not to each application team, hoping they remember.

---

## 3. ⭐ The hierarchy is the design

```
Tenant Root
 └─ mg-org
     ├─ mg-platform        ⭐ the shared services, tightest policy
     │   ├─ identity  │ management  │ connectivity
     ├─ mg-landingzones
     │   ├─ mg-corp        ⭐ NO public endpoints — enforced, not requested
     │   └─ mg-online      public-facing, different policy set
     ├─ mg-sandbox         ⭐ permissive BUT ringfenced: no peering, hard budget
     └─ mg-decommissioned  ⭐ read-only, awaiting deletion
```

⭐ **`mg-corp` versus `mg-online` is the design decision that earns its keep.** "No public endpoints"
becomes a **policy assigned once at `mg-corp`**, inherited by every current and future subscription
beneath it. **Nobody has to remember, and no Owner can opt out** —
[`../azure-rbac/`](../azure-rbac/) §2.

⭐ **`mg-sandbox` is the one people leave out, and its absence causes the ungoverned subscription.**
People need somewhere to experiment; if the only options are "production rules" or "nothing", they
choose nothing and create a subscription outside the hierarchy. ⭐ **Give them a permissive place that
is ringfenced — no peering to the hub, a hard budget, short lifetime — and the shadow subscription
stops being necessary.** Designing for the pressure rather than against it is the senior move, and it
is the same reasoning as offering a sanctioned AI tool instead of banning AI
([`../../60-ai-and-secure-ai/ai-governance/`](../../60-ai-and-secure-ai/ai-governance/) §4).

---

## 4. Worked example — is this a landing zone, or a diagram?

**The test is not "do you have management groups". It is "what does a new subscription inherit?"**

```powershell
# ① Create (or pick) a subscription and ask what it ALREADY has, before anyone touches it
$sub = "/subscriptions/<newSubId>"

"--- policies inherited ---"
az policy assignment list --scope $sub --disable-scope-strict-match `
  --query "[].{Name:displayName, Effect:parameters.effect.value, Scope:scope}" -o table

"--- role assignments inherited ---"
az role assignment list --scope $sub --include-inherited `
  --query "[].{Principal:principalName, Role:roleDefinitionName, Scope:scope}" -o table

"--- is logging wired? ---"
az monitor diagnostic-settings subscription list `
  --query "value[].{Name:name, Workspace:workspaceId}" -o table

"--- is there a budget? ---"
az consumption budget list --query "[].{Name:name, Amount:amount}" -o table
```

```
--- policies inherited ---
Name                              Effect  Scope
--------------------------------  ------  --------------------------
Deny public network access        Deny    /…/managementGroups/mg-corp     ✅
Deploy diagnostic settings        DINE    /…/managementGroups/mg-org      ✅
Require Owner tag                 Modify  /…/managementGroups/mg-org      ✅

--- is there a budget? ---
(empty)                                                                   <-- ⚠⚠
```

⭐ **Empty rows are the report.** A landing zone that delivers policy but no budget has no containment
against the cost-shaped incidents in
[`../budgets-and-cost-controls/`](../budgets-and-cost-controls/) — and no signal when something starts
mining.

**The harder question, and the one that separates real from aspirational:**

```powershell
# ⭐ ② Which subscriptions are NOT under a governed management group?
#    (from ../subscriptions-and-management-groups/ §4 — the landing zone's own failure metric)
```

⭐ **The number of ungoverned subscriptions *is* the landing zone's score.** Not the number of
policies written. **If teams keep creating subscriptions outside it, the landing zone is not
governance — it is documentation**, and the reason is almost always that the paved road is slower
than going around it.

---

## 5. Subscription vending

⭐ **The mechanism that makes it real: a request process that produces a governed subscription
automatically.**

```
request (form / PR)
   → create subscription
   → ⭐ PARENT into the right management group      ← the single load-bearing step
   → assign RBAC to the team's GROUP (not people)
   → peer to hub, link Private DNS Zones
   → wire diagnostic settings to the platform workspace
   → set a budget with alerts
   → hand over
```

⭐ **Parenting is the load-bearing step**, because everything else is inheritance. Get that wrong and
the subscription is a `mg-sandbox` workload sitting in `mg-corp`, or worse, at root.

⚠ **Make the paved road faster than the alternative.** ⭐ If vending takes three weeks and a credit
card takes three minutes, you will keep finding ungoverned subscriptions no matter what the policy
document says. **That is a process finding, not a technical one, and it is usually the real answer to
§4 ②.**

---

## 6. What breaks

**A diagram with no enforcement.** §4 — ⭐ measure what a new subscription inherits.

**No `mg-sandbox`.** §3 — ⭐ people create ungoverned subscriptions instead.

**Subscriptions parented at root.** §5 — inherits nothing.

**Private DNS Zones owned by app teams.** §2 — unlinked zones, silent public resolution.

**Policy assigned per subscription** rather than at the management group — guaranteed drift.

**No budget in the vended subscription.** §4 — no cost containment or signal.

**RBAC assigned to people, not groups.** Unreviewable, and there is a ceiling.

**Vending slower than a credit card.** §5 — ⭐ the real cause of shadow subscriptions.

**No decommission path.** §3 — `mg-decommissioned` exists for a reason.

**Treating "we deployed the accelerator" as done.** ⭐ The accelerator is a starting point, not a
posture.

---

## 7. Customer discovery questions

1. ⭐ **What does a brand-new subscription inherit before anyone logs in?** *(§4 — run it.)*
2. How many subscriptions are **outside** the governed hierarchy? *(§4 ② — the score.)*
3. Is there a **sandbox** management group, and is it ringfenced? *(§3.)*
4. How long does **subscription vending** take versus a credit card? *(§5.)*
5. Who owns **Private DNS Zones** — the platform or each team? *(§2.)*
6. Are policies assigned at **management group** or repeated per subscription?
7. Does a vended subscription arrive with **logging and a budget**?
8. What is the **decommission** path?
9. Which controls are enforced, and which are ⭐ **documented and hoped for**?

---

## 8. Remember it

**Hook — "What does a new subscription inherit before anyone logs in?"**

**Analogy — a serviced office versus an empty warehouse.** ⭐ **A landing zone is a serviced office:
you get a desk, a locked door, wired internet, the fire alarm already tested, and a badge system you
cannot switch off.** The alternative is an empty warehouse with a set of keys and an encouraging
email about safety standards. ⭐ **And notice the crucial detail — if the serviced office takes three
weeks to move into and the warehouse is available today, everyone ends up in the warehouse**, which
is precisely why shadow subscriptions exist.

**The one thing:** ⭐ **the count of subscriptions outside the governed hierarchy is the landing
zone's score.** Not policies written, not accelerators deployed, not diagrams drawn. If that number is
not near zero, the landing zone is documentation — and the fix is almost always **making the paved
road faster than going around it**, which is a process change rather than a technical one. ⭐ **Design
for the pressure people are actually under**, which is also why `mg-sandbox` must exist.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. State what a landing zone is in terms of one question.
2. Name the two halves and who is accountable for each.
3. ⭐ Who should own Private DNS Zones, and what goes wrong otherwise?
4. Why do `mg-corp` and `mg-online` exist separately?
5. ⭐ Why is `mg-sandbox` necessary, and what happens without it?
6. What is the real test of whether a landing zone exists?
7. ⭐ What is the landing zone's score?
8. Which step in vending is load-bearing, and why?
9. Why is vending speed a security concern?
10. Why is "we deployed the accelerator" not an answer?

<details>
<summary>Answers</summary>

1. ⭐ **"When a team asks for a subscription on Monday, what do they get and what can they not do?"**
2. **Platform** (identity, management, connectivity) — the platform team; **application** landing
   zones — the workload team, which ⭐ **cannot weaken what is enforced above it**.
3. ⭐ **The platform, centrally**, with `DeployIfNotExists` creating links. Otherwise zones go
   unlinked and resources ⭐ **resolve publicly while the portal shows "private endpoint: connected"**.
4. So **"no public endpoints"** can be a policy assigned once at `mg-corp` and inherited by every
   current and future subscription beneath it, with no opt-out.
5. ⭐ People need somewhere to experiment; without a **ringfenced permissive** option they create
   **ungoverned subscriptions** outside the hierarchy.
6. ⭐ **What a brand-new subscription inherits before anyone logs in** — policies, RBAC, logging,
   budget.
7. ⭐ **The number of subscriptions outside the governed hierarchy.**
8. ⭐ **Parenting into the correct management group** — everything else is inheritance.
9. ⭐ If vending is slower than a credit card, teams go around it, and you get ungoverned
   subscriptions regardless of policy.
10. ⭐ The accelerator is a **starting point, not a posture** — the measurable questions in §4 are what
    determine whether governance is real.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — run the §4 "what does this inherit" sweep against a subscription. ✗ Requires an
  Azure subscription.
- **`break-fix/`** ⭐ — create a subscription **parented at root**, show it inherits nothing, then move
  it under `mg-corp` and show the policies, logging and budget appear with no other change.
  **The move-and-re-run is the demonstration that makes inheritance concrete.**
- **`security/`** — ungoverned subscription list (⭐ the score); enforced-vs-documented control matrix;
  Private DNS Zone ownership; management group policy assignment inventory.
- **`operations/`** — subscription vending runbook with a measured **time-to-deliver** against the
  credit-card alternative; decommission path into `mg-decommissioned`.
- **`architecture-decisions/`** — ADR: management group hierarchy with `mg-sandbox` ringfenced;
  platform owns DNS, firewall and the log workspace; policy assigned at MG scope only.
- **`customer-use-cases/`** — §7 answered; "what a new subscription inherits" as a one-page assessment.
