# Routing and BGP

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> How packets choose a path, and how Azure decides for you. Feeds
> [`../vpn-and-expressroute/`](../vpn-and-expressroute/).

---

## 1. What it is

**Routing** is the per-hop decision: given a destination IP, which interface do I send this out of?
**BGP** is the protocol by which networks *tell each other* which destinations they can reach.

Every router does the same thing: consult a table, pick the best match, forward. The nuance is
entirely in how "best" is defined.

---

## 2. Why it matters in Azure specifically

On-premises you configure routes. In Azure, **Azure creates them** and your job is to override
selectively. That inversion means the important skill is not writing routes — it is **reading the
effective route table** and understanding precedence.

Every "traffic is not going where I expect" incident is answered by one command (§5).

---

## 3. How it works underneath

### Longest prefix match

Given multiple matching routes, **the most specific wins** — regardless of any other attribute.

```
Destination: 10.100.3.57

Routes:
  0.0.0.0/0        → Firewall        matches (prefix length 0)
  10.100.0.0/16    → VNet local      matches (16)
  10.100.3.0/24    → NVA 10.0.9.4    matches (24)   ◄── WINS: longest prefix
```

> ⭐ **Longest prefix match beats everything, including administrative distance and BGP attributes.**
> A `/32` route always wins over a `/0`. This is how a single misconfigured specific route can
> hijack traffic that every other rule says should go elsewhere.

### Azure route precedence

Azure resolves conflicts in a fixed order **when prefixes are equal**:

```
1. User Defined Route (UDR)      ← highest
2. BGP route (from VPN/ER)
3. System route                  ← lowest
```

So a UDR beats a BGP route from on-premises, which beats Azure's built-in routes. This is exactly
how you force egress through a firewall even though a system route says "Internet".

⚠ Note the interaction: precedence applies **for the same prefix**. A more specific BGP route still
beats a less specific UDR, because longest prefix match is evaluated first. This is the subtlety
that makes route troubleshooting hard, and it is why you read the effective table rather than reason
about it.

### Next hop types

| Next hop | Meaning |
|---|---|
| `VirtualNetworkGateway` | Via VPN or ExpressRoute |
| `VnetLocal` | Inside this VNet |
| `Internet` | Out to the internet |
| `VirtualAppliance` | ⭐ To an NVA/firewall IP — the one you create |
| **`None`** | ⭐ **Traffic is dropped.** Used to blackhole deliberately |

---

## 4. BGP — only the parts that matter here

BGP exchanges **reachability**: "I can reach these prefixes; here is the path." It is the protocol
that runs the internet, and in Azure it appears whenever you connect to on-premises dynamically.

**ASN** — the number identifying each network. Azure gateways default to **65515** ⚠ verify; your
on-premises side uses your own (often a private ASN, 64512–65534).

**Why BGP rather than static routes for hybrid connectivity:**

| Static | BGP |
|---|---|
| Edit both sides when a subnet is added | **Advertised automatically** |
| No failover awareness | Withdraws routes when a path dies → **automatic failover** |
| Fine for two fixed networks | Necessary at any real scale |

**Route advertisement is a security boundary.** What on-premises advertises to Azure determines what
Azure sends over the tunnel. **Advertising `0.0.0.0/0` from on-premises forces all Azure internet
traffic through your datacentre** — that is forced tunnelling, and it is sometimes done by accident.
The symptom is a sudden collapse in cloud egress performance.

**Best-path selection** (simplified — the full list is longer):

```
1. Highest LOCAL_PREF        (your own preference, propagated internally)
2. Shortest AS_PATH          (fewest networks traversed)
3. Lowest MED                (a hint to your neighbour)
4. eBGP over iBGP
```

**AS path prepending** is the common real-world lever: advertise the same prefix with your ASN
repeated, making the path look longer so traffic prefers the other link. It is how you make an
active/active pair behave active/passive.

---

## 5. Worked example — reading the effective route table

The one command that answers "where is my traffic actually going":

```bash
az network nic show-effective-route-table -n app-vm-nic -g rg-workload -o table
```

```
Source                 State    Address Prefix   Next Hop Type           Next Hop IP
---------------------  -------  --------------   ---------------------   -----------
Default                Active   10.101.0.0/16    VnetLocal
VNetPeering            Active   10.100.0.0/16    VNetPeering
VirtualNetworkGateway  Active   192.168.0.0/16   VirtualNetworkGateway   10.100.255.4
User                   Active   0.0.0.0/0        VirtualAppliance        10.100.4.4
Default                Invalid  0.0.0.0/0        Internet
Default                Active   10.0.0.0/8       None
```

**Read it line by line — six facts:**

| Line | Tells you |
|---|---|
| `10.101.0.0/16 VnetLocal` | Local VNet traffic stays local |
| `10.100.0.0/16 VNetPeering` | The hub peering is working |
| `192.168.0.0/16 VirtualNetworkGateway` | On-premises is reachable — **and this route came from BGP** |
| `0.0.0.0/0 VirtualAppliance` **Active** | Egress is forced to the firewall ✅ |
| `0.0.0.0/0 Internet` **Invalid** | The direct route was overridden ✅ |
| `10.0.0.0/8 None` | Unused RFC1918 space is **blackholed** — not leaked |

> **`State: Invalid` does not mean broken.** It means overridden. Engineers regularly raise incidents
> about it.

**Check what BGP learned and advertised:**

```bash
az network vnet-gateway list-learned-routes -g rg-network -n vgw-hub -o table
az network vnet-gateway list-advertised-routes -g rg-network -n vgw-hub --peer 10.1.1.1 -o table
```

```
Network          NextHop      Origin  AsPath   Weight
---------------  -----------  ------  -------  ------
192.168.0.0/16   10.1.1.1     EBgp    65001    32768
192.168.10.0/24  10.1.1.1     EBgp    65001    32768
0.0.0.0/0        10.1.1.1     EBgp    65001    32768   <-- ⚠ on-prem is forcing ALL egress back
```

That last line is a finding. Unless forced tunnelling is deliberate policy, someone advertised a
default route and every Azure workload's internet traffic is now crossing the VPN.

---

## 6. What breaks

**A UDR with no route back.** You route traffic to an NVA; the NVA has no return route, so the flow
is one-way. Routes are per-direction and both must exist.

**IP forwarding not enabled on the NVA's NIC.** Azure drops packets a VM tries to forward unless
`enableIPForwarding` is set. The firewall looks healthy and silently discards everything.

**`0.0.0.0/0` advertised from on-premises.** Accidental forced tunnelling.

**More specific route overriding a UDR.** Longest prefix match wins; your `/0` UDR loses to a `/24`
BGP route.

**Blackhole routes left behind.** A `None` next hop is invisible in a diagram and silently drops
traffic.

**BGP session down but tunnel up.** Connectivity appears fine, routes are stale or missing. Check
the BGP peer status, not just the connection status.

---

## 7. Customer discovery questions

1. Static routes or BGP for hybrid connectivity?
2. What does on-premises **advertise** to Azure? Is `0.0.0.0/0` among it?
3. What does Azure advertise back — is it just the VNet ranges, or more?
4. Any UDRs, and does anyone verify them with effective routes?
5. Are there NVAs, and is **IP forwarding** enabled on their NICs?
6. Any `None` next-hop routes, and does anyone know why they exist?
7. What ASNs are in use on each side?
8. Is AS path prepending used to steer traffic between redundant links?

---

## 8. Remember it

**Hook — "Specific beats strong,"** then **U-B-S** for ties: **U**DR → **B**GP → **S**ystem.

**Analogy — postal sorting.** "London" and "10 Downing Street, London" both match, but the sorter
always uses the most specific address available, regardless of who wrote which instruction. Longest
prefix match is evaluated **before** any precedence rule.

**The one thing:** a `/24` learned by BGP beats your `/0` UDR. That is why you **read the effective
route table** instead of reasoning about intent — and why `State: Invalid` means *overridden*, not
broken.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 9. Self-test

1. `0.0.0.0/0 → firewall` (UDR) and `10.100.3.0/24 → NVA` (BGP). Where does 10.100.3.57 go?
2. Azure route precedence for equal prefixes?
3. What does `State: Invalid` mean?
4. What does a `None` next hop do?
5. On-prem advertises `0.0.0.0/0`. Consequence?
6. NVA deployed, routes correct, traffic still dropped. What is missing?
7. Why prefer BGP over static routes for hybrid?
8. How do you make one of two redundant links preferred, without changing the other side?

<details>
<summary>Answers</summary>

1. To the **NVA** — `/24` is more specific and **longest prefix match wins** before precedence is
   considered.
2. **UDR → BGP → system route.**
3. That route was **overridden** by a higher-precedence route. Not an error.
4. **Drops the traffic** — a deliberate blackhole.
5. **Forced tunnelling** — all Azure internet-bound traffic is sent to on-premises.
6. **IP forwarding on the NVA's NIC** (`enableIPForwarding`). Azure drops forwarded packets otherwise.
7. Automatic advertisement of new prefixes and **automatic failover** when a path withdraws.
8. **AS path prepending** on the link you want to be secondary, making its path look longer.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — capture an effective route table with peering, gateway, UDR and blackhole routes
  present; annotate every line.
- **`break-fix/`** — deploy an NVA without IP forwarding and diagnose the silent drop; add a more
  specific route that overrides a UDR and prove it with effective routes.
- **`security/`** — learned-routes review looking for `0.0.0.0/0`; blackhole route inventory.
- **`operations/`** — advertised/learned route baseline, re-run and diffed after every change.
- **`architecture-decisions/`** — ADR: BGP versus static; forced tunnelling posture.
