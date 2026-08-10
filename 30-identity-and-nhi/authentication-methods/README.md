# Authentication Methods

> **Concept facet.** Depth lives in
> [Layer 3 §5](../conditional-access/LAYER-3-DOMAIN-2-AUTH-AND-ACCESS.md).

## What it is

The set of ways a user can prove identity, and the **Authentication methods policy** that governs
which methods each population may register and use. This is the modern control surface; it
replaces the legacy per-user MFA settings and the separate SSPR method configuration.

## Why it exists as a separate policy

Because *what a user may register* and *what a resource demands* are different questions, and
conflating them is why passwordless rollouts stall.

- **Authentication methods policy** — broad. "Engineering may register passkeys and Authenticator."
- **Conditional Access authentication strength** — narrow. "This admin portal demands
  phishing-resistant."

**That two-layer model is the answer to "how do we go passwordless without breaking everyone at
once."** Enable methods broadly; demand them narrowly, resource by resource.

## The methods, ranked by what they actually resist

| Method | Resists phishing? | Notes |
|---|---|---|
| **Passkeys (FIDO2)** | **Yes** | Device-bound passkeys in Authenticator count. Current terminology — "FIDO2" alone dates you |
| **Windows Hello for Business** | **Yes** | Satisfies MFA. Three trust models — cloud Kerberos trust is the simplest |
| **Certificate-based auth (multifactor)** | **Yes** | PIV/CAC, government staple. Needs a PKI trust store and username binding rules |
| Microsoft Authenticator push | No | Number matching is enforced; add context to reduce MFA fatigue |
| Temporary Access Pass | No | Time-limited. **Onboarding a passwordless user and recovering a lost factor** |
| SMS / voice | **No** | NIST SP 800-63B treats SMS as restricted. Migrate off it |

**"Phishing-resistant" has a precise meaning:** the credential is cryptographically bound to the
origin, so an adversary-in-the-middle proxy cannot replay it. Push notifications are not — the
user approves a prompt they cannot distinguish from a legitimate one.

## How it works underneath

Authentication produces the **`amr` claim** in the token (Layer 1 §4). That claim is how a resource
knows *how* the user authenticated, and it is what Conditional Access evaluates against an
authentication strength. **Read `amr` to prove MFA occurred** — it is the ground truth, not the
sign-in log summary.

## When and where

Every tenant needs a deliberate methods policy. The sequence that works:

1. Enable Authenticator and passkeys broadly; leave SMS enabled but deprioritised
2. Run a **registration campaign** to nudge SMS users onto Authenticator
3. Demand phishing-resistant strength for admins via CA
4. Only then remove SMS as a permitted method

## The traps

1. **Legacy MFA and SSPR settings coexist with the new policy during migration and can disagree.**
   Migrate deliberately and verify per method.
2. **Removing a method a user has as their *only* factor locks them out.** Check registration
   coverage before disabling anything — that is what TAP exists to rescue.
3. **Authentication strength and sign-in frequency can be satisfied at different moments.** A
   passkey sign-in yesterday can satisfy today's strength requirement while a Windows Hello unlock
   satisfies frequency. Users are not always re-prompted when you expect.
4. **Windows Hello as primary factor** satisfies a strength requiring it; signing in with a
   password first does **not** prompt for it — the user must restart and choose the method.

## Evidence this topic needs

- `lab/` — register a passkey; apply phishing-resistant strength to one app; attempt password+SMS
  and read the failure.
- `break-fix/` — disable a method a test user depends on; recover with TAP.
- `security/` — registration coverage report; who still has SMS as their only method.
