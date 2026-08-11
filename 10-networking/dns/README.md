# DNS

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The highest-value topic in this domain.** More "identity is broken" incidents are DNS than
> any other single cause. Pairs with
> [`../../35-active-directory-and-hybrid-identity/dns-kerberos-ldap-gpo/`](../../35-active-directory-and-hybrid-identity/dns-kerberos-ldap-gpo/)
> and is a hard prerequisite for [`../private-endpoints/`](../private-endpoints/).

---

## 1. What it is

A distributed, hierarchical, **cached** database mapping names to records. Every one of those four
words causes a distinct class of failure — especially *cached*.

---

## 2. Why it breaks so much

DNS is the **first** step of nearly every transaction and it **fails silently by design**. A stale
cached answer is indistinguishable from a correct one. A resolver returning a public answer where a
private one was expected returns `NOERROR` — success — and the connection then fails somewhere far
away, at a layer that looks unrelated.

> **Rule of thumb that will serve you for a career: if something worked yesterday and nothing
> changed, suspect DNS or a certificate.** Those are the two things that change by themselves.

---

## 3. How it works underneath — resolution order

```
Application asks for  fs01.corp.contoso.com
      │
      ├─ 1. HOSTS file            ← wins over everything. Check it. People forget.
      ├─ 2. Local resolver cache  ← stale answers live here
      ├─ 3. Configured DNS server
      │        ├─ authoritative for the zone? → answer
      │        ├─ conditional forwarder?      → send to a specific server
      │        └─ forwarder / root hints      → recurse
      └─ 4. answer + TTL → cached at every layer on the way back
```

**Record types that matter here:**

| Type | Purpose |
|---|---|
| `A` / `AAAA` | Name → IPv4 / IPv6 |
| `CNAME` | Alias. **Cannot coexist with other records at the same name.** |
| `SRV` | ⭐ Service location — how AD clients find DCs |
| `PTR` | Reverse. Often stale; some apps depend on it |
| `TXT` | Domain verification, SPF/DKIM/DMARC |
| `NS` / `SOA` | Delegation and zone authority |

**TTL is the blast radius of a change.** A record with a 24-hour TTL takes up to 24 hours to
propagate. Before any planned cutover, **lower the TTL well in advance** — a day before a migration
is too late, because the *old* TTL governs how long the old answer survives.

---

## 4. Worked example — the SRV lookup that finds a domain controller

✅ Real output, runnable now with no AD:

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

That is exactly the mechanism AD uses. **Priority** selects the group — lower wins. **Weight**
distributes load within equal priority.

Against a real domain:

```powershell
Resolve-DnsName '_ldap._tcp.dc._msdcs.corp.contoso.com' -Type SRV
Resolve-DnsName '_ldap._tcp.uk-south._sites.dc._msdcs.corp.contoso.com' -Type SRV   # site-aware
nltest /dsgetdc:corp.contoso.com                                                     # what the client chose
```

**Diagnostic commands worth knowing cold:**

```powershell
Resolve-DnsName learn.microsoft.com                       # uses the local resolver + cache
Resolve-DnsName learn.microsoft.com -Server 1.1.1.1       # bypass local — compare answers
Resolve-DnsName learn.microsoft.com -DnsOnly -NoHostsFile # ignore HOSTS and NetBIOS

Get-DnsClientServerAddress -AddressFamily IPv4            # what am I actually asking?
Get-DnsClientCache | Where-Object Entry -like '*contoso*' # what is cached right now
Clear-DnsClientCache                                      # flush local
```

> ⭐ **The single most valuable DNS diagnostic is comparing two resolvers.** If
> `Resolve-DnsName name` and `Resolve-DnsName name -Server 1.1.1.1` disagree, you have found the
> problem: split-brain, a conditional forwarder, or a private zone. That one comparison replaces
> an hour of guessing.

---

## 5. Split-brain, and why Azure makes it mandatory

The same name resolves differently inside and outside the network — **deliberately**.

```
   contoso.com  ─ from the internet ──► 20.x.x.x    (public front door)
   contoso.com  ─ from inside ────────► 10.x.x.x    (internal server)
```

In Azure this is not optional once you use **Private Endpoints**. The public name
`myaccount.blob.core.windows.net` must resolve to a **private** IP from inside the VNet, which is
done with a **Private DNS Zone** linked to the VNet.

```
Client in VNet asks:  myaccount.blob.core.windows.net
      │
      ├─ Azure-provided DNS (168.63.129.16)
      ├─ checks linked Private DNS Zone  privatelink.blob.core.windows.net
      └─ returns 10.0.1.4                ← the private endpoint NIC
```

**`168.63.129.16` is a fixed, Microsoft-owned virtual IP** present in every VNet. It serves DNS,
DHCP and health probes. It must never be blocked by an NSG or firewall — doing so breaks name
resolution and load-balancer health probes in ways that look like application failures.

**The classic private endpoint failure:** the endpoint is created, everything looks right, and
clients still reach the public IP — because the Private DNS Zone was not **linked to the VNet**, or
an on-premises resolver still answers with the public address. See
[`../private-endpoints/`](../private-endpoints/).

---

## 6. Hybrid DNS — the pattern that actually works

On-premises clients must resolve Azure private names, and Azure clients must resolve on-premises
names. Azure-provided DNS is not reachable from on-premises, so you need a resolver in the middle:

```
On-prem clients ──► on-prem DNS ──(conditional forwarder for
                                   privatelink.*.core.windows.net)──►  Azure DNS Private Resolver
                                                                              │
                                                                              ▼
                                                                    Private DNS Zones

Azure clients   ──► Azure DNS ──(forwarding ruleset for corp.contoso.com)──► on-prem DNS
```

**Azure DNS Private Resolver** is the managed answer; before it existed, everyone ran a pair of DNS
forwarder VMs, and many estates still do. ⚠ Check which is deployed before designing around either.

**Conditional forwarders are the mechanism.** Forward only the specific zones — never forward
everything, or you break internet resolution or create a loop.

---

## 7. What breaks

**Stale cache after a change.** Flush at every layer: client (`Clear-DnsClientCache`), server
(`Clear-DnsServerCache`), and any intermediate resolver. Then remember downstream TTLs.

**HOSTS file entries** left behind by a previous engineer. They win over DNS and are invisible to
every DNS diagnostic. Check `C:\Windows\System32\drivers\etc\hosts` early — `-NoHostsFile` proves it.

**CNAME at the zone apex.** `contoso.com` cannot be a CNAME if it also has `MX` or `NS` records.
Use the provider's alias/ALIAS record instead.

**Clients pointed at public DNS.** Domain members using `8.8.8.8` cannot see `_msdcs` records, so
they cannot find a DC at all. Presents as total authentication failure with perfect network
connectivity.

**Blocking `168.63.129.16`.** Breaks Azure DNS and health probes.

**Private DNS Zone not linked to the VNet.** Private endpoint created, still resolving public.
Consistently the most common Azure private-networking incident.

**Missing reverse (PTR) records.** Some applications and log pipelines do reverse lookups; missing
PTRs cause slow logons and multi-second delays that nobody attributes to DNS.

---

## 8. Customer discovery questions

1. What DNS servers do clients use — on-premises and in each VNet?
2. Any **public resolver** configured anywhere on a domain-joined machine?
3. Is there **split-brain**, and is it documented?
4. Private endpoints in use? Are the Private DNS Zones **linked to every VNet that needs them**?
5. How do on-premises clients resolve Azure private names — Private Resolver or forwarder VMs?
6. Which zones have **conditional forwarders**, and who maintains them?
7. What TTLs are used on records involved in failover?
8. Is `168.63.129.16` reachable from every subnet?
9. Any HOSTS file entries in the standard build? *(Ask; the answer is often yes.)*

---

## 9. Remember it

**Hook — "Two resolvers, one truth."** Ask the local resolver and a public one; disagreement
localises the fault in a single step.

**Analogy — a phone book that everyone photocopies.** Copies live in the app, the OS, the resolver
and every device in between, each with its own expiry (TTL). A stale copy looks exactly like a
correct one — which is why DNS fails **silently** rather than loudly.

**The one thing:** if it worked yesterday and nothing changed, suspect **DNS or a certificate** —
the two things that change by themselves when a TTL or a validity period lapses.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 10. Self-test

1. Something worked yesterday, nothing changed, now it fails. Two first suspects?
2. Single most valuable DNS diagnostic, in one command pair?
3. What is `168.63.129.16` and what breaks if it is blocked?
4. Private endpoint created, clients still hit the public IP. Most likely cause?
5. Why can't a domain member use `8.8.8.8`?
6. In an SRV record, what do Priority and Weight do?
7. Why lower TTL *before* a migration rather than during?
8. Why can `contoso.com` not be a CNAME?
9. DNS looks correct but the app still resolves wrongly. What have you not checked?

<details>
<summary>Answers</summary>

1. **DNS or a certificate** — the two things that change without anyone touching them (TTL
   expiry, cert expiry).
2. `Resolve-DnsName x` versus `Resolve-DnsName x -Server 1.1.1.1`. Disagreement localises the fault
   immediately.
3. Azure's fixed platform IP for **DNS, DHCP and health probes**. Blocking it breaks name
   resolution and load-balancer probes.
4. The **Private DNS Zone is not linked to the VNet** (or on-prem DNS still answers publicly).
5. It cannot see the internal `_msdcs` **SRV** records, so it cannot locate a domain controller.
6. **Priority** picks the group (lower wins); **Weight** load-balances within equal priority.
7. The **old** TTL governs how long stale answers persist. Lowering it during the migration is too late.
8. A CNAME cannot coexist with other records at the same name, and the apex must carry `NS` and `SOA`.
9. The **HOSTS file** — it wins over DNS and is invisible to DNS tooling. Prove with `-NoHostsFile`.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — resolve SRV records; compare two resolvers on the same name; inspect and clear the
  client cache.
- **`break-fix/`** — create a private endpoint **without** linking the Private DNS Zone, prove it
  resolves publicly, then link it and prove the change. **The most valuable single lab in this domain.**
- **`security/`** — confirm no public resolvers on domain members; DNS query logging in place;
  `168.63.129.16` reachability verified.
- **`operations/`** — hybrid DNS diagram with every conditional forwarder and its owner; TTL
  standards for failover records.
- **`architecture-decisions/`** — ADR: Azure DNS Private Resolver versus forwarder VMs.
