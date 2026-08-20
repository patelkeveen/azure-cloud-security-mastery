# EXPLAIN — every SC-300 concept at four levels

> ⭐ **The goal you set: be able to explain this to an 8-year-old, and to a 40-year-old and an
> 80-year-old, technical or not.** That is not a nice-to-have — ⭐ **it is the single best test of
> whether you actually understand something**, and it is the same test an interviewer applies.

---

## 1. Why four levels, and why this works

⭐ **You cannot simplify what you do not understand.** Jargon lets you *sound* correct while
hiding a gap; a child's question does not. When you say *"it uses OAuth to federate the identity"*
you may know exactly what happens, or you may be reciting. ⭐ **Forcing yourself to say it without
a single technical word is what exposes the difference** — and every place you stall is a gap you
can go and fix.

The four registers:

| Level | Who | What it forces |
|---|---|---|
| ⭐ **Age 8** | a child | ⭐ **A concrete physical picture. Zero jargon.** If you can't, you don't understand the mechanism |
| **Any adult** | 40 or 80, non-technical | An everyday analogy **plus why it matters** — the consequence, not the mechanism |
| **Technical** | a peer engineer | The real mechanism, correct terminology, the actual objects and claims |
| ⭐ **Exam** | the examiner | ⭐ **The precise distinction and the trap** — what the wrong answer looks like and why it's offered |

⭐ **The trick nobody tells you: the age-8 level is the hardest, and it is the one that makes the
exam level stick.** A concrete image survives stress; a definition does not. On exam day, under
time pressure, *"eligible means allowed but not holding the key"* will still be there when
*"eligible assignments require activation"* has evaporated.

---

## 2. The four files — 41 concepts, mapped to exam weight

| File | Domain | Weight | Concepts |
|---|---|---|---|
| [`D1-USER-IDENTITIES.md`](D1-USER-IDENTITIES.md) | Implement and manage user identities | 20–25% | 10 |
| ⭐ [`D2-AUTH-AND-ACCESS.md`](D2-AUTH-AND-ACCESS.md) | ⭐ **Authentication and access management** | ⚠ **25–30%** | 13 |
| [`D3-WORKLOAD-IDENTITIES.md`](D3-WORKLOAD-IDENTITIES.md) | Plan and implement workload identities | 20–25% | 8 |
| [`D4-GOVERNANCE.md`](D4-GOVERNANCE.md) | Plan and automate identity governance | 20–25% | 7 |

⭐ **D2 is the biggest block of marks. If you revise one file on 27 August, revise D2.**

### Full concept index

**D1** — what Entra ID is · tenant/directory/subscription · identity types · groups ·
⭐ administrative units · roles and least privilege · ⭐ PHS/PTA/federation · Connect vs Cloud Sync ·
group-based licensing · B2B collaboration vs direct connect

**D2** — authN vs authZ · what a factor is · the authentication methods policy · ⭐ TAP ·
passwordless and phishing-resistance · SSPR and writeback · password protection ·
⭐ **Conditional Access — the model** · ⭐ authentication strengths · session controls ·
⭐ **CAE** · Identity Protection risk · report-only

**D3** — app registration vs enterprise app · ⭐ **`scp` vs `roles`** · the consent framework ·
managed identities · workload identity federation · secrets vs certificates · reading a token ·
⭐ **SaaS app integration — SSO, SCIM provisioning, App Proxy**

**D4** — ⭐ **PIM eligible vs active** · activation controls · access reviews ·
entitlement management · connected organizations · lifecycle workflows ·
separation of duties and role-assignable groups

---

## 3. How to actually use this — 40 minutes an evening

⭐ **Reading it is worth almost nothing. The value is entirely in saying it out loud.**

```
1. Pick a concept. Read all four levels once.
2. Close the file.
3. ⭐ Say the AGE-8 version out loud. Out loud, not in your head.
4. Then the adult version, then the technical, then the exam distinction.
5. ⭐ Every time you say "and then it sort of..." - STOP. That is the gap. Go reread that bit.
6. Write the stalled ones down. They are tomorrow's first 20 minutes.
```

⭐ **Step 5 is the whole method.** The stall is data. Most people push through it and never
notice they didn't know; you are going to write it down instead.

⭐ **The "cover the right column" tables at the end of each file are the exam-mode drill.** Read
the prompt, answer aloud, *then* look. ⚠ **Recognising the right answer when you see it is not
recall, and the exam tests recall.**

---

## 4. Schedule — mapped to your remaining days

| Evening | Read | Also |
|---|---|---|
| **Thu 20 Aug** | D1 §1–5 | [`../GAP-DRILL.md`](../GAP-DRILL.md) §1–2 |
| **Fri 21 Aug** | ⭐ **D2 §8–11** *(CA, strengths, CAE — today's labs)* | GAP-DRILL §3 |
| **Sat 22 Aug** | D4 §1–2 *(PIM)* + D1 §6 *(roles)* | GAP-DRILL §4 |
| **Sun 23 Aug** | D4 §3–7 *(governance)* | GAP-DRILL §5 |
| **Mon 24 Aug** | D3 all *(workload identity)* | GAP-DRILL §6 |
| **Tue 25 Aug** | D2 §12–13 + D1 §10 *(risk, external)* | GAP-DRILL §7 |
| **Wed 26 Aug** | ⭐ **All four, cold, answers covered** | + practice assessment |
| **Thu 27 Aug** | ⭐ **D2 only, then stop** | [`../EXAM-DAY.md`](../EXAM-DAY.md) |

⭐ **Note the ordering: you read the concept the same evening you labbed it.** Doing the lab
builds the memory; explaining it that night is what fixes it. ⭐ **Leave a week and you will have
to learn it twice.**

---

## 5. ⭐ The spacing rule — this is how you remember it

⭐ **Reading something four times in one evening does almost nothing. Reading it four times across
eight days does almost everything.** The forgetting curve is real and it is the reason cramming
fails.

```
Same day        the evening you labbed it
Next day        the first 20 minutes of the next evening   <- built into the schedule
Three days on   Revision A, Wed 26 Aug
A week on       Revision B, Thu 27 Aug
```

⭐ **Every one of those touches is already in the schedule above** — you do not need to track it.
⭐ **You only need to not skip the first 20 minutes of each evening**, which is the "next day"
touch, and it is the one people drop when they're tired. **It is the highest-value 20 minutes of
the day.**

⭐ **And interleave.** Jumping between D1, D2 and D4 in one session feels worse and works better
than blocking one domain — ⭐ **because the exam interleaves, and because the difficulty is the
mechanism, not a bug.**

---

## 6. ⭐ One mnemonic for the whole exam — U-A-W-G

⭐ **The four domains are four verbs, in the order things actually happen:**

```
U  Users        create identities      tenants, users, groups, external, hybrid
A  Access       control access         MFA, passwordless, SSPR, CA, risk
W  Workloads    authorise non-humans   apps, SPs, managed identities, consent
G  Governance   govern and prove       PIM, access reviews, packages, logs
```

⭐ **Every question on this exam is one of those four verbs.** When you are lost, ask which — it
narrows the answer space before you have read a single option.
*(Adopted from a ChatGPT-authored plan.)*

---

## 6. The three highest-value hooks, if you only keep three

| | |
|---|---|
| ⭐ **CA grant controls** | ⭐ **AND by default.** Exclusions beat inclusions. Block beats grant |
| ⭐ **`scp` vs `roles`** | `scp` = a user was there, rights are the **intersection**. `roles` = alone, full permission |
| ⭐ **PIM** | Eligible = allowed. Active = holding it. ⭐ **Permanent + active is the thing you're removing** |

> ⭐ **Final test, and it is the real one: explain any concept in here to an imaginary junior
> engineer, out loud, without notes, at all four levels.** ⭐ **The place you stall is the place
> the exam will find you.**

> **Related:** [`../EXAM-COUNTDOWN.md`](../EXAM-COUNTDOWN.md) — the day plan ·
> [`../GAP-DRILL.md`](../GAP-DRILL.md) — what the labs never covered ·
> [`../EXAM-DAY.md`](../EXAM-DAY.md) — technique ·
> [`../../RETENTION.md`](../../RETENTION.md) — the wider memory layer
