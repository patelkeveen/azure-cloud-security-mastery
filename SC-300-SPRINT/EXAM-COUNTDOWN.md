# Exam countdown — SC-200 on Sat 12 Sep 2026, SC-300 on Fri 18 Sep 2026

> ## ⚠ SUPERSEDED — 2026-09-14
>
> **Read [`FINAL-FOUR.md`](FINAL-FOUR.md) instead.** Two things changed on 2026-09-14:
>
> | | |
> |---|---|
> | **SC-200** | **POSTPONED to October 2026.** It is no longer first, and no longer in this window |
> | **SC-300** | **Friday 18 September 2026, 07:30 IST**, online proctored — the only exam left |
> | **M365 E5 trial** | **ENDED 2026-09-10.** Azure credits exhausted |
>
> **There is no tenant.** Every lab instruction in this pack — `DAY-1.md`…`DAY-7.md`, the
> `Day0`/`Day1` scripts, the audit-log fix below — is moot. Do not open them.
>
> What is still good here: the *technique* and the *content*. What is stale: every date, every
> lab step, and anything that assumes a live E5 licence.
>
> **New for this window:** [`FINAL-FOUR.md`](FINAL-FOUR.md) (the plan, verified exam logistics and
> the 07:30 protocol) · [`BLIND-SPOTS.md`](BLIND-SPOTS.md) (**three live skill groups with zero
> coverage in `EXPLAIN/`**) · [`DISCRIMINATORS.md`](DISCRIMINATORS.md) (83 pairs with exam tells).


> ⭐ **This file overrides the pacing in [`README.md`](README.md) §4.** That sprint was built to
> produce a portfolio on a 30-day licence clock; this is triage against an exam date.
> **Rebuilt 2026-08-27 after the exam moved from 28 Aug to 31 Aug. Four days left.**
>
> ⚠ **I do not know which lab days you actually completed** — `SC-300-SPRINT/evidence/` holds one
> file, dated 12 Aug. So this plan is ordered by **exam weight**, not by lab number: if time runs
> out, what is left undone is the least valuable thing available.

---

## 1. ⭐ The arithmetic, stated honestly

**Four days. Ordered by what the exam actually weights**, so the tail is the cheapest thing to lose.

```
Aug 27 Thu  D-4  <- TODAY   D2 Authentication & Conditional Access     25-30%
Aug 28 Fri  D-3             D3 Workload identities + D4 Governance     20-25% each
Aug 29 Sat  D-2             D1 User identities + the GAP-DRILL gaps    20-25%
Aug 30 Sun  D-1             Everything cold, timed practice, stop 16:00
Aug 31 Mon  D-0  EXAM
```

⭐ **Why D2 today and not "the next lab you haven't done":** it is the single largest block of
marks, and with four days left you spend them in weight order. ⭐ **A lab you skip in D3 costs
less than an hour you never spent on Conditional Access.**

⚠ **If you have already labbed a domain, do not re-lab it** — read its [`EXPLAIN/`](EXPLAIN/)
file out loud instead and move to the drill. Recall is what is short now, not exposure.

---

## 2. ⚠ Day 1 is not finished. Fix this before anything else today

**Unified audit logging is genuinely OFF**, and the error message you hit sends you the wrong way.

Microsoft Learn (`purview/audit-log-enable-disable`, rev 2026-06-19):

> ⭐ *"unmanaged tenants that use free trials of enterprise licenses don't have auditing enabled
> by default … you must manually enable auditing."*

⭐ **So your `False` reading is true, not the stale-property artifact.** (That artifact is a
*different* trap worth knowing: in **Security & Compliance PowerShell** the property reads `False`
even when auditing is on. Read it in **Exchange Online PowerShell** or the answer is meaningless.
You did — so yours is real.)

The PowerShell path is a dead end on this tenant: the proxy throws
`InvalidOperationInDehydratedContextException` telling you to run
`Enable-OrganizationCustomization`, while `Get-OrganizationConfig` reports `IsDehydrated: False`
and `Enable-OrganizationCustomization` reports *"already enabled"*. ⭐ **Stop fighting it. Use the
portal — it is the documented path, not a workaround:**

```
1. https://purview.microsoft.com
2. Audit card   (or: View all solutions > Core > Audit)
3. Click the banner: "Start recording user and admin activity"
```

⭐ **Needs the *Audit Logs* role in Exchange Online** — the `Organization Management` or
`Compliance Management` role group. Global Admin alone does not always carry it.

Then **prove it**, because a flag records intent and only a search records capture:

```powershell
Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-1) -EndDate (Get-Date) -ResultSize 5
```

⚠ **Allow up to 60 minutes.** Zero rows after an hour means it is still off.

⭐ **Do this in the first ten minutes of today.** Audit captures **forward only** — it cannot
backfill 19 August, and Day 7's Identity Protection labs read the history this produces.

**Also from Day 1, still outstanding:** the six portal items in
`Day1-Enable-Telemetry.ps1` §3. ⭐ **Only two matter for the exam** — Identity Protection (already
on, good) and sign-in volume. Defender onboarding and attack simulation are SC-200. **Skip them
until 29 August.**

---

## 3. ⭐ The cut — what to stop doing, and why it costs you nothing

⭐ **The daily contract in [`README.md`](README.md) §5 has six steps. Steps 4–6 score zero exam
marks.**

```
[] Read the topic README first      <- KEEP, this is the revision
[] Run the lab                       <- KEEP
[] Break something deliberately      <- KEEP (see below)
[] File evidence with New-LabEvidence.ps1   <- DEFER to 29 Aug
[] Re-run Build-CoverageRegister.ps1        <- DEFER to 29 Aug
[] Commit                                   <- DEFER to 29 Aug
```

⭐ **This is not abandoning the evidence goal — it is sequencing it.** The tenant keeps its
configuration. Exports, screenshots and policy JSON can all be captured on **29 August–9
September**, which is still inside the E5 trial (expires **2026-09-10**). The exam cannot be
moved; the evidence sweep can.

⚠ **One exception, and it is genuinely irreversible: capture the verbatim error text from every
deliberate failure, in the moment.** Two minutes into a scratch file. Error strings are the one
artifact you cannot reconstruct next week, and
[`00-foundations/troubleshooting-method`](../00-foundations/troubleshooting-method/) is built on
recognising them.

```powershell
# The whole ceremony, compressed to something you will actually do
"$(Get-Date -f 'MM-dd HH:mm') | LAB 3.3 | $($Error[0].Exception.Message)" |
    Add-Content .\SC-300-SPRINT\evidence\errors-verbatim.log
```

⭐ **Saves ~6 hours across six days. That is exactly the revision time you need.**

---

## 4. The four days, in detail

| Day | Do this | Then drill |
|---|---|---|
| ⭐ **D-4 Thu 27** | ⭐ **[D2 all 13 concepts](EXPLAIN/D2-AUTH-AND-ACCESS.md), out loud.** If CA is unlabbed: policy set in report-only, What-If, the AND trap | [`GAP-DRILL.md`](GAP-DRILL.md) §2 roles |
| **D-3 Fri 28** | [D3](EXPLAIN/D3-WORKLOAD-IDENTITIES.md) `scp` vs `roles`, consent, SCIM · [D4](EXPLAIN/D4-GOVERNANCE.md) PIM 2×2, reviews, packages | §5 connected orgs · §6 consent |
| **D-2 Sat 29** | [D1](EXPLAIN/D1-USER-IDENTITIES.md) all 10 · ⭐ **the material no lab covered** | §1 admin units · §3 hybrid · §4 groups · §7 external |
| **D-1 Sun 30** | ⭐ **All four EXPLAIN files cold, answers covered** · Microsoft practice assessment, timed · score it and write down *why* each miss was wrong | ⭐ **Stop at 16:00** |
| **D-0 Mon 31** | [`EXAM-DAY.md`](EXAM-DAY.md) + the ten one-liners. Nothing new | — |

⭐ **The 104 practice questions are live in your dashboard** at `localhost:9190` → SC-300, and the
[Lexicon](sc-300-lexicon.html) has 274 terms with 83 traps flagged and a *hide known* filter.

---


## 5. ⭐ The evening block — 90 minutes, every day, non-negotiable

⭐ **This is the part that was missing, and it is the part that passes exams.** Labs build
capability; the exam tests *recall under time pressure* and *discrimination between options that
look alike*. Those are trained separately.

```
20 min   ⭐ Yesterday's material, cold. Cover the answer, SAY IT OUT LOUD.
40 min   Today's concepts from EXPLAIN/ - all four levels, out loud
20 min   Today's section of GAP-DRILL.md
10 min   Write down every "and then it sort of..." you said. That list is tomorrow's 20 min.
```

⭐ **The out-loud part is not optional and it is not embarrassing — it is the entire mechanism.**
Reading is recognition. The exam tests recall, and ⭐ **so does every interview you will sit.**

| Evening of | [`EXPLAIN/`](EXPLAIN/) — four levels each | [`GAP-DRILL.md`](GAP-DRILL.md) |
|---|---|---|
| D-4 Thu 27 | [D1](EXPLAIN/D1-USER-IDENTITIES.md) §1–5 — Entra, tenant, identities, groups, ⭐ AUs | §1–2 |
| D-3 Fri 28 | ⭐ [D2](EXPLAIN/D2-AUTH-AND-ACCESS.md) §8–11 — ⭐ **CA, strengths, CAE** | §3 |
| D-2 Sat 29 | [D4](EXPLAIN/D4-GOVERNANCE.md) §1–2 PIM + [D1](EXPLAIN/D1-USER-IDENTITIES.md) §6 roles | §4 |
| D-1 Sun 30 | [D4](EXPLAIN/D4-GOVERNANCE.md) §3–7 — reviews, packages, lifecycle | §5 |

⭐ **You read each concept the same evening you labbed it.** The lab builds the memory; explaining
it that night is what fixes it. ⭐ **Leave it a week and you learn it twice.**

---

## 6. Revision A — folded into D-1 (Sun 30 Aug)

⭐ **No new material. None.** Anything unlearned by tonight stays unlearned.

```
09:00  GAP-DRILL.md end to end, cold, answers covered          2.5 h
12:00  RETENTION.md sec.1 numbers, sec.4 pairs, sec.6 reflexes 1.5 h
14:00  Microsoft Learn practice assessment, full and timed     1 h
15:00  Score it. Write down every wrong answer AND WHY.        1 h
16:30  Re-read only the topics behind the wrong answers        2 h
```

⭐ **The "and why" is the whole exercise.** A wrong answer you cannot explain will be wrong
again. Sort your errors into three buckets — *didn't know it* (go read), *knew it and misread the
question* (a technique problem, see [`EXAM-DAY.md`](EXAM-DAY.md)), *knew it and second-guessed
myself* (stop doing that; first instinct on recall questions is usually right).

⭐ **Free and official:** the practice assessment on the
[SC-300 exam page](https://learn.microsoft.com/credentials/certifications/exams/sc-300/). Take it
here, not on exam eve — you want time to act on the result.

---

## 7. Exam eve — Sun 30 Aug, stop at 16:00

```
09:00  Only the weak areas from yesterday's scoring          3 h
12:00  Second practice pass, timed                           1 h
14:00  90-second refresher: RETENTION.md sec.9               0.5 h
15:00  Read EXAM-DAY.md once                                 0.5 h
16:00  ⭐ STOP. Confirm exam logistics. Do something else.
```

⭐ **Stopping at 16:00 is a technique, not a reward.** Cramming on exam eve reliably costs more
in fatigue than it adds in recall, and the last thing you read is the thing most likely to
crowd out something you already knew.

⚠ **Confirm before you close the laptop:** booking time and time zone, ID that matches the
booking name exactly, and — if it is an online proctored sit — the room and system check. **The
system check fails often enough that discovering it at the start of the exam is a real risk.**

---

## 8. What this plan does not pretend

⭐ **It does not make you good at hybrid identity.** You have no domain controller, so PHS, PTA,
federation, Entra Connect and password writeback are **theory only** — [`GAP-DRILL.md`](GAP-DRILL.md)
§3 gets you to exam-answerable, not to competent. ⭐ **Say that out loud in an interview and it
lands as judgement; imply otherwise and it collapses on the first follow-up.**

⭐ **It does not produce the portfolio.** WRITTEN stays **0/144** through 28 August by design.
The evidence sweep resumes 29 August with the trial still live until 10 September.

⭐ **It does not touch Azure — with one optional exception.** You have a subscription
(`912ac3b8-d003-48d1-8266-e4d029ba1fd7`, RG `sc-300-lab-cin-rg-01`) and **₹19,130 of credit that
expires 2026-09-10 — the same day as the E5 trial.** ⚠ **Sentinel, Defender for Cloud and Foundry
are SC-200 and SC-500 — not one mark on SC-300.** **29 August.**

⭐ **The exception is a real domain controller**, because it is the only thing that converts §8's
"hybrid identity is theory only" into something you have actually seen:
[`35-active-directory-and-hybrid-identity/ad-ds/lab/`](../35-active-directory-and-hybrid-identity/ad-ds/lab/).
Deploy + promote is **~90 minutes, mostly waiting**, and costs about **₹120**.

> ⭐ **Optional, Day 6 evening only, and only if Day 6 finishes on time.** Hybrid is ~5–8% of the
> exam and it tests the *decision model*, not `Install-ADDSForest`. ⭐ **The full hybrid track
> belongs to 29 Aug – 10 Sep, when both clocks are still live.** If Day 6 runs long, skip it
> without guilt — Conditional Access is worth five times as much.

> ⭐ **Related:** [`GAP-DRILL.md`](GAP-DRILL.md) — what the sprint never covered ·
> [`EXAM-DAY.md`](EXAM-DAY.md) — technique and the morning of ·
> [`README.md`](README.md) — the original 30-day framing ·
> [`../RETENTION.md`](../RETENTION.md) — the memory layer ·
> [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) — when a lab will not start
