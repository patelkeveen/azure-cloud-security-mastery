# Private Endpoints

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The single highest-value Azure networking topic for a security engineer**, and the one that
> fails most often — always for the same reason. Hard prerequisite: [`../dns/`](../dns/).

---

## 1. What it is

A **network interface with a private IP from your own subnet**, connected to a specific instance of
a PaaS service — a storage account, a Key Vault, a SQL database — over **Azure Private Link**.

The service stops being something you reach across the internet and becomes something with an
address inside your network.

---

## 2. Why it exists

PaaS services are born with public endpoints. `myaccount.blob.core.windows.net` resolves publicly
and is reachable from anywhere on the internet. Access control is by key, SAS token or Entra
identity — not by network.

That is a genuine problem:

- A leaked storage key is exploitable **from anywhere on earth**
- A compromised workload can exfiltrate to *its own* storage account, which firewall rules permitting
  "Storage" happily allow
- Auditors and regulators ask "is this reachable from the internet?" and the honest answer is yes

Private endpoints make the answer **no**. Combined with `publicNetworkAccess: Disabled`, the data
plane becomes unreachable except from your networks — a leaked key stops being sufficient.

---

## 3. How it works underneath

```
   Your subnet 10.100.3.0/24
        │
        ├── privateEndpoint NIC   10.100.3.4  ──── Private Link ────► storage account "myaccount"
        │                                                             (ONE specific instance)
        └── VM 10.100.3.10
                │  asks DNS for  myaccount.blob.core.windows.net
                ▼
        Azure DNS (168.63.129.16)
                │  checks Private DNS Zone linked to this VNet
                │  privatelink.blob.core.windows.net → 10.100.3.4
                ▼
        connects to 10.100.3.4  — never leaves the VNet
```

**Two things are created and they are independent:**

1. The **network path** — a NIC in your subnet mapped to one service instance
2. The **name resolution** — a Private DNS Zone that must return the private IP

> ⭐ **Creating the endpoint does not redirect anything by itself.** Clients use the public
> hostname. Until DNS returns the private IP, every client keeps going out the public path — and
> **everything appears to work**, which is exactly why this failure is so persistent.

### The CNAME chain — the mechanism worth understanding

When a private endpoint exists, Azure changes the *public* DNS answer to a CNAME:

```
myaccount.blob.core.windows.net
     └── CNAME → myaccount.privatelink.blob.core.windows.net
                      ├── from INSIDE  (private zone linked) → 10.100.3.4      ✅
                      └── from OUTSIDE (public DNS)          → 20.x.x.x        public IP
```

The application never changes its connection string. The **same hostname** resolves differently by
location. This is deliberate split-brain — see [`../dns/`](../dns/) §5 — and it is why the private
zone must be named **exactly** `privatelink.blob.core.windows.net`. A typo produces a zone that
resolves nothing and traffic silently continues out the public path.

**Sub-resources matter.** One private endpoint targets one sub-resource: `blob`, `file`, `table`,
`queue`, `dfs` for storage; `vault` for Key Vault; `sqlServer` for SQL. **Creating a `blob` endpoint
does not cover `file`.** Each needs its own endpoint and its own zone.

---

## 4. Worked example — the failure, then the fix

**Symptom:** private endpoint created, `publicNetworkAccess` still enabled, and the VM connects
fine — so nobody notices anything is wrong. Then public access is disabled and everything breaks.

**Diagnose from the VM:**

```powershell
Resolve-DnsName myaccount.blob.core.windows.net
```

**Broken — resolving publicly:**

```
Name                                        Type   TTL   Section  IPAddress
----                                        ----   ---   -------  ---------
myaccount.blob.core.windows.net             CNAME  60    Answer
myaccount.privatelink.blob.core.windows.net A      10    Answer   20.60.181.4     <-- PUBLIC
```

**Working — resolving privately:**

```
myaccount.blob.core.windows.net             CNAME  60    Answer
myaccount.privatelink.blob.core.windows.net A      10    Answer   10.100.3.4      <-- PRIVATE
```

**One line tells you which you have.** The CNAME to `privatelink.*` is present in both — that is
the trap. **The address is the test, not the CNAME.**

**Find the cause:**

```bash
# Does the zone exist, and is it linked to THIS VNet?
az network private-dns zone list -o table
az network private-dns link vnet list -g rg-network -z privatelink.blob.core.windows.net -o table
```

```
Name              VirtualNetwork      RegistrationEnabled  ProvisioningState
----------------  ------------------  -------------------  -----------------
link-vnet-prod    vnet-prod           False                Succeeded
```

If your VNet is not in that list, that is the bug. **Missing VNet link is the cause the large
majority of the time.**

```bash
# What IP did the endpoint actually get?
az network private-endpoint show -n pe-storage -g rg-prod \
  --query "customDnsConfigs[].{fqdn:fqdn, ip:ipAddresses[0]}" -o table

# Is the connection approved?
az network private-endpoint-connection list --id <resource-id> -o table
```

**Then close the door** — the step that makes any of this a security control:

```bash
az storage account update -n myaccount -g rg-prod --public-network-access Disabled
```

> **A private endpoint without disabling public network access is not a security control.** It is a
> routing preference. This is the finding to look for in any tenant review: endpoints deployed,
> public access still enabled, everyone believing the service is private.

---

## 5. On-premises access — where designs go wrong

Private endpoints **are** reachable from on-premises over VPN or ExpressRoute — that is a major
advantage over service endpoints. But **on-premises DNS servers do not know about Azure Private DNS
Zones.**

```
On-prem client asks its own DNS for myaccount.blob.core.windows.net
      └── on-prem DNS has no idea about privatelink zones
           └── forwards to the internet → returns the PUBLIC IP → connection fails
```

The fix is a **conditional forwarder** on the on-premises DNS server for
`privatelink.blob.core.windows.net`, pointing at an **Azure DNS Private Resolver** inbound endpoint
(or legacy forwarder VMs). See [`../dns/`](../dns/) §6.

**Design rule:** centralise Private DNS Zones in the **hub**, link them to every spoke VNet, and
point on-premises at the resolver. Per-spoke zones produce inconsistent resolution that is very hard
to debug — the answer depends on which VNet the client happens to be in.

---

## 6. What breaks

| Symptom | Cause |
|---|---|
| Resolves to a public IP inside the VNet | ⭐ **Private DNS Zone not linked to the VNet** |
| Works from Azure, fails from on-premises | No conditional forwarder on on-prem DNS |
| `blob` works, `file` fails | Separate sub-resource needs its **own** endpoint and zone |
| Zone exists, still public | Zone name misspelled — must match `privatelink.*` exactly |
| Intermittent, depends on the client | Multiple zones or a stale cache; also check the HOSTS file |
| Endpoint shows `Pending` | Connection **not approved** (cross-subscription/tenant needs manual approval) |
| Everything works, auditor still fails you | `publicNetworkAccess` was never disabled |

**NSGs on private endpoint subnets** historically behaved specially. ⚠ Verify current behaviour
before relying on an NSG to filter private endpoint traffic — this is an area that has changed.

---

## 7. Customer discovery questions

1. Which PaaS services have private endpoints, and is `publicNetworkAccess` **Disabled** on each?
   *(The gap between these two lists is your finding.)*
2. Where do Private DNS Zones live — hub, or scattered across spokes?
3. Is **every** VNet that needs a zone actually linked to it?
4. How do on-premises clients resolve `privatelink` names?
5. Are **all** required sub-resources covered — blob *and* file *and* dfs?
6. Any private endpoint connections stuck in `Pending`?
7. Who approves cross-subscription private endpoint connections?
8. Is there a Policy enforcing private endpoints and denying public access on new resources?

---

## 8. Remember it

**Hook — "The CNAME lies, the IP tells the truth."** The `privatelink` CNAME appears whether it is
working or not. Only the resolved address distinguishes them.

**Analogy — a private phone line plus the phone book.** Installing the line changes nothing until
you update the **phone book** (the Private DNS Zone). Everyone keeps dialling the public number —
and it still connects, so nobody notices anything is wrong.

**The one thing:** a private endpoint is only a security control once the zone is **linked to the
VNet** *and* `publicNetworkAccess` is **Disabled**. Without both, it is a routing preference.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 9. Self-test

1. What are the two independent things a private endpoint deployment creates?
2. `Resolve-DnsName` shows the `privatelink` CNAME. Does that prove it is working?
3. Most common cause of a private endpoint resolving publicly?
4. Why is a private endpoint without disabling public access not a security control?
5. On-prem client gets the public IP. Fix?
6. Blob works, file share fails. Why?
7. Why centralise Private DNS Zones in the hub?
8. Endpoint shows `Pending`. What is missing?

<details>
<summary>Answers</summary>

1. The **network path** (a NIC in your subnet) and the **name resolution** (Private DNS Zone). They
   are configured separately and either can be missing.
2. **No.** The CNAME appears in both broken and working cases. **The resolved IP address is the test.**
3. The **Private DNS Zone is not linked to that VNet**.
4. The public endpoint is still live and reachable from the internet, so a leaked key still works.
   It changes routing, not exposure.
5. A **conditional forwarder** on the on-premises DNS for the `privatelink` zone, pointing at an
   Azure DNS Private Resolver inbound endpoint.
6. Each **sub-resource** needs its own private endpoint and DNS zone.
7. Consistent resolution everywhere. Per-spoke zones make the answer depend on the client's VNet.
8. **Approval** — cross-subscription or cross-tenant connections require manual approval.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — create a storage account, add a private endpoint, and capture `Resolve-DnsName`
  **before and after** linking the Private DNS Zone. Those two outputs side by side are the single
  most instructive artifact in this entire domain.
- **`break-fix/`** — unlink the zone and reproduce the public resolution; disable public access
  while DNS is still wrong and capture the resulting application error.
- **`security/`** — an inventory of PaaS resources with private endpoints **and** their
  `publicNetworkAccess` state; the delta is the report.
- **`operations/`** — hub Private DNS Zone inventory with VNet links; on-prem conditional forwarders.
- **`architecture-decisions/`** — ADR: centralised hub DNS zones; Azure Policy to enforce private
  endpoints and deny public network access on new data services.
