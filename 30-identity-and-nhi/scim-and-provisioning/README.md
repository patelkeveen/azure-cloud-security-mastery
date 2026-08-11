# SCIM and Provisioning

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Licensing verified against Microsoft Learn **2026-08-10**.
> Pairs with [`../lifecycle-workflows/`](../lifecycle-workflows/) and
> [`../entra-users-and-groups/`](../entra-users-and-groups/).

---

## 1. What it is

Automatically creating, updating and **deactivating** user accounts in a target system from Entra ID
— using **SCIM** (System for Cross-domain Identity Management), a REST/JSON standard.

```
SOURCE            →   ENTRA ID   →   TARGET
HR system / AD        the hub        Salesforce, ServiceNow, AWS, Zoom, on-prem AD
```

⭐ **Provisioning is about the account existing. Federation is about the sign-in.** They are
independent, and an application usually needs **both** — SSO gets you in the door, provisioning
means there is a desk with your name on it.

---

## 2. Why it exists — and the security case

Without it, every SaaS application has its own joiner–leaver process, performed by hand, by whoever
owns that app.

> ⭐ **The leaver path is the security case.** SSO revocation stops someone signing in *through*
> Entra — it does not remove a **local account** in the SaaS app, and many applications also permit
> direct sign-in with a local password. **Deprovisioning is what actually closes that door.**

That is the sentence to have ready: *"disabling their Entra account does not delete their Salesforce
user — unless provisioning is wired up."*

---

## 3. How it works underneath

Entra runs a scheduled provisioning job against the target's SCIM endpoint:

```
1. INITIAL CYCLE    ⚠ full sweep of everyone in scope — can take HOURS
2. INCREMENTAL      every ~40 minutes thereafter, changes only
3. MATCH            existing target users matched on a MATCHING ATTRIBUTE
4. MAP              attribute mappings, with expressions if needed
5. SCOPE            assigned users/groups, or a scoping filter
```

⭐ **The matching attribute is the highest-risk setting on the page.** It decides whether Entra
*claims* an existing account or *creates a duplicate*. Default is usually `userPrincipalName` →
`userName`, and if the target's existing accounts use a different identifier, you get a full set of
duplicates on first run.

**Two behaviours worth knowing before the first run:**

- ⚠ **The initial cycle processes everyone in scope, not just changes.** On a large tenant it is
  hours, and it is where quota and rate-limit failures surface.
- ⭐ **Deprovisioning is usually *soft*** — most connectors **disable** rather than delete, because
  deletion is unrecoverable and target-specific. **Confirm which the connector does** before
  claiming an offboarding control works.

---

## 4. Worked example — scope it, then read what actually happened

```powershell
Connect-MgGraph -Scopes 'Application.ReadWrite.All','Synchronization.ReadWrite.All'

# Which apps are provisioning, and are the jobs healthy?
Get-MgServicePrincipal -All -Filter "tags/any(t:t eq 'WindowsAzureActiveDirectoryIntegratedApp')" |
  ForEach-Object {
    $jobs = Get-MgServicePrincipalSynchronizationJob -ServicePrincipalId $_.Id -ErrorAction SilentlyContinue
    foreach ($j in $jobs) {
      [pscustomobject]@{
        App        = $_.DisplayName
        Status     = $j.Status.Code
        LastRun    = $j.Status.LastSuccessfulExecution.TimeEnded
        Quarantine = $j.Status.Quarantine.Reason
      }
    }
  } | Sort-Object Status
```

```
App                Status      LastRun               Quarantine
-----------------  ----------  --------------------  ----------------------------
ServiceNow         Active      2026-08-10 08:41:02
Salesforce         Quarantine  2026-07-02 14:12:55   EncounteredQuarantineException   <-- ⚠⚠
Zoom               Active      2026-08-10 08:39:17
```

⭐ **`Quarantine` is the finding, and it is silent.** After repeated failures Entra quarantines the
job and **stops trying** — with escalating retry intervals, eventually up to daily. Salesforce has
not provisioned since **2 July**. Every leaver since then still has an active account there, and
nothing alerted anyone.

> ⭐ **"Provisioning is configured" and "provisioning is running" are different claims.** This one
> query separates them, and quarantined jobs are extremely common in real tenants.

**Test one user before trusting the whole job** — provision on demand:

```powershell
# Portal: Enterprise app → Provisioning → Provision on demand
# Returns a per-step trace: matched? in scope? which attributes exported?
```

⭐ **On-demand provisioning shows the attribute-by-attribute result for a single user** — it is the
fastest way to prove a scoping filter or mapping is wrong, without waiting 40 minutes.

**Then read the provisioning logs:**

```kusto
AADProvisioningLogs
| where TimeGenerated > ago(7d)
| where ResultType != "Success"
| summarize Failures = count(), Reasons = make_set(ResultSignature, 5)
        by ServicePrincipalName = tostring(ServicePrincipal.DisplayName)
| sort by Failures desc
```

---

## 5. The provisioning directions ✅

| Direction | Example | Licence |
|---|---|---|
| **Outbound to SaaS** (users) | Entra → Salesforce | ✅ Free |
| Outbound to SaaS (**groups**) | Entra → Slack groups | **P1** |
| **Inbound HR-driven** | Workday/SuccessFactors → Entra | **P1** |
| **API-driven inbound** | Any HR system via `/bulkUpload` | **P1** |
| **On-premises app provisioning** | Entra → LDAP / SQL app | **P1** |
| **Cross-tenant sync** (users) | Tenant A → Tenant B | **P1** |
| Cross-tenant sync (**groups**), cross-cloud | | ⭐ **ID Governance** |
| **Account Discovery** | Find orphan accounts in targets | ⭐ **ID Governance** |

⭐ **HR-driven inbound provisioning is the one that makes lifecycle work**, because it populates
`employeeHireDate` and `employeeLeaveDateTime` — without which
[`../lifecycle-workflows/`](../lifecycle-workflows/) silently does nothing.

⚠ **Account Discovery** (ID Governance) finds **orphan accounts** in target applications that have
no matching Entra user — the accounts provisioning never knew about. That is a genuine assessment
deliverable.

---

## 6. What breaks

**Quarantined jobs nobody noticed.** §4 — the most common real finding.

**Wrong matching attribute.** Duplicate accounts across the entire target on first run.

**Assuming deprovisioning deletes.** Most connectors **disable**. Confirm.

**Assuming SSO revocation removes SaaS access.** §2 — it does not.

**No scoping filter**, so every user is provisioned into a per-seat-licensed application.

**Not testing with on-demand provisioning** before enabling the job.

**Expecting the initial cycle to be quick.**

**Custom SCIM endpoint not conforming to the spec** — subtle failures in filtering and PATCH
semantics are the usual cause.

**Attribute mappings that overwrite target-managed fields**, causing a change war between systems.

---

## 7. Customer discovery questions

1. Which applications have provisioning configured, and **are any jobs quarantined**? *(§4.)*
2. When a user leaves, which SaaS accounts are actually **deprovisioned** — and disabled or deleted?
3. What is the **matching attribute** per connector, and was it verified against existing accounts?
4. Is provisioning **scoped**, or does everyone get a seat?
5. Is **HR-driven inbound** provisioning in place? Are lifecycle attributes populated?
6. Are **provisioning logs** monitored, or checked only when someone complains?
7. Any applications where users can sign in **locally**, bypassing SSO?
8. Has anyone looked for **orphan accounts** in the targets?

---

## 8. Remember it

**Hook — "SSO is the door. Provisioning is the desk."** Federation lets you in; provisioning means
there is an account waiting — and, more importantly, that it is removed when you leave.

**Analogy — a building pass versus the staff list.** Revoking the **pass** (SSO) stops someone
entering through the front door. **It does nothing about their name still being on the staff list**
in a system that also has its own side entrance. **Deprovisioning removes the name.** Organisations
that revoke passes and never update lists are exactly the ones that discover an ex-employee still
had Salesforce eighteen months later.

**The one thing:** ⭐ **check for quarantined jobs.** After repeated failures Entra **stops trying**,
silently, with retries stretching to daily. "Provisioning is configured" and "provisioning has run
this month" are different claims — and the second one is the one that matters for every leaver since
it broke.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Provisioning versus federation — what does each do?
2. Why doesn't disabling an Entra account remove a SaaS account?
3. What is the highest-risk setting when configuring a connector, and what goes wrong?
4. What does `Status: Quarantine` mean, and why is it dangerous?
5. Do connectors typically delete or disable on deprovisioning?
6. Which capability lets you test a single user before enabling the job?
7. Which provisioning direction populates lifecycle attributes, and why does that matter?
8. What is Account Discovery for, and which licence?
9. Why is the initial cycle slow?

<details>
<summary>Answers</summary>

1. **Provisioning** creates/updates/deactivates the **account**; **federation** handles the
   **sign-in**. Independent, and usually both are needed.
2. Because the SaaS **local account still exists**, and many apps allow direct sign-in bypassing SSO.
3. **The matching attribute.** Mismatched, it creates **duplicates across the entire target**.
4. Entra has **stopped retrying** after repeated failures. It is silent, and every change since then
   — including leavers — is unprocessed.
5. **Disable**, usually. Confirm per connector before claiming offboarding works.
6. **Provision on demand** — a per-step, attribute-by-attribute trace for one user.
7. **HR-driven inbound** — it populates `employeeHireDate` / `employeeLeaveDateTime`, without which
   Lifecycle Workflows silently do nothing.
8. Finding **orphan accounts** in target applications with no matching Entra user. **ID Governance.**
9. It is a **full sweep of everyone in scope**, not just changes.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — configure provisioning to a test SaaS app; use **provision on demand** and capture the
  per-attribute trace; disable a user and prove the target account is deactivated.
- **`break-fix/`** ⭐ — set a **wrong matching attribute** in a lab and produce duplicate accounts;
  then force a job into **quarantine** and demonstrate that nothing alerts.
- **`security/`** — the §4 quarantine report; leaver test end to end per application; local sign-in
  paths that bypass SSO; orphan account discovery.
- **`operations/`** — provisioning log monitoring with alerting on quarantine; matching attribute
  documented per connector.
- **`architecture-decisions/`** — ADR: authoritative source per attribute, and the deprovisioning
  standard (disable versus delete) per application.
- **`customer-use-cases/`** — §7 answered against a real tenant.
