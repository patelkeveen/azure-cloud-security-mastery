# Identity Protection

> **Concept facet.** Depth in
> [Layer 3 §4](../conditional-access/LAYER-3-DOMAIN-2-AUTH-AND-ACCESS.md). Requires **P2**.

## What it is

Machine-learning risk detection over identity signals, expressed as two scores that Conditional
Access can consume as conditions.

| | **User risk** | **Sign-in risk** |
|---|---|---|
| Asks | Is this identity **compromised**? | Is **this sign-in** suspicious? |
| Examples | **Leaked credentials**, threat-intel match, anomalous activity | Anonymous IP, impossible travel, unfamiliar properties, token anomaly |
| Response | Require secure password change | Require MFA, or block |

## Why the split matters

They are different questions with different remedies. A compromised *credential* needs the password
changed. A suspicious *sign-in* needs stronger proof **right now** — changing the password does
nothing if the credential was never the problem.

Conflating them produces the common misconfiguration: a user-risk policy that forces password
changes for people whose password was fine, training them to ignore the prompt.

## How it works underneath

**Leaked-credential detection requires Password Hash Sync.** Microsoft compares your users' synced
hashes against credentials recovered from breach corpora. **A federated or PTA-only tenant gets
nothing from this** — which is one of the strongest practical arguments for enabling PHS even when
you authenticate elsewhere. See [`../hybrid-identity/`](../hybrid-identity/).

**Real-time vs offline detections.** Some fire during sign-in and can trigger a policy; others
surface minutes to hours later. A user who "passed" can be flagged afterwards — which is precisely
what **Continuous Access Evaluation** and user-risk policies exist to handle.

## The feedback loop nobody operates

**Confirm compromised / confirm safe trains the model.** Dismissing risk without classifying it
throws the signal away. Doing it consistently measurably improves detection quality, and it is the
habit that distinguishes an operator from someone who enabled a feature.

## Retention — verified, and not what most assume

| Report | Free | P1 | **P2** |
|---|---|---|---|
| Risky sign-ins | 7 days | 30 days | **90 days** |
| **Risky users** | **No limit** | No limit | **No limit** |

Risky sign-ins get **longer** retention than ordinary sign-in logs. **Risky users are never aged
out until the risk is remediated**, which is why unremediated risk visibly accumulates — that is a
feature, and a good discovery finding.

## Risky workload identities

Service principals get risk detections too. **Under-taught, and increasingly the actual breach
path** — an attacker who compromises a service principal inherits application permissions with no
user-rights intersection. See [`../service-principals/`](../service-principals/).

## When and where

Any tenant with P2. Deploy in this order:

1. Enable and **observe** — do not enforce on day one
2. Read the risky users/sign-ins reports for a week; learn your baseline
3. Sign-in risk → require MFA (low blast radius, high value)
4. User risk → require password change (higher friction; needs MFA registration coverage first)
5. **Registration campaigns** to move users off SMS

## The traps

1. **Enforcing before observing.** Impossible-travel fires for VPN users and frequent travellers.
   Learn the baseline first.
2. **User-risk password change requires prior MFA registration** — otherwise the remediation path
   is itself blocked.
3. **Expecting leaked-credential detection without PHS.** It simply will not populate.
4. **Ignoring workload identity risk** because the dashboard defaults to humans.

## Evidence this topic needs

- `lab/` — enable; simulate risk (anonymous IP via Tor/VPN); observe detection and policy.
- `break-fix/` — trigger a user-risk policy on an account with no MFA registered; observe the trap.
- `security/` — risky users report; confirm-compromised workflow documented.
- `operations/` — triage runbook: who investigates, what evidence, what closes a case.
