# Lab — Respond to an incident end to end, and prove you contained it

**Exam:** SC-200, *Respond to security incidents* (35–40%).
**Tenant needed:** yes. **Before 2026-09-10** — this is the group that most needs a live
tenant, because an incident queue cannot be simulated on paper.

You finish able to take an incident from queue to closed with evidence at each step, and
to say what containment actually stopped.

---

## 0. Setup

You need at least one alert. Two honest ways to get one:

1. **Defender for Endpoint evaluation** — Microsoft's own simulation, in
   **Defender portal → Endpoints → Evaluation & tutorials**. Safe, self-contained,
   generates a real multi-stage incident.
2. **Your own analytic** from the Sentinel lab, triggered by six failed sign-ins.

Do **not** run real malware, and do not run offensive tooling against anything you do
not own. The simulation exists precisely so you do not have to.

---

## 1. Triage — read the incident before touching it

Open the incident and answer these before you click anything:

| Question | Where the answer is |
| --- | --- |
| What fired, and which detection produced it? | Incident → Alerts tab |
| Which entities are involved? | Entities tab — accounts, devices, IPs, files |
| Is this one alert or a correlated set? | Alert count; XDR correlates across products |
| What does the attack story look like? | Attack story / investigation graph |
| Has automated investigation already acted? | Investigations tab, and Action center |

⭐ **Check the Action center first.** Automated investigation and response may already
have quarantined a file or suspended an account. Acting again without checking is how
you produce a second, confusing incident — and how you tell an auditor you did something
the system had already done.

---

## 2. The distinction the exam turns on

| Term | Means | Reverses? |
| --- | --- | --- |
| **Isolate device** | Cuts network except the Defender connection | Yes — release from Action center |
| **Restrict app execution** | Only Microsoft-signed binaries may run | Yes |
| **Contain user** *(attack disruption)* | Blocks the identity's lateral movement | Yes |
| **Collect investigation package** | Pulls forensic artefacts off the device | Read-only |
| **Live response** | Interactive shell on the device | Depends what you run |
| **Automatic attack disruption** | XDR acts on its own, mid-attack, at high confidence | Yes, from Action center |

**Automatic attack disruption is on the blueprint twice** — under Defender XDR and
again under Defender for Endpoint. It is the feature that contains an attack *while it
is running*, without waiting for an analyst. Know that it exists, that it is high
confidence only, and that everything it does is reversible from the Action center.

---

## 3. Act, and record the timestamp

On the affected device:

```
Defender portal → Devices → <device> → Isolate device
  Reason: "SC-200 lab containment test, 2026-08-29"
```

Then, before releasing it, collect the package:

```
Devices → <device> → Collect investigation package
```

Expected: a download link appears in **Action center → History**, typically within a few
minutes. It contains autoruns, installed programs, network connections, prefetch,
scheduled tasks, services, SMB sessions, temp files and the event logs.

**Note both timestamps.** Time-to-contain is the number a SOC is measured on, and you
cannot report it later if you did not write it down.

---

## 4. Live response — one real command

```
Devices → <device> → Initiate live response session
```

```
getfile C:\Windows\System32\drivers\etc\hosts
processes
connections
```

Expected shape from `connections`: a table of local/remote address, port, state and
owning process.

If live response is unavailable, that is itself the finding — it must be **turned on in
Advanced features**, and the device must have a recent enough agent. Record the exact
message.

---

## 5. Deliberate failure — respond in the wrong console

Try to isolate the device from **Microsoft Sentinel** rather than the Defender portal.

You will find you cannot, unless a **playbook** exists that calls the Defender API on
your behalf. Sentinel is the SIEM — correlation, incidents, automation — while the
response *actions* on an endpoint live in Defender XDR. Sentinel reaches them through a
playbook, not directly.

This is a real architectural boundary and the exam tests it. Record what the UI did and
did not offer.

---

## 6. Purview, for the M365 half

The blueprint's third sub-group is *"Investigate Microsoft 365 activities to identify
threats."*

```powershell
Connect-ExchangeOnline -Device      # -Device: WAM fails on this laptop
Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date) `
  -Operations UserLoggedIn -ResultSize 20 |
  Select-Object CreationDate, UserIds, Operations
```

If this returns nothing, **check the Purview portal's Audit banner** before debugging
PowerShell. On trial tenants auditing is not on by default, and the PowerShell path
dead-ends: the proxy throws `InvalidOperationInDehydratedContextException` telling you
to run `Enable-OrganizationCustomization`, while `Get-OrganizationConfig` reports
`IsDehydrated: False` and that cmdlet says it is already enabled. Turn it on in the
portal, then prove capture with a search — a configuration flag records intent, only a
search records capture.

Reading `Search-UnifiedAuditLog` also needs the **Audit Logs** role in Exchange Online,
which Global Administrator does not imply.

---

## 7. Close it properly

Close the incident with a **classification** — True positive / Informational, expected
activity / False positive — and a comment saying what you did and what contained it.

Then read your own comment back and ask whether a colleague could reconstruct the
timeline from it alone. If not, it is a status change, not an investigation record.

---

## 8. Verification — you have finished when

- [ ] You checked the Action center **before** acting, and know whether AIR had already moved
- [ ] A device was isolated and released, both timestamps recorded
- [ ] An investigation package downloaded, and you can name three things inside it
- [ ] You ran at least one live response command and read its output
- [ ] You can state why Sentinel cannot isolate a device on its own
- [ ] `Search-UnifiedAuditLog` returned rows, or you recorded exactly why it did not
- [ ] The incident is closed with a classification and a reconstructable comment

---

## 9. Evidence

Into `50-security-operations/incident-response/lab/evidence/`:

| Artifact | Note |
| --- | --- |
| Incident timeline screenshot with entities | Dies with the trial on 10 Sep |
| Action center history showing isolate → release | Your time-to-contain proof |
| Investigation package file listing | Not the package itself — it is large and holds real host data |
| Verbatim error from §5 and §6 | Cannot be reconstructed once auditing is on |
| Your closing comment | The thing an interviewer will actually ask to see |

---

## 10. Cleanup

- **Release the device from isolation.** An isolated device stays isolated.
- Undo any live response change you made.
- Close every incident you raised, so the queue is not left dirty.
- Leave unified audit logging **on** — it is forward-only, so turning it off costs you
  data you cannot get back.

---

## Remember it

**Triage, contain, investigate, eradicate, close — and check what the machine already
did before you do it again.**

The line that regenerates the topic: *Sentinel correlates and automates; Defender XDR
acts on the endpoint and the identity; Purview holds what happened in M365. An incident
crosses all three, and knowing which console owns which verb is most of the exam.*
