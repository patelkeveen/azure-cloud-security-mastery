# PIM and Access Reviews

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (updated 2026-04-24).
> **SC-300 Domain 4 core.** Both features are **P2**. Full narrative in
> **[LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md](LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md)**.

---

## 1. What they are

**PIM** removes *standing* privilege: an administrator is **eligible** for a role and **activates**
it when needed, with MFA, justification, approval and a time limit. **Access reviews** periodically
ask a human to confirm existing access is still justified.

Together they answer the two questions every auditor asks: **"who can do this?"** and
**"who checked?"**

---

## 2. Why it exists

A Global Administrator account that is privileged 24/7 is privileged at 3am on a Sunday when its
owner is asleep and its token has been stolen. **Standing privilege is a window that is always open.**

> ✅ **"There's no difference in the access given to someone with a permanent versus an eligible role
> assignment."** Once activated, the power is identical. **The only difference is time** — and time
> is the entire control. It shrinks the window in which a stolen credential is useful from *always*
> to *the few hours someone deliberately opened it*.

PIM also produces the artifact governance actually needs: **every elevation has a requester, a
justification, an approver and a timestamp.**

---

## 3. The assignment matrix — draw this and you have operated PIM

Most people think the choice is "eligible vs active." ✅ It is a **2×2** — *type* × *duration*:

| | **Permanent** | **Time-bound** |
|---|---|---|
| **Eligible** | Can activate any time, indefinitely | ⭐ Can activate only between start/end dates |
| **Active** | ⭐ **Standing access — the thing PIM exists to eliminate** | Standing, but expires |

**Target state for humans: eligible + time-bound.** *Permanent active* should exist only for
break-glass (§8).

**Expiry is self-service** ✅: users **extend** before expiry and **renew** after it, both requiring
Global Administrator or Privileged Role Administrator approval. Administrators are not meant to be
managing expiry dates by hand.

---

## 4. ⭐ Who can manage what — the separation people get wrong ✅

| Scope | Can **manage** assignments | Can **view** |
|---|---|---|
| **Entra roles** | Privileged Role Administrator, Global Administrator | + Security Administrator, Global Reader, Security Reader |
| **Azure resource roles** | Subscription admin, resource **Owner**, **User Access Administrator** | ⚠ **Privileged Role Admins, Security Admins and Security Readers do NOT have this by default** |

> ⭐ **A Privileged Role Administrator cannot see Azure resource role assignments in PIM by default.**
> That is a deliberate separation between the directory plane and the resource plane — and it is why
> "we reviewed all privileged access" is often only half true. Ask which plane was reviewed.

**A safety net worth knowing** ✅: PIM **prevents removal of the last active Global Administrator
and the last Privileged Role Administrator**. You cannot lock the tenant out through PIM alone —
which is precisely why break-glass exists for the cases PIM *cannot* cover (§8).

---

## 5. Worked example — auditing standing privilege

**The first question in any tenant: who has standing access right now?**

```powershell
Connect-MgGraph -Scopes 'RoleManagement.Read.Directory','Directory.Read.All'

# ACTIVE (standing) directory role assignments
Get-MgRoleManagementDirectoryRoleAssignment -All -ExpandProperty Principal |
  ForEach-Object {
    [pscustomobject]@{
      Role      = (Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $_.RoleDefinitionId).DisplayName
      Principal = $_.Principal.AdditionalProperties.displayName
      Type      = $_.Principal.AdditionalProperties.'@odata.type' -replace '#microsoft.graph.',''
    }
  } | Group-Object Role | Sort-Object Count -Descending |
  Select-Object Name, Count
```

```
Name                             Count
-------------------------------  -----
Global Administrator                 9    <-- ⚠
Application Administrator            4
Security Reader                     11
Privileged Role Administrator        3
```

**Nine standing Global Administrators is the finding.** Microsoft's guidance is a small number, and
most of those nine will be dormant, service accounts, or people who left.

**Now compare against eligible assignments** — the ratio tells you whether PIM is real:

```powershell
Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All |
  Group-Object RoleDefinitionId | Measure-Object -Property Count -Sum |
  Select-Object @{n='EligibleAssignments';e={$_.Sum}}
```

> ⭐ **A tenant with PIM licensed, 9 permanent-active Global Admins and 2 eligible assignments has
> bought PIM and not deployed it.** That ratio — active versus eligible — is a one-line maturity
> measure, and it is far more honest than "yes we use PIM."

**Then read who actually elevated, and whether anyone justified it:**

```kusto
AuditLogs
| where TimeGenerated > ago(30d)
| where OperationName has "Add member to role completed (PIM activation)"
| extend Role      = tostring(TargetResources[0].displayName),
         Requester = tostring(InitiatedBy.user.userPrincipalName),
         Reason    = tostring(ResultReason)
| project TimeGenerated, Requester, Role, Reason
| sort by TimeGenerated desc
```

⚠ Operation names vary by role type and have changed over time. **Confirm the exact string in the
target tenant** before building a detection on it.

---

## 6. Activation settings — including the one that impresses

Per role you can require: **MFA**, **justification**, **approval** (named approvers), a **maximum
duration**, and **ticket information**.

Beyond those, activation can require a **Conditional Access authentication context** — so elevating
to Global Administrator demands a **passkey**, not a push notification.

```
Authentication context  c1  →  bound to a CA policy requiring phishing-resistant strength
                              ↓
PIM role setting: "On activation, require Conditional Access authentication context c1"
```

⭐ **This is the single most impressive control you can demo in an interview**, and it also fixes the
[`../conditional-access/`](../conditional-access/) §4 gap: CA policies targeting roles are evaluated
**only when a token is issued**, so requiring MFA *on activation* forces fresh evaluation at exactly
the moment privilege is granted.

**Approval is where PIM becomes governance rather than a speed bump.** Self-approval is common and
defeats the purpose — name approvers who are *not* the requester.

---

## 7. PIM for Groups, and workload identities

**PIM for Groups** makes *group membership* just-in-time. That is the workaround for everything
without native PIM support: a group granting a SaaS app role, an Azure RBAC assignment, an
on-premises-synced group. **P2, not an add-on.**

✅ **PIM assignments can target users, groups, service principals *and* managed identities.** That
matters more every year — see [`../service-principals/`](../service-principals/) and
[`../managed-identities/`](../managed-identities/). A service principal holding standing
`Directory.ReadWrite.All` is the same problem as a standing Global Admin, and almost nobody applies
governance to it.

---

## 8. ⚠ Licence expiry is a security event

When P2 or ID Governance lapses — **including a trial ending**:

| Assignment | What happens |
|---|---|
| Active **permanent** | Unaffected |
| Active **time-bound** | ⭐ **Becomes permanent** |
| **Eligible** | ⭐ **Removed entirely** |

**A lapsed licence silently converts time-bound admin access into standing admin access while
deleting the just-in-time path everyone relied on.** The tenant becomes *less* secure, quietly, on a
date nobody diarised.

> ⚠ **This will happen in your own lab tenant when the trial ends.** It is also a first-class
> discovery question: *"what is your P2 renewal date, and who watches it?"*

⚠ Licensing detail sits in the Entra ID Governance licensing documentation and moves — **verify per
capability** before quoting.

---

## 9. Access reviews — the hard part is the reviewer

| Reviewer | Good for | Failure mode |
|---|---|---|
| **Manager** | Broad recertification | ⭐ **Rubber-stamping** — managers rarely know what a group grants |
| Group / app owner | Access to *their* resource | May not know the person |
| **Self-review** | Cheap, wide | **Nobody removes their own access** |

**Two settings decide whether the exercise is real:**

1. **Auto-apply.** Without it, decisions are recorded and **nothing happens**. ⭐ This is the single
   most common reason an organisation "does access reviews" while access never changes.
2. **If reviewers don't respond.** Setting this to *Approve* makes the whole thing theatre. Choose
   **Remove** or **No change** and mean it.

**Licence counting is by reviewed population, not by reviewers.** A 500-member group reviewed by 3
people needs **503** licences — a costing mistake that appears in proposals.

---

## 10. Break-glass — specified, not improvised

```
✅ Two accounts (never one)
✅ Cloud-only, on *.onmicrosoft.com          ← never federates, never syncs
✅ PERMANENT ACTIVE Global Admin — and NOT PIM-eligible
✅ Excluded from EVERY Conditional Access policy
✅ No single-method MFA dependency
✅ Credentials split, physically secured
✅ Alert on ANY sign-in
✅ Tested on a schedule, with the date recorded
```

> ⭐ **The property people get wrong is "not PIM-eligible."** The situations where you need
> break-glass are exactly the situations where PIM is unavailable, misconfigured, or its licence has
> lapsed (§8). An eligible break-glass account is not a break-glass account.

**Alert on any sign-in** — this is one of the highest-signal detections in a tenant, because the
expected volume is zero:

```kusto
SigninLogs
| where TimeGenerated > ago(1d)
| where UserPrincipalName in ("bg1@contoso.onmicrosoft.com","bg2@contoso.onmicrosoft.com")
| project TimeGenerated, UserPrincipalName, IPAddress, ResultType, AppDisplayName
```

---

## 11. What breaks

**PIM licensed but not deployed.** Nine permanent-active Global Admins and two eligible assignments.

**Self-approval.** Approval that the requester can grant themselves is a speed bump, not a control.

**No auto-apply on access reviews.** Decisions recorded, access unchanged.

**"If reviewers don't respond → Approve."** Theatre.

**Break-glass accounts that are PIM-eligible**, federated, or CA-included.

**Only the directory plane reviewed.** §4 — Azure resource roles are governed separately and are
invisible to Privileged Role Administrators by default.

**Licence lapse unwatched.** §8 — silently converts to standing access.

**Ignoring workload identities.** A service principal with standing `Directory.ReadWrite.All` is
effectively a standing Global Admin.

**Activation without MFA on activation.** Misses the CA re-evaluation opportunity in §6.

---

## 12. Customer discovery questions

1. How many **permanent active** privileged assignments exist, versus **eligible**? *(§5 — the ratio
   is the maturity measure.)*
2. How many standing **Global Administrators**?
3. Does activation require **MFA, justification and approval** — and can requesters self-approve?
4. Is an **authentication context** bound to activation for the highest roles?
5. Were **Azure resource roles** reviewed too, or only directory roles? *(§4.)*
6. Do access reviews have **auto-apply** on, and what is the no-response default?
7. What is the **P2 renewal date**, and who watches it? *(§8.)*
8. Are there **two** break-glass accounts, cloud-only, **not PIM-eligible**, CA-excluded, and when
   were they last **tested**?
9. Is there an alert on break-glass sign-in?
10. Are **service principals and managed identities** covered by any governance at all?

---

## 13. Remember it

**Hook — the 2×2: type × duration.** *Eligible/Active* × *Permanent/Time-bound*. Target state:
**eligible + time-bound**. Break-glass: **permanent active, never eligible**.

**Analogy — a key cabinet, not a key ring.** Standing privilege is everyone carrying the master key
permanently. PIM puts the key in a **signed-out cabinet**: you say why you need it, someone
countersigns, and it goes back automatically. **The key is identical either way — the control is the
sign-out sheet and the clock.** And the break-glass key is the one in the smash-glass box on the
wall, because a cabinet you cannot open is no use in a fire.

**The one thing:** ⭐ **a lapsed licence makes the tenant less secure, silently.** Time-bound active
assignments **become permanent** and eligible assignments **are deleted** — so the just-in-time path
vanishes while standing privilege hardens. Nobody is alerted. That single behaviour is why
"what is your renewal date and who watches it?" is a real discovery question.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 14. Self-test

1. Draw the assignment matrix. What is the target state for humans, and for break-glass?
2. Is there any difference in access between a permanent and an activated eligible assignment?
3. Who can manage Azure resource role assignments in PIM, and who **cannot see them by default**?
4. What happens to eligible and time-bound-active assignments when P2 lapses?
5. Which single access review setting most often makes the exercise pointless?
6. How are access review licences counted?
7. Why must break-glass accounts **not** be PIM-eligible?
8. How does requiring MFA on activation fix a Conditional Access gap?
9. What does a ratio of 9 active to 2 eligible assignments tell you?
10. Which non-human principals can PIM govern?

<details>
<summary>Answers</summary>

1. **Eligible/Active × Permanent/Time-bound.** Humans → **eligible + time-bound**. Break-glass →
   **permanent active, not eligible**.
2. **None.** Once activated the access is identical — the only difference is **time**.
3. Subscription admins, resource **Owners**, **User Access Administrators**. **Privileged Role
   Administrators, Security Administrators and Security Readers cannot view them by default.**
4. Time-bound **active becomes permanent**; **eligible assignments are removed entirely**.
5. **Auto-apply off** — decisions are recorded and nothing changes. (Closely followed by
   "no response → Approve".)
6. By **reviewed population**, not reviewers — 500 members + 3 reviewers = **503**.
7. Because you need them exactly when PIM is unavailable, misconfigured, or unlicensed.
8. CA policies targeting roles are evaluated **only at token issuance**; requiring MFA on activation
   forces fresh evaluation at the moment privilege is granted.
9. **PIM is licensed but not deployed.**
10. **Service principals and managed identities** (as well as users and groups).

</details>

---

## 15. Evidence this topic needs

- **`lab/`** — make yourself eligible, activate, and **decode the token to find `wids`**
  ([Layer 1](../oauth-oidc-saml-and-api-auth/LAYER-1-IDENTITY-PROTOCOLS.md) §4); bind activation to
  an authentication context requiring a passkey. ✗ **Requires Entra ID P2.**
- **`break-fix/`** ⭐ — run an access review with **auto-apply ON** and no-response = **Remove**;
  deliberately ignore one decision and watch that user lose access. **Then run the same review with
  auto-apply off and prove nothing happens.** The two side by side are the lesson.
- **`security/`** — the §5 standing-privilege report before and after; break-glass alert rule
  deployed; workload identities with standing privileged permissions.
- **`operations/`** — break-glass test procedure with dates; PIM approval workflow with named
  approvers; **P2 renewal date with an owner**.
- **`architecture-decisions/`** — ADR: which roles require approval and authentication context, and
  the standing-privilege exceptions with justification.
- **`customer-use-cases/`** — §12 answered against a real tenant.
