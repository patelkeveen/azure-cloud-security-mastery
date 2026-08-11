# Microsoft 365 Groups

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The substrate topic. Read this before any other M365 topic** — Teams, SharePoint, Planner and
> shared mailboxes are all views over this object.

---

## 1. ⭐ One object, many front doors

**Creating a Microsoft 365 Group provisions a set of resources at once:**

```
Microsoft 365 GROUP  (an Entra object with members and owners)
   ├─ ⭐ a SharePoint SITE          the files
   ├─ ⭐ a shared MAILBOX + calendar the conversations
   ├─ a Planner plan
   ├─ a OneNote notebook
   └─ optionally a TEAM             ⭐ a UI over all of the above
```

⭐ **So "creating a Team" creates a SharePoint site and a mailbox.** The person clicking the button is
usually not thinking of it that way, and neither is the governance process.

> ⭐ **Group membership is an authorisation decision, made by end users, at scale.** Adding someone to
> a Team grants them the files in a SharePoint site and the history of a mailbox. **That is the whole
> M365 security model in one sentence, and it is the inverse of Azure**
> ([`../../20-azure-platform/azure-rbac/`](../../20-azure-platform/azure-rbac/)), where an
> administrator grants and a user receives.

**Which is why the recurring M365 finding is different in kind:** Azure findings are *misconfiguration
by administrators*; ⭐ **M365 findings are accumulated grants by users**, each individually reasonable.

---

## 2. ⭐ The three group types people confuse

| Type | Can it hold members? | ⭐ Used for | Mail |
|---|---|---|---|
| **Security group** | yes | ⭐ **authorisation** — RBAC, CA, licensing | optionally |
| **Microsoft 365 Group** | yes | ⭐ **collaboration** — provisions the §1 set | yes |
| **Distribution list** | yes | mail only | yes |
| ⚠ **Mail-enabled security group** | yes | ⭐ both, and ⚠ **immutable in EXO** | yes |

⭐ **The mistake that matters: using a Microsoft 365 Group as a Conditional Access target.** It works,
and it means **anyone who can add a member to that Team has changed who your CA policy applies to** —
[`../../30-identity-and-nhi/conditional-access/`](../../30-identity-and-nhi/conditional-access/).

> ⭐ **Authorisation groups must not be user-managed.** A group that gates access should be
> security-type, owned by IT, and ideally **dynamic or governed by entitlement management**
> ([`../../30-identity-and-nhi/entitlement-management/`](../../30-identity-and-nhi/entitlement-management/)).

⚠ **Role-assignable groups** (`isAssignableToRole`) are a special case: they can hold Entra role
assignments, they cannot be dynamic, and ⭐ **their owners can effectively grant those roles** — so
group ownership becomes a privileged-access question.

---

## 3. Worked example — who can create, and what did they create

```powershell
Connect-MgGraph -Scopes 'Group.Read.All','Directory.Read.All','Policy.Read.All'

# ① ⭐ Can ANY user create a group? (default: yes)
$dirSettings = Get-MgBetaDirectorySetting -EA SilentlyContinue |
  Where-Object { $_.DisplayName -eq 'Group.Unified' }
$dirSettings.Values | Where-Object Name -in 'EnableGroupCreation','GroupCreationAllowedGroupId' |
  Select-Object Name, Value
```

```
Name                          Value
----------------------------  -----
EnableGroupCreation           true      <-- ⚠ every user can provision a site + mailbox
GroupCreationAllowedGroupId             <-- (empty: nobody is restricted)
```

⭐ **`EnableGroupCreation = true` means every user can create a SharePoint site and a mailbox on
demand.** That is not automatically wrong — restricting it pushes people to consumer tools, the same
trade as
[`../../60-ai-and-secure-ai/ai-governance/`](../../60-ai-and-secure-ai/ai-governance/) §4 — but **it
must be a decision, and it must come with an expiry policy.**

```powershell
# ② ⭐ Ownerless groups: nobody to ask, nobody to review, nobody to remove them
$rows = Get-MgGroup -All -Property Id,DisplayName,GroupTypes,Visibility,CreatedDateTime |
  Where-Object { $_.GroupTypes -contains 'Unified' } |
  ForEach-Object {
    $owners  = @(Get-MgGroupOwner  -GroupId $_.Id -EA SilentlyContinue)
    $members = @(Get-MgGroupMember -GroupId $_.Id -EA SilentlyContinue)
    [pscustomobject]@{
      Name = $_.DisplayName; Visibility = $_.Visibility
      Owners = $owners.Count; Members = $members.Count
      Created = $_.CreatedDateTime
    }
  }

"ownerless: {0} of {1}" -f @($rows | Where-Object Owners -eq 0).Count, @($rows).Count
$rows | Where-Object { $_.Owners -eq 0 } | Sort-Object Members -Descending | Select-Object -First 10
```

```
ownerless: 147 of 892

Name                     Visibility  Owners  Members  Created
-----------------------  ----------  ------  -------  ----------
Project Falcon           Public           0       84  2023-02-11   <-- ⚠⚠ public + ownerless
Redundancy Planning      Public           0        6  2024-09-03   <-- ⚠⚠⚠
```

⭐ **`Visibility = Public` on a Microsoft 365 Group means any user in the tenant can join it and read
its files and conversations — without asking anyone.** Combine that with ownerless and you have
content nobody governs, discoverable by everybody.

⭐ **Row two is the finding you rehearse for an interview**: a group named *Redundancy Planning*, set
Public, with no owner. **That is exactly the content that surfaces in
[`../../60-ai-and-secure-ai/sensitive-data-leakage/`](../../60-ai-and-secure-ai/sensitive-data-leakage/)
§2 the moment Copilot is enabled** — no permission changed, the difficulty of finding it just
disappeared.

---

## 4. Lifecycle — the only thing that stops sprawl

```powershell
# ⭐ Expiration policy: groups must be renewed or they are deleted
Get-MgGroupLifecyclePolicy | Select-Object GroupLifetimeInDays, ManagedGroupTypes, AlternateNotificationEmails
```

⭐ **An expiration policy is the single highest-value setting here**, because it converts *"nobody
will ever clean this up"* into *"an owner must say this is still needed."* ⚠ And it requires owners
to exist — which is why §3 ② comes first.

⚠ **Deleted groups are soft-deleted for 30 days**, and restoring one restores the site and mailbox
too. **That is a recovery feature and an exfiltration window**: a deleted group's content is still
recoverable by anyone who can restore it.

**Naming policy** (prefix/suffix and blocked words) is worth having for one security reason:
⭐ **it makes the environment and sensitivity legible in every log line and every sharing dialogue** —
the same argument as resource naming in
[`../../20-azure-platform/resource-groups-and-tags/`](../../20-azure-platform/resource-groups-and-tags/) §4.

---

## 5. ⭐ Sensitivity labels on the container

**Labels do not only classify documents — they configure the container:**

```
Label "Confidential – Internal"  applied to a GROUP/TEAM/SITE
   ├─ ⭐ privacy forced to Private
   ├─ ⭐ external guests blocked
   ├─ unmanaged-device access limited
   └─ the label is visible in the Teams header
```

⭐ **This is the highest-leverage control in M365 collaboration**, because it moves the decision from
*"did the site owner configure sharing correctly?"* to *"which label did they pick?"* — one choice, in
language a non-technical owner understands, that sets several technical settings at once.

⚠ Labels apply at creation and on change; ⭐ **existing containers need a remediation pass**, exactly
like Azure Policy's non-retroactivity
([`../../20-azure-platform/azure-policy/`](../../20-azure-platform/azure-policy/) §3).

---

## 6. What breaks

**Using a Microsoft 365 Group as a CA target.** §2 — ⭐ users change who the policy covers.

**Role-assignable group owners unreviewed.** §2 — ⭐ ownership becomes privileged access.

**Unrestricted creation with no expiry.** §3/§4 — sprawl with no end.

**Ownerless groups.** §3 — nobody to review or renew.

**Public visibility by default.** §3 — ⭐ any user joins and reads.

**No expiration policy.** §4 — the only thing that reverses sprawl.

**Assuming deletion is immediate.** §4 — 30-day soft delete, restorable.

**Labels applied only to new containers.** §5 — existing ones need remediation.

**Treating Teams, SharePoint and the mailbox as separate governance problems.** §1 — ⭐ one object.

**Restricting creation with no sanctioned alternative.** Users move to consumer tools.

---

## 7. Customer discovery questions

1. Can **every user** create a group, and is there an **expiration policy**? *(§3/§4.)*
2. How many groups are **ownerless**? How many are **Public**? *(§3 — run it.)*
3. Is any **Microsoft 365 Group** used as a Conditional Access or licensing target? *(§2.)*
4. Who owns the **role-assignable** groups?
5. Are **sensitivity labels** applied to containers, and were **existing** ones remediated? *(§5.)*
6. Is there a **naming policy** that makes sensitivity legible?
7. ⭐ Before enabling Copilot — have you listed **Public + ownerless** groups? *(§3.)*
8. What happens to a group when its owner leaves?

---

## 8. Remember it

**Hook — "A Team is a Group is a site is a mailbox."** One object, four front doors.

**Analogy — a serviced meeting room you booked without reading the contract.** ⭐ **You thought you
created a chat. You created a filing room, a post box and a shared calendar** — and the door policy is
whatever the person who clicked the button happened to choose. ⭐ **"Public" here does not mean
internet-public; it means anyone in the company can walk in, take a file and read the post** — which
is a very reasonable default for a book club and a poor one for redundancy planning.

**The one thing:** ⭐ **in M365, end users make authorisation decisions at scale.** Adding a member to
a Team grants a SharePoint site and a mailbox history; setting a group Public grants the whole
tenant. **Nothing is misconfigured — every individual decision was reasonable — and the aggregate is
an estate nobody designed.** That is why the M365 engagement is *"list what users have granted"*
rather than *"check what admins configured"*, and why the pre-Copilot review
([`../../60-ai-and-secure-ai/sensitive-data-leakage/`](../../60-ai-and-secure-ai/sensitive-data-leakage/))
is a permissions exercise.

**Runner-up:** ⭐ **never gate access with a group users can join.**

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. What does creating a Microsoft 365 Group actually provision?
2. ⭐ State the M365 authorisation model in one sentence, and contrast it with Azure.
3. Name the group types and say which belongs in a Conditional Access policy.
4. ⭐ Why is a Microsoft 365 Group a bad CA target?
5. What is special about role-assignable groups?
6. What does `Visibility = Public` mean, and what does it not mean?
7. Why are ownerless groups a governance dead end?
8. What is the highest-value lifecycle setting, and what does it depend on?
9. How long are deleted groups recoverable, and why is that dual-edged?
10. ⭐ What do container sensitivity labels configure, and what do they miss?

<details>
<summary>Answers</summary>

1. ⭐ A **SharePoint site, a shared mailbox and calendar**, a Planner plan, a OneNote notebook, and
   optionally a **Team**.
2. ⭐ **End users make authorisation decisions at scale** — group membership grants files and mail
   history. ⭐ In Azure an **administrator grants**; in M365 **users grant**.
3. Security group, Microsoft 365 Group, distribution list, ⚠ mail-enabled security group. ⭐ **Security
   groups** belong in CA.
4. ⭐ Because **anyone who can add a member to that Team changes who the policy applies to.**
5. They can hold **Entra role assignments**, cannot be dynamic, and ⭐ **their owners can effectively
   grant those roles**.
6. ⭐ **Any user in the tenant can join and read files and conversations.** It does **not** mean
   internet-public.
7. ⭐ **Nobody to review, renew or remove them** — any process that works by asking someone fails.
8. ⭐ **The expiration policy.** It depends on ⭐ **owners existing**.
9. **30 days**, and restoring restores the site and mailbox — ⭐ a recovery feature and a window in
   which deleted content is still retrievable.
10. ⭐ **Privacy, guest access, unmanaged-device access** on the container. ⚠ They apply at creation
    and change — ⭐ **existing containers need a remediation pass.**

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — the §3 ownerless/public sweep and the §4 lifecycle policy check. **Runnable today on
  the E5 licence with no Azure subscription** — one of the few labs currently unblocked.
- **`break-fix/`** ⭐ — create a Microsoft 365 Group, set it **Public**, put a file in it, then find and
  open that file **as an unrelated user who was never invited**. **Two minutes, and it makes the
  "users grant access" argument permanently concrete.** Then apply a container label and show the
  privacy setting forced.
- **`security/`** — ownerless and public group register; groups used as CA/licensing targets;
  role-assignable group owners; container label coverage including remediation of existing groups.
- **`operations/`** — expiration policy with owner attestation; ownerless-group reassignment runbook;
  naming policy.
- **`architecture-decisions/`** — ADR: authorisation groups are security-type and IT-owned;
  collaboration groups are user-created with expiry; container labels mandatory.
- **`customer-use-cases/`** — §7 answered; the "147 of 892 ownerless" figure as a Copilot-readiness
  headline.
