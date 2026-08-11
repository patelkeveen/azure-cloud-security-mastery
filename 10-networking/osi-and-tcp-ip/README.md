# OSI and TCP/IP

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> The mental model the rest of this domain hangs on. **Its real value is diagnostic**: it tells you
> which layer to test next instead of guessing.

---

## 1. What it is

A layered model of how data moves between machines. Each layer talks to its peer on the other host
and treats everything below it as a working pipe.

**OSI has seven layers and is the vocabulary. TCP/IP has four and is what actually runs.**

| OSI | TCP/IP | What lives there | You debug it with |
|---:|---|---|---|
| 7 Application | Application | HTTP, DNS, LDAP, Kerberos, SMB | `curl`, `Resolve-DnsName` |
| 6 Presentation | Application | **TLS**, encoding | `openssl s_client` |
| 5 Session | Application | Sessions, RPC | — |
| 4 Transport | Transport | **TCP, UDP** — ports | `Test-NetConnection -Port` |
| 3 Network | Internet | **IP**, routing, ICMP | `ping`, `tracert`, `Get-NetRoute` |
| 2 Data Link | Link | MAC, ARP, VLANs | `arp -a` |
| 1 Physical | Link | Cable, radio | Link lights |

---

## 2. Why it exists

Without layering, every application would implement its own routing and retransmission. Layering
means HTTP does not know or care whether it is on fibre or Wi-Fi.

**For you, the payoff is diagnostic order.** "The app is broken" is not actionable. "DNS resolves,
TCP connects, TLS fails" is a fix. Layers give you a **binary search over the failure**, which is
the difference between ten minutes and a day.

---

## 3. How it works underneath — encapsulation

Each layer wraps the one above:

```
   Application data                      "GET /api/users"
        ↓  + TLS record
   [TLS| GET /api/users ]
        ↓  + TCP header (src port, dst port, seq, ack, flags)
   [TCP|TLS| ... ]                       dst port 443
        ↓  + IP header (src IP, dst IP, TTL, protocol)
   [IP|TCP|TLS| ... ]                    dst 20.112.52.29
        ↓  + Ethernet header (src MAC, dst MAC)
   [ETH|IP|TCP|TLS| ... ]                dst MAC = the ROUTER's, not the server's
```

> ⭐ **The destination MAC is the next hop; the destination IP is the final target.** MAC rewrites
> at every hop, IP does not. Internalising this single asymmetry explains routing, ARP, NAT, and
> why a firewall in the path can see IPs and ports but not names.

**MTU and fragmentation.** Ethernet's default payload is **1500 bytes**. Add tunnelling — IPsec
VPN, WireGuard, some overlays — and the usable payload shrinks. If a router cannot fragment and the
"don't fragment" bit is set, it should return ICMP "fragmentation needed". **Networks that block all
ICMP break this feedback**, producing the classic symptom: *small requests work, large ones hang
forever.* Blocking ICMP wholesale is a self-inflicted wound, and it is still common.

---

## 4. TCP versus UDP — and why identity protocols care

| | TCP | UDP |
|---|---|---|
| Connection | Handshake first | Fire and forget |
| Ordering / retransmit | ✅ | ✗ — the app must handle it |
| Cost | Round trips before data | One packet |
| Used by | HTTP, LDAP, SMB, **Kerberos over 1465 bytes** | DNS (small), **Kerberos (default)** |

**The TCP three-way handshake:**

```
Client ── SYN ──────────────► Server
Client ◄── SYN-ACK ────────── Server
Client ── ACK ──────────────► Server        connection established
```

Read the failure mode, because each means something different:

| Response | Meaning |
|---|---|
| **SYN-ACK** | Open. Something is listening. |
| **RST** | Reachable, but **nothing listening on that port** — you got to the host |
| **Nothing (timeout)** | ⭐ Silently dropped — almost always a **firewall or NSG** |

> **RST versus timeout is the single most useful distinction in network troubleshooting.** RST
> means routing works and the service is down. Timeout means something is eating your packets, and
> you should be looking at a firewall rule, not the application.

**Why Kerberos cares:** Kerberos uses **UDP 88** by default, but a ticket carrying a large PAC —
a user in many groups — exceeds the UDP limit and **switches to TCP 88**. Firewalls opened for
UDP 88 only produce a memorable symptom: *most users authenticate, users in many groups fail.*
That is not an AD problem; it is a firewall rule.

---

## 5. Worked example — walking the layers in order

Diagnose top-down or bottom-up, but **go in order**. Stop at the first failure.

```powershell
# L3 - is the host reachable at all?
Test-NetConnection -ComputerName learn.microsoft.com

# L4 - is the PORT open? (the one that actually matters)
Test-NetConnection -ComputerName learn.microsoft.com -Port 443

# L7 - does the application respond?
curl.exe -sS -o NUL -w "%{http_code}\n" https://learn.microsoft.com
```

`Test-NetConnection -Port` output, and how to read it:

```
ComputerName     : learn.microsoft.com
RemoteAddress    : 20.112.52.29
RemotePort       : 443
TcpTestSucceeded : True          <-- L4 is fine. Any failure now is L5-7.
PingSucceeded    : False         <-- ICMP blocked. NOT a fault. See below.
```

> ⭐ **`PingSucceeded : False` with `TcpTestSucceeded : True` is normal and healthy.** Most cloud
> endpoints drop ICMP. Engineers who test reachability with `ping` alone declare working services
> broken every day. **Test the port, not the host.**

**Reading the result:**

| L3 | L4 | L7 | Diagnosis |
|:---:|:---:|:---:|---|
| ✅ | ✅ | ✗ | Application, TLS, or auth — network is fine, stop looking at it |
| ✅ | ✗ (timeout) | — | **Firewall / NSG** dropping silently |
| ✅ | ✗ (RST) | — | Reachable; **service not listening** |
| ✗ | ✗ | — | Routing or DNS — resolve the name first |

---

## 6. Where each layer fails in a Microsoft identity estate

This is why a networking topic sits in an identity repository:

| Layer | Failure | Presents as |
|---|---|---|
| **L3** routing | No route to the DC subnet | "Cannot log in" |
| **L4** ports | UDP 88 open, TCP 88 closed | Users **in many groups** fail Kerberos |
| **L4** ports | 636 blocked | LDAPS fails, app falls back to plaintext 389 |
| **L6** TLS | Expired or untrusted certificate | AD FS outage; see [`../tls-pki-and-certificates/`](../tls-pki-and-certificates/) |
| **L7** DNS | `_msdcs` SRV unreachable | Client cannot find a DC; **silent NTLM fallback** |

Every one of these arrives at the service desk as "Active Directory is broken."

---

## 7. What breaks

**Blocking all ICMP.** Breaks Path MTU Discovery. Symptom: small requests succeed, large ones hang.
Allow ICMP type 3 code 4 at minimum.

**Testing with `ping`.** See §5. Cloud endpoints drop ICMP by design.

**Assuming a timeout means "server down".** It usually means a firewall. Check for an RST.

**Ignoring MTU on VPN.** IPsec overhead shrinks usable payload; large packets vanish. Symptom looks
like application instability, not networking.

**Confusing "port open" with "service healthy".** A load balancer can accept TCP and forward to a
dead backend. `TcpTestSucceeded : True` proves L4 only — always finish with an L7 check.

---

## 8. Customer discovery questions

1. Is ICMP blocked end to end? Is **type 3 code 4** permitted?
2. What is the MTU on the VPN or ExpressRoute path? Any known large-packet issues?
3. Are **both UDP and TCP 88** open to every DC from every client subnet?
4. Do firewall rules use names or IPs? *(Names imply DNS resolution inside the firewall — its own
   failure mode.)*
5. When something breaks, does anyone test **per layer**, or is it "restart it"?
6. Is 389 still permitted alongside 636? *(Encourages silent plaintext fallback.)*

---

## 9. Remember it

**Hook — "Silence is a firewall; RST is an answer."** Timeout means something ate your packet;
RST means you reached the host and nothing was listening.

**Analogy — the postal system.** The **envelope** address (MAC) is rewritten at every sorting depot;
the **letter's** address (IP) never changes. That asymmetry explains routing, ARP, NAT, and why a
firewall in the path sees addresses and ports but never names.

**The one thing:** the destination **MAC is the next hop**, the destination **IP is the target**.
Test the **port**, never `ping` — cloud endpoints drop ICMP by design.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 10. Self-test

1. In an Ethernet frame to a server on another network, whose MAC is the destination?
2. `TcpTestSucceeded : True`, `PingSucceeded : False`. Broken?
3. TCP connect returns RST versus times out. Different causes?
4. Kerberos works for most users but fails for those in many groups. Why?
5. Why does blocking all ICMP break large transfers?
6. Which layer does TLS sit at, and what does that mean for a firewall doing IP/port filtering?
7. Fastest way to prove the network is *not* the problem?
8. LDAP client connects on 389 and works; security asks why traffic is cleartext. Which layer, which fix?

<details>
<summary>Answers</summary>

1. **The router's** (the next hop). The destination **IP** is the server. MAC rewrites every hop.
2. **No — normal.** ICMP is dropped by most cloud endpoints. The port test is what matters.
3. **RST** = host reachable, nothing listening. **Timeout** = silently dropped, almost always a
   firewall/NSG.
4. Large PAC exceeds the UDP limit and Kerberos switches to **TCP 88**, which is not open.
5. It breaks **Path MTU Discovery** — the "fragmentation needed" message never arrives, so large
   packets are dropped silently.
6. **L6** (presentation). A firewall filtering IP and port sees the connection but **not the
   content** — it cannot tell you the certificate expired.
7. `Test-NetConnection -Port`. TCP success means L1–L4 are fine; look higher.
8. **L4/L6.** Move to **636 (LDAPS)** and block 389, or enforce signing — see
   [`../../35-active-directory-and-hybrid-identity/dns-kerberos-ldap-gpo/`](../../35-active-directory-and-hybrid-identity/dns-kerberos-ldap-gpo/).

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — run the §5 three-command ladder against a working and a broken endpoint; capture both.
- **`break-fix/`** — block a port with an NSG and record the **timeout**; stop the service and
  record the **RST**. Put the two outputs side by side — that contrast *is* the lesson.
- **`security/`** — the port matrix for identity traffic (88 TCP+UDP, 389, 636, 3268, 3269, 445).
- **`operations/`** — a layer-ordered triage runbook the service desk can follow.
- **`architecture-decisions/`** — ADR: ICMP policy, with Path MTU Discovery as the justification.
