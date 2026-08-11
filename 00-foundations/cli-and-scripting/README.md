# CLI and Scripting

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Every audit in this repository is a filter over a stream.** Once you see that, the queries stop
> being things to memorise.

---

## 1. ⭐ The idea that makes PowerShell click

> **Bash pipes TEXT. PowerShell pipes OBJECTS.**

```
bash          ps aux | grep ssh | awk '{print $2}'
                          ▲            ▲
              ⭐ re-parsing text that was formatted for a human

PowerShell    Get-Process | Where-Object Name -eq 'ssh' | Select-Object Id
                          ▲
              ⭐ properties were never destroyed, so there is nothing to re-parse
```

⭐ **The bash version works until the output format changes** — a longer username, a space in a path,
a localised column header. **The PowerShell version cannot break that way**, because the data never
became text.

**The consequence for security work is direct and it is the reason this topic exists:**

> ⭐ **Never grep formatted output. Ask for structured data and filter it.**

```powershell
# ✗ FRAGILE - parsing a table meant for humans
az role assignment list -o table | Select-String 'Owner'

# ✅ ROBUST - filter server-side, then work with real objects
az role assignment list --all --query "[?roleDefinitionName=='Owner']" -o json |
  ConvertFrom-Json | Select-Object principalName, scope
```

⭐ **`--query` is JMESPath and runs before the data reaches you** — less transferred, nothing to
misparse, and the filter is explicit rather than a coincidence of spacing.

---

## 2. ⭐ The audit pattern, once

**Almost every finding in this repo is the same four-step shape.** Learn it once and you can write
the query for a service you have never used:

```
① ENUMERATE   list every object of a kind          (…list --all)
② PROJECT     keep only the fields that decide      (--query / Select-Object)
③ ⭐ ORDER    put the worst first                   (Sort-Object)
④ JUDGE       the eye does the last step
```

```powershell
# The canonical example: role assignments, broadest scope first
az role assignment list --all --query "[].{Principal:principalName, \
    Type:principalType, Role:roleDefinitionName, Scope:scope}" -o json |
  ConvertFrom-Json |
  Sort-Object { $_.Scope.Length } |          # ⭐ step ③ — shortest scope = broadest
  Format-Table -AutoSize
```

⭐ **Step ③ is the one people skip, and it is what turns a 400-row dump into a finding.** A wall of
rows tells you nothing; the same rows sorted by blast radius put the answer on line one. **This is
why every audit in this repository sorts by scope length** — the technique is identical in
[`../../30-identity-and-nhi/`](../../30-identity-and-nhi/),
[`../../60-ai-and-secure-ai/model-access-control/`](../../60-ai-and-secure-ai/model-access-control/)
and [`../../60-ai-and-secure-ai/ai-pipeline-nhi/`](../../60-ai-and-secure-ai/ai-pipeline-nhi/).

---

## 3. ⭐ Reversible by construction

**A read-only script is safe by definition. A writing script needs proof before it runs.**

```powershell
function Remove-StalePrincipal {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]   # ⭐ the whole point
    param([Parameter(Mandatory)][string]$Id)

    if ($PSCmdlet.ShouldProcess($Id, 'Delete service principal')) {
        Remove-MgServicePrincipal -ServicePrincipalId $Id
    }
}
```

```powershell
Remove-StalePrincipal -Id abc-123 -WhatIf
```

```
What if: Performing the operation "Delete service principal" on target "abc-123".
```

⭐ **`SupportsShouldProcess` costs one attribute and one `if`, and it converts an irreversible script
into one that can be rehearsed.** ⚠ Note: `-WhatIf` only works if the *author* wired it up — it is
not free, and **assuming an unfamiliar script supports it is how people delete things.**

**The three rules, in order of value:**

| Rule | Why |
|---|---|
| ⭐ **Separate the finding from the fix** | Run the read-only audit, review the output, *then* feed it to the writer |
| ⭐ **Make it idempotent** | Safe to re-run — the difference between a script and a landmine |
| **Log what you changed** | ⭐ Not what you *intended* — capture the actual response |

⭐ **"Separate the finding from the fix" is the habit that prevents the worst incidents**, because it
puts a human between the query and the destruction. A query with a bug produces a wrong list; a
combined query-and-delete with a bug produces an outage.

---

## 4. Worked example — a safe remediation, end to end

```powershell
# ① FIND (read-only, safe to run anywhere, safe to re-run)
$stale = Get-MgServicePrincipal -All |
  Where-Object { $_.DisplayName -match '^ai-|^mi-' } |
  ForEach-Object {
    $owners = @(Get-MgServicePrincipalOwner -ServicePrincipalId $_.Id -EA SilentlyContinue)
    [pscustomobject]@{
      Name = $_.DisplayName; Id = $_.Id
      Owners = $owners.Count
      Created = $_.AdditionalProperties.createdDateTime
    }
  } | Where-Object Owners -eq 0

# ② REVIEW — ⭐ a human looks at this before anything is touched
$stale | Format-Table -AutoSize
$stale | Export-Csv .\stale-principals.csv -NoTypeInformation

# ③ REHEARSE
$stale | ForEach-Object { Remove-StalePrincipal -Id $_.Id -WhatIf }

# ④ ACT, capturing the ACTUAL result rather than assuming success
$log = foreach ($s in $stale) {
    try   { Remove-StalePrincipal -Id $s.Id -Confirm:$false
            [pscustomobject]@{ Id=$s.Id; Name=$s.Name; Result='removed' } }
    catch { [pscustomobject]@{ Id=$s.Id; Name=$s.Name; Result="FAILED: $($_.Exception.Message)" } }
}
$log | Export-Csv .\removal-log.csv -NoTypeInformation
```

⭐ **Step ④'s `try/catch` is not defensive padding — it is the difference between a log and a
guess.** Without it, a script that silently fails on 40 of 100 objects reports the same as one that
succeeded, and you will not find out until the next audit.

---

## 5. The traps that actually bite

| Trap | ⭐ What happens |
|---|---|
| **`$ErrorActionPreference` default** | ⭐ **Non-terminating errors do not stop the loop** — set `'Stop'` and use try/catch |
| **A single object is not an array** | ⭐ `$x.Count` is `$null` for one item — wrap in `@()` |
| ⭐ **`-eq` on collections filters** | `$a -eq $b` returns *matching elements*, not `$true` |
| **String vs object comparison** | `Where-Object Name -eq 'x'` is not `Where-Object { $_.Name -eq 'x' }` for edge cases |
| ⭐ **Output not captured** | Uncaptured output pollutes the pipeline; use `$null =` or `Out-Null` |
| **Secrets in history** | ⭐ `Get-History`, `~/.bash_history` — see [`../linux-and-windows/`](../linux-and-windows/) §5 |

⭐ **The array trap is the one that produces silently wrong audits.** A sweep that finds exactly one
over-permissioned account reports `Count` as blank, a `-gt 0` check fails, and **the finding is
dropped precisely because it was small enough to be the real one.** Always `@()`.

---

## 6. What breaks

**Grepping formatted output.** §1 — breaks on spacing, locale and length.

**Filtering client-side when the API can filter.** §1 — slower and more fragile.

**No sort by blast radius.** §2 — a dump instead of a finding.

**Assuming `-WhatIf` works.** §3 — ⭐ only if the author wired it up.

**Combining find and fix.** §3 — a query bug becomes an outage.

**Not capturing actual results.** §4 — a log of intentions.

**Default `$ErrorActionPreference`.** §5 — loops continue past failures.

**Single object treated as a collection.** §5 — ⭐ drops the finding.

**Secrets on the command line.** They land in history, in logs, and in process listings.

**Scripts that are not idempotent.** ⭐ Re-running should be boring.

---

## 7. Customer discovery questions

1. Are audit scripts **read-only**, and is the fix a separate step? *(§3.)*
2. Do your scripts **parse table output** or query structured data? *(§1.)*
3. Do remediation scripts support **`-WhatIf`**, and has anyone verified it?
4. Do you log **what actually changed**, or what was attempted? *(§4.)*
5. Are scripts **idempotent** — is re-running safe?
6. Where do the scripts run, **as which identity**, and does it hold standing permissions?
7. Do any scripts take **secrets as parameters**?

---

## 8. Remember it

**Hook — "Objects, not text. Find, then fix."**

**Analogy — a receipt versus a shopping list.** ⭐ **`grep` on formatted output is reading a
photograph of a receipt** — it works until someone reprints it with wider columns. **An object
pipeline is being handed the itemised list itself**, where "price" is a field rather than the thing
that happens to be after the third space. **And `-WhatIf` is reading the order back before you pay.**

**The one thing:** ⭐ **separate the finding from the fix.** Run the read-only audit, put the output in
front of a human, *then* feed the reviewed list to the writer. It costs one extra step and it is the
difference between a query bug producing a wrong CSV and producing an outage. ⭐ **Every serious
scripting incident is the same shape: someone combined the search and the destruction, and the search
was wrong.**

**Runner-up:** ⭐ **wrap collections in `@()`.** A single result has no `.Count`, so the audit that
found exactly one problem silently reports none — and one is usually the real finding.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. What does PowerShell pipe that bash does not, and why does it matter for audits?
2. Why is `--query` better than piping to `Select-String`?
3. Name the four steps of the audit pattern. Which is most often skipped?
4. Why sort by scope length?
5. What does `SupportsShouldProcess` give you, and what is the caveat?
6. Why separate the find from the fix?
7. Why is `try/catch` around a remediation loop essential?
8. What does the default `$ErrorActionPreference` do in a loop?
9. ⭐ Why can a single-result audit silently report nothing?
10. Name three places a secret on the command line ends up.

<details>
<summary>Answers</summary>

1. ⭐ **Objects.** Properties are never destroyed, so there is nothing to re-parse and nothing to
   break when formatting changes.
2. It filters ⭐ **server-side, before the data reaches you** — less transferred, explicit rather than
   dependent on spacing or locale.
3. **Enumerate → project → ⭐ order → judge.** ⭐ **Ordering** is skipped, and it is what turns a dump
   into a finding.
4. ⭐ **Shortest scope = broadest blast radius**, so the worst row lands first.
5. **`-WhatIf` / `-Confirm` rehearsal.** ⚠ Caveat: ⭐ it only works if the **author wired it up** —
   never assume it on an unfamiliar script.
6. ⭐ It puts a human between the query and the destruction: a query bug then produces a **wrong
   list** rather than an **outage**.
7. Because without it a script that fails on part of the set ⭐ **reports the same as one that
   succeeded**.
8. ⭐ Non-terminating errors **do not stop the loop** — it continues past failures.
9. ⭐ A single object **is not an array**, so `.Count` is `$null` and a `-gt 0` check fails. Wrap in
   `@()`.
10. **Shell history, logs, and process listings** (`ps`, `/proc/<pid>/cmdline`).

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — rewrite three text-parsing audits as object pipelines and compare them on a
  deliberately awkward input (a long display name, a space in a path).
  **Runnable now, no subscription.**
- **`break-fix/`** ⭐ — build an audit that returns exactly **one** result and watch a `-gt 0` check
  drop it; fix with `@()`. **One screen, and it teaches §5 permanently.** Then run a remediation
  without `try/catch` against a set where some deletions fail, and compare the log to reality.
- **`security/`** — inventory of remediation scripts: which are read-only, which support `-WhatIf`,
  which run as which identity, which take secrets as parameters.
- **`operations/`** — the find/review/rehearse/act runbook from §4 as the standard shape.
- **`architecture-decisions/`** — ADR: audits are read-only and separate from remediation; scripts run
  under a federated identity rather than a stored secret.
- **`customer-use-cases/`** — §7 answered against a real automation estate.
