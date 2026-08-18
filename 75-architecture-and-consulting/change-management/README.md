# Change Management (organisational / adoption)

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **Boundary — two different disciplines share this name.** This topic is **organisational**
> change: getting humans to accept and adopt what you built. **Technical** change control — RFCs,
> CAB, change windows, freeze periods — is
> [`../../70-operations-and-reliability/change-management/`](../../70-operations-and-reliability/change-management/).
> ⭐ **Confusing them is why "we have change management" can mean two unrelated things in one
> meeting.**

---

## 1. What it is

The work of moving people from the current way of working to the new one: understanding who is
affected and how, communicating before they find out for themselves, building local champions,
training, and measuring adoption rather than deployment.

⭐ **Security controls change how people work every single day. That is not a side effect — it is
the deliverable.**

---

## 2. Why it exists

⭐ **A technically perfect rollout that users route around has made security worse, not better.**
The pattern is completely predictable:

| Control deployed | ⭐ The workaround it produces |
|---|---|
| MFA on every sign-in, no exceptions | ⭐ approve-everything fatigue → ⭐ **push-bombing works** |
| Blocked personal file sharing | ⭐ files emailed to personal Gmail instead |
| ⭐ Short session lifetimes | ⭐ passwords in a browser, or written down |
| ⭐ PIM with a slow approver | ⭐ **a permanent role quietly granted "just for now"** |
| Blocked USB, no alternative | consumer cloud storage on a phone |

⭐ **Every row is a control that measurably reduced security while showing green on a dashboard.**
The workaround is not user stupidity; it is people solving the problem you left them with.

⭐ **The professional consequence: if you cannot name the friction your control creates and what
users will do instead, you have not finished the design.**

---

## 3. How it works underneath — ADKAR, used as a diagnostic

⭐ **ADKAR's value is not as a plan but as a *diagnosis*: adoption stalls at exactly one stage, and
the remedy differs completely by stage.**

```
A  AWARENESS   ⭐ do they know it's coming, and WHY?
                  stalled here → ⭐ comms problem
D  DESIRE      do they want it, or at least accept it?
                  stalled here → ⭐ WIIFM problem / sponsor problem
K  KNOWLEDGE   do they know HOW?
                  stalled here → ⭐ training problem  → ../customer-training/
A  ABILITY     ⭐ can they actually do it, in their real environment?
                  stalled here → ⭐ TOOLING problem (⭐ ability ≠ knowledge)
R  REINFORCE   does it stick after week two?
                  stalled here → ⭐ measurement + management problem
```

⭐ **The most common misdiagnosis in this whole field: treating a *desire* or *ability* problem with
more training.** People who do not want a change, or who physically cannot complete it on the device
they have, will not be fixed by another session — and running one wastes the goodwill you needed.

⭐ **Ability is separate from knowledge for a concrete reason.** A user who understands passkeys
perfectly but has a five-year-old phone that will not run the authenticator app has an *ability*
gap. ⭐ **The remedy is a hardware key or a device refresh — a budget conversation, not a slide
deck.**

---

## 4. Worked example — the impact assessment, per persona

⭐ **This table is what makes a change plan real. Written before deployment, it changes the design.**

```
CHANGE   Phishing-resistant MFA for all administrators (REQ-019)

PERSONA          WHAT CHANGES        ⭐ FRICTION      ⭐ WORKAROUND RISK   MITIGATION
─────────────────────────────────────────────────────────────────────────────────────
IT admins (9)    passkey/FIDO2       ⭐ +1 device to  ⭐ shared key in a   ⭐ 2 keys each,
                 replaces app push      carry            drawer            personally issued
Exec assistants  same, ⭐ + delegated ⭐ high - opens  ⭐ credential        ⭐ delegate FIRST
(3)              mailbox access         many mailboxes   sharing           in the pilot
Field engineers  passkey on a        ⭐ ABILITY GAP:  ⭐ they will ask an  ⭐ hardware keys,
(6)              shared laptop          ⭐ no personal    admin to sign in     ⭐ NOT phone-based
                                        device            for them
Break-glass      ⭐ NO CHANGE         -               -                  ⭐ excluded by design
```

⭐ **The field engineers row is the one that changes the architecture.** Six people with no personal
device cannot use a phone-based method. Discover that before deployment and you buy twelve security
keys; discover it after and ⭐ **you have created a culture of admins signing in on each other's
behalf — which is worse than the control you replaced.**

⭐ **The exec assistants row shows why the pilot order matters.** The highest-friction, highest-
visibility persona goes *first*, not last: if it fails there, it fails everywhere, and you want that
failure at a scale of three people rather than three hundred.

**The communication sequence — ⭐ three touches, and the middle one is the one people skip:**

```
T-14 days  ⭐ WHY, from the SPONSOR - not from IT
           ⭐ "our cyber insurer requires this by 30 June" beats
              "we are enhancing our security posture"
T-3 days   ⭐ WHAT and HOW, from IT: 90-second video + one-page guide
           ⭐ + the exact date and time it starts
T-0        ⭐ WHERE TO GET HELP: named channel, staffed, ⭐ with hours
T+7 days   ⭐ adoption numbers back to the sponsor - see §5
```

⭐ **The first message must come from the business sponsor, not from IT.** A security change
announced by IT is a policy imposed on people; ⭐ **the same change announced by the CFO with the
insurance reason is a business decision people are part of.** Same content, entirely different
reception — and it costs one email to get right.

---

## 5. Commands — measure adoption, not deployment

⭐ **"Deployed" is a fact about your work. "Adopted" is a fact about theirs.** Only one predicts
whether the control survives.

```powershell
$reg = Get-MgReportAuthenticationMethodUserRegistrationDetail -All
[pscustomobject]@{
  Users        = $reg.Count
  MfaCapable   = @($reg | Where-Object IsMfaCapable).Count
  PhishResist  = @($reg | Where-Object {
                    $_.MethodsRegistered -match 'fido2|windowsHelloForBusiness' }).Count
  ⭐AdminsNoMfa = @($reg | Where-Object { $_.IsAdmin -and -not $_.IsMfaRegistered }).Count
}
```

```
Users MfaCapable PhishResist AdminsNoMfa
  517        498          14           2
```

⭐ **`PhishResist 14` against 9 admins + 3 assistants + 6 engineers = 18 targeted means four people
have not adopted** — and you can name them. ⭐ **That is an adoption conversation with four
individuals, not a broadcast reminder to 517.**

⭐ **`AdminsNoMfa: 2` is the row that goes to the sponsor**, every week, until it is zero.

**Reinforcement — is it sticking, or decaying?**

```powershell
$since = (Get-Date).AddDays(-7)
Get-MgAuditLogSignIn -Filter "createdDateTime ge $($since.ToString('yyyy-MM-ddTHH:mm:ssZ'))" -All |
  Group-Object { $_.AuthenticationDetails.AuthenticationMethod -join ',' } |
  Select-Object Name, Count | Sort-Object Count -Descending
```

```
Name                        Count
Password, Mobile app push    1204
⭐ Password, FIDO2 key          88
Password                       17
```

⭐ **Registration is not usage.** People register a passkey in the session you ran, then keep using
push because it is habit. ⭐ **This query is the difference between "we rolled it out" and "they use
it"**, and week-two decay is normal — which is precisely what the `R` in ADKAR is for.

---

## 6. When and where

| Change | Organisational effort |
|---|---|
| Invisible to users (backend, logging) | ⭐ minimal — ⭐ **say so; do not manufacture comms** |
| ⭐ Changes daily sign-in | ⭐ **full: personas, comms, champions, measurement** |
| Removes a capability people use | ⭐ **heaviest — must offer the alternative in the same message** |
| Regulatory, non-negotiable | ⭐ lead with the obligation; ⭐ do not pretend it is optional |

⭐ **Never announce a removal without the replacement in the same sentence.** *"USB storage is
blocked"* generates workarounds; *"USB storage is blocked — here is the approved way to move a large
file, it takes 30 seconds"* generates compliance. ⭐ **The gap between those two messages is where
shadow IT is born.**

---

## 7. What breaks

| Symptom | ADKAR stage | Fix |
|---|---|---|
| "Nobody told us" | ⭐ Awareness | ⭐ sponsor-led message at T-14 |
| "Why are we doing this?" | Desire | ⭐ the real driver, stated plainly |
| Helpdesk flooded | Knowledge | ⭐ guide + staffed channel **before** go-live |
| ⭐ Some users simply cannot comply | ⭐ **Ability** | ⭐ hardware/budget, **not more training** |
| Adoption decays after week 2 | Reinforce | ⭐ measure weekly; managers see their own numbers |
| ⭐ Users found a workaround | ⭐ friction unmitigated | ⭐ §4 table — fix the design, not the user |
| Sponsor absent from comms | ⭐ ownership | ⭐ escalate; ⭐ IT cannot mandate a business change |

⭐ **When a workaround appears, the correct first response is curiosity, not enforcement.** The
workaround tells you precisely which friction you failed to design for — ⭐ **it is free, high-quality
feedback, and punishing it only makes the next one harder to see.**

---

## 8. Customer discovery questions

1. ⭐ **"Who will announce this — you, or IT?"** (⭐ the answer predicts adoption)
2. "Which teams have been through a change recently, and how did it go?"
3. ⭐ **"Is there anyone who physically cannot comply — no smartphone, shared device, field work?"**
4. "Who are the informal influencers people actually listen to?"
5. ⭐ **"What will people do if this makes their job harder?"** — ⭐ ask it directly; they know
6. "How do you normally communicate change, and does anyone read it?"
7. "Who will keep measuring adoption after we leave?"

---

## 9. Remember it

**Hook — `ADKAR` as a *diagnosis*, not a plan.** ⭐ **Locate the stage where adoption stalled; the
remedy is different at each, and training is the answer at only one of them.**

**Analogy — a new one-way system in a town.** ⭐ **Signs go up (awareness), people are told why —
school safety, not bureaucracy (desire), the new route is published (knowledge), but the lorry
drivers physically cannot make the turn (ability), and after a fortnight everyone reverts unless
enforcement continues (reinforcement).** ⭐ **The lorries are the field engineers with no personal
phone** — and the analogy predicts the fix: you widen the corner, you do not re-issue the map.

**The one line:** ⭐ **Name the friction your control creates and what users will do instead — before
you deploy it — and measure adoption, not deployment.**

---

## 10. Self-test

1. Which discipline is this, and what is the other one called?
   → ⭐ Organisational/adoption change; technical change control (RFC/CAB) is separate.
2. Difference between knowledge and ability gaps, with an example?
   → ⭐ Knowledge = doesn't know how; ability = knows but cannot (no compatible device). Only one is fixed by training.
3. Why must the first announcement come from the sponsor?
   → ⭐ A business decision people are part of, versus a policy imposed by IT.
4. Registration numbers look good; usage does not. Which ADKAR stage?
   → ⭐ Reinforcement — habit reverts around week two.
5. What is a user workaround, professionally speaking?
   → ⭐ Free, high-quality feedback naming the friction you failed to design for.
6. Rule for announcing a removed capability?
   → ⭐ Never without the replacement in the same sentence.
7. Which control from §2 makes security actively worse when adopted badly?
   → ⭐ Push-based MFA with no number matching — fatigue makes push-bombing work.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | the adoption query (§5) run before and after a change |
| `customer-use-cases` | ⭐ the per-persona impact table, written before deployment |
| `operations` | the comms sequence actually sent, with dates and sender |
| `break-fix` | ⭐ one workaround observed, and the design change it caused |
| `architecture-decisions` | one design altered by an ability gap (e.g. hardware keys purchased) |
