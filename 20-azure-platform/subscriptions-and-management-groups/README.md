# Subscriptions and Management Groups

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The tree everything else in this domain hangs off.** Read before
> [`../azure-rbac/`](../azure-rbac/) and [`../azure-policy/`](../azure-policy/) — both are
> "what applies at which level".

---

## 1. The hierarchy

```
Entra TENANT                        ⭐ the identity boundary — one per organisation
 └─ Tenant Root Management Group    ⭐ every subscription is under it, always
     └─ Management Groups           up to 6 levels deep (excluding root)
         └─ SUBSCRIPTION            ⭐ billing + quota + the practical blast radius
             └─ Resource Group      lifecycle + the usual RBAC target
                 └─ Resource
```

⭐ **Inheritance flows down and only down.** An assignment at a management group applies to every
subscription beneath it, forever, including subscriptions created afterwards. **There is no way to
"un-inherit"** — that is the whole reason the root management group is dangerous (§3).

**Each level exists for a different reason, and confusing them is the design error:**

| Level | Exists for | ⭐ Is it a security boundary? |
|---|---|---|
| **Tenant** | identity | ⭐ **Yes — the strongest one** |
| **Management group** | ⭐ governance at scale | Policy/RBAC scope, not isolation |
| **Subscription** | billing, quota, limits | ⭐ **In practice, yes — the blast-radius unit** |
| **Resource group** | lifecycle (delete together) | RBAC target, ⚠ not isolation |
| **Resource** | the thing | — |

---

## 2. ⭐ The subscription is the blast-radius unit

**People choose subscription boundaries on billing grounds and inherit a security consequence.**

⭐ **A subscription is the natural unit of separation because it is where quota, policy, RBAC and
"delete everything" all converge.** Two workloads in one subscription share:

```
⭐ Owners            an Owner of the sub owns BOTH workloads
⭐ quota / limits    one can exhaust the other's capacity
   policy posture   one policy set applies to both
   cost signal      an anomaly in one is diluted by the other
```

⭐ **So "separate subscriptions" is a security answer, not a finance one** — and it is the cheapest
isolation in Azure. When someone asks how to separate prod from non-prod properly, the answer starts
here, not with NSGs.

⚠ **A resource group is not isolation.** It is a lifecycle grouping with an RBAC scope attached.
Anyone with rights at subscription scope has them in every RG beneath it, and **an RG cannot contain a
subscription-scoped Owner.**

---

## 3. ⭐ The root management group is the finding

> **The tenant root management group is the ancestor of every subscription — including ones that do
> not exist yet.**

⭐ **An Owner assignment there is an Owner assignment on the entire Azure estate, in perpetuity.** And
it is invisible from any individual resource's Access Control blade unless you tick *inherited*.

**Two behaviours worth knowing precisely:**

| Behaviour | ⭐ Consequence |
|---|---|
| A **Global Administrator** can self-elevate to **User Access Administrator at root scope** | ⭐ The identity plane can reach the resource plane — one toggle |
| Root MG assignments apply to **future** subscriptions | ⭐ You cannot fix this by auditing today's subscriptions |

⭐ **That first row is the single most important sentence connecting
[`../../30-identity-and-nhi/`](../../30-identity-and-nhi/) to this domain.** Global Administrator is
not "just" an Entra role — via *Access management for Azure resources*, it becomes root over Azure
too. **So the tenant's Global Admin count is an Azure finding, not only an identity one.**

```bash
# ① Who holds anything at the ROOT management group? (the broadest scope that exists)
az role assignment list --scope "/providers/Microsoft.Management/managementGroups/<tenantId>" \
  --query "[].{Principal:principalName, Type:principalType, Role:roleDefinitionName}" -o table
```

```
Principal              Type              Role
---------------------  ----------------  --------------------------
sg-azure-platform      Group             Owner                        <-- ⚠⚠⚠ the entire estate
svc-terraform-prod     ServicePrincipal  Contributor                  <-- ⚠⚠ every subscription
```

⭐ **Row two is the more interesting one.** A CI service principal with Contributor at root scope can
create, modify and delete in **every subscription in the tenant, including ones created next year** —
and it authenticates with a secret in a pipeline. Cross-reference
[`../../00-foundations/git-and-github/`](../../00-foundations/git-and-github/) §4.

---

## 4. Worked example — map the estate before judging it

```bash
# The tree, as it actually is
az account management-group list --query "[].{Name:displayName, Id:name}" -o table
az account list --all --query "[].{Name:name, Id:id, State:state, Tenant:tenantId}" -o table
```

```powershell
# ⭐ Every assignment, everywhere, broadest first - the pattern from
#    ../../00-foundations/cli-and-scripting/ §2
$rows = az role assignment list --all --include-inherited --include-groups `
  --query "[].{Principal:principalName, Type:principalType, Role:roleDefinitionName, Scope:scope}" `
  -o json | ConvertFrom-Json

$rows | Where-Object { $_.Role -in 'Owner','Contributor','User Access Administrator' } |
  Sort-Object { $_.Scope.Length } |
  Select-Object -First 20 |
  Format-Table -AutoSize
```

⭐ **Sorting by scope length puts management-group assignments above subscription assignments above
resource ones — which is exactly severity order.** The first rows are the report.

**Then the question almost nobody asks:**

```bash
# ⭐ Are there subscriptions NOT under a governed management group?
az account list --all --query "[].{Name:name, Id:id}" -o json | ConvertFrom-Json | ForEach-Object {
  $mg = az account management-group entity list `
        --query "[?name=='$($_.Id)'].parent.displayName" -o tsv 2>$null
  [pscustomobject]@{ Subscription = $_.Name; Parent = ($mg ?? 'ROOT - ungoverned') }
}
```

```
Subscription        Parent
------------------  ---------------------
sub-prod-platform   mg-prod
sub-datasci-poc     ROOT - ungoverned      <-- ⚠⚠ inherits nothing
```

⭐ **A subscription sitting directly under root inherits only root's policies — which is usually
none.** It is outside every guardrail the organisation built, and **it is the subscription somebody
created with a credit card to try something.** This is the Azure equivalent of shadow IT, and it is
where the unmanaged AI resources from
[`../../60-ai-and-secure-ai/azure-ai-services/`](../../60-ai-and-secure-ai/azure-ai-services/) live.

---

## 5. Limits are a security topic

**Subscription limits are usually treated as capacity planning. They are also containment:**

| Limit | ⭐ Security reading |
|---|---|
| vCPU quota per region | ⭐ Caps a crypto-mining incident at the quota, not the credit card |
| Resource group count | — |
| Role assignments per subscription | ⚠ Sprawl hits a ceiling and deployments start failing mysteriously |
| ⭐ Public IP quota | Caps how much can be exposed at once |

⭐ **A quota is a blast-radius control**, exactly as it is for AI in
[`../../60-ai-and-secure-ai/model-access-control/`](../../60-ai-and-secure-ai/model-access-control/)
§4. **Requesting a large quota "just in case" removes a containment control that costs nothing.**

⚠ The role-assignment ceiling is a real operational trap: an estate that assigns roles per user rather
than per group hits it, and the failure looks like a broken deployment rather than a governance
problem.

---

## 6. What breaks

**Owner at the root management group.** §3 — ⭐ the whole estate, including future subscriptions.

**A service principal with Contributor at root.** §3 — CI owns everything.

**Forgetting Global Admin can self-elevate.** §3 — ⭐ the identity plane reaches the resource plane.

**Subscriptions parented directly to root.** §4 — inherits no guardrails.

**Treating a resource group as isolation.** §1 — it is a lifecycle grouping.

**Choosing subscription boundaries purely on billing.** §2 — you are choosing blast radius.

**Auditing without `--include-inherited`.** ⭐ The dangerous assignments are the inherited ones.

**Requesting oversized quota by default.** §5 — discards free containment.

**Assuming a management group isolates.** It scopes policy and RBAC; it does not isolate.

---

## 7. Customer discovery questions

1. Who holds anything at the **tenant root management group**? *(§3 — run it live.)*
2. Are any **subscriptions parented directly to root**? *(§4.)*
3. How many **Global Administrators** are there, and do they know about ⭐ **Azure resource
   elevation**?
4. Are subscription boundaries drawn on **billing** or **blast radius**? *(§2.)*
5. Do any **service principals** hold rights at management-group scope?
6. Are role assignments made to **groups** or to individual users? *(§5 — the ceiling.)*
7. What is the **quota** posture — requested deliberately, or maximised by habit?
8. If a subscription were fully compromised, **what else would be affected?**

---

## 8. Remember it

**Hook — "Inheritance flows down, and there is no un-inherit."**

**Analogy — a company org chart where every instruction is permanent.** ⭐ **A rule written at the
top of the chart applies to every team below it, including teams that will be founded next year, and
nobody below can opt out.** That is enormously powerful for governance and enormously dangerous for
access: **"Owner at the root" is not a job title, it is a standing instruction that everyone who ever
joins must obey you.** And the subscription is the department — ⭐ **when something goes wrong, the
department is what burns**, which is why you draw those lines for containment rather than for
accounting.

**The one thing:** ⭐ **a Global Administrator can toggle "Access management for Azure resources" and
become User Access Administrator at the tenant root — over every subscription, present and future.**
The identity plane and the resource plane are not separate estates; there is a documented door
between them and it opens from the identity side. **So the Global Admin count in
[`../../30-identity-and-nhi/pim-and-access-reviews/`](../../30-identity-and-nhi/pim-and-access-reviews/)
is an Azure platform finding**, and anyone auditing Azure RBAC without asking about Entra roles has
audited half the problem.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Draw the hierarchy from tenant to resource.
2. Which direction does inheritance flow, and can it be blocked?
3. Which level is the practical blast-radius unit, and why?
4. Is a resource group a security boundary?
5. ⭐ Why is an Owner assignment at the root management group worse than at a subscription?
6. ⭐ How can a Global Administrator obtain rights over all Azure resources?
7. What is wrong with a subscription parented directly to root?
8. Why does `--include-inherited` matter in an audit?
9. Give two security readings of subscription quotas.
10. What operational failure does per-user role assignment eventually cause?

<details>
<summary>Answers</summary>

1. **Entra tenant → tenant root management group → management groups → subscription → resource group
   → resource.**
2. ⭐ **Down only, and it cannot be blocked** — there is no un-inherit.
3. ⭐ **The subscription** — quota, policy, RBAC and "delete everything" all converge there.
4. ⚠ **No** — it is a lifecycle grouping with an RBAC scope; subscription-scoped rights reach into it.
5. ⭐ It applies to **every subscription, including ones created in future**, so auditing today's
   subscriptions cannot find or fix it.
6. ⭐ By enabling **"Access management for Azure resources"**, which grants **User Access
   Administrator at the tenant root scope**.
7. ⭐ It inherits **only root's policies — usually none**, so it sits outside every guardrail.
8. ⭐ Because **the dangerous assignments are the inherited ones**; without it they are invisible.
9. ⭐ It **caps a crypto-mining incident** at the quota rather than the credit card, and **limits how
   much can be publicly exposed at once**.
10. ⚠ Hitting the **role-assignment ceiling**, which presents as a mysteriously failing deployment.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — the §4 estate map and root-scope assignment query. ✗ Requires an Azure subscription
  — **but the §3 Global Admin / elevation question is answerable in Entra alone, today.**
- **`break-fix/`** ⭐ — assign a role at a management group, show it appearing on a resource three
  levels down **only when `--include-inherited` is used**, then create a new subscription under that
  MG and show the assignment already applies to it. **The "future subscriptions" demonstration is the
  one that lands.**
- **`security/`** — root and MG-scope assignment register; ungoverned subscription list; Global
  Administrator count with elevation status; service principals holding MG scope.
- **`operations/`** — subscription vending process that parents new subs into a governed MG by
  default; quota requested deliberately with justification.
- **`architecture-decisions/`** — ADR: subscription boundaries drawn on blast radius; no standing
  Owner above subscription scope.
- **`customer-use-cases/`** — §7 answered against a real tenant; the estate map as a one-page
  deliverable.
