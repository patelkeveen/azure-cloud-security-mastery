# External Identities

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (updated 2026-06-15).
> **SC-300 Domain 1.** Depth in
> **[LAYER-2-DOMAIN-1-USER-IDENTITIES.md](../entra-users-and-groups/LAYER-2-DOMAIN-1-USER-IDENTITIES.md)**.

---

## 1. What it is

Letting people **outside your organisation** access your resources using **an identity they already
have** — a partner's work account, a Microsoft account, or a social identity.

⭐ **The first question is always: which tenant configuration?** ✅

| | **Workforce tenant** | **External tenant** |
|---|---|---|
| Contains | Your employees and resources | ⭐ **Only your app's customers** |
| Scenario | **B2B collaboration** with partners | **CIAM** — consumers and business customers |
| SSO to Microsoft 365 | ✅ Yes | ✗ **Not supported** |
| Branding default | Microsoft design | **Neutral**, fully customisable |
| Entitlement management | ✅ Supported | ✗ **Not applicable** |

**Guests in your employee directory ≠ customers of your app.** Conflating them produces designs
that cannot work.

---

## 2. ⚠ Azure AD B2C is closed to new customers ✅

> **Effective 1 May 2025, Azure AD B2C is no longer available for new customers to purchase.**

It is now explicitly **a legacy solution**. New CIAM builds use **External ID in an external
tenant**. Any tutorial, course or blog recommending B2C for a greenfield project is out of date —
and there are a great many of them.

⚠ Existing B2C tenants continue; migration guidance is a live topic. **Verify current status before
advising a customer with an existing estate.**

---

## 3. The three collaboration models ✅

```
B2B COLLABORATION      guest USER OBJECT created in your workforce directory
                       → manage like any user: groups, CA, access reviews

B2B DIRECT CONNECT     ⭐ NO user object created
                       → Teams shared channels; two-way trust; users stay in their tenant

CROSS-TENANT SYNC      one-way provisioning between your own tenants
                       → multitenant organisations; no invitation, no consent prompt
```

⭐ **B2B direct connect creates no guest object**, which is why searching your directory for a
shared-channel collaborator finds nothing. That surprises people mid-investigation.

**Cross-tenant access settings** govern all of it — inbound and outbound policies per organisation,
per group, per application.

---

## 4. ⭐ Trust settings — the feature that removes double MFA ✅

A guest whose home tenant already enforced MFA should not be challenged again by yours. Cross-tenant
access settings let you **trust MFA and device claims from the external user's home organisation**:

```
Guest signs in
   ├─ Trust settings ON  → Entra checks the incoming token for an MFA claim or device ID
   │                        → already satisfied → seamless access
   └─ Trust settings OFF → MFA challenge initiated in the GUEST'S HOME TENANT
```

> **Guests being MFA-challenged twice is the most common external-collaboration complaint**, and it
> is a cross-tenant access setting, not a Conditional Access problem. Knowing which knob to turn
> saves an afternoon of CA archaeology.

⚠ Trusting another tenant's MFA claim means **trusting their MFA posture**. That is a risk decision,
not a UX one — document it.

---

## 5. Worked example — auditing the guest estate

```powershell
Connect-MgGraph -Scopes 'User.Read.All','AuditLog.Read.All'

Get-MgUser -Filter "userType eq 'Guest'" -All -Property `
    UserPrincipalName,DisplayName,CreatedDateTime,SignInActivity,ExternalUserState |
  Select-Object DisplayName,
    @{n='Domain';e={ ($_.UserPrincipalName -split '#EXT#')[0] -replace '.*_','' }},
    @{n='State';e={ $_.ExternalUserState }},
    @{n='LastSignIn';e={ $_.SignInActivity.LastSignInDateTime }},
    CreatedDateTime |
  Sort-Object LastSignIn
```

```
DisplayName      Domain           State           LastSignIn           CreatedDateTime
---------------  ---------------  --------------  -------------------  -------------------
A. Contractor    oldvendor.com    Accepted        2024-02-11 09:14:02  2023-11-02 10:00:00  <-- ⚠
J. Partner       fabrikam.com     Accepted        2026-08-09 11:22:41  2025-04-18 14:30:00
K. Unknown       gmail.com        PendingAcceptance  (never)           2025-09-01 08:15:00  <-- ⚠
```

⭐ **Two findings in one query.** A contractor from a vendor relationship that ended, still holding
access 18 months after last sign-in. And a **`PendingAcceptance`** invite never redeemed — an
account that exists, may be in groups, and nobody owns.

**Then read the guest UPN format**, because it trips people up constantly:

```
j.partner_fabrikam.com#EXT#@contoso.onmicrosoft.com
└──────── original address, @ becomes _ ────────┘
```

⭐ **Filtering guests by email will fail.** Their `mail` and `UserPrincipalName` differ, and the UPN
is mangled. **Correlate on `oid`** — the same rule as
[`../entra-users-and-groups/`](../entra-users-and-groups/) §3.

**Who is inviting them?**

```kusto
AuditLogs
| where TimeGenerated > ago(90d)
| where OperationName == "Invite external user"
| extend Inviter = tostring(InitiatedBy.user.userPrincipalName),
         Invitee = tostring(TargetResources[0].userPrincipalName)
| summarize Invites = count(), Guests = make_set(Invitee, 5) by Inviter
| sort by Invites desc
```

---

## 6. Governing guests

**Entitlement management is the right tool** — access packages with expiry, approval and review, so
guest access is time-bounded by construction rather than by someone remembering. See
[`../entitlement-management/`](../entitlement-management/).

⚠ **Guest governance uses Monthly Active User (MAU) billing and requires an Azure subscription** ✅.
That is a different licensing model from employees and it surprises people at procurement.

**Self-service sign-up** lets guests onboard themselves through a user flow, optionally collecting
attributes — useful, and it needs a governance story or it becomes an uncontrolled front door.

---

## 7. What breaks

**Assuming B2C for a new CIAM project.** §2 — closed to new customers.

**Confusing workforce guests with external-tenant customers.** Different tenants, different features.

**Looking for a B2B direct connect user in your directory.** No object exists.

**Filtering guests by email.** §5 — the UPN is `#EXT#`-mangled.

**Double MFA prompts.** §4 — cross-tenant trust settings, not CA.

**Trusting another tenant's MFA without assessing their posture.**

**Guests never expiring.** No access package, no review, no departure trigger.

**`PendingAcceptance` invitations accumulating.** Accounts that exist but nobody redeemed.

**Expecting external tenants to SSO into Microsoft 365.** Not supported.

**Forgetting guest governance needs an Azure subscription for MAU billing.**

---

## 8. Customer discovery questions

1. Workforce guests, external tenant, or both? Any legacy **B2C**?
2. How many guests, and how many have **not signed in for 90+ days**?
3. Any **`PendingAcceptance`** invitations older than 30 days?
4. Who can **invite** guests — everyone, or a delegated set?
5. Are guests governed by **access packages** with expiry, or invited ad hoc?
6. Are **cross-tenant access settings** configured per partner, or left at default?
7. Is **MFA trust** enabled for any partner, and was their posture assessed?
8. Is **B2B direct connect** enabled, and with whom?
9. Is guest **MAU billing** configured with an Azure subscription?

---

## 9. Remember it

**Hook — "Workforce guests, external customers."** Two tenant configurations, and the first question
in every design.

**Analogy — a visitor badge versus a customer account.** **B2B collaboration** issues a visitor
badge: they appear in your reception log (a guest user object in *your* directory), you decide which
floors they reach, and the badge should expire. **External tenant CIAM** is a shop loyalty account:
they were never a visitor to your office at all, and they live in an entirely separate system.
**B2B direct connect is the trades entrance** — they come and go, no badge is ever issued, and
that's why you can't find them in the log.

**The one thing:** ⭐ **Azure AD B2C has been closed to new customers since 1 May 2025.** New CIAM
work uses **External ID in an external tenant**. A large amount of published training still
recommends B2C, and repeating that is a dated tell.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 10. Self-test

1. Two tenant configurations, and what each is for?
2. What is the purchase status of Azure AD B2C?
3. Which collaboration model creates **no** user object, and what is it used for?
4. Why can't you filter guests by email address?
5. A partner's users are prompted for MFA twice. Which setting fixes it, and what is the risk?
6. Which licensing model applies to governing guests, and what does it require?
7. Does an external tenant support SSO to Microsoft 365?
8. What does `ExternalUserState = PendingAcceptance` mean, and why does it matter?
9. Which tool time-bounds guest access by construction?

<details>
<summary>Answers</summary>

1. **Workforce** (employees + B2B guests) and **external** (CIAM for your app's customers).
2. **Closed to new customers since 1 May 2025** — a legacy solution. Use External ID in an external
   tenant.
3. **B2B direct connect** — Teams shared channels. Users stay in their own tenant.
4. Their UPN is **`#EXT#`-mangled** and differs from `mail`. **Correlate on `oid`.**
5. **Cross-tenant access trust settings** — trust MFA/device claims from the home tenant. The risk
   is that you are **trusting their MFA posture**.
6. **Monthly Active User (MAU)** billing, which **requires an Azure subscription**.
7. **No** — SSO only to apps registered in that external tenant.
8. The invitation was **never redeemed**. The account exists, may hold group memberships, and nobody
   owns it.
9. **Entitlement management** access packages, with expiry, approval and review.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — invite a guest; inspect the `#EXT#` UPN and `oid`; configure cross-tenant access
  settings with MFA trust and observe the prompt disappear.
- **`break-fix/`** ⭐ — filter guests by email, get nothing, then correlate on `oid` and succeed.
  Then leave an invitation unredeemed and find it in the §5 report.
- **`security/`** — the §5 stale-guest and pending-invitation report; who can invite; cross-tenant
  settings per partner with the MFA-trust decision documented.
- **`operations/`** — guest lifecycle via access packages; MAU billing configured.
- **`architecture-decisions/`** — ADR: workforce guests versus external tenant per scenario; any
  B2C migration position.
- **`customer-use-cases/`** — §8 answered against a real tenant.
