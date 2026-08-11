# Troubleshooting Method

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The most transferable topic in the repository.** Products change; this does not.
> It is also, unchanged, the method behind
> [`../../50-security-operations/incident-response/`](../../50-security-operations/incident-response/).

---

## 1. What it is

**A discipline for reducing a search space, under uncertainty, without guessing.**

Most people troubleshoot by pattern-matching: *"I've seen this before, try X."* That is fast when it
works and produces nothing when it fails — no narrowed space, no eliminated causes, no learning.

⭐ **The method is the opposite: every action must eliminate possibilities, whether or not it fixes
anything.**

```
symptom
   │
   ├─ ① STATE the observation precisely  (not "it's broken")
   ├─ ② FORM a hypothesis that is FALSIFIABLE
   ├─ ③ pick the test that ELIMINATES THE MOST, not the nearest one
   ├─ ④ run it, and RECORD the result — including the boring ones
   └─ ⑤ repeat on the surviving half
```

---

## 2. ⭐ The one idea that separates senior from mid

> **Choose the cheapest test that halves the search space — not the test nearest the symptom.**

Everyone's instinct is to investigate where the error appeared. ⭐ **The error appears at the end of
the chain; the cause is usually in the middle.** Testing the middle eliminates half the chain in one
move.

```
User → Client → Network → LB → App → DB → Storage
                            ▲
       ⭐ testing HERE eliminates half the chain either way
       Testing at the App (where the error surfaced) eliminates almost nothing
```

**Worked reasoning — "users can't sign in":**

| Test | Cost | ⭐ Eliminates |
|---|---|---|
| Read the app's error log | low | ⭐ **almost nothing** — you already know it fails |
| Restart the app | low | ⭐ **nothing, and destroys evidence** |
| ⭐ **Can *one* user sign in from a different network?** | low | ⭐ **half the space in one question** |
| Rebuild the environment | very high | everything, and teaches nothing |

⭐ **Row three is the senior move.** One question, one minute, and the answer splits the problem into
*identity/authorisation* or *network/client* regardless of which way it goes.

> ⭐ **A test that can only confirm what you already believe is not a test.** If both outcomes leave
> you in the same place, pick a different one.

---

## 3. ⭐ "It works on my machine" is an undeclared variable

This sentence is not an excuse — **it is a finding.** It says: *two environments differ, and nobody
has enumerated the difference.*

```
⭐ Working env  ≠  broken env  →  the DELTA is the answer
                                   enumerate it, don't argue about it
```

**The delta is almost always one of these, and it is worth memorising the list:**

| Delta | How it hides |
|---|---|
| **Identity** | you are an admin, they are not |
| **Network path** | you are on VPN, on-prem, or a different egress IP |
| **Version** | client, module, API version, model version |
| **State** | cached token, warm session, existing object |
| **Config / env vars** | different tenant, subscription, region |
| ⭐ **Encoding / line endings** | ⭐ invisible, and it bites — see §6 |

⭐ **Bisect the delta, do not debate it.** Make your environment more like theirs one variable at a
time, and the variable that flips the behaviour is the cause.

---

## 4. Worked example — bisecting a real failure

A pipeline that passed locally and failed in CI. **The naïve reading is "the code is wrong." The
method says: enumerate the delta.**

```powershell
# ① State it precisely. Not "CI is broken" — what EXACTLY differs?
#    Local:  ./tools/Build-CoverageRegister.ps1 -Check  → exit 0
#    CI:     same command, same commit               → exit 1 "STALE"

# ② Hypothesis, falsifiable: "the runner's files differ from mine."
#    Prediction if true: a byte-level comparison shows a difference.

# ③ The test that eliminates the most: compare a single file's SIZE,
#    because size is cheap and any difference kills the "code is wrong" theory outright.
$f    = '60-ai-and-secure-ai/azure-openai/README.md'
$disk = (Get-Item $f).Length
$blob = [int](git cat-file -s (git rev-parse "HEAD:$f"))
$lines= (Get-Content $f).Count
"disk=$disk  blob=$blob  lines=$lines  crlf-would-be=$($blob + $lines)"
```

```
disk=11564  blob=11564  lines=256  crlf-would-be=11820
```

⭐ **One command, and the code is exonerated.** The file is 256 bytes bigger when checked out with
CRLF — and the tool measures file sizes. **The hypothesis is now specific enough to test at scale:**

```powershell
# ④ How BIG is it? A cause that explains one file may not explain the failure.
$drift = 0; $total = 0
Get-ChildItem -Directory | Where-Object Name -match '^\d\d-' | ForEach-Object {
    Get-ChildItem $_.FullName -Directory -EA SilentlyContinue } | ForEach-Object {
    $files = Get-ChildItem $_.FullName -File -Recurse -EA SilentlyContinue
    $lf = ($files | Measure-Object Length -Sum).Sum
    $crlf = $lf + (($files | Where-Object Extension -in '.md','.ps1' |
                    ForEach-Object { (Get-Content $_.FullName).Count } ) |
                   Measure-Object -Sum).Sum
    $total++
    if ([math]::Round($lf/1KB,1) -ne [math]::Round($crlf/1KB,1)) { $drift++ }
}
"topics whose measurement changes under CRLF: $drift of $total"
```

```
topics whose measurement changes under CRLF: 66 of 144
```

⭐ **Now it is not a theory, it is a measurement**, and it is large enough to be the whole cause.

---

## 5. ⭐ Reproduce the failure, not the success

**The most common verification error, and it is subtle:**

> After fixing the above, running the tool locally passes. ⭐ **That proves nothing** — it passed
> locally *before* the fix too. **Locally is the environment where the bug does not occur.**

**The correct verification recreates the failing condition:**

```powershell
# Copy the repo, convert every text file to CRLF, and validate the LF-authored
# register inside it. This is the runner's condition, reproduced locally.
$sim = "$env:TEMP\crlf-sim"
robocopy . $sim /E /XD .git /NFL /NDL /NJH /NJS /NP | Out-Null
Get-ChildItem $sim -Recurse -File -Include *.md,*.ps1 | ForEach-Object {
    $t = [IO.File]::ReadAllText($_.FullName)
    [IO.File]::WriteAllText($_.FullName, (($t -replace "`r`n","`n") -replace "`n","`r`n"))
}
& "$sim\tools\Build-CoverageRegister.ps1" -Path $sim -Check; "exit=$LASTEXITCODE"
```

```
COVERAGE.md is current.
exit=0
```

⭐ **Reproduce the failure, then remove it. A test you were always going to pass is not evidence.**
This is the same principle as testing at `temperature=0` in
[`../../60-ai-and-secure-ai/ai-fundamentals/`](../../60-ai-and-secure-ai/ai-fundamentals/) §6, and
the same principle as break-fix labs throughout this repo: ⭐ **you have not demonstrated a control
until you have watched it stop something.**

---

## 6. ⭐ The invisible-cause list

When every visible thing checks out, the cause is in something that does not render. **Keep this
list; it is short and it is where days are lost:**

```
⭐ line endings          CRLF vs LF          — §4, and it cost two days of red CI
⭐ encoding              BOM, UTF-16, ANSI   — "the file looks identical"
⭐ trailing whitespace   in tokens, in YAML
⭐ homoglyphs            Cyrillic а vs Latin a, non-breaking space
⭐ clock skew            token "expired" that is not
⭐ DNS / TTL caching     you fixed it; the client hasn't noticed
⭐ token lifetime        the change is right, the SESSION is old
```

⭐ **The last two are the identity-specific ones and they cause more false diagnoses than anything
else in this repo.** Removing a user from a group does not end their session —
[`../../30-identity-and-nhi/conditional-access/`](../../30-identity-and-nhi/conditional-access/).
"The policy isn't working" is usually "the token predates the policy."

---

## 7. What breaks

**Restarting first.** ⭐ It sometimes fixes and always destroys evidence.

**Testing where the error appeared.** §2 — eliminates the least.

**Changing two things at once.** You cannot attribute the result.

**Not recording the boring results.** ⭐ An eliminated hypothesis is progress, and if it is not
written down you will re-test it.

**Arguing about the delta instead of enumerating it.** §3.

**Verifying in the environment that always worked.** §5 — the most common verification error.

**Stopping at the fix.** ⭐ A fix without a cause recurs, and you learn nothing transferable.

**Blaming the last change** without testing it. Often right, frequently not, and always untested.

**Escalating without the narrowed space.** Hand over what you *eliminated*, not just the symptom.

---

## 8. Customer discovery questions

*(Ask these of a team, not a system — they diagnose the process.)*

1. When something breaks, **what is the first action** taken? *(If it is "restart", that is the
   finding.)*
2. Are **eliminated hypotheses recorded** anywhere, or re-tested every incident?
3. How do you enumerate the **delta** between working and broken environments?
4. After a fix, do you **reproduce the original failure** to confirm it? *(§5.)*
5. Do post-incident writeups name a **cause**, or only a fix?
6. Who decides when to **stop investigating and restore service** — and is that separate from finding
   the cause?

---

## 9. Remember it

**Hook — "Halve the space, don't chase the symptom."**

**Analogy — twenty questions, played badly.** A novice guesses *"is it a hammer?"* — one object
eliminated out of thousands. ⭐ **An expert asks "is it bigger than a car?"** — half the world gone,
whatever the answer. **The novice's question is nearer the answer they hope for; the expert's is
further away and worth a thousand times more.** Troubleshooting is the same game, and "let me look at
the error log again" is *"is it a hammer?"*

**The one thing:** ⭐ **pick the test that eliminates the most, and make sure both outcomes teach you
something.** If a test can only confirm what you already believe, it is not a test — it is
reassurance. This single habit is what makes someone fast at problems they have never seen before,
which is precisely the skill an interview panel is trying to detect and the one product knowledge
cannot fake.

**Runner-up:** ⭐ **reproduce the failure before you claim the fix.** Passing in the environment that
never failed is not evidence.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 10. Self-test

1. What must every troubleshooting action do, whether or not it fixes anything?
2. Why is testing at the point of the error usually wrong?
3. What makes a test worthless?
4. What does "it works on my machine" actually tell you?
5. Name six common deltas between environments.
6. Why is verifying locally after fixing a CI bug insufficient?
7. Name five invisible causes.
8. Which two invisible causes dominate identity troubleshooting?
9. Why is restarting first a bad default?
10. What should you hand over when escalating?

<details>
<summary>Answers</summary>

1. ⭐ **Eliminate possibilities** — narrow the search space regardless of outcome.
2. The error surfaces at the **end of the chain**; the cause is usually in the middle, so testing the
   middle eliminates half.
3. ⭐ When **both outcomes leave you in the same place** — it confirms rather than discriminates.
4. ⭐ **Two environments differ and nobody has enumerated the difference.** It is a finding, not an
   excuse.
5. **Identity, network path, version, state, config/env, ⭐ encoding and line endings.**
6. ⭐ Because **local is the environment where the bug does not occur** — it passed before the fix too.
7. Line endings, encoding/BOM, trailing whitespace, homoglyphs, clock skew, DNS/TTL caching, token
   lifetime.
8. ⭐ **Token lifetime and DNS/TTL caching** — "the policy isn't working" is usually "the token
   predates the policy."
9. It ⭐ **destroys evidence**, and when it works you have learned nothing and it will recur.
10. ⭐ **What you eliminated**, not just the symptom — the narrowed space is the value.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** ⭐ — the §4/§5 bisection reproduced end to end. **Runnable right now with no
  subscription and no licence** — the repo's own CI failure is the worked example.
- **`break-fix/`** ⭐ — deliberately introduce one of the §6 invisible causes into a working script
  (a BOM, a homoglyph, a CRLF) and time how long it takes to find. **Do it three times; the third is
  much faster, and that is the point.**
- **`security/`** — the incident-response mapping: this method under time pressure with an adversary,
  cross-referenced to
  [`../../50-security-operations/incident-response/`](../../50-security-operations/incident-response/).
- **`operations/`** — a hypothesis log template: observation, hypothesis, test, result, eliminated.
- **`architecture-decisions/`** — ADR: restore-service and find-cause are separate tracks with
  separate owners.
- **`customer-use-cases/`** — §8 answered against a real team's incident process.
