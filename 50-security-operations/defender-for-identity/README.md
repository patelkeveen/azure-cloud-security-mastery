# Microsoft Defender for Identity (MDI)

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (overview updated 2026-07-23, sensor
> prerequisites 2026-07-29).
> ⭐ **The bridge from your AD depth into the SOC.** Everything in
> [`../../35-active-directory-and-hybrid-identity/ad-ds/`](../../35-active-directory-and-hybrid-identity/ad-ds/) §7
> — DCSync, Golden Ticket, Kerberoasting — is what this product detects. Hunt with [`../kql/`](../kql/).

---

## 1. What it is

A **sensor on your identity infrastructure** plus a cloud analytics service that detects
identity-based attacks: reconnaissance, credential compromise, lateral movement, and domain
dominance.

It watches the things AD itself does not alert on. Active Directory will happily perform a DCSync
for anyone holding the right permission and log nothing that looks alarming. MDI knows that
replication from a non-DC is an attack.

**It is no longer on-premises only.** MDI now monitors on-premises AD, **Entra ID**, and other IAM
systems including **Okta**, via API connectors — ✅ verified 2026-08-10. Material written before
about 2025 describes a narrower product.

---

## 2. Why it exists

Two problems no other tool solves:

**Native AD auditing is unusable as a detection source.** Turn on verbose auditing and you get
millions of events per day with no notion of what is normal. Kerberoasting looks exactly like a
service ticket request, because it *is* one.

**The high-value attacks leave almost no trace.**

| Attack | What AD logs |
|---|---|
| **DCSync** | A legitimate replication request. Nothing suspicious. |
| **Golden Ticket** | Nothing — the TGT was never issued by the DC |
| **Silver Ticket** | ⭐ **Nothing on the DC at all** — the DC is never contacted |
| **Kerberoasting** | A normal `4769` service ticket request |

> **MDI's value is behavioural.** It knows which machines are domain controllers, so replication
> from anything else is an attack. It knows this account has never requested 40 service tickets in
> a minute. That baseline is what native logging can never give you.

---

## 3. Where sensors go — and the version split

✅ Verified 2026-08-10. **There are now two sensor generations**, and picking wrong is a common
deployment error:

| Sensor | Use on |
|---|---|
| **v3.x** | ⭐ **Recommended for domain controllers running Windows Server 2019 or later** |
| **v2.x** | DCs running **Windows Server 2016 or earlier**, and **AD FS / AD CS / Entra Connect servers that are not DCs** |

Supported operating systems: **Windows Server 2016, 2019, 2022, 2025**. Server core and desktop
experience both work; **Nano Server does not**. Windows Server 2012/2012 R2 hit extended end of
support on **10 October 2023** — sensors still report but some functionality is unavailable.

**Where sensors install, and the three rules people get wrong:**

```
Domain Controllers      ── every one, including RODCs
AD FS servers           ── ⭐ federation servers ONLY, not WAP
AD CS servers           ── ⭐ only those with the Certification Authority Role Service
                           (offline CAs need nothing)
Entra Connect servers   ── ⭐ BOTH the active AND the staging server
```

> **"Both active and staging" is the one that gets missed.** A staging server holds the same
> credentials and the same DCSync-capable connector account as the active one — see
> [`../../35-active-directory-and-hybrid-identity/entra-connect-sync/`](../../35-active-directory-and-hybrid-identity/entra-connect-sync/).
> Leaving it unmonitored leaves the fattest target in the estate blind.

**Server requirements** ✅ verified: **2 cores, 6 GB RAM, 6 GB disk (10 GB recommended)**, on top of
what the DC already uses. Power option set to **High Performance**.

⚠ **Virtualisation gotchas that cause real, hard-to-diagnose failures:**
- **Hyper-V: Dynamic Memory must be disabled.**
- **VMware: reserve all guest memory**, and **disable Large Send Offload (LSO)** on the NIC.
- Time must be synchronised **within 5 minutes** across sensor servers — the same tolerance
  Kerberos itself uses.

---

## 4. Licensing — read this before planning anything

✅ Verified 2026-08-10. MDI requires **one of**:

- **Enterprise Mobility + Security E5** (EMS E5/A5)
- **Microsoft 365 E5** (E5/A5/G5)
- Microsoft 365 E5/A5/G5/**F5 Security**
- Microsoft 365 F5 Security + Compliance
- A **standalone Defender for Identity** licence

> ⚠ **Office 365 E5 is not on that list.** MDI is unavailable on your current `Kev@KWin.onmicrosoft.com`
> tenant. This is the *same delta* as Entra ID P2: it lands with **EMS E5**, which remains the single
> highest-value trial to add — one trial unblocks Conditional Access, PIM, Intune, Defender for Cloud
> Apps **and** Defender for Identity. See `SESSION_CONTEXT.md`.

Roles: creating the workspace needs **Security Administrator**. Sensors need a **Directory Service
Account (DSA)** with **read access to all objects** in monitored domains.

---

## 5. Worked example — pre-flight and connectivity

**Microsoft ships a readiness script.** Run it before touching a domain controller — it is also
available in Defender XDR under **Identities → Tools**:

```powershell
# From github.com/microsoft/Microsoft-Defender-for-Identity
.\Test-MdiReadiness.ps1
```

It checks OS version, memory, .NET, power plan, auditing configuration and connectivity, and it
saves the argument about whether a DC is ready.

**Verify the sensor can reach its cloud endpoint.** The URL is workspace-specific:

```powershell
# https://<your-workspace-name>sensorapi.atp.azure.com
Test-NetConnection -ComputerName 'contoso-corpsensorapi.atp.azure.com' -Port 443
```

```
ComputerName     : contoso-corpsensorapi.atp.azure.com
RemotePort       : 443
TcpTestSucceeded : True
```

⚠ **SSL inspection is not supported.** A proxy that intercepts and re-signs this traffic breaks the
sensor. That is a firm constraint and it surprises organisations that inspect everything by policy —
see [`../../10-networking/tls-pki-and-certificates/`](../../10-networking/tls-pki-and-certificates/) §7.

**The ports that matter** ✅ verified:

| Port | Direction | Purpose |
|---|---|---|
| **TCP 443** → `*.atp.azure.com` | Outbound | Sensor to cloud (or via proxy / ExpressRoute) |
| TCP+UDP 53 | Outbound | DNS |
| **TCP 135, UDP 137, TCP 3389** | Sensor → all devices | ⭐ **Network Name Resolution** — resolves IP to computer name |
| TCP 444 | localhost | Sensor updater |
| UDP 1813 | Inbound | RADIUS accounting |

> ⭐ **NNR is the part that quietly degrades detections.** MDI resolves IP addresses to machine
> names to attribute activity. Block 135/137/3389 and alerts arrive naming an **IP with no
> hostname** — technically working, practically useless in an investigation. If your alerts look
> anaemic, check NNR first.

**Multi-forest** additionally needs outbound LDAP **389**, LDAPS **636**, GC **3268**, GC-over-TLS
**3269**. Sensors query LDAP on 389/3268 by default; switching to LDAPS requires a support case.

---

## 6. What it detects, mapped to the kill chain

✅ The four stages are Microsoft's own framing:

| Stage | Detections |
|---|---|
| **Reconnaissance** | Enumeration of users, groups, IPs and resources — SAMR and LDAP recon, DNS reconnaissance |
| **Compromised credentials** | Brute force, password spray, repeated failed authentication, suspicious group membership changes |
| **Lateral movement** | Pass-the-Hash, Pass-the-Ticket, Overpass-the-Hash, movement toward sensitive identities |
| **AD domain dominance** | ⭐ **DCSync (malicious replication), DCShadow, Golden Ticket, remote code execution on a DC** |

**Map that against what you already know:** every row in
[`ad-ds/`](../../35-active-directory-and-hybrid-identity/ad-ds/) §7 appears here. MDI is the
detection layer for the attacks that topic describes — which is exactly why learning AD deeply first
makes this product legible rather than magical.

**Lateral movement paths** are the posture feature worth demonstrating: MDI computes how an attacker
reaching a low-value workstation could chain to a Domain Admin, because a privileged account once
logged on there and left credentials in memory. It turns the abstract tiering argument into a
picture of *your* estate — and that picture is what actually gets tiering funded.

**Honeytoken accounts.** Designate a dormant, attractive-looking account (`svc_backup_admin`) as a
honeytoken. **Any** authentication involving it alerts, because there is no legitimate use. Near-zero
false positives and it catches enumeration early. ⭐ Cheap, high-signal, and almost nobody deploys it.

---

## 7. Hunting — the tables

⚠ Verify current schema in your tenant before relying on column names; these move.

| Table | Contains |
|---|---|
| `IdentityLogonEvents` | Authentication activity seen by sensors |
| `IdentityDirectoryEvents` | Directory changes — group membership, account changes |
| `IdentityQueryEvents` | ⭐ **LDAP/SAMR queries — this is where recon lives** |
| `IdentityInfo` | Identity metadata for enrichment |

**Find reconnaissance** — the query that catches an attacker before they escalate:

```kusto
IdentityQueryEvents
| where Timestamp > ago(7d)
| where QueryType in ("AllGroups", "AllMembers", "SAMR")
| summarize Queries = count(),
            Targets = dcount(QueryTarget),
            Devices = make_set(DeviceName, 5)
        by AccountUpn, bin(Timestamp, 1h)
| where Queries > 50 and Targets > 20
| sort by Queries desc
```

**Correlate on-premises with cloud** — the join that only MDI plus Entra logs makes possible:

```kusto
IdentityLogonEvents
| where Timestamp > ago(1d)
| where LogonType == "Failed logon"
| summarize OnPremFailures = count() by AccountUpn
| where OnPremFailures > 10
| join kind=inner (
    SigninLogs
    | where TimeGenerated > ago(1d)
    | where ResultType == 0
    | summarize CloudSuccess = min(TimeGenerated), IP = any(IPAddress) by AccountUpn = UserPrincipalName
) on AccountUpn
| project AccountUpn, OnPremFailures, CloudSuccess, IP
```

> **That query is the interview answer to "how do you detect hybrid attacks?"** — on-premises
> failures followed by a cloud success is a signal neither platform can produce alone.

---

## 8. What breaks

**No sensor on the Entra Connect staging server.** The highest-value unmonitored host in the estate.

**Sensor on a WAP server.** Unsupported and unnecessary — AD FS sensors go on federation servers.

**NNR ports blocked.** Alerts name IPs, not machines. Investigations stall.

**SSL inspection on sensor traffic.** Not supported. The sensor simply fails to connect.

**Dynamic Memory enabled on Hyper-V**, or unreserved memory on VMware. Intermittent sensor failures
that look like a product defect.

**Windows event auditing not configured.** Several detections depend on specific event log entries;
without the audit policy MDI runs with reduced fidelity and nothing tells you.

**DSA lacking read access** to some domain or OU. Silent blind spot in exactly the place someone
decided to restrict.

**Wrong sensor version.** v2.x on a Server 2022 DC works but v3.x is recommended; check before
mass deployment.

**Assuming MDI covers Entra-only identities without the connectors configured.**

---

## 9. Customer discovery questions

1. Are sensors on **every** DC, including RODCs — and on **both** Entra Connect servers?
2. Are AD FS and AD CS sensors deployed where applicable?
3. Is **NNR** working, or do alerts show bare IP addresses?
4. Is **Windows event auditing** configured per the MDI requirements?
5. Does the **DSA** have read access to every domain and OU?
6. Are **honeytoken** accounts deployed? *(Usually no — a quick, high-value win.)*
7. Have **lateral movement paths** been reviewed, and did anything change as a result?
8. Are Entra ID and third-party IAM connectors (e.g. **Okta**) configured?
9. Does a proxy perform **SSL inspection** on sensor traffic?
10. What licence is in place — EMS E5, M365 E5, or standalone?

---

## 10. Remember it

**Hook — "Sensors on identity infrastructure: DCs, AD FS, AD CS, and *both* Entra Connect servers."**
And **"v3 for 2019+, v2 for everything else."**

**Analogy — a store detective who knows the staff.** CCTV (native AD auditing) records everything and
proves nothing; someone walking into the stockroom looks identical whether they work there or not.
The store detective knows which people are staff, which door is for deliveries, and that this person
has never opened forty tills in a minute. **MDI's value is the baseline, not the recording** — which
is precisely why DCSync from a non-DC is obvious to it and invisible in the event log.

**The one thing:** the attacks that matter most leave **nothing** in AD's own logs — a Golden Ticket
was never issued by the DC, and a Silver Ticket never touches one. Behavioural detection is not a
nicer interface on event logs; it is the only thing that sees these at all.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 11. Self-test

1. Why can't native AD auditing detect Kerberoasting well?
2. Which servers get sensors, and which two placement rules are most often wrong?
3. Which sensor version for a Server 2022 domain controller?
4. Alerts show IP addresses instead of machine names. Cause?
5. Why is SSL inspection a hard blocker?
6. Which Defender for Identity licence options exist, and is Office 365 E5 one of them?
7. What is a honeytoken and why is its false-positive rate near zero?
8. Which table holds reconnaissance activity?
9. How would you detect an on-premises brute force that succeeded in the cloud?
10. Why does a Golden Ticket leave no trace in AD's own logs?

<details>
<summary>Answers</summary>

1. A Kerberoasting request **is** a normal service ticket request (`4769`). Only a behavioural
   baseline distinguishes it — volume, timing, and which account is asking.
2. DCs (including RODCs), **AD FS federation servers only — not WAP**, AD CS servers with the CA
   Role Service, and **both active and staging Entra Connect servers**. The last two are the
   commonly missed ones.
3. **v3.x** — recommended for Windows Server 2019 and later. v2.x is for 2016 and earlier, and for
   non-DC AD FS/AD CS/Entra Connect servers.
4. **Network Name Resolution** is failing — ports 135, 137 or 3389 blocked from the sensor.
5. It is **not supported**. Intercepting and re-signing sensor traffic breaks the connection to
   `*.atp.azure.com`.
6. EMS E5, M365 E5 (E5/A5/G5), M365 E5/A5/G5/F5 Security, M365 F5 Security + Compliance, or a
   standalone MDI licence. **Office 365 E5 is not among them.**
7. A dormant, attractive-looking account with **no legitimate use**. Any authentication involving it
   is by definition suspicious.
8. **`IdentityQueryEvents`** — LDAP and SAMR queries.
9. Join `IdentityLogonEvents` failures to `SigninLogs` successes on the same UPN. Neither platform
   can produce that signal alone.
10. The TGT was **forged with the krbtgt key** and never issued by a domain controller, so there is
    no issuance event to log.

</details>

---

## 12. Evidence this topic needs

- **`lab/`** — run `Test-MdiReadiness.ps1`; deploy a sensor; create a **honeytoken** and trigger it.
  ✗ Requires EMS E5 or M365 E5 **and** a domain controller — blocked on the current tenant.
- **`break-fix/`** — block NNR ports and capture alerts degrading to bare IP addresses; enable
  Hyper-V Dynamic Memory and observe sensor instability.
- **`security/`** ⭐ — sensor coverage audit (every DC, **both** Entra Connect servers, AD FS, AD CS);
  lateral movement path review with the remediation actually taken; honeytokens deployed.
- **`operations/`** — sensor health monitoring; DSA permission scope documented; Windows event
  auditing verified against the MDI requirements.
- **`architecture-decisions/`** — ADR: sensor version strategy and proxy/SSL-inspection exemption.
- **`customer-use-cases/`** — §9 answered against a real estate; the §7 hybrid correlation query
  deployed as a Sentinel rule.
