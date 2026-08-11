# IPv4, IPv6 and Subnetting

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The one topic here you must be able to do on a whiteboard without a calculator.** Address
> plans are near-impossible to change once workloads are running, so mistakes here are permanent.

---

## 1. What it is

An IPv4 address is **32 bits**. A subnet mask says how many leading bits identify the **network**;
the rest identify the **host**. `/24` means 24 network bits, 8 host bits.

That is the whole concept. Everything else is arithmetic.

---

## 2. Why it matters more in cloud than on-premises

On-premises you can renumber a VLAN over a weekend. In Azure:

- **A VNet address space cannot overlap with anything you will ever peer to.** Peering with
  overlapping ranges is refused outright.
- **Resizing a subnet with resources in it is restricted**, and some resources cannot move.
- A merger brings *their* `10.0.0.0/16`, and if you also used `10.0.0.0/16`, you now need NAT
  between your own business units — permanently.

> **The most expensive networking mistake is `10.0.0.0/16` chosen on day one by someone who
> assumed the estate would stay small.** Everyone picks it. That is exactly why it collides.

---

## 3. How it works underneath

```
10.0.1.0/26

10.0.1.0        = 00001010.00000000.00000001.00000000
mask /26        = 11111111.11111111.11111111.11000000
                                             └┬┘└──┬──┘
                                    network bits   6 host bits → 2^6 = 64 addresses
```

**The table to memorise.** Learn the last-octet column; everything else follows.

| CIDR | Mask | Addresses | Azure usable | Block size |
|---|---|---:|---:|---:|
| /24 | 255.255.255.0 | 256 | **251** | 256 |
| /25 | 255.255.255.128 | 128 | 123 | 128 |
| /26 | 255.255.255.192 | 64 | **59** | 64 |
| /27 | 255.255.255.224 | 32 | 27 | 32 |
| /28 | 255.255.255.240 | 16 | 11 | 16 |
| /29 | 255.255.255.248 | 8 | **3** | 8 |
| /30 | 255.255.255.252 | 4 | 0 | 4 |

**Fast mental method:** `256 − mask octet = block size`. Subnets start at multiples of the block
size. For /26, block = 64, so networks are `.0`, `.64`, `.128`, `.192`. No binary needed.

### ⭐ Azure reserves five addresses per subnet, not two

On-premises you lose 2 (network, broadcast). **Azure takes 5:**

| Address | Use |
|---|---|
| `.0` | Network address |
| `.1` | **Default gateway** |
| `.2`, `.3` | **Azure DNS mapping** |
| last | Broadcast |

This is why the smallest usable Azure subnet is **/29 — with just 3 usable addresses.** Anyone
sizing a /29 for four VMs has already failed, and the error surfaces at deployment time.

---

## 4. Worked example — real computed output

✅ Verified — this is actual output, not illustration:

```
CIDR        Network  Broadcast    Mask               Total  AzureUsable
----        -------  ---------    ----               -----  -----------
10.0.0.0/24 10.0.0.0 10.0.0.255   255.255.255.0        256          251
10.0.1.0/26 10.0.1.0 10.0.1.63    255.255.255.192       64           59
10.0.2.0/29 10.0.2.0 10.0.2.7     255.255.255.248        8            3
10.1.0.0/16 10.1.0.0 10.1.255.255 255.255.0.0        65536        65531
```

Reproduce it — this function is worth keeping in your profile:

```powershell
function Show-Subnet($cidr){
  $ip,$p = $cidr -split '/'; $p=[int]$p
  $b=[uint32]0; ($ip -split '\.') | ForEach-Object { $b=($b -shl 8) -bor [uint32]$_ }
  $mask = if($p -eq 0){[uint32]0}else{[uint32]::MaxValue -shl (32-$p)}
  $net=$b -band $mask; $bcast=$net -bor (-bnot $mask)
  $f={param($x)(($x -shr 24) -band 255),(($x -shr 16) -band 255),(($x -shr 8) -band 255),($x -band 255) -join '.'}
  [pscustomobject]@{CIDR=$cidr;Network=(&$f $net);Broadcast=(&$f $bcast);AzureUsable=[math]::Pow(2,32-$p)-5}
}
'10.0.0.0/24','10.0.1.0/26','10.0.2.0/29' | ForEach-Object { Show-Subnet $_ }
```

**Check whether an address is in a range** — the question peering and NSG rules turn on:

```powershell
# Is 10.0.1.75 inside 10.0.1.0/26?  Block size 64 → range is .0-.63 → NO, it is in 10.0.1.64/26
```

---

## 5. RFC 1918 — the private ranges, and how to choose

| Range | CIDR | Size |
|---|---|---:|
| `10.0.0.0` – `10.255.255.255` | **10.0.0.0/8** | 16.7M |
| `172.16.0.0` – `172.31.255.255` | **172.16.0.0/12** | 1M |
| `192.168.0.0` – `192.168.255.255` | **192.168.0.0/16** | 65K |

**Practical guidance that will save you a merger:**

- **Do not start at `10.0.0.0/16`.** Everyone does; collisions in M&A are near-certain.
- Pick a **deliberately unusual** block — `10.183.0.0/16` — and write down why.
- **Allocate per region and environment**, leaving gaps:

```
10.100.0.0/16   prod    - UK South
10.101.0.0/16   prod    - North Europe
10.110.0.0/16   non-prod- UK South
10.120.0.0/16   reserved for acquisitions   ← the line that pays for itself
```

⚠ `169.254.0.0/16` is **link-local**, and `169.254.169.254` is the **cloud instance metadata
endpoint** — the target of SSRF attacks against cloud workloads. Never route it; it should never
appear in an address plan. That connects directly to
[`../../30-identity-and-nhi/managed-identities/`](../../30-identity-and-nhi/managed-identities/):
managed-identity tokens are fetched from that address, which is why SSRF there is so serious.

---

## 6. IPv6 — the parts that actually matter

128 bits, written as eight hex groups. Compression rules:

```
2001:0db8:0000:0000:0000:ff00:0042:8329
2001:db8:0:0:0:ff00:42:8329        drop leading zeros in each group
2001:db8::ff00:42:8329             :: replaces ONE run of zero groups
```

> **`::` may appear only once** — otherwise the length is ambiguous.

| Prefix | Meaning |
|---|---|
| `2000::/3` | Global unicast (routable) |
| `fe80::/10` | **Link-local** — always present on every interface |
| `fc00::/7` | Unique local (the RFC 1918 analogue) |
| `ff00::/8` | Multicast. **IPv6 has no broadcast at all.** |

**`/64` is the standard subnet size** and you should not deviate. It looks wasteful — 18 quintillion
addresses per subnet — but SLAAC depends on it.

**The security point that matters most:** IPv6 is often **enabled and unmanaged**. Hosts get
link-local addresses automatically, and a firewall policy written only for IPv4 leaves an
unfiltered path. Rogue Router Advertisements are a real attack (`mitm6`) that pairs with NTLM relay
to compromise AD. **Disabling IPv6 on Windows is not recommended by Microsoft** — filter it instead,
and enable RA Guard on switches.

---

## 7. What breaks

**Overlapping ranges block peering.** Azure refuses the peering outright. There is no fix except
renumbering one side.

**Subnet too small, discovered at deployment.** Remember the **5 reserved addresses**.

**Forgetting service-delegated subnets.** Azure Firewall requires `AzureFirewallSubnet` at **/26
minimum**; the Bastion and Gateway subnets have their own name and size rules. Reserve them in the
plan, not when the deployment fails.

**Assuming `/24` everywhere.** Wasteful in a hub-and-spoke with many small subnets, and it exhausts
the parent range faster than expected.

**IPv4-only NSG rules on a dual-stack VNet.** The IPv6 path is unfiltered.

---

## 8. Customer discovery questions

1. What is the **enterprise address plan**, and is it written down anywhere authoritative?
2. Which ranges are already used **on-premises**? *(Cloud must not collide with them.)*
3. Is there a reserved block for **acquisitions**?
4. Any overlapping ranges today? How are they worked around — NAT?
5. Is IPv6 enabled anywhere, and do NSG/firewall rules cover it?
6. Who **allocates** ranges, and how does a team request one?
7. Have the required Azure service subnets (`AzureFirewallSubnet`, `GatewaySubnet`,
   `AzureBastionSubnet`) been reserved with correct sizes?

---

## 9. Remember it

**Hook — "Gateway, DNS, DNS, and both ends."** That is Azure's five reserved addresses:
`.0`, `.1` (gateway), `.2` and `.3` (DNS), and the broadcast.

**Analogy — block sizes, not binary.** `256 − mask octet = block size`. Subnets start at multiples
of it. For a /26 the block is 64, so networks are `.0`, `.64`, `.128`, `.192`. No binary required,
and it works on a whiteboard under pressure.

**The one thing:** Azure takes **5**, not 2 — so the smallest usable subnet (/29) yields **3**
addresses. And never start an estate at `10.0.0.0/16`; everyone does, which is exactly why it
collides in a merger.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 10. Self-test

1. How many **usable** addresses in an Azure `/26`? Why not 62?
2. Is `10.0.1.75` inside `10.0.1.0/26`?
3. Smallest usable Azure subnet, and how many usable addresses?
4. Why is `10.0.0.0/16` a poor default?
5. What is `169.254.169.254`, and why does it matter for identity security?
6. Compress `2001:0db8:0000:0000:0000:ff00:0042:8329`. Why only one `::`?
7. Standard IPv6 subnet size, and why not smaller?
8. Two companies merge, both using `10.0.0.0/16`. Options?

<details>
<summary>Answers</summary>

1. **59.** Azure reserves **five**: network, gateway (`.1`), two for DNS (`.2`, `.3`), broadcast.
2. **No.** Block size 64 → `10.0.1.0/26` covers `.0`–`.63`. `.75` is in `10.0.1.64/26`.
3. **/29**, with **3** usable.
4. Everyone chooses it, so it collides in any merger or partner connection.
5. The **instance metadata endpoint** — where managed-identity tokens are fetched. An SSRF that
   reaches it can steal a workload's token.
6. `2001:db8::ff00:42:8329`. Two `::` would make the number of omitted zero groups ambiguous.
7. **/64** — SLAAC assumes it.
8. Renumber one side (correct, painful), or NAT between them (fast, permanent complexity). There
   is no third option, which is why the reserved-block line in §5 matters.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — build a real address plan for a three-region, two-environment estate with an
  acquisition reserve; verify each subnet with the §4 function.
- **`break-fix/`** — attempt a peering with overlapping ranges and capture the exact refusal;
  deploy into a /29 and hit the reserved-address limit.
- **`security/`** — dual-stack NSG coverage check; confirmation that `169.254.169.254` is not
  routable from user subnets.
- **`operations/`** — the IP allocation register and the request process.
- **`architecture-decisions/`** — ADR: the address plan, with the acquisition reserve justified.
