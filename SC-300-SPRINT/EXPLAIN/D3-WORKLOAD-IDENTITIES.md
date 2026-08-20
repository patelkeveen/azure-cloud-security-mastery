# D3 — Plan and implement workload identities · 20–25%

> ⭐ **Identities that are not people.** Apps, scripts, pipelines, robots — and increasingly AI
> agents. ⭐ **This is the domain most people under-revise because it feels abstract**, and it is a
> fifth of the exam.

---

## 1. App registration vs enterprise application

**Age 8** — A toy company designs **one** robot (the **blueprint**). Then schools buy it, and each
school has **their own actual robot** with their own rules about which rooms it may enter. ⭐ **One
blueprint, many robots.**

**Any adult** — The **app registration** is the *definition* of an application, and it lives in the
tenant where the app was built. The **enterprise application (service principal)** is the *local
instance* of that app inside **your** tenant — carrying **your** permissions, **your** consent,
**your** role assignments.

⭐ **This is why "Salesforce" appears in your tenant even though you didn't build it:** Salesforce's
registration lives in Salesforce's tenant; a service principal for it was created in yours the
moment someone consented.

**Technical** — `Application` object (global, one, in the home tenant) → `ServicePrincipal` object
(one **per** tenant that uses it). The SP is the security principal that actually gets tokens,
role assignments and consent grants.

⭐ **Exam** — ⭐ **"Where do I change X?"** is the tested question:

| Change | Where |
|---|---|
| Redirect URIs, exposed API, certificates & secrets | ⭐ **App registration** (home tenant) |
| Who in *our* company may use the app | ⭐ **Enterprise application** — user/group assignment |
| Consent granted in *our* tenant | ⭐ **Enterprise application** |
| Disable this app for our company | ⭐ **Enterprise application** — "Enabled for users to sign in: No" |

⚠ **Deleting the app registration does not clean up service principals in other tenants**, and
you cannot edit a third-party app's registration at all — you only ever control your SP.

⭐ **Hook** — **Registration = the blueprint. Service principal = your robot.**

---

## 2. Delegated vs application permissions — `scp` vs `roles`

**Age 8** — Two ways the robot can fetch things. **(Delegated)** the robot goes **with you** and
can only reach shelves **you** are allowed to reach — if you can't get the top shelf, neither can
it. **(Application)** the robot goes **alone** with its own master key, and it can reach every
shelf, whoever asked.

**Any adult** — **Delegated** = the app acts *on behalf of a signed-in user*, and is limited by
**both** the permission granted **and** what that user could already do. **Application** = the app
acts *as itself*, with no user, and gets the full permission everywhere.

⭐ **This is the most consequential distinction in the whole domain, because it is where
over-privilege actually happens.**

**Technical**

```
scp    DELEGATED     a user is present
                     ⭐ effective rights = INTERSECTION( user's own rights, granted scope )

roles  APPLICATION   no user at all
                     ⭐ the app has the FULL stated permission, tenant-wide
                     ⭐ ALWAYS requires admin consent
```

⭐ **The intersection is the whole idea.** A delegated `User.ReadWrite.All` held by an app that a
*normal employee* consented to does **not** let that employee rewrite the directory — they never
could. ⭐ **The same permission as an *application* permission does**, because there is no user
present to be limited by.

⭐ **Exam** — ⭐ **Decode a token and look at the claim name.** `scp` (space-separated string) →
delegated. `roles` (array) → application. ⚠ **A daemon or nightly job with no user must use
application permissions** — delegated cannot work, because there's nobody to be on behalf of.
⭐ **And the least-privilege answer is almost always "use delegated if a user is present."**

⭐ **Hook** — **`scp` = with you, limited by you. `roles` = alone, limited by nothing.**

---

## 3. The consent framework

**Age 8** — Before the robot is allowed to read your diary, **someone has to say yes**. Sometimes
you can say yes yourself. For the really important things, only the **head teacher** can.

**Any adult** — When an app asks for access to your data, someone must agree. **User consent** lets
individuals agree for their own data. **Admin consent** covers the whole organisation, and is
required for anything high-impact. ⭐ **Leaving user consent wide open is how a phishing link turns
into a permanent mailbox reader.**

**Technical** — Consent creates an `oauth2PermissionGrant` (delegated) or an app role assignment
(application) against the service principal. Tenant settings control the boundary.

| Setting | What matters |
|---|---|
| **User consent** | Do not allow · ⭐ **Allow for verified publishers, low-impact permissions only** · Allow all |
| ⭐ **Admin consent workflow** | Users *request*, designated reviewers approve. ⭐ **The answer to "stop users consenting but don't create a ticket storm"** |
| **Permission classification** | Defines what "low impact" means for the middle option |
| **Group owner consent** | Whether group owners may consent on behalf of their group's data |

⭐ **Exam** — ⚠ **The illicit consent grant attack** is examinable and worth understanding
properly: a phishing link asks for delegated `Mail.Read`; the user consents; the attacker reads
mail with a **legitimate** token. ⭐ **Resetting the password does NOT revoke it** — the OAuth grant
is independent of the credential. ⭐ **You must revoke the service principal's grant and its refresh
tokens.** That "password reset didn't help" scenario is a favourite.

⭐ **Best-practice answer:** restrict user consent to **verified publishers + low impact**, and
**enable the admin consent workflow**.

⭐ **Hook** — **Consent outlives the password. Revoke the grant, not the credential.**

---

## 4. Managed identities

**Age 8** — Instead of giving the robot a **password on a sticky note** that someone could copy,
the building itself **recognises the robot**. Nothing written down means nothing to steal.

**Any adult** — An identity for an Azure resource where ⭐ **Azure holds and rotates the credential
for you — you never see it, never store it, never rotate it.** It removes the single most common
cause of breach: a secret checked into source control.

**Technical** — A service principal automatically managed by the platform. Two kinds:

| | **System-assigned** | **User-assigned** |
|---|---|---|
| Lifecycle | ⭐ **Tied to the resource. Delete the VM, the identity dies** | ⭐ **Independent object. Survives** |
| Sharing | ⭐ **One resource only** | ⭐ **Many resources share one identity** |
| Use when | Single resource, simple | Fleet of resources needing the same access; pre-assigned permissions before deployment |

⭐ **Exam** — ⭐ *"Twenty VMs all need the same Key Vault access, and permissions must survive a
redeploy"* → **user-assigned**. ⭐ *"One app, one resource, keep it simple"* → **system-assigned**.
⚠ **Managed identities are free and need no licence.** ⭐ **And they only work for Azure resources**
— they are not available for on-prem apps or third-party SaaS, which is where §5 comes in.

⭐ **Hook** — **System-assigned dies with the resource. User-assigned outlives it.**

---

## 5. Workload identity federation

**Age 8** — A robot from **another** building wants in. Instead of giving it a key that could be
copied, the two buildings agree: *"if their building vouches for that exact robot, let it in."*
⭐ **No key ever changes hands.**

**Any adult** — It lets something outside Azure — a GitHub Action, a Kubernetes pod, a pipeline in
another cloud — get an Entra token **without any stored secret**. The external system's own
identity token is exchanged for an Entra token. ⭐ **This is how you delete the last long-lived
secret from your CI/CD.**

**Technical** — A **federated identity credential** on the app registration establishes trust with
an external OIDC issuer, matched on **issuer**, **subject** and **audience**. The external token is
exchanged for an Entra access token — no client secret exists at all.

⭐ **Exam** — ⭐ **The subject must match EXACTLY**, and the exam knows people get this wrong:

```
repo:contoso/app:ref:refs/heads/main       -> only the main branch
repo:contoso/app:environment:production    -> only that environment
⚠ repo:contoso/app:pull_request            -> ANY fork's PR can assume this identity
```

⚠ **That last one is a genuine production hole**, not a trick question — a subject scoped to
`pull_request` means an outside contributor's pull request runs with your production identity.

⭐ **"Eliminate stored secrets in a GitHub Actions pipeline"** → **workload identity federation**,
not a rotated client secret, not a certificate.

⭐ **Hook** — **Managed identity for things inside Azure. Federation for things outside it.**

---

## 6. Secrets vs certificates

**Age 8** — A **password written on paper** versus a **wax seal only you can make**. Paper can be
copied by anyone who sees it. The seal can't.

**Any adult** — A client **secret** is a shared string — whoever has it *is* the app. A
**certificate** proves possession of a private key without ever transmitting it. ⭐ **Both expire,
and expiry is the outage nobody diaries.**

**Technical** — Secrets are symmetric shared strings sent on every token request. Certificates use
asymmetric proof-of-possession. ⭐ **Preference order: managed identity > federated credential >
certificate > secret.**

⭐ **Exam** — ⚠ **Expiry is the examinable failure.** An app that worked for two years stops
overnight; nothing changed; the secret expired. ⭐ **Know how to find them before they bite:**

```powershell
Get-MgApplication -All | ForEach-Object {
    $_.PasswordCredentials | Where-Object { $_.EndDateTime -lt (Get-Date).AddDays(30) } |
        ForEach-Object { "{0} expires {1:yyyy-MM-dd}" -f $using:_.DisplayName, $_.EndDateTime }
}
```

⭐ **And the ownership problem behind it:** an app whose owner has left the company has no one to
renew it. ⭐ **"Every workload identity must have a named human owner" is the governance answer**,
and it connects to access reviews in [`D4`](D4-GOVERNANCE.md).

⭐ **Hook** — **Secrets expire on a date nobody diarised. Managed identities never do.**

---

## 7. Reading a token — the claims that matter

**Age 8** — The wristband has writing on it saying **who you are, who gave it to you, when it stops
working, and what it lets you do.**

**Any adult** — A token is a small signed document. ⭐ **Anyone can read it — it is encoded, not
encrypted.** The signature is what stops forgery, not secrecy.

**Technical** — Paste a JWT into [jwt.ms](https://jwt.ms) and read:

| Claim | Means |
|---|---|
| `aud` | **Audience** — who this token is *for*. ⭐ Wrong audience is a very common 401 |
| `iss` | Issuer — which tenant/authority minted it |
| `sub` / `oid` | The subject; ⭐ **`oid` is the stable object ID** — use it, not the UPN |
| ⭐ `scp` | **Delegated** scopes (space-separated string) |
| ⭐ `roles` | **Application** permissions (array) |
| `exp` / `nbf` | Expiry / not-before |
| `amr` | ⭐ **How** they authenticated — `pwd`, `mfa`, `fido` |
| `appid` | Which client requested it |

⭐ **Exam** — ⭐ **`scp` present = a user was there. `roles` present = no user.** ⚠ **Never trust
an unvalidated token** — the signature and `aud` must be verified. ⭐ **And never key your app off
the UPN**: UPNs change with marriage, transfer and domain migration. `oid` does not.

⭐ **Hook** — **`oid` is forever. UPNs change. `scp` means a human was present.**

---

## 8. SaaS app integration — SSO, SCIM provisioning, App Proxy

> ⚠ **This section was missing until 2026-08-20.** SCIM appeared **zero times** across the whole
> EXPLAIN layer while [`../../SC-300-MASTERY-SYLLABUS.md`](../../SC-300-MASTERY-SYLLABUS.md) tags
> it **`[CORE]`**. ⭐ **Credit where due — ChatGPT caught this gap and I had missed it.**

**Age 8** — The school gets a new reading app. Two separate jobs, and people mix them up.
**(SSO)** the app learns to trust the school's door person, so you don't need a new password.
**(Provisioning)** ⭐ **someone still has to write your name in the app's own register** — and,
more importantly, **rub it out when you leave.**

**Any adult** — ⭐ **Single sign-on and provisioning are different problems and they fail
differently.** SSO means users don't get a second password. Provisioning means the account
**exists** in the app at all, and — the part everyone forgets — ⭐ **gets removed when they leave.**
An app with SSO but no provisioning still has a stale account for every leaver you ever had.

**Technical — the four SSO methods:**

| Method | When |
|---|---|
| ⭐ **SAML-based** | The app speaks SAML. Most enterprise SaaS |
| **OIDC / OAuth** | Modern apps, usually already in the gallery |
| ⭐ **Password-based** | ⭐ **The app supports neither** — Entra vaults the credential and replays it into the form |
| **Linked** | Just a tile pointing elsewhere. ⚠ **No authentication at all** |

**Gallery vs non-gallery:** gallery apps ship with pre-built SSO and provisioning config. A
non-gallery app is the same machinery, configured by hand.

**SCIM provisioning** — Entra acts as a **client** against the app's SCIM 2.0 endpoint:

```
/Users  /Groups           the endpoints Entra calls
create / update / disable the lifecycle it drives
attribute mappings        which Entra attribute lands in which app attribute
scoping filters           WHICH users are in scope (assignment, or an attribute rule)
```

⭐ **Incremental cycle runs roughly every 40 minutes; the initial cycle can take hours.**
⚠ **Repeated failures put the job in quarantine** — it backs off and stops making progress until
you fix the cause and restart it.

**Application Proxy** — publishes an **on-premises web app** through Entra without a VPN, via a
lightweight connector making **outbound** connections. ⭐ **Pre-authentication in Entra means
Conditional Access applies to a legacy on-prem app** — which is the whole point.

⭐ **Exam**

| Scenario | Answer |
|---|---|
| App supports neither SAML nor OIDC; team shares one login | ⭐ **Password-based SSO** |
| Leavers still active in the SaaS app | ⭐ **Provisioning not configured — SSO alone never deprovisions** |
| New user has SSO but "account not found" in the app | Provisioning not run, or ⭐ **out of scoping filter** |
| Provisioning silently stopped | ⭐ **Job quarantined after repeated failures** |
| Legacy on-prem web app, no VPN, must honour CA | ⭐ **Application Proxy** |
| Who configures Application Proxy? | ⭐ **Application Administrator — Cloud App Administrator cannot** |

⭐ **The distinction the exam leans on: SSO is authentication, provisioning is lifecycle.**
⭐ **Disabling a user in Entra kills their SSO immediately, but the app-side account persists
until provisioning removes it** — and that stale account is what an auditor finds.

⭐ **Hook** — **SSO gets you in. SCIM gets you created and, more importantly, deleted.**

---

## Say it back — cover the right column

| Prompt | Answer |
|---|---|
| Where do I set redirect URIs? | App registration |
| Where do I assign who can use the app? | Enterprise application |
| `scp` in a token means | Delegated — a user was present; rights are the intersection |
| `roles` in a token means | Application — no user, full permission, admin consent required |
| Nightly job, no user | Application permissions |
| Password reset didn't stop the rogue app | Consent is independent — revoke the SP grant + tokens |
| 20 VMs, same access, survives redeploy | User-assigned managed identity |
| GitHub Actions with no stored secret | Workload identity federation |
| Federated subject `pull_request` | ⚠ Any fork's PR can assume production identity |
| App broke overnight, nothing changed | Client secret expired |
| Stable identifier for a user | `oid`, never the UPN |
| App supports no SAML/OIDC | Password-based SSO |
| Leavers still active in the SaaS app | No SCIM provisioning — SSO never deprovisions |
| On-prem web app must honour CA | Application Proxy (Application Administrator) |

> **Next:** [`D4-GOVERNANCE.md`](D4-GOVERNANCE.md) · **Index:** [`README.md`](README.md) ·
> **Lab:** [`../DAY-6.md`](../DAY-6.md)
