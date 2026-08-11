# Azure Virtual Network

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> The Azure networking foundation. Requires [`../ipv4-ipv6-subnetting/`](../ipv4-ipv6-subnetting/).

---

## 1. What it is

A **software-defined private network** inside an Azure region. It gives you an address space,
subnets, routing and filtering — but it is not a virtual switch, and reasoning about it as one
produces wrong answers.

**A VNet is regional.** It does not span regions; connecting regions means peering.

---

## 2. Why the abstraction differs from on-premises

There is no broadcast domain. No spanning tree. No VLANs. Azure intercepts and answers ARP itself,
and there is a **system route table** you did not create.

Two consequences that surprise every network engineer:

1. **All subnets in a VNet can reach each other by default.** There is no inter-VLAN routing to
   configure — and no implicit isolation either. Segmentation is something you must *add* with NSGs.
2. **Broadcast and multicast do not work.** Clustering products and discovery protocols that depend
   on them fail. This is a real migration blocker for older applications and it is rarely discovered
   until testing.

---

## 3. How it works underneath

```
VNet  10.100.0.0/16          (regional)
 ├── subnet  web       10.100.1.0/24   ── NSG ── route table
 ├── subnet  app       10.100.2.0/24   ── NSG
 ├── subnet  data      10.100.3.0/24   ── NSG ── service endpoint / private endpoint
 └── subnet  GatewaySubnet 10.100.255.0/27    ← reserved name, NSG rules restricted
```

**System routes exist before you create anything:**

| Destination | Next hop | Meaning |
|---|---|---|
| VNet address space | Virtual network | Intra-VNet traffic |
| `0.0.0.0/0` | **Internet** | ⭐ **Default egress is open** |
| `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` | **None** (dropped) | Prevents accidental RFC1918 leakage |
| Peered ranges | VNet peering | Added when peering is created |

> ⭐ **A new VNet has unrestricted outbound internet access.** Nothing warns you. This is the
> default that matters most for security, and forcing egress through a firewall is a deliberate
> act — see [`../nat-and-firewalls/`](../nat-and-firewalls/).

### Reserved subnet names and sizes

Some subnets must be named exactly and sized minimally. Get these into the address plan early:

| Name | Minimum | For |
|---|---|---|
| `GatewaySubnet` | /27 recommended | VPN / ExpressRoute gateway |
| `AzureFirewallSubnet` | **/26** | Azure Firewall |
| `AzureBastionSubnet` | **/26** | Bastion |
| `RouteServerSubnet` | /27 | Route Server |

⚠ Minimums change; verify against current docs before finalising a plan. What does not change is
that **you cannot rename or resize these later without redeploying the service.**

---

## 4. NSGs — the filtering model, and the rule people misread

An NSG is a stateful five-tuple filter applied to a **subnet** or a **NIC**, with separate inbound
and outbound rule sets processed by **priority, lowest number first, first match wins**.

**The default rules, which are always present:**

| Priority | Direction | Rule |
|---:|---|---|
| 65000 | In | Allow VNet → VNet |
| 65001 | In | Allow Azure Load Balancer |
| **65500** | In | **Deny All** |
| 65000 | Out | Allow VNet → VNet |
| 65001 | Out | **Allow Internet** |
| 65500 | Out | Deny All |

> **Inbound is deny-by-default. Outbound is allow-by-default.** That asymmetry is where data
> exfiltration paths come from, and it is the first thing to check in a security review.

**Stateful means return traffic is automatic.** You do not write a reverse rule. Engineers from a
stateless-ACL background write them anyway and then cannot explain the behaviour.

**When an NSG is on both the subnet and the NIC:**

```
Inbound :  subnet NSG evaluated FIRST, then NIC NSG    (both must allow)
Outbound:  NIC NSG evaluated FIRST, then subnet NSG    (both must allow)
```

Both must permit the traffic. This double-layering is a very common cause of "the rule is there but
it still fails."

**Service Tags** replace IP lists and are maintained by Microsoft — `Storage`, `Sql`,
`AzureActiveDirectory`, `AzureMonitor`, `Internet`, `VirtualNetwork`. Use them; hand-maintained
Azure IP ranges go stale and break.

---

## 5. Worked example — why is this traffic blocked?

Do not read rules and reason about them. **Ask Azure what it decided.**

```bash
az network nic list-effective-nsg --name myVmNic --resource-group rg-prod -o table
```

```powershell
Get-AzEffectiveNetworkSecurityGroup -NetworkInterfaceName myVmNic -ResourceGroupName rg-prod |
  Select-Object -ExpandProperty EffectiveSecurityRules |
  Where-Object { $_.DestinationPortRange -contains '443' -or $_.DestinationPortRange -contains '*' } |
  Select-Object Name, Priority, Direction, Access, Protocol, DestinationPortRange
```

```
Name                            Priority Direction Access Protocol DestinationPortRange
----                            -------- --------- ------ -------- --------------------
AllowHttpsInbound                    100 Inbound   Allow  TCP      443
DenyAllInBound                     65500 Inbound   Deny   *        0-65535
AllowInternetOutBound              65001 Outbound  Allow  *        0-65535
```

**Effective rules merge subnet and NIC NSGs and show the real evaluation order** — including the
defaults you did not write. This one command settles most NSG arguments.

**Confirm the actual route** — the other half of "why can't it connect":

```bash
az network nic show-effective-route-table --name myVmNic --resource-group rg-prod -o table
```

```
Source    State    Address Prefix    Next Hop Type   Next Hop IP
--------  -------  ---------------   -------------   -----------
Default   Active   10.100.0.0/16     VnetLocal
Default   Active   0.0.0.0/0         Internet
User      Active   0.0.0.0/0         VirtualAppliance 10.100.4.4     <-- forced tunnel to a firewall
Default   Invalid  0.0.0.0/0         Internet                        <-- overridden by the UDR
```

⭐ **`State: Invalid` means that route was overridden.** Reading this table tells you whether egress
actually goes through the firewall you think it does.

---

## 6. Service endpoints versus private endpoints

Constantly confused, and the difference is a security control:

| | Service Endpoint | **Private Endpoint** |
|---|---|---|
| What it does | Routes to the service over the Azure backbone, and lets the service filter by VNet | ⭐ Puts a **private IP from your subnet** on the service |
| Resource still has a public IP | **Yes** | Can be disabled entirely |
| Reachable from on-premises | ✗ | **✅ via VPN/ER** |
| DNS change needed | No | **Yes — mandatory.** See [`../private-endpoints/`](../private-endpoints/) |
| Cost | Free | Per endpoint per hour |

**Private endpoints are the modern default for data services.** Service endpoints leave the public
endpoint live, so they reduce exposure rather than removing it.

---

## 7. What breaks

**Assuming default deny outbound.** It is allow. Egress filtering is opt-in.

**Overlapping address space.** Peering is refused. See [`../ipv4-ipv6-subnetting/`](../ipv4-ipv6-subnetting/).

**Subnet too small.** Five reserved addresses; resizing with resources deployed is restricted.

**NSG on subnet *and* NIC.** Both must allow. Use effective rules.

**Blocking `168.63.129.16`.** Breaks DNS, DHCP and load-balancer health probes.

**Expecting broadcast/multicast.** They do not exist. Legacy clustering fails.

**NSGs on `GatewaySubnet`.** Restricted and easy to break — misconfiguration takes down the VPN.

---

## 8. Customer discovery questions

1. Is outbound internet from every subnet **filtered**, or is the default still in place?
2. Are NSGs applied at subnet, NIC, or both? Does anyone use **effective rules** when debugging?
3. Are **Service Tags** used, or hand-maintained IP lists?
4. Service endpoints or private endpoints for data services? Are public endpoints disabled?
5. Is there a **UDR forcing egress** through a firewall, and is it `Active` on every NIC?
6. Were the reserved subnets sized correctly at build time?
7. Any application depending on broadcast or multicast?
8. Are NSG flow logs enabled and going anywhere useful?

---

## 9. Remember it

**Hook — "In is deny, out is allow."** NSG rule 65500 denies inbound; rule 65001 **allows all
outbound**.

**Analogy — an office with guarded doors and unlocked fire exits.** Everyone focuses on who gets in.
The attacker is already inside and only needs a way out — for command and control, and for the data.

**The one thing:** a new VNet has **unrestricted outbound internet access** and nothing warns you.
Egress filtering is opt-in, and "can this subnet reach `raw.githubusercontent.com`?" is a better
security question than "is port 22 open?"

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 10. Self-test

1. Default outbound internet access on a new VNet — allowed or denied?
2. NSGs on both subnet and NIC — which is evaluated first inbound, and must both allow?
3. `State: Invalid` in the effective route table — what does it mean?
4. Do you need a return rule for established connections?
5. Service endpoint versus private endpoint — which leaves a public IP live?
6. Why does legacy clustering software often fail in a VNet?
7. Command that ends most "the rule is there but it's blocked" arguments?
8. Why must reserved subnet sizes be planned up front?

<details>
<summary>Answers</summary>

1. **Allowed** — rule 65001 `AllowInternetOutBound`. Restricting it is a deliberate act.
2. **Subnet first** inbound (NIC first outbound). **Both must allow.**
3. That route was **overridden** by a higher-precedence route, typically a UDR.
4. **No.** NSGs are **stateful**; return traffic is automatic.
5. **Service endpoint** — the resource keeps its public IP. Private endpoints let you disable it.
6. **No broadcast or multicast** in a VNet.
7. `az network nic list-effective-nsg` / `Get-AzEffectiveNetworkSecurityGroup` — merged, ordered,
   including defaults.
8. They cannot be renamed or resized later without redeploying the service that uses them.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — build a VNet with three subnets; capture effective NSG rules and the effective route
  table before and after adding a UDR.
- **`break-fix/`** — apply conflicting NSGs at subnet and NIC and diagnose using **only** effective
  rules; block `168.63.129.16` and observe what fails.
- **`security/`** — egress filtering proof; public endpoints disabled on data services; NSG flow
  logs enabled.
- **`operations/`** — subnet register including reserved subnets and their sizes.
- **`architecture-decisions/`** — ADR: service endpoints versus private endpoints for data services.
