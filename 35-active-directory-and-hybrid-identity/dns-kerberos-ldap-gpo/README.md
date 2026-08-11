# DNS, Kerberos, LDAP and Group Policy

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> The four protocols AD actually runs on. Builds on [`../ad-ds/`](../ad-ds/).
> **Most "Active Directory is broken" tickets are really DNS tickets.**

---

## 1. What it is

Four separate protocols doing four separate jobs, which people blur into "AD":

| Protocol | Job | Port |
|---|---|---|
| **DNS** | *Where* is a domain controller? | 53 |
| **Kerberos** | *Who* are you? | **88** |
| **LDAP** | *What* is in the directory? | 389 / 636 / 3268 / 3269 |
| **Group Policy** | *What settings* apply to you? | SMB to SYSVOL (445) |

Knowing which one failed is the whole diagnostic skill. "Cannot log in" has a different root cause
in each.

---

## 2. Why it matters that they are separate

Authentication is a chain, and it fails at the earliest broken link:

```
find a DC (DNS) → get a TGT (Kerberos) → read the directory (LDAP) → apply policy (SMB/GPO)
```

A DNS failure and a Kerberos failure produce **similar user-visible symptoms** and completely
different fixes. Engineers who cannot separate them restart servers until something works.

---

## 3. DNS — how a client finds a domain controller

AD does not hard-code DC addresses. Clients **discover** them with **SRV records**. This is the
DC Locator process, and it is why AD is so intolerant of DNS misconfiguration.

The records live under `_msdcs.<forest-root>`:

| Record | Answers |
|---|---|
| `_ldap._tcp.dc._msdcs.<domain>` | Any DC in the domain |
| `_kerberos._tcp.dc._msdcs.<domain>` | Any KDC |
| `_ldap._tcp.<site>._sites.dc._msdcs.<domain>` | ⭐ A DC **in my site** — how clients prefer a local DC |
| `_ldap._tcp.pdc._msdcs.<domain>` | The **PDC Emulator** specifically |
| `_ldap._tcp.gc._msdcs.<forest>` | A Global Catalog |

**The mechanism, on a public domain** — ✅ real output, run it now, no AD required:

```powershell
Resolve-DnsName -Name '_sip._tls.microsoft.com' -Type SRV |
  Select-Object Name, NameTarget, Port, Priority, Weight | Format-List
```

```
Name       : _sip._tls.microsoft.com
NameTarget : sipdir.online.lync.com
Port       : 443
Priority   : 100
Weight     : 1
```

That is exactly the shape AD uses. **Priority** picks the group (lower wins); **Weight** load-
balances within equal priority. In AD, the site-specific record is how a branch office client
avoids authenticating across a WAN link to head office.

The equivalent against a real domain:

```powershell
Resolve-DnsName -Name '_ldap._tcp.dc._msdcs.corp.contoso.com' -Type SRV
nltest /dsgetdc:corp.contoso.com          # what the client actually chose, and why
```

### The three DNS rules that prevent most AD outages

1. **Domain members must point at AD-integrated DNS**, never at `8.8.8.8` or the router. A client
   using public DNS cannot see `_msdcs` records and therefore **cannot find a DC at all**.
2. **DCs should not point at themselves first** in a multi-DC domain — the "island" problem, where
   a DC that only trusts its own copy can stop replicating DNS.
3. **Split-brain is normal and deliberate.** Internal `contoso.com` resolves differently from
   external `contoso.com`. Breaking this is a classic self-inflicted outage.

> **Symptom → cause.** "Cannot log in, but ping to the DC by IP works" is DNS almost every time.
> The client cannot *find* the DC, even though the network to it is fine.

---

## 4. Kerberos — the ticket dance

Three exchanges. Learn the shape; the ticket types follow from it.

```
   CLIENT                                    KDC (a domain controller)
     │                                              │
     │ ①  AS-REQ  ─ pre-auth: timestamp encrypted   │
     │             with my password-derived key ──► │   proves I know the password
     │ ◄─ AS-REP ─ TGT, encrypted with krbtgt's key │   I cannot read the TGT. Only DCs can.
     │                                              │
     │ ②  TGS-REQ ─ "here is my TGT, I want a       │
     │              ticket for SPN cifs/fs01" ────► │
     │ ◄─ TGS-REP ─ service ticket, encrypted with  │
     │              the SERVICE account's key       │
     │                                              │
     │ ③  AP-REQ ─ present service ticket ─────► FILE SERVER
     │             the server decrypts it with its own key. It never contacts the DC.
```

**Why each step matters:**

- **The timestamp in step ① is why clock skew breaks everything.** Tolerance is **5 minutes**.
  Beyond it, pre-authentication fails and the user cannot log in at all.
- **The TGT is encrypted with krbtgt's key**, which is why stealing that hash yields a
  **Golden Ticket** — see [`../ad-ds/`](../ad-ds/) §7.
- **The service ticket is encrypted with the service account's key.** Any authenticated user can
  request one for any SPN and crack it offline — **Kerberoasting**. The DC does not check whether
  you are allowed to use the service.
- **Step ③ never touches a DC.** This is why a **Silver Ticket** leaves no DC log entry, and why
  authentication can appear to work while the DC is down.

**Inspect your own ticket cache** — ✅ real output from a **non-domain-joined** machine:

```powershell
klist
```

```
Current LogonId is 0:0x1740e5
Cached Tickets: (0)
```

**Zero tickets, because there is no domain to issue them.** On a domain-joined machine you would
see a `krbtgt/DOMAIN` entry (the TGT) plus one per service used. Useful commands:

```powershell
klist purge      # drop tickets — forces fresh ones; fixes "stale group membership" complaints
klist tgt        # inspect the TGT specifically
setspn -Q */*    # enumerate SPNs — also exactly what an attacker runs first
```

> **"I added them to a group but they still get access denied."** Group membership is baked into
> the **PAC** inside the ticket at issue time. `klist purge` then sign out and back in. This is a
> daily-use fact that almost nobody learns from documentation.

**NTLM is the fallback**, and it is the thing to be eliminating: no mutual authentication,
relay-able, and the reason `Protected Users` blocks it. Kerberos requires an SPN and working DNS —
so **when DNS breaks, authentication silently falls back to NTLM**, and security teams see an
unexplained NTLM spike. That correlation is a genuinely senior observation.

---

## 5. LDAP — reading the directory

| Port | Protocol | Scope |
|---:|---|---|
| **389** | LDAP | Domain. Plaintext unless signed/sealed. |
| **636** | LDAPS | Domain, TLS-wrapped. Needs a certificate on the DC. |
| **3268** | Global Catalog | ⭐ **Forest-wide**, partial attribute set |
| **3269** | GC over TLS | Forest-wide |

> **Query the forest, not the domain: use 3268.** An app configured against 389 in a multi-domain
> forest will "not find" users who exist — they are simply in another domain. Common, and commonly
> misdiagnosed as a permissions problem.

**LDAP signing and channel binding.** Unsigned simple binds send credentials in cleartext and are
relay-able. Microsoft hardened the defaults; enforcement state varies by build and by policy.
⚠ **check the current enforcement setting in the target estate rather than assuming** — this is
one of the few areas here that has genuinely moved. Audit before enforcing:

```powershell
# Event 2889 on DCs = a client performed an unsigned/cleartext bind. Find them BEFORE enforcing.
Get-WinEvent -LogName 'Directory Service' -FilterXPath "*[System[EventID=2889]]" -MaxEvents 50 |
  Select-Object TimeCreated, Message
```

Enforcing without this audit is a well-known way to take down every legacy LDAP application at
once — printers, scanners, and old line-of-business apps are the usual casualties.

---

## 6. Group Policy — order decides everything

Settings apply in **LSDOU** order, and **later overwrites earlier**:

```
Local  →  Site  →  Domain  →  OU  →  nested OU (deepest wins)
```

Two modifiers invert the model, and they are where the confusion lives:

- **`Enforced`** on a GPO link — that GPO wins regardless of depth, and cannot be blocked.
- **`Block Inheritance`** on an OU — stops parent GPOs, **except Enforced ones**.

> **Enforced beats Block Inheritance.** Interview question, and a real source of "why is this
> setting still applying?"

**Loopback processing** applies the *computer's* user-policies to whoever logs on. This is the
right answer for kiosks, VDI and shared terminals, and it is the cause of the most baffling GPO
tickets when someone enabled it and forgot.

**Two independent filters** decide whether a linked GPO applies at all:

- **Security filtering** — the principal needs **Read + Apply group policy**. Removing
  "Authenticated Users" without granting Read elsewhere silently disables the GPO.
- **WMI filtering** — evaluated per machine, and **slow**. A heavy WMI filter is a real logon-time
  cost.

**Diagnose, don't guess:**

```powershell
gpupdate /force
gpresult /h C:\gpreport.html /f      # ⭐ the readable answer: what applied, what was filtered, and why
gpresult /r                          # quick console summary
```

`gpresult /h` names the **winning GPO per setting**. It ends arguments in seconds.

GPOs live in two halves that must agree: the **GPC** in AD (replicated by AD replication) and the
**GPT** in SYSVOL (replicated by **DFSR**). When these disagree — usually broken DFSR — policy
applies inconsistently by DC, which presents as "it works for some people". Check with
`dcdiag /test:sysvolcheck /test:advertising`.

---

## 7. What breaks — symptom to root cause

| Symptom | Most likely | Confirm with |
|---|---|---|
| Cannot log in; DC pings fine by IP | **DNS** — client cannot find a DC | `nltest /dsgetdc:<domain>` |
| "Clock skew too great" / random logon failure | **Time** — PDCe hierarchy | `w32tm /query /status` |
| Access denied right after a group change | **PAC is stale** in the cached ticket | `klist` then `klist purge` |
| App cannot find users that exist | **LDAP 389 vs GC 3268** in a multi-domain forest | Retarget to 3268 |
| Legacy app breaks after a security push | **LDAP signing/channel binding** | Event **2889** |
| GPO not applying to some users | Security filtering, or **Block Inheritance** | `gpresult /h` |
| Policy applies inconsistently by user | **SYSVOL/DFSR** divergence | `dcdiag /test:sysvolcheck` |
| Unexplained NTLM spike | Kerberos failing → silent fallback | Correlate with DNS/SPN health |

---

## 8. Customer discovery questions

1. What DNS servers do clients and DCs use? Any public resolver in the chain?
2. Is the **time hierarchy** correct — PDCe to an external source, everyone else to the PDCe?
3. Is **LDAP signing / channel binding** enforced, and was Event **2889** audited first?
4. Any application still using **LDAP 389 simple bind** with credentials?
5. Are there **Enforced** GPOs or **Block Inheritance** OUs, and does anyone remember why?
6. Is **loopback processing** enabled anywhere? Deliberately?
7. Is SYSVOL on **DFSR**? Is it healthy? *(FRS is dead and any survivor is an emergency.)*
8. NTLM usage trend — falling, or quietly rising?

---

## 9. Remember it

**Hook — LSDOU** for GPO order (Local, Site, Domain, OU; later overwrites earlier), and
**"Enforced beats Block Inheritance."**

**Analogy — Kerberos is a theme park.** Show ID at the gate once, get a **wristband** (TGT). At each
ride, swap the wristband for a **ride ticket** (service ticket). The ride operator checks the ticket
**without phoning the gate** — which is exactly why a forged Silver Ticket leaves no entry in the
gate's log, and why authentication keeps working briefly after a DC dies.

**The one thing:** group membership is baked into the **PAC** when the ticket is issued. New group,
still denied → `klist purge`, then sign out and back in.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 10. Self-test

1. Which DNS record lets a branch client prefer a local DC, and why does it matter?
2. Client can ping the DC by IP but cannot log in. First thing you check?
3. Why does 5 minutes of clock skew stop authentication entirely?
4. Why does presenting a service ticket generate no DC log entry?
5. User added to a group, still denied. Why, and the two-command fix?
6. Ports 389 and 3268 — when does the difference bite?
7. `Enforced` on a parent GPO vs `Block Inheritance` on the child OU. Who wins?
8. A GPO is linked and enabled but does not apply to some users. Two likely causes?
9. Why might breaking DNS cause a *security* alert about NTLM?

<details>
<summary>Answers</summary>

1. `_ldap._tcp.<site>._sites.dc._msdcs.<domain>`. Without it, clients may authenticate across a
   slow WAN link to a remote DC.
2. **DNS.** Network reachability is fine; the client cannot *discover* a DC. `nltest /dsgetdc:`.
3. Pre-authentication encrypts a **timestamp**. Outside the **5-minute** window the KDC rejects it,
   so no TGT is issued.
4. The service ticket is decrypted by the **service's own key** — step ③ never contacts a DC.
   Hence Silver Tickets are invisible to DC logs.
5. Group membership is in the **PAC**, fixed when the ticket was issued. `klist purge`, then sign
   out and back in.
6. **389 is domain-scoped, 3268 is forest-wide.** In a multi-domain forest, an app on 389 cannot
   see users in other domains.
7. **Enforced wins.** Block Inheritance does not stop an Enforced link.
8. **Security filtering** (missing Read + Apply group policy) or **Block Inheritance**. Confirm
   with `gpresult /h`.
9. Kerberos needs DNS and a valid SPN. When it fails, clients **silently fall back to NTLM**, so
   NTLM volume rises without any change in user behaviour.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — resolve the `_msdcs` SRV records in your own domain; capture `klist` before and
  after purge; produce a `gpresult /h` report showing a winning GPO.
- **`break-fix/`** — point a client at a public DNS resolver and document the exact failure; skew a
  clock past 5 minutes; block a GPO with security filtering and diagnose it only from `gpresult`.
- **`security/`** — Event 2889 audit; SPN inventory versus gMSA; NTLM usage baseline; LDAPS
  certificate validity.
- **`operations/`** — time hierarchy diagram; `dcdiag` and `repadmin` baselines.
- **`architecture-decisions/`** — ADR: LDAP signing enforcement, with the 2889 audit as evidence
  and a named remediation window for the legacy apps it will break.
- **`customer-use-cases/`** — §7 symptom table applied to real incidents.
