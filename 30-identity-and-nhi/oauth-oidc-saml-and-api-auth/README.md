# OAuth 2.0, OIDC, SAML and API Auth

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The highest-ROI content in this repository, and it appears in no Microsoft study guide.**
> Full depth in **[LAYER-1-IDENTITY-PROTOCOLS.md](LAYER-1-IDENTITY-PROTOCOLS.md)**.
> Prerequisite: [`../../10-networking/http-and-api-networking/`](../../10-networking/http-and-api-networking/).

---

## 1. What it is

The protocols underneath **every** sign-in and API call in this repository.

⭐ **The distinction people get wrong, stated once:**

```
OAuth 2.0   AUTHORISATION   "this app may read your mail"        → ACCESS token
OIDC        AUTHENTICATION  "this is who the user is"            → ID token
SAML        both, XML-based, older, redirect/POST-driven         → SAML assertion
```

> **OIDC is a thin identity layer *on top of* OAuth 2.0.** OAuth alone never tells you who the user
> is — that was the gap OIDC filled, and it is why "we use OAuth to log people in" is a red flag.

---

## 2. Why it matters more than the products

Every failure you will debug — Conditional Access, consent, Graph, federation, workload identity —
resolves to **a token, its claims, and who validated them**. Engineers who can read a token debug in
minutes what others escalate.

**And the whole repo converges here:** `amr` proves how someone authenticated
([`../authentication-methods/`](../authentication-methods/)), `roles` versus `scp` is the app-only
versus delegated split ([`../service-principals/`](../service-principals/)), `wids` shows activated
PIM roles ([`../pim-and-access-reviews/`](../pim-and-access-reviews/)), and the federated `sub`
decides workload identity ([`../workload-identity-federation/`](../workload-identity-federation/)).

---

## 3. The flows, and when each is correct

| Flow | Use | Notes |
|---|---|---|
| **Authorisation code + PKCE** | ⭐ **Web apps, SPAs, mobile — the default** | PKCE is now standard for *all* clients, not just public ones |
| **Client credentials** | Daemon, no user present | App-only. `roles` claim. See §5 |
| **Device code** | Input-constrained devices (TV, CLI) | ⚠ Abused in **device-code phishing** |
| **On-behalf-of (OBO)** | API calling a downstream API **as the user** | Preserves the user's identity across hops |
| ~~Implicit~~ | — | ✗ **Superseded.** Leaks tokens in the URL fragment |
| ~~ROPC~~ | — | ✗ **Never.** The app handles the password; no MFA, no CA |

⭐ **Device code phishing** is worth naming: an attacker starts a device-code flow, sends the user a
legitimate Microsoft URL and a real code, and the user authenticates *genuinely* — MFA included —
while the attacker receives the tokens. **Nothing is spoofed.** Restrict device code flow by
Conditional Access unless it is genuinely needed.

---

## 4. Worked example — read a real token

**Do this today. It needs nothing but a browser and a tenant.**

```powershell
# Get a token you own, then decode it
Connect-MgGraph -Scopes 'User.Read'
# In a browser: paste any JWT into https://jwt.ms   (client-side; nothing is uploaded)
```

**Decode locally instead — no third-party site involved:**

```powershell
function Read-Jwt($jwt) {
  $p = $jwt.Split('.')[1].Replace('-','+').Replace('_','/')
  while ($p.Length % 4) { $p += '=' }
  [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p)) | ConvertFrom-Json
}
Read-Jwt $token | Format-List
```

**The claims that carry meaning, and what each answers:**

| Claim | Question it answers |
|---|---|
| **`aud`** | ⭐ **Who is this token *for*?** Validate it or you accept tokens meant for others |
| `iss` | Who issued it — must match your expected tenant |
| **`oid`** | ⭐ The **stable** user/principal ID. Correlate on this, never UPN |
| `tid` | Which tenant |
| **`scp`** | **Delegated** permissions (space-separated) |
| **`roles`** | ⭐ **App-only** permissions, or app roles assigned to a user |
| **`amr`** | ⭐ **How** they authenticated — `pwd`, `mfa`, `fido`, `rsa` |
| `wids` | Activated directory role template IDs |
| `exp` / `nbf` / `iat` | Validity window |
| `appid` | The calling application |

⭐ **`scp` present = delegated. `roles` present with no user = app-only.** That single check tells
you whether a call has a user-rights intersection behind it — the §3 asymmetry in
[`../service-principals/`](../service-principals/).

**The groups overage — a real production failure:**

```json
{
  "_claim_names":   { "groups": "src1" },
  "_claim_sources": { "src1": { "endpoint": "https://graph.microsoft.com/v1.0/users/.../getMemberObjects" } }
}
```

⭐ **Past roughly 150–200 groups the `groups` claim is replaced by a pointer.** Applications that
read `groups` directly break for exactly the users with the most access — usually administrators.
**Use app roles instead**; see [`../app-registrations/`](../app-registrations/) §8.

---

## 5. Validation — what a resource must actually check

```
1. SIGNATURE   against the issuer's published JWKS
2. iss         is this my tenant/issuer?
3. aud         ⭐ is this token FOR ME?
4. exp / nbf   is it currently valid?
5. scp / roles does it carry the permission this endpoint requires?
```

> ⭐ **Skipping `aud` validation is the classic token-confusion vulnerability.** A token legitimately
> issued for API A is presented to API B; if B only checks the signature, it accepts it. That is why
> [`../app-registrations/`](../app-registrations/) §7 insists a v2 resource app validate **only its
> own `appId`**.

**Never trust an ID token as an access token**, and never make authorisation decisions on an ID
token — it is proof of authentication for *your* client, not permission to call an API.

---

## 6. SAML — what still matters

Still everywhere in enterprise SSO. The mechanics:

```
App (SP) → redirect → IdP → user authenticates → SIGNED ASSERTION → POST back → app validates signature
```

**The app validates a signature, never calls back** — which is exactly why **Golden SAML** is
catastrophic ([`../../35-active-directory-and-hybrid-identity/adfs-and-federation/`](../../35-active-directory-and-hybrid-identity/adfs-and-federation/) §6).

| SAML | OIDC equivalent |
|---|---|
| Assertion | ID token |
| `Issuer` | `iss` |
| `Audience` | `aud` |
| `NotOnOrAfter` | `exp` |
| `AuthnContextClassRef` | `amr` |

⭐ **The concepts are identical; only the encoding differs.** Learn one properly and the other is
vocabulary.

---

## 7. What breaks

**Using OAuth for authentication.** It does not identify the user — that is OIDC.

**Not validating `aud`.** Token confusion.

**Authorising on an ID token.**

**Correlating on UPN.** Use `oid`.

**Reading `groups` without handling overage.** Breaks for administrators specifically.

**Implicit or ROPC flows.** Superseded and dangerous respectively.

**Leaving device code flow unrestricted.** Phishing with no spoofing required.

**Assuming a token can be revoked.** Access tokens are valid until `exp`; CAE narrows this for
supported services only.

**Ignoring `amr`** when proving MFA occurred — the sign-in log summary is a rendering; `amr` is the
claim.

---

## 8. Customer discovery questions

1. Do custom applications validate **`aud`**, or only the signature?
2. Does anything read the **`groups`** claim, and has overage been handled?
3. Is **device code flow** restricted by Conditional Access?
4. Any application still using **implicit** or **ROPC**?
5. Do applications correlate users on `oid` or on UPN/email?
6. Are any resource apps issuing **v1** tokens with custom identifier URIs?
7. Where MFA is asserted to a downstream system, is it validated from **`amr`**?
8. Is OBO used, or do APIs call downstream services as themselves?

---

## 9. Remember it

**Hook — "OAuth authorises, OIDC authenticates, SAML does both in XML."** And the claim pairs:
**`scp` = delegated, `roles` = app-only, `amr` = how, `oid` = who.**

**Analogy — a festival wristband and a passport.** **OAuth issues a wristband**: it says *what you
may enter*, not who you are — the bar staff never learn your name. **OIDC adds a passport photo** so
the venue knows who is wearing it. **`aud` is the festival name printed on the band** — and a venue
that does not read it will happily admit someone holding last week's wristband from a different
event. **That is token confusion, and it is the most consequential validation people skip.**

**The one thing:** ⭐ **read the token.** Every Conditional Access, consent, Graph and federation
failure resolves to a claim you can see — `aud`, `scp`, `roles`, `amr`, `oid`. **Engineers who
decode tokens debug in minutes what others escalate**, and this is the single most transferable
skill in the repository.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 10. Self-test

1. OAuth versus OIDC — which authenticates, and what does each return?
2. Which flow is the default for web, SPA and mobile clients?
3. What is device code phishing, and what is spoofed?
4. Five checks a resource must perform on a token?
5. What happens past ~150–200 group memberships, and who breaks first?
6. `scp` present versus `roles` present — what does each imply?
7. Which claim proves *how* someone authenticated?
8. Why is Golden SAML possible, in one sentence?
9. Why should you never authorise on an ID token?
10. Which identifier should applications correlate on?

<details>
<summary>Answers</summary>

1. **OIDC authenticates** (ID token). **OAuth authorises** (access token). OAuth alone never says
   who the user is.
2. **Authorisation code with PKCE.**
3. The attacker starts a device-code flow and relays a **genuine** Microsoft URL and code; the user
   authenticates for real, including MFA, and the attacker collects the tokens. **Nothing is spoofed.**
4. **Signature, `iss`, `aud`, `exp`/`nbf`, and `scp`/`roles`.**
5. The `groups` claim is replaced by **`_claim_names` / `_claim_sources`** pointing at Graph. It
   breaks for **users with the most group memberships — usually administrators.**
6. **`scp` = delegated** (user-rights intersection applies). **`roles` with no user = app-only**
   (no intersection).
7. **`amr`.**
8. The relying party **validates a signature and never calls back**, so whoever holds the signing key
   can mint valid assertions.
9. It is proof of authentication **to your client**, not permission to call an API.
10. **`oid`.**

</details>

---

## 11. Evidence this topic needs

- **`lab/`** ⭐ — **decode a real token from your own sign-in** and narrate every claim. **Runnable
  today, on the current tenant, with no premium licence.** This is the single highest-value lab in
  the repository.
- **`break-fix/`** — present a token with the wrong `aud` to an API and capture the rejection; force
  a groups overage on a test user and show `_claim_names` appear.
- **`security/`** — device code flow restricted; implicit/ROPC inventory; `aud` validation confirmed
  in custom apps.
- **`operations/`** — token lifetime and CAE posture documented.
- **`architecture-decisions/`** — ADR: app roles over group claims, and the flow chosen per
  application type.
- **`customer-use-cases/`** — §8 answered against a real estate.
