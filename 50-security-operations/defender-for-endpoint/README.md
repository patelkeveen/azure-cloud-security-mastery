# Microsoft Defender for Endpoint (MDE)

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (overview updated 2026-07-28, ASR 2026-06-25).
> The endpoint pillar of Defender XDR. Hunt with [`../kql/`](../kql/); correlates with
> [`../defender-for-identity/`](../defender-for-identity/) and [`../sentinel/`](../sentinel/).

---

## 1. What it is

An endpoint security platform that **prevents**, **detects**, **investigates** and **responds** —
four verbs, four distinct subsystems. Most people know it as "the EDR" and see only the third.

It runs on **Windows, macOS, Linux, Android and iOS** ✅ — but capability is not equal across them,
and that asymmetry is the single most common planning error (§4).

---

## 2. Why it exists

Signature antivirus answers *"have I seen this exact file before?"* Modern intrusions are built to
make that question useless:

- **Living off the land** — the attacker uses `powershell.exe`, `certutil.exe`, `wmic.exe`. Every
  binary is signed by Microsoft. There is no malicious file to sign.
- **Fileless** — the payload never touches disk; it lives in memory or the registry.
- **Novel or recompiled** — one byte changed defeats a hash, per the Pyramid of Pain in
  [`../threat-hunting/`](../threat-hunting/) §3.

**EDR answers a different question: *what did this process do?*** `winword.exe` spawning
`powershell.exe` with an encoded command is suspicious regardless of whether any file is malicious —
and it is suspicious *forever*, because the technique cannot change without the attacker changing
trade.

---

## 3. How it works underneath — five layers, in the order they act

```
① ATTACK SURFACE REDUCTION   prevent the behaviour ever being possible
② NEXT-GEN PROTECTION        AV + cloud-delivered + behavioural blocking
③ EDR                        record everything; detect patterns; alert
④ AUTO-INVESTIGATION         triage and remediate without a human
⑤ ATTACK DISRUPTION          ⭐ autonomous containment mid-attack
```

**The layers are ordered by cost.** Layer ① is free at run time and prevents whole classes of
attack; layer ⑤ is a last resort that isolates a machine while an attack is underway. Organisations
that deploy only ② and ③ have bought an expensive alarm and left the ladder against the wall.

**Automatic attack disruption** ✅ is the capability worth understanding: when high-confidence
signals correlate across endpoint, identity and email, Defender acts *during* the attack —
containing a device or suspending an account — rather than waiting for an analyst. **Predictive
shielding** extends this preventively. ⚠ Both are evolving; verify current triggers and scope before
promising specific behaviour to a customer.

---

## 4. ⭐ Attack surface reduction — and the platform table nobody reads

ASR is a **set of capabilities**, not one feature ✅:

| Capability | What it stops |
|---|---|
| **ASR rules** | Risky software behaviour — Office spawning children, obfuscated scripts, credential theft from LSASS |
| **Controlled folder access** | Ransomware modifying protected folders |
| **Exploit protection** | Memory-corruption exploitation (the EMET successor) |
| **Network protection** | Connections to low-reputation domains and IPs |
| **Web protection / content filtering** | Web threats, and category-based blocking |
| **Device control** | USB and peripheral use — data loss and malware from removable media |
| **Network firewall reporting** | Central visibility of Windows Firewall events |

**Now the part that changes designs** ✅ verified 2026-08-10:

| Feature | Windows | macOS | Linux |
|---|:---:|:---:|:---:|
| **ASR rules** | ✅ | ❌ | ❌ |
| **Controlled folder access** | ✅ | ❌ | ❌ |
| **Exploit protection** | ✅ | ❌ | ❌ |
| Network protection | ✅ | ✅ | ⚠ preview |
| Web protection | ✅ | ✅ | ⚠ preview |
| Web content filtering | ✅ | ✅ | ✅ |
| Device control | ✅ | ✅ | ❌ |
| Firewall reporting | ✅ | ❌ | ❌ |

> ⭐ **The three highest-value preventive controls — ASR rules, controlled folder access and exploit
> protection — are Windows-only.** A hardening standard written as "we enforce ASR everywhere" is
> false the moment there is a Mac or a Linux server in the estate. Knowing this table stops you
> promising something you cannot deliver, which is exactly the sort of detail a customer remembers.

**Related but separately managed** — these are *not* MDE features and are configured elsewhere:
**Application Guard**, **Windows Defender Application Control (WDAC)**, and **Windows Firewall**.

---

## 5. ⭐ Audit mode first — and the pattern this repeats

**Audit mode** ✅ is supported for ASR rules, controlled folder access, exploit protection and
network protection. Nothing is blocked; Windows logs what *would* have happened.

```
Deploy in AUDIT → hunt the events → find the line-of-business breakage → exclude → THEN block
```

Skip it and you will block a genuine business process on day one. The organisation will not conclude
that the rule was untuned — it will conclude that endpoint security breaks things, and your next
three proposals will be refused.

> **This is the same pattern you have now met four times in this repo, and naming it is the
> fellow-level observation:**
>
> | Control | Audit step first |
> |---|---|
> | LDAP signing enforcement | Hunt **Event 2889** for unsigned binds |
> | SOAR playbooks | Notification and enrichment before remediation |
> | Conditional Access | **Report-only mode** before enforcement |
> | **ASR rules** | **Audit mode** before block |
>
> **Every enforcement control in the Microsoft stack has a "watch first" mode, and the seniority
> test is whether you use it.** Junior engineers enable the control; senior engineers measure the
> blast radius, then enable the control. It is the same instinct as
> [`feedback: measure before changing`] applied to security.

**Find what audit mode caught:**

```kusto
DeviceEvents
| where TimeGenerated > ago(30d)
| where ActionType startswith "Asr"
| summarize Events = count(), Devices = dcount(DeviceId),
            Files = make_set(InitiatingProcessFileName, 10)
        by ActionType
| sort by Devices desc
```

`ActionType` ending in `Audited` is what *would* have been blocked. **Anything with a high device
count is a line-of-business process you are about to break** — investigate before switching to block.

---

## 6. Worked example — hunting and responding on the endpoint

**The stacking hunt from [`../threat-hunting/`](../threat-hunting/) §5 runs against MDE tables.**
The key ones:

| Table | Contains |
|---|---|
| `DeviceProcessEvents` | Process creation — parent/child, command lines |
| `DeviceNetworkEvents` | Outbound connections |
| `DeviceFileEvents` | File creation and modification |
| `DeviceLogonEvents` | Logons seen at the endpoint |
| `DeviceRegistryEvents` | Registry changes — persistence |
| `DeviceEvents` | Mixed security events, including ASR |

**Credential theft — the highest-signal endpoint hunt:**

```kusto
DeviceProcessEvents
| where Timestamp > ago(7d)
| where ProcessCommandLine has_any ("lsass", "sekurlsa", "comsvcs.dll", "MiniDump")
    or (FileName =~ "rundll32.exe" and ProcessCommandLine has "comsvcs")
| project Timestamp, DeviceName, AccountName, FileName, ProcessCommandLine,
          InitiatingProcessFileName
| sort by Timestamp desc
```

`rundll32.exe comsvcs.dll MiniDump` is **LSASS dumping using a signed Microsoft binary** — no
malware, no file on disk to detect, and the single most common credential-theft technique. It leads
directly to the attacks in
[`ad-ds/`](../../35-active-directory-and-hybrid-identity/ad-ds/) §7.

**Beaconing — steady-interval outbound traffic to one destination:**

```kusto
DeviceNetworkEvents
| where Timestamp > ago(3d) and ActionType == "ConnectionSuccess"
| where RemoteIPType == "Public"
| summarize Connections = count(), Devices = dcount(DeviceId),
            Interval = avg(datetime_diff('second', Timestamp, prev(Timestamp)))
        by RemoteUrl, InitiatingProcessFileName
| where Connections > 100 and Devices <= 2          // ⭐ rare AND frequent = suspicious
| sort by Connections desc
```

> **Rare *and* frequent is the beaconing signature.** Normal software is either common across many
> devices, or infrequent. Something talking constantly from only one machine is either a bespoke
> business tool — or an implant.

**Response actions:**

```
Isolate device        ← network isolation; Defender itself keeps communicating
Restrict app execution ← only Microsoft-signed binaries may run
Run antivirus scan
Collect investigation package
Live Response          ⭐ an interactive shell on the endpoint
```

**Live Response** is the one to understand. It gives an authenticated remote shell — `getfile`,
`putfile`, `processes`, `run <script>` — for evidence collection without touching the machine
physically. **It is also, by construction, remote code execution as SYSTEM across the fleet.** Who
holds that role is a Tier 0 question, and it is rarely asked.

---

## 7. Licensing — and what it means for you

✅ Verified: Defender for Endpoint comes as **Plan 1**, **Plan 2**, or **Defender for Business**.
**Microsoft 365 E5 and Microsoft 365 E5 Security include Plan 2.**

**Roughly:** P1 gives you the preventive layers (next-gen protection, ASR, device control) and
manual response. **P2 adds EDR, automated investigation, threat hunting and vulnerability
management** — i.e. everything in §5 and §6.

> ⚠ **Office 365 E5 does not include Defender for Endpoint.** This is now the *third* capability
> blocked on your `Kev@KWin.onmicrosoft.com` tenant, alongside Entra ID P2 and Defender for
> Identity. Unlike those two, **EMS E5 does not fix this one** — MDE P2 needs M365 E5 / E5 Security
> or a standalone plan. Worth knowing before you plan labs around it.

If Defender for Servers is also in play, a licensing discount may apply — check rather than assume.

---

## 8. What breaks

**ASR rules in block mode without audit first.** Broken line-of-business apps, and lost credibility.

**Assuming ASR everywhere.** It is Windows-only. §4.

**Onboarding without offboarding hygiene.** Stale devices inflate exposure scores and make coverage
reporting meaningless.

**Third-party AV left in active mode.** Defender AV drops to passive and several capabilities
degrade; teams then report MDE "not working."

**Exclusions copied from a legacy AV product.** Broad path exclusions become the attacker's safe
harbour — and they are inherited without review for years.

**Live Response ungoverned.** Remote SYSTEM execution across the fleet with no approval trail.

**Hunting only endpoint tables.** The endpoint sees process and network activity, not what the
identity did in the cloud. Correlate — that is the point of XDR.

**Tamper protection off.** Attackers disable the sensor first; tamper protection is what stops them.

---

## 9. Customer discovery questions

1. What is onboarding **coverage** — devices onboarded versus devices that exist?
2. Are ASR rules in **block** or **audit**, and which specific rules?
3. Was audit data reviewed before blocking, and what exclusions came out of it?
4. Is **tamper protection** enabled?
5. Is another AV product in active mode anywhere?
6. What **exclusions** exist, who approved them, and when were they last reviewed?
7. Who can run **Live Response**, and is it logged and approved?
8. Is P1 or P2 deployed — do you actually have EDR and automated investigation?
9. For macOS and Linux estates, what compensates for the Windows-only controls?
10. Is automatic attack disruption enabled, and does anyone know what it is authorised to do?

---

## 10. Remember it

**Hook — "Audit before block."** And the five layers in cost order: **ASR → NGP → EDR →
auto-investigation → attack disruption.**

**Analogy — the ladder and the alarm.** Next-gen protection and EDR are the alarm: they tell you
someone is climbing in. **ASR removes the ladder.** Most organisations buy an expensive alarm and
leave the ladder against the wall, because prevention is invisible when it works and detection
produces satisfying dashboards.

**The one thing:** **every enforcement control in this stack has a "watch first" mode** — ASR audit
mode, Conditional Access report-only, LDAP Event 2889, SOAR notification-before-remediation. Junior
engineers enable the control; senior engineers **measure the blast radius, then** enable it. That
one habit, applied everywhere, is most of what separates the two.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 11. Self-test

1. Why does signature AV fail against living-off-the-land attacks?
2. Name the five layers in the order they act, and which is cheapest.
3. Which three ASR capabilities are **Windows-only**, and why does it matter?
4. What must you do before switching ASR rules to block, and what happens if you skip it?
5. What does `rundll32.exe comsvcs.dll MiniDump` indicate?
6. What is the beaconing signature in `DeviceNetworkEvents`?
7. Why is Live Response a Tier 0 concern?
8. Does Office 365 E5 include MDE? Does EMS E5 fix it?
9. Third-party AV is active. What happens to Defender AV?
10. Name four Microsoft controls that all have a "watch first" mode.

<details>
<summary>Answers</summary>

1. The binaries are legitimate and Microsoft-signed — `powershell.exe`, `certutil.exe`. There is no
   malicious file to match. **EDR asks what the process did**, not what it is.
2. **ASR → next-gen protection → EDR → automated investigation → attack disruption.** ASR is
   cheapest, because prevented attacks cost nothing at run time.
3. **ASR rules, controlled folder access, exploit protection.** A hardening standard claiming
   "ASR everywhere" is false in any estate containing macOS or Linux.
4. Run them in **audit mode**, hunt the events, exclude genuine business processes. Skipping it
   breaks production and costs you organisational trust in endpoint security.
5. **LSASS credential dumping using a signed Microsoft binary** — no malware, no dropped file.
6. **Rare and frequent** — high connection count from very few devices to one destination.
7. It is an authenticated remote shell running as **SYSTEM** across the fleet — remote code
   execution by design.
8. **No.** And **EMS E5 does not fix it** — MDE P2 requires M365 E5 / E5 Security or a standalone plan.
9. Defender AV drops to **passive mode** and several capabilities degrade — commonly misreported as
   "MDE isn't working."
10. **ASR audit mode**, **Conditional Access report-only**, **LDAP signing Event 2889 auditing**,
    **SOAR notification-before-remediation**.

</details>

---

## 12. Evidence this topic needs

- **`lab/`** — onboard a device; enable ASR rules in **audit**; run the §5 query to see what would
  have been blocked; run the §6 credential-theft hunt. ✗ Requires MDE P2 — blocked on the current
  tenant.
- **`break-fix/`** ⭐ — enable a strict ASR rule in **block** mode against a machine running a
  legitimate script-based business process, break it, then recover via audit-derived exclusions.
  **That failure teaches the §5 pattern permanently.**
- **`security/`** — onboarding coverage versus asset inventory; exclusion register with owners and
  review dates; tamper protection confirmed; Live Response role membership.
- **`operations/`** — ASR rollout plan by ring with audit evidence per ring.
- **`architecture-decisions/`** — ADR: compensating controls for macOS and Linux where the
  Windows-only capabilities do not reach.
- **`customer-use-cases/`** — §9 answered against a real estate.
