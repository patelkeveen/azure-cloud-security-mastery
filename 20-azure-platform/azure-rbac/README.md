# Azure RBAC

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> Scoped by the tree in
> [`../subscriptions-and-management-groups/`](../subscriptions-and-management-groups/).
> ⭐ **Read alongside [`../azure-policy/`](../azure-policy/) — they are opposite algebras** (§2).

---

## 1. The three parts, and the one that decides everything

```
ROLE ASSIGNMENT  =  WHO (principal)  +  WHAT (role definition)  +  ⭐ WHERE (scope)
```

⭐ **Scope is the part people under-weight and it is where the severity lives.** The same role at two
scopes is two completely different grants:

```
Contributor  @  /subscriptions/xxx/resourceGroups/rg-test        one resource group
Contributor  @  /subscriptions/xxx                                ⭐ everything in the subscription
Contributor  @  /providers/…/managementGroups/root                ⭐⭐ the entire estate, forever
```

⭐ **Which is why every audit in this repository sorts by scope length.** Shortest string = broadest
scope = read it first —
[`../../00-foundations/cli-and-scripting/`](../../00-foundations/cli-and-scripting/) §2.

---

## 2. ⭐ RBAC is additive. Policy is restrictive.

> **RBAC computes a UNION: a principal's effective permissions are every `Action` from every
> assignment at every scope above the resource.**
>
> ⭐ **Policy computes an INTERSECTION: every policy in scope must allow, or the request fails.**

| | Azure RBAC | Azure Policy |
|---|---|---|
| Question | ⭐ **"May this *principal* do this?"** | ⭐ **"May this *resource* exist like that?"** |
| Algebra | **union** — more assignments = more rights | **intersection** — more policies = fewer options |
| Default | deny (no assignment = no access) | allow (no policy = anything) |
| Can an **Owner** override it? | they *are* the override | ⭐ **No — Owner cannot violate Policy** |

⭐ **That last row is the most useful sentence in this domain.** It is why **Policy is the guardrail
and RBAC is not**: you cannot RBAC your way out of a policy, but you can always find someone with
Owner. Any control that must hold *even against your own administrators* belongs in Policy.

⭐ **And the additive rule kills the most common misconception:** removing someone from one group
does not reduce their access if another assignment still grants it. **There is no "most specific
wins" in RBAC** — that is a firewall/routing intuition
([`../../10-networking/routing-and-bgp/`](../../10-networking/routing-and-bgp/)) that does not
transfer.

**The single exception:**

> ⭐ **Deny assignments win over everything, including Owner** — but you cannot create them directly.
> They come from **Azure Blueprints** and **managed applications**, which is why a resource can be
> undeletable by an Owner with no lock in sight.

---

## 3. ⭐ The escalation path nobody audits

**Three roles look similar in a list and are not:**

| Role | Can manage resources? | ⭐ Can grant access? |
|---|---|---|
| **Reader** | no | no |
| **Contributor** | ⭐ yes | ⭐ **no** — deliberately |
| **User Access Administrator** | ⭐ **no** | ⭐ **yes** |
| **Owner** | yes | yes |

⭐ **User Access Administrator is Owner with one extra step**, and it reads as harmless because it
cannot touch resources. **It can assign itself Owner.** Anyone holding UAA at a scope effectively
holds Owner at that scope, and the audit that flags Owners while ignoring UAA has missed half the
finding.

⭐ **Contributor deliberately cannot grant access** — that separation is the entire point of the role,
and it is the single most useful thing to know when someone asks "why can't my Contributor add a role
assignment?" **The answer is: by design, and do not fix it by making them Owner.**

⚠ **But Contributor can still escalate in practice** — by deploying a resource with a managed identity
and granting *that* identity rights it can then use, or via ARM template `Microsoft.Authorization`
deployments at a scope it controls. **Treat Contributor at subscription scope as near-Owner.**

---

## 4. Worked example — the audit that produces findings

```powershell
# ① Everything, everywhere, with inheritance and group expansion
$all = az role assignment list --all --include-inherited --include-groups `
  --query "[].{Principal:principalName, Type:principalType, Role:roleDefinitionName, Scope:scope}" `
  -o json | ConvertFrom-Json

# ② ⭐ Privileged roles, broadest scope first
$all | Where-Object Role -in 'Owner','Contributor','User Access Administrator',
                             'Role Based Access Control Administrator' |
  Sort-Object { $_.Scope.Length }, Role |
  Format-Table -AutoSize
```

```
Principal            Type              Role                        Scope
-------------------  ----------------  --------------------------  -------------------------------
sg-cloud-platform    Group             Owner                       /providers/…/managementGroups/…   <-- ⚠⚠⚠
svc-terraform        ServicePrincipal  Contributor                 /subscriptions/aaaa               <-- ⚠⚠
jdoe@contoso.com     User              User Access Administrator   /subscriptions/aaaa               <-- ⚠⚠ = Owner
app-backup           ServicePrincipal  Contributor                 /…/rg-backup                      ✅
```

⭐ **Row three is the one a normal audit misses.** UAA does not appear on an "Owners" report and is
functionally equivalent.

**Then the two questions that turn a list into a report:**

```powershell
# ③ ⭐ Assignments to USERS rather than groups - unmanageable and unreviewable
$all | Where-Object { $_.Type -eq 'User' } |
  Group-Object Principal | Sort-Object Count -Descending | Select-Object Count, Name

# ④ ⭐ Orphaned assignments - the principal no longer exists
az role assignment list --all --include-inherited `
  --query "[?principalName==null || principalName=='']" -o json | ConvertFrom-Json |
  Select-Object roleDefinitionName, scope, principalId
```

⭐ **Orphaned assignments (`principalName` empty) mean the principal was deleted but the assignment
survives.** They are usually harmless — until an object ID is reused, and until then they are noise
that hides real findings. **They are also evidence that nobody has a joiner-mover-leaver process
reaching Azure**, which is the finding worth writing up.

---

## 5. Reducing standing access

**In order of value, and each is cheap:**

| Move | ⭐ Effect |
|---|---|
| ⭐ **PIM for Azure resources** | Owner becomes **eligible**, not standing — [`../../30-identity-and-nhi/pim-and-access-reviews/`](../../30-identity-and-nhi/pim-and-access-reviews/) |
| **Assign to groups, never users** | Reviewable, and dodges the assignment ceiling |
| **Custom roles** | ⭐ Only when a built-in genuinely does not fit — they rot |
| ⭐ **ABAC conditions** | Narrow a role by resource attribute, e.g. blob container or tag |
| **Access reviews** | ⭐ Must include **service principals**, not only users |

⭐ **PIM for Azure resources is the highest-value change in this topic**, because it converts the
entire §4 report from *standing* privilege into *activatable* privilege without changing who can do
what. **The audit findings stay; their exposure window collapses from permanent to hours.**

⚠ **Custom roles are usually a mistake at first.** They must be maintained as Azure adds actions, they
are invisible to people who know the built-ins, and most requests for one are actually requests for a
narrower **scope**. ⭐ **Try scope first, then ABAC, then a custom role.**

---

## 6. What breaks

**Auditing without `--include-inherited`.** §4 — the dangerous ones are inherited.

**Ignoring User Access Administrator.** §3 — ⭐ it is Owner with one extra step.

**Expecting "most specific wins".** §2 — ⭐ RBAC is a union.

**Expecting to fix over-permission by removing one group.** §2 — another assignment may still grant.

**Treating Contributor at subscription scope as safe.** §3 — near-Owner in practice.

**Assigning to users instead of groups.** §5 — unreviewable, and there is a ceiling.

**Custom roles as a first resort.** §5 — they rot.

**Expecting RBAC to be a guardrail.** §2 — ⭐ someone always has Owner; use Policy.

**Being surprised by an undeletable resource.** §2 — a **deny assignment** from a managed application.

**Access reviews that cover users only.** Service principals are the ones that never leave.

---

## 7. Customer discovery questions

1. Who holds **Owner** *and* **User Access Administrator**, at what scopes? *(§3.)*
2. Is **PIM for Azure resources** in use, or is privilege standing? *(§5.)*
3. Are assignments made to **groups** or individuals?
4. How many **orphaned** assignments exist — and what does that say about leavers? *(§4.)*
5. Do any **service principals** hold Owner or Contributor above resource-group scope?
6. Are there **custom roles**, and can anyone explain why a built-in did not fit?
7. Which controls do you believe are enforced by RBAC that ⭐ **should be in Policy**? *(§2.)*
8. Do access reviews include **service principals**?

---

## 8. Remember it

**Hook — "RBAC adds up. Policy narrows down."** Union versus intersection.

**Analogy — keys versus building regulations.** ⭐ **RBAC is the set of keys someone carries** — give
them another key and they can open more; taking one away changes nothing if they still hold a master.
⭐ **Policy is the building code**: it does not care who you are, and **the owner of the building
cannot pour a staircase that violates it.** People try to enforce the building code by handing out
fewer keys, and it never works, because someone always has the master — **that is the entire argument
for putting real guardrails in Policy.**

**The one thing:** ⭐ **an Owner cannot violate Policy, but someone always has Owner — so any control
that must hold against your own administrators belongs in Policy, not RBAC.** This is the sentence
that decides where a control goes, and it is the most common architectural mistake in Azure
governance: teams spend months trimming role assignments to enforce something that one policy
definition would have made impossible.

**Runner-up:** ⭐ **User Access Administrator is Owner with one extra step**, and it never appears on
an Owners report.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Name the three parts of a role assignment. Which carries the severity?
2. ⭐ State the algebra of RBAC and of Policy, and the question each answers.
3. Can an Owner override Policy? What follows from the answer?
4. Does "most specific wins" apply in RBAC?
5. What is the one thing that beats an Owner, and where does it come from?
6. Why can Contributor not assign roles — and why is it still near-Owner at subscription scope?
7. ⭐ Why is User Access Administrator as severe as Owner?
8. What does an empty `principalName` on an assignment indicate, and what is the real finding?
9. What is the highest-value change for reducing standing access?
10. In what order should you try scope, ABAC and custom roles?

<details>
<summary>Answers</summary>

1. **Principal, role definition, ⭐ scope** — scope carries the severity.
2. ⭐ **RBAC is a union** answering *"may this principal do this?"*; ⭐ **Policy is an intersection**
   answering *"may this resource exist like that?"*
3. ⭐ **No.** Therefore any control that must hold against your own administrators belongs in
   **Policy**, because someone always has Owner.
4. ⭐ **No** — that is a firewall/routing intuition. RBAC accumulates.
5. ⭐ **Deny assignments** — and you cannot create them directly; they come from **Blueprints and
   managed applications**.
6. The separation is deliberate. ⚠ It is still near-Owner because it can deploy resources with
   managed identities and perform `Microsoft.Authorization` deployments at scopes it controls.
7. ⭐ **It can assign itself Owner**, and it does not appear on an Owners report.
8. The **principal was deleted** but the assignment survives. ⭐ The real finding is that **no
   joiner-mover-leaver process reaches Azure**.
9. ⭐ **PIM for Azure resources** — same people, same rights, exposure window collapses from permanent
   to hours.
10. ⭐ **Scope first, then ABAC, then a custom role** — most custom-role requests are really
    scope requests, and custom roles rot.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — the §4 four-query audit. ✗ Requires an Azure subscription.
- **`break-fix/`** ⭐ — grant **User Access Administrator** to a test principal, then use it to assign
  itself **Owner**. **Two commands, and it permanently changes how you read a role list.** Then
  enable PIM and show the same rights become activatable rather than standing.
- **`security/`** — privileged assignment register sorted shortest-scope-first, including UAA;
  user-vs-group assignment split; orphaned assignments; custom role inventory with justification.
- **`operations/`** — joiner-mover-leaver process that reaches Azure; access reviews covering service
  principals.
- **`architecture-decisions/`** — ADR: no standing Owner above subscription scope; PIM mandatory for
  privileged roles; ⭐ guardrails implemented in Policy, not RBAC, with §2 as the reasoning.
- **`customer-use-cases/`** — §7 answered; the UAA finding presented as its own item.
