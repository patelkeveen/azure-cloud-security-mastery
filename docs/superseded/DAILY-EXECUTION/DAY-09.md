# Day 9 — SecOps, Intune, NHI, and Automation

> Standard set by [DAY-01](DAY-01.md). `✅ verified` / `⚠ check` convention applies.
>
> **Companion depth:** [Layer 3 (CA)](../../../30-identity-and-nhi/conditional-access/LAYER-3-DOMAIN-2-AUTH-AND-ACCESS.md) ·
> [Layer 4 (workload identity)](../../../30-identity-and-nhi/service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md) ·
> [Layer 5 (governance, KQL)](../../../30-identity-and-nhi/pim-and-access-reviews/LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md)

**Outcome:** a defensible baseline — Conditional Access, PIM, an NHI register, detections, and
enough automation that the state is reproducible rather than clicked.

---

## 1. Order of operations — and the way to not lock yourself out

**Break-glass first. Always.** Before any Conditional Access policy exists.

```powershell
Connect-MgGraph -Scopes 'Policy.Read.All','Policy.ReadWrite.ConditionalAccess',
    'RoleManagement.ReadWrite.Directory','User.ReadWrite.All'
```

1. Break-glass pair — [Layer 5 §4](../../../30-identity-and-nhi/pim-and-access-reviews/LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md).
   Two accounts, cloud-only, permanent Global Admin, **not PIM-eligible**, excluded from every
   policy, alerted on.
2. **Measure legacy auth** (Day 5 KQL) before blocking it.
3. Build every policy in **report-only** first.
4. Read the report-only results in the sign-in logs for at least a day.
5. Enable one at a time.

---

## 2. Conditional Access baseline

```powershell
Get-MgIdentityConditionalAccessPolicy |
    Select-Object DisplayName,State,Id | Format-Table                 # ✅
Get-MgIdentityConditionalAccessPolicy |
    Where-Object DisplayName -like '*MFA*' | ConvertTo-Json -Depth 10  # ✅ read the real structure
```

The starting set, by persona (not by app):

| # | Policy | Note |
|---|---|---|
| 1 | **Block legacy authentication** | Highest value single policy. Basic auth cannot do MFA |
| 2 | MFA for all users | Exclude break-glass |
| 3 | **Phishing-resistant strength for admins** | Passkey/FIDO2/CBA — Layer 3 §3.3 |
| 4 | Require compliant device for admins | Needs Intune |
| 5 | Sign-in risk → MFA | P2 |
| 6 | User risk → password change | P2 |
| 7 | Block unsupported countries | Only if the business genuinely has boundaries |

> ⚠ **The trap that produces a real outage.** Selecting several grant controls defaults to
> **"Require ALL the selected controls."** You must explicitly choose *"Require one of the
> selected controls"* to get OR. Getting this backwards builds a policy far stricter than
> intended — MFA **and** compliant device **and** hybrid join simultaneously — and locks out
> anyone missing any one of them.
>
> **Lab it deliberately today.** One policy, two grant controls, observe the default; switch to
> "require one"; observe the difference. Thirty minutes that inoculate you permanently.

**Reading the result:** the sign-in log's **Conditional Access** tab shows every policy and its
outcome. *"Not applied"* is where you debug — expand it to see **which assignment** excluded the
sign-in.

---

## 3. PIM

Target state for humans: **eligible + time-bound**, never permanent active — except break-glass.

Activation settings that matter: short maximum duration; require justification; require approval
for the top roles; and **bind activation to a Conditional Access authentication context** requiring
phishing-resistant strength, so elevating to Global Admin demands a passkey rather than a push.

**That last configuration is the single most impressive control you can demo in an interview**, and
it is P2 — no add-on required.

> **Licence-expiry behaviour, which is a security finding, not trivia:** when P2/Governance lapses,
> **eligible assignments are removed entirely** while **active time-bound assignments become
> permanent**. A lapsed licence silently converts time-bound admin access into standing admin
> access. **This will happen in your lab tenant when the trial ends.**

---

## 4. The NHI register — the artifact almost nobody has

Non-human identities now outnumber humans in most tenants and are the dominant breach path. The
register is a deliverable customers will pay for because they cannot produce it themselves.

```powershell
# Every app registration credential expiring within 60 days
Connect-MgGraph -Scopes 'Application.Read.All'
Get-MgApplication -All | ForEach-Object {
    $app = $_
    $app.PasswordCredentials + $app.KeyCredentials |
      Where-Object { $_.EndDateTime -and $_.EndDateTime -lt (Get-Date).AddDays(60) } |
      ForEach-Object {
        [pscustomobject]@{
            App     = $app.DisplayName
            AppId   = $app.AppId
            Type    = if ($_.Key) { 'Certificate' } else { 'Secret' }
            Expires = $_.EndDateTime
            Days    = [int]($_.EndDateTime - (Get-Date)).TotalDays
        }
      }
} | Sort-Object Days | Format-Table -AutoSize                          # ✅
```

Register columns: **identity, type, owner, purpose, permissions held, credential type, expiry,
last used, rotation method, revocation procedure.**

**Sort by application permissions first.** Per
[Layer 4 §5](../../../30-identity-and-nhi/service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md),
application permissions have **no intersection** with any user's rights — `Mail.Read` as an
application permission reads every mailbox in the organisation.

**Then remove the secrets.** Credential hierarchy, best to worst:

1. **Managed identity** — no credential exists
2. **Workload identity federation** — no credential exists (GitHub Actions, Kubernetes, AWS, GCP)
3. Certificate
4. Client secret — a password for a robot, sitting in a pipeline variable

Migrating one pipeline to federated credentials and deleting its secret is a same-day deliverable
with a clean before/after.

---

## 5. Intune — the device signal

Conditional Access's *"require compliant device"* is an **Intune verdict**, distinct from
*"require Hybrid Entra joined"*, which is a **join-state fact**. A device can be hybrid-joined and
non-compliant. **A compliance-requiring policy in a tenant without Intune blocks everyone.**

Minimum viable: enrolment configured, a compliance policy (encryption, OS version, password), and
a configuration profile — then a CA policy consuming the signal.

---

## 6. Detection and KQL

Ship logs first — otherwise there is nothing to query, and **retention is not retroactive**.

```powershell
# Diagnostic settings send Entra logs to Log Analytics. Configure in the portal or via Graph.
# Categories worth sending: SignInLogs, NonInteractiveUserSignInLogs,
# ServicePrincipalSignInLogs, ManagedIdentitySignInLogs, AuditLogs, ProvisioningLogs,
# RiskyUsers, UserRiskEvents
```

Detections to build today:

```kusto
// Break-glass used - this should return nothing. Alert on any row.
union SigninLogs, AADNonInteractiveUserSignInLogs
| where TimeGenerated > ago(90d)
| where UserPrincipalName startswith "breakglass"
| project TimeGenerated, UserPrincipalName, AppDisplayName, IPAddress, ResultType
```

```kusto
// Consent grants - illicit consent hunting
AuditLogs
| where TimeGenerated > ago(30d)
| where OperationName has "Consent to application"
| extend App = tostring(TargetResources[0].displayName)
| project TimeGenerated, App, Actor = InitiatedBy.user.userPrincipalName
```

```kusto
// Service principals signing in from more than one country
AADServicePrincipalSignInLogs
| where TimeGenerated > ago(30d) and ResultType == 0
| summarize Countries=make_set(LocationDetails.countryOrRegion), Signins=count()
    by ServicePrincipalName, AppId
| where array_length(Countries) > 1
```

> **There are four sign-in tables, not one.** Investigating with `SigninLogs` alone misses
> non-interactive, service principal and managed identity activity — which is exactly where modern
> attackers persist.

---

## 7. Automation and posture-as-code

**Run [Maester](https://maester.dev/) against the tenant.** Pester-based, ships EIDSCA + CISA SCuBA
+ CIS M365 + ORCA checks, and runs in CI. Baseline today, re-run after each change.

*"I have Entra configuration drift gated in a pipeline"* is a portfolio artifact. A certificate is
not.

Bicep/Terraform for the resource plane; Graph PowerShell for the directory plane; **secretless
auth via workload identity federation** for whatever runs it.

---

## 8. Failure exercises

| Cause it | Lesson |
|---|---|
| Two grant controls on the default setting | Discover the AND default — Layer 3 §2 |
| Require compliant device with no Intune | Everyone blocked; recover **via break-glass** |
| Delete an app registration, then restore it | The **service principal does not come back** |
| Let a client secret expire | Watch the integration fail; find the error |
| Query `SigninLogs` for a service principal | Returns nothing; use the right table |

**Exercise 2 is mandatory.** Lock a *test* user out on purpose and recover with break-glass, once,
in a lab — so you never do it accidentally in production.

---

## 9. Teach-back

1. **Compliant device vs Hybrid joined?** Intune verdict vs join-state fact.
2. **Why break-glass before any CA policy?** CA misconfiguration is the most common lockout cause.
3. **Why do application permissions matter more than delegated?** No intersection with user rights.
4. **Why is legacy auth the highest-value block?** It cannot do MFA, so it bypasses every policy.
5. **What happens to PIM when the licence lapses?** Eligible removed; time-bound active becomes
   permanent.
6. **Why four sign-in log tables?** Interactive, non-interactive, service principal, managed
   identity — attackers live in the last two.

---

## 10. Deliverables

| Facet | Artifact |
|---|---|
| `lab/` | CA baseline in report-only then enabled; PIM configured; Maester baseline report |
| `break-fix/` | The five failures, including a real lockout and break-glass recovery |
| `security/` | NHI register; over-privileged application permissions; secret-expiry report |
| `operations/` | CA change runbook; break-glass test procedure; detection/alert rules |
| `architecture-decisions/` | ADR: CA persona model; credential strategy and what it replaces |
| `customer-use-cases/` | Finance (PIM + evidence) vs SaaS (secretless CI/CD) — [Layer 7](../../../80-customer-scenarios/LAYER-7-INDUSTRY-VERTICALS.md) |

**Cleanup:** disable test CA policies (do **not** delete — keep them as evidence), remove test PIM
assignments, revoke test app credentials.
