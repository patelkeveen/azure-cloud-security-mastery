# LLD — Low Level Design

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The test: could a competent engineer who has never met you build this, without asking a
> single question?** Pairs with [`../hld/`](../hld/) and
> [`../configuration-checklists/`](../configuration-checklists/).

---

## 1. What it is

The buildable specification: every object, every name, every value, every exclusion — written for
the person who will implement it, and precise enough that two different engineers building from it
independently would produce identical configuration.

⭐ **An HLD can be argued with. An LLD can only be typed in correctly or incorrectly.**

---

## 2. Why it exists

⭐ **Because the alternative is a phone call.** Every ambiguity in an LLD becomes an interruption,
a guess, or a drift between environments:

| Without a real LLD | Consequence |
|---|---|
| ⭐ "Exclude break-glass" | ⭐ **which accounts? by object ID or UPN?** — a guess |
| "Name it sensibly" | ⭐ four naming conventions across one tenant |
| No exclusions listed | the service account gets locked out on day one |
| ⭐ **Nothing to diff against** | ⭐ **drift is undetectable** — you cannot prove today matches design |
| Build done from memory | ⭐ dev and prod silently differ |

⭐ **The last row is the one that matters long after delivery.** An LLD is the only artifact that
makes configuration drift *measurable*, because it is the declared expected state — see §6.

---

## 3. How it works underneath — the four properties

Every LLD entry must be:

```
① ⭐ UNAMBIGUOUS   one reading only
                   ✗ "exclude break-glass accounts"
                   ✅ ⭐ exclude object IDs 3f9a…, 7c21…  (UPNs shown for humans)

② COMPLETE        every field the object has, including the DEFAULTS you kept
                   ⭐ "left at default" is a decision — record it

③ ⭐ VERIFIABLE    each row has a way to read it back
                   ⭐ this is what turns an LLD into a drift test

④ TRACEABLE       every object cites the requirement and HLD decision
                   ⭐ REQ-022 → HLD §4.2 → LLD §7.3
```

⭐ **Property ② surprises people: you must record settings you did not change.** A default that is
silently accepted is indistinguishable from one that was never considered — and when Microsoft
changes that default (which happens), nobody can tell whether the old value was deliberate.

---

## 4. Worked example — one Conditional Access policy, fully specified

⭐ **This is what "buildable without asking" actually looks like.**

```
LLD §7.3   CA-004  Require phishing-resistant MFA for privileged roles
TRACE      REQ-022 (MUST)  ◄─  HLD §4.2 Option B

┌──────────────────────┬──────────────────────────────────────────────────────┐
│ Field                │ Value                                                 │
├──────────────────────┼──────────────────────────────────────────────────────┤
│ displayName          │ CA-004-Admin-PhishResistant-Prod                      │
│ state                │ ⭐ enabledForReportingButNotEnforced                   │
│                      │    ⭐ then 'enabled' at step 9 of the checklist        │
│ includeRoles         │ Global Administrator      62e90394-69f5-4237-9190-…   │
│                      │ Privileged Role Admin     e8611ab8-c189-46e8-94e1-…   │
│                      │ Security Administrator    194ae4cb-b126-40b2-bd5b-…   │
│ ⭐ excludeUsers       │ ⭐ breakglass1@kwin.onmicrosoft.com  3f9a1c72-…        │
│                      │ ⭐ breakglass2@kwin.onmicrosoft.com  7c21e480-…        │
│ includeApplications  │ All                                                   │
│ clientAppTypes       │ all           ⭐ (default retained - deliberate)       │
│ grantControls        │ authenticationStrength                                │
│  └ authStrength      │ Phishing-resistant MFA  00000000-0000-0000-0000-…04   │
│  └ operator          │ OR            ⭐ single control; operator is moot      │
│ sessionControls      │ none          ⭐ (default retained - deliberate)       │
└──────────────────────┴──────────────────────────────────────────────────────┘

⭐ VERIFY
  (Get-MgIdentityConditionalAccessPolicy -Filter "displayName eq
   'CA-004-Admin-PhishResistant-Prod'").GrantControls.AuthenticationStrength.Id
  EXPECT  00000000-0000-0000-0000-000000000004

⭐ ROLLBACK
  Set-MgIdentityConditionalAccessPolicy -Id <id> -State 'disabled'
```

⭐ **Object IDs *and* UPNs.** The GUID is what the system uses and cannot be ambiguous; the UPN is
what a human can sanity-check. ⭐ **Give both — a document with only GUIDs is unreviewable, and one
with only names is un-buildable.**

⭐ **`state: enabledForReportingButNotEnforced` with a note about when it changes** is the single
most important row. It encodes the *"watch first"* pattern that runs through
[`../../30-identity-and-nhi/conditional-access/`](../../30-identity-and-nhi/conditional-access/):
⭐ **deploy in report-only, read the impact, then enforce.** An LLD that specifies `enabled` on day
one has designed an outage.

---

## 5. Naming standards — decide once, in the LLD

⭐ **Naming is not cosmetic; it is how objects are found, filtered and audited at 3 a.m.**

```
<TYPE>-<NN>-<SCOPE>-<PURPOSE>-<ENV>

CA-004-Admin-PhishResistant-Prod
GRP-SEC-PIM-Approvers-Prod
SPN-MIG-BitTitan-Temp          ⭐ 'Temp' in the name = an expiry conversation
```

| Rule | Why |
|---|---|
| ⭐ Number CA policies | ⭐ they sort, and "CA-004" is sayable on a call |
| Environment suffix | ⭐ prevents the prod/test mistake that has no undo |
| ⭐ Purpose, not product | ⭐ survives the product being renamed |
| Never spaces in group names | scripting and filters break on them |
| ⭐ Mark temporary objects | ⭐ everything temporary becomes permanent unless named |

⭐ **`SPN-MIG-BitTitan-Temp` is a small idea with a large payoff.** It is the migration service
principal from
[`../../45-m365-migration-engineering/migration-tools/`](../../45-m365-migration-engineering/migration-tools/) —
and the word `Temp` in its display name is what causes someone to ask, six months later, why it
still exists.

---

## 6. Commands — the LLD as an executable drift test

⭐ **This is where an LLD stops being paperwork.** Express the design as data, then compare reality
to it:

```powershell
$design = @{
  'CA-004-Admin-PhishResistant-Prod' = @{
     State = 'enabled'
     AuthStrengthId = '00000000-0000-0000-0000-000000000004'
     ExcludeUsers = @('3f9a1c72-...','7c21e480-...')
  }
}

foreach ($name in $design.Keys) {
  $live = Get-MgIdentityConditionalAccessPolicy -All |
          Where-Object DisplayName -eq $name
  if (-not $live) { "MISSING : $name"; continue }
  $d = $design[$name]
  if ($live.State -ne $d.State) { "DRIFT   : $name state $($live.State) != $($d.State)" }
  if ($live.GrantControls.AuthenticationStrength.Id -ne $d.AuthStrengthId) {
      "DRIFT   : $name authStrength" }
  $missing = @($d.ExcludeUsers | Where-Object { $_ -notin $live.Conditions.Users.ExcludeUsers })
  if ($missing) { "⭐ DRIFT : $name break-glass NOT excluded" }
}
```

```
DRIFT   : CA-004-Admin-PhishResistant-Prod state enabledForReportingButNotEnforced != enabled
```

⭐ **One line of output, and it is the truth about the tenant.** ⭐ **A design document you can *run*
is worth ten you can only read** — and this is the artifact that makes a handover defensible, because
the customer can re-run it every month without you.

**Capture as-built at handover — the LLD's final form:**

```powershell
Get-MgIdentityConditionalAccessPolicy -All |
  ConvertTo-Json -Depth 10 | Out-File .\as-built-ca-2026-08-18.json
```

⭐ **As-built ≠ as-designed, always.** Something changed during build. The handover document must
state which rows differ and why — see [`../handover/`](../handover/).

---

## 7. When and where

| Situation | LLD depth |
|---|---|
| Anything another person will build | ⭐ **full** |
| Anything you must prove later | ⭐ full — ⭐ it is the audit evidence |
| One-line change you make yourself | a change record, not an LLD |
| ⭐ Managed service handover | ⭐ **full + the drift script** |

⭐ **Write the LLD before the build, not after.** An LLD reverse-engineered from a finished tenant
documents what you did, including the mistakes — ⭐ **it cannot catch them, because it was copied
from them.**

---

## 8. What breaks

| Symptom | Root cause | Fix |
|---|---|---|
| Implementer phones you | ambiguity | ⭐ §3 property ① — one reading only |
| Prod and test differ | build from memory | ⭐ the §6 drift script, both environments |
| ⭐ Lockout on go-live | ⭐ exclusions not specified | ⭐ break-glass rows are mandatory in every policy |
| Auditor cannot verify | no `VERIFY` line per row | add read-back commands |
| Default changed by Microsoft | ⭐ default never recorded | record retained defaults explicitly |
| Nobody can find an object | ⭐ no naming standard | §5, decided once |

⭐ **The lockout row is the one that ends careers on a Friday night.** Every enabled policy in an LLD
must carry its break-glass exclusion **as a written row**, not as an assumption — the same rule the
sprint enforces in
[`../../SC-300-SPRINT/TROUBLESHOOTING.md`](../../SC-300-SPRINT/TROUBLESHOOTING.md) §5.

---

## 9. Customer discovery questions

1. ⭐ **"Who will build this — your team or mine?"** — decides the required precision
2. "Do you have an existing naming convention?" (⭐ use theirs; consistency beats elegance)
3. ⭐ **"Which accounts must never be locked out?"**
4. "Is there a test tenant, and does it match production?"
5. "Who audits this, and what evidence format do they accept?"
6. ⭐ **"How will you detect configuration drift after we leave?"**
7. "Are there objects that must be deleted at the end of the project?"

---

## 10. Remember it

**Hook — `U C V T`: Unambiguous, Complete, Verifiable, Traceable.** Four properties; ⭐ **Verifiable
is the one that turns a document into a test.**

**Analogy — a recipe versus a menu description.** ⭐ **The menu says "slow-braised lamb"; the recipe
says 140 °C, 4 hours, 2.1 kg shoulder.** The analogy predicts each property: **two cooks working
from the same recipe produce the same dish (unambiguous), the recipe lists the salt even though
everyone uses salt (complete), you can taste it against the description (verifiable), and it says
which menu item it is for (traceable).** ⭐ **And a recipe written down *after* cooking preserves
your mistakes** — which is exactly why the LLD precedes the build.

**The one line:** ⭐ **If a competent stranger cannot build it without phoning you, it is not an
LLD.**

---

## 11. Self-test

1. The one-sentence test for a finished LLD?
   → ⭐ A competent engineer who has never met you can build it without asking a question.
2. Why record settings you did not change?
   → ⭐ A silent default is indistinguishable from an unconsidered one, and defaults change.
3. Why give both object ID and UPN?
   → ⭐ GUIDs are unambiguous for machines; UPNs make the document reviewable by humans.
4. What state should a new CA policy specify, and why?
   → ⭐ Report-only, with a defined step at which it becomes enabled — watch first.
5. What turns an LLD into a drift test?
   → ⭐ A `VERIFY` read-back per row, expressed as data (§6).
6. Why must the LLD precede the build?
   → ⭐ Reverse-engineered documentation copies the mistakes instead of catching them.
7. Which row is mandatory in every enabled-policy spec?
   → ⭐ The break-glass exclusion.

---

## 12. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | one fully specified object in the §4 format, built and verified |
| `operations` | ⭐ the drift script and one run showing a real difference |
| `security` | break-glass exclusion rows present in every enabled-policy spec |
| `break-fix` | one as-built vs as-designed difference, explained |
| `architecture-decisions` | the naming standard, decided once and applied |
