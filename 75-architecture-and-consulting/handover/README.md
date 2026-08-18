# Handover

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The engagement ends when the customer can run it without you — not when the build finishes.**
> Pairs with [`../customer-training/`](../customer-training/),
> [`../sop-and-runbooks/`](../sop-and-runbooks/) and [`../lld/`](../lld/).

---

## 1. What it is

The formal transfer of a working system and the ability to operate it: as-built documentation,
procedures, credentials, known issues, a support transition, a hypercare period, and a signed
acceptance against the requirements agreed at the start.

⭐ **Handover is a gate with criteria, not an email with attachments.**

---

## 2. Why it exists

⭐ **Without a defined handover, an engagement does not end — it fades.** The consequences are
concrete and they fall on you:

| Without a handover gate | Consequence |
|---|---|
| ⭐ No acceptance sign-off | ⭐ **final invoice disputed** |
| Support boundary undefined | ⭐ free support for months |
| ⭐ Credentials transferred badly | ⭐ **your access persists — a real liability** |
| Known issues undocumented | ⭐ they become "faults you left" |
| ⭐ As-built ≠ as-designed, unstated | the next engineer trusts the wrong document |
| No hypercare window | ⭐ every week-three question is an emergency |

⭐ **The credentials row is the one with legal weight.** If your account still has Global
Administrator in the customer's tenant three months after the project, ⭐ **you are inside their
breach scope, their audit scope, and their insurance questionnaire** — and neither party intended
it.

---

## 3. How it works underneath — five gates, in order

```
① ⭐ ACCEPTANCE   every MUST requirement tested and passed
                   ⭐ evidence attached per requirement → ../requirements/
      │
② DOCUMENTATION  ⭐ AS-BUILT (not as-designed) + SOPs + runbooks
      │           ⭐ deltas from the LLD explicitly listed
      │
③ ⭐ CAPABILITY   competency matrix complete → ../customer-training/
      │           ⭐ gaps here BLOCK the gate
      │
④ ⭐ CREDENTIALS  customer holds everything; ⭐ YOUR access REMOVED
      │           ⭐ removal VERIFIED by the customer, not asserted by you
      │
⑤ SUPPORT        hypercare window, then defined BAU support
                  ⭐ with a written end date
      │
      ▼
   ⭐ SIGN-OFF — one named person, dated
```

⭐ **Gate ③ blocking is the discipline most consultancies lack.** If the administrator cannot
perform the SOPs unaided, the system is not handed over — it is abandoned in place with a document.
⭐ **Saying "we are not ready to hand over" costs a week; the alternative costs the relationship.**

---

## 4. Worked example — the credential handover, done correctly

⭐ **This is where good engineers are casual and it matters most.**

```
CREDENTIAL HANDOVER              Contoso · 2026-09-20 · witnessed

ITEM                    METHOD                        ⭐ VERIFICATION           ✓
────────────────────────────────────────────────────────────────────────────────
Break-glass 1 password  ⭐ sealed envelope, physical   ⭐ customer signs         ☐
                        ⭐ handed to J. Okafor            for receipt
Break-glass 2 password  ⭐ SEPARATE envelope,          ⭐ separate signature     ☐
                        ⭐ SEPARATE custodian
Break-glass 1+2         ⭐ CUSTOMER RESETS BOTH        ⭐ we are told "done",    ☐
                        ⭐ after we leave                 ⭐ never the value
Emergency access acct   ⭐ CA exclusions re-verified   script output attached   ☐
Migration SPN           ⭐ DELETED                      ⭐ Get-MgServicePrincipal ☐
  (SPN-MIG-…-Temp)                                     ⭐ returns nothing
⭐ Consultant accounts   ⭐ roles removed, then          ⭐ CUSTOMER runs the     ☐
                        ⭐ accounts DISABLED              ⭐ check, not us
Secrets in Key Vault    ⭐ access policy updated;       customer confirms        ☐
                        ⭐ our principals removed          access
────────────────────────────────────────────────────────────────────────────────
⭐ RULE: we never hold a credential we have not watched the customer change.
```

⭐ **"The customer resets both break-glass passwords after we leave" is the row that makes the whole
thing honest.** You generated those passwords; you may have seen them. ⭐ **Custody is only provable
once the value has changed to something you have never known** — and this is exactly the *provable
sole custody* principle from
[`../../SC-300-SPRINT/DAY-1.md`](../../SC-300-SPRINT/DAY-1.md), applied at the exit.

⭐ **Two envelopes, two custodians, two signatures.** One person holding both break-glass credentials
recreates the single point of failure the second account exists to remove.

⭐ **The customer runs the verification, not you.** *"I've removed my access"* is a claim; ⭐ **their
own query returning zero rows is evidence** — and it is the version that survives their auditor
asking.

**The verification they run — hand them this, do not run it for them:**

```powershell
# Consultant access removed?  ⭐ Expect: nothing.
Get-MgUser -All -Filter "endsWith(userPrincipalName,'#EXT#@contoso.onmicrosoft.com')" `
  -ConsistencyLevel eventual -CountVariable c |
  Select-Object DisplayName, UserPrincipalName, AccountEnabled

# Temporary service principals gone?  ⭐ Expect: nothing.
Get-MgServicePrincipal -All | Where-Object DisplayName -match 'Temp|MIG|Migration' |
  Select-Object DisplayName, AppId

# ⭐ Who holds Global Administrator now?  ⭐ Expect: exactly the two break-glass accounts.
$ga = Get-MgDirectoryRole -Filter "roleTemplateId eq '62e90394-69f5-4237-9190-012177145e10'"
Get-MgDirectoryRoleMember -DirectoryRoleId $ga.Id -All |
  ForEach-Object { $_.AdditionalProperties.userPrincipalName }
```

```
breakglass1@contoso.onmicrosoft.com
breakglass2@contoso.onmicrosoft.com
```

⭐ **Two lines of output, and the handover is provable.** Anything else in that list is a finding
that must be explained before sign-off.

---

## 5. The known-issues register — ⭐ write it yourself, before they find it

⭐ **Every project has residual issues. Documenting them converts a future complaint into a
disclosed, accepted item.**

```
KNOWN ISSUES AT HANDOVER

KI-01  ⭐ 3 users on legacy handsets cannot register a passkey
       ⭐ Workaround: temporary exclusion group, ⭐ REVIEW DATE 2026-10-31
       Owner: D. Mwangi     ⭐ Not a defect - an ability gap, see change-management §4

KI-02  Guest access review scheduled but ⭐ first cycle not yet run
       First completion due 2026-10-01     Owner: L. Petrov

KI-03  ⭐ AS-BUILT DELTA: CA-004 excludes 3 service accounts
       ⭐ not present in the LLD; added during build after a relay failure.
       ⭐ LLD §7.3 updated 2026-09-18. Rationale recorded.
```

⭐ **KI-03 is the pattern to internalise.** As-built almost never equals as-designed. ⭐ **Naming the
delta, dating it, and giving the reason is what keeps the LLD trustworthy** — an LLD that quietly
disagrees with reality is worse than none, because the next engineer will believe it.

⭐ **A temporary exclusion with no review date is a permanent exclusion.** KI-01 has one, and
somebody's name against it.

---

## 6. Hypercare — the boundary that must be written

| Element | Example |
|---|---|
| ⭐ Duration | ⭐ **10 business days from sign-off** |
| Scope | ⭐ defects in delivered scope — ⭐ **not new requests** |
| Response | ⭐ named channel, 4 business hours |
| ⭐ Exit | ⭐ **automatic on the date**, unless extended in writing |
| ⭐ Out of scope | ⭐ new users, new policies, unrelated incidents |

⭐ **"Automatic on the date, unless extended in writing" is the sentence that ends engagements
cleanly.** Without it, hypercare has no end and the final invoice sits unpaid while "just one more
thing" accumulates. ⭐ **Every "small favour" during hypercare should be logged as a change request
even if you do it for free** — the log is what makes the pattern visible and the scope defensible.

---

## 7. What breaks

| Symptom | Root cause | Fix |
|---|---|---|
| Final invoice disputed | no acceptance evidence per requirement | ⭐ gate ① with evidence attached |
| Free support for months | ⭐ no hypercare end date | ⭐ §6, in writing |
| ⭐ Your access still live | removal asserted, not verified | ⭐ **customer runs the query** |
| "You left it broken" | known issues undocumented | ⭐ §5 register, before they find it |
| Next engineer misled | ⭐ as-built delta unrecorded | ⭐ KI-03 pattern |
| ⭐ Break-glass unusable | ⭐ never rehearsed by the customer | competency matrix blocks the gate |
| Handover refused | operator excluded from discovery | ⭐ too late — fix it in week one |

⭐ **"Handover refused" is always a discovery failure surfacing at the end.** The service desk lead
who first sees the system at handover has every reason to reject it. ⭐ **The fix is nine weeks
earlier** — put them in the room in
[`../discovery/`](../discovery/).

---

## 8. Customer discovery questions

*(Ask these in week one, not week nine.)*

1. ⭐ **"What must be true for you to sign acceptance?"**
2. "Who signs, and will they be available in that week?"
3. ⭐ **"How do you want credentials transferred, and who are the two custodians?"**
4. "What is your expectation for support after go-live, and for how long?"
5. ⭐ **"Who verifies that our access has been removed?"**
6. "Where should documentation live, and who maintains it after us?"
7. ⭐ **"What would make you say this was handed over badly?"**

---

## 9. Remember it

**Hook — `A D C C S`: Acceptance, Documentation, Capability, Credentials, Support.** Five gates;
⭐ **Capability is the one that blocks, Credentials is the one with legal weight.**

**Analogy — handing over a rented flat at the end of a tenancy.** ⭐ **There is an inventory checked
against the one taken at the start (acceptance against requirements), an inspection with defects
noted rather than hidden (known issues), and — the part that actually matters — ⭐ every key
returned, counted, and the landlord changing the locks anyway.** The analogy predicts the whole
credential section: **you do not keep a key "just in case", the landlord verifies rather than trusts,
and the deposit is not released until the inventory is signed.**

**The one line:** ⭐ **You never hold a credential you have not watched the customer change, and the
customer — not you — verifies your access is gone.**

---

## 10. Self-test

1. Which handover gate should block, and why is that hard?
   → ⭐ Capability. Saying "not ready" costs a week; skipping it costs the relationship.
2. Why must the customer reset break-glass passwords after you leave?
   → ⭐ Sole custody is only provable once the value is one you have never known.
3. Why two envelopes and two custodians?
   → ⭐ One holder recreates the single point of failure the second account exists to remove.
4. Who runs the access-removal verification?
   → ⭐ The customer. Your claim is not evidence.
5. What is an as-built delta, and how is it handled?
   → ⭐ A difference from the LLD; name it, date it, give the reason, update the LLD.
6. What does a temporary exclusion without a review date become?
   → ⭐ Permanent.
7. Handover is refused at the end. When was the actual mistake made?
   → ⭐ In discovery — the operator was never in the room.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | the acceptance matrix: every MUST requirement, its test, and the evidence |
| `security` | ⭐ the credential handover sheet, signed, plus the customer-run removal output |
| `operations` | the known-issues register with owners and review dates |
| `customer-use-cases` | the hypercare terms as agreed, with the end date |
| `architecture-decisions` | ⭐ every as-built delta from the LLD, with rationale |
