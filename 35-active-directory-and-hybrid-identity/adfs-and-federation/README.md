# AD FS and Federation

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **AD FS has no announced retirement date** — I checked and did not find one, so do not tell a
> customer it is "being retired." What is true: Microsoft's guidance is migration to Entra ID, and
> new capability lands there, not in AD FS.
> Protocol depth in [Layer 1](../../30-identity-and-nhi/oauth-oidc-saml-and-api-auth/LAYER-1-IDENTITY-PROTOCOLS.md).

---

## 1. What it is

An on-premises **Security Token Service**. It authenticates a user against AD and issues a **signed
SAML or WS-Federation token** that a relying party trusts.

The critical property: **the password never leaves the building.** That is why regulated
organisations adopted it, and why some still resist moving off it.

---

## 2. Why it exists — and why it is declining

It solved a real problem: single sign-on to external applications without giving them AD
credentials, and with on-premises control over every authentication.

The costs became larger than the benefit:

| Cost | Consequence |
|---|---|
| **Single point of failure on the auth path** | AD FS down = nobody authenticates to **anything**, cloud included |
| Server farm + WAP in the DMZ + load balancers | Patching, certificates, capacity — permanent operational load |
| **Certificate rollover** | The classic annual outage. See §5. |
| **Golden SAML** | ⭐ A forest-ending attack with no equivalent in cloud auth. See §6. |
| Security features live in Entra | Identity Protection signals, risk-based CA and passwordless are weaker or absent when auth happens at AD FS |

> The strategic argument that lands with executives is not technical: **AD FS is a system you own,
> patch, and get blamed for. Moving to Entra makes availability Microsoft's problem.**

---

## 3. How it works underneath

```
1  User → application (relying party)
2  App redirects → AD FS  (WS-Fed or SAML AuthnRequest)
3  AD FS authenticates against AD  (Kerberos on the internal network, forms auth externally)
4  AD FS builds a token: claims + issuer + audience
5  AD FS SIGNS it with the TOKEN-SIGNING CERTIFICATE   ◄── the crown jewel
6  Browser POSTs the token → application
7  App validates the SIGNATURE against AD FS's published public key, and trusts the claims
```

**Step 7 is the whole security model.** The application does not call AD FS to verify. It checks a
signature. **Anyone holding the token-signing private key can mint a valid token for any user**,
with no authentication and no log entry anywhere.

For Entra ID, the relying party is Entra itself: it trusts tokens issued by your AD FS for your
federated domain.

**Home realm discovery:** Entra decides where to send a user by the **domain suffix of the UPN**.
`user@contoso.com` redirects to AD FS if `contoso.com` is federated; `user@contoso.onmicrosoft.com`
never does. That is exactly why break-glass accounts use `.onmicrosoft.com` — see §7.

---

## 4. Worked example — is this tenant federated?

The first question in any hybrid assessment. **Domain state is per domain, not per tenant.**

```powershell
Connect-MgGraph -Scopes 'Domain.Read.All'
Get-MgDomain | Select-Object Id, AuthenticationType, IsVerified, IsDefault
```

```
Id                          AuthenticationType  IsVerified  IsDefault
--                          ------------------  ----------  ---------
contoso.com                 Federated           True        True
contoso.mail.onmicrosoft.com Managed            True        False
contoso.onmicrosoft.com     Managed            True        False
```

- **`Managed`** — Entra ID authenticates the user itself (PHS or PTA).
- **`Federated`** — Entra ID redirects to an external STS.

For a federated domain, read the trust configuration:

```powershell
Get-MgDomainFederationConfiguration -DomainId contoso.com |
  Select-Object IssuerUri, PassiveSignInUri, SigningCertificateUpdateStatus, NextSigningCertificate
```

**Two things to check every time:**

1. **`IssuerUri`** — must match the `Issuer` in incoming tokens exactly. A mismatch after a rebuild
   is a total outage for that domain.
2. **Is `NextSigningCertificate` populated?** If it is empty and expiry is close, §5 is about to
   happen to you.

---

## 5. Certificate rollover — the outage that recurs annually

AD FS uses three certificates. Only one causes most incidents:

| Certificate | Purpose | Default life |
|---|---|---|
| **Token-signing** | ⭐ Signs every token | **1 year**, auto-rolled |
| Token-decrypting | Decrypts inbound tokens | 1 year |
| Service communication (TLS) | HTTPS on the endpoint | Your CA's lifetime |

With `AutoCertificateRollover` enabled, AD FS generates a new self-signed token-signing certificate
**before** expiry and publishes it in federation metadata. Entra ID is supposed to pick it up
automatically.

**How it fails in practice:**

- Metadata polling is broken or blocked by a firewall, so Entra never learns the new key.
- Someone used a **CA-issued** certificate, which disables auto-rollover — now it is a manual,
  date-driven task that a departed engineer used to own.
- A partner relying party polls metadata **weekly**, so it breaks days *after* your successful
  rollover, when nobody connects the two events.

**Check and force:**

```powershell
Get-AdfsCertificate -CertificateType Token-Signing |
  Select-Object CertificateType, Thumbprint, IsPrimary, @{n='NotAfter';e={$_.Certificate.NotAfter}}

Update-MgDomainFederationConfiguration -DomainId contoso.com   # push new metadata to Entra now
```

> Put token-signing expiry in a **calendar with an owner**, not a monitoring dashboard nobody reads.
> This single control prevents the most predictable outage in hybrid identity.

---

## 6. Golden SAML — why this is a security topic

Steal the **token-signing private key** and you can forge a token asserting *any* user, including a
Global Administrator, with **any** claims — including a claim that MFA was performed.

```
Attacker with the signing key
      │
      ├─ forges a SAML token for admin@contoso.com
      ├─ asserts  multipleauthn  (i.e. "MFA already done")
      │
      ▼
Entra ID validates the signature — it is genuine — and issues real tokens
```

What makes it severe:

- **No authentication occurs**, so there is no AD logon event and no failed-sign-in trail.
- **MFA is bypassed** by asserting it, not by defeating it.
- **Password resets do not help.** Neither does disabling the account upstream.
- It persists until the **certificate is rotated and the trust re-established**.

This is not theoretical — it was used in the SolarWinds/Solorigate intrusions. The AD FS server is
therefore **Tier 0**, exactly like a domain controller ([`../ad-ds/`](../ad-ds/) §7).

**Detection and hardening:**

- Store keys in an **HSM** where the private key cannot be exported.
- Alert on any AD FS token-signing configuration change, and on sign-ins claiming MFA with no
  corresponding MFA record.
- Ship the AD FS logs to Sentinel. If AD FS logs are not collected, Golden SAML is invisible.
- **Migrating to PHS removes this attack surface entirely.** That is the strongest security
  argument for migration, and it is more persuasive to a CISO than any availability argument.

---

## 7. Migrating off AD FS

**Staged Rollout** is the mechanism: move selected groups to cloud authentication *while the domain
stays federated*, so you can test with real users and roll back per group.

```
Federated domain
   │  Staged Rollout: pilot group → PHS       (domain still Federated)
   │  validate, expand
   ▼
Convert the domain to Managed                 (cutover)
   │
   ▼  Decommission AD FS only after every relying party has moved
```

Order that avoids the usual disasters:

1. **Enable PHS first, even while federated.** It is supported alongside federation and gives you a
   working fallback if AD FS fails. There is no good reason not to have it.
2. **Inventory every relying party.** `Get-AdfsRelyingPartyTrust` — Entra ID is one of many. Each
   other application must be migrated to Entra or repointed.
3. **Run Staged Rollout** with a pilot group.
4. **Convert the domain**, then verify `AuthenticationType` is `Managed`.
5. **Decommission last.**

```powershell
Get-AdfsRelyingPartyTrust | Select-Object Name, Identifier, Enabled
```

> **Before converting, confirm at least one cloud-only break-glass account on
> `.onmicrosoft.com`.** ⭐ Federation converts the *domain*. If federation breaks and every admin
> uses a federated UPN, nobody can sign in to fix it. A `.onmicrosoft.com` account never redirects
> to AD FS — that is precisely why it is the escape hatch.

---

## 8. Customer discovery questions

1. Which domains are `Federated` versus `Managed`?
2. Is **PHS enabled as a fallback** even though federated? *(If not, that is a same-week fix.)*
3. When does the **token-signing certificate** expire, is auto-rollover on, and **who owns the date**?
4. How many **relying parties** besides Entra ID? *(This sizes the migration, and the answer is
   usually higher than IT expects.)*
5. Are AD FS logs in the SIEM? Could you detect **Golden SAML**?
6. Is AD FS treated as **Tier 0** — same admin restrictions as a DC?
7. Are there cloud-only break-glass accounts on `.onmicrosoft.com`, excluded from CA, and tested?
8. Any custom **claims rules**? *(Each one is migration work — they do not port automatically.)*
9. What is the actual reason for federation today? *(Often "a regulator asked in 2016" and nobody
   re-checked. Sometimes it is genuine — smart card, or on-prem MFA.)*

---

## 9. Remember it

**Hook — "The app checks the seal; it never phones home."**

**Analogy — a stolen embossing seal.** Relying parties do not call AD FS to verify anything — they
check the **seal** on the document. Steal the seal and you emboss whatever you like, including
"this person completed MFA." Resetting everyone's password does nothing; you have to **re-cut the
seal** by rotating the token-signing certificate and re-establishing trust.

**The one thing:** validation is a **signature check**, not a callback. That single fact explains
Golden SAML, why there is no failed-logon trail, and why the signing key is Tier 0.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 10. Self-test

1. In step 7 of §3, does the application call AD FS to validate the token?
2. Why does that make the token-signing key so valuable?
3. What is Golden SAML, and why do password resets not remediate it?
4. Federation breaks and every admin UPN is `@contoso.com`. Who can still sign in?
5. Can PHS and federation be enabled at the same time? Why would you?
6. What does Staged Rollout let you do that a domain conversion does not?
7. Rollover succeeded, then a partner app broke three days later. Why?
8. Where do you look to size an AD FS migration properly?

<details>
<summary>Answers</summary>

1. **No.** It validates a **signature** against published metadata. No call-back occurs.
2. Anyone with the private key can **mint valid tokens for any user**, with no authentication and
   no log entry.
3. Forging SAML tokens with the stolen signing key — including asserting MFA was performed.
   Passwords are never used, so resetting them changes nothing. Rotate the certificate and
   re-establish trust.
4. Only a **cloud-only account on `.onmicrosoft.com`**, because that suffix never redirects to AD FS.
5. **Yes**, and you should — PHS is a supported fallback if the AD FS farm fails.
6. Move **selected groups** to cloud auth while the domain stays federated, with per-group rollback.
7. That partner polls federation **metadata on its own schedule** (often weekly) and had not yet
   picked up the new key.
8. `Get-AdfsRelyingPartyTrust` — every relying party, not just Entra ID, plus any custom claims rules.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — capture a real SAML token, decode it, identify `Issuer`, `Audience`, `NotOnOrAfter`
  and the MFA claim. ✗ AD FS itself is unrunnable without infrastructure — but token decoding is
  runnable today via any SAML app.
- **`break-fix/`** — let a token-signing certificate expire in a lab and document the exact error;
  recover with `Update-MgDomainFederationConfiguration`.
- **`security/`** — Golden SAML detection logic; AD FS Tier 0 admin-access review; break-glass
  accounts verified as cloud-only and CA-excluded.
- **`operations/`** — certificate expiry calendar **with a named owner**; relying-party inventory.
- **`architecture-decisions/`** — ADR: migrate to PHS, with the §6 security argument as the driver.
- **`customer-use-cases/`** — a staged-rollout migration plan for a real estate.
