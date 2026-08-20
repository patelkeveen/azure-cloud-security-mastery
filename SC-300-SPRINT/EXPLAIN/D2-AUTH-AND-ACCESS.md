# D2 — Authentication and access management · 25–30%

> ⭐ **The largest block of marks on the exam.** If you run out of revision time, come back here.
> Four registers per concept: age 8 → non-technical adult → technical → exam.

---

## 1. Authentication vs authorisation

**Age 8** — Two different questions at the door. **"Are you really Sam?"** — that's showing your
face. **"Is Sam allowed in the staff room?"** — that's a different question, and the answer can be
no even though you really are Sam.

**Any adult** — **AuthN** proves *who you are*. **AuthZ** decides *what you may do*. ⭐ **Proving
who you are grants you nothing by itself.** Most access failures people call "login problems" are
actually authorisation failures — the sign-in worked fine.

**Technical** — AuthN produces a token with claims about the principal. AuthZ evaluates policy —
role assignments, scopes, Conditional Access — against those claims. Different failure modes,
different logs, different fixes.

⭐ **Exam** — ⭐ **Read the error.** *"You don't have permission"* after a **successful** sign-in is
authorisation — check roles, consent, or a CA grant control. *"We couldn't verify it's you"* is
authentication. ⭐ **Answering the wrong half is a deliberate trap.**

⭐ **Hook** — **AuthN = who. AuthZ = what. The sign-in log tells you which one broke.**

---

## 2. MFA and what a "factor" actually is

**Age 8** — To get the treasure you need **two different kinds** of proof: a **secret word** you
remember, and the **actual key** in your pocket. Two secret words isn't two kinds — someone who
overhears you gets both.

**Any adult** — Three categories: **something you know** (password, PIN), **something you have**
(phone, security key), **something you are** (fingerprint, face). ⭐ **MFA means two from
*different* categories.** A password plus a security question is still one category, and that's
why security questions are not MFA.

**Technical** — Factors are independent authentication channels. Strength varies enormously
*within* "something you have": ⭐ **SMS is phishable and SIM-swappable; a FIDO2 key is
cryptographically bound to the site's origin and cannot be phished at all.**

⭐ **Exam** — ⚠ **"Enable MFA" is no longer a sufficient answer.** The exam wants **which method**,
enforced **by what**. Modern answer: **Conditional Access** requiring an **authentication
strength**, not per-user MFA, not legacy baseline policies. ⭐ **Per-user MFA is legacy and is a
wrong answer** wherever CA is available.

⭐ **Hook** — **Know / have / are. Two categories, not two secrets.**

---

## 3. The authentication methods policy — the converged one

**Age 8** — One list on the wall saying **which kinds of keys the school accepts at all**, and
**who is allowed to use each kind**. Older children may use the electronic fob; everyone may use
the metal key.

**Any adult** — A single tenant-wide place that decides which sign-in methods exist and who can
register them. It replaced two older, separate settings screens that used to disagree with each
other and confuse everyone.

**Technical** — The converged **authentication methods policy** governs registration and use of
every method (Authenticator, FIDO2, TAP, SMS, voice, OATH tokens, certificates). It supersedes the
legacy **MFA service settings** and the legacy **SSPR** method settings.

⭐ **Exam** — ⭐ **Legacy screens are offered as wrong answers.** If a question says "the legacy MFA
settings page" or "per-user MFA", it is either the wrong choice or the thing being migrated *away
from*. ⭐ **Managed by Authentication Policy Administrator** — not Authentication Administrator,
which is per-user (see [`D1`](D1-USER-IDENTITIES.md) §6).

⚠ **Dated:** Microsoft-provided **SMS and voice are being retired (1 Feb 2027)**, and **passkeys
become default 1 Sep 2026**. Direction of travel matters for "recommend the approach" questions.

⭐ **Hook** — **One policy, all methods. Legacy MFA and legacy SSPR settings are dead ends.**

---

## 4. Temporary Access Pass (TAP)

**Age 8** — A **day pass** for a child who lost their fob. It works for a short time, then stops
by itself. You use it to collect your **new** fob — not to get in every day.

**Any adult** — A time-limited code an admin issues so someone with **no working method** can
bootstrap one. ⭐ **The classic use is day one of employment: a new starter has nothing, and you
need them to register a passkey without ever giving them a password.**

**Technical** — TAP is a time-limited passcode, issuable as one-time or multi-use, with a
configurable lifetime. ⭐ **It satisfies MFA and can be used to register other strong methods** —
which is exactly the bootstrap problem.

⭐ **Exam** — ⭐ *"Onboard a new employee to passwordless without issuing a password"* → **TAP**.
⭐ *"User lost their phone and their only method was Authenticator"* → **TAP** to re-register.
⚠ **It is enabled in the authentication methods policy**, and it is off by default.

⭐ **Hook** — **TAP is the bootstrap. It exists so you never have to issue a password.**

---

## 5. Passwordless — FIDO2, passkeys, Windows Hello

**Age 8** — Instead of a **secret word** anyone could overhear, you get a **magic key** that only
works on the real door. If a fake door asks, the key simply won't turn. ⭐ **It can't be tricked,
because it checks the door as much as the door checks you.**

**Any adult** — Your device holds a private key that never leaves it, unlocked by your face,
fingerprint or PIN. The website gets only a signature. ⭐ **There is no shared secret to steal, and
crucially the key refuses to work on a lookalike phishing site — because it verifies the site's
address before signing.** That single property is why passwordless beats "strong password + SMS".

**Technical** — WebAuthn/FIDO2: an **origin-bound** asymmetric key pair; the private key lives in
a TPM or security key. **Windows Hello for Business** is FIDO2 bound to a device. **Passkeys** are
discoverable FIDO2 credentials, optionally synced across a vendor's ecosystem.

⭐ **Exam** — ⭐ **"Phishing-resistant" is a precise term, not a compliment.** It means
**FIDO2 / WHfB / certificate-based authentication**. ⚠ **Authenticator push, SMS, voice and OATH
codes are NOT phishing-resistant.** ⭐ **Any question containing "phishing-resistant" is asking you
to pick the phishing-resistant authentication strength**, and it is a very common item.

⭐ **Hook** — **Phishing-resistant = FIDO2, WHfB, certificates. Push and SMS are not.**

---

## 6. SSPR and password writeback

**Age 8** — Instead of queuing at the office to have your password changed, you answer some things
only you would know, and change it yourself.

**Any adult** — Self-service password reset. ⭐ **It is a helpdesk-cost feature that is sold as a
security feature** — the security part is only true if the verification methods are strong.
**Password writeback** is the extra piece that pushes the new password **back down** into on-prem
AD, so the user's laptop and file shares accept it too.

**Technical** — SSPR requires registered methods and a policy defining how many are needed.
Writeback is a Connect/Cloud Sync feature. ⭐ **Without writeback, a hybrid user resets their cloud
password and their domain-joined laptop still wants the old one** — two passwords, immediate
helpdesk call.

⭐ **Exam** — ⭐ **Writeback is supported with PHS, PTA *and* federation** — a common wrong
assumption is that it needs PHS. ⭐ *"Hybrid users must be able to reset their own password and
have it work on-premises"* → **SSPR + password writeback**.

⭐ **Hook** — **No writeback, two passwords.**

---

## 7. Password protection and smart lockout

**Age 8** — The school bans obviously silly passwords like "password" and the school's own name,
and if someone guesses wrong many times the door pauses — but it recognises *you* and doesn't
punish you for someone else's guessing.

**Any adult** — A **banned password list** (Microsoft's global one, plus your own custom terms like
your company name and local sports teams) and a **lockout** that slows attackers down. ⭐ **Smart
lockout distinguishes the real user from an attacker by familiar location and device**, so a
brute-force attempt doesn't lock the legitimate person out — which is exactly how naive lockout
becomes a self-inflicted denial of service.

**Technical** — Entra Password Protection evaluates candidates against global + custom banned
lists using normalisation and fuzzy matching. It can be **extended on-premises** via agents on
domain controllers, in **audit** or **enforce** mode.

⭐ **Exam** — ⭐ **The on-prem agent has an audit mode — deploy there first.** ⭐ **"Deployed is not
enforced" is a recurring theme across this whole exam** (report-only CA, audit-mode ASR,
report-only risk policies). ⚠ **Custom banned lists require P1.**

⭐ **Hook** — **Smart lockout locks the attacker, not the user. Audit mode first, always.**

---

## 8. Conditional Access — the model

**Age 8** — A rule that says: **"IF it's a Year 6 pupil, AND they're coming in through the back
gate, THEN they must show a fob as well as their face — unless they're the caretaker, who's always
allowed."**

**Any adult** — If–then rules for sign-in. **If** *this user*, accessing *this app*, from *this
place*, on *this device*, looking *this risky* — **then** require MFA, or a managed device, or
block entirely. ⭐ **It is the single most important control in Microsoft identity, and it is where
most of your daily job will actually live.**

**Technical** — Policies evaluate **assignments** (users/groups/roles, target resources,
conditions) and apply **access controls** (grant/block, session). ⭐ **All matching policies are
evaluated, and the results combine — this is not first-match-wins.**

⭐ **Exam — the three rules that decide most CA questions:**

```
1. EXCLUSIONS ALWAYS BEAT INCLUSIONS.
   A user excluded in ANY matching policy is excluded from that policy, full stop.

2. BLOCK BEATS GRANT.
   If any applicable policy blocks, the sign-in is blocked. No grant overrides it.

3. MULTIPLE GRANT CONTROLS DEFAULT TO -AND-.
   Select "require MFA" and "require compliant device" and you have required BOTH.
   You must explicitly choose "Require ONE of the selected controls" to get OR.
```

⚠ **Rule 3 is the single most common CA mistake in the real world and a guaranteed exam item.**
Someone means "MFA *or* a managed device" and accidentally demands both, and half the company
can't work.

⭐ **And the safety rule that outranks all of it: exclude your break-glass accounts from every
policy, before you write the first one.** A CA policy that locks out every administrator is
recoverable **only** through an excluded account.

### ⭐ The recall sentence — say this and the policy blade writes itself

> ⭐ **When WHO, using WHAT, from WHERE, accesses WHICH APP, under WHAT RISK,
> then enforce WHICH CONTROLS, for HOW LONG.**

⭐ **That is not a mnemonic — it is the blade, in order.** Each clause is a real field:

```
WHO            Assignments > Users, groups, directory roles, workload identities
WHAT           Conditions  > Device platforms, client apps, filter for devices
WHERE          Conditions  > Locations (named locations, trusted IPs, countries)
WHICH APP      Target resources (cloud apps, user actions, auth context)
WHAT RISK      Conditions  > Sign-in risk, user risk, insider risk
WHICH CONTROLS Grant  (MFA, compliant device, auth strength, terms of use)
HOW LONG       Session (sign-in frequency, persistent browser, app-enforced)
```

⭐ **If you can recite the sentence you can reconstruct any CA question from first principles**,
including the ones that describe a policy in prose and ask what it does.
*(Adopted from a ChatGPT-authored plan — it is the best single idea in it.)*

⭐ **Hook** — **Exclusions win. Block wins. Grants are AND unless you say otherwise.**

---

## 9. Authentication strengths

**Age 8** — Not "show me a key" but "show me **this particular kind** of key."

**Any adult** — Instead of a policy saying *"require MFA"* — which any two factors satisfy,
including weak SMS — you say *"require a **phishing-resistant** method."* ⭐ **It turns MFA from a
yes/no into a quality bar.**

**Technical** — An authentication strength is a named set of allowed method combinations,
referenced as a **grant control** in Conditional Access. Three built-ins — **MFA**,
**Passwordless MFA**, **Phishing-resistant MFA** — plus custom.

⭐ **Exam** — ⭐ **"Administrators must use phishing-resistant MFA"** → a CA policy targeting
directory roles, granting with the **phishing-resistant MFA** strength. ⭐ **Not per-user MFA. Not
"require MFA".** ⭐ **Authentication strength is a policy *input*** — the authentication methods
policy decides what exists; the strength decides what this particular access demands.

⭐ **Hook** — **"Require MFA" is a yes/no. Authentication strength is a quality bar.**

---

## 10. Session controls — sign-in frequency and persistent browser

**Age 8** — Even after you're let in, the door can say **"come back and show me again in an
hour"**, or **"don't stay signed in on the shared computer."**

**Any adult** — Controls that apply **after** a successful sign-in. **Sign-in frequency** forces
re-authentication on a schedule. **Persistent browser** decides whether "stay signed in?" is
offered — you turn it off on shared and kiosk machines.

**Technical** — Session controls in CA. Default refresh-token behaviour keeps users signed in for
long periods; sign-in frequency overrides that with a defined interval.

⭐ **Exam** — ⚠ **Shortening token lifetime is the *blunt* tool and it hurts.** ⭐ **The exam wants
you to know that a revoked or risky user isn't stopped by waiting for a token to expire — that's
what CAE is for (§11).** ⭐ *"Users on unmanaged devices must not stay signed in"* → **persistent
browser session: Never**.

⭐ **Hook** — **Sign-in frequency is a timer. CAE is an event. Timers are the slow answer.**

---

## 11. Continuous Access Evaluation (CAE)

**Age 8** — Normally your wristband is good for an hour, even if you're sent home after ten
minutes. **CAE is the door being *told* immediately** that you're not allowed any more — so the
wristband stops working right away instead of at the end of the hour.

**Any adult** — Without it, a token stays valid until it expires. Disable an account and they can
still read mail for up to an hour. ⭐ **CAE lets the app and the identity provider talk in near
real time**, so account disable, password reset, or a big risk change kills the session in
**minutes, not an hour**.

**Technical** — Resource providers (Exchange Online, SharePoint, Teams, Graph) subscribe to
critical events and re-evaluate. ⭐ **Critical events**: account disabled/deleted, password change,
MFA enabled for the user, admin-triggered token revocation, high user risk. Also enforces
**location changes** in near real time.

⭐ **Exam** — ⭐ **"How do we stop a terminated employee's access immediately?"** → **CAE**, not a
shorter token lifetime. ⚠ **CAE is a property of the resource + client supporting it** — not every
app participates. ⭐ **The contrast with §10 is the point of the question:
sign-in frequency is a timer; CAE is an event.**

⭐ **Hook** — **Token lifetime is a countdown. CAE is a phone call.**

---

## 12. Identity Protection — risk

**Age 8** — The school notices something **odd**: your badge was used in two cities an hour apart.
It doesn't accuse you — it asks you to prove it's really you.

**Any adult** — Machine learning on sign-in signals. ⭐ **Two different clocks:**
**Sign-in risk** = *is this particular sign-in suspicious right now?* (impossible travel, anonymous
IP, unfamiliar properties). **User risk** = *do we believe this account is compromised?* (leaked
credentials found in a breach dump).

⭐ **The responses differ, and the exam tests that they differ:** sign-in risk → require **MFA**.
User risk → require a **secure password change**.

**Technical** — Risk detections feed risk levels (low/medium/high), consumed as CA conditions.
Remediation is self-service (MFA or password change) or admin (dismiss, confirm compromised —
which also feeds the model).

⭐ **Exam**

```
SIGN-IN risk  -> this session looks wrong  -> require MFA
USER risk     -> this account looks owned  -> require secure password change
```

⭐ **Leaked credentials requires PHS** — no hash in the cloud, no comparison, no detection.
⚠ **Risk policies need P2**, and ⭐ **they capture forward only — a policy enabled today knows
nothing about last week.**

⭐ **Hook** — **Sign-in risk → prove it's you. User risk → change the password.**

---

## 13. Report-only mode

**Age 8** — Practising the fire drill **without** actually locking the doors. You find out who
would have been stuck, and nobody gets stuck.

**Any adult** — A CA policy that evaluates and logs what it *would* have done, but never blocks.
⭐ **It is how you avoid locking out your own company on a Friday afternoon.**

**Technical** — Policy state `enabledForReportingButNotEnforced`. Results appear per sign-in in the
sign-in logs' Report-only tab. Pair it with **What-If** for hypothetical evaluation without a
real sign-in.

⭐ **Exam** — ⭐ **The safe-deployment sequence is examinable:**

```
1. Write the policy in REPORT-ONLY
2. Run WHAT-IF against representative users
3. Read the report-only results in the sign-in logs
4. THEN enable  -- and only after break-glass exclusion is verified
```

⭐ **"Deployed is not enforced" — and the mirror trap is that report-only protects nobody.** A
policy left in report-only for six months is a control the auditor will fail you on.

⭐ **Hook** — **Report-only tells the truth and stops nothing. Ship it, then enforce it.**

---

## Say it back — cover the right column

| Prompt | Answer |
|---|---|
| Two grant controls selected | **AND** by default — choose "require one" for OR |
| A user excluded in one matching policy | Excluded. Exclusions always win |
| Any policy blocks | Blocked. Block beats grant |
| "Phishing-resistant" means | FIDO2 / WHfB / certificate-based. **Not** push or SMS |
| New starter, no methods, no password | TAP |
| Terminated employee, access now | CAE — not shorter token lifetime |
| Sign-in risk response | Require MFA |
| User risk response | Secure password change |
| Leaked credentials needs | PHS |
| Hybrid SSPR must reach on-prem | Password writeback (works with all three auth methods) |
| Shared kiosk, don't stay signed in | Persistent browser: Never |
| Before enabling any policy | Break-glass excluded, report-only, What-If |

> ⭐ **If you can only revise one file on 27 August, revise this one.**

> **Next:** [`D3-WORKLOAD-IDENTITIES.md`](D3-WORKLOAD-IDENTITIES.md) ·
> **Index:** [`README.md`](README.md) · **Labs:** [`../DAY-2.md`](../DAY-2.md), [`../DAY-3.md`](../DAY-3.md)
