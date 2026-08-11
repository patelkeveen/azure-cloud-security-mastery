# Tenant Architecture

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The tenant is the only hard boundary in Microsoft 365** — and that single fact drives every
> merger, divestiture and "can we separate these business units" conversation.
> Compare with
> [`../../20-azure-platform/subscriptions-and-management-groups/`](../../20-azure-platform/subscriptions-and-management-groups/).

---

## 1. ⭐ Azure divides. M365 does not.

```
AZURE          tenant ─▶ management groups ─▶ ⭐ subscriptions ─▶ resource groups
               ⭐ several usable isolation levels below the tenant

MICROSOFT 365  tenant ─▶ ⭐ …that's it
               ⭐ one Exchange org, one SharePoint estate, one directory
```

⭐ **There is no "subscription" in Microsoft 365.** Everything below the tenant — administrative
units, sensitivity labels, EXO address book policies, SharePoint hubs — is **scoping, not
isolation**. Each is a partition an administrator can cross.

> ⭐ **So the answer to "can we separate these two business units?" is: partially, and only by
> convention — unless you use two tenants.** Saying that plainly, with the list of what *can* be
> partitioned, is the useful contribution. **Claiming M365 can isolate business units the way Azure
> subscriptions can is the mistake.**

**What you actually get below the tenant:**

| Mechanism | ⭐ Partitions | ⚠ Does not partition |
|---|---|---|
| ⭐ **Administrative units** | ⭐ *admin scope* over users/groups | data, mail flow, SharePoint |
| **Sensitivity labels** | access to labelled content | the directory |
| **Address book policies (EXO)** | ⭐ who sees whom in the GAL | actual mail delivery |
| **SharePoint hubs / site scoping** | navigation and some policy | the tenant's search index |
| **Conditional Access** | ⭐ *conditions*, per group | ⚠ not a data boundary |

⭐ **Administrative units are the most useful and the most misunderstood.** They scope *who can
administer whom* — genuinely valuable for a devolved helpdesk — and they do **not** stop a
tenant-wide admin, do not partition data, and do not appear in most people's mental model at all.

---

## 2. Multi-tenant: when, and what it costs

⭐ **Two tenants is the only real isolation, and it is expensive in exactly the ways that matter to
users:**

```
✅ real boundary: separate directories, separate data, separate admins
⚠ ⭐ collaboration becomes GUEST access or cross-tenant sync
⚠ ⭐ licences are per tenant — a person in both costs twice
⚠ Teams, calendars and the GAL do not merge
⚠ ⭐ every policy must be built and maintained twice — and they will drift
```

**When two tenants is right:**

| Driver | ⭐ Verdict |
|---|---|
| Regulatory / sovereignty requiring hard separation | ⭐ **yes** |
| An acquisition not yet integrated | yes, temporarily |
| Genuinely independent businesses under one holding | yes |
| ⭐ "Different departments should not see each other" | ⭐ **no — that is labels and ABPs** |
| ⭐ "Dev/test isolation" | ⭐ **yes — a separate test tenant is legitimate and cheap** |

⭐ **Cross-tenant access settings and cross-tenant synchronisation** are what make multi-tenant
survivable — inbound/outbound trust configured per partner tenant, with MFA and device-compliance
claims **trusted across the boundary** rather than re-prompted. See
[`../../30-identity-and-nhi/external-identities/`](../../30-identity-and-nhi/external-identities/).

⚠ **Microsoft 365 multi-tenant organisation features exist and are evolving.** ⭐ **Verify the current
capability set before designing on it** — this is a fast-moving area and the answer you give a
customer today may be wrong in a quarter.

---

## 3. Worked example — read the tenant's shape

```powershell
Connect-MgGraph -Scopes 'Organization.Read.All','Directory.Read.All','Policy.Read.All'

# ① Identity and verified domains — ⭐ every domain here can receive mail as you
Get-MgOrganization | Select-Object DisplayName, Id, CountryLetterCode,
  @{n='Domains';e={ ($_.VerifiedDomains | Where-Object Capabilities -match 'Email').Name -join ', ' }}
```

```powershell
# ② ⭐ Tenant-wide switches that are decisions, not defaults
$policy = Get-MgPolicyAuthorizationPolicy
$policy | Select-Object `
  @{n='UsersCanRegisterApps';   e={$_.DefaultUserRolePermissions.AllowedToCreateApps}},
  @{n='UsersCanCreateTenants';  e={$_.DefaultUserRolePermissions.AllowedToCreateTenants}},
  @{n='UsersCanReadOtherUsers'; e={$_.DefaultUserRolePermissions.AllowedToReadOtherUsers}},
  @{n='GuestRoleId';            e={$_.GuestUserRoleId}},
  @{n='UsersCanInviteGuests';   e={$_.AllowInvitesFrom}}
```

```
UsersCanRegisterApps  : True      <-- ⚠ any user creates an app registration
UsersCanCreateTenants : True      <-- ⚠⚠ ⭐ any user creates a NEW TENANT
UsersCanReadOtherUsers: True      <-- normal, but enables enumeration
GuestRoleId           : a0b1b346… <-- ⭐ "same as member" if this is the member role
UsersCanInviteGuests  : everyone  <-- ⚠ anyone invites guests
```

⭐ **`UsersCanCreateTenants = True` is the finding people have never heard of.** Any user can create a
brand-new Entra tenant, become its Global Administrator, and use it — **outside every policy, log and
control you own.** It is the Azure "ungoverned subscription" problem
([`../../20-azure-platform/subscriptions-and-management-groups/`](../../20-azure-platform/subscriptions-and-management-groups/) §4)
in its purest form, and the default has historically been permissive.

⭐ **`GuestUserRoleId` is the second one.** If it is set to the *member* role, ⭐ **guests can read
your directory like employees.** The restricted guest role exists for a reason.

```powershell
# ③ ⭐ Administrative units — is admin scope actually devolved, or is everyone tenant-wide?
Get-MgDirectoryAdministrativeUnit -All |
  Select-Object DisplayName, Id, @{n='Members';e={
    @(Get-MgDirectoryAdministrativeUnitMember -AdministrativeUnitId $_.Id -All).Count }}
```

---

## 4. ⭐ Tenant-level settings that are security decisions

| Setting | ⭐ Why it matters |
|---|---|
| ⭐ **Users can create tenants** | §3 — a whole ungoverned tenant |
| ⭐ **Users can register applications** | app registrations outside review — [`../../30-identity-and-nhi/app-registrations/`](../../30-identity-and-nhi/app-registrations/) |
| ⭐ **User consent to apps** | ⚠ set to *admin consent workflow*, not off and not open |
| **Guest user role** | restricted vs member |
| **Who can invite guests** | everyone / members / admins |
| ⭐ **Security defaults vs Conditional Access** | ⚠ mutually exclusive — CA replaces defaults |
| **Self-service purchase** | ⭐ users buying licences with a card, outside procurement |
| **Tenant restrictions** | ⭐ stops *your* devices signing in to *other* tenants |

⭐ **Self-service purchase is the M365 equivalent of the shadow subscription** — a user buys Power BI
or Visio with a card, and now there is licensed capability in your tenant that no one approved. It is
disabled per-product with `Set-MsCommerceProductPolicy` ⚠ (verify the current module and cmdlet).

⭐ **Tenant restrictions is the one worth knowing about and almost nobody deploys**: it prevents a
managed device from signing in to *other organisations'* tenants — the control that stops corporate
data being moved into a personal or third-party tenant through a browser. **It is the outbound
counterpart to everything else on this list.**

---

## 5. What breaks

**Believing M365 can isolate business units.** §1 — ⭐ only two tenants isolate.

**Confusing administrative units with data isolation.** §1 — ⭐ admin scope only.

**Two tenants chosen for a labels-and-ABPs problem.** §2 — expensive and permanent.

**`UsersCanCreateTenants = True`.** §3 — ⭐ ungoverned tenants by design.

**Guest role set to member.** §3 — guests read the directory like employees.

**Unrestricted app registration and user consent.** §4.

**Self-service purchase left on.** §4 — licensed capability nobody approved.

**Security defaults left on while deploying CA.** §4 — ⚠ mutually exclusive.

**No tenant restrictions.** §4 — ⭐ data walks out into other tenants.

**Designing multi-tenant on a preview capability.** §2 — ⚠ verify first.

---

## 6. Customer discovery questions

1. Is this **one tenant or several**, and what drove that? *(§2.)*
2. ⭐ Can users **create tenants**? *(§3 — run it.)*
3. Can users **register applications** and **consent** to them?
4. Is the **guest role** restricted or member-equivalent?
5. Is **self-service purchase** disabled? *(§4.)*
6. Are **tenant restrictions** deployed? *(§4.)*
7. Are **administrative units** used — and does anyone believe they isolate data? *(§1.)*
8. Are **security defaults** and **Conditional Access** both in play? *(§4.)*
9. If you had to separate a business unit tomorrow, ⭐ **what would actually separate?**

---

## 7. Remember it

**Hook — "Azure divides below the tenant. M365 doesn't."**

**Analogy — an office building versus an open-plan floor.** ⭐ **Azure is a building with floors and
lockable suites**: you can genuinely hand one to a team and keep them out of the others.
⭐ **Microsoft 365 is one very large open-plan floor.** You can put up screens, agree that the north
end is Finance, and issue different lanyards — **and all of it is convention.** ⭐ **The only real wall
is a different building**, and moving to one means people can no longer just walk over and talk, which
is precisely the cost.

**The one thing:** ⭐ **any user can create a new tenant unless you have turned that off.** They become
its Global Administrator, they can put corporate data in it, and it exists entirely outside your
policies, your logs, your DLP and your eDiscovery. It is the purest form of the shadow-IT pattern this
repo keeps finding — **shadow subscriptions in Azure, shadow AI in
[`../../60-ai-and-secure-ai/ai-governance/`](../../60-ai-and-secure-ai/ai-governance/), self-service
purchase, and now an entire shadow tenant.** One property, one query, and almost nobody checks it.

**Runner-up:** ⭐ **tenant restrictions is the outbound control** — it stops your devices signing in to
someone else's tenant, and almost no one deploys it.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 8. Self-test

1. ⭐ What is the only hard boundary in M365, and how does that differ from Azure?
2. What do administrative units scope, and what do they not?
3. Name three mechanisms that partition below the tenant and say what each misses.
4. When is a second tenant the right answer, and when is it not?
5. What are the costs of multi-tenant, in user terms?
6. ⭐ What does `UsersCanCreateTenants = True` allow, and why is it severe?
7. What does the guest user role control?
8. ⭐ What is self-service purchase, and which pattern does it belong to?
9. What do tenant restrictions prevent?
10. Why can't security defaults and Conditional Access coexist?

<details>
<summary>Answers</summary>

1. ⭐ **The tenant.** Azure has ⭐ **management groups and subscriptions** as usable isolation levels
   below the tenant; M365 has none.
2. ⭐ **Admin scope over users and groups.** ⚠ Not data, not mail flow, not SharePoint, and not
   tenant-wide admins.
3. **Administrative units** (admin scope, not data), **sensitivity labels** (content access, not the
   directory), **address book policies** (GAL visibility, not delivery).
4. ⭐ **Yes** for regulatory/sovereign separation, un-integrated acquisitions, genuinely independent
   businesses, and a test tenant. ⭐ **No** for "departments shouldn't see each other" — that is
   labels and ABPs.
5. ⭐ **Guest access or cross-tenant sync for collaboration, double licensing, no merged GAL/Teams/
   calendars, and every policy built and maintained twice — which drifts.**
6. ⭐ Any user can **create a new tenant and become its Global Administrator**, entirely outside your
   policies, logs, DLP and eDiscovery.
7. Whether guests are ⭐ **restricted** or can read the directory ⭐ **like members**.
8. ⭐ **Users buying licences with a card**, adding capability nobody approved — the same shadow-IT
   pattern as shadow subscriptions, shadow AI and shadow tenants.
9. ⭐ They stop **your managed devices signing in to other organisations' tenants** — the outbound
   data-movement control.
10. ⚠ They are **mutually exclusive** — Conditional Access replaces security defaults.

</details>

---

## 9. Evidence this topic needs

- **`lab/`** ⭐ — the §3 authorization-policy read and administrative unit inventory. **Runnable today
  on the E5 licence** — and `UsersCanCreateTenants` is the first thing to check.
- **`break-fix/`** ⭐ — with tenant creation enabled, **create a new tenant as a standard user**, put a
  file in it, and confirm it appears in **no** audit log, DLP policy or eDiscovery search of the
  original tenant. **Then disable the setting and show the attempt fail.** That demonstration ends the
  argument.
- **`security/`** — authorization policy record (tenant creation, app registration, consent, guest
  role, invitations); self-service purchase state per product; tenant restrictions deployment;
  administrative unit map with what each genuinely scopes.
- **`operations/`** — tenant-setting review cadence; process for the legitimate cases that made people
  want self-service purchase or their own tenant.
- **`architecture-decisions/`** — ADR: single tenant with labels and ABPs for separation, or explicit
  multi-tenant with the ⭐ collaboration and licensing costs recorded and accepted.
- **`customer-use-cases/`** — §6 answered; "any of your users can create their own tenant" as an
  opening finding.
