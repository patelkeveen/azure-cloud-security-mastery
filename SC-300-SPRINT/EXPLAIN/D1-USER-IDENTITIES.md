# D1 — Implement and manage user identities · 20–25%

> ⭐ **Four registers per concept.** Age 8 → non-technical adult → technical → exam.
> ⭐ **You do not know it until you can do all four without notes.**
> How to use this: [`README.md`](README.md).

---

## 1. What Entra ID actually is

**Age 8** — Imagine a school where one person at the front door knows every pupil's face. You
don't carry a key to each classroom. You show your face once, and the door person tells each
teacher *"yes, that's really Sam, and Sam is allowed in here."*

**Any adult** — It's the company's **list of who's who**, plus the bouncer who checks it. Every
app — email, payroll, the VPN — stops keeping its own private list of usernames and asks this one
service instead. One place to add a joiner. ⭐ **One place to cut off a leaver — which is the whole
reason it exists.**

**Technical** — A multi-tenant cloud **identity provider**. It authenticates principals and issues
**tokens** (JWTs) that applications validate. It speaks **OAuth 2.0**, **OpenID Connect** and
**SAML**. Applications become *relying parties* instead of credential stores.

⭐ **Exam** — ⚠ **Entra ID is not "Active Directory in the cloud."** AD is a **directory with
LDAP and Kerberos**, organised into forests, domains and OUs, designed for machines on a LAN.
Entra ID is an **identity provider with HTTP-based protocols**, organised as a **flat tenant**,
designed for the internet. ⭐ **No OUs. No Group Policy. No Kerberos across the internet.** Any
answer that implies you can "just move" AD concepts across is wrong.

⭐ **Hook** — **AD is a filing cabinet. Entra is a bouncer.**

---

## 2. Tenant, directory, subscription

**Age 8** — The **tenant** is your whole school. The **subscription** is the school's account at
the sports shop — it's how you *buy things*. Same school can have several shop accounts.

**Any adult** — The tenant is your organisation's identity boundary. A subscription is a billing
container for Azure resources. ⭐ **You can have many subscriptions trusting one tenant — but a
subscription trusts exactly one tenant at a time.**

**Technical** — The tenant is a dedicated Entra ID instance with its own directory and a
**tenant ID** (GUID). Azure subscriptions have a `tenantId` property naming their trusted
directory. Moving a subscription between tenants **strips every Azure RBAC assignment**, because
the principals it referenced no longer exist in the new directory.

⭐ **Exam** — ⭐ **Identity lives in the tenant; resources live in the subscription.** Entra roles
(Global Admin, User Admin) are **tenant-scoped**. Azure RBAC roles (Owner, Contributor) are
**resource-scoped**. ⚠ **Global Administrator does NOT automatically grant access to Azure
resources** — you must "elevate access" to gain User Access Administrator at root scope. That
elevation is a classic exam item and a real audit finding.

⭐ **Hook** — **Entra roles govern the directory. Azure RBAC governs the bill.**

---

## 3. Identity types — member, guest, cloud-only, synced

**Age 8** — Some children **go to** the school (members). Some are **visiting from another school
for the day** (guests) — they get a sticker badge, not a uniform.

**Any adult** — A **member** is your own employee. A **guest** is someone from another company you
invited to collaborate. ⭐ **Guests can see less by default, and that default is adjustable.**
Separately: a **cloud-only** account was born in Entra; a **synced** account was born in on-prem
AD and copied up.

**Technical** — `userType` is `Member` or `Guest`. Source is `onPremisesSyncEnabled` true/false.
Synced objects are **mastered on-premises**: most attributes are read-only in the cloud, and
editing them in Entra is either blocked or silently overwritten at the next sync cycle.

⭐ **Exam** — ⭐ **"Why can't I change this user's job title in the portal?"** → because they are
**synced**, and the on-prem AD object is authoritative. ⭐ **Fix it in AD, not Entra.** ⚠ And the
break-glass rule that follows: emergency accounts must be **cloud-only** — a synced account dies
with the sync, and an outage in Connect must not also be a lockout.

⭐ **Hook** — **Synced means on-prem wins. Break-glass must be cloud-only.**

---

## 4. Groups — security vs Microsoft 365, assigned vs dynamic

**Age 8** — Two kinds of group. A **team** (you play football together — you get a shirt, a
locker, a group chat). And a **list** (everyone allowed in the library — no shirt, just permission).

**Any adult** — A **Microsoft 365 group** comes with *stuff*: a shared mailbox, a SharePoint site,
a Teams team. A **security group** is purely a permission list — no mailbox, no site. ⭐ **Choose by
whether people need to collaborate or merely to be allowed.**

Separately: **assigned** membership means a human adds people. **Dynamic** means a rule adds them
automatically from their attributes.

**Technical** — Dynamic groups evaluate a membership rule against directory attributes:

```
user.department -eq "Sales"
(user.country -eq "IN") and (user.jobTitle -startsWith "Engineer")
user.userType -eq "Guest"
```

Operators: `-eq -ne -startsWith -contains -match -in -notIn -any -all`.
⭐ `-match` is a **regex**; `-contains` is not. Dynamic membership requires **P1**.

⭐ **Exam** — ⚠ **You cannot mix `user.` and `device.` in one rule** — a group is user-based or
device-based, never both. ⭐ **And the big one: a role-assignable group must be `Assigned`.
Dynamic is forbidden** — otherwise anyone who can edit a user attribute could grant themselves a
privileged role. ⭐ **That restriction is a security boundary, not an oversight**, and the exam
offers "dynamic group for the Helpdesk role" as bait.

⭐ **Hook** — **M365 group = comes with furniture. Security group = just a key.**

---

## 5. Administrative units

**Age 8** — The school has a **head of Year 3**. They can help *any* Year 3 child — lost jumper,
forgotten password for the class computer — but they can't do anything for Year 6. Their power is
**real, but only inside their year**.

**Any adult** — A way to say *"you're a helpdesk admin — **for Germany only**."* Without it, the
moment you make someone a password admin they can reset **everyone's** password including the
CEO's. With it, their reach is fenced.

**Technical** — An **administrative unit (AU)** is a container of users, groups and devices used as
a **scope for a directory role assignment**. Assign Password Administrator at tenant scope → all
users. Assign it scoped to the "Germany" AU → only that AU's members.

⭐ **Exam** — ⭐ **The distinction being tested is verbs vs nouns:**

```
CUSTOM ROLE          restricts WHAT actions   (verbs)
ADMINISTRATIVE UNIT  restricts WHICH objects  (nouns)
```

⭐ *"Helpdesk resets passwords **but only for Germany**"* constrains **objects** → AU + a
**built-in** role. Reaching for a custom role is the offered wrong answer.

Also tested: ⚠ **AUs cannot be nested** (an object can be in several). Dynamic AU membership works
for **users and devices**; ⭐ **groups must be added manually**. And ⭐ **restricted management AUs**
lock out even tenant-scoped User Administrators — which is the correct answer to *"protect the
break-glass accounts from a compromised helpdesk admin."*

⭐ **Hook** — **Custom role = which verbs. AU = which nouns.**

---

## 6. Roles and least privilege

**Age 8** — The person who hands out lunch shouldn't also be allowed to change your report card.
Each job gets **only the keys that job needs**.

**Any adult** — Every admin task has a **smallest role that can do it**. Handing out the top role
because it's easier is how one phished account becomes a company-wide incident.

**Technical** — Built-in Entra directory roles, assignable permanently or via PIM, at tenant or AU
scope.

⭐ **Exam** — ⭐ **The question is almost always "which is the LEAST privileged role that can do X."
Global Administrator is on offer and it is nearly always wrong.**

| Task | Least-privileged role |
|---|---|
| Reset non-admin passwords | Password Administrator / Helpdesk Administrator |
| Manage Conditional Access policies | Conditional Access Administrator |
| Manage the **authentication methods policy** | ⭐ Authentication **Policy** Administrator |
| Reset MFA for **non-admins** | ⭐ **Authentication** Administrator |
| Reset MFA for **anyone incl. Global Admins** | ⭐ **Privileged Authentication** Administrator |
| Assign roles, configure PIM | Privileged Role Administrator |
| All app registrations **+ App Proxy** | Application Administrator |
| All app registrations, **no App Proxy** | ⭐ **Cloud** Application Administrator |
| Assign licences | License Administrator |
| Access packages, reviews, lifecycle | Identity Governance Administrator |
| Read sign-in / audit logs | Reports Reader |

⭐ **The three deliberately confusable ones:**

```
Authentication POLICY Administrator  -> the TENANT POLICY. Which methods exist at all.
Authentication Administrator         -> PER-USER methods, non-admins only.
Privileged Authentication Admin      -> PER-USER methods, ANYONE, incl. Global Admins.
```

⭐ **Cue words: "policy" = tenant-wide · "reset this user's MFA" = per-user ·
"including administrators" = the Privileged variant.**

⭐ **Hook** — **"Policy" means the rulebook. No "policy" means one person. "Including admins" means Privileged.**

---

## 7. Hybrid identity — PHS, PTA, federation

**Age 8** — Your house key also opens the school gate. Three ways to arrange that:
**(PHS)** the school keeps a *copy of the shape* of your key, so the gate works even if your house
burns down. **(PTA)** the gate phones your house to ask *"is this the right key?"* — no phone line,
no entry. **(Federation)** your house has its **own** gate guard who decides, and the school just
trusts whatever they say.

**Any adult** — Where does the password actually get checked?
**PHS** — in Microsoft's cloud, against a synced hash. **PTA** — on your own servers, by a small
agent. **Federation (ADFS)** — entirely on your own infrastructure, which then vouches for the user.

⭐ **The trade is always the same: keeping the check on-premises gives you control and gives you an
outage.**

**Technical**

| | **PHS** | **PTA** | **Federation** |
|---|---|---|---|
| Password checked | ⭐ In Entra | On-prem agent | On-prem ADFS |
| Password in cloud? | Hash of a hash, ⭐ not reversible | No | No |
| ⭐ Survives on-prem outage? | ⭐ **Yes** | **No** | **No** |
| Leaked-credential detection | ⭐ **Yes — needs PHS** | No | No |
| Smart card / third-party on-prem MFA | No | No | ⭐ **Yes** |
| Infrastructure | Lowest | Agents (⭐ **3+ for HA**) | Highest |

⭐ **Exam — read the requirement, pick the column:**

```
"must work if the datacentre is down"       -> PHS
"passwords must never leave the premises"   -> PTA or federation
"leaked-credential risk detection"          -> PHS   (no hash, no detection)
"smart cards / third-party MFA on-prem"     -> Federation
"lowest cost and complexity"                -> PHS
```

⭐ **PHS as a *backup* for PTA/federation is a recommended design and a common right answer** —
an on-prem failure then degrades to cloud auth instead of an outage.

Supporting facts: **Seamless SSO** works with PHS and PTA, ⭐ **not federation** (ADFS does its
own); it creates the `AZUREADSSOACC` computer object, ⭐ **roll its key every 30 days**.
**Password writeback** works with all three. ⭐ **Staged rollout** moves users federation → cloud
auth **in batches** without flipping the domain's federation setting — the safe migration answer.
**PHS syncs every 2 minutes**; Connect Sync's default cycle is **30 minutes**.

⭐ **Hook** — **PHS survives the outage. PTA keeps the password home. Federation buys smart cards.**

---

## 8. Entra Connect Sync vs Cloud Sync

**Age 8** — Two delivery vans. The **big van** carries everything but only drives one route. The
**small van** is quick and can visit lots of separate villages, but won't carry the heavy items.

**Any adult** — **Connect Sync** is the full-featured engine: one server, every capability.
**Cloud Sync** is a lightweight agent that can serve **several separate, untrusting AD forests** —
common after a merger — but it can't do everything.

**Technical** — ⭐ **Cloud Sync**: lightweight agent, **multiple disconnected forests**, no device
writeback, no Exchange hybrid writeback. ⭐ **Connect Sync**: full feature set — device writeback,
group writeback, Exchange hybrid, complex attribute flows.

⭐ **Exam** — ⭐ *"Two merged companies, forests don't trust each other, need sync quickly"* →
**Cloud Sync**. ⭐ *"We need device writeback / Exchange hybrid"* → **Connect Sync**.

⭐ **Hook** — **Cloud Sync = many forests, fewer features. Connect Sync = one engine, everything.**

---

## 9. Group-based licensing

**Age 8** — Instead of handing every child a lunch ticket one at a time, you say *"everyone in
Year 4 gets lunch."* New child joins Year 4 → they get lunch automatically.

**Any adult** — Assign the licence to a **group**, not to people. Members inherit it; leavers lose
it. Combine with a dynamic group and licensing becomes fully automatic.

**Technical** — Licence assignment on a group object; Entra reconciles membership to service plans.

⭐ **Exam** — the failure modes are what get tested:

| Fact | Detail |
|---|---|
| ⭐ **Usage location** | ⭐ **Must be set or assignment fails** — the most common cause |
| ⭐ **Nested groups** | ⭐ **Not supported.** Members of a child group inherit **nothing** |
| Conflicting service plans | User lands in **error** state; resolve on the group |
| Not enough licences | Fails and is **reported on the group**, not silent |

⭐ **Hook** — **No usage location, no licence. Nested groups inherit nothing.**

---

## 10. External identities — B2B collaboration vs B2B direct connect

**Age 8** — Two ways to let a friend from another school in. **(Collaboration)** you sign them in
at reception and they get a visitor badge that lives in the school's book. **(Direct connect)** the
two head teachers agree the schools trust each other, and your friend just walks into the shared
sports hall — ⭐ **no badge, no entry in your book at all.**

**Any adult** — **B2B collaboration** creates a guest account in your directory. **B2B direct
connect** creates **nothing** in your directory — the two organisations trust each other directly,
and today that's used for **Teams shared channels**.

**Technical**

| | **B2B collaboration** | **B2B direct connect** |
|---|---|---|
| Object in your directory? | ⭐ Yes — a Guest user | ⭐ **None** |
| Setup | Invitation + redemption | ⭐ Mutual trust in **cross-tenant access settings, both tenants** |
| Used for | Apps, Teams, SharePoint, access packages | ⭐ **Teams shared channels** |

⭐ **Exam** — ⭐ *"The partner must not appear in our directory"* is the tell for **direct connect**.

⭐ **And the favourite: trust settings.** Cross-tenant access settings can **trust MFA / compliant
device / hybrid-joined claims from the guest's home tenant**. ⚠ **Without that, a guest hitting
your CA policy must re-register MFA in your tenant** — which shows up as *"guests complain they
must set up Authenticator twice."*

Also: guest access levels are **same as members / limited / restricted** (most restrictive — can't
enumerate the directory). ⚠ **Domain allow-list and deny-list are mutually exclusive — never both.**

⭐ **Hook** — **Collaboration makes an object. Direct connect makes a handshake. Trust settings stop the second MFA.**

---

## Say it back — cover the right column

| Prompt | Answer |
|---|---|
| Entra vs AD in one line | Bouncer vs filing cabinet; HTTP protocols vs LDAP/Kerberos; flat tenant vs OUs |
| Why can't I edit this user in the portal? | Synced — on-prem AD is authoritative |
| Helpdesk for one country only | Administrative unit + built-in role |
| Reset a Global Admin's MFA | Privileged Authentication Administrator |
| Must survive an on-prem outage | PHS |
| Need leaked-credential detection | PHS — no hash, no detection |
| Two untrusting forests | Cloud Sync |
| Licence assigned but not applied | Usage location missing, or nested group |
| Partner must not appear in our directory | B2B direct connect |
| Guests asked to register MFA twice | Enable inbound trust for MFA claims |

> ⭐ **The real test: explain any row above out loud, at all four levels, without notes.**
> ⭐ **Every "and then it sort of…" is a gap.**

> **Next:** [`D2-AUTH-AND-ACCESS.md`](D2-AUTH-AND-ACCESS.md) — the biggest domain ·
> **Index:** [`README.md`](README.md)
