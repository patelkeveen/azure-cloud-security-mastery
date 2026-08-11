# Day 6 — Applications, consent and workload identity

> **Theory first:** [`app-registrations`](../30-identity-and-nhi/app-registrations/) ·
> [`oauth-oidc-saml-and-api-auth`](../30-identity-and-nhi/oauth-oidc-saml-and-api-auth/) ·
> [`workload-identity-federation`](../30-identity-and-nhi/workload-identity-federation/) ·
> [`data-formats-and-apis`](../00-foundations/data-formats-and-apis/) §3
> **Time:** 8 hours.

---

## ⭐ The one distinction today is built around

```
scp   →  DELEGATED   a user is present.  Effective = INTERSECTION of
                     (what the user can do) ∩ (what the app was consented)
roles →  APPLICATION no user.            ⭐ NO intersection. NO upper bound.
```

⭐ **Everything else today is a consequence of that.** Read a token, find which one it carries,
and you know the blast radius in ten seconds.

---

## Lab 6.1 — ⭐ Read a real token *(1.5 h)*

**The highest-value single skill in identity work.**

```powershell
function Read-Jwt {
    param([Parameter(Mandatory)][string]$Token)
    $p = $Token.Split('.')[1].Replace('-','+').Replace('_','/')
    while ($p.Length % 4) { $p += '=' }               # ⭐ base64URL needs re-padding
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p)) | ConvertFrom-Json
}

# Get a real token from your own tenant
$tok = (Get-MgContext) ; Connect-MgGraph -Scopes 'User.Read' -NoWelcome
# Or acquire explicitly via MSAL / az account get-access-token --resource https://graph.microsoft.com

Read-Jwt $accessToken | Select-Object aud, iss, appid, oid, tid, scp, roles,
  @{n='issued'; e={[DateTimeOffset]::FromUnixTimeSeconds($_.iat).LocalDateTime}},
  @{n='expires';e={[DateTimeOffset]::FromUnixTimeSeconds($_.exp).LocalDateTime}},
  @{n='amr';    e={$_.amr -join ','}}
```

- [ ] Identify `aud` — ⭐ **most 401s are this**
- [ ] Identify `scp` vs `roles`
- [ ] Note `amr` — ⭐ **this is your MFA evidence in a token**
- [ ] Compare `iat` against when you made a policy change on Day 3

⚠ **Never paste a real token into an online decoder. It is a live credential.**

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/oauth-oidc-saml-and-api-auth `
  -Facet lab -Name 'token-claims-decoded' `
  -Note 'Real tenant token decoded locally: aud, scp vs roles, amr as MFA evidence, iat vs policy change time' `
  -Command { 'Claims captured manually — see notes. Token values deliberately not stored.' }
```

---

## Lab 6.2 — Delegated vs application, proved *(2 h)*

- [ ] Create an app registration with **delegated** `Mail.Read`
- [ ] Sign in as a seeded user; read **only that user's** mail
- [ ] Attempt to read **another user's** mail → ⭐ fails, because of the intersection
- [ ] Grant the same app **application** `Mail.Read` with admin consent
- [ ] ⭐ Read **any** mailbox in the tenant

> ⭐ **That contrast is the whole lesson, and you have now demonstrated it rather than read it.**
> An application permission has no upper bound from any user's rights.

**Then scope it — the most under-used control in Exchange Online:**

```powershell
Connect-ExchangeOnline
New-ApplicationAccessPolicy -AppId <appId> `
  -PolicyScopeGroupId sg-app-scoped-mailboxes@<domain> `
  -AccessRight RestrictAccess -Description 'SC300 lab: scoped mail access'

Test-ApplicationAccessPolicy -Identity <someOtherUser> -AppId <appId>   # ⭐ turns config into evidence
```

⚠ Verify the current mechanism — this surface has moved. **The principle survives: scope app-only
mail access to a group of mailboxes.**

---

## Lab 6.3 — Consent framework *(1.5 h)*

- [ ] Set user consent to **admin consent workflow** — ⭐ not off, not open
- [ ] As a seeded user, attempt to consent to an app requiring a high-privilege permission
- [ ] Observe the request routed to an approver
- [ ] Approve it, and find the resulting **service principal**

> ⭐ **Disabling user consent with no workflow is the failure mode**: users route around it to
> unmanaged tools and you lose visibility. **Provide the governed path** — the same trade as
> sanctioned AI, MAM for BYOD and governed guest access. **Fourth appearance.**

```powershell
# ⭐ Audit: which apps already hold high-privilege application permissions?
Get-MgServicePrincipal -All | ForEach-Object {
  $sp = $_
  Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -EA SilentlyContinue |
    ForEach-Object {
      [pscustomobject]@{ App=$sp.DisplayName; Resource=$_.ResourceDisplayName; RoleId=$_.AppRoleId }
    }
} | Group-Object App | Sort-Object Count -Descending | Select-Object Count, Name -First 15
```

---

## Lab 6.4 — Workload identity federation *(2 h)*

⭐ **Remove the secret entirely.** This is the fix for the `gh-actions-*` finding in
[`ai-pipeline-nhi`](../60-ai-and-secure-ai/ai-pipeline-nhi/) §5.

```powershell
# Federated credential on the app — GitHub Actions exchanges its OIDC token for an Entra token
New-MgApplicationFederatedIdentityCredential -ApplicationId <appObjectId> -BodyParameter @{
  name      = 'github-main'
  issuer    = 'https://token.actions.githubusercontent.com'
  subject   = 'repo:patelkeveen/azure-cloud-security-mastery:ref:refs/heads/main'
  audiences = @('api://AzureADTokenExchange')
}
```

- [ ] Create it against **this repository**
- [ ] ⭐ Confirm the app now has **zero** password credentials
- [ ] Note the limit: ⭐ **20 federated identity credentials per app**

```powershell
Get-MgApplication -ApplicationId <appObjectId> -Property PasswordCredentials,KeyCredentials |
  Select-Object @{n='Secrets';e={@($_.PasswordCredentials).Count}},
                @{n='Certs';  e={@($_.KeyCredentials).Count}}
```

---

## ⭐ Deliberate failure — the subject must match exactly

- [ ] Change the workflow to run on a **branch other than `main`**
- [ ] ⭐ Watch the token exchange **fail** — the `subject` no longer matches
- [ ] Record the verbatim error

> ⭐ **That exact-match requirement is the security property.** A federated credential is not
> "trust GitHub" — it is "trust this repo, this branch, this workflow". Loosening the subject to a
> wildcard is how the control is quietly destroyed, and it is the same over-broad-allow-list
> mistake as `*.openai.azure.com` and sender-domain mail exemptions.

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/workload-identity-federation `
  -Facet break-fix -Name 'federated-subject-mismatch' `
  -Note 'Token exchange fails when the branch changes — the subject is an exact match and that is the control' `
  -Command { Get-MgApplicationFederatedIdentityCredential -ApplicationId <appObjectId> |
             Select-Object Name, Issuer, Subject, Audiences }
```

---

## Close out

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/app-registrations `
  -Facet security -Name 'application-permission-inventory' `
  -Note 'Apps holding application permissions — no user intersection, so this is the real blast radius' `
  -Command { Get-MgServicePrincipal -All | ForEach-Object { $sp=$_
               Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -EA SilentlyContinue |
                 ForEach-Object { [pscustomobject]@{ App=$sp.DisplayName; Resource=$_.ResourceDisplayName } } } }

cd .. ; .\tools\Build-CoverageRegister.ps1
git add . ; git commit -m "SC-300 sprint Day 6: tokens, consent, workload identity federation" ; git push
```

**Done when:**

- [ ] ⭐ A real token decoded locally; `aud`, `scp`/`roles`, `amr`, `iat` all read
- [ ] Delegated vs application demonstrated **by outcome**, not description
- [ ] Application access policy scoping proved with `Test-ApplicationAccessPolicy`
- [ ] Admin consent workflow tested end to end
- [ ] Federated credential working, ⭐ **zero secrets on the app**
- [ ] Subject-mismatch failure recorded verbatim

> **Tomorrow:** [`DAY-7.md`](DAY-7.md) — external identities, Identity Protection, and the
> evidence sweep. ⭐ **Day 7 works because Day 1 turned Identity Protection on.**
