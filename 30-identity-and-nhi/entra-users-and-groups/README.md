# Entra Users and Groups

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (role-assignable groups updated 2026-06-23).
> **SC-300 Domain 1 core.** Full narrative in
> **[LAYER-2-DOMAIN-1-USER-IDENTITIES.md](LAYER-2-DOMAIN-1-USER-IDENTITIES.md)**.
> Lab seeder: **[Seed-LabTenant.ps1](Seed-LabTenant.ps1)**.

---

## 1. What it is

The directory objects everything else attaches to. **Get the object model wrong and every downstream
control inherits the error** — Conditional Access assignment, licence allocation, access review
scope, role assignment.

---

## 2. Source of authority — the concept that explains half the tickets

| Source | Edited where | Consequence |
|---|---|---|
| **Cloud** | Entra | Fully editable |
| **Windows Server AD** | On-premises | ⭐ **Most attributes read-only in Entra** |
| **External / B2B** | Partner's home tenant | You hold a stub; **they own the credential** |

A synced user showing greyed-out fields is not broken. **Entra is refusing to create a divergence it
cannot reconcile.** Half of all "why can't I change this?" questions are a source-of-authority
answer. See [`../../35-active-directory-and-hybrid-identity/entra-connect-sync/`](../../35-active-directory-and-hybrid-identity/entra-connect-sync/).

---

## 3. Users — the fields that bite

- **`UserPrincipalName` ≠ `mail` ≠ `proxyAddresses`.** Sign-in uses UPN; mail routing uses
  proxyAddresses. Assuming they match produces *"can't sign in but receives email fine."*
- **`UsageLocation` is mandatory before licensing** — and the error does not say so.
- **Soft delete is 30 days.** Restore preserves the `oid`; **recreation does not**, which is why
  restore works and recreate silently breaks every prior grant.
- ⭐ **`oid` is the only stable identifier.** UPNs change; guests are `#EXT#`-mangled. **Correlate on
  `oid`** — in KQL, in scripts, everywhere.

```powershell
# First move in any "I deleted the wrong account" incident
Get-MgDirectoryDeletedItemAsUser -All |
  Select-Object Id, UserPrincipalName, DeletedDateTime |
  Sort-Object DeletedDateTime -Descending
Restore-MgDirectoryDeletedItem -DirectoryObjectId <id>
```

---

## 4. Groups

| | Security group | M365 group |
|---|---|---|
| Purpose | Access control | Collaboration (mailbox, site, Teams) |
| Nesting | Yes | **No** |
| Has a mailbox | No | Yes |

**Dynamic membership** (P1) deserves more respect than it gets:

```
(user.department -eq "Engineering")
(user.department -eq "Sales") -and (user.country -eq "India")
(user.extensionAttribute1 -startsWith "CONTRACTOR")
```

Four things bite people:

1. Evaluation is **asynchronous** — minutes at small scale, far longer at tens of thousands.
   **Check processing state before debugging syntax.**
2. You **cannot manually add or remove members.** The rule is the only authority.
3. It requires **P1**.
4. ⭐ **A perfect rule over an unpopulated attribute returns an empty group** — which in hybrid
   estates is a *sync* problem wearing a *groups* costume.

---

## 5. ⭐ Role-assignable groups — the rules, verified

Assigning roles to groups is the right pattern. The restrictions exist because it is also an
escalation path, and Microsoft's own example is the clearest statement of why:

> An Exchange administrator who can modify dynamic membership groups could **add themselves** to
> `Contoso_User_Administrators` — a group assigned the User Administrator role — and thereby become
> a User Administrator. **An administrator elevates their privilege in a way you did not intend.**

Hence these rules ✅:

| Rule | Detail |
|---|---|
| **`isAssignableToRole` is immutable** | Set **only at creation**. You cannot convert an existing group. |
| **Creator must be Privileged Role Administrator** | At minimum |
| ⭐ **Membership must be Assigned — never dynamic** | Precisely to prevent the escalation above |
| ⭐ **No nesting** | A group cannot be a member of a role-assignable group |
| **Max 500 per tenant** | A real ceiling worth planning against |
| ⭐ **Graph needs `RoleManagement.ReadWrite.Directory`** | **`Group.ReadWrite.All` will not work** |
| ⭐ **Changing members' credentials needs Privileged Authentication Administrator** | Resetting a password or MFA for a member/owner is itself privileged |
| **Cannot assign Entra roles to on-premises (synced) groups** | Cloud groups only |
| Soft delete | 30 days; **group owners can restore** |

> ⭐ **Two of these are the ones that separate people who have used the feature from people who have
> read about it:** `Group.ReadWrite.All` silently failing on role-assignable group membership, and
> needing **Privileged Authentication Administrator** to reset a member's password. The second
> exists so a Helpdesk Administrator cannot reset the password of someone in a privileged group and
> inherit their access.

**Create one properly:**

```powershell
Connect-MgGraph -Scopes 'RoleManagement.ReadWrite.Directory'

New-MgGroup -DisplayName 'SEC-Role-HelpdeskAdmins' `
            -MailEnabled:$false -MailNickname 'sec-role-helpdeskadmins' `
            -SecurityEnabled:$true `
            -IsAssignableToRole:$true          # ⭐ cannot be added later
```

**Audit which groups hold roles — a first-visit query:**

```powershell
Get-MgGroup -Filter "isAssignableToRole eq true" -ConsistencyLevel eventual -CountVariable c -All |
  Select-Object DisplayName, Id, @{n='Members';e={ (Get-MgGroupMember -GroupId $_.Id -All).Count }}
"Role-assignable groups: $c of 500"
```

```
DisplayName                Id                                    Members
-------------------------  ------------------------------------  -------
SEC-Role-HelpdeskAdmins    8f2c...                                     14
SEC-Role-GlobalAdmins      1a7e...                                      3
Role-assignable groups: 12 of 500
```

**Then pair it with PIM** — make the group *eligible* rather than standing, and ⚠ **require approval
for eligible member assignments**: Microsoft notes explicitly that a Helpdesk Administrator can reset
an eligible user's password, so activation without approval leaves an escalation path open. See
[`../pim-and-access-reviews/`](../pim-and-access-reviews/).

---

## 6. Group-based licensing — elegant, with sharp edges

Assign licences to a group; membership drives allocation. The edges:

- **Conflicts** when two licences grant the same service plan
- ⭐ **Removing a user from the group removes the licence**, which **deletes service data** after the
  grace period

> **An offboarding automation that drops group membership is also deleting mailboxes.** That is
> usually intended — but only usually, and it should be a decision rather than a side effect.

`UsageLocation` must be set first, or assignment silently fails for those users.

---

## 7. Administrative units — delegation without tenant-wide power

An AU scopes administrative permissions to a subset of users, groups or devices — "Helpdesk
Administrator, but only for the UK."

Without AUs, delegating password reset means granting it **tenant-wide**, including over
administrators. AUs are the answer to *"we want regional IT to help their own users and nobody
else's."*

⚠ **Restricted management AUs** exist for the stronger case — protecting objects so that *only*
specified admins can manage them, even against tenant-wide roles. Verify current capability and
licensing before designing around them.

---

## 8. What breaks

**Assuming UPN and mail match.** §3.

**Debugging dynamic-group syntax** when the problem is evaluation latency or an unpopulated attribute.

**Deleting instead of restoring** — losing the `oid` and every grant tied to it.

**Forgetting `UsageLocation`** and misreading the licensing error.

**Trying to make an existing group role-assignable.** ⭐ Impossible — `isAssignableToRole` is immutable.

**Using `Group.ReadWrite.All`** to manage role-assignable group membership. It fails; you need
`RoleManagement.ReadWrite.Directory`.

**Making a role-assignable group dynamic.** Not permitted — and the escalation scenario in §5 is why.

**Assigning an Entra role to a synced on-premises group.** Not supported.

**Offboarding by group removal** without realising licences and data go with it.

**Correlating on UPN in scripts or KQL.** Use `oid`.

---

## 9. Customer discovery questions

1. How many **role-assignable groups** exist, and how close to the **500** limit?
2. Are Entra roles assigned to **users or groups**? Are those groups PIM-eligible?
3. Do eligible group assignments **require approval**? *(§5 — Helpdesk Admin escalation.)*
4. Are dynamic groups used for anything privileged? *(They cannot be role-assignable — check nobody
   worked around it.)*
5. Is **group-based licensing** in use, and does offboarding understand the data deletion?
6. Are **administrative units** used for regional delegation, or is everything tenant-wide?
7. How are deleted users handled — **restore** or recreate?
8. Do scripts and detections correlate on `oid` or on UPN?
9. Is `UsageLocation` set as part of joiner automation?

---

## 10. Remember it

**Hook — "Source of authority decides what you can edit."** Cloud → editable. Synced → read-only in
Entra. Guest → their tenant owns it.

**Analogy — a passport office, not a spreadsheet.** The `oid` is the **passport number**: it never
changes, and every visa (role, licence, grant) is stamped against it. The UPN is the **name in the
passport** — it changes with marriage or rebrand and nothing else moves. **Restore a deleted person
and their passport number comes back with them; issue a new passport and every visa is void.** That
is exactly why restore works and recreate silently breaks everything.

**The one thing:** ⭐ **`isAssignableToRole` can only be set at creation and never changed.**
Role-assignable groups must be **Assigned**, never dynamic; cannot be nested; cap at **500**; and
their membership needs **`RoleManagement.ReadWrite.Directory`**, not `Group.ReadWrite.All`. Every one
of those restrictions exists to close the same escalation path — an admin who can influence group
membership inheriting a role they were never granted.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 11. Self-test

1. Why are some attributes read-only on a synced user?
2. Which identifier should scripts and KQL correlate on, and why not UPN?
3. What is preserved by restoring a deleted user that recreation loses?
4. Can you make an existing group role-assignable?
5. Why can a role-assignable group not use dynamic membership?
6. Which Graph permission manages role-assignable group membership — and which one silently fails?
7. Which role is required to reset the password of a member of a role-assignable group, and why?
8. What is the tenant cap on role-assignable groups?
9. What happens to licences and data when a user leaves a licensing group?
10. A perfect dynamic rule returns an empty group. Most likely cause in a hybrid tenant?

<details>
<summary>Answers</summary>

1. **Source of authority is on-premises AD.** Entra refuses a divergence it cannot reconcile.
2. **`oid`** — UPNs change and guests are `#EXT#`-mangled.
3. **The `oid`**, and therefore every role assignment, licence and grant tied to it.
4. **No.** `isAssignableToRole` is **immutable** and set only at creation.
5. Automated population could add an unwanted account, **elevating an administrator who can modify
   the rule** into the assigned role.
6. **`RoleManagement.ReadWrite.Directory`.** **`Group.ReadWrite.All` does not work.**
7. **Privileged Authentication Administrator** — so a lesser admin cannot reset a privileged member's
   credentials and inherit their access.
8. **500 per tenant.**
9. The licence is removed and **service data is deleted after the grace period**.
10. **The attribute is unpopulated** — usually a sync/attribute-flow problem, not a rule problem.

</details>

---

## 12. Evidence this topic needs

- **`lab/`** — run [`Seed-LabTenant.ps1`](Seed-LabTenant.ps1); create a dynamic group and **time**
  the membership update; create a role-assignable group and attempt to make it dynamic.
- **`break-fix/`** ⭐ — delete a user, restore from soft delete, and **prove the `oid` is unchanged**;
  then create a same-named user and prove every prior grant is gone. Two commands, permanent lesson.
- **`security/`** — role-assignable group inventory with member counts; groups holding privileged
  roles without PIM; confirmation that no privileged group is dynamic.
- **`operations/`** — bulk operations with server-side `-Filter`, throttling backoff, idempotency;
  joiner automation that sets `UsageLocation`.
- **`architecture-decisions/`** — ADR: group naming and the role-assignable group model; AU
  delegation boundaries.
- **`customer-use-cases/`** — §9 answered against a real tenant.
