# DHCP

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> Small topic, two disproportionately important consequences: **it is an attack surface**, and
> **Azure's version is not the one you know**.

---

## 1. What it is

A protocol that hands a client an IP address, subnet mask, default gateway, DNS servers and a lease
duration — automatically, before the client has an address to communicate with.

That bootstrapping problem is why it works the way it does: the client must ask **without** having
an address, so it broadcasts.

---

## 2. Why it is a security topic

DHCP has **no authentication of the server**. A client takes the first plausible answer. Whoever
answers gets to tell the client:

- which **default gateway** to use → a man-in-the-middle position
- which **DNS server** to use → ⭐ control of every name the client resolves

> **Controlling DNS is functionally equivalent to controlling the network for most purposes.** You
> can redirect any hostname, and the client has no way to detect it at this layer. That is why rogue
> DHCP is a serious attack and not a nuisance.

The IPv6 equivalent — rogue **Router Advertisements** — is worse, because IPv6 is often enabled and
unmonitored. The `mitm6` technique chains exactly this into NTLM relay against Active Directory. See
[`../ipv4-ipv6-subnetting/`](../ipv4-ipv6-subnetting/) §6.

---

## 3. How it works underneath — DORA

```
Client                                        Server
   │  ① DISCOVER  broadcast, "anyone there?"  →
   │                                          ← ② OFFER    "take 10.0.1.57"
   │  ③ REQUEST   broadcast, "I'll take it"   →
   │                                          ← ④ ACK      lease confirmed
```

**Steps ① and ③ are broadcasts**, which produces two consequences:

1. **Any device on the segment can answer** — hence rogue DHCP.
2. **Broadcasts do not cross routers**, so a server on another subnet needs a **DHCP relay** (IP
   helper) on the router to forward requests.

**Lease renewal** happens at **50%** of the lease (T1) directly to the server, and at **87.5%** (T2)
by broadcast if that failed. A client whose lease expires entirely goes back to DISCOVER — and if
nothing answers, Windows self-assigns a **169.254.x.x** APIPA address.

> ⭐ **`169.254.x.x` on an interface means DHCP failed.** Not "a network problem" generically — the
> client asked and nobody answered. That address is diagnostic, and it points at the DHCP path
> specifically: dead server, blocked relay, or exhausted scope.

**Key options** — the numbers appear in captures and vendor documentation:

| Option | Meaning |
|---:|---|
| 1 | Subnet mask |
| 3 | **Default gateway** |
| 6 | **DNS servers** |
| 15 | DNS domain name |
| 51 | Lease time |
| 66 / 67 | TFTP server / boot file — **PXE boot** |

Options 66/67 matter because **PXE and DHCP interact**. Two servers answering with different boot
files is a classic imaging failure, and it is why imaging teams and network teams end up in the same
meeting.

---

## 4. Azure — what is different, and it is most of it

**Azure runs DHCP for you and you cannot turn it off or replace it.**

| | On-premises | **Azure** |
|---|---|---|
| Server | You run it | **Platform**, via `168.63.129.16` |
| Custom scopes | Yes | ✗ |
| Reservations | Yes | ✗ — use a **static NIC allocation** instead |
| Lease | You choose | **Infinite** for the NIC's lifetime |
| Custom options | Yes | ✗ — except DNS, set at VNet or NIC level |
| Rogue DHCP risk | **Real** | ⭐ **Eliminated** — the fabric will not deliver rogue offers |

**The critical operational rule:**

> ⭐ **Never set a static IP inside the guest OS in Azure.** Set the allocation to **Static on the
> NIC**, and let DHCP continue to deliver that same address to the guest.

Configuring the address inside Windows or Linux instead breaks in ways that look unrelated: the VM
loses connectivity after a platform maintenance event or a resize, DNS settings applied at VNet
level stop reaching it, and the mismatch is invisible in the portal — which shows the NIC's
configured address, not what the guest believes.

```bash
# The correct way to pin an address
az network nic ip-config update -g rg-prod --nic-name vm-app-nic -n ipconfig1 \
  --private-ip-address 10.100.1.10 --set privateIpAllocationMethod=Static
```

```bash
az network nic ip-config list -g rg-prod --nic-name vm-app-nic \
  --query "[].{name:name, ip:privateIPAddress, method:privateIPAllocationMethod}" -o table
```

```
Name       Ip            Method
---------  ------------  ------
ipconfig1  10.100.1.10   Static
```

**Verify what the guest actually received:**

```powershell
Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway, DnsServer
Get-NetIPInterface -AddressFamily IPv4 | Select-Object InterfaceAlias, Dhcp
```

```
InterfaceAlias  Dhcp
--------------  ----
Ethernet        Enabled       <-- correct in Azure, even for a "static" address
```

⭐ **`Dhcp: Enabled` with a Static NIC allocation is the correct combination.** Seeing `Disabled`
means someone hard-coded it in the guest and you have found a latent outage.

**DNS in Azure** is set at the VNet (or NIC) level and delivered by DHCP. Changing it requires a
**NIC restart or VM reboot** to take effect — the lease is infinite, so nothing re-requests options
on its own. This surprises people who change VNet DNS and expect immediate propagation.

---

## 5. What breaks

**`169.254.x.x` address.** DHCP failed — server down, relay missing, or scope exhausted.

**Scope exhaustion.** More devices than addresses; new clients get nothing while existing ones are
fine. Look at lease *utilisation*, not just server health.

**Missing DHCP relay** on a routed subnet. Broadcasts do not cross routers.

**Two DHCP servers with overlapping scopes.** Duplicate addresses, intermittent failures that move
around the estate.

**Rogue DHCP server.** Often accidental — a home router plugged into a corporate port. Mitigate with
**DHCP snooping** on switches, permitting server responses only on trusted ports.

**Static IP set in the guest in Azure.** See §4. The most common Azure-specific failure here.

**VNet DNS changed, VMs still using the old servers.** Infinite lease; reboot or restart the NIC.

**Short lease times on a large network.** Renewal traffic and server load scale inversely with lease
duration.

---

## 6. Customer discovery questions

1. On-premises: where are the DHCP servers, and are they redundant? *(Failover pair, or split scope?)*
2. What is scope utilisation on the busiest subnets?
3. Is **DHCP snooping** enabled on access switches?
4. Is IPv6 enabled? Is **RA Guard** configured? *(The bigger risk today.)*
5. In Azure, are any VMs configured with static IPs **inside the guest**?
6. Is VNet DNS set correctly, and have VMs been restarted since it last changed?
7. Does anything depend on DHCP options 66/67 for PXE?
8. Are lease durations appropriate for each network's device turnover?

---

## 7. Remember it

**Hook — DORA** (Discover, Offer, Request, Ack), and in Azure:
**"Static on the NIC, never in the guest."**

**Analogy — a hotel front desk with no ID check.** Whoever answers first assigns your room, tells you
which corridor is the exit (**default gateway**) and which directory to trust (**DNS servers**).
Nobody verifies the desk is real — which is exactly why rogue DHCP is an attack and not a nuisance.

**The one thing:** `169.254.x.x` means **DHCP failed** — the client asked and nobody answered. And
in Azure, `Dhcp: Enabled` on a statically allocated NIC is **correct**; `Disabled` means someone
hard-coded it in the guest and you have found a latent outage.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 8. Self-test

1. What are the four DORA steps and which are broadcast?
2. What does a `169.254.x.x` address tell you specifically?
3. Why is a rogue DHCP server a serious attack rather than a nuisance?
4. Which two options give an attacker the most leverage?
5. In Azure, how do you pin a VM's IP address correctly?
6. In an Azure guest, should DHCP be Enabled or Disabled for a statically allocated NIC?
7. VNet DNS changed but VMs still use the old servers. Why, and what fixes it?
8. Why does a DHCP server on a different subnet need extra configuration?

<details>
<summary>Answers</summary>

1. **DISCOVER, OFFER, REQUEST, ACK.** DISCOVER and REQUEST are broadcast.
2. **DHCP failed** — the client asked and nothing answered. Server, relay, or exhausted scope.
3. It sets the **default gateway** and **DNS servers**, giving a man-in-the-middle position and
   control of every name the client resolves.
4. **Option 3** (default gateway) and **option 6** (DNS servers).
5. Set the **NIC** allocation to **Static** in Azure. Never configure it inside the guest OS.
6. **Enabled.** Azure delivers the pinned address via DHCP. `Disabled` means someone hard-coded it.
7. The lease is **infinite**, so options are never re-requested. Restart the NIC or reboot the VM.
8. DHCP DISCOVER is a **broadcast** and broadcasts do not cross routers — a **DHCP relay / IP
   helper** is required.

</details>

---

## 9. Evidence this topic needs

- **`lab/`** — capture `Get-NetIPConfiguration` and `Get-NetIPInterface` on an Azure VM with a
  Static NIC allocation, showing `Dhcp: Enabled`.
- **`break-fix/`** — set a static IP inside the guest, then resize the VM and document the resulting
  loss of connectivity. Recover it.
- **`security/`** — DHCP snooping status on access switches; RA Guard for IPv6; rogue DHCP detection.
- **`operations/`** — scope utilisation report; lease duration standard per network type.
- **`architecture-decisions/`** — ADR: Azure IP allocation standard, explicitly forbidding in-guest
  static configuration and stating why.
