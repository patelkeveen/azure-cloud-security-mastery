# Threat Hunting

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> Requires [`../kql/`](../kql/). Uses the tables from [`../sentinel/`](../sentinel/) and
> [`../defender-for-identity/`](../defender-for-identity/).
> **The discipline, not a tool.** Everything here works in any SIEM.

---

## 1. What it is

The **proactive** search for adversary activity that has already evaded your detections, driven by a
hypothesis rather than an alert.

The distinction that matters:

| | Detection | Hunting |
|---|---|---|
| Trigger | An alert fires | **You go looking** |
| Assumes | This behaviour is known-bad | **Something got through** |
| Starts from | A rule | ⭐ **A hypothesis** |
| Success | Alert triaged | **A new detection**, or a documented negative |
| Automatable | Yes — that is the point | No. Automate it and it *becomes* a detection |

> ⭐ **The moment a hunt is fully automated it stops being a hunt and becomes a detection rule.**
> That is not failure — it is the goal. Hunting is the R&D function that produces detections.

---

## 2. Why it exists

Every detection rule encodes **behaviour someone already understood**. By construction, rules cannot
catch what nobody has characterised yet — a novel technique, a living-off-the-land approach using
only signed Microsoft binaries, or an insider whose actions are individually legitimate.

The uncomfortable arithmetic: dwell time is measured in weeks or months in most breaches, and a
large share of intrusions are found by someone *other* than the victim's own tooling. If your
detections were sufficient, that number would be near zero.

**Hunting assumes compromise has already happened and asks where.** That inversion is the whole
mindset, and it is what interviewers are testing when they ask how you would hunt.

---

## 3. The Pyramid of Pain — the model that makes hunting strategic

David Bianco's model, and the single most useful mental tool in this topic. It ranks indicators by
**how much it hurts the adversary when you detect on them**:

```
              ▲  TTPs                    ← TOUGH!      they must relearn their craft
             ╱ ╲ Tools                   ← Challenging  rebuild or buy new tooling
            ╱   ╲ Network/Host Artifacts ← Annoying     re-engineer their kit
           ╱     ╲ Domain Names          ← Simple       register a new one
          ╱       ╲ IP Addresses         ← Easy         change VPS
         ╱_________╲ Hash Values         ← Trivial      recompile, one byte
```

**Hashes and IPs are free for an attacker to change** — that is why an indicator feed goes stale in
days. **TTPs cost them real effort**, because changing how they move laterally means retraining
people and rewriting playbooks.

> ⭐ **Hunt near the top of the pyramid.** "Find this hash" is a lookup, not a hunt. "Find any
> process spawning from Office with an encoded PowerShell command line" survives the attacker
> changing everything below it. This one idea reorganises how you spend hunting time.

---

## 4. The hunting loop

```
1. HYPOTHESIS   "If an attacker did X, I would see Y in data source Z"
        │
2. SCOPE        which tables, what time range, what would normal look like?
        │
3. HUNT         query, pivot, refine
        │
4. TRIAGE       finding, or explainable normal?
        │
5. OUTCOME  ──► found something      → incident + a new detection rule
            ──► found nothing        → ⭐ DOCUMENT IT, and note the visibility gap
            ──► found normal-but-odd → baseline it so next time it is not odd
```

### Writing a hypothesis that is actually testable

| ✗ Not a hypothesis | ✅ A hypothesis |
|---|---|
| "Look for malware" | "If an attacker is using **AS-REP roasting**, I would see Kerberos requests for accounts with pre-auth disabled from a non-admin workstation" |
| "Check for weird logins" | "If credentials were phished, I would see a **successful sign-in from a country with no prior history** for that user, within an hour of a suspicious mail click" |
| "Review service principals" | "If an app registration was backdoored, I would see a **new credential added** to an existing SP, followed by sign-ins from a new IP" |

**The pattern: `If [technique], then [observable] in [data source].`** If you cannot name the data
source, you have found a **visibility gap** — and that is a genuine hunt outcome worth reporting.

---

## 5. ⭐ Stacking — the core technique, and it is counterintuitive

Also called **least-frequency analysis** or long-tail analysis. It is the single most productive
hunting technique and beginners get it backwards.

> **Attackers are rare. So sort ascending, not descending.**

Everyone's instinct is `| sort by Count desc` — which surfaces the noisiest, most normal thing in
the estate. The interesting rows are at the **bottom**.

```kusto
// Hunt: rare parent-child process relationships
DeviceProcessEvents
| where Timestamp > ago(30d)
| summarize Executions  = count(),
            Devices     = dcount(DeviceId),
            FirstSeen   = min(Timestamp),
            Example     = any(ProcessCommandLine)
        by InitiatingProcessFileName, FileName
| where Devices <= 2 and Executions <= 5      // ⭐ the rare tail, not the noisy head
| sort by Executions asc
```

```
InitiatingProcessFileName  FileName          Executions  Devices  FirstSeen
-------------------------  ----------------  ----------  -------  -------------------
winword.exe                powershell.exe             1        1  2026-08-08 14:22:31
outlook.exe                wscript.exe                1        1  2026-08-09 09:11:04
sqlservr.exe               cmd.exe                    2        1  2026-08-07 23:45:12
w3wp.exe                   whoami.exe                 3        1  2026-08-09 16:02:55
```

**Read that output like an analyst.** Every row is suspicious for a reason you can articulate:

- `winword.exe → powershell.exe` — Office spawning a shell. Macro execution.
- `outlook.exe → wscript.exe` — attachment executing a script.
- `sqlservr.exe → cmd.exe` — **`xp_cmdshell`**, i.e. SQL injection reaching the OS.
- `w3wp.exe → whoami.exe` — **a web shell**. IIS does not run `whoami` for business reasons.

None of these would ever appear near the top of a descending sort. All four are near the bottom, and
all four matter.

**Stacking works on almost any dimension:** rarest user agents, rarest scheduled task names, rarest
service names, rarest signing certificates, rarest LDAP query patterns.

---

## 6. Worked example — a complete hunt, hypothesis to detection

**Hypothesis:** *If an attacker has compromised an app registration, they would add a new credential
to an existing service principal and then authenticate with it from unfamiliar infrastructure.*

This targets a technique that generates **no failed logins and no malware** — it is entirely
legitimate API activity, which is why detections rarely cover it.

**Step 1 — find credentials added to service principals:**

```kusto
let lookback = 30d;
AuditLogs
| where TimeGenerated > ago(lookback)
| where OperationName has_any ("Update application", "Update service principal",
                               "Add service principal credentials")
| mv-expand TargetResources
| extend AppName    = tostring(TargetResources.displayName),
         AppId      = tostring(TargetResources.id),
         Actor      = tostring(InitiatedBy.user.userPrincipalName),
         ActorApp   = tostring(InitiatedBy.app.displayName),
         Modified   = tostring(TargetResources.modifiedProperties)
| where Modified has_any ("KeyDescription", "PasswordCredentials", "KeyCredentials")
| project TimeGenerated, AppName, AppId, Actor = coalesce(Actor, ActorApp), Modified
| sort by TimeGenerated desc
```

**Step 2 — pivot: did that app then sign in from somewhere new?** This is the join that makes it a
hunt rather than a report:

```kusto
let credAdds =
    AuditLogs
    | where TimeGenerated > ago(30d)
    | where OperationName has_any ("Update application", "Update service principal")
    | mv-expand TargetResources
    | where tostring(TargetResources.modifiedProperties) has_any ("KeyDescription","PasswordCredentials")
    | project CredAddTime = TimeGenerated,
              AppId = tostring(TargetResources.id),
              AppName = tostring(TargetResources.displayName);
let historicIPs =
    AADServicePrincipalSignInLogs                     // ⭐ NOT SigninLogs
    | where TimeGenerated between (ago(90d) .. ago(30d))
    | summarize KnownIPs = make_set(IPAddress, 200) by ServicePrincipalId;
AADServicePrincipalSignInLogs
| where TimeGenerated > ago(30d) and ResultType == 0
| join kind=inner credAdds on $left.ServicePrincipalId == $right.AppId
| where TimeGenerated > CredAddTime                    // causality: sign-in AFTER the change
| join kind=leftouter historicIPs on ServicePrincipalId
| where isempty(KnownIPs) or IPAddress !in (KnownIPs)  // ⭐ an IP never seen before
| project TimeGenerated, AppName, ServicePrincipalId, IPAddress,
          Country = tostring(LocationDetails.countryOrRegion), CredAddTime
| sort by TimeGenerated asc
```

**Why the clauses matter — this is the transferable part:**

- **`AADServicePrincipalSignInLogs`**, not `SigninLogs`. Workload identities are not in the human
  table, and this is the mistake that makes an entire hunt return nothing.
- **`TimeGenerated > CredAddTime`** enforces causality. Without it you match apps that merely did
  both things in the same month.
- **The 90-to-30-day baseline window** defines "new". A hunt without a baseline cannot say "unusual",
  only "present".

**Step 3 — triage.** Most hits are legitimate: a certificate rotation followed by a deployment from
a new build agent. **Confirm with the app owner** — and if nobody knows who owns it, you have found
the finding from
[`../../30-identity-and-nhi/service-principals/`](../../30-identity-and-nhi/service-principals/):
an unowned service principal nobody can authorise disabling.

**Step 4 — promote to a detection.** Tighten thresholds, add entity mappings, ship it as a Sentinel
rule per [`../sentinel/`](../sentinel/) §4. **The hunt has now paid for itself permanently.**

---

## 7. Hunting the identity kill chain

Reuse what you already know. These map directly onto
[`ad-ds/`](../../35-active-directory-and-hybrid-identity/ad-ds/) §7:

| Hypothesis | Where to look |
|---|---|
| Reconnaissance before escalation | `IdentityQueryEvents` — LDAP/SAMR volume from non-admin hosts |
| Kerberoasting | Service ticket requests for many distinct SPNs by one account, short window |
| AS-REP roasting | Accounts with pre-auth disabled being requested at all |
| DCSync from a non-DC | `IdentityDirectoryEvents` — replication from an unexpected source |
| Golden Ticket | Tickets with anomalous lifetimes or absent issuance events |
| Consent phishing | `AuditLogs` — "Consent to application" by ordinary users, stacked by app, ascending |
| Dormant account revival | Account with no sign-ins for 90 days that suddenly authenticates |

**Dormant-account revival, because it is cheap and effective:**

```kusto
let recent = SigninLogs | where TimeGenerated > ago(7d) and ResultType == 0
             | summarize Recent = count() by UserPrincipalName;
let dormant = SigninLogs | where TimeGenerated between (ago(97d) .. ago(7d))
             | summarize Prior = count() by UserPrincipalName
             | where Prior == 0;
recent | join kind=inner dormant on UserPrincipalName
| project UserPrincipalName, Recent
```

---

## 8. Documenting hunts — including the ones that find nothing

**A hunt that finds nothing is only wasted if it is undocumented.** Record, every time:

```
Hypothesis      : If an attacker backdoored an app registration, ...
Date / Hunter   : 2026-08-10 / K. Patel
Data sources    : AuditLogs, AADServicePrincipalSignInLogs
Time range      : 30d, baselined against 90-30d
Query           : <link to source control>
Result          : 4 hits, all legitimate cert rotations (owners confirmed)
Visibility gaps : ⭐ AADServicePrincipalSignInLogs not collected before 2026-06
Outcome         : Detection rule shipped; gap raised for retention change
Re-run          : quarterly
```

The **visibility gap** line is often the most valuable output of the whole exercise. "We cannot
answer this question" is a finding that justifies budget, and it is the kind of thing a principal
engineer surfaces while everyone else reports "no findings."

---

## 9. What breaks

**No hypothesis.** Browsing dashboards is not hunting. Without a hypothesis there is no way to know
when you are finished.

**Sorting descending.** Surfaces the noisiest normal thing. **Sort ascending.**

**No baseline window.** You can say "this happened", not "this is unusual".

**Hunting only `SigninLogs`.** Misses every workload identity.

**Hunting the bottom of the pyramid.** Hash and IP hunts expire in days.

**Not enforcing causality.** Two events in the same month is not a sequence.

**Never promoting findings to detections.** The same hunt gets re-run forever by hand.

**Discarding negative results.** The visibility gap goes unrecorded and is rediscovered next year.

**Retention shorter than the baseline window.** A 90-day baseline needs 90 days of data — check
before designing the hunt, not after writing the query.

---

## 10. Customer discovery questions

1. Is there a hunting programme, or only alert triage?
2. Are hypotheses written down, and are hunts repeatable from source control?
3. Are **negative results and visibility gaps** recorded?
4. How many detections originated from hunts in the last year? *(The honest measure of maturity.)*
5. Is retention long enough to baseline? What is the longest answerable question?
6. Are workload identity logs collected and hunted?
7. Is hunting mapped to **MITRE ATT&CK**, and where is coverage thinnest?
8. Who hunts, and is time actually protected for it — or does triage always win?

---

## 11. Remember it

**Hook — "Sort ascending."** Attackers are rare; the interesting rows are in the tail, not the head.
And **"If [technique], then [observable] in [data source]."**

**Analogy — the Pyramid of Pain, or: fingerprints versus method.** Catching a burglar by their
fingerprints means they wear gloves tomorrow — cost to them, near zero. Catching them because they
*always* enter through a first-floor bathroom window at 3am means they must learn a new trade.
**Hashes and IPs are gloves. TTPs are the trade.** Hunt the trade.

**The one thing:** the moment a hunt is fully automated it **becomes a detection** — and that is the
point, not a failure. Hunting is the R&D function that manufactures detections, which is why
"how many detections came from hunts last year?" is the only honest maturity metric.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 12. Self-test

1. Difference between hunting and detection, in one sentence?
2. Why sort ascending rather than descending?
3. What does `w3wp.exe → whoami.exe` almost certainly indicate?
4. Where should you hunt on the Pyramid of Pain, and why?
5. Turn "check for weird logins" into a testable hypothesis.
6. Why is a hunt that finds nothing still valuable?
7. Which table do you need for workload identity hunting, and what happens if you forget?
8. Why does a hunt need a baseline window separate from the hunt window?
9. What is the honest measure of a hunting programme's maturity?
10. What happens when a hunt is fully automated?

<details>
<summary>Answers</summary>

1. Detection waits for known-bad to fire; hunting **assumes something already got through** and goes
   looking, driven by a hypothesis.
2. **Attackers are rare.** Descending surfaces the noisiest normal activity; the findings are in the
   long tail.
3. **A web shell.** IIS worker processes have no business running `whoami`.
4. **Near the top — TTPs.** Hashes and IPs cost an adversary nothing to change, so detections built
   on them expire within days.
5. e.g. "If credentials were phished, I would see a successful sign-in from a country with no prior
   history for that user within an hour of a suspicious mail click, in `SigninLogs`."
6. It records a **visibility gap** and narrows the search space. "We cannot answer this question" is
   a finding that justifies budget.
7. **`AADServicePrincipalSignInLogs`.** Forget it and the hunt returns nothing while appearing to work.
8. Without a baseline you can only say something **happened**, not that it is **unusual**.
9. **How many detections originated from hunts** in the past year.
10. It **becomes a detection rule** — which is the goal.

</details>

---

## 13. Evidence this topic needs

- **`lab/`** — run the §5 stacking query and the §6 hunt end to end; document both, including
  negative results. ✗ Needs populated logs — the read-only Cobuman tenant is genuinely useful here.
- **`break-fix/`** — run the §6 hunt against `SigninLogs` instead of
  `AADServicePrincipalSignInLogs`, get zero rows, and document why an empty result was not a clean
  bill of health. **That is the most instructive mistake in this topic.**
- **`security/`** — a hunt log with hypotheses, outcomes and visibility gaps; MITRE coverage map
  showing where hunting is thinnest.
- **`operations/`** — hunt queries in source control; a re-run cadence per hypothesis.
- **`architecture-decisions/`** — ADR: retention required to support the baseline windows the
  hunting programme depends on.
- **`customer-use-cases/`** — §10 answered against a real SOC.
