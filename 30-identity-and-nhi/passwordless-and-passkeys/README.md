# Passwordless and Passkeys

> **Concept facet.** Depth in
> [Layer 3 §5](../conditional-access/LAYER-3-DOMAIN-2-AUTH-AND-ACCESS.md) and
> [`../authentication-methods/`](../authentication-methods/).

## What it is

Authentication with no shared secret to steal. A key pair is generated on the authenticator; the
**private key never leaves it**; the service holds only the public key.

**Terminology, current as of 2026:** Microsoft's objective wording is **"passkeys (FIDO2)"**.
Saying "FIDO2" alone dates you; passkeys is the term, and it includes **device-bound passkeys in
Microsoft Authenticator**, not only hardware keys.

## Why it matters more than MFA did

MFA solved credential *guessing*. It did not solve credential *relay*.

An adversary-in-the-middle proxy sits between the user and the real sign-in page, relays the
password **and the push approval**, and captures the resulting session token. The user did
everything right. MFA passed. The attacker is in.

**Passkeys break this because the credential is cryptographically bound to the origin.** The
authenticator will not sign a challenge for `micros0ft-login.com`, no matter how convincing the
page is to the human. That is what "phishing-resistant" precisely means — not "stronger," but
**origin-bound**.

Once MFA is universal, attackers move to token theft. Passkeys plus **token protection** are the
answer; more MFA is not.

## How it works underneath

1. **Registration** — the authenticator generates a key pair for this relying party; the public key
   is registered with Entra.
2. **Authentication** — Entra sends a challenge; the authenticator unlocks the private key with a
   **local gesture** (biometric or PIN), signs, and returns it.
3. Entra verifies with the public key.

**The biometric never leaves the device and is never sent to Microsoft.** It unlocks the key
locally. This is the single most common customer misconception and the one that stalls rollouts —
"we're not sending our employees' fingerprints to Microsoft" is a fear you can dissolve in one
sentence.

**Two factors are inherent:** something you have (the authenticator) and something you are or know
(the local gesture). It is not "single factor because there's no password."

## The three phishing-resistant methods

| Method | Best for |
|---|---|
| **Passkeys (FIDO2)** — security key or device-bound in Authenticator | General workforce; shared devices via security keys |
| **Windows Hello for Business** | Windows estate. Three trust models; **cloud Kerberos trust** is the simplest |
| **Certificate-based auth (multifactor)** | Government / PIV-CAC; existing PKI |

## Rolling it out without breaking everyone

1. Enable passkeys in the **authentication methods policy** for a pilot group
2. Issue a **Temporary Access Pass** so users can register *without* an existing strong factor —
   TAP is the bootstrap, and the recovery path when someone loses their only key
3. Register, then verify with a CA policy requiring phishing-resistant strength on **one** app
4. Expand by persona: admins first, then general workforce
5. **Only then** remove SMS as a permitted method

**Do not demand phishing-resistant strength before registration coverage exists.** That is a
self-inflicted lockout, and the recovery path is the very method you just blocked.

## The traps

1. **Attestation and key restrictions.** You can restrict which authenticator models are permitted
   by AAGUID. Enforce this in regulated environments; skip it and any USB key qualifies.
2. **Shared devices** — biometrics do not fit. Security keys or smartcards do.
3. **Losing the only factor.** TAP is the answer, and it must be operationally ready *before*
   rollout, not designed during the first incident.
4. **Windows Hello as primary vs step-up** — if a user signs in with a password first, a strength
   requiring WHfB does **not** prompt for it; they must restart and choose the method.
5. **Assuming passwordless removes the password.** The account still *has* one until you take the
   further step of removing it — otherwise the phishable credential still exists.

## Evidence this topic needs

- `lab/` — register a passkey; sign in with it; **decode the token and read `amr`** to see what the
  method reported (Layer 1 §4).
- `break-fix/` — apply phishing-resistant strength to an app, attempt password + SMS, read the
  failure; then recover a "lost key" user with TAP.
- `security/` — registration coverage; who still holds SMS as their only method; attestation policy.
- `customer-use-cases/` — healthcare bedside (gloves, shared workstations); manufacturing shop floor.
