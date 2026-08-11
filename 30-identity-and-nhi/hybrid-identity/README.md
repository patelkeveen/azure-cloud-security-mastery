# Hybrid Identity

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10**.
> **The orientation topic for [`../../35-active-directory-and-hybrid-identity/`](../../35-active-directory-and-hybrid-identity/)**,
> which carries the full depth across eight topics.

---

## 1. What it is

Running **on-premises Active Directory and Entra ID together**, with three independent decisions
people routinely conflate:

```
1. AUTHENTICATION   where is the password verified?     PHS · PTA · Federation
2. SYNCHRONISATION  how do objects get to the cloud?    Connect Sync · Cloud Sync
3. DEVICES          how do machines get an identity?    Entra join · Hybrid join · Registered
```

⭐ **They are orthogonal.** You can run Cloud Sync with federation, or Connect Sync with PHS, or any
other combination. Treating them as one choice produces designs that cannot be built.

---

## 2. Why it is the destination, not a phase

Almost nobody gets to be cloud-only. There is a file server, a line-of-business app that speaks
LDAP, a printer, a manufacturing system from 2009.

> ⭐ **Hybrid is the end state for most organisations, and treating it as temporary produces designs
> nobody ever finishes.** The correct framing is "hybrid, done well" — not "a stop on the way to
> cloud-only."

---

## 3. The authentication decision

```
                     Where is the password verified?
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
      PHS                  PTA             FEDERATION
  In Entra, against    On-prem, by an     On-prem, by AD FS
  a synced hash        agent in memory    or a third-party STS
   ✅ Survives an       ⚠ Needs the agent  ⚠ Needs the whole farm
      on-prem outage
   ✅ Leaked-credential detection (P2)     ✅ Real-time policy enforcement
```

| | **PHS** | PTA | Federation |
|---|:---:|:---:|:---:|
| Survives a total on-prem outage | ⭐ **✅** | ✗ | ✗ |
| Leaked-credential detection | ⭐ **✅** | ✗ | ✗ |
| Immediate on-prem disable | ✗ (next sync) | ✅ | ✅ |
| On-prem sign-in hours enforced | ✗ | ✅ | ✅ |
| Infrastructure required | **None** | Agents (3+) | Farm + WAP + LB |

**PHS is the default recommendation and the bar for choosing otherwise is high.** Genuine reasons:
a regulatory requirement that no password derivative leaves the premises, on-prem sign-in-hour or
immediate-disable enforcement, smart-card-only logon, or third-party MFA on the AD FS path.

> ⭐ **"We don't want our passwords in the cloud" is not a valid reason.** No password and no usable
> hash leaves the building — Entra stores a **salted PBKDF2/HMAC-SHA256 derivative of the MD4 hash**,
> which cannot be replayed against on-premises AD. It is therefore *safer* than the status quo.
> Full byte-level detail in
> [`../../35-active-directory-and-hybrid-identity/entra-connect-sync/`](../../35-active-directory-and-hybrid-identity/entra-connect-sync/) §6.

⭐ **Enable PHS as a fallback even under PTA or federation.** It is supported alongside both, and it
converts "AD FS is down, nobody works" into "flip the domain to managed and carry on."

---

## 4. Worked example — establishing the actual posture

**Never accept a description. Four commands settle it:**

```powershell
Connect-MgGraph -Scopes 'Domain.Read.All','Organization.Read.All','Directory.Read.All'

Get-MgDomain | Select-Object Id, AuthenticationType, IsVerified          # 1. per DOMAIN
Get-MgOrganization | Select-Object -ExpandProperty OnPremisesSyncEnabled  # 2. sync on?
Get-MgOrganization | Select-Object -ExpandProperty OnPremisesLastSyncDateTime
(Get-MgDirectoryOnPremiseSynchronization).Features                        # 3. feature flags
Get-MgDevice -All -Property TrustType | Group-Object TrustType            # 4. device estate
```

```
Id                        AuthenticationType
------------------------  ------------------
contoso.com               Federated
contoso.onmicrosoft.com   Managed

Name          Count
----          -----
AzureAd          12     Entra joined
ServerAd        847     Hybrid joined      <-- ⚠ blocks Cloud Sync
Workplace        63     Registered
```

⭐ **Two findings in one screen.** `AuthenticationType` is **per domain**, not per tenant — a tenant
can be half federated. And **847 hybrid-joined devices means device sync is in use**, which blocks
[`../../35-active-directory-and-hybrid-identity/entra-cloud-sync/`](../../35-active-directory-and-hybrid-identity/entra-cloud-sync/)
until **Cloud Kerberos Trust** is adopted. **One command turned an opinion into a scoped project.**

---

## 5. The synchronisation decision

| | Connect Sync | **Cloud Sync** |
|---|---|---|
| Architecture | Server + SQL, config on-prem | ⭐ Lightweight agents, **config in the cloud** |
| HA | Staging server (manual failover) | ⭐ **Multiple active agents** |
| Disconnected forests | ✗ | ✅ |
| Device sync (hybrid join) | ✅ | ✗ |
| Scale | Unlimited | **150,000 per domain**, groups **50,000** |
| Advanced sync rules, cross-forest refs, reconciliation | ✅ | ✗ |

**Default to Cloud Sync unless a specific row blocks it.** ⚠ **Exchange hybrid attributes are
supported by both** — a widely repeated error that pushes customers onto Connect Sync unnecessarily.

---

## 6. The device decision

| Join type | On-prem dependency | Use |
|---|---|---|
| **Entra joined** | None | ⭐ The target for new estates |
| **Hybrid joined** | ⭐ **Connect Sync device sync** | Compatibility, not the destination |
| Registered | None | BYOD |

**Cloud Kerberos Trust** lets an Entra-joined device obtain a Kerberos TGT for on-premises resources
**without being domain-joined** — it replaced device writeback and is what unblocks Cloud Sync for
estates currently depending on hybrid join.

---

## 7. What breaks

**Treating the three decisions as one.** §1.

**Reading `AuthenticationType` as tenant-wide.** It is per domain.

**No PHS fallback under PTA or federation.** An outage becomes total.

**Disabling a leaver in AD only.** Under PHS it takes up to 30 minutes, **and refresh tokens keep
working regardless** — you must also `Revoke-MgUserSignInSession`.

**Relying on `accountExpires` or sign-in hours.** ⭐ `accountExpires` **does not sync at all**, so an
expired contractor account is still active in the cloud.

**UPN suffix not verified in the tenant.** Users provision as `user@tenant.onmicrosoft.com` — fix
**before** first sync.

**One PTA agent.** A single point of failure that cannot be patched without an outage. Run **three**.

**Assuming Exchange hybrid needs Connect Sync.** §5.

---

## 8. Customer discovery questions

1. Authentication method **per domain**, and what was the original reason?
2. Is **PHS enabled as a fallback**, even under PTA or federation?
3. Device join distribution? *(§4 — decides whether Cloud Sync is reachable.)*
4. Does offboarding **disable in AD and revoke sessions**, or only the first?
5. Does anything depend on **`accountExpires`** or sign-in hours?
6. How many **PTA agents**, on how many hosts?
7. Connect Sync or Cloud Sync — and which specific row justifies the choice?
8. Has staging-server failover ever been **tested**?
9. Is Cloud Kerberos Trust evaluated, or is hybrid join inherited?

---

## 9. Remember it

**Hook — "Three decisions: auth, sync, devices."** Independent, and asking which is which is the
first move in any hybrid conversation.

**Analogy — three separate contracts, one building.** **Authentication** is who checks ID at the
door. **Synchronisation** is who keeps the tenant list up to date. **Devices** is how the lifts know
which floors you may reach. **They are negotiated with different suppliers and can be changed
independently** — and treating them as one contract is why hybrid projects stall in analysis.

**The one thing:** ⭐ **only PHS survives a total on-premises outage**, and it is the only method
that gets leaked-credential detection. **Enable it as a fallback even where you authenticate
elsewhere** — it converts "AD FS is down, nobody works" into "convert the domain to managed and
carry on."

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 10. Self-test

1. What are the three independent decisions?
2. Which authentication method survives a complete on-premises outage?
3. Answer "we don't want our passwords in the cloud" in two sentences.
4. Why enable PHS in a federated estate with no migration plans?
5. Is `AuthenticationType` per tenant or per domain?
6. 847 devices report `TrustType = ServerAd`. What does that block?
7. A user is disabled in AD under PHS. How long until cloud access ends, and what else is needed?
8. Which two on-premises controls have no cloud equivalent under PHS?
9. Which sync tool supports disconnected forests, and which supports device sync?

<details>
<summary>Answers</summary>

1. **Authentication** (PHS/PTA/federation), **synchronisation** (Connect Sync/Cloud Sync), **devices**
   (Entra join/hybrid join/registered).
2. **PHS.**
3. No password and no usable hash leaves the building — Entra stores a **salted PBKDF2/HMAC-SHA256
   derivative** of the MD4 hash. It **cannot be replayed against on-premises AD**, so it is safer
   than the status quo.
4. **Fallback.** If AD FS or the PTA agents fail, converting the domain to managed restores
   authentication immediately — but only if hashes are already synced.
5. **Per domain.** A tenant can be half federated.
6. **Hybrid Entra join** → device sync → **blocks Cloud Sync** until Cloud Kerberos Trust is adopted.
7. Up to **30 minutes**, and you must also **`Revoke-MgUserSignInSession`** — refresh tokens survive.
8. **`accountExpires`** (does not sync at all) and **sign-in hours**.
9. **Cloud Sync** for disconnected forests; **Connect Sync** for device sync.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — run the §4 four-command posture check and record the result; enable PHS.
  ✗ Full labs need on-premises AD.
- **`break-fix/`** ⭐ — disable a user in AD, time how long cloud access survives, then prove
  `Revoke-MgUserSignInSession` closes it immediately. **The offboarding evidence a customer will ask
  for.**
- **`security/`** — offboarding runbook covering disable **and** revoke; `accountExpires` exposure
  check; PTA agent count and host separation.
- **`operations/`** — the §4 posture snapshot re-run quarterly and diffed.
- **`architecture-decisions/`** — ADR: authentication method with the actual regulatory driver — or
  its absence — recorded, plus the sync tool decision and the row that justifies it.
- **`customer-use-cases/`** — §8 answered; a federation-to-PHS migration plan with Staged Rollout.
