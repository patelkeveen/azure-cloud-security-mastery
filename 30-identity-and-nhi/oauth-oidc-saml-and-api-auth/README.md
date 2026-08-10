# OAuth, OIDC, SAML and API Authentication

> **Concept facet.** Full depth in
> **[LAYER-1-IDENTITY-PROTOCOLS.md](LAYER-1-IDENTITY-PROTOCOLS.md)** in this folder.
> **This is the highest-ROI topic in the repository** and appears as a section in no Microsoft
> study guide.

## What it is

The protocol machinery underneath every sign-in. SC-300 tests *outcomes* — "configure app
authentication." The job tests *mechanism* — "why does this token lack the `groups` claim?"

## The first-principles problem

A user wants an app to access their data in some service. Giving the app your password fails four
ways: no scoping, no independent revocation, every app becomes a credential liability, and MFA
becomes impossible.

So the industry separated **authentication** (who you are) from **authorisation** (what a bearer
may do), and inserted a trusted third party. **Everything else follows from that one decision.**

> **Interview-grade framing:** OAuth 2.0 is a **delegation** protocol, not an authentication
> protocol. It answers *"may this bearer do X?"* — never *"who is this?"* People who use OAuth to
> log users in build broken systems. **OpenID Connect exists precisely because OAuth alone cannot
> authenticate.**

## The flow decision tree — the most common senior interview question

```
Is a human present and interacting?
├── NO  → Client Credentials
│         In Azure: prefer a MANAGED IDENTITY (no secret at all)
│         For CI/CD: prefer WORKLOAD IDENTITY FEDERATION (no secret at all)
└── YES → Can the device show a browser and accept typed input?
     ├── NO  → Device Code
     └── YES → Authorization Code + PKCE   ← the default, always
```

**PKCE defeats authorization-code interception.** On mobile a malicious app can register the same
custom URI scheme and steal the code; without PKCE it can redeem it. With PKCE it also needs the
`code_verifier`, which never left the legitimate app.

Dead or deprecated, and you should know why: **implicit flow** (tokens in the URL fragment, leaked
into history and referrers) and **ROPC** (app collects the password — breaks MFA, CA and federation).

## The JWT is where troubleshooting happens

Three Base64URL segments: `header.payload.signature`. **Base64 is encoding, not encryption** — the
payload is readable by anyone holding it. The signature guarantees integrity and authenticity,
**not confidentiality.**

Claims to know cold: `iss`, **`aud`** (audience mismatch is the #1 "works in Postman, fails in my
app"), `sub` vs **`oid`** (only `oid` is stable — correlate on it), `tid`, `exp`/`nbf`,
**`scp`** (delegated) vs **`roles`** (application), `wids`, and **`amr`** — which is how you *prove*
MFA occurred.

**The overage trap:** past ~150–200 groups, Entra **silently drops** the `groups` claim and
substitutes `_claim_names`. Group checks then authorise nobody — and it works perfectly in dev,
failing in production for your most senior, most group-joined users.

## Why revoking a session doesn't log them out

Access tokens are **stateless and self-contained**; the resource server validates signature and
expiry without calling Entra. So disabling the account blocks *new* tokens, revoking sessions kills
*refresh* tokens, and **the already-issued access token stays valid until `exp`.**

**Continuous Access Evaluation** closes that gap for CAE-aware resources with a claims challenge.
The honest answer to *"how fast can we lock someone out?"* is: **instantly for CAE-aware workloads,
up to token lifetime for everything else.**

## SAML and the consent framework

**SAML** still runs a large share of enterprise SSO. The recurring outage is **token-signing
certificate expiry** — it breaks SSO for every user of that app simultaneously, with no warning
unless someone configured the notification. **Track signing-cert expiry for every SAML app**; it is
a guaranteed-value deliverable.

**Consent:** delegated permissions intersect with the user's own rights; **application permissions
do not intersect with anything.** That asymmetry is why the **illicit consent grant attack** works —
the user genuinely authenticates, MFA passes, and the attacker holds a refresh token. A password
reset does not remediate it; revoking the grant does.

## Evidence this topic needs

- `lab/` — capture a real sign-in in devtools, decode the JWT at `jwt.ms`, **narrate every claim**.
  Read the `.well-known/openid-configuration` and match a `kid` to the token header.
- `break-fix/` — **reproduce the groups overage** with a user in 210 groups; run client credentials
  by hand with no SDK.
- `security/` — delegated vs application permission comparison as a non-privileged user.
