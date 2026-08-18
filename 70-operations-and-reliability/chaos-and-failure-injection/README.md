# Chaos and Failure Injection

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Every runbook, failover and backup is an untested belief until something breaks it on
> purpose.** Pairs with [`../incident-command/`](../incident-command/),
> [`../runbooks/`](../runbooks/) and [`../backup-restore-testing/`](../backup-restore-testing/).

---

## 1. What it is

Deliberately injecting failure into a system to verify that it behaves as designed — and, just as
importantly, that **the people and procedures around it** behave as documented. Azure Chaos Studio
provides the fault injection; **game days** provide the human half.

⭐ **This is not "breaking things randomly". It is an experiment with a written hypothesis, a bounded
blast radius, and a stop condition.**

---

## 2. Why it exists

⭐ **Because every reliability mechanism you have was tested in the condition it was built for, and
never since.** The catalogue of things that are believed rather than known:

| Belief | ⭐ How it actually fails |
|---|---|
| "It fails over automatically" | ⭐ it does — ⭐ **to a secondary with stale configuration** |
| "The runbook covers this" | ⭐ step 2 references a UI that changed |
| ⭐ "We have a backup" | ⭐ untested — [`../backup-restore-testing/`](../backup-restore-testing/) |
| "The alert will fire" | ⭐ it fires **to a mailbox nobody reads** |
| ⭐ "On-call knows what to do" | ⭐ on-call joined six weeks ago |
| "Retries handle it" | ⭐ retries amplify the outage — ⭐ see §5 |

⭐ **Chaos engineering finds these before an incident does, at a time you choose, with the right
people awake.** That last clause is the entire commercial argument: ⭐ **the same discovery on a
Tuesday afternoon costs a fraction of what it costs at 03:00 on a Sunday.**

---

## 3. How it works underneath — an experiment, not a stunt

```
① ⭐ STEADY STATE      ⭐ define "normal" as a MEASUREMENT, not a feeling
                        e.g. ⭐ "sign-in success rate > 99.5 %, p95 < 800 ms"

② ⭐ HYPOTHESIS        ⭐ "If we shut down one AZ, steady state is MAINTAINED"
                        ⭐ written down BEFORE the experiment

③ ⭐ BLAST RADIUS      ⭐ smallest injection that tests the hypothesis
                        ⭐ + a STOP CONDITION agreed in advance

④ INJECT              ⭐ run it, ⭐ with everyone watching

⑤ ⭐ OBSERVE           ⭐ did steady state hold? ⭐ did the ALERT fire?
                        ⭐ did the RUNBOOK work? ⭐ did the HUMAN find it?

⑥ ⭐ LEARN             ⭐ every surprise becomes an action - like a postmortem
```

⭐ **Step ② is what separates this from vandalism.** ⭐ **A hypothesis you expect to be *confirmed* is
the right kind: you are testing a belief you hold, and the value is in the cases where you are
wrong.** An experiment run "to see what happens" has no failure condition and therefore teaches
nothing reproducible.

⭐ **The stop condition is non-negotiable and must be stated in advance** — real user impact, a
duration cap, or a named person calling halt. ⭐ **Same discipline as the abort criteria in a
cutover playbook**
([`../../75-architecture-and-consulting/cutover-playbooks/`](../../75-architecture-and-consulting/cutover-playbooks/) §4):
decided in daylight, not during the event.

---

## 4. Worked example — a game day that tests people, not just machines

⭐ **The highest-value chaos experiments in an identity practice are not technical at all.**

```
GAME DAY  GD-2026-04     ⭐ "Conditional Access lockout"
Date 2026-08-20 14:00    ⭐ Deliberately a Tuesday afternoon

⭐ STEADY STATE
  Administrators can access the Entra portal. Sign-in success > 99.5 %.

⭐ HYPOTHESIS
  ⭐ "If a CA policy accidentally blocks all administrators, the on-call
     engineer can recover using break-glass within 15 minutes,
     ⭐ using only the runbook."

⭐ BLAST RADIUS
  ⭐ ONE test admin account, ⭐ scoped policy — ⭐ NOT the real admin group.
  ⭐ STOP: any impact on a real user, or 30 minutes elapsed.

⭐ PARTICIPANTS
  ⭐ Injector: D. Mwangi (⭐ knows the plan)
  ⭐ Responder: L. Petrov (⭐ DOES NOT know what is coming)
  Observer/scribe: A. Bose

⭐ WHAT HAPPENED
  T+0    Policy applied to the test account. Sign-in blocked.
  T+3    ⭐ Responder noticed - ⭐ VIA A USER REPORT, ⭐ NOT the alert
         ⭐ FINDING 1: no alert exists on CA policy modification
  T+6    Responder opened the runbook
  T+9    ⭐ Break-glass credential envelope located — ⭐ in a drawer,
         ⭐ FINDING 2: the runbook says a safe that no longer exists
  T+14   ⭐ Break-glass sign-in FAILED - ⭐ MFA registration required
         ⭐ FINDING 3: ⭐ a CA change 4 months ago silently broke break-glass
  T+22   ⭐ Recovered via the second break-glass account
  T+24   Policy reverted. Steady state restored.

⭐ RESULT  ⭐ HYPOTHESIS DISPROVED. Recovery took 22 min against a 15 min target,
          ⭐ and the primary recovery path did not work at all.
```

⭐ **Three findings, one of which — break-glass silently broken four months ago by an unrelated
change — is a genuine "we had no recovery path" discovery.** ⭐ **It would otherwise have been found
during a real lockout, which is the definition of the worst possible time.**

⭐ **The responder deliberately did not know what was coming.** ⭐ **A rehearsed responder tests the
technology; an unrehearsed one tests the system**, which includes the documentation, the alerting
and the on-call's actual knowledge.

⭐ **A disproved hypothesis is a *successful* experiment.** Recording it as a failure is the fastest
way to ensure nobody runs the next one.

---

## 5. The failure modes worth injecting first

⭐ **Order by "what would hurt most and is least tested", not by what is easy to inject.**

| Injection | ⭐ What it really tests |
|---|---|
| ⭐ Kill one instance | ⭐ does the load balancer actually notice? |
| ⭐ Availability zone down | is the "zone redundant" claim true? |
| ⭐ **Dependency latency (not failure)** | ⭐ **timeouts and retries** — ⭐ the subtle one |
| Expire a certificate in test | ⭐ do you find out before the customer? |
| ⭐ Revoke a managed identity's role | does the app fail safe, or fail open? |
| ⭐ **CA lockout drill** | ⭐ break-glass, end to end |
| Region failover | RTO, ⭐ and stale secondary configuration |

⭐ **Injecting *latency* rather than failure is the most underrated experiment.** ⭐ **A dependency
that returns an error is handled; a dependency that takes 30 seconds to respond exhausts your
connection pool, and every unrelated request then fails too.** That is how one slow third party
takes down a whole application — and it is invisible until you inject it.

⭐ **The retry-storm mechanism is worth stating explicitly:**

```
   dependency slows  →  requests pile up  →  ⭐ clients time out and RETRY
        ▲                                              │
        └──────── ⭐ retries ADD load to the struggling service ◄┘

   ⭐ The retry logic added for resilience becomes the amplifier.
   ⭐ Fixes: exponential backoff + JITTER, circuit breakers, retry budgets.
```

⭐ **Jitter matters as much as backoff.** ⭐ **Without randomisation, every client retries at the same
moment and you get synchronised waves** — the service recovers, is immediately flattened, and
oscillates. ⚠ The precise backoff parameters are workload-specific; the *pattern* is universal.

---

## 6. Commands — start small, in non-production

Azure Chaos Studio requires each resource to be **onboarded as a target** with specific
capabilities enabled — ⭐ **a deliberate safety gate, not bureaucracy.**

```powershell
# ⭐ What is even eligible to be broken?
Get-AzChaosTarget -ResourceGroupName rg-app-test |
  Select-Object Name, Type
```

```
Name                        Type
Microsoft-VirtualMachine    Microsoft.Chaos/targets
```

```powershell
# ⭐ After the experiment - did it run, and did it stop cleanly?
Get-AzChaosExperimentExecution -ResourceGroupName rg-app-test `
  -ExperimentName exp-vm-shutdown |
  Select-Object Id, Status, StartedAt, StoppedAt
```

```
Id        Status     StartedAt             StoppedAt
9f2a1d5c  Success    20/08/2026 14:00:02   20/08/2026 14:10:04
```

⚠ `⚠ check` — Chaos Studio cmdlet names, target types and available faults change; verify against
current documentation and your Az module.

⭐ **The most valuable early experiments need no product at all.** ⭐ **Stopping a VM, disabling an
NSG rule, expiring a test certificate, or applying a scoped CA policy are all fault injection** —
and the CA lockout drill in §4, which found three real defects, used nothing but the portal.

⭐ **Do not start in production.** Start in test, ⭐ then in production during business hours with
everyone watching, ⭐ and only then consider automated continuous chaos. ⭐ **An organisation that
cannot survive a planned experiment in test will not survive an unplanned one in production.**

---

## 7. When and where

| Maturity | Appropriate practice |
|---|---|
| ⭐ No runbooks, no alerting | ⭐ **not yet** — ⭐ build the basics first |
| Runbooks exist, untested | ⭐ **game days** — ⭐ start here; highest return |
| Tested runbooks, good alerting | fault injection in test |
| ⭐ Mature | production experiments, ⭐ bounded, announced |
| ⭐ Very mature | continuous/automated chaos |

⭐ **Chaos engineering on an immature system just causes outages and discredits the practice.**
⭐ **If there is no alerting, the experiment's finding is "we have no alerting" — which you already
knew, and you did not need to break anything to learn it.**

⭐ **Game days are the right entry point for almost every organisation**, because they need no
tooling, test the human system, and produce findings on the first attempt.

---

## 8. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| ⭐ Experiment becomes a real outage | ⭐ blast radius too large | ⭐ smallest viable injection + stop condition |
| Nothing learned | ⭐ no hypothesis | ⭐ write it before injecting |
| ⭐ Team resents it | ⭐ unannounced in production, ⭐ or used to blame | ⭐ announce, ⭐ blameless, ⭐ start in test |
| Findings not fixed | ⭐ no action tracking | ⭐ treat like a postmortem — [`../root-cause-analysis/`](../root-cause-analysis/) |
| ⭐ Retry storm during the test | ⭐ **that is a genuine finding** | backoff + jitter + circuit breaker |
| Only technical faults injected | tooling-led thinking | ⭐ inject **process** faults too — §4 |

⭐ **"Unannounced in production" deserves a clear position.** ⭐ **Some mature organisations do it;
most should not.** The learning from an announced experiment is nearly as good, ⭐ **and the
organisational trust required for unannounced production chaos takes years to build and one bad day
to destroy.**

---

## 9. Customer discovery questions

1. ⭐ **"When did you last test a failover, and did it work?"**
2. "Has anyone ever signed in with break-glass, other than at creation?"
3. ⭐ **"If a dependency became slow rather than failing, what happens?"**
4. "Do your retries use exponential backoff with jitter?"
5. ⭐ **"Does your on-call have a runbook, and have they used it?"**
6. "Would you be comfortable turning off one instance right now?" (⭐ the answer is the finding)
7. ⭐ **"What are you most afraid would happen?"** — ⭐ that is your first experiment

---

## 10. Remember it

**Hook — `S H B O`: Steady state, Hypothesis, Blast radius, Observe.** ⭐ **No hypothesis, no
experiment.**

**Analogy — a fire drill, not an arson.** ⭐ **You evacuate the building on a Tuesday at 11 a.m.,
having told everyone it may happen this month, and you time it. You are not testing whether the
building burns — you are testing whether people find the exits, whether the fire door that has been
propped open gets noticed, and whether the new starter knows the assembly point.** The analogy
predicts everything: ⭐ **the value is in the propped-open door**, and ⭐ **a drill where everything
goes perfectly was probably too easy.**

**The one line:** ⭐ **Write the hypothesis first, bound the blast radius, and remember that
injecting latency teaches you more than injecting failure.**

---

## 11. Self-test

1. What makes a chaos experiment different from breaking something?
   → ⭐ A measured steady state, a written hypothesis, a bounded blast radius and a stop condition.
2. Why is a disproved hypothesis a successful experiment?
   → ⭐ You found an untrue belief at a time of your choosing.
3. Why inject latency rather than failure?
   → ⭐ Errors are handled; slowness exhausts connection pools and takes down unrelated requests.
4. Describe the retry storm and its fixes.
   → ⭐ Retries add load to a struggling service; fix with exponential backoff, **jitter**, circuit breakers, retry budgets.
5. Why does jitter matter as much as backoff?
   → ⭐ Without it, clients retry in synchronised waves and the service oscillates.
6. When should an organisation *not* do chaos engineering?
   → ⭐ Before it has runbooks and alerting — the finding would be something it already knows.
7. What is the best entry point, and why?
   → ⭐ Game days: no tooling, they test the human system, and they produce findings immediately.

---

## 12. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | one experiment with steady state, hypothesis, blast radius and result |
| `security` | ⭐ the CA lockout / break-glass game day, with the findings |
| `operations` | ⭐ the runbook defects the experiment exposed, and the fixes |
| `break-fix` | one retry or timeout behaviour discovered under injected latency |
| `architecture-decisions` | the maturity assessment: which experiments are appropriate now |
