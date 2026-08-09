# Layer 1 — Identity Protocols (the layer no study guide teaches)

> **Why this document exists.** SC-300 tests outcomes: *"configure app authentication,"*
> *"configure API permissions."* The job tests mechanism: *"why is this token missing its
> `groups` claim?"*, *"why does revoking the session not log them out?"*, *"why did consent
> succeed for one user and fail for another?"*
>
> Every one of those is answered at this layer, and this layer appears as a section in **no**
> Microsoft study guide. It is the single largest separator between certified and senior.
>
> **Gate:** you own this layer when you can decode a real JWT by hand and explain every claim.

---

## 1. First principles: the problem federation solves

Before any protocol, understand the problem. Three parties, one hard question.

A user wants an app to access their data in some service. The naive solution — give the app
your password — fails on four counts:

1. The app now has **full** access, forever, to everything (no scoping)
2. You cannot revoke the app without changing your password (no independent revocation)
3. Every app becomes a credential-storage liability (blast radius)
4. MFA is impossible — a password field can't carry a second factor

So the industry separated **authentication** (proving who you are) from **authorization**
(what a bearer may do), and inserted a trusted third party. That third party is the
**identity provider**. Everything below is the consequence of that one decision.

| Term | Means | Entra example |
|---|---|---|
| **Resource Owner** | The human who owns the data | Your user |
| **Client** | The app wanting access | An app registration |
| **Authorization Server** | Issues tokens; authenticates the owner | Microsoft Entra ID |
| **Resource Server** | Holds the data; validates tokens | Microsoft Graph, your API |

> **Interview-grade framing:** OAuth 2.0 is a **delegation** protocol, not an authentication
> protocol. It answers *"may this bearer do X?"* — never *"who is this?"* People who use OAuth
> to log users in build broken systems. OpenID Connect exists precisely because OAuth alone
> cannot authenticate.

---

## 2. OAuth 2.0 flows — the decision tree

**This is the most common senior-interview question in identity.** You must pick a flow from a
described topology and defend it.

```
Is a human present and interacting?
├── NO  → Client Credentials
│         Daemon, service, cron, CI/CD. App acts as itself, no user.
│         In Azure: prefer a MANAGED IDENTITY (no secret at all).
│         For CI/CD: prefer WORKLOAD IDENTITY FEDERATION (no secret at all).
│
└── YES → Can the device show a browser and accept typed input?
     ├── NO  → Device Code
     │         Smart TV, CLI on a headless box, IoT.
     │         User goes to microsoft.com/devicelogin on a phone, types a code.
     │
     └── YES → Authorization Code + PKCE          ← the default, always
               SPAs, mobile, native, and confidential web apps.
               PKCE is mandatory for public clients and recommended for all.
```

### The flows in detail

**Authorization Code + PKCE** — the one you should reach for by default.

```
1. Client generates code_verifier (random) and code_challenge = SHA256(verifier)
2. Browser → /authorize?...&code_challenge=...&code_challenge_method=S256
3. Entra authenticates the user (password, MFA, CA policies all evaluate HERE)
4. Entra redirects back with a short-lived authorization CODE
5. Client → /token, POSTing code + code_verifier
6. Entra hashes the verifier, compares to the stored challenge, issues tokens
```

*Why PKCE exists:* on mobile, a malicious app can register the same custom URI scheme and
intercept the redirect containing the code. Without PKCE the attacker redeems the code.
With PKCE they also need the `code_verifier`, which never left the legitimate app.
**PKCE defeats authorization-code interception. That is its entire job.**

**Client Credentials** — no user, app authenticates as itself.
```
POST /token   grant_type=client_credentials
              client_id, client_secret|client_assertion, scope=https://graph.microsoft.com/.default
```
Uses **application permissions** (not delegated). There is no user to consent, so an admin
consents once, tenant-wide. This is why application permissions are dangerous: `User.Read.All`
as an application permission reads *every* user, unconstrained by any user's own rights.

**On-Behalf-Of (OBO)** — API-to-API while preserving user identity.
API A receives a user's token, exchanges it for a token to call API B *as that user*.
Preserves the audit trail and the user's actual permissions. Without OBO, middle-tier APIs
call downstream as themselves and you lose all per-user authorization.

**Device Code** — input-constrained devices. Also, notably, an **attacker technique**: device
code phishing sends a victim a legitimate Microsoft URL and a code. It is worth blocking via
Conditional Access if you don't need it.

**ROPC (Resource Owner Password Credentials)** — `[DEPRECATED]`. App collects the password
directly. Breaks MFA, breaks CA, breaks federation, defeats the entire point of OAuth.
Know its name only so you can refuse to use it.

**Implicit flow** — `[DEAD]`. Returned tokens in the URL fragment, where they leaked into
browser history and referrer headers. Replaced by Auth Code + PKCE for SPAs.

---

## 3. OpenID Connect — authentication on top of OAuth

OIDC is a thin layer over OAuth 2.0 that adds the missing piece: **an identity assertion**.

| | OAuth 2.0 | OpenID Connect |
|---|---|---|
| Question answered | "May this bearer do X?" | "Who is this user?" |
| Artifact | Access token | **ID token** |
| Audience | The resource server | **The client itself** |
| Scope trigger | resource scopes | `openid` (plus `profile`, `email`) |

**Discovery** — every OIDC provider publishes its configuration:
```
https://login.microsoftonline.com/{tenant}/v2.0/.well-known/openid-configuration
```
Returns `authorization_endpoint`, `token_endpoint`, `jwks_uri`, `issuer`, supported scopes and
response types. `jwks_uri` gives the public signing keys — this is how a resource server
validates signatures without contacting Entra per request, and why **key rollover** matters.

**`nonce`** — the client sends a random `nonce` in the request; Entra echoes it into the ID
token. The client verifies it matches. This defeats **token replay**.

---

## 4. JWT anatomy — decode one by hand ⭐

A JWT is three Base64URL segments separated by dots: `header.payload.signature`.

> **Critical:** Base64 is **encoding**, not encryption. A JWT payload is *readable by anyone
> who holds it*. Never put secrets in a token. The signature guarantees **integrity**
> (not tampered) and **authenticity** (really from Entra) — **not confidentiality**.

**Header** — how to verify:
```json
{ "typ": "JWT", "alg": "RS256", "kid": "abc123..." }
```
`alg` = RS256 (asymmetric: Entra signs with a private key, anyone verifies with the public
key from `jwks_uri`). `kid` = which key — this is what makes rollover work.

### Claims you must know cold

| Claim | Name | Why it matters operationally |
|---|---|---|
| `iss` | Issuer | Who minted it. **Validate this** or you accept tokens from any tenant |
| `aud` | Audience | Who it's FOR. A resource server rejecting a valid token almost always means `aud` mismatch — the #1 "it works in Postman but not in my app" bug |
| `sub` | Subject | Pairwise, per-app. **Not** a stable cross-app user ID |
| `oid` | Object ID | **The real, immutable user ID in the tenant.** Use this to correlate, never `sub` or `upn` |
| `tid` | Tenant ID | Which tenant. Essential for multi-tenant apps |
| `exp` / `nbf` / `iat` | Expiry / not-before / issued-at | Unix epoch. Clock skew between your server and Entra causes intermittent, maddening failures |
| `scp` | Scope | **Delegated** permissions, space-separated. Present when a user is involved |
| `roles` | Roles | **Application** permissions OR app roles. Present in app-only tokens |
| `wids` | Well-known IDs | Tenant-wide **directory role** template IDs (e.g. Global Admin) |
| `amr` | Auth methods | HOW they authenticated: `pwd`, `mfa`, `rsa`, `fido`. **Read this to prove MFA occurred** |
| `acr` / `acrs` | Auth context | Which authentication context was satisfied (`c1`–`c25`) |
| `groups` | Groups | Group object IDs — **see the overage trap below** |
| `appid` | App ID | Which client requested it |

### The `groups` overage trap ⭐

If a user belongs to more than **~150 groups** (SAML) or **~200** (JWT), Entra **silently
removes** the `groups` claim and substitutes:

```json
"_claim_names":   { "groups": "src1" },
"_claim_sources": { "src1": { "endpoint": "https://graph.microsoft.com/v1.0/users/{oid}/getMemberObjects" } }
```

Your app's group check now evaluates against a claim that isn't there, and **silently
authorizes nobody** — or, worse, falls through to a default-allow. This works perfectly in
dev (where test users are in 3 groups) and fails in production for exactly your most senior,
most-group-joined users.

**Fixes, in order of preference:** use **app roles** instead of groups; or restrict the claim
to *groups assigned to the application*; or call Graph `getMemberObjects` on overage.

### The three token types

| Token | Audience | Lifetime | Purpose |
|---|---|---|---|
| **ID token** | The client | Short | Prove who the user is. **Never send to an API** |
| **Access token** | The resource | ~60–90 min, variable | The bearer credential. **Never inspect in the client** |
| **Refresh token** | Entra | Up to 90 days, sliding | Obtain new access tokens silently |

> **Two mirror-image mistakes.** Sending an *ID token* to an API — it fails `aud` validation.
> Having a *client* parse an *access token* to read the username — the client isn't the audience,
> the format is not contractual, and it may be an opaque string tomorrow. The ID token is for
> the client; the access token is for the API. Never cross the streams.

### Why revoking a session doesn't log them out ⭐

The question every customer asks after their first offboarding incident.

Access tokens are **stateless and self-contained**. A resource server validates the signature
and expiry — it does **not** call Entra. So:

- Disabling the account → blocks *new* token issuance
- `Revoke-MgUserSignInSession` → invalidates *refresh* tokens
- The already-issued **access token remains valid until `exp`** — up to ~90 minutes

That is the gap. **Continuous Access Evaluation (CAE)** closes it: CAE-aware resources
(Exchange, SharePoint, Teams, Graph) subscribe to critical events — account disabled, password
changed, high user risk, network location change — and Entra pushes a **claims challenge** that
forces immediate re-auth. Revocation drops from ~90 minutes to near-real-time.

**When a customer asks "how fast can we lock someone out?", the honest answer is:
instantly for CAE-aware workloads, up to token lifetime for everything else.** Knowing that
distinction is a senior answer.

---

## 5. SAML 2.0 — the one that won't die

XML-based, predates OAuth, and still runs a large share of enterprise SaaS SSO. You will
configure it constantly.

| Concept | SAML term | OIDC equivalent |
|---|---|---|
| Identity provider | IdP | Authorization Server |
| Application | SP / Relying Party | Client |
| Assertion | SAML Assertion (XML) | ID Token (JWT) |
| User identifier | `NameID` | `sub` / `oid` |

**SP-initiated** (normal): user hits the app → app redirects to Entra → Entra posts an
assertion back. **IdP-initiated**: user starts in MyApps → Entra posts to the app.
Some apps support only one. Always ask which.

**Signing vs encryption:** Entra **signs** the assertion (integrity/authenticity) always.
It **encrypts** only if configured. Signing ≠ encryption — a signed, unencrypted assertion is
readable in a HAR file.

**The recurring outage:** the token-signing certificate expires (default 3 years). SSO breaks
for every user of that app, simultaneously, with no warning unless someone configured the
notification email. **Track signing-cert expiry for every SAML app.** This is a
guaranteed-value deliverable on any customer engagement.

---

## 6. The consent framework — and the attack it enables

**Delegated permissions** = app acts *as the signed-in user*. Effective access is the
**intersection** of the app's permission and the user's own rights. A user with `Mail.Read`
delegated can only read *their* mail.

**Application permissions** = app acts *as itself*. **No intersection, no user context.**
`Mail.Read` as an application permission reads **every mailbox in the tenant**. This is why
application permissions always require admin consent and why over-granting them is the most
common critical finding in a tenant review.

**`/.default`** — "give me every permission already consented for this app," rather than
requesting scopes dynamically. Required for client credentials.

### Illicit consent grant attack ⭐

The phishing technique that defeats MFA — because the user *really does* authenticate.

1. Attacker registers an app with a plausible name ("Office365 Backup Service")
2. Sends a legitimate `login.microsoftonline.com` link requesting `Mail.Read offline_access`
3. User authenticates — **MFA passes, CA passes, everything is genuine**
4. User clicks Accept
5. Attacker holds a refresh token. **No password was stolen. Password reset does not help.**

**Defences:**
- Set user consent to *"Do not allow"* or restrict to verified publishers + low-risk permissions
- Enable the **admin consent workflow** so requests are reviewed, not blocked into shadow IT
- Hunt `Consent to application` in `AuditLogs`
- Use **Defender for Cloud Apps OAuth app policies** to detect and revoke

Remediation is **not** a password reset — it's revoking the service principal's grants and
sessions.

---

## 7. Hands-on gate

Do these in order. You own Layer 1 when all five are done without notes.

**Lab 1 — Decode a real token.** Sign in to a web app, open devtools → Network, find the
`/token` response, paste the access token into `jwt.ms`. Then narrate: `aud`, `iss`, `oid`,
`scp` vs `roles`, `amr`, `exp`. **Explain why `amr` proves MFA happened.**

**Lab 2 — Read the discovery document.**
```powershell
$t = 'YOUR-TENANT-ID'
irm "https://login.microsoftonline.com/$t/v2.0/.well-known/openid-configuration" |
    Select-Object issuer, authorization_endpoint, token_endpoint, jwks_uri
```
Then fetch `jwks_uri` and match a `kid` to the one in your token header.

**Lab 3 — Client credentials by hand.** Register an app, add `User.Read.All` **application**
permission, grant admin consent, then acquire a token with a raw HTTP POST (no SDK) and call
Graph. Doing this manually once teaches more than ten portal walkthroughs.

**Lab 4 — Delegated vs application.** Same Graph call, both permission types, as a
non-privileged user. Observe that delegated returns only what the user can see and application
returns the whole tenant. **This is the lesson.**

**Lab 5 — Reproduce the overage trap.** Add a test user to 210 groups, sign in, inspect the
token. Watch `groups` vanish and `_claim_names` appear.

---

## 8. Connecting Graph PowerShell (start here)

```powershell
Connect-MgGraph -Scopes 'User.Read.All','Directory.Read.All','Policy.Read.All'
Get-MgContext | Select-Object Account, TenantId, Scopes
```

`Connect-MgGraph` runs **Authorization Code + PKCE** — the flow from §2 — and caches a refresh
token. `-Scopes` are the **delegated** permissions requested, so your effective access is the
intersection of those scopes and your own directory role. If a cmdlet returns
`Insufficient privileges`, the cause is one of exactly two things: a missing scope, or a
missing role. Diagnosing which is the skill.

> **Module note (2026):** `MSOnline` and `AzureAD` are **retired**. `Microsoft.Graph` is the
> only supported path. Any tutorial using `Connect-MsolService` or `Connect-AzureAD` is stale —
> a reliable signal that the rest of that content is stale too.

---

## Cross-references

| Concept here | Applied in |
|---|---|
| Auth Code + PKCE, client credentials | Layer 4 — app registrations, workload identity federation |
| `amr` / `acr` claims | Layer 3 — Conditional Access authentication context |
| CAE and claims challenges | Layer 3 — session management |
| Consent framework | Layer 4 — enterprise apps, Defender for Cloud Apps OAuth policies |
| SAML assertions | Layer 4 — SaaS integration |
| `oid` correlation | Layer 5 — KQL over `SigninLogs` |
