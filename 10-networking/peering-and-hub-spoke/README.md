# VNet Peering and Hub-and-Spoke

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> The reference topology for every Azure landing zone. Requires
> [`../azure-vnet/`](../azure-vnet/) and [`../ipv4-ipv6-subnetting/`](../ipv4-ipv6-subnetting/).

---

## 1. What it is

**Peering** connects two VNets so their resources communicate over the Azure backbone using private
IPs, as if on one network. **Hub-and-spoke** is the topology built from it: one central VNet holding
shared services, with workload VNets peered to it.

---

## 2. Why hub-and-spoke rather than one big VNet

One VNet per environment seems simpler until you need any of these:

| Requirement | Why one VNet fails |
|---|---|
| Separate teams own separate workloads | Everyone shares one RBAC scope and one blast radius |
| Independent lifecycle | Deleting or rebuilding one workload risks the rest |
| Shared firewall, VPN gateway, DNS | Duplicated per environment — expensive and inconsistent |
| Subscription limits | Quotas are per subscription; growth forces a split anyway |

**The economic argument is the strongest:** a VPN gateway, ExpressRoute circuit, Azure Firewall and
Bastion are expensive. Deploying them **once in a hub** and sharing across twenty spokes is the
difference between a viable platform and an unaffordable one.

```
                    ┌───────────── HUB ─────────────┐
                    │  Azure Firewall               │
                    │  VPN / ExpressRoute gateway   │◄──── on-premises
                    │  Bastion                      │
                    │  Private DNS Zones            │
                    └───┬──────────┬──────────┬─────┘
                   peer │          │          │ peer
                    ┌───▼───┐  ┌───▼───┐  ┌───▼───┐
                    │spoke A│  │spoke B│  │spoke C│
                    │ prod  │  │ dev   │  │ data  │
                    └───────┘  └───────┘  └───────┘
                       ✗ ────── no peering ─────── ✗
                       spokes do NOT peer to each other
```

---

## 3. How it works underneath — the three properties that decide everything

**① Peering is NOT transitive.**

```
A ──peer── B ──peer── C          A cannot reach C.
```

This is the most important fact in the topic. Spokes peered to a hub **cannot reach each other**
by default. That is a feature — it is your segmentation — and it is also the source of endless
"why can't spoke A reach spoke B" tickets.

To make spokes communicate you must deliberately choose one:

| Option | Mechanism | Trade-off |
|---|---|---|
| **Route through the hub NVA/Firewall** | UDR in each spoke sending spoke-to-spoke via the firewall | ⭐ Inspected and logged. The right answer for regulated estates. |
| **Direct spoke-to-spoke peering** | Peer them to each other | Fast and cheap; **bypasses the firewall**, and becomes a mesh at scale |
| **Azure Virtual WAN** | Managed transit | Microsoft manages routing; less control |

**② Peering is bidirectional but configured as two objects.** Each side has its own peering
resource with its own flags. **If only one side is created, the state stays `Disconnected`** —
a frequent and confusing half-configuration.

**③ Address spaces must not overlap.** Peering is refused outright. There is no NAT option in
peering. See [`../ipv4-ipv6-subnetting/`](../ipv4-ipv6-subnetting/) §2.

### The four flags that matter

| Flag | Meaning |
|---|---|
| `allowVirtualNetworkAccess` | Permit traffic at all. Normally `true`. |
| `allowForwardedTraffic` | ⭐ Accept traffic that **originated elsewhere** and was forwarded. Required on the **hub** side for spoke-to-spoke via firewall. |
| `allowGatewayTransit` | Set on the **hub** — "you may use my gateway" |
| `useRemoteGateways` | Set on the **spoke** — "I will use the hub's gateway" |

> **Gateway transit is the pair people invert.** `allowGatewayTransit` on the hub,
> `useRemoteGateways` on the spoke. Reverse them and the spoke cannot reach on-premises, with an
> error that does not point at the cause. A spoke cannot have its own gateway *and* use the hub's.

---

## 4. Worked example — diagnosing a broken peering

```bash
az network vnet peering list -g rg-network --vnet-name vnet-hub -o table
```

```
Name              PeeringState  AllowForwardedTraffic  AllowGatewayTransit  UseRemoteGateways
----------------  ------------  ---------------------  -------------------  -----------------
hub-to-spoke-a    Connected     True                   True                 False
hub-to-spoke-b    Connected     True                   True                 False
hub-to-spoke-c    Disconnected  True                   True                 False    <-- broken
```

`Disconnected` means **the other side was deleted or never created**. Check the spoke:

```bash
az network vnet peering list -g rg-workload --vnet-name vnet-spoke-c -o table
```

Empty output confirms it. Recreate the return peering:

```bash
az network vnet peering create \
  --name spoke-c-to-hub --resource-group rg-workload --vnet-name vnet-spoke-c \
  --remote-vnet /subscriptions/<sub>/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-hub \
  --allow-vnet-access --use-remote-gateways
```

**Then verify the route actually exists on a NIC** — peering being `Connected` is not proof that
traffic flows:

```bash
az network nic show-effective-route-table -n spoke-c-vm-nic -g rg-workload -o table
```

```
Source           State    Address Prefix   Next Hop Type          Next Hop IP
---------------  -------  --------------   --------------------   -----------
Default          Active   10.101.0.0/16    VnetLocal
VNetPeering      Active   10.100.0.0/16    VNetPeering                          <-- hub reachable
VirtualNetworkGatewayActive 192.168.0.0/16 VirtualNetworkGateway               <-- on-prem via hub
User             Active   0.0.0.0/0        VirtualAppliance       10.100.4.4   <-- egress to firewall
```

**Read it as a checklist:** a `VNetPeering` route proves peering works; a
`VirtualNetworkGateway` route proves gateway transit works; the `VirtualAppliance` route proves
egress is forced through the firewall. Three facts from one command.

---

## 5. Spoke-to-spoke through the firewall — the config people get wrong

To make spoke A reach spoke B via the hub firewall, **three things** must all be true:

```
1. UDR in spoke A:  10.101.0.0/16 (spoke B) → next hop 10.100.4.4 (firewall)
2. UDR in spoke B:  10.102.0.0/16 (spoke A) → next hop 10.100.4.4
3. allowForwardedTraffic = TRUE on BOTH hub peerings
```

**Step 3 is the one that gets missed.** Without it the hub drops traffic that did not originate in
the hub, and the symptom is a one-way or completely silent failure. The UDRs look perfect, the
firewall shows no denies, and nothing works — because the packets never arrive.

⚠ Also ensure the firewall itself has a rule permitting the flow. "Allowed by routing, denied by
policy" and "denied by routing" look identical from the client.

---

## 6. What breaks

**Expecting transitivity.** Spokes cannot reach each other by default. By design.

**One-sided peering.** `Disconnected` state. Both objects must exist.

**Overlapping address space.** Peering refused. No workaround but renumbering.

**Gateway transit flags inverted.** Spoke cannot reach on-premises.

**`allowForwardedTraffic` false on the hub.** Spoke-to-spoke through the firewall silently fails.

**Peering across regions costs money in both directions.** Global peering charges ingress *and*
egress. High-volume cross-region chatter produces surprising bills — a design problem, not a
billing problem.

**Mesh sprawl.** Direct spoke-to-spoke peering "just for now" accumulates. Twenty spokes fully
meshed is 190 peerings, none inspected by the firewall. Decide the pattern once and enforce it with
Policy.

---

## 7. Customer discovery questions

1. Is the topology hub-and-spoke, mesh, or accidental?
2. How is **spoke-to-spoke** handled — via firewall, direct peering, or not allowed?
3. Is `allowForwardedTraffic` set correctly on hub peerings?
4. Any peerings in `Disconnected` state right now?
5. Do spokes use **gateway transit**, or does anyone have their own gateway?
6. Any **global** (cross-region) peerings, and is the traffic volume understood?
7. Is there Azure Policy preventing ad-hoc spoke-to-spoke peering?
8. Does the address plan reserve ranges for future spokes?

---

## 8. Remember it

**Hook — "Hub allows, spoke uses"** (`allowGatewayTransit` on the hub, `useRemoteGateways` on the
spoke), and **"peering is a handshake, not a highway."**

**Analogy — handshakes.** A shakes B's hand; B shakes C's. A and C have never met. Peering is **not
transitive**, and that is your segmentation rather than a defect.

**The one thing:** spoke-to-spoke through the hub firewall needs **three** things — UDRs in both
spokes, `allowForwardedTraffic` on **both** hub peerings, and a firewall rule. The forwarded-traffic
flag is the one that gets missed, and it fails silently.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 9. Self-test

1. A peered to B, B peered to C. Can A reach C?
2. Three requirements for spoke-to-spoke through a hub firewall?
3. `PeeringState: Disconnected` — what does it mean?
4. Which side gets `allowGatewayTransit`, which gets `useRemoteGateways`?
5. Two VNets both use `10.0.0.0/16`. Can you peer them?
6. One command proving peering, gateway transit and forced egress all work?
7. Why is direct spoke-to-spoke peering discouraged despite being simpler?
8. UDRs are correct, firewall shows no denies, traffic still fails. What did you forget?

<details>
<summary>Answers</summary>

1. **No.** Peering is **not transitive**.
2. UDRs in **both** spokes pointing at the firewall, `allowForwardedTraffic = true` on **both** hub
   peerings, and a firewall rule permitting the flow.
3. The peering object on the **other side** is missing or was deleted. Both must exist.
4. **Hub** gets `allowGatewayTransit`; **spoke** gets `useRemoteGateways`.
5. **No.** Overlapping address space; peering is refused and there is no NAT option.
6. `az network nic show-effective-route-table` — shows `VNetPeering`,
   `VirtualNetworkGateway` and `VirtualAppliance` routes together.
7. It **bypasses the hub firewall** (no inspection or logging) and becomes an unmanageable mesh at scale.
8. **`allowForwardedTraffic` on the hub peerings.** The packets never reach the firewall.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — build a hub and two spokes; prove spokes cannot reach each other; then enable
  spoke-to-spoke through the firewall and capture the effective route table at each stage.
- **`break-fix/`** — delete one side of a peering and capture `Disconnected`; set
  `allowForwardedTraffic` to false and diagnose the silent failure.
- **`security/`** — proof that spoke-to-spoke is inspected; inventory of any direct peerings that
  bypass the firewall.
- **`operations/`** — peering inventory with state and flags, re-run and diffed.
- **`architecture-decisions/`** — ADR: hub-and-spoke versus Virtual WAN; spoke-to-spoke policy.
