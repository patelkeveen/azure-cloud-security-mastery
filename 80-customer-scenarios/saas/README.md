# SaaS and Technology

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **Boundary:** [`../LAYER-7-INDUSTRY-VERTICALS.md`](../LAYER-7-INDUSTRY-VERTICALS.md) §7 is the
> brief. ⭐ **This is engagement depth — and the only vertical where the customer's *product* is also
> an identity system.** Pairs with
> [`../../30-identity-and-nhi/managed-identities/`](../../30-identity-and-nhi/managed-identities/)
> and [`../../30-identity-and-nhi/app-registrations/`](../../30-identity-and-nhi/app-registrations/).

---

## 1. What it is

Identity engineering for software companies, where there are ⭐ **two identity planes that people
constantly conflate**:

| Plane | Who | ⭐ Built with |
|---|---|---|
| ⭐ **Workforce** | employees, contractors | ⭐ Entra ID — the normal tenant |
| ⭐ **Customer (CIAM)** | ⭐ **the product's own users** | ⭐ Entra External ID, Auth0, Okta CIC, or homegrown |

⭐ **These are separate systems with separate threat models, and the mistake of running customers in
the workforce tenant is both common and expensive to undo.**

---

## 2. Why it is different

⭐ **A SaaS company's biggest identity risk is not its staff — it is its pipeline and its
service principals.**

| Ordinary customer | ⭐ SaaS company |
|---|---|
| A few admin accounts | ⭐ **hundreds of service principals**, most undocumented |
| Secrets in a vault | ⭐ secrets in **CI/CD**, in **code**, in **Slack** |
| Compliance is internal | ⭐ **SOC 2 / ISO 27001 gate revenue** — ⭐ enterprise deals stall without it |
| One tenant | ⭐ dev / staging / prod, ⭐ often three tenants |
| Auditors once a year | ⭐ **every enterprise prospect's security questionnaire** |

⭐ **"Compliance gates revenue" is the framing that unlocks budget in this vertical.** ⭐ **A stalled
enterprise deal has a number attached to it**, and identity controls that unblock a SOC 2 Type II
report are an investment against that number rather than a cost — which is exactly how to present
the work.

---

## 3. How it works underneath — ⭐ the secret you should not have

⭐ **The single highest-value change available to most SaaS companies:**

```
⭐ BEFORE — the client secret in the pipeline

  GitHub Actions ──[ ⭐ AZURE_CLIENT_SECRET stored as a repo secret ]──► Entra
        │
        ⭐ risks: ⭐ never rotated · ⭐ visible to anyone with repo admin ·
                 ⭐ copied into a fork · ⭐ expires at 3 a.m. and breaks deploys ·
                 ⭐ EXFILTRATABLE - it is a bearer credential

⭐ AFTER — workload identity federation (⭐ NO SECRET EXISTS)

  GitHub Actions ──[ ⭐ short-lived OIDC token, issued by GitHub ]──► Entra
                                                                      │
        Entra trusts GitHub's issuer for ⭐ THIS repo + THIS branch ◄──┘
                     │
        ⭐ nothing to steal · ⭐ nothing to rotate · ⭐ nothing to expire
```

⭐ **Federated credentials replace a stored secret with a trust relationship.** ⭐ **There is no
long-lived credential anywhere** — GitHub mints a short-lived token, Entra validates the issuer,
subject and audience, and issues an access token. ⭐ **Being able to explain this mechanism is one of
the strongest modern identity signals in an interview**, because it demonstrates you understand
tokens rather than just portals.

⭐ **The `subject` is the security boundary, and it is where people get it wrong:**

```
repo:contoso/payments-api:ref:refs/heads/main        ⭐ only main branch
repo:contoso/payments-api:environment:production     ⭐ only that environment
⭐ repo:contoso/payments-api:pull_request             ⭐ ← ⭐ DANGEROUS
   ⭐ any PR, including from a fork, can assume this identity
```

⭐ **A federated credential scoped to `pull_request` means anyone who can open a pull request can
obtain your production identity.** ⭐ **Scope to a branch or an environment, and protect that
environment with a required reviewer.**

---

## 4. Worked example — replacing a secret with federation

```powershell
$app = Get-MgApplication -Filter "displayName eq 'gh-deploy-payments-api'"

New-MgApplicationFederatedIdentityCredential -ApplicationId $app.Id -BodyParameter @{
  name      = 'github-main'
  issuer    = 'https://token.actions.githubusercontent.com'
  subject   = 'repo:contoso/payments-api:ref:refs/heads/main'   # ⭐ the boundary
  audiences = @('api://AzureADTokenExchange')
}

# ⭐ Then DELETE the old secret. ⭐ Federation is worthless while the secret still works.
Get-MgApplication -ApplicationId $app.Id |
  Select-Object -ExpandProperty PasswordCredentials |
  ForEach-Object { Remove-MgApplicationPassword -ApplicationId $app.Id -KeyId $_.KeyId }
```

⭐ **The deletion step is the one people skip, and skipping it removes the entire benefit.** ⭐ **A
federated credential added alongside a live secret has improved nothing** — the secret is still a
bearer credential someone can steal.

**Verify the exposure across the whole tenant — ⭐ the query that produces the finding:**

```powershell
Get-MgApplication -All -Property DisplayName,Id,PasswordCredentials,KeyCredentials |
  Where-Object { $_.PasswordCredentials.Count -gt 0 } |
  Select-Object DisplayName,
    @{n='Secrets';e={$_.PasswordCredentials.Count}},
    @{n='NextExpiry';e={($_.PasswordCredentials.EndDateTime | Sort-Object)[0]}} |
  Sort-Object NextExpiry
```

```
DisplayName                Secrets  NextExpiry
legacy-billing-sync              2  2026-08-29   ⭐ 11 days - ⭐ nobody knows
gh-deploy-payments-api           1  2027-01-14
data-export-tool                 3  2027-03-02   ⭐ 3 secrets?
```

⭐ **Two findings in one output.** ⭐ **A secret expiring in 11 days that nobody is tracking is a
production outage with a date on it** — and it will happen at whatever hour the job runs. ⭐ **Three
secrets on one app means two are almost certainly abandoned**, and each is a live credential.

⭐ **Set a recurring alert on this query.** ⭐ **"Client secret expired" is one of the most common
avoidable SaaS outages**, and it is entirely preventable with one scheduled report.

---

## 5. Service principal sprawl — and the consent question

⭐ **The other half of the SaaS identity problem: nobody knows what the applications can do.**

```powershell
# ⭐ Which apps hold the permissions that matter?
$graphSp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
$risky = 'Mail.Read','Mail.ReadWrite','Files.ReadWrite.All','Directory.ReadWrite.All',
         'User.ReadWrite.All','Application.ReadWrite.All'

Get-MgServicePrincipal -All | ForEach-Object {
  $sp = $_
  $grants = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -ErrorAction SilentlyContinue |
            Where-Object ResourceId -eq $graphSp.Id
  foreach ($g in $grants) {
    $perm = ($graphSp.AppRoles | Where-Object Id -eq $g.AppRoleId).Value
    if ($perm -in $risky) { [pscustomobject]@{ App = $sp.DisplayName; Permission = $perm } }
  }
}
```

```
App                     Permission
legacy-billing-sync     ⭐ Mail.ReadWrite
data-export-tool        ⭐ Files.ReadWrite.All
ci-provisioning         ⭐ Application.ReadWrite.All
```

⭐ **`Application.ReadWrite.All` is effectively a path to tenant compromise**, because an application
holding it can grant itself anything else. ⭐ **`Mail.ReadWrite` on an application means it can read
every mailbox in the tenant, with no user involved and no interactive sign-in** — which is precisely
why application permissions deserve the same scrutiny as Global Administrator, and rarely receive
it.

⭐ **The consent control that prevents the next one:** restrict user consent so that a developer
cannot grant an app broad permissions themselves, and enable the ⭐ **admin consent workflow** so the
request is routed rather than refused. ⭐ **Blocking consent without providing a request path just
produces shadow tenants.**

---

## 6. Design reference

| Area | Decision | ⭐ Why |
|---|---|---|
| ⭐ Customer identity | ⭐ **Entra External ID** (or a CIAM product) — ⭐ **never the workforce tenant** | ⭐ different threat model, different scale, different lifecycle |
| ⭐ CI/CD | ⭐ **workload identity federation** — ⭐ no secrets | §3 |
| Remaining secrets | ⭐ Key Vault + ⭐ expiry alerting | §4 |
| Environments | ⭐ separate tenants or ⭐ strictly separate app registrations | ⭐ a dev credential must not reach prod |
| Consent | ⭐ restrict user consent + ⭐ admin consent workflow | §5 |
| ⭐ Multi-tenant app | ⭐ **publisher verification** + least-privilege scopes | ⭐ enterprise customers check this |
| Privileged access | PIM for engineers with prod access | SOC 2 evidence |
| Evidence | ⭐ access reviews, ⭐ PIM history, ⭐ change records | ⭐ what the auditor samples |

⚠ `⚠ check` — the CIAM product landscape moved: ⭐ **Azure AD B2C is no longer the recommended path
for new build; Entra External ID is the successor.** Verify current availability, migration guidance
and pricing before advising, as this changed recently and continues to.

⭐ **Publisher verification is a small task with disproportionate commercial value.** ⭐ **An
unverified multi-tenant app shows a warning at consent**, and enterprise security teams reject apps
on exactly that basis — ⭐ **so it is a sales blocker disguised as an identity setting.**

---

## 7. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| ⭐ Deploy fails at 03:00 | ⭐ client secret expired | ⭐ federation; ⭐ meanwhile, expiry alerting |
| Secret in a public repo | stored credential existed at all | ⭐ federation removes the class |
| ⭐ Federation added, ⭐ risk unchanged | ⭐ **old secret not deleted** | ⭐ delete it |
| ⭐ Any PR can deploy to prod | ⭐ `subject` scoped to `pull_request` | ⭐ scope to branch/environment |
| App can read every mailbox | application permission never reviewed | ⭐ §5 sweep, ⭐ then remove |
| Enterprise deal stalls | ⭐ no SOC 2 / unverified publisher | ⭐ evidence artifacts + verification |
| Customers in the workforce tenant | ⭐ expedient at seed stage | ⭐ separate CIAM — ⭐ expensive to unwind |

⭐ **"Customers in the workforce tenant" is the architectural mistake with the longest tail.** ⭐ **It
works at 200 users and becomes untenable at 20,000** — guest sprawl, licensing confusion,
conditional access that cannot distinguish staff from customers, and a directory where a customer
support agent can enumerate every customer. ⭐ **Flag it early even when it is not in scope.**

---

## 8. Customer discovery questions

1. ⭐ **"How does your CI/CD pipeline authenticate to Azure — a secret, or federation?"**
2. ⭐ **"How many app registrations have client secrets, and who owns each?"**
3. "Are your product's users in the same tenant as your employees?"
4. ⭐ **"Which applications hold application-level Graph permissions?"**
5. "Can a developer consent to a new application themselves?"
6. ⭐ **"Has an enterprise deal ever stalled on a security questionnaire?"** (⭐ the budget question)
7. "Are dev, staging and prod separated by tenant or only by naming?"

---

## 9. Remember it

**Hook — ⭐ `W C`: two planes — **W**orkforce and **C**ustomer — ⭐ **never the same tenant.**
And within workforce: ⭐ **no secrets, federate.**

**Analogy — a house key versus a visitor being buzzed in.** ⭐ **A client secret is a cut key: once
copied, it opens the door forever and you cannot tell how many copies exist. Federation is an
intercom — the visitor proves who they are each time, from the doorstep, and access lasts only for
that visit.** The analogy predicts the design rules: ⭐ **you must take the old key back or the
intercom changed nothing** (delete the secret), and ⭐ **you buzz in the person, not "anyone standing
at the door"** — which is exactly why the `subject` claim must name a branch, not `pull_request`.

**The one line:** ⭐ **Delete the secret; the federated credential is only a control once the bearer
credential is gone.**

---

## 10. Self-test

1. Name the two identity planes and why they must be separate.
   → ⭐ Workforce (Entra) and customer/CIAM (External ID). Different threat model, scale and lifecycle.
2. What replaces a stored client secret, and what is the mechanism?
   → ⭐ Workload identity federation: the platform mints a short-lived OIDC token; Entra trusts issuer + subject + audience.
3. Why is `subject: pull_request` dangerous?
   → ⭐ Anyone who can open a PR — including from a fork — can assume that identity.
4. What must you do after adding a federated credential?
   → ⭐ Delete the old secret. Otherwise nothing changed.
5. Why is `Application.ReadWrite.All` a tenant-compromise permission?
   → ⭐ The app can grant itself any other permission.
6. Why enable the admin consent workflow rather than just blocking consent?
   → ⭐ Blocking without a request path produces shadow tenants.
7. Why is publisher verification a commercial issue?
   → ⭐ Unverified apps show a consent warning, and enterprise security teams reject on that basis.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | ⭐ one app converted from secret to federated credential, with the secret deleted |
| `security` | ⭐ the application-permission sweep, and at least one permission removed |
| `operations` | the secret-expiry report, scheduled, with the soonest expiry actioned |
| `break-fix` | one expired-secret outage, and the federation that prevented recurrence |
| `architecture-decisions` | ⭐ the workforce-vs-CIAM tenant decision, written down |
