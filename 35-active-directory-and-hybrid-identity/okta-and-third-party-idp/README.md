# Okta and Third-Party Identity Providers

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Contains a hard deadline roughly seven weeks out.** See §5.
> Sources checked 2026-08-10 on Microsoft domains; **confirm the dates in the Message Center before
> putting them in a customer plan.**

---

## 1. What it is

Two genuinely different architectures that people call the same thing:

| Pattern | Who authenticates | Entra's role |
|---|---|---|
| **A — Third-party as IdP** | Okta / Ping / ForgeRock | Entra **federates** the domain out and trusts their token |
| **B — Third-party as MFA** | Entra does primary auth; Duo/Okta Verify/RSA does the second factor | Entra owns the session, calls out for MFA |

Pattern A is a *federation* decision — mechanically the same as
[`../adfs-and-federation/`](../adfs-and-federation/), with Okta in place of AD FS. Pattern B is a
*Conditional Access* decision. Confusing them produces migration plans that solve the wrong problem.

---

## 2. Why these exist in Microsoft estates

Rarely a considered choice. Usually history:

- Okta arrived first, for SaaS SSO, before Entra ID was credible at it
- An acquisition brought a different IdP
- A security team standardised on Duo or RSA years ago
- Multi-cloud policy: "no single vendor owns identity"

That last one deserves respect rather than dismissal. But the honest counter-argument is worth
being able to make: **federating Entra out to a third party means their compromise is your
compromise, and you lose the Entra-native signals that depend on Entra performing the
authentication** — risk-based Conditional Access, Identity Protection, token protection.

Okta has itself been breached more than once. That is not a vendor smear; it is the reason "our IdP
is external" is a *risk-transfer* decision, not a risk-elimination one, and it should be documented
as such.

---

## 3. Pattern A — third-party as the identity provider

```
User → Microsoft 365
         │
         ▼
   Entra ID sees UPN suffix contoso.com  →  domain is FEDERATED
         │
         ▼
   redirect → Okta   (Okta authenticates, applies its own MFA)
         │
         ▼
   signed SAML/WS-Fed token → Entra ID → session issued
```

Identical trust model to AD FS, and it inherits **all** of the same properties, including
**Golden SAML** ([`../adfs-and-federation/`](../adfs-and-federation/) §6). Whoever holds the
third-party signing key can mint tokens for any user, asserting MFA, with no log in your tenant.

Check it exactly the same way:

```powershell
Connect-MgGraph -Scopes 'Domain.Read.All'
Get-MgDomain | Select-Object Id, AuthenticationType
Get-MgDomainFederationConfiguration -DomainId contoso.com |
  Select-Object IssuerUri, PassiveSignInUri, SigningCertificateUpdateStatus
```

`AuthenticationType = Federated` with an `IssuerUri` pointing at `okta.com` is the whole diagnosis.

**What you lose in this pattern:** sign-in risk and user risk detections degrade because Entra is
not performing the authentication, and Conditional Access grant controls that depend on Entra
knowing *how* the user authenticated become assertions you are simply trusting.

---

## 4. Pattern B — third-party MFA, and the deprecated way of doing it

Historically this was wired up with **Conditional Access custom controls**. Custom controls were
always a bolt-on, and the limitations were severe:

- The result **did not satisfy the MFA claim** in the token. So a custom-control MFA did not count
  as MFA for PIM activation, for Identity Protection remediation, or for other policies requiring MFA.
- Did not integrate with **sign-in risk** or **authentication strengths**.
- Effectively invisible to the rest of the Entra security model.

This produced tenants that believed they had MFA everywhere while Entra's own view disagreed —
a genuinely dangerous gap between the compliance report and reality.

---

## 5. ⚠ The deadline: custom controls → External Authentication Methods

**Checked 2026-08-10 against Microsoft-domain sources:**

| Date | Event |
|---|---|
| **30 September 2026** | ⭐ **Conditional Access custom controls retire** |
| **May 2027** | Custom controls reach **end of life** |

**That is roughly seven weeks away.** Any tenant still using custom controls for third-party MFA
needs migration to **External Authentication Methods (EAM)** now.

**Why EAM is a real fix rather than a rename:**

- OIDC-based and **first-class in the authentication methods policy**
- ✅ **Satisfies the MFA claim** — so it works with PIM, authentication strengths, and
  Identity Protection
- Configured per method, targetable at groups, and visible in sign-in logs like any other method

### Find out whether you are affected — run this first

Custom controls appear inside a Conditional Access policy's grant controls as
`customAuthenticationFactors`. Enumerate every policy and surface them:

```powershell
Connect-MgGraph -Scopes 'Policy.Read.All'

Get-MgIdentityConditionalAccessPolicy -All |
  Where-Object { $_.GrantControls.CustomAuthenticationFactors.Count -gt 0 } |
  Select-Object DisplayName, State,
    @{n='CustomControls'; e={ $_.GrantControls.CustomAuthenticationFactors -join ', ' }},
    @{n='Operator';       e={ $_.GrantControls.Operator }}
```

```
DisplayName                    State    CustomControls           Operator
-----------                    -----    --------------           --------
Require Duo for Finance        enabled  RequireDuoMfa            OR
Legacy MFA - contractors       enabled  RequireDuoMfa            OR
```

**Any row returned is in scope for the 30 September 2026 retirement.** Empty output means you are
clear — record that as evidence rather than assuming.

Then check what EAM providers are already registered:

```powershell
Connect-MgGraph -Scopes 'Policy.ReadWrite.AuthenticationMethod'
Get-MgPolicyAuthenticationMethodPolicy |
  Select-Object -ExpandProperty AuthenticationMethodConfigurations |
  Select-Object Id, State
```

**Verify the fix actually worked** — the whole point is the MFA claim. After migrating, inspect a
real sign-in and confirm the method is recorded and MFA is satisfied:

```powershell
Connect-MgGraph -Scopes 'AuditLog.Read.All'
Get-MgAuditLogSignIn -Filter "userPrincipalName eq 'pilot@contoso.com'" -Top 1 |
  Select-Object CreatedDateTime, AuthenticationRequirement,
    @{n='Methods'; e={ $_.AuthenticationDetails.AuthenticationMethod -join ', ' }},
    @{n='Succeeded'; e={ $_.AuthenticationDetails.Succeeded -join ', ' }}
```

```
CreatedDateTime      AuthenticationRequirement  Methods                     Succeeded
---------------      -------------------------  -------                     ---------
2026-08-10 09:14:22  multiFactorAuthentication  Password, Duo (external)    True, True
```

`AuthenticationRequirement = multiFactorAuthentication` with the external method listed is the
proof. Under custom controls the external factor would not appear here — **which is exactly why
PIM never counted it.**

**What to do:**

1. Run the detection above and record the result.
2. Confirm the provider supports EAM (Duo, Okta, RSA, Ping and others published EAM integrations).
3. Configure the provider under **Authentication methods → External authentication methods**.
4. Run both in parallel on a pilot group, then remove the custom control grant.
5. **Verify the MFA claim is now satisfied** — this is the point of the exercise. Test a
   PIM activation that requires MFA; under custom controls it would have failed.

> **This is a concrete, dated, high-value finding you can raise with any customer this month.**
> Most estates using Duo or RSA with Entra have custom controls somewhere and have not noticed the
> retirement notice.

**Two adjacent retirements to raise in the same conversation** — same sources, same caveat:

- **1 September 2026** — passkeys become the default experience, auto-enabled for users currently
  enabled for SMS or voice.
- **1 February 2027** — **Microsoft-provided** SMS and voice delivery is retired. Organisations
  still needing them must configure customer-managed providers.

Anyone whose MFA story rests on SMS has a dated migration to plan, not a preference to defend.

---

## 6. When to keep a third-party IdP, and when to consolidate

**Keep it when:** it is genuinely the enterprise IdP for a large non-Microsoft application estate;
a merger has not completed; or there is a real regulatory or contractual requirement.

**Consolidate onto Entra when:** the third party exists only for Microsoft 365 SSO (common, and
pure cost); you want risk-based Conditional Access and Identity Protection to actually work; or the
licence is being paid for twice.

The migration is the same shape as the AD FS one — **Staged Rollout, then convert the domain to
managed** ([`../hybrid-coexistence/`](../hybrid-coexistence/) §5). Enable PHS first so a fallback
exists.

> **The cost argument usually wins the meeting.** Many organisations pay Okta for SSO to Microsoft
> 365 while already owning Entra ID P1/P2 through their M365 licensing. Naming that number is more
> persuasive than any architecture diagram.

---

## 7. What breaks

**Third-party IdP outage = total outage**, exactly as with AD FS. Cloud-only break-glass accounts
on `.onmicrosoft.com` are mandatory, because that suffix never federates out.

**MFA claim gaps.** Under custom controls, PIM activation requiring MFA fails even though the user
"did MFA". People raise this as a PIM bug for years. It is not.

**Double MFA.** Okta prompts, then Entra prompts, because both were configured independently and
neither trusts the other. Users route around it, and the fix is a design decision about which
system owns MFA — not a support ticket.

**Provisioning drift.** If Okta provisions users into Entra via SCIM *and* Connect Sync syncs the
same users from AD, you get conflicts and duplicates. Pick one source of authority. See
[`../source-anchor-and-matching/`](../source-anchor-and-matching/).

---

## 8. Customer discovery questions

1. Is the third party the **IdP** (Pattern A) or an **MFA provider** (Pattern B)? *(Establish this
   first — everything else depends on it.)*
2. ⭐ **Are Conditional Access custom controls in use?** If yes, what is the plan before
   **30 September 2026**?
3. Does third-party MFA currently **satisfy the MFA claim**? *(Test a PIM activation. Most are
   surprised.)*
4. Who holds the third-party **token-signing key**, and is it in an HSM?
5. Are third-party IdP logs in your SIEM, or only in their console?
6. Cloud-only break-glass accounts on `.onmicrosoft.com`, excluded from CA, tested?
7. What is the third-party IdP actually delivering that Entra ID P1/P2 — already paid for — does not?
8. Any SMS or voice MFA still in use? *(§5 dates.)*
9. Is anything provisioned by **both** SCIM and directory sync?

---

## 9. Remember it

**Hook — "Custom controls never claimed MFA."**

**Analogy — a bouncer whose stamp the club does not recognise.** The user genuinely did MFA; the
external system genuinely verified it. But the stamp never appeared in the token, so PIM,
authentication strengths and risk remediation all behaved as though no MFA had happened. People
raised it as a PIM bug for years.

**The one thing:** **30 September 2026** — custom controls retire, EOL May 2027. Migrate to
**External Authentication Methods**, which does satisfy the MFA claim.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 10. Self-test

1. Pattern A versus Pattern B — what is the difference and why does it matter first?
2. Does Golden SAML apply to Okta-federated Entra? Why?
3. What is the retirement date for Conditional Access custom controls?
4. Why did custom-control MFA fail to satisfy PIM's MFA requirement?
5. What replaced custom controls, and what is the key improvement?
6. Okta is down. Who can sign in to Entra?
7. Why do sign-in risk detections degrade under Pattern A?
8. What happens when Okta SCIM and Connect Sync provision the same users?

<details>
<summary>Answers</summary>

1. **A** = third party is the IdP (a federation decision). **B** = third party provides MFA (a
   Conditional Access decision). They have different migrations and different risks.
2. **Yes.** The trust model is identical — Entra validates a **signature**, so the signing key
   holder can mint tokens asserting any user and any MFA state.
3. **30 September 2026**, end of life **May 2027**.
4. Custom controls were a bolt-on that never returned the **MFA claim** in the token, so anything
   requiring MFA — PIM activation, authentication strengths, risk remediation — did not see it.
5. **External Authentication Methods (EAM)** — OIDC-based, first-class in the authentication
   methods policy, and it **does** satisfy the MFA claim.
6. Only **cloud-only accounts on `.onmicrosoft.com`**, which never federate out.
7. Entra is not performing the authentication, so it lacks the signals; it is trusting an assertion
   rather than observing the sign-in.
8. Conflicts and duplicate objects. Choose one source of authority.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — configure an EAM provider and prove the **MFA claim is satisfied** by activating a
  PIM role that requires MFA. ✗ Requires Entra ID P2 — blocked on the current Office 365 E5 tenant.
- **`break-fix/`** — reproduce the custom-control gap: MFA succeeds but PIM activation refuses.
  **The most instructive single lab in this topic.**
- **`security/`** — third-party IdP signing-key custody; break-glass verification; SIEM ingestion
  of third-party sign-in logs.
- **`operations/`** — the custom-control migration plan with the **30 September 2026** date and a
  named owner.
- **`architecture-decisions/`** — ADR: retain or consolidate the third-party IdP, including the
  licence cost already sunk in Entra ID P1/P2.
- **`customer-use-cases/`** — an Okta-to-Entra consolidation, or a documented decision to keep Okta
  with the risk transfer stated explicitly.
