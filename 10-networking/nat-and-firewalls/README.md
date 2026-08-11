# NAT and Firewalls

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> Where egress control lives — and egress is the direction that matters for exfiltration.
> Requires [`../azure-vnet/`](../azure-vnet/).

---

## 1. What it is

**NAT** rewrites addresses in transit, so many private addresses share few public ones.
**Firewalls** decide which traffic is permitted. In Azure they are different products, and
conflating them produces designs with gaps.

---

## 2. Why egress is the direction that matters

Security teams instinctively guard inbound. But an attacker who is already inside — via phishing, a
vulnerable dependency, a compromised pipeline — needs **outbound** to be useful: command and
control, and data exfiltration.

Azure's default makes this worse: **outbound internet is allowed by default** on every new VNet
([`../azure-vnet/`](../azure-vnet/) §3). Nothing warns you.

> **"Can this subnet reach `raw.githubusercontent.com`?" is a better security question than "is
> port 22 open?"** — and in most estates the honest answer to the first is yes.

---

## 3. The Azure options, and what each is actually for

| Product | Layer | Purpose |
|---|---|---|
| **NSG** | L3/L4 | Five-tuple filtering at subnet/NIC. Free. **No FQDN, no inspection.** |
| **NAT Gateway** | L3 | ⭐ **Outbound only.** Predictable SNAT, huge port scale. Not a filter. |
| **Azure Firewall** | L3–L7 | FQDN rules, threat intelligence, TLS inspection (Premium), logging |
| **Application Gateway (WAF)** | L7 HTTP | **Inbound** web protection, OWASP rules |
| **Load Balancer** | L4 | Distribution, not security. See [`../load-balancing/`](../load-balancing/) |
| **Third-party NVA** | varies | When existing vendor policy must be reused |

**They compose rather than compete.** A typical secure design uses NSGs for coarse segmentation,
Azure Firewall for inspected egress, WAF for inbound web, and NAT Gateway where only outbound
scale is needed.

---

## 4. SNAT port exhaustion — the failure nobody predicts

The most confusing outage in Azure networking, and it looks like an application bug.

**The mechanism:** outbound connections share a public IP. Each concurrent connection to the *same
destination IP and port* needs a unique source port. Ports are finite (~64,000 per IP), and after a
connection closes the port is held in `TIME_WAIT` before reuse.

```
1,000 VMs  ×  many connections  →  one shared public IP
                                    └── 64,000 ports, held after close
                                         └── exhaustion
```

**Symptoms — note that they are all intermittent, which is why this is misdiagnosed for weeks:**

- Random connection timeouts under load, fine when idle
- Works from one VM, fails from another
- Retrying succeeds
- Application logs show connection failures to a healthy dependency

| Outbound method | SNAT ports | Verdict |
|---|---|---|
| Default outbound access | Small, shared | ⚠ Being retired — do not design on it |
| Load Balancer outbound rules | Manually allocated per VM | Workable, needs sizing |
| **NAT Gateway** | ⭐ **~64,000 per IP, dynamically shared** | **The answer** |

**NAT Gateway is the fix and it is close to free of design effort.** It also gives a **stable,
predictable set of source IPs**, which is what partners need for their allow-lists. Attach it to the
subnet and it takes precedence over default outbound.

⚠ **Default outbound internet access for new VMs is being retired by Microsoft.** Verify the current
date and behaviour before assuming a subnet has any outbound path at all — designs that relied on
the implicit default will break. Explicit NAT Gateway or Load Balancer outbound is the durable
pattern.

---

## 5. Worked example — forcing egress through the firewall

Deploying Azure Firewall changes nothing on its own. **Traffic only reaches it if routing sends it
there**, which means a UDR on every spoke subnet.

```bash
# 1. Route table sending all egress to the firewall's private IP
az network route-table create -g rg-network -n rt-spoke-egress

az network route-table route create -g rg-network --route-table-name rt-spoke-egress \
  -n default-to-firewall --address-prefix 0.0.0.0/0 \
  --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.4.4

# 2. Associate with the workload subnet
az network vnet subnet update -g rg-workload --vnet-name vnet-spoke-a -n snet-app \
  --route-table rt-spoke-egress
```

**Verify it took effect — do not assume:**

```bash
az network nic show-effective-route-table -n app-vm-nic -g rg-workload -o table
```

```
Source   State    Address Prefix   Next Hop Type      Next Hop IP
-------  -------  --------------   ----------------   -----------
Default  Active   10.101.0.0/16    VnetLocal
User     Active   0.0.0.0/0        VirtualAppliance   10.100.4.4      <-- forced to firewall
Default  Invalid  0.0.0.0/0        Internet                           <-- overridden ✅
```

⭐ **`Default … Internet … Invalid` is the proof.** The direct internet route has been overridden.
If it still reads `Active`, egress is bypassing your firewall and every rule you wrote is decorative.

**Then write FQDN rules** — the capability NSGs cannot provide:

```bash
az network firewall application-rule create -g rg-network -f fw-hub \
  --collection-name allow-updates --name allow-ms --priority 200 --action Allow \
  --protocols Http=80 Https=443 \
  --source-addresses 10.101.0.0/16 \
  --target-fqdns "*.windowsupdate.com" "*.microsoft.com"
```

> **FQDN filtering is the reason to run Azure Firewall rather than only NSGs.** "Allow
> `*.windowsupdate.com`, deny everything else" is expressible here and impossible in an NSG, because
> an NSG only knows IP addresses and the update endpoints' IPs change constantly.

---

## 6. Forced tunnelling and asymmetric routing

**Forced tunnelling** sends internet-bound traffic back to on-premises for inspection — usually a
compliance requirement. It works, but it adds latency and makes the on-premises egress a bottleneck
and a single point of failure for cloud workloads.

**Asymmetric routing** is the classic self-inflicted outage:

```
Inbound :  internet → Azure Load Balancer → VM        (direct)
Outbound:  VM → UDR → Firewall → internet             (different path)
                       └── firewall sees a reply to a flow it never saw open → DROP
```

Because firewalls are **stateful**, a reply arriving on a path where no matching outbound state
exists is discarded. Symptom: inbound connections hang and die. The fix is making both directions
traverse the same device — commonly by excluding load-balancer traffic from the UDR, or terminating
inbound at the firewall too.

---

## 7. What breaks

**Firewall deployed, no UDR.** Traffic bypasses it entirely. Verify with effective routes.

**SNAT exhaustion.** Intermittent, load-dependent failures. Attach a NAT Gateway.

**NSG blocking `168.63.129.16`.** Breaks DNS, DHCP and health probes.

**Asymmetric routing.** See §6.

**Firewall subnet misnamed or too small.** `AzureFirewallSubnet`, **/26 minimum** ⚠ verify current
requirement.

**Overly broad FQDN rules.** `*.blob.core.windows.net` allows exfiltration to **any** storage
account in the world, including the attacker's. Scope to your own accounts.

**Forgetting NSG outbound is allow-by-default.** Adding an inbound deny does nothing for egress.

---

## 8. Customer discovery questions

1. Is **all** egress forced through a firewall? Verified by effective routes, or assumed?
2. Is there **FQDN filtering**, or only IP/port rules?
3. Is a **NAT Gateway** attached, or is default outbound still in use? *(§4 retirement.)*
4. Any known intermittent connectivity that could be **SNAT exhaustion**?
5. Are firewall logs going to Sentinel or Log Analytics? Is anyone reading them?
6. Are there any `*.blob.core.windows.net`-style broad allow rules?
7. Is forced tunnelling required, and is the on-prem egress sized for cloud volume?
8. Any asymmetric routing between load-balanced inbound and firewalled outbound?

---

## 9. Remember it

**Hook — "Deployed is not inspected."**

**Analogy — a security guard in a room nobody walks through.** Deploying Azure Firewall changes
nothing on its own. Traffic reaches it only if **routing** sends it there, and until you add the
UDR, every rule you wrote is decorative.

**The one thing:** the proof is in the effective route table — the direct `0.0.0.0/0 → Internet`
route must read **`Invalid`**, overridden by your `VirtualAppliance` route. If it still reads
`Active`, egress is bypassing the firewall.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 10. Self-test

1. Default outbound internet on a new VNet — allowed or denied?
2. Symptoms of SNAT port exhaustion, and why is it usually misdiagnosed?
3. Which route-table entry proves egress is forced through a firewall?
4. Why can an NSG not implement "allow `*.windowsupdate.com`, deny the rest"?
5. Why does asymmetric routing break a stateful firewall?
6. Which is inbound web protection — Azure Firewall or Application Gateway WAF?
7. Why is a broad `*.blob.core.windows.net` allow rule dangerous?
8. Firewall deployed, rules written, traffic still reaches the internet directly. Cause?

<details>
<summary>Answers</summary>

1. **Allowed** (NSG rule 65001). Egress filtering is opt-in.
2. Intermittent timeouts under load, fine when idle, retries succeed. Misdiagnosed because it looks
   like an application or dependency fault, not a network limit.
3. The direct `0.0.0.0/0 → Internet` route showing **`Invalid`**, overridden by a `VirtualAppliance`
   User route.
4. NSGs are **L3/L4** — they match IP addresses and ports, and update endpoint IPs change constantly.
5. The reply arrives with no matching connection state, so the firewall **drops** it.
6. **Application Gateway WAF** for inbound HTTP. Azure Firewall is primarily egress and L3–L7 filtering.
7. It permits exfiltration to **any** storage account, including one the attacker controls.
8. **No UDR** sending `0.0.0.0/0` to the firewall — routing was never changed.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — deploy a firewall, apply the UDR, capture effective routes before and after; write an
  FQDN rule and prove a non-listed domain is blocked.
- **`break-fix/`** — remove the UDR and prove traffic bypasses the firewall; reproduce asymmetric
  routing with a load balancer plus UDR.
- **`security/`** — egress rule review for over-broad FQDNs; confirmation that firewall logs reach
  the SIEM; NAT Gateway attached where needed.
- **`operations/`** — outbound IP register for partner allow-lists; SNAT utilisation monitoring.
- **`architecture-decisions/`** — ADR: Azure Firewall versus NVA; forced tunnelling or not.
