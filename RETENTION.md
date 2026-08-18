# Retention — Tips, Tricks and Hooks

> **The memory layer.** Deliberately **one interleaved document, not one appendix per topic.**
> Mixing topics during recall is what makes memory durable; reviewing one topic at a time feels
> productive and isn't.
>
> ⚠ **Honest scope.** §§1–9 were built from the first **22** DEEP topics
> ([`35-active-directory-and-hybrid-identity/`](35-active-directory-and-hybrid-identity/) and
> [`10-networking/`](10-networking/)); §10 covers
> [`45-m365-migration-engineering/`](45-m365-migration-engineering/), §11
> [`75-architecture-and-consulting/`](75-architecture-and-consulting/) and §12
> [`70-operations-and-reliability/`](70-operations-and-reliability/). The repo has **135** DEEP
> topics — see [`COVERAGE.md`](COVERAGE.md) — so ⭐ **this deck trails the content and does not yet
> cover Azure platform, identity, M365 or AI security.** Each of those topics carries its own
> **§ Remember it** and **§ Self-test**; use those until they are folded in here.
>
> Last revised **2026-08-18**.

---

## How to use this

Three rules, and they are the whole method:

1. **Cover the right-hand column and answer out loud** before reading it. Recognition is not recall,
   and reading this document top to bottom teaches you almost nothing.
2. **Interleave.** Jump between hybrid identity and networking. It feels worse and works better.
3. **Space it.** Same day, next day, three days, a week. Anything you get right twice in a row,
   drop for two weeks.

> ⭐ **The single best study technique for this material: explain the mechanism to an imaginary
> junior engineer, out loud, without notes.** Every place you say "and then it sort of…" is a gap.
> That is the same test an interviewer applies.

---

## 1. The numbers you must know cold

Numbers are what separate "I've read about it" from "I've run it." These are the ones that come up.

| Number | What | Hook |
|---:|---|---|
| **2 min** | Password hash sync cadence | **"2 for passwords, 30 for everything else"** |
| **30 min** | Object sync cycle (and the floor) | ↑ same hook |
| **5 min** | Kerberos clock skew tolerance | Five minutes late and Kerberos won't let you in |
| **5** | Addresses Azure reserves per subnet | **Gateway, DNS, DNS, and both ends** (.0 .1 .2 .3 + last) |
| **1,000** | PBKDF2 iterations in PHS | |
| **10 bytes** | Per-user salt in PHS | |
| **180 days** | Tombstone lifetime (modern default) | Half a year offline = rebuild, don't reconnect |
| **500** | Accidental-deletion threshold | |
| **150,000** | Cloud Sync objects **per domain** | **Per domain, not per tenant** — the trap |
| **50,000** | Cloud Sync max group members | Retail and education break here first |
| **250,000** | Connect Sync max group members | |
| **65,000** | SNAT ports per public IP | |
| **1500** | Default Ethernet MTU | |
| **168.63.129.16** | Azure DNS + DHCP + health probes | **Block it and everything dies** |
| **169.254.169.254** | Instance metadata endpoint | Where SSRF steals managed-identity tokens |
| **169.254.x.x** | APIPA — DHCP failed | The client asked; nobody answered |
| **88 / 389 / 636 / 3268** | Kerberos / LDAP / LDAPS / **Global Catalog** | 3268 is **forest-wide** |
| **500 / 502 / 512 / 519** | RIDs: Administrator / **krbtgt** / Domain Admins / **Enterprise Admins** | |

---

## 2. Mnemonics

| Mnemonic | Unpacks to |
|---|---|
| **DORA** | DHCP: **D**iscover, **O**ffer, **R**equest, **A**ck |
| **LSDOU** | GPO order: **L**ocal, **S**ite, **D**omain, **OU** — later overwrites earlier |
| **AGDLP** | **A**ccounts → **G**lobal → **D**omain **L**ocal → **P**ermission |
| **U-B-S** | Azure route precedence: **U**DR → **B**GP → **S**ystem |
| **"2 for passwords, 30 for everything else"** | PHS 2 min; object sync 30 min |
| **"Hard before soft"** | Matching order: sourceAnchor first, then UPN/SMTP |
| **"Hub allows, spoke uses"** | `allowGatewayTransit` on hub; `useRemoteGateways` on spoke |
| **"In is deny, out is allow"** | NSG default asymmetry — the exfiltration path |
| **"Specific beats strong"** | Longest prefix match wins over any precedence rule |
| **"401 = who?  403 = no."** | Unauthenticated vs forbidden |
| **"Silence is a firewall; RST is an answer"** | Timeout = dropped; RST = reachable, not listening |
| **"The CNAME lies, the IP tells the truth"** | Private endpoint DNS verification |
| **"Gateway, DNS, DNS, and both ends"** | Azure's 5 reserved addresses |

---

## 3. Analogies that actually hold

Use these to *rebuild* a mechanism you've half-forgotten — each one is load-bearing, not decorative.

**Connect Sync = a translation office with an interpreter's notebook.**
Two embassies (AD, Entra) never speak directly. Each has an inbox (**connector space**) where mail
sits until collection time. The interpreter keeps one master notebook (**metaverse**) with one page
per person, assembled from both embassies. *This is why your change isn't in Entra yet* — it's in
the inbox, waiting for pickup. It's also why a **staging server** is possible: it reads and
translates but never delivers.

**Source anchor = a passport number, not a name.**
Names change with marriage, rebrand, merger. `objectGUID` is a **national ID** — worthless once you
emigrate to a new forest. `ms-DS-ConsistencyGuid` is a number **you** control and carry across the
border. Hence: *GUID dies at the forest border; ConsistencyGuid crosses it.*

**Kerberos = a theme park.**
Show ID at the gate once, get a **wristband** (TGT). At each ride, swap the wristband for a
**ride ticket** (service ticket). The ride operator checks the ticket **without phoning the gate** —
which is exactly why a forged Silver Ticket leaves no entry in the gate's log, and why your new
group membership doesn't work until you get a new wristband (`klist purge`).

**Golden SAML = a stolen embossing seal.**
Applications don't call AD FS to verify — they check the **seal**. Steal the seal and you emboss any
document you like, including "this person did MFA." Changing everyone's passwords doesn't help;
you have to **re-cut the seal** (rotate the certificate).

**The forest is the security boundary because domains share a schema.**
Domains are flats in one building; the forest is the building. Separate flats, but shared plumbing,
wiring and a caretaker with every key. Two organisations that must not reach each other need
**separate buildings**, not separate flats.

**Private endpoint = a private phone line to one specific office.**
Creating the line changes nothing until you **update the phone book** (Private DNS Zone). Everyone
keeps dialling the public number. Worse — it still connects, so nobody notices. *And the line is
only a security control once you disconnect the public number* (`publicNetworkAccess: Disabled`).

**Peering is a handshake, not a highway.**
A shakes B's hand, B shakes C's. A and C have not met. Peering is **not transitive** — and that's
your segmentation, not a bug.

**Health probe = a bouncer who only checks the door is unlocked.**
A probe against `/` says the web server answers. It says nothing about whether the database is
reachable. Over-correct with a deep probe and one dead database removes **every** backend at once —
degraded becomes total outage. Hence liveness (am I running?) ≠ readiness (can I serve?).

---

## 3b. ⭐ Cross-cutting patterns — the ones that recur across every domain

These are worth more than any single fact, because they transfer. When you meet a new Microsoft
control you have never seen, these predict how it behaves.

### "Watch first" — every enforcement control has an observe mode

| Control | The observe step | Skip it and… |
|---|---|---|
| Conditional Access | **Report-only mode** | You lock out the tenant |
| ASR rules | **Audit mode** | You break line-of-business apps |
| LDAP signing | Audit **Event 2889** | Printers, scanners and legacy apps die at once |
| SOAR playbooks | Notification before remediation | One false positive disables real accounts |
| Sentinel rules | Tune before enabling incident creation | Analysts drown and mute the rule |
| Deletion threshold (Connect Sync) | It **is** the observe step — do not raise it | 500 objects vanish for real |

> **Junior engineers enable the control. Senior engineers measure the blast radius, then enable the
> control.** That one habit, applied everywhere, is most of the difference — and it is the security
> expression of "measure before changing."

### "Two identities" — the thing people forget exists

Almost every identity incident and design failure comes from forgetting that **workload identities
are separate principals** with their own credentials, permissions and logs.

| You did this to the user | It did nothing to |
|---|---|
| Reset the password | The consented app, the service principal credential |
| Revoked sessions | The SP's own tokens |
| Queried `SigninLogs` | `AADServicePrincipalSignInLogs` |
| Disabled the account | An added federated domain |

### "It changes by itself" — the two silent clocks

**Certificates expire. DNS TTLs lapse.** Nobody acted, and yet the system changed. When something
worked yesterday and "nothing changed", these are why — and they are also why calendar-with-an-owner
beats a dashboard nobody reads.

### "Deployed is not enforced"

| Deployed | Actually doing something only when |
|---|---|
| Azure Firewall | A **UDR** sends traffic to it (`Invalid` on the system route) |
| Private endpoint | The **DNS zone is linked** *and* public access is **disabled** |
| Defender sensor | It is on **both** Entra Connect servers, and NNR ports are open |
| ASR rule | It is in **block**, not audit — after auditing |
| MFA via custom controls | ⚠ It never satisfied the MFA claim at all |

---

## 4. Confusion pairs — the ones people mix up

Cover the right column. These are exactly what gets asked.

| Pair | The distinction that resolves it |
|---|---|
| **Domain vs forest boundary** | **Forest** is the security boundary. Domains share a schema. |
| **Project vs join vs provision** | Project = new metaverse object. Join = link to existing (**evaluated once, never re-evaluated**). Provision = create downstream connector-space object (changes nothing until export). |
| **Hard vs soft match** | Hard = **sourceAnchor**. Soft = **UPN or primary SMTP**. Hard is tried first. |
| **`objectGUID` vs `ms-DS-ConsistencyGuid`** | Only the second survives a forest migration. |
| **PHS vs PTA vs Federation** | Only **PHS** survives a complete on-prem outage. Only PHS gets leaked-credential detection. |
| **Managed vs Federated domain** | Managed = Entra authenticates. Federated = Entra redirects to an external STS. **Per domain, not per tenant.** |
| **Connect Sync vs Cloud Sync** | Cloud Sync has **no metaverse** → supports disconnected forests, but can't do cross-forest references or multi-domain attribute merge. Same design choice, both consequences. |
| **Device sync vs device writeback** | Device sync = Connect-only (blocks Cloud Sync). Device **writeback** is retired → **Cloud Kerberos Trust**. |
| **Service endpoint vs private endpoint** | Service endpoint leaves the **public IP live**. Private endpoint puts a **private IP in your subnet**. |
| **401 vs 403** | 401 = get a new token. 403 = **the token is fine**, the permission is wrong. |
| **Timeout vs RST** | Timeout = firewall/NSG dropped it. RST = reachable, nothing listening. |
| **CN vs SAN** | Modern clients read **SAN only**. CN is ignored. |
| **`allowGatewayTransit` vs `useRemoteGateways`** | **Hub allows, spoke uses.** |
| **NSG inbound vs outbound default** | Inbound deny, **outbound allow**. |
| **Traffic Manager vs Front Door** | Traffic Manager is **DNS** (not in the path, TTL-bound failover). Front Door is a **proxy**. |
| **Azure Firewall vs App Gateway WAF** | Firewall = egress + L3–L7. WAF = **inbound HTTP** protection. |
| **389 vs 3268** | 389 = **domain**. 3268 = **forest-wide** Global Catalog. |
| **`State: Invalid` vs broken** | Invalid = **overridden** by a higher-precedence route. Not an error. |
| **Custom controls vs EAM** | Custom controls **never satisfied the MFA claim** (so PIM refused). EAM does. |

---

## 5. The "if you remember one thing" line, per topic

**Hybrid identity**

| Topic | The one line |
|---|---|
| Connect Sync | The **connector space** exists so nothing propagates automatically — that's every timing question you'll ever debug |
| Source anchor & matching | GUID bytes are **little-endian**; hand-rolled immutableId scripts get it wrong and duplicate the user |
| Cloud Sync | **No metaverse** → disconnected forests work, cross-forest references don't |
| AD DS | The **forest** is the security boundary, not the domain |
| DNS/Kerberos/LDAP/GPO | Group membership is baked into the **PAC** at ticket issue — `klist purge` |
| AD FS | The app checks a **signature**, never calls back. That's why the signing key is everything |
| Hybrid coexistence | Disable in AD **and `Revoke-MgUserSignInSession`** — otherwise refresh tokens keep working |
| Okta / third-party | Custom controls **retire 30 Sep 2026**; they never satisfied the MFA claim |

**Networking**

| Topic | The one line |
|---|---|
| OSI / TCP-IP | Destination **MAC is the next hop**; destination IP is the target |
| Subnetting | Azure reserves **5**, so the smallest usable subnet (/29) gives you **3** |
| DNS | Compare two resolvers — disagreement localises the fault instantly |
| TLS / PKI | Servers must send **intermediates**; browsers hide the omission, `curl` doesn't |
| Azure VNet | **Outbound internet is allowed by default** |
| Private endpoints | The CNAME appears either way — **the IP is the test** |
| Peering | **Not transitive** |
| NAT / firewalls | Firewall deployed ≠ traffic inspected. Check for the **`Invalid`** system route |
| Routing / BGP | **Longest prefix beats precedence** |
| VPN / ExpressRoute | ExpressRoute is **private, not encrypted** |
| Load balancing | Health probes come from **168.63.129.16** |
| HTTP / APIs | Read the **response body** — Graph tells you exactly what's wrong |
| Troubleshooting | **Connect by IP** — one step eliminates or convicts DNS |
| DHCP | In Azure, set Static on the **NIC**, never inside the guest |

---

## 6. Symptom → cause reflex table

Build the reflex. In an incident you want the candidate cause in seconds, not a methodology.

| Symptom | First suspect |
|---|---|
| Worked yesterday, nothing changed | **DNS or a certificate** — the two things that change by themselves |
| Cannot log in, DC pings fine by IP | DNS — client can't *find* a DC |
| "Clock skew too great" / random logon failures | PDC Emulator time hierarchy |
| Access denied right after a group change | Stale **PAC** — `klist purge` |
| Most users fine, users in **many groups** fail Kerberos | Large PAC → **TCP 88** not open |
| App can't find users that exist | LDAP **389 instead of 3268** in a multi-domain forest |
| Works in Chrome, fails from `curl` | **Missing intermediate** certificates |
| Handshake takes 15s then succeeds | **Revocation check** (CRL/OCSP) timing out |
| Small requests work, large ones hang | **MTU** — and ICMP blocked, so PMTUD can't work |
| Intermittent timeouts under load only | **SNAT port exhaustion** |
| Private endpoint resolves to a public IP | **Private DNS Zone not linked to the VNet** |
| Every backend suddenly unhealthy | NSG blocking **168.63.129.16** |
| Traffic bypasses the firewall | **No UDR** — check for `Invalid` on the system route |
| Spoke A can't reach spoke B | Peering **isn't transitive** — needs UDRs + `allowForwardedTraffic` |
| Spoke can't reach on-premises, hub can | **`useRemoteGateways`** missing |
| Tunnel `Connected`, `RoutesReceived: 0` | BGP peered but nothing advertised |
| NVA deployed, traffic silently dropped | **IP forwarding** not enabled on its NIC |
| VM loses connectivity after resize | Static IP set **inside the guest** |
| `169.254.x.x` on an interface | **DHCP failed** |
| PIM refuses activation though MFA was done | **Custom controls** — no MFA claim |
| Disabled in AD, still reading email | PHS lag **and** no session revoke |
| Expired contractor still has mailbox access | **`accountExpires` doesn't sync** |
| Unexplained NTLM spike | Kerberos failing → **silent fallback** |

---

## 7. Interview-grade answers

The questions that actually get asked, and the shape of a strong answer. **Say the mechanism, then
the consequence** — that ordering is what makes an answer sound senior.

**"Walk me through password hash sync."**
> Every 2 minutes the agent pulls `unicodePwd` over MS-DRSR. The 16-byte MD4 hash is expanded to 64
> bytes, salted with 10 bytes per user, and run through PBKDF2 — 1,000 iterations of HMAC-SHA256.
> **The MD4 hash never leaves the building**; Entra stores a salted SHA256 derivative. So if the
> cloud hash is stolen, it can't be replayed against on-prem AD — which makes PHS *more* secure than
> what most customers do today.

**"Is the domain a security boundary?"**
> No — the **forest** is. Domains share a schema and configuration partition, so a Domain Admin in
> any domain has a path to the whole forest. Two organisations that must not reach each other need
> separate forests.

**"How do you decide Connect Sync vs Cloud Sync?"**
> Default to Cloud Sync — it's Microsoft's strategic direction and gives real HA through multiple
> active agents. Six rows decide it in practice: device sync for Hybrid Entra Join, 150k objects per
> domain, 50k group members, advanced sync rules, cross-forest references, reconciliation. And note
> Exchange hybrid attributes are supported by **both** — that's widely misreported.

**"Why is a private endpoint alone not a security control?"**
> Because the public endpoint stays live. It changes routing, not exposure — a leaked key still
> works from anywhere. It becomes a control when you also set `publicNetworkAccess: Disabled`, and
> when the Private DNS Zone is actually linked to the VNet, which is the step that's usually missed.

**"You get a 403 from Graph. What now?"**
> Not a token problem — 403 means authenticated but not permitted. I'd read the response body;
> `Authorization_RequestDenied` means the permission is missing or unconsented. Then check the
> token's `scp` or `roles` claim against what the endpoint needs. And capture `request-id` for support.

**"How would you find the riskiest thing in an AD estate in an hour?"**
> Who holds **Replicate Directory Changes All** — that's DCSync, every hash including krbtgt,
> without touching a DC. Then unconstrained delegation on non-DCs, SPN accounts that aren't gMSA,
> and when krbtgt was last reset — twice, or it doesn't count.

---

## 8. The traps that have cost people their weekend

| Trap | Why it bites |
|---|---|
| Assuming **soft/hard match block flags** are on | Both default **False**; most tenants never close them after migration |
| Enabling PHS **after** `CloudPasswordPolicyForPasswordSyncedUsersEnabled` | Retrofitting only clears the flag on each user's *next* password change |
| Reading **150,000** as a tenant limit | It's **per domain** — rules out migrations that would work |
| One `klist` fix, forgetting sign-out | The PAC is in the *ticket*; purge **and** re-authenticate |
| Raising the deletion threshold | It's the guard working. Find why 500 objects vanished |
| Trusting the network **diagram** | Diagrams record intent. Effective routes record reality |
| `ping` as a reachability test | Cloud endpoints drop ICMP by design |
| Testing failover **on paper** | "We have a staging server" ≠ tested failover |
| Wildcard certificates everywhere | One key on thirty hosts — compromise anywhere is compromise everywhere |
| `*.blob.core.windows.net` firewall allow | Permits exfiltration to **any** storage account on earth |

---

## 9. Ninety-second refresher

Read this the morning of an interview or exam.

> **Forest** is the security boundary. **Connector space** decouples read from write — that's why
> changes wait. **Metaverse** assembles one identity from many sources; Cloud Sync has none, which
> buys disconnected forests and costs cross-forest references. **Source anchor** must survive a
> forest move, so `ms-DS-ConsistencyGuid`, and the GUID bytes are little-endian. **Hard match before
> soft**, and since **1 July 2026** hard match is blocked against privileged accounts.
> **2 minutes** for passwords, **30** for everything else. **PHS** is the only method that survives
> an on-prem outage. Disabling a leaver needs a **session revoke**. `accountExpires` **doesn't sync**.
>
> **Longest prefix beats precedence**; then **UDR → BGP → system**. NSG is **deny in, allow out**.
> Azure reserves **5** addresses. Peering is **not transitive**; hub allows, spoke uses.
> **168.63.129.16** is DNS, DHCP and health probes — block it and everything looks broken at once.
> A private endpoint needs the **DNS zone linked** and the **public endpoint disabled**, or it's
> decoration. **401 is who, 403 is no.** Timeouts are firewalls; RSTs are answers. And when it
> worked yesterday and nothing changed — it's **DNS or a certificate**.

---

## 10. ⭐ Migration engineering — hooks

> Added **2026-08-18** with [`45-m365-migration-engineering/`](45-m365-migration-engineering/).
> Interleave these with the identity material above — ⭐ **migration questions are identity
> questions wearing a different hat**, and answering them that way is what reads as senior.

### The eleven hooks

| Topic | Hook | The line that regenerates it |
|---|---|---|
| Discovery | `I M C` — Identity, Mailbox, Content | ⭐ Discovery converts a user count into a **date and a list of blockers** |
| Exchange migrations | `C S H I` — Cutover, Staged, Hybrid, IMAP | ⭐ Hybrid **separates copying data from cutting users over**; every other type fuses them |
| SharePoint / OneDrive | `S P U I` — Scan, Package, Upload, Import | ⭐ The migration is easy; **remediating names, paths and permissions is the project** |
| Teams | `G S C E` — Group, SharePoint, Chat, Exchange | ⭐ Files migrate; **messages are re-created with an old date stamp** |
| Tenant-to-tenant | `D I C T` — Domain, Identity, Content, Teams | ⭐ **One domain, one tenant, one moment**; everything else is pre-staging |
| Coexistence | `M D F A` — Mail, Directory, Free/busy, Autodiscover | ⭐ Three synced mechanisms and **one live one — free/busy — and it's the one that breaks** |
| Cutover / rollback | `T G V R` — TTL, Go/no-go, Verify, Rollback | ⭐ TTL down **3 days early**, **two** go/no-go gates, old endpoint alive **a week** |
| Public folders | `H C M` — Hierarchy, Content, Mail-enabled | ⭐ **One writable hierarchy**; mail-enabled folders are **live mail flow** |
| Google Workspace | `L D O S` — Labels, Docs, Orphans, Scopes | ⭐ Nothing is like-for-like; **domain-wide delegation is a master key — revoke it on the last day** |
| Migration tools | `A S B` — Agent, Service-side, SaaS Broker | ⭐ Native for like-for-like; **pay only for cross-tenant, Teams history and the endpoint problem** |
| Reconciliation | `C S S F` — Count, Size, Structure, Function | ⭐ A tool reports it **finished**; reconciliation proves what **arrived** |

### The analogies that carry the mechanism

| Analogy | What it predicts |
|---|---|
| ⭐ **Moving house vs forwarding post** (Exchange) | the address label is **Autodiscover**, changed last — which is why the Outlook profile survives |
| ⭐ **Airport baggage** (SharePoint) | prohibited items rejected at check-in (invalid chars, 400-char path); ⭐ **the conveyor throttles everyone equally (429) and shouting changes nothing** |
| ⭐ **Two branch offices** (coexistence) | cut the phone line and the printed directory still looks fine — ⭐ **a certificate expiry kills calendars while mail keeps flowing** |
| ⭐ **A library** (public folders) | one master catalogue, many shelves; ⭐ **the returns slot in the front door is a live address the public still uses** |
| ⭐ **`V1` on a runway** (cutover) | the abort point is **computed on the ground**, never judged in the moment |
| ⭐ **Translating a book** (Google) | most sentences survive; ⭐ **the puns do not** — labels, Docs revision history, Apps Script |
| ⭐ **A warehouse stocktake** (reconciliation) | no manifest written **before** loading → no stocktake possible |
| ⭐ **Company registered address** (tenant-to-tenant) | only one registration at a time, so the move is an **instant**, not a phase |

### Numbers to know cold

| Value | What it is |
|---|---|
| **400** | SharePoint full **decoded URL path** limit, characters |
| **250 GB** | single-file upload ceiling (SharePoint/OneDrive) |
| **25 TB** | site collection storage |
| **5,000** | list view threshold — ⭐ bites long before the 30 M item ceiling |
| **100 GB** | per public folder mailbox · **1,000** PF mailboxes per tenant |
| **2,000** | cutover migration ceiling — ⭐ **but ~150 is the practical number** |
| **30 min** | Entra Connect delta sync (⭐ **2 min** for password hash sync) |
| **300 s** | the TTL you set 72 hours before cutover |
| **50** | `BadItemLimit` above which `-AcceptLargeDataLoss` is required |
| **95 %** | ⭐ where a healthy hybrid batch **rests and waits** — not a failure |

### Symptom → cause reflex

| Symptom | Cause |
|---|---|
| `IMCEAEX-...RESOLVER.ADR.ExRecipNotFound` | ⭐ **missing X.500 proxy address** — always |
| Batch "stuck" at 95 % | ⭐ it is the wait state. `Complete-MigrationBatch` |
| `StalledDueToTarget_MdbAvailability` | ⭐ EXO throttling. Not a fault. **Do not restart** |
| Free/busy hatched, mail fine | ⭐ on-prem EWS endpoint or its **certificate** |
| Your own domain fails DMARC | ⭐ internal mail routed via the internet — connectors wrong |
| `HTTP 429` + `Retry-After` | SharePoint throttling — sleep exactly that long |
| Migrated Google Doc is 300 bytes | ⭐ `.gdoc` **stub** — conversion was not enabled |
| Counts match, users report loss | ⭐ **per-folder** mismatch hidden by the mailbox total |
| `unauthorized_client` (Google) | delegation scope string mismatch |
| Everything modified today by admin | ⭐ **drag-and-drop was used** — metadata unrecoverable |

### ⭐ Interview-grade answers

> **"How would you migrate 1,400 mailboxes?"**
> ⭐ *"I'd start with the arithmetic, not the tool. Total size over usable bandwidth, times two for
> throttling — if that exceeds the outage the business will accept, hybrid is the only option and
> the decision is made. Then I'd build waves from the **delegation map**, not the org chart, so a
> manager and their assistant never sit on opposite sides of the boundary."*

> **"What's the riskiest part?"**
> ⭐ *"The irreversible ones: the DNS cutover and, in tenant-to-tenant, the domain move — a domain
> exists in exactly one tenant, so there's no hybrid state for it. I lower TTL three days early,
> set two go/no-go gates, and keep the old endpoint accepting mail for a week, because DNS
> propagation has no completion event."*

> **"How do you know it worked?"**
> ⭐ *"'Completed' is the tool's opinion. I reconcile on four axes — count, size, structure and
> function — against a baseline captured before wave one, name every skipped item rather than
> counting them, and hand over a signed report. Sizes legitimately differ by a few per cent;
> **item counts must not.**"*

> **"What's the security concern people miss?"**
> ⭐ *"The migration service account. It reads every mailbox in scope and it's usually excluded from
> MFA to make the tool work. That's a standing exception — time-box it, scope conditional access to
> the tool's IPs, and remove it on the last day. Same discipline as break-glass. For Google
> sources it's worse: domain-wide delegation is one key that impersonates the entire domain."*

---

## 11. ⭐ Architecture and consulting — hooks

> Added **2026-08-18** with [`75-architecture-and-consulting/`](75-architecture-and-consulting/).
> ⭐ **This is the layer that converts "I did labs" into "I've delivered engagements"** — and it is
> what the interview panel is actually probing when they ask a scenario question.

### The ten hooks

| Topic | Hook | The line that regenerates it |
|---|---|---|
| Requirements | `T O N T` — Testable, Owned, Numbered, Traceable | ⭐ **Write the acceptance test at the same moment as the requirement**, or you haven't written one |
| Discovery | `D S C S` — Driver, Stakeholders, Constraints, Success | ⭐ Find the driver, the **one** Accountable name, the blockers you don't control, and **who runs it after you leave** |
| HLD | `D O R I` — Decision, Options, Rationale, Implications | ⭐ HLD records the decision **and why the alternatives lost**; LLD records values |
| LLD | `U C V T` — Unambiguous, Complete, Verifiable, Traceable | ⭐ If a competent stranger can't build it **without phoning you**, it isn't an LLD |
| Checklists | `P V S` — Pause point, Verification, Short | ⭐ ≤9 items, at a named pause point, **every item states how it was verified** |
| Cutover playbooks | `L E V C S` — Lead, Executor, Verifier, Comms, Scribe | ⭐ **Lead never types; Verifier is never the Executor**; abort criteria written in daylight |
| SOPs / runbooks | `S R C` — SOP teaches, Runbook removes thinking, Checklist prevents omission | ⭐ Write for **03:00, second week**; header says `Last tested`, not `Last updated` |
| Change (adoption) | `ADKAR` **as a diagnosis, not a plan** | ⭐ Name the friction and **what users will do instead** — before you deploy |
| Customer training | `U D A S` — Users, Desk, Admins, Sponsor | ⭐ **Sit on your hands and watch them do it.** Verified capability, not a delivered session |
| Handover | `A D C C S` — Acceptance, Documentation, Capability, Credentials, Support | ⭐ **Never hold a credential you haven't watched them change**; the customer verifies your access is gone |

### ⭐ The three name collisions — know which is which

| Name | In `75-` (consulting) | Elsewhere |
|---|---|---|
| **Discovery** | ⭐ people, drivers, decision rights | `45-`: ⭐ the **estate inventory** |
| **Change management** | ⭐ **adoption** — ADKAR, comms, champions | `70-`: ⭐ **change control** — RFC, CAB, windows |
| **Runbooks / cutover** | ⭐ the **artifact and command structure** | `70-`/`45-`: ⭐ the **mechanism** |

⭐ **Being asked "do you do change management?" and answering the wrong one is a real interview
failure.** Ask which they mean — that question alone signals seniority.

### Analogies that carry the mechanism

| Analogy | What it predicts |
|---|---|
| ⭐ **Planning permission vs builder's drawings** (HLD/LLD) | the committee can't approve joist specs; the builder can't build from a planning statement |
| ⭐ **A recipe vs a menu description** (LLD) | ⭐ a recipe written *after* cooking preserves your mistakes |
| ⭐ **The surgical checklist, not the shopping list** | it confirms what everyone already knows, ⭐ because catastrophic failures are the obvious ones under pressure |
| ⭐ **A theatre production** (cutover) | ⭐ the director doesn't act; someone watches from the auditorium to see what the audience sees |
| ⭐ **Satnav vs driving lesson** (runbook vs SOP) | ⭐ a satnav explaining urban planning at a junction is useless |
| ⭐ **A new one-way system** (adoption) | ⭐ the lorries physically can't make the turn — **you widen the corner, you don't re-issue the map** |
| ⭐ **A driving test, not a lesson** (training) | the examiner sits **silently**; you test the emergency stop even though it's inconvenient |
| ⭐ **End of a tenancy** (handover) | ⭐ every key counted, and the landlord changes the locks anyway |
| ⭐ **A builder's quote vs a conversation** (requirements) | *"a nice kitchen"* can't be inspected; ⭐ *"3.2 m quartz, installed by 14 March"* can |
| ⭐ **A doctor's consultation, not a lab test** (discovery) | ⭐ a clinically perfect prescription the patient can't follow is a failed treatment |

### Rules that transfer to any employer

| Rule | Why it holds |
|---|---|
| ⭐ **One Accountable per decision** | two `A`s is an unresolved argument written down |
| ⭐ **One human name, never a department** | *"IT Security will approve"* has never approved anything |
| ⭐ **Executor ≠ Verifier** | the builder tests the path they built and sees it work |
| ⭐ **Abort criteria written in daylight** | at 02:40, sunk cost beats judgement every time |
| ⭐ **Two people trained per task** | the single trained person is on leave during the first incident |
| ⭐ **A temporary exclusion with no review date is permanent** | applies to CA exclusions, service principals, MFA exemptions |
| ⭐ **`Last tested`, not `Last updated`** | an untested runbook is a hypothesis |
| ⭐ **Never announce a removal without the replacement** | the gap between those two messages is where shadow IT is born |
| ⭐ **A user workaround is free, high-quality feedback** | it names the friction you failed to design for |
| ⭐ **As-built ≠ as-designed. Always. Name the delta** | an LLD that quietly disagrees with reality is worse than none |

### ⭐ Interview-grade answers

> **"Walk me through how you'd run a project."**
> ⭐ *"Discovery first — but two kinds: the estate inventory, and the engagement one. Who's the
> single Accountable person, what's driving the deadline, and **who operates this after I leave** —
> that last one changes the design more than anything technical. Requirements next, each with its
> acceptance test written at the same moment, because a requirement I can't test isn't one. Then HLD
> for the decisions and rejected options, LLD for the values, and the LLD doubles as a drift script
> the customer can re-run monthly."*

> **"How do you avoid causing an outage?"**
> ⭐ *"Report-only first and actually read the impact — I've seen three report-only failures in a
> week, which is three real users I'd have blocked. Then a short pre-flight checklist at a named
> pause point, where item one is that break-glass was **tested today**, not that it exists. And the
> person who made the change isn't the person who verifies it."*

> **"A control you deployed isn't being followed. What do you do?"**
> ⭐ *"Find out what people are doing instead, first — the workaround tells me exactly which friction
> I didn't design for. Then diagnose the stage: if they don't know it's coming that's comms, if they
> can't comply on the device they have that's an **ability** gap and more training won't touch it —
> that's a hardware conversation. Most teams answer every adoption problem with training, and it's
> the right answer at only one stage."*

> **"What does 'done' mean to you?"**
> ⭐ *"Five gates: acceptance evidence per requirement, as-built documentation with the deltas named,
> the customer's admins performing each procedure unaided while I sit on my hands, credentials
> transferred so I hold nothing I haven't watched them change, and a hypercare window with a written
> end date. The capability gate is the one that blocks — if they can't run it, it isn't handed over,
> it's abandoned in place with a document."*

---

## 12. ⭐ Operations and reliability — hooks

> Added **2026-08-18** with [`70-operations-and-reliability/`](70-operations-and-reliability/).
> ⭐ **This is the layer that decides whether the security controls you built are still working in
> six months** — and most of it transfers to any employer, cloud or on-premises.

### The thirteen hooks

| Topic | Hook | The line that regenerates it |
|---|---|---|
| Azure Monitor | `M L` — Metrics free/fast/forgetful, Logs paid/slow/permanent | ⭐ **Logs capture forward only** — the diagnostic setting must exist **before** the incident |
| Log Analytics | `T P R` per table — Table, Plan, Retention | ⭐ Filter on time **first**; never change a table's plan without checking the alerts on it |
| Alerts | `A A A` — Actionable, Attributable, Acted-on | ⭐ If nobody must act at 03:00 it's a dashboard; ⭐ **frequency ≤ window** |
| App Insights | `R D E T` + `itemCount` | ⭐ **`sum(itemCount)`, never `count()`**; `operation_Id` rebuilds the journey |
| SLI/SLO/SLA | `I O A` — Indicator measures, Objective targets, Agreement costs | ⭐ Error budget turns "reliable enough?" into arithmetic; ⭐ **serial dependencies multiply** |
| Incident command | `I O C S` — IC, Ops, Comms, Scribe | ⭐ **Declare early, IC doesn't type, communicate before you understand** |
| RCA | `T T A` — Timeline, TTD/TTM, Actions | ⭐ Contributing **factors**, not a root cause; ⭐ an action with no owner isn't an action |
| Runbooks | ladder `T W S A H` | ⭐ **Automate execution, never judgement**; count every self-healing action |
| Change control | `S N E` — Standard, Normal, Emergency | ⭐ **Make the safe path the fast path**; an untested backout is a hypothesis |
| Backup/restore | `R R V` — RPO, RTO, **Verify content** | ⭐ **A green job proves data was written, not that it comes back** |
| Capacity | `U G L` — Usage, Growth, Lead time → **a date** | ⭐ Order date = exhaustion − lead time − margin; ⭐ **ceiling is 80 %** |
| Performance | `p50 p95 p99` · **USE** resources · **RED** services | ⭐ Averages lie; latency degrades **hyperbolically** past ~80 % |
| Chaos | `S H B O` — Steady state, Hypothesis, Blast radius, Observe | ⭐ **No hypothesis, no experiment**; inject **latency**, not just failure |

### ⭐ Numbers to know cold

| Value | What it is |
|---|---|
| ⭐ **43.2 min** | monthly error budget at **99.9 %** |
| ⭐ **4.32 min** | monthly budget at **99.99 %** — ⭐ less than a reboot |
| 7.2 hours | monthly budget at 99 % |
| **93 days** | ⭐ platform **metric** retention · also SharePoint recycle bin total |
| ⭐ **80 %** | the utilisation **knee** — wait ≈ 4× service time |
| ⭐ **95 %** | the utilisation **cliff** — wait ≈ 19× service time |
| **14 → 30 days** | Exchange deleted-items retention, default → max |
| **30 days** | Entra deleted-user recovery window |
| ⭐ **2024-08-31** | Log Analytics agent (MMA) **retired** — AMA only |
| Sev 0–4 | ⭐ 0 critical … ⭐ **4 isn't an alert, delete it** |

### Analogies that carry the mechanism

| Analogy | What it predicts |
|---|---|
| ⭐ **Dashboard vs flight recorder** (metrics/logs) | ⭐ you cannot retrofit a black box **after** the crash |
| ⭐ **Warehouse with three storage rates** (table plans) | ⭐ moving boxes to the depot to save money, then finding the alarm needed to see them |
| ⭐ **A car with 40 warning lights** (alerts) | ⭐ the always-on light's real cost is the one nobody noticed underneath it |
| ⭐ **Hospital wristband** (`operation_Id`) | one department not recording it breaks the chart from there on |
| ⭐ **Household budget** (error budget) | ⭐ "we have 29 minutes left" ends an argument the way "£40 left" does |
| ⭐ **A fire ground, not a fire** (incident command) | the commander stands **outside** with a radio; the best firefighter is inside |
| ⭐ **Air accident investigation, not a court** (RCA) | ⭐ "pilot error" starts the enquiry; the output is a directive with a deadline |
| ⭐ **Hospital backup generator** (runbooks) | ⭐ starts itself, but nobody counts the mains failures |
| ⭐ **Airport security lanes** (change control) | ⭐ a 3-hour normal lane makes everyone an emergency |
| ⭐ **Fire drill, not an extinguisher on the wall** (restore testing) | the point is the fire door that's been propped shut |
| ⭐ **Hospital oxygen supply** (capacity) | ⭐ delivery time is what kills you, not the tank level |
| ⭐ **Motorway at rush hour** (performance) | ⭐ headroom isn't waste; the driver who arrived at the wrong moment is your p99 |
| ⭐ **A drill where everything went perfectly** (chaos) | ⭐ was probably too easy |

### ⭐ Symptom → cause reflex

| Symptom | Cause |
|---|---|
| "There are no logs for that day" | ⭐ diagnostic setting never existed — ⭐ **unrecoverable** |
| Alert never fired | ⭐ `Average` where you needed `Maximum` |
| KQL disagrees with the portal chart | ⭐ `count()` instead of `sum(itemCount)` |
| Query times out | ⭐ time filter not first |
| Alert stopped after a cost review | ⭐ table moved to a cheap plan |
| Green dashboard, angry users | ⭐ server-side SLI |
| Latency exploded, CPU "only" 95 % | ⭐ the utilisation curve, behaving normally |
| Load test passed, prod fell over | ⭐ **coordinated omission** |
| Runbook succeeded, nothing changed | ⭐ no post-condition read-back |
| Restart runbook ran 3× in 4 hours | ⭐ self-healing hiding a degrading system |
| Autoscale failed under load | ⭐ **quota**, not capacity |
| Backup dashboard green, data 5 days old | ⭐ reading successes, not **latest** |
| Most changes are "emergency" | ⭐ the normal path is too slow |

### ⭐ The cross-domain rules

| Rule | Where it also appears |
|---|---|
| ⭐ **Deployed is not enforced** | report-only CA · audit-mode Policy · DMARC `p=none` · ⭐ **an alert nobody actions** |
| ⭐ **Telemetry captures forward only** | unified audit log · diagnostic settings · Identity Protection |
| ⭐ **Read the state back; never trust the call** | break-glass role assignment · runbook post-conditions · restore verification |
| ⭐ **Untested recovery is not recovery** | break-glass · backout plans · restores · failover |
| ⭐ **Executor ≠ verifier** | cutover · restore testing · chaos game days |
| ⭐ **Decide the abort criteria in daylight** | cutover playbooks · error budget policy · chaos stop conditions |
| ⭐ **A temporary exception with no review date is permanent** | CA exclusions · MFA exemptions · automation roles |

### ⭐ Interview-grade answers

> **"How do you know a system is healthy?"**
> ⭐ *"Not from a dashboard being green. I'd want an SLI measured from the user's path — good events
> over valid events — an SLO with an error budget, and burn-rate alerting rather than error-count
> alerting, so a handful of 500s at 3 a.m. wakes nobody but a budget-exhausting rate does. Then
> percentiles rather than averages, because an average of 199 ms can hide a p99 of ten seconds."*

> **"Walk me through an outage."**
> ⭐ *"Declare early — declaring is cheap, under-declaring is expensive. Name an IC who doesn't type,
> because the moment they start debugging they lose the overview. Comms goes out before we know the
> cause, in user terms not component terms, on a fixed cadence. And the first diagnostic is 'what
> changed?' — activity log and directory audit, writes only, last six hours. Most incidents follow a
> change."*

> **"Your backups are green. Are you protected?"**
> ⭐ *"No — that only proves data was written. I'd want a timed, unannounced restore performed by
> someone who didn't build it, verified by opening named files and checking their dates, with the
> RTO measured from when the incident started rather than from when someone authorised the restore.
> And I'd check immutability is **locked** and multi-user authorisation is on, because otherwise a
> single compromised admin deletes the backups first."*

> **"What would you automate?"**
> ⭐ *"Execution, never judgement. Anything mechanical done more than weekly, moved into Azure
> Automation under a managed identity with a scoped role — that removes the standing admin rights
> the manual procedure was justifying. But every self-healing action increments a counter and
> something alerts on the rate, because a restart runbook that quietly fires three times a day has
> converted a visible failure into an invisible one."*

---

## 13. Where to go deeper

- Standard every topic is written to: [`CONTENT-STANDARD.md`](CONTENT-STANDARD.md)
- Measured state, generated not asserted: [`COVERAGE.md`](COVERAGE.md)
- Full topics: [`35-active-directory-and-hybrid-identity/`](35-active-directory-and-hybrid-identity/) ·
  [`10-networking/`](10-networking/)
- Every topic carries its own **§ Self-test** with answers — use those for spaced repetition
  rather than re-reading the prose.
