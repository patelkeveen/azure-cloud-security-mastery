# Load Balancing

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> Four Azure products that look interchangeable and are not. Choosing wrong is expensive to undo.

---

## 1. What it is

Distributing traffic across multiple backends for **scale** and **availability**, while removing
unhealthy backends automatically.

The health probe is the part that actually matters. Distribution is easy; **knowing which backends
are alive** is the whole product.

---

## 2. Why there are four products

They differ on two axes: **which OSI layer** they understand, and **global versus regional**.

|  | Regional | Global |
|---|---|---|
| **L4** (TCP/UDP) | **Azure Load Balancer** | Cross-region Load Balancer |
| **L7** (HTTP/S) | **Application Gateway** (+ WAF) | **Front Door** (+ WAF, CDN) |

| Product | Use it when |
|---|---|
| **Load Balancer** | Any TCP/UDP; non-HTTP protocols; lowest latency; cheapest |
| **Application Gateway** | HTTP(S) in **one region**, needs WAF, path routing, TLS termination |
| **Front Door** | **Multi-region** HTTP(S), global anycast entry, edge caching, WAF at the edge |
| **Traffic Manager** | DNS-level steering — returns different answers; ⚠ **does not proxy traffic** |

> ⭐ **Traffic Manager is DNS, not a proxy.** It hands out an address and steps out of the path. It
> therefore cannot terminate TLS, inspect requests, or fail over faster than the client's DNS cache
> allows. People deploy it expecting instant failover and get TTL-bound failover instead.

**The common correct pattern** for a multi-region web application:

```
Internet → Front Door (global anycast, WAF, TLS)
              └─► region A: Application Gateway → VMs / AKS
              └─► region B: Application Gateway → VMs / AKS
```

Front Door handles global routing and edge; Application Gateway handles regional L7 and its WAF.
Using both is not redundancy — they do different jobs.

---

## 3. How it works underneath

### Health probes — where outages actually come from

```
Probe every N seconds  ──► backend endpoint
      │
      ├── expected response (e.g. HTTP 200)  → backend IN rotation
      └── failure × threshold                → backend REMOVED
```

**The probe is a promise about what "healthy" means, and most probes lie.**

A probe hitting `/` returns 200 from the web server even when the database is unreachable. Traffic
keeps arriving at a backend that cannot serve it. The fix is a **deep health endpoint**:

```
GET /healthz
    → checks DB connection, cache, critical dependency
    → 200 only if the instance can genuinely serve requests
    → 503 otherwise
```

⚠ Deep probes have a failure mode too: if the shared database dies, **every** backend fails its
probe and the whole pool is removed — turning a degraded service into a total outage. Mature designs
separate **liveness** (am I running?) from **readiness** (can I serve?), and only readiness controls
rotation.

**Azure health probes come from `168.63.129.16`.** ⭐ If an NSG blocks it, **every backend is marked
unhealthy and the service goes fully down** — with no obvious cause. This single fact resolves a
whole category of incidents.

### Session persistence

| Mode | Behaviour |
|---|---|
| None (5-tuple) | Every connection may land anywhere. Default, and correct for stateless apps. |
| Client IP (2-tuple) | Same client IP → same backend |
| Cookie-based (App Gateway) | Cookie pins the session |

**Persistence is a workaround for state stored in the wrong place.** It undermines even
distribution, breaks when clients share a NAT address, and makes deployments harder. Externalise
session state instead; use persistence only when you cannot.

---

## 4. Worked example — every backend is unhealthy

```bash
az network lb probe list -g rg-prod --lb-name lb-app -o table
```

```
Name        Protocol  Port  IntervalInSeconds  NumberOfProbes  RequestPath
----------  --------  ----  -----------------  --------------  -----------
probe-http  Http      80    5                  2               /healthz
```

```bash
# Application Gateway gives a per-backend explanation - this is the useful one
az network application-gateway show-backend-health -g rg-prod -n agw-app \
  --query "backendAddressPools[].backendHttpSettingsCollection[].servers[]" -o table
```

```
Address      Health     HealthProbeLog
-----------  ---------  ------------------------------------------------------------
10.101.1.4   Unhealthy  Received invalid status code 404. Expected 200-399
10.101.1.5   Unhealthy  Received invalid status code 404. Expected 200-399
```

**`HealthProbeLog` names the cause.** Here the probe path `/healthz` does not exist — 404, not 200.
Other messages worth recognising:

| Message | Cause |
|---|---|
| `Received invalid status code 404` | Probe path wrong |
| **Timed out** | ⭐ **NSG blocking `168.63.129.16`**, or the service is not listening |
| `Backend certificate is invalid` | End-to-end TLS with an untrusted or expired backend cert |
| `Common name does not match` | Probe hostname differs from the backend certificate SAN |

**Verify from inside** before blaming the load balancer:

```powershell
Invoke-WebRequest -Uri http://10.101.1.4/healthz -UseBasicParsing |
  Select-Object StatusCode, @{n='Body';e={$_.Content.Substring(0,60)}}
```

If that returns 200 from a peer VM but the probe fails, the problem is between the platform and the
backend — which points squarely at the NSG.

---

## 5. TLS termination — three patterns, one decision

```
① Termination      client ──TLS──► AppGw ──plaintext──► backend
② End-to-end       client ──TLS──► AppGw ──TLS────────► backend      (re-encrypted)
③ Passthrough      client ──TLS──────────────────────► backend      (L4 LB only)
```

| | Inspect / WAF | Backend cert needed | Use when |
|---|:---:|:---:|---|
| ① Termination | ✅ | ✗ | Trusted network segment between LB and backend |
| ② End-to-end | ✅ | ✅ | Regulated — encrypted in transit everywhere |
| ③ Passthrough | ✗ | ✅ | mTLS to the backend, or the LB must not see the traffic |

**Passthrough means no WAF.** You cannot inspect what you cannot decrypt. Choosing passthrough for
"security" reasons often *reduces* security by removing the inspection point.

---

## 6. What breaks

**NSG blocking `168.63.129.16`.** Every backend unhealthy. The most common total outage here.

**Shallow probe.** Backend answers 200 while unable to serve. Traffic sinks into a broken instance.

**Over-deep probe.** A shared dependency fails and removes the entire pool at once.

**Expired backend certificate** in end-to-end TLS. Front end looks fine; all backends unhealthy.

**Asymmetric routing with a UDR.** Inbound via the load balancer, outbound via a firewall — the
firewall drops replies to flows it never saw. See [`../nat-and-firewalls/`](../nat-and-firewalls/) §6.

**Expecting Traffic Manager to fail over instantly.** It is DNS. Client caches honour TTL, and some
ignore it.

**Session persistence hiding a state bug.** It works until the pinned instance is replaced.

---

## 7. Customer discovery questions

1. Which products are deployed, and does the choice match the requirement — or history?
2. What do the health probes actually check — `/` or a real readiness endpoint?
3. Is `168.63.129.16` permitted from every backend subnet?
4. TLS terminated, end-to-end, or passthrough? Is there a WAF, and can it see the traffic?
5. Is session persistence enabled? Why — and what state is being held locally?
6. Multi-region: Front Door, Traffic Manager, or both? What is the expected failover time?
7. Is there any asymmetric routing between load-balanced inbound and firewalled outbound?
8. Who monitors backend health, and does anyone get alerted before users notice?

---

## 8. Remember it

**Hook — "The bouncer checks the door, not the kitchen."**

**Analogy — probe depth.** A probe against `/` confirms the web server answers; it says nothing
about whether the database is reachable. Over-correct with a deep probe and one dead database
removes **every** backend at once, turning degraded into total outage. Hence liveness (am I
running?) must be separated from readiness (can I serve?).

**The one thing:** health probes originate from **168.63.129.16**. Block it with an NSG and **every**
backend goes unhealthy simultaneously, with no obvious cause.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 9. Self-test

1. Four Azure products — which is L4 regional, which is L7 global?
2. Why is Traffic Manager not a load balancer in the usual sense?
3. Health probe source IP, and what happens if it is blocked?
4. Why is a probe against `/` dangerous, and what is the risk of over-correcting?
5. Which TLS pattern prevents WAF inspection?
6. All backends unhealthy, `HealthProbeLog` says timed out. Two candidate causes?
7. Why is session persistence usually a workaround?
8. Front Door **and** Application Gateway together — redundancy or different jobs?

<details>
<summary>Answers</summary>

1. **Azure Load Balancer** = L4 regional. **Front Door** = L7 global.
2. It works at **DNS** — it returns an address and is not in the traffic path, so failover is bound
   by DNS TTL and client caching.
3. **`168.63.129.16`.** If blocked, **every backend is marked unhealthy** and the service goes down.
4. `/` returns 200 even when dependencies are dead. Over-deep probes remove the **entire pool** when
   a shared dependency fails — separate liveness from readiness.
5. **Passthrough** — the load balancer cannot decrypt, so it cannot inspect.
6. **NSG blocking `168.63.129.16`**, or the service is not listening on the probe port.
7. It compensates for session state held on the instance instead of externalised.
8. **Different jobs** — Front Door for global routing and edge, Application Gateway for regional L7
   and WAF.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — deploy an Application Gateway with two backends; capture `show-backend-health`
  healthy, then break one and capture the `HealthProbeLog`.
- **`break-fix/`** ⭐ — block `168.63.129.16` with an NSG and observe **every** backend go
  unhealthy. This is the highest-value single lab in the topic.
- **`security/`** — TLS pattern per application and whether WAF can inspect; WAF mode
  (detection versus prevention) recorded per app.
- **`operations/`** — health endpoint standard (liveness versus readiness) and probe configuration
  baseline.
- **`architecture-decisions/`** — ADR: product selection per application, and the multi-region
  failover mechanism with its expected RTO.
