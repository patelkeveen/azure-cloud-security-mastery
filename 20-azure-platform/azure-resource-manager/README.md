# Azure Resource Manager

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Everything in Azure goes through here — which is why the Activity Log is ground truth.**
> Underpins [`../azure-rbac/`](../azure-rbac/), [`../azure-policy/`](../azure-policy/),
> [`../bicep/`](../bicep/) and [`../terraform/`](../terraform/).

---

## 1. ⭐ The insight: there is only one door

**The portal, the CLI, PowerShell, Terraform, Bicep, the SDKs and the REST API are all the same
thing** — clients of the ARM endpoint.

```
portal ┐
az     ├──▶ ⭐ management.azure.com  ──▶ RBAC check ──▶ Policy check ──▶ Resource Provider
Az PS  │         (one API)                  (may I?)      (may it exist?)
tf     ┘
```

⭐ **Two consequences, and they are the whole reason this topic exists:**

1. ⭐ **The control-plane audit trail is complete.** Nobody can change a resource "outside" the log,
   because there is no other door. **The Activity Log is not a partial record — it is the record.**
2. ⭐ **RBAC and Policy are evaluated at the same choke point**, in that order, which is why an Owner
   passes the first check and still fails the second — [`../azure-policy/`](../azure-policy/) §1.

> ⭐ **The corollary is the exam-and-interview line:** *control plane* (ARM: create/delete/configure a
> storage account) is logged in the Activity Log; ⭐ ***data plane* (read a blob, call a model, open a
> secret) is not** — it needs diagnostic settings enabled per resource. **"We have the Activity Log"
> is not data-plane logging**, and it is the most common gap in an Azure logging review.

---

## 2. Providers, API versions and the thing that dates you

```
/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}
                                          └──── resource provider ────┘
```

**A resource provider must be *registered* in a subscription before you can use it** — which is why a
deployment sometimes fails in a fresh subscription with a puzzling `MissingSubscriptionRegistration`
and works everywhere else. ⭐ **That is the "delta between environments" from
[`../../00-foundations/troubleshooting-method/`](../../00-foundations/troubleshooting-method/) §3, in
Azure form.**

```bash
az provider list --query "[?registrationState!='Registered'].namespace" -o tsv
```

⭐ **API versions matter for security specifically**, because properties appear over time. A tool
pinned to an old `api-version` **cannot see `disableLocalAuth`, `allowSharedKeyAccess`, or
`publicNetworkAccess`** — so an audit written against an old version reports a clean estate because
the field it needed did not exist yet.

```bash
# What versions does this type support? ⭐ Audit with a recent one.
az provider show -n Microsoft.CognitiveServices \
  --query "resourceTypes[?resourceType=='accounts'].apiVersions[0:5]" -o tsv
```

⭐ **"The audit says everything is fine" plus "the audit is pinned to a 2019 API version" is a real
and quiet failure mode**, and it belongs on the invisible-causes list.

---

## 3. Worked example — the Activity Log as an investigation tool

**This is what "complete control-plane record" buys you.**

```bash
# ⭐ Who deleted it, when, and from where?
az monitor activity-log list --offset 7d \
  --query "[?operationName.value=='Microsoft.Storage/storageAccounts/delete'].\
    {When:eventTimestamp, Who:caller, IP:httpRequest.clientIpAddress, \
     Status:status.value, Resource:resourceId}" -o table
```

```
When                  Who                    IP             Status     Resource
--------------------  ---------------------  -------------  ---------  ------------------
2026-08-09T02:14:11Z  svc-terraform-prod     20.51.x.x      Succeeded  /…/stprodlogs
```

⭐ **`caller` is the principal and it is always populated** — because everything went through the one
door. Compare this to the AI-domain finding in
[`../../60-ai-and-secure-ai/ai-pipeline-nhi/`](../../60-ai-and-secure-ai/ai-pipeline-nhi/) §4, where
one principal accounted for all traffic: **here the identity is real, but if the caller is a shared
service principal you are back to "the pipeline did it" with no human attached.**

**The queries that actually find things:**

```kusto
// ⭐ Role assignments created - privilege changes are control-plane events
AzureActivity
| where TimeGenerated > ago(30d)
| where OperationNameValue == "MICROSOFT.AUTHORIZATION/ROLEASSIGNMENTS/WRITE"
| where ActivityStatusValue == "Success"
| project TimeGenerated, Caller, CallerIpAddress, _ResourceId
| sort by TimeGenerated desc
```

```kusto
// ⭐ Policy exemptions created - see azure-policy §3
AzureActivity
| where OperationNameValue has "POLICYEXEMPTIONS/WRITE"
| project TimeGenerated, Caller, _ResourceId
```

⭐ **"Who granted themselves access, and when" is answerable in one query**, and almost nobody has it
saved. It is the single most useful detection in this domain and it needs no product beyond what is
already on.

⚠ **Activity Log retention is 90 days by default.** ⭐ **Export it to a Log Analytics workspace or
storage account, or your investigation window is 90 days whether you like it or not.**

---

## 4. Deployments, idempotency and the history nobody reads

**ARM deployments are `PUT` operations — declarative and idempotent** (the HTTP property from
[`../../00-foundations/data-formats-and-apis/`](../../00-foundations/data-formats-and-apis/) §4).
Re-running the same template converges rather than duplicating.

**Two modes, and one is dangerous:**

| Mode | ⭐ Behaviour |
|---|---|
| **Incremental** (default) | leaves resources not in the template alone |
| ⭐ **Complete** | ⭐ **DELETES anything in the resource group not in the template** |

⭐ **Complete mode is how people delete production by deploying a correct template to the wrong
resource group.** It is a legitimate tool for enforcing desired state and it needs the same respect as
`rm -rf`.

**And the security detail almost nobody knows:**

```bash
# ⭐ Deployment history retains PARAMETER VALUES
az deployment group list -g rg-prod --query "[].{Name:name, Time:properties.timestamp}" -o table
az deployment group show -g rg-prod -n <deploymentName> --query "properties.parameters"
```

⭐ **A parameter passed in plaintext is retained in deployment history and readable by anyone with
read access to the resource group.** Marking a parameter `@secure()` (Bicep) or `securestring` (ARM)
is what keeps it out — **and it is the same lesson as git and container layers: an append-only record
does not forget.** See [`../bicep/`](../bicep/) §4.

---

## 5. Resource IDs, and why the string matters

```
/subscriptions/{sub}/resourceGroups/{rg}/providers/{ns}/{type}/{name}
└──────────────────── ⭐ this string IS the RBAC and Policy scope ────┘
```

⭐ **A resource ID is a path, and a scope is a prefix of that path.** That is the entire mechanism
behind inheritance in [`../subscriptions-and-management-groups/`](../subscriptions-and-management-groups/)
§1 — and it is why **sorting assignments by scope-string length sorts them by blast radius**
([`../azure-rbac/`](../azure-rbac/) §1). Once you see that, the technique stops being a trick and
becomes obvious.

⚠ **Moving a resource changes its ID**, which breaks role assignments scoped to it, policy
exemptions, monitoring rules, and anything holding the old string.

---

## 6. What breaks

**Assuming the Activity Log covers data-plane actions.** §1 — ⭐ it does not.

**Leaving Activity Log at default retention.** §3 — a 90-day investigation ceiling.

**Auditing with an old `api-version`.** §2 — ⭐ the security property is invisible.

**Unregistered resource providers.** §2 — a deployment that works everywhere but here.

**Complete-mode deployment to the wrong resource group.** §4 — ⭐ deletion by template.

**Secrets as plain deployment parameters.** §4 — retained in history, readable by any reader.

**No saved query for role-assignment writes.** §3 — the best detection here is free.

**Moving resources without checking what referenced the old ID.** §5.

**Believing the portal is a separate system.** §1 — it is a client like any other.

---

## 7. Customer discovery questions

1. Is the **Activity Log exported**, and what is the real retention? *(§3.)*
2. Is **data-plane logging** enabled per resource, or only the Activity Log? *(§1 — ⭐ the usual gap.)*
3. Do you have an alert or saved query on ⭐ **role assignment writes** and **policy exemption
   writes**?
4. What **API version** do your audit scripts use? *(§2.)*
5. Does any pipeline deploy in **Complete mode**, and to which scopes? *(§4.)*
6. Have you checked **deployment history for plaintext secrets**? *(§4.)*
7. Are privileged actions attributable to a **person**, or only to a shared service principal? *(§3.)*

---

## 8. Remember it

**Hook — "One door: ARM."** RBAC then Policy, then the provider.

**Analogy — a building with a single staffed entrance.** ⭐ **Every visitor signs the same book,
whichever company they are visiting** — so the entrance log is genuinely complete, and that is a rare
and valuable property. ⭐ **But the book records who came into the building, not which filing cabinets
they opened once inside.** People point at a perfect entrance log and believe they have surveillance;
they have **arrivals**. The cabinets need their own cameras, switched on per room — **that is
diagnostic settings, and it is off by default.**

**The one thing:** ⭐ **the Activity Log is the control plane only.** Creating, deleting and
configuring a resource is recorded automatically and completely; **reading a blob, calling a model,
retrieving a secret is not recorded at all unless diagnostic settings were enabled on that resource.**
"We have full audit logging in Azure" is true about half the estate's activity and false about the
half where the data lives — and it is the most common gap in an Azure logging review.

**Runner-up:** ⭐ **deployment history retains parameter values**, so a secret passed as a plain
parameter is readable by anyone with read access, forever.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. What do the portal, CLI and Terraform have in common?
2. In what order are RBAC and Policy evaluated, and why does an Owner still get blocked?
3. ⭐ What does the Activity Log cover, and what does it not?
4. What is the default Activity Log retention, and what should you do about it?
5. Why can an audit script report a clean estate incorrectly? *(§2.)*
6. What error suggests an unregistered resource provider?
7. ⭐ What does Complete mode do, and what is the comparable command elsewhere?
8. Why is a plaintext deployment parameter a finding?
9. Why does sorting by scope-string length sort by blast radius?
10. What breaks when a resource is moved?

<details>
<summary>Answers</summary>

1. ⭐ They are all **clients of the same ARM API** — there is only one door.
2. ⭐ **RBAC first ("may this principal?"), then Policy ("may it exist like that?")** — an Owner
   passes the first and can still fail the second.
3. ⭐ **Control plane only** — create/delete/configure. ⭐ **Data-plane reads are not logged** without
   per-resource diagnostic settings.
4. **90 days.** ⭐ **Export to Log Analytics or storage**, or your investigation window is capped.
5. ⭐ It is pinned to an **old `api-version`** in which the security property does not exist.
6. **`MissingSubscriptionRegistration`.**
7. ⭐ It **deletes anything in the resource group not in the template** — comparable in gravity to
   `rm -rf`.
8. ⭐ It is **retained in deployment history** and readable by anyone with read access to the group.
9. ⭐ Because a **scope is a prefix of the resource ID path** — shorter prefix, broader scope.
10. Its **resource ID changes**, breaking role assignments, policy exemptions, monitoring rules and
    anything referencing the old string.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — the §3 Activity Log queries and the §4 deployment-history inspection. ✗ Requires an
  Azure subscription.
- **`break-fix/`** ⭐ — pass a secret as a plain parameter, deploy, then **read it back out of
  deployment history as a user with only Reader**. Repeat with `@secure()` and show it absent.
  **Recovering your own "hidden" secret is what makes §4 stick.** Then run an audit with an old
  `api-version` and watch it report compliant.
- **`security/`** — Activity Log export and retention state; per-resource diagnostic settings
  coverage; saved detections for role-assignment and policy-exemption writes; deployment history
  scanned for plaintext parameters.
- **`operations/`** — API version policy for audit tooling; provider registration as part of
  subscription vending; Complete-mode usage restricted and documented.
- **`architecture-decisions/`** — ADR: data-plane logging enabled by policy (`DeployIfNotExists`),
  not left to teams.
- **`customer-use-cases/`** — §7 answered; the control-plane-versus-data-plane gap written up.
