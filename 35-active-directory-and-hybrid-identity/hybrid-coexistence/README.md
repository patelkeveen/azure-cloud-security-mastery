# Hybrid Coexistence

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> The topic that ties this domain together: **which authentication method, which sync tool, which
> device join** — and how they combine. Read [`../entra-connect-sync/`](../entra-connect-sync/),
> [`../entra-cloud-sync/`](../entra-cloud-sync/) and [`../adfs-and-federation/`](../adfs-and-federation/) first.

---

## 1. What it is

Running on-premises AD and Entra ID **at the same time**, permanently or during a migration, with
three independent decisions:

1. **Where does authentication happen?** — PHS, PTA, or federation
2. **How do objects get there?** — Connect Sync or Cloud Sync
3. **How do devices get an identity?** — Entra join, hybrid join, or registration

People conflate these constantly. They are orthogonal: you can run Cloud Sync with federation, or
Connect Sync with PHS, or any other combination.

---

## 2. Why it exists

Almost nobody gets to be cloud-only. There is a file server, a line-of-business app that speaks
LDAP, a printer, a manufacturing system from 2009. **Hybrid is not a transition state for most
organisations — it is the destination**, and treating it as temporary produces designs that never
get finished.

---

## 3. The three authentication methods

```
                        Where is the password verified?
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        ▼                           ▼                           ▼
      PHS                          PTA                      FEDERATION
  In Entra ID, against       On-prem, by an agent      On-prem, by AD FS
  a synced hash             holding the password       (or a 3rd-party STS)
                            in memory only
   ✅ Survives an           ⚠ Needs the agent          ⚠ Needs the whole farm
      on-prem outage           reachable                  reachable
   ✅ No servers            ⚠ 3+ agents for HA         ⚠ Farm + WAP + LB
   ✅ Leaked-credential     ✅ Real-time policy         ✅ Real-time policy
      detection (P2)           enforcement                enforcement
                            ✅ No hash in cloud         ✅ Password never leaves
```

| | PHS | PTA | Federation |
|---|---|---|---|
| Domain state | Managed | Managed | **Federated** |
| On-prem dependency for cloud sign-in | **None** | Agent | **Entire farm** |
| Enforces on-prem account disable **immediately** | ✗ (next sync) | ✅ | ✅ |
| Enforces on-prem sign-in **hours** | ✗ | ✅ | ✅ |
| Works when the WAN is down | **✅** | ✗ | ✗ |
| Leaked-credential risk detection | **✅** | ✗ | ✗ |

**PHS is the default recommendation, and the bar for choosing otherwise is high.** The genuine
reasons to pick PTA or federation are: a regulatory requirement that no password derivative leave
the premises, on-premises sign-in-hour or immediate-disable enforcement, smart-card-only logon, or
a third-party MFA on the AD FS path.

> **"We don't want our passwords in the cloud" is not a valid reason** — no password and no usable
> hash leaves the building. See [`../entra-connect-sync/`](../entra-connect-sync/) §6 for the
> byte-level answer. Being able to explain that in two sentences resolves this objection in most
> meetings.

**PHS as a fallback is nearly always correct.** It is supported alongside PTA *and* federation, and
it converts "AD FS is down, nobody works" into "flip the domain to managed and carry on."

---

## 4. Worked example — determining the current state

Never accept a description. Measure. Four commands establish the whole posture:

```powershell
Connect-MgGraph -Scopes 'Domain.Read.All','Organization.Read.All','Directory.Read.All'

# 1. Per-domain authentication
Get-MgDomain | Select-Object Id, AuthenticationType, IsVerified

# 2. Is sync on at all, and what feature flags?
Get-MgOrganization | Select-Object -ExpandProperty OnPremisesSyncEnabled
(Get-MgDirectoryOnPremiseSynchronization).Features

# 3. Is PHS actually running? (last sync timestamp)
Get-MgOrganization | Select-Object -ExpandProperty OnPremisesLastSyncDateTime

# 4. Device join state distribution
Get-MgDevice -All -Property TrustType,DisplayName |
  Group-Object TrustType | Select-Object Name, Count
```

```
Name          Count
----          -----
AzureAd          12     <-- Entra joined (cloud-native)
ServerAd        847     <-- Hybrid joined  (requires Connect Sync device sync)
Workplace        63     <-- Registered (BYOD)
```

**Read that output as a migration constraint.** 847 hybrid-joined devices means device sync is in
use, which means [`../entra-cloud-sync/`](../entra-cloud-sync/) is blocked until Cloud Kerberos
Trust is adopted. One command turned an opinion into a scoped project.

---

## 5. Staged Rollout — the safe way to change authentication

Changing a domain from `Federated` to `Managed` is a **cutover for every user at once**. Staged
Rollout removes that risk:

- Move **selected groups** to cloud authentication while the domain stays `Federated`
- Test with real users doing real work
- Roll back per group, not per domain

```
Federated domain
   ├── Group: IT pilot        → cloud auth (PHS)   ✅ testing
   ├── Group: Finance         → still AD FS
   └── everyone else          → still AD FS
```

**Prerequisite: PHS must already be enabled and have completed an initial sync.** Users without a
synced password hash simply cannot sign in when moved. That is the most common Staged Rollout
failure, and it is entirely avoidable.

⚠ Staged Rollout does **not** apply to legacy authentication protocols or to certain client types
— verify the current exclusion list before promising a pilot group a seamless experience.

---

## 6. Devices — the third axis

| Join type | What it is | Needs |
|---|---|---|
| **Entra joined** | Cloud-native. No on-prem dependency. | Nothing on-prem |
| **Hybrid joined** | Domain-joined **and** registered in Entra. | ⭐ **Connect Sync device sync** |
| **Registered** | BYOD — personal device, work account. | Nothing |

**Hybrid join is the compatibility option, not the target.** It exists so that domain-joined
machines can satisfy device-based Conditional Access. New estates should go **Entra joined** with
**Intune**, and reach on-premises resources via **Cloud Kerberos Trust**.

**Cloud Kerberos Trust** lets an Entra-joined device get a Kerberos TGT for on-premises resources
without being domain-joined. It replaced device writeback and is the reason device writeback was
retired rather than reimplemented. It is also what unblocks Cloud Sync for estates currently
depending on hybrid join.

> **Seamless SSO (SSO for domain-joined devices on the corporate network) is a PHS/PTA companion,
> not an authentication method.** It is frequently confused with one. It also creates a computer
> account called `AZUREADSSOACC` whose **Kerberos decryption key should be rolled periodically** —
> a genuinely obscure but real hardening item that almost no estate does.

---

## 7. What breaks

**"Disabled the user in AD, they can still get email."** With **PHS**, disable propagates only on
the next sync cycle — up to 30 minutes. Under PTA or federation it is immediate. For a real
termination, disable in AD **and** revoke sessions in the cloud:

```powershell
Revoke-MgUserSignInSession -UserId leaver@contoso.com
```

Without the revoke, existing refresh tokens keep working regardless of the account state. **This is
the single most commonly missed step in offboarding**, and it is the one that appears in breach
reports.

**PTA agent count.** One agent is a single point of failure that also cannot be patched without an
outage. Run **at least three**, on separate hosts.

**Sign-in hours and account expiry do not exist in the cloud.** `accountExpires` does not sync at
all (see [`../entra-connect-sync/`](../entra-connect-sync/) §4), and logon-hour restrictions are not
enforced by Entra under PHS. Estates that rely on either for contractor control have a gap they
usually do not know about.

**UPN mismatch.** If the on-premises UPN suffix is not a verified domain in the tenant, users are
provisioned as `user@tenant.onmicrosoft.com`. Fix the UPN suffix in AD **before** the first sync —
retrofitting means every user changes identity.

**Password writeback needs the licence.** SSPR writing back to AD requires Entra ID P1. ✗ Not
available on your current Office 365 E5 tenant — see the tenant note in `SESSION_CONTEXT.md`.

---

## 8. Customer discovery questions

1. Authentication method **per domain**, and what was the original reason for it?
2. Is **PHS enabled as a fallback** even under PTA or federation?
3. Device join distribution? *(§4 command 4 — decides whether Cloud Sync is reachable.)*
4. What does offboarding actually do — disable in AD only, or disable **and revoke sessions**?
5. Does anything depend on **sign-in hours** or **`accountExpires`**?
6. How many PTA agents, on how many hosts?
7. Is Seamless SSO in use, and has the `AZUREADSSOACC` key ever been rolled?
8. Is hybrid join a deliberate choice, or inherited? Has Cloud Kerberos Trust been evaluated?

---

## 9. Remember it

**Hook — "Only PHS survives the outage."** PTA needs its agent; federation needs the whole farm.

**Analogy — three ways to check ID at a door.** PHS: the doorman holds a copy of the guest list and
works even when head office burns down. PTA: he radios head office for every guest. Federation: head
office issues the passes and the door is useless without it.

**The one thing:** disabling a leaver in AD is **not** offboarding. Under PHS it takes up to 30
minutes, and existing refresh tokens keep working regardless — you must also
`Revoke-MgUserSignInSession`. This is the step that shows up in breach reports.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 10. Self-test

1. Three authentication methods — which survives a complete on-premises outage?
2. "We don't want our passwords in the cloud." Answer it in two sentences.
3. Why enable PHS in a federated estate that has no intention of migrating?
4. User disabled in AD under PHS. How long until they lose cloud access, and what must you also do?
5. 847 devices report `TrustType = ServerAd`. What does that block, and what unblocks it?
6. What must be true *before* Staged Rollout will work?
7. Which method detects leaked credentials, and why can the others not?
8. On-prem UPN suffix is not verified in the tenant. What happens on first sync?

<details>
<summary>Answers</summary>

1. **PHS.** PTA needs its agent; federation needs the whole farm.
2. No password and no usable hash leaves the building — Entra stores a salted **PBKDF2/HMAC-SHA256
   derivative** of the MD4 hash. It cannot be replayed against on-premises AD, so it is **safer**
   than the status quo.
3. **Fallback.** If AD FS or the PTA agents fail, converting the domain to managed restores
   authentication immediately. Without a synced hash there is nothing to fall back to.
4. Up to **30 minutes** (next sync). You must also **`Revoke-MgUserSignInSession`**, or existing
   refresh tokens keep working.
5. Hybrid Entra join → **device sync** → blocks Cloud Sync. **Cloud Kerberos Trust** unblocks it.
6. **PHS enabled and initial sync complete.** Otherwise moved users have no hash and cannot sign in.
7. **PHS.** Entra ID needs the hash to compare against known-breached credential corpora; under PTA
   and federation it never has one.
8. Users are provisioned as `user@tenant.onmicrosoft.com`. Fix the suffix **before** first sync.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — run the four §4 commands and record the posture; enable PHS; run Staged Rollout with
  a pilot group.
- **`break-fix/`** — disable a user in AD and time how long cloud access survives; then prove
  `Revoke-MgUserSignInSession` closes it. **This is the offboarding evidence a customer will ask for.**
- **`security/`** — offboarding runbook covering disable + revoke; `AZUREADSSOACC` key roll date;
  PTA agent count and host separation.
- **`operations/`** — the §4 posture snapshot, re-run quarterly and diffed.
- **`architecture-decisions/`** — ADR: authentication method choice, with the §3 table and the
  actual regulatory driver — or its absence — recorded.
- **`customer-use-cases/`** — a federation-to-PHS migration plan with Staged Rollout phases.
