# Hybrid Identity

> **Concept facet.** Full depth in
> [Layer 2 §1.4](../entra-users-and-groups/LAYER-2-DOMAIN-1-USER-IDENTITIES.md) and
> [DAY-04](../../DAILY-EXECUTION/DAY-04.md).
> See also [`../../35-active-directory-and-hybrid-identity/`](../../35-active-directory-and-hybrid-identity/).

## What it is

Projecting on-premises Active Directory into Entra ID so one human has one identity across both.
**More consulting revenue lives here than anywhere else in the Microsoft identity stack**, because
it is where everything breaks and few people can debug it.

## The mental model — memorise this

```
AD → [connector space] → METAVERSE → [connector space] → Entra
      inbound rules                    outbound rules
```

Objects import into a **connector space** (per-source staging), project or join into the
**metaverse** (one object per real person, even across multiple forests), then export outward.
**Sync rules govern every transition.**

This three-stage model is what turns *"the attribute is right in AD and wrong in Entra"* from a
guess into a bisect: **which stage did it stop at?**

## The decision you cannot undo: source anchor

The **source anchor** (`immutableId`) permanently links an on-prem object to its cloud object.
Change it and Entra sees a **different person** — the old object orphans and the user loses
everything tied to their old `oid`.

| Anchor | Consequence |
|---|---|
| `objectGUID` (legacy default) | **Breaks** if the object ever moves forests or the forest is rebuilt |
| **`ms-DS-ConsistencyGuid`** | Connect stamps `objectGUID` into it once; it then travels with the object |

**Always `ms-DS-ConsistencyGuid`.** The one-line reason, worth memorising verbatim: *it lets you
migrate or rebuild the forest without re-creating every cloud identity.* That sentence answers the
question in a customer meeting and shows you have done this before.

## The failure that defines the topic: soft match vs hard match

| | Matches on | Fires when |
|---|---|---|
| **Soft match** | Primary SMTP or UPN | First sync, no anchor set on the cloud object |
| **Hard match** | `immutableId` | You explicitly force the link |

**The classic break:** a cloud-only user exists. AD sync starts. The addresses don't align, soft
match misses, and you now have **two objects for one human** — one holding the mailbox and licences,
one empty but authoritative.

**Duplicate attribute resiliency** quarantines the conflicting attribute so the export continues.
Good behaviour — and it means **the error is silent unless you look.** "Sync completed" does not
mean "sync correct."

## Choosing the authentication method

| | PHS | PTA | Federation |
|---|---|---|---|
| Auth happens | **Cloud** | On-prem agent | On-prem AD FS |
| On-prem outage | **Users still sign in** | Fails | Fails |
| Leaked-credential detection | **Requires this** | No | No |

**Recommend PHS unless there is a hard requirement against it.** PTA and federation make cloud
sign-in depend on on-prem availability — a datacentre problem becomes a Microsoft 365 outage.

**PHS is a hash of a hash.** NTLM hash → hex → 10-byte per-user salt → **PBKDF2, 1,000 iterations
of HMAC-SHA256**. Microsoft's own words: *"if the hash stored in Microsoft Entra ID is obtained, it
can't be used in an on-premises pass-the-hash attack."* Quote it; don't paraphrase.

## Connect Sync vs Cloud Sync

Choose **Cloud Sync** for disconnected forests, M&A with no trust, or when you want no sync server
to maintain. Choose **Connect Sync** for device writeback, Exchange hybrid writeback, or complex
attribute transformation. They can coexist across different OUs.

## The traps

1. **Narrowing sync scope deletes cloud objects.** Filtering an OU out while users are in it is a
   mass-deprovisioning incident. This is why **staging mode** exists.
2. **The scheduler being disabled.** First question in any "user isn't syncing" ticket — someone
   paused it for maintenance and forgot.
3. **Seamless SSO's Kerberos key is never rolled.** Microsoft recommends every 30 days; it is not
   automatic; running the rollover twice per forest breaks SSO until tickets expire.
4. **Decommissioning AD FS without budgeting for what breaks** — claims rules, MFA adapters, and
   access control policies all need rebuilding.

## Evidence this topic needs

- `lab/` — DC + Connect with `ms-DS-ConsistencyGuid` and PHS; sync an OU.
- `break-fix/` — **cause the duplicate-object failure deliberately and repair it with a hard
  match.** This single exercise teaches more than any course.
- `operations/` — sync troubleshooting runbook; staging-mode failover.
