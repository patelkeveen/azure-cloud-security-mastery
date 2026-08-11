# VPN and ExpressRoute

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> Hybrid connectivity — the physical dependency underneath hybrid identity. Requires
> [`../routing-and-bgp/`](../routing-and-bgp/).

---

## 1. What it is

Two ways to connect on-premises to Azure privately:

| | **VPN Gateway** | **ExpressRoute** |
|---|---|---|
| Path | ⭐ **Over the public internet**, encrypted | ⭐ **Private circuit**, never touches the internet |
| Bandwidth | Up to ~10 Gbps (SKU-dependent) | 50 Mbps – 100 Gbps |
| Latency | Variable — internet conditions | Consistent, SLA-backed |
| Provisioning | Minutes | **Weeks to months** — a telco is involved |
| Cost | Low | High, plus carrier charges |
| Encryption | **Built in (IPsec)** | ⚠ **None by default** |

---

## 2. Why the choice matters more than it looks

The decision is usually framed as bandwidth. It is really about **predictability and lead time**.

- A VPN can be up this afternoon. ExpressRoute needs a carrier order — that is a **project
  milestone**, not a task, and discovering it late has derailed many migrations.
- ExpressRoute's value is **consistent latency**, which matters enormously for chatty protocols.
  Domain controller replication, LDAP and SMB are all latency-sensitive; throughput is rarely the
  constraint.

> ⭐ **ExpressRoute traffic is not encrypted by default.** People assume "private circuit" means
> "encrypted". It means the packets do not traverse the public internet — a different guarantee.
> Regulated workloads typically run **IPsec over ExpressRoute**, or MACsec at the physical layer.
> Being able to state this distinction cleanly marks you out in an architecture review.

---

## 3. How it works underneath

### VPN Gateway

```
On-prem VPN device ──── IPsec tunnel over internet ────► Azure VPN Gateway
                                                            │
                                                    GatewaySubnet
                                                            │
                                                          VNet
```

- **Site-to-site** — network to network. The normal case.
- **Point-to-site** — individual clients. Useful for admins and small teams.
- **Active/active** — two gateway instances, two public IPs, both live. ⭐ The default is
  active/**standby**, where failover takes time. Ask which is deployed; most people assume they have
  redundancy they do not have.

### ExpressRoute — three peering types

```
On-prem ── carrier ── ExpressRoute circuit ──┬── PRIVATE peering   → your VNets (RFC1918)
                                             ├── MICROSOFT peering → M365, PaaS public endpoints
                                             └── (public peering — retired)
```

**Private peering** is what connects your VNets. **Microsoft peering** carries traffic to Microsoft
public services.

> ⚠ **Microsoft does not recommend routing Microsoft 365 over ExpressRoute in most cases.** M365 is
> designed for internet egress close to the user; forcing it down a circuit adds latency and cost
> and usually degrades the experience. Customers ask for it constantly, believing it is faster.
> Verify current guidance before advising, but expect the answer to be "don't".

**A circuit has two connections** to two Microsoft Enterprise Edge routers for redundancy. Running
only one is a common, undetected single point of failure — the circuit *looks* healthy.

---

## 4. Worked example — diagnosing a tunnel

```bash
az network vpn-connection show -g rg-network -n conn-to-onprem \
  --query "{name:name, status:connectionStatus, ingressBytes:ingressBytesTransferred, egressBytes:egressBytesTransferred}" -o table
```

```
Name             Status     IngressBytes   EgressBytes
---------------  ---------  -------------  -----------
conn-to-onprem   Connected  48293011       51203944
```

**`Connected` is necessary but not sufficient.** Check that routes are actually being exchanged:

```bash
az network vnet-gateway list-bgp-peer-status -g rg-network -n vgw-hub -o table
```

```
Neighbor    ASN    State       ConnectedDuration   RoutesReceived
----------  -----  ----------  -----------------   --------------
10.1.1.1    65001  Connected   12:04:33            14
```

⭐ **`RoutesReceived: 0` with `State: Connected` is the classic half-failure** — the tunnel is up,
BGP is peered, and nothing is being advertised. Connectivity "works" for nothing.

```bash
az network vnet-gateway list-learned-routes -g rg-network -n vgw-hub -o table
```

**And for ExpressRoute:**

```bash
az network express-route show -g rg-network -n er-circuit \
  --query "{state:circuitProvisioningState, service:serviceProviderProvisioningState, bandwidth:serviceProviderProperties.bandwidthInMbps}" -o table
az network express-route peering list -g rg-network --circuit-name er-circuit -o table
```

```
CircuitProvisioningState  ServiceProviderProvisioningState  BandwidthInMbps
------------------------  --------------------------------  ---------------
Enabled                   Provisioned                       1000
```

**Both must read as shown.** `Enabled` + `NotProvisioned` means Azure is ready and **the carrier has
not finished their side** — a waiting-on-telco state that is frequently mistaken for a
misconfiguration and debugged for days.

---

## 5. Sizing, and the mistake that recurs

**Gateway SKU sets bandwidth, tunnel count and feature availability**, and it is not freely
changeable — some SKU changes require redeployment, which means an outage and a new public IP.

⚠ Verify current SKU tables before quoting numbers; they change. What does not change:

- **Aggregate, not per-tunnel.** A gateway's bandwidth is shared across all its tunnels.
- **Zone-redundant SKUs** exist and should be the default in regions that support them.
- **The gateway is often the bottleneck**, not the circuit or the internet link. Teams buy a 1 Gbps
  ExpressRoute circuit and attach a gateway that cannot carry it.

**Latency, not bandwidth, is usually the real constraint.** Before quoting a circuit, measure:

```powershell
Test-NetConnection -ComputerName dc01.corp.contoso.com -Port 389 -InformationLevel Detailed
1..10 | ForEach-Object { (Test-Connection dc01.corp.contoso.com -Count 1).Latency }
```

If domain controller replication or LDAP is slow, adding bandwidth changes nothing.

---

## 6. What breaks

**Tunnel up, no routes.** See §4. Check BGP peer status and learned routes, not connection status.

**IKE/IPsec parameter mismatch.** Both ends must agree on encryption, integrity, DH group and
lifetimes. Symptom: tunnel repeatedly establishes and drops. Compare the two configurations
parameter by parameter — vendor defaults rarely match.

**MTU and fragmentation.** IPsec overhead shrinks the usable payload. Small packets work, large
transfers hang. Same root cause as [`../osi-and-tcp-ip/`](../osi-and-tcp-ip/) §3, and it is why
blocking ICMP makes VPNs mysteriously unreliable.

**Overlapping address space.** The tunnel builds and traffic goes nowhere sensible.

**Active/standby assumed to be active/active.** Failover is slower than expected during an incident.

**Single ExpressRoute connection.** No redundancy, and it looks healthy until the maintenance window.

**Gateway undersized for the circuit.** The circuit is fine; the gateway is the bottleneck.

**Forgetting `useRemoteGateways` on spokes.** Spokes cannot reach on-premises even though the hub
can. See [`../peering-and-hub-spoke/`](../peering-and-hub-spoke/) §3.

---

## 7. Customer discovery questions

1. VPN, ExpressRoute, or both? Is the VPN a **tested** ExpressRoute failover, or just documented?
2. Is the VPN gateway **active/active** or active/standby?
3. Does the ExpressRoute circuit have **both** connections up?
4. Is ExpressRoute traffic **encrypted**? Does policy require it?
5. Is Microsoft 365 routed over ExpressRoute? *(If yes, why — and has it been measured?)*
6. What is the measured **latency** to on-premises DCs, and is anything latency-sensitive crossing it?
7. Do all spokes have `useRemoteGateways` set?
8. When was failover last **tested**, not planned?
9. Is the gateway SKU sized for the circuit bandwidth?

---

## 8. Remember it

**Hook — "Private is not encrypted."**

**Analogy — a private road versus an armoured van.** ExpressRoute gives you a road nobody else
drives on; it does not armour the vehicle. VPN sends you down the public motorway in an armoured
van. Regulated workloads want both: **IPsec over ExpressRoute**.

**The one thing:** `Status: Connected` proves nothing. Check **`RoutesReceived`** — a peered BGP
session advertising zero routes is a tunnel that carries nothing, and it is the classic half-failure.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 9. Self-test

1. Is ExpressRoute encrypted by default?
2. `Status: Connected`, `RoutesReceived: 0`. What is wrong?
3. `circuitProvisioningState: Enabled`, `serviceProviderProvisioningState: NotProvisioned`. Who acts?
4. Difference between private and Microsoft peering?
5. Small pings work, large file transfers hang over VPN. Cause?
6. Why is ExpressRoute often chosen for domain controller traffic?
7. Spokes cannot reach on-premises but the hub can. What is missing?
8. Tunnel establishes then drops repeatedly. First thing to compare?

<details>
<summary>Answers</summary>

1. **No.** It is private — it does not traverse the public internet — but it is not encrypted.
   Use IPsec over ExpressRoute or MACsec where required.
2. BGP is peered but **nothing is being advertised**. Check what on-premises is advertising.
3. **The carrier.** Azure's side is ready; the service provider has not completed provisioning.
4. **Private peering** → your VNets (RFC1918). **Microsoft peering** → Microsoft public services
   such as M365 and PaaS endpoints.
5. **MTU/fragmentation** from IPsec overhead, made worse if ICMP is blocked and Path MTU Discovery
   cannot work.
6. **Consistent latency.** Replication, LDAP and SMB are latency-sensitive; bandwidth is rarely the limit.
7. **`useRemoteGateways`** on the spoke peerings (with `allowGatewayTransit` on the hub).
8. **IKE/IPsec parameters** — encryption, integrity, DH group and lifetimes must match exactly.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — build a site-to-site VPN (a second VNet can simulate on-premises); capture connection
  status, BGP peer status and learned routes.
- **`break-fix/`** — mismatch an IPsec parameter and capture the flapping tunnel; reproduce the
  `Connected` + `RoutesReceived: 0` state by withdrawing advertisements.
- **`security/`** — ExpressRoute encryption posture; learned-routes review for `0.0.0.0/0`;
  point-to-site certificate/authentication model.
- **`operations/`** — measured latency baseline to on-premises DCs; a **tested** failover record
  with a date.
- **`architecture-decisions/`** — ADR: VPN versus ExpressRoute with the latency measurements, plus
  the M365-over-ExpressRoute decision and its rationale.
