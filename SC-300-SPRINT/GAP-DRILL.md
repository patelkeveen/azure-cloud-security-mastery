# Gap drill — what the sprint labs never cover, and the exam does

> ⭐ **Why this file exists.** The 7-day sprint is **lab-driven**: it teaches what you can build in
> a trial tenant. The exam is **objective-driven** — it tests things you cannot lab without a
> domain controller, and a few you *could* lab but the sprint simply skipped.
> **Measured, not asserted:** `administrative unit` appears **0 times** in `SC-300-SPRINT/`,
> `password hash sync` **0 times**, `connected organization` **0 times**, `B2B direct connect`
> **0 times**. ⭐ **That is roughly 15–20% of the exam with no lab behind it.**
>
> **How to use it:** 40 minutes an evening, per the schedule in
> [`EXAM-COUNTDOWN.md`](EXAM-COUNTDOWN.md) §5. ⭐ **Cover the right-hand column and say the answer
> out loud.** Recognition is not recall, and the exam tests recall.

---

## 1. Administrative units — the sprint's biggest hole

⭐ **There is no `administrative-units` topic in this repo at all.** It is D1 content. Learn it here.

### The mechanism

An **administrative unit (AU)** is a container of users, groups and devices that a directory role
can be **scoped to**. Assign someone Password Administrator *at tenant scope* and they can reset
anyone's password. Assign the same role *scoped to the "India" AU* and they can reset only that
AU's members.

### ⭐ The distinction the exam is actually testing

```
CUSTOM ROLE          restricts WHAT actions       (verbs)
ADMINISTRATIVE UNIT  restricts WHICH objects      (nouns)
both together        a custom role assigned at AU scope
```

⭐ **Read the question for which half is being constrained.** "Helpdesk should reset passwords
**but only for Germany**" → the constraint is on *objects*, so it is an AU with a **built-in**
role. Reaching for a custom role there is the wrong answer and it is deliberately offered.

### The facts that get tested

| Fact | Detail |
|---|---|
| Nesting | ⭐ **AUs cannot be nested.** An object *can* belong to several AUs |
| Dynamic membership | Supported for **users and devices**; ⭐ **groups must be added manually** |
| Licence | Dynamic AU membership needs **P1** |
| Scopeable roles | User Admin, Helpdesk Admin, Password Admin, Authentication Admin, License Admin, Groups Admin *(not every role can be scoped)* |
| ⭐ **Restricted management AU** | Members can be modified **only** by admins scoped to that AU — ⭐ **tenant-level User Administrator is locked out**. Global Admin and Privileged Role Admin still manage the AU itself |

⭐ **Restricted management AUs are the answer to "protect the break-glass accounts from a
compromised helpdesk admin."** That is a very natural exam scenario and it connects straight to
your Day 1 work.

### Self-test

1. Regional helpdesk in three countries, each resetting only their own users. Fewest changes? →
   *Three AUs, Helpdesk Administrator scoped to each. No custom roles.*
2. Can you put an AU inside an AU? → *No.*
3. What stops a tenant-wide User Administrator editing your two break-glass accounts? →
   *Putting them in a **restricted management** AU.*

---

## 2. Least-privilege role selection

⭐ **The exam asks "which is the *least privileged* role that can do X" constantly.** Global
Administrator is almost always on offer and almost always wrong.

| Task | ⭐ Least-privileged role |
|---|---|
| Reset passwords for non-admin users | **Password Administrator** (or Helpdesk Administrator) |
| Create and manage Conditional Access policies | **Conditional Access Administrator** |
| Manage the **authentication methods policy** (tenant-wide) | ⭐ **Authentication Policy Administrator** |
| Reset MFA / manage auth methods for **non-admin** users | ⭐ **Authentication Administrator** |
| Same, for **admins including Global Admins** | ⭐ **Privileged Authentication Administrator** |
| Assign directory roles, configure PIM | **Privileged Role Administrator** |
| Manage all app registrations **and Application Proxy** | **Application Administrator** |
| Manage all app registrations, **no App Proxy** | ⭐ **Cloud Application Administrator** |
| Assign and remove licences | **License Administrator** |
| Create and manage groups | **Groups Administrator** |
| Access packages, access reviews, lifecycle workflows | **Identity Governance Administrator** |
| Read sign-in and audit logs | **Reports Reader** |
| Read security posture, Identity Protection reports | **Security Reader** |
| Remediate risky users, manage Identity Protection | **Security Operator** / Security Administrator |

### ⭐ The three that are deliberately confusable

```
Authentication POLICY Administrator   -> the TENANT POLICY. Which methods exist at all.
Authentication Administrator          -> PER-USER methods, non-admins only.
Privileged Authentication Admin       -> PER-USER methods, ANYONE, incl. Global Admins.
```

⭐ **Cue word: "policy" means tenant-wide; "reset this user's MFA" means per-user; "including
administrators" is the tell for the privileged variant.**

### Self-test

1. Enable passkeys tenant-wide, nothing else → *Authentication Policy Administrator.*
2. Clear a Global Admin's stale MFA registration → *Privileged Authentication Administrator.*
3. Publish an app through Application Proxy → *Application Administrator* — ⭐ Cloud Application
   Administrator cannot.

---

## 3. Hybrid identity — theory only, and that is fine

⭐ **You have no domain controller, so none of this is labbable, and the exam does not require you
to have labbed it.** ⚠ **Say "I know the decision model, I have not run Connect in production" in
an interview** — that reads as judgement. Implying otherwise collapses on the first follow-up.

### The three authentication choices

| | **PHS** password hash sync | **PTA** pass-through auth | **Federation** ADFS |
|---|---|---|---|
| Where the password is checked | ⭐ **In Entra** | ⭐ **On-prem, by an agent** | On-prem, by ADFS |
| Password stored in cloud? | A hash of a hash — ⭐ **not reversible** | **No** | **No** |
| ⭐ Survives an on-prem outage? | ⭐ **Yes** | ⭐ **No** | **No** |
| Leaked-credential detection | ⭐ **Yes — requires PHS** | No | No |
| Smart cards, third-party on-prem MFA, sign-in hour restrictions | No | No | ⭐ **Yes** |
| Infrastructure | Lowest | Agents (⭐ **install 3+ for HA**) | Highest — servers, WAP, certs |

### ⭐ Read the requirement, pick the column

```
"must keep working if the datacentre is down"        -> PHS
"passwords must never leave the premises"            -> PTA (or federation)
"we need leaked-credential risk detection"           -> PHS  (no hash, no detection)
"smart cards" / "third-party MFA on-prem"            -> Federation
"lowest cost and complexity"                         -> PHS
```

⭐ **PHS as a backup for PTA/federation is the recommended design** and a common right answer:
enable it alongside, so an on-prem failure degrades to cloud authentication instead of an outage.

### The supporting pieces

| Thing | What to know |
|---|---|
| **Seamless SSO** | Kerberos-based silent sign-in on domain-joined devices. ⭐ **Works with PHS and PTA; irrelevant to federation** (ADFS does its own). Creates the `AZUREADSSOACC` computer object — ⭐ **roll its key every 30 days** |
| **Password writeback** | Required for SSPR to reach on-prem AD. ⭐ **Supported with all three** auth methods |
| **Staged rollout** | ⭐ Move users **federation → cloud auth in batches**, without flipping the domain's federation setting. The safe migration answer |
| **Connect Sync vs Cloud Sync** | ⭐ **Cloud Sync**: lightweight agent, **multiple disconnected forests**, no device writeback, no Exchange hybrid writeback. ⭐ **Connect Sync**: full feature set — device writeback, group writeback, Exchange hybrid |
| **Sync interval** | Connect Sync default **30 min**; ⭐ **PHS syncs every 2 min** |

### Self-test

1. Two companies merged, forests do not trust each other, need sync fast → *Cloud Sync — it
   handles disconnected forests.*
2. Requirement: Identity Protection must flag leaked credentials. Currently PTA. → *Enable PHS.*
3. On-prem WAN dies. Who can still sign in to M365 — PHS, PTA or federation? → *PHS only.*

---

## 4. Groups, licensing and dynamic rules

### Dynamic membership rule syntax

```
user.department -eq "Sales"
user.userType -eq "Guest"
(user.country -eq "IN") and (user.jobTitle -startsWith "Engineer")
user.assignedPlans -any (assignedPlan.servicePlanId -eq "..." -and
                         assignedPlan.capabilityStatus -eq "Enabled")
```

Operators: `-eq -ne -startsWith -notStartsWith -contains -notContains -match -notMatch -in -notIn`
and the multi-value `-any` / `-all`. ⭐ **`-match` is a regex; `-contains` is not** — that pair is
tested.

⚠ **A group is user-based *or* device-based. You cannot mix `user.` and `device.` in one rule.**
Dynamic membership requires **P1**.

### ⭐ Role-assignable groups — the trap that is on your Day 4 lab

```
isAssignableToRole = true    ⭐ MUST be set AT CREATION. Cannot be added later.
membership type              ⭐ MUST be Assigned. Dynamic is NOT allowed.
who can manage it            Privileged Role Administrator / Global Administrator only
```

⭐ **"We need a dynamic group that gets the Helpdesk role" is impossible**, and the exam offers it.
Dynamic membership would let anyone who can edit user attributes grant themselves a privileged
role — the restriction is a security boundary, not an oversight.

### Group-based licensing

| Fact | Detail |
|---|---|
| Prerequisite | ⭐ **Usage location must be set** or assignment fails |
| Nested groups | ⭐ **Not supported** — members of a nested group do **not** inherit |
| Conflicts | Two service plans that cannot coexist → the user lands in **error** state; fix on the group |
| Not enough licences | Assignment fails and is reported on the group, not silently |

### Self-test

1. Dynamic group for the Helpdesk *role*? → *Not possible — role-assignable requires Assigned.*
2. Licence assigned to a parent group; child-group members get nothing. Why? → *Nested groups are
   not supported for group-based licensing.*
3. `-match` vs `-contains`? → *`-match` is regex; `-contains` is a substring/collection test.*

---

## 5. Entitlement management — connected organizations

⭐ **Zero mentions in the sprint.** Requires **Entra ID Governance / P2**.

```
CATALOG            container for resources (groups, apps, SharePoint sites)
ACCESS PACKAGE     a bundle of those resources + the policies to get them
POLICY             WHO may request, WHO approves, HOW LONG it lasts
CONNECTED ORG      ⭐ an external tenant or domain you will accept requests from
SPONSOR            the internal or external person who approves for that org
```

⭐ **A connected organization is what makes an access package requestable by people who are not
in your directory yet** — the external user is created *on approval*, not invited up front. That
inversion is the point: **governance first, guest object second.**

Its state is **configured** (you added it deliberately) or **proposed** (discovered because a user
from that domain already exists). Policies can target *specific* connected organizations, **all
configured** connected organizations, or **all users including new external users**.

### Self-test

1. Partner staff should request access themselves, approved by *their* manager, with a guest
   account created only if approved. → *Access package + connected organization with an external
   sponsor as approver.*
2. Difference between inviting a guest and this? → *Invite creates the object immediately with no
   lifecycle; the access package creates it on approval, with expiry and review attached.*

---

## 6. Consent, permissions, and the `scp` / `roles` split

Day 6 labs this — ⭐ **but the tenant *settings* around it are exam content the lab skips.**

```
scp    ⭐ DELEGATED     a user is present.
                       ⭐ effective rights = INTERSECTION(user's own rights, granted scope)
roles  ⭐ APPLICATION   no user. The app has the full stated permission.
                       ⭐ always requires admin consent
```

⭐ **The intersection is the whole idea.** A delegated `User.ReadWrite.All` held by an app a
*normal user* consented to does not let that user rewrite the directory — they never could. The
same permission as an **application** permission does, because there is no user to be limited by.

### The tenant settings

| Setting | Options that matter |
|---|---|
| **User consent** | Do not allow · ⭐ **Allow for verified publishers, low-impact permissions only** · Allow all |
| **Admin consent workflow** | Users *request*, designated reviewers approve. ⭐ **The answer to "stop users consenting but don't create a helpdesk ticket storm"** |
| **Permission classification** | Defines what counts as "low impact" for the middle option |
| **Group owner consent** | Whether group owners can consent on behalf of their group's data |

⚠ **Illicit consent grant attack:** a phishing link asks for delegated `Mail.Read`; the user
consents; the attacker reads mail with a legitimate token and ⭐ **a password reset does not
revoke it.** Revoke the *service principal's* grant. This is why user consent is restricted.

### Self-test

1. Least-privilege way to let users use new SaaS apps without a free-for-all → *Restrict user
   consent to verified publishers + low-impact, and enable the admin consent workflow.*
2. Ex-employee's password reset, but a rogue app still reads their mail. Why? → *The OAuth grant
   is independent of the password — revoke the consent/refresh tokens.*

---

## 7. External identities — cross-tenant access

### ⭐ Two different things called "external"

| | **B2B collaboration** | **B2B direct connect** |
|---|---|---|
| Object in your directory? | ⭐ **Yes — a Guest user** | ⭐ **No object at all** |
| How it is set up | Invitation + redemption | ⭐ **Mutual trust in cross-tenant access settings, both tenants** |
| What it is used for | Apps, Teams, SharePoint, access packages | ⭐ **Teams shared channels** |

⭐ **"The partner must not appear in our directory" is the tell for direct connect.**

### Cross-tenant access settings — the high-value bit

Default settings plus per-organization overrides, each with **inbound** and **outbound** rules.

⭐ **Trust settings are the exam favourite:**

```
Trust MFA from the other tenant       -> the guest's OWN MFA satisfies YOUR CA policy
Trust compliant device
Trust hybrid Entra joined device
```

⭐ **Without trust settings, a guest hitting a CA policy that requires MFA must re-register MFA in
*your* tenant** — a real onboarding failure, and the scenario is usually written as "guests
complain they must set up the Authenticator twice."

### External collaboration settings

| Setting | Detail |
|---|---|
| Guest user access | Same as members · **Limited** · ⭐ **Restricted** (most restrictive — cannot enumerate the directory) |
| Who can invite | Anyone · members · admins/specific roles only · no one |
| Domain allow/deny list | ⭐ **One or the other — never both at once** |
| Email OTP | Fallback authentication when the guest has no Entra or Microsoft account |

### Self-test

1. Partner engineers in a Teams shared channel, no guest accounts. → *B2B direct connect,
   configured in cross-tenant access settings on **both** tenants.*
2. Guests told to register MFA twice. Fix? → *Enable "trust MFA from Entra tenants" inbound for
   that organization.*
3. Can you run an allow list and a deny list together? → *No.*

---

## 8. ⭐ The ten one-liners to have cold on the morning

| | |
|---|---|
| CA grant controls, multiple selected | ⭐ **AND by default** — you must choose "require one" for OR |
| CA policy assignment | ⭐ **Exclusions always beat inclusions** |
| Report-only | Evaluates and logs, ⭐ **never blocks** |
| CAE | Near-real-time revocation on critical events — ⭐ **not the token lifetime setting** |
| PIM eligible vs active | ⭐ **Eligible = can activate. Active = holds it now** |
| Access review, no response | Outcome depends on the configured **"if reviewers don't respond"** action |
| Leaked credentials detection | ⭐ **Requires PHS** |
| Role-assignable group | ⭐ **Set at creation, Assigned membership only** |
| Restricted management AU | ⭐ **Tenant-scoped admins locked out** |
| Application permission | ⭐ **Always admin consent, no user context, no intersection** |

> ⭐ **The best single test:** explain any row above, out loud, to an imaginary junior engineer,
> without notes. ⭐ **Every "and then it sort of…" is a gap** — and it is the same test an
> interviewer applies.

> **Related:** [`EXAM-COUNTDOWN.md`](EXAM-COUNTDOWN.md) — the schedule that uses this file ·
> [`EXAM-DAY.md`](EXAM-DAY.md) · [`../RETENTION.md`](../RETENTION.md) §4 confusion pairs ·
> [`../SC-300-MASTERY-SYLLABUS.md`](../SC-300-MASTERY-SYLLABUS.md) — full objective map ·
> [`../30-identity-and-nhi/hybrid-identity/`](../30-identity-and-nhi/hybrid-identity/) ·
> [`../30-identity-and-nhi/external-identities/`](../30-identity-and-nhi/external-identities/) ·
> [`../30-identity-and-nhi/entitlement-management/`](../30-identity-and-nhi/entitlement-management/)
