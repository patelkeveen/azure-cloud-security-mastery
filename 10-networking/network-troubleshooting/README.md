# Network Troubleshooting

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> The method, not another tool list. Everything else in this domain feeds into it.
> Pairs with [`../osi-and-tcp-ip/`](../osi-and-tcp-ip/).

---

## 1. What it is

A **binary search over the path**, layer by layer, that converts "it's broken" into a specific
failing component in a small number of steps.

The method matters more than the tools. Engineers with the same tooling differ by an order of
magnitude in time-to-diagnosis, and the difference is whether they follow an order or guess.

---

## 2. Why a method beats intuition

Under pressure, people jump to the component they know best. A Windows admin restarts the service; a
network engineer checks the firewall; a developer blames DNS. One of them is occasionally right,
which reinforces the habit.

**A method is falsifiable at each step**, so you make measurable progress even when wrong. It also
produces evidence you can hand to another team, which is what actually resolves cross-team incidents.

---

## 3. The method

```
0. What EXACTLY is failing?      one user or all? one destination or all? since when?
        │
1. Has anything changed?          deployment, certificate expiry, firewall rule, DNS TTL
        │
2. NAME      does it resolve, and to the RIGHT address?
        │
3. PATH      is the destination reachable? where does it stop?
        │
4. PORT      is the specific port open?  timeout vs RST
        │
5. TLS       does the handshake complete? is the chain valid?
        │
6. APP       does the application respond, and what does it SAY?
```

**Stop at the first failure and fix it.** Do not continue collecting data — later layers will fail
as a consequence and send you chasing symptoms.

> ⭐ **Step 0 is the one people skip, and it is the highest-value step.** "One user" versus "all
> users" eliminates most of the estate immediately. "Since 09:00" versus "since always" tells you
> whether you are debugging a change or a design.

---

## 4. Worked example — the ladder in commands

```powershell
# 2. NAME - and critically, compare two resolvers
Resolve-DnsName myapp.contoso.com
Resolve-DnsName myapp.contoso.com -Server 1.1.1.1        # do they agree?

# 3. PATH
Test-NetConnection myapp.contoso.com                      # ICMP may be blocked - not conclusive
tracert -d -h 15 myapp.contoso.com                        # where does it stop?

# 4. PORT  <- the decisive step
Test-NetConnection myapp.contoso.com -Port 443

# 5. TLS
$c=[Net.Sockets.TcpClient]::new('myapp.contoso.com',443)
$s=[Net.Security.SslStream]::new($c.GetStream(),$false,({$true}))
$s.AuthenticateAsClient('myapp.contoso.com')
"$($s.SslProtocol)  $(([Security.Cryptography.X509Certificates.X509Certificate2]$s.RemoteCertificate).NotAfter)"

# 6. APP
curl.exe -sS -o NUL -w "http=%{http_code} dns=%{time_namelookup}s connect=%{time_connect}s tls=%{time_appconnect}s total=%{time_total}s\n" https://myapp.contoso.com
```

That last command is worth memorising — **it times every layer in one call**:

```
http=200 dns=0.004s connect=0.021s tls=0.089s total=0.310s
```

**Read the timings, not just the code:**

| Pattern | Diagnosis |
|---|---|
| `dns` high (>1s) | Slow or failing resolver; check forwarders |
| `connect` high | Network latency or a retrying path |
| `tls` high (>2s) | ⭐ **Revocation check timing out** — CRL/OCSP blocked |
| `total` high, others low | The **application** is slow. Network is exonerated. |

> That table converts "the app is slow" — an argument — into a measurement that assigns ownership.

---

## 5. Azure-specific tools

| Tool | Answers |
|---|---|
| **Effective NSG rules** | Which rule actually applies, including defaults |
| **Effective route table** | Where traffic actually goes; what was overridden |
| **NSG flow logs** | Was it allowed or denied, historically |
| **Connection troubleshoot** | End-to-end test with the platform's own verdict |
| **Packet capture** (Network Watcher) | When you genuinely need the bytes |

```bash
# Azure's own verdict on a specific flow - use this before arguing with anyone
az network watcher test-connectivity \
  --source-resource vm-app-01 -g rg-prod \
  --dest-address 10.100.3.4 --dest-port 443 -o json
```

```json
{
  "connectionStatus": "Unreachable",
  "hops": [
    { "type": "Source",  "address": "10.101.1.4",
      "issues": [ { "type": "NetworkSecurityRule", "value": "DenyAllOutBound" } ] }
  ]
}
```

⭐ **`test-connectivity` names the blocking rule.** It is the fastest path from "connection fails"
to "this NSG rule, on this hop" and it removes the guesswork entirely.

**Historical questions need flow logs**, because the moment has passed:

```kusto
AzureNetworkAnalytics_CL
| where TimeGenerated > ago(1h)
| where DestPort_d == 443 and FlowStatus_s == "D"        // D = Denied
| summarize Denied = count() by NSGRule_s, SrcIP_s, DestIP_s
| order by Denied desc
```

---

## 6. Isolating the variable

When the ladder does not settle it, change **one** thing at a time:

| Question | Test |
|---|---|
| Is it this client? | Same request from another machine in the same subnet |
| Is it this subnet? | Same request from a different subnet |
| Is it this destination? | Same client to a different destination |
| Is it DNS? | Connect **by IP**, bypassing name resolution |
| Is it TLS? | Try plain HTTP, or disable validation temporarily |
| Is it the app? | Request a static health endpoint instead |

**Connecting by IP is the highest-yield single test.** If it works by IP and fails by name, you have
localised the fault to DNS in one step and eliminated the entire network.

---

## 7. What breaks the troubleshooting itself

**Using `ping` as the reachability test.** Cloud endpoints drop ICMP. See
[`../osi-and-tcp-ip/`](../osi-and-tcp-ip/) §5.

**Changing several things at once.** When it starts working you have learned nothing, and you cannot
write the postmortem.

**Trusting the diagram.** Diagrams describe intent. Effective routes and effective NSG rules
describe reality; when they disagree, the diagram is wrong.

**Not checking the HOSTS file.** It defeats every DNS diagnostic and is invisible.

**Ignoring "nothing changed".** Certificates expire and DNS TTLs lapse without anyone acting — those
*are* changes.

**Skipping step 0.** Debugging the whole estate when one user is affected.

---

## 8. Customer discovery questions

1. Is there a documented triage runbook, or does the service desk escalate everything?
2. Are **NSG flow logs** enabled and queryable? For how long?
3. Does anyone use **effective rules and routes**, or do teams read the portal blades?
4. Is Network Watcher enabled in every region in use?
5. Who owns the boundary between "network" and "application"? How is it settled today?
6. Is ICMP permitted enough for `tracert` and Path MTU Discovery to work?
7. Are timings captured during incidents, or only success/failure?

---

## 9. Remember it

**Hook — "Connect by IP."** Works by IP but not by name → DNS, proven in one step.

**Analogy — binary search, not intuition.** Under pressure everyone jumps to the component they know
best, and is occasionally right, which reinforces the habit. A layered ladder is **falsifiable at
each step**, so you make measurable progress even when your guess is wrong — and it produces
evidence another team will accept.

**The one thing:** **step 0 is the one people skip.** One user or all? One destination or all? Since
when? That question eliminates most of the estate before you run a single command.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 10. Self-test

1. First question before any command?
2. Fastest way to determine whether DNS is the problem?
3. `curl` shows `tls=4.2s`, everything else fast. Diagnosis?
4. Which Azure command names the specific NSG rule blocking a flow?
5. Timeout versus RST on a port test?
6. Why is a network diagram not evidence?
7. Where do you look for a denial that happened yesterday?
8. Works from VM A, fails from VM B, same subnet. What does that eliminate?

<details>
<summary>Answers</summary>

1. **What exactly is failing** — one user or all, one destination or all, and since when.
2. **Connect by IP.** Works by IP but not by name → DNS, in one step.
3. **Revocation check timing out** — the CRL/OCSP endpoint is blocked or slow.
4. `az network watcher test-connectivity` — it returns the blocking rule in `issues`.
5. **Timeout** = silently dropped, almost always a firewall/NSG. **RST** = reachable, nothing
   listening.
6. It records **intent**. Effective routes and effective NSG rules record **reality**.
7. **NSG flow logs**, queried in Log Analytics. Live tools cannot answer historical questions.
8. Eliminates the **subnet-level** controls — NSG on the subnet, routing, DNS server config. The
   difference is on VM B itself: host firewall, local config, or its NIC-level NSG.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — run the full §4 ladder against a working service and capture every output as a
  baseline. A baseline is what makes an anomaly visible.
- **`break-fix/`** — break the service at each layer in turn (DNS, NSG, TLS, app) and capture how
  the ladder localises each one. **Six deliberate breakages produce the most valuable single
  artifact in this domain.**
- **`security/`** — flow logs enabled and retained; confirmation that denials are queryable.
- **`operations/`** — the triage runbook, written so the service desk can execute it unaided.
- **`architecture-decisions/`** — ADR: flow log retention period and cost trade-off.
