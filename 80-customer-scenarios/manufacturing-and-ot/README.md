# Manufacturing and Operational Technology

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **Boundary:** [`../LAYER-7-INDUSTRY-VERTICALS.md`](../LAYER-7-INDUSTRY-VERTICALS.md) §5 is the
> brief. ⭐ **This is engagement depth — and the vertical where the security priorities you learned
> are in the wrong order.** Pairs with
> [`../../10-networking/peering-and-hub-spoke/`](../../10-networking/peering-and-hub-spoke/).

---

## 1. What it is

Identity and access engineering where the systems being protected are **physical**: production
lines, PLCs, SCADA, robots, building management. IT security meets **operational technology**, and
OT has different priorities, different lifetimes, and things that can injure people.

⭐ **You are not there to secure the PLC. You are there to control who reaches it, from where, and
with what evidence** — because the PLC itself usually cannot be secured at all.

---

## 2. ⭐ Why it is different — the triad is inverted

```
   ⭐ IT PRIORITY                       ⭐ OT PRIORITY
   ─────────────                       ─────────────
   1  Confidentiality                  1  ⭐ SAFETY      ⭐ people can be injured
   2  Integrity                        2  AVAILABILITY  ⭐ the line must run
   3  Availability                     3  Integrity
                                       4  ⭐ Confidentiality  ⭐ ← LAST
```

⭐ **A control that risks stopping the line will be refused, and the refusal is correct.** An
unplanned stop on a continuous process can cost more in one hour than the entire security budget —
and on some plants, an uncontrolled stop is a **safety** event, not a financial one.

| IT assumption | ⭐ OT reality |
|---|---|
| Patch monthly | ⭐ **patch window is one weekend a year**, if that |
| Reboot to apply | ⭐ **a reboot is a production outage** |
| Hardware refreshed every 4 years | ⭐ **20–30 year lifetimes** — ⭐ Windows XP HMIs are real |
| Everyone has an account | ⭐ **shared operator account is the design**, not laziness |
| MFA everywhere | ⭐ **a PLC cannot do MFA. Ever.** |
| Vendor support by ticket | ⭐ **vendor needs remote access at 02:00 or the line stays down** |

⭐ **The shared operator account is worth understanding rather than condemning.** ⭐ **In an
emergency, an operator must reach the HMI immediately — a locked screen and a forgotten password
during a process upset is a safety hazard.** The answer is not individual logins at the panel; it is
⭐ **physical access control plus compensating monitoring**, and saying so demonstrates you
understand the plant.

---

## 3. How it works underneath — the Purdue model, and where identity lives

```
  ⭐ LEVEL 5  Enterprise IT        ⭐ Entra, M365, ERP        ⭐ ← your usual world
  ⭐ LEVEL 4  Site business        MES, plant scheduling
  ═══════════ ⭐ DMZ / conduit ══════ ⭐ THE BOUNDARY YOU DEFEND ═══════════
     LEVEL 3  Site operations      historians, engineering workstations
     LEVEL 2  Supervisory          ⭐ SCADA, HMI
     LEVEL 1  Control              ⭐ PLCs, RTUs
     LEVEL 0  Process              ⭐ sensors, actuators  ⭐ ← physical reality
```

⭐ **Identity work happens at Levels 5, 4 and 3 — and at the DMZ.** ⭐ **Below Level 3 there is
frequently no identity at all**: a PLC authenticates nothing, an HMI has one shared login, and the
protocol has no concept of a user.

⭐ **So the control is the *path*, not the endpoint.** ⭐ **You cannot authenticate to the PLC, so you
authenticate to the only route that reaches it** — and you make sure there is only one route.

⭐ **IEC 62443** is the OT security standard to know by name (zones and conduits), and ⭐ **NIS2** is
the EU regulation that has pulled many manufacturers into scope. ⚠ Verify current transposition and
applicability per member state.

---

## 4. Worked example — ⭐ third-party vendor remote access

⭐ **This is the highest-risk, highest-value identity problem in the vertical**, and it is the one
you are most likely to be asked to fix.

```
⭐ WHAT YOU WILL FIND

  Robot vendor needs to diagnose a fault at 02:00.
  Today:  ⭐ a TeamViewer instance on the engineering workstation,
          ⭐ installed in 2019, ⭐ password shared by email,
          ⭐ always on, ⭐ no logging, ⭐ nobody knows it is there.

  ⭐ It bypasses the DMZ entirely. ⭐ It is a permanent inbound path
     from the internet to Level 3.
```

⭐ **Every element of that is real and typical.** ⭐ **The vendor is not the adversary; the
always-on, unlogged, un-owned path is** — and it exists because the alternative (a ticket at 02:00
with the line down) was unworkable.

**The design that replaces it, and why each part is there:**

```
① IDENTITY      ⭐ vendor engineer gets a B2B guest in the enterprise tenant
                ⭐ NOT a shared local account, ⭐ NOT a shared password

② TIME-BOUND    ⭐ entitlement management access package
                ⭐ expiry: 8 hours · ⭐ requires approval · ⭐ justification recorded

③ STRONG AUTH   ⭐ Conditional Access: phishing-resistant MFA + named location
                ⭐ + no persistent session

④ PATH          ⭐ access to a JUMP HOST at Level 3 only
                ⭐ never a route to Level 2 or below
                ⭐ (Global Secure Access / Private Access instead of a VPN
                   ⭐ that would grant the whole network)

⑤ EVIDENCE      ⭐ session recorded · ⭐ sign-in logged · ⭐ access auto-expires
                ⭐ + review of what they did
```

⭐ **Step ④ is the one that matters most architecturally.** ⭐ **A VPN grants network access; an
identity-aware proxy grants *application* access** — which means the vendor reaches one jump host
rather than everything the VPN's route table can see. ⭐ **That difference is the entire modern case
against flat VPN access for third parties.**

**The check you run to find the accounts nobody owns:**

```powershell
# ⭐ Guests who have never signed in, or have not signed in for 90 days
$cut = (Get-Date).AddDays(-90)
Get-MgUser -All -Filter "userType eq 'Guest'" `
  -Property Id,UserPrincipalName,CreatedDateTime,SignInActivity |
  Select-Object UserPrincipalName, CreatedDateTime,
    @{n='LastSignIn';e={$_.SignInActivity.LastSignInDateTime}} |
  Where-Object { -not $_.LastSignIn -or $_.LastSignIn -lt $cut }
```

```
UserPrincipalName                         CreatedDateTime  LastSignIn
svc.robotvendor_ext#EXT#@contoso...       2019-04-11
maint.contractor_ext#EXT#@contoso...      2023-08-02       2024-11-14
```

⭐ **A vendor guest created in 2019 that has never signed in is not harmless — it is an unowned
credential with a live invitation.** ⭐ **And the second row is a contractor whose engagement ended
in 2024 and whose access did not.** Both are findings you can produce in the first hour.

---

## 5. Design reference

| Control | Setting | ⭐ OT reason |
|---|---|---|
| ⭐ Vendor access | ⭐ **B2B + access package, 8 h expiry, approval** | ⭐ replaces the always-on tool |
| ⭐ Path | ⭐ **jump host at Level 3 only**, identity-aware | ⭐ never a flat network route |
| Engineering workstations | ⭐ managed, ⭐ compliant-device required | the real entry point to OT |
| ⭐ Shared HMI accounts | ⭐ **accept them**; compensate with physical + monitoring | ⭐ safety overrides |
| ⭐ Legacy auth | ⭐ **measure before blocking** | ⭐ a historian may depend on it |
| Change | ⭐ OT change windows, ⭐ annual not monthly | [`../../70-operations-and-reliability/change-management/`](../../70-operations-and-reliability/change-management/) |
| Monitoring | ⭐ sign-ins to the jump host, ⭐ alert on out-of-hours | detection replaces prevention |

⭐ **"Measure before blocking" is not optional here.** ⭐ **Blocking legacy authentication in an
office is a Tuesday; doing it at a plant can stop a historian ingesting process data**, and the
consequence is a production and possibly a regulatory reporting gap. ⭐ **Run the usage query, name
every affected system, and get the owner's sign-off in writing.**

⭐ **Detection replaces prevention wherever prevention would risk availability** — and that is a
legitimate, defensible security position in OT, not a compromise you should be embarrassed by. ⭐ **A
control you cannot deploy protects nothing; a monitor you can deploy at least tells you.**

---

## 6. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| ⭐ Security proposal refused outright | ⭐ risks stopping the line | ⭐ lead with safety and availability |
| ⭐ Unknown remote-access tool found | ⭐ vendor need not met legitimately | ⭐ replace it, do not just remove it |
| Legacy auth block halts a historian | not measured first | ⭐ measure, name the systems, get sign-off |
| ⭐ Vendor guest from 2019 still live | ⭐ no expiry, no owner | ⭐ access packages with expiry |
| Compliant-device policy blocks an HMI | ⭐ device cannot be managed | ⭐ exclude by object, ⭐ with a review date |
| ⭐ CMMC obligations discovered late | ⭐ defence contract in the supply chain | ⭐ ask early — [`../government/`](../government/) §3 |
| Patch demanded, refused | ⭐ annual window | ⭐ compensating controls, documented |

⭐ **"Replace it, do not just remove it" is the sentence that makes you welcome on a plant.**
⭐ **Deleting the vendor's remote-access tool without providing a working alternative guarantees it
reappears within a month, better hidden** — because the 02:00 fault has not gone away. ⭐ **Solve the
need, then remove the tool.**

---

## 7. Customer discovery questions

1. ⭐ **"How does your equipment vendor connect when a line is down at 2 a.m.?"**
2. ⭐ **"What is the cost of one hour of unplanned downtime?"** (⭐ it reframes every risk conversation)
3. "How many engineering workstations are there, and are they domain-joined?"
4. ⭐ **"When is your maintenance window, and how long is it?"**
5. "What is the oldest operating system still in production, and what runs on it?"
6. ⭐ **"Do you hold any defence contracts?"** (⭐ CMMC reaches the supply chain)
7. ⭐ **"Who owns the boundary between IT and OT — and do they agree they own it?"**

⭐ **Question 7 finds the organisational gap that produces most OT incidents.** ⭐ **IT believes OT
owns the plant network; OT believes IT owns anything with an IP address; the DMZ belongs to
nobody** — and unowned infrastructure does not get patched, monitored or reviewed.

---

## 8. Remember it

**Hook — ⭐ `S A I C`: Safety, Availability, Integrity, Confidentiality.** ⭐ **The IT triad, upside
down.**

**Analogy — securing a hospital's operating theatre versus its records office.** ⭐ **In the records
office you lock the door and require a badge. In the theatre, a door that fails locked during
surgery kills someone — so you control who is in the building, log who entered the corridor, and
leave the theatre door itself openable.** The analogy predicts the whole design: ⭐ **you secure the
path rather than the endpoint**, ⭐ **you accept the shared account at the panel because the
alternative is a safety hazard**, and ⭐ **detection replaces prevention exactly where prevention
would be dangerous.**

**The one line:** ⭐ **You cannot authenticate the PLC, so authenticate the only path that reaches
it — and never remove a vendor's access route without replacing the capability.**

---

## 9. Self-test

1. State the OT priority order and why it differs.
   → ⭐ Safety, Availability, Integrity, Confidentiality — physical processes can injure people and stopping the line is costly or unsafe.
2. Where does identity work actually happen in the Purdue model?
   → ⭐ Levels 5, 4, 3 and the DMZ. Below Level 3 there is often no identity at all.
3. Why is a shared HMI account defensible?
   → ⭐ A locked screen during a process upset is a safety hazard; compensate with physical control and monitoring.
4. What is wrong with a VPN for vendor access?
   → ⭐ It grants network reach; an identity-aware proxy grants access to one application/jump host.
5. Why measure legacy authentication before blocking it here?
   → ⭐ A historian or SCADA component may depend on it; the failure is a production and reporting gap.
6. Why does removing a vendor's remote-access tool fail?
   → ⭐ The 02:00 need remains; it reappears better hidden. Replace the capability first.
7. Which framework reaches manufacturers unexpectedly?
   → ⭐ CMMC, via the defence supply chain.

---

## 10. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | ⭐ the stale-guest query, identifying unowned vendor accounts |
| `security` | ⭐ the vendor access package: expiry, approval, and one expired grant |
| `operations` | the legacy-auth usage measurement, with affected systems named and signed off |
| `break-fix` | one unmanaged remote-access tool found, and the replacement design |
| `architecture-decisions` | ⭐ the accepted shared-account risk, with compensating controls and a review date |
