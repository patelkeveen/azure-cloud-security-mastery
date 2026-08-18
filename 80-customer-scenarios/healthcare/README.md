# Healthcare

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **Boundary:** [`../LAYER-7-INDUSTRY-VERTICALS.md`](../LAYER-7-INDUSTRY-VERTICALS.md) §3 is the
> brief. ⭐ **This is engagement depth — and healthcare is the vertical where a technically correct
> control does the most damage.** Pairs with
> [`../../30-identity-and-nhi/passwordless-and-passkeys/`](../../30-identity-and-nhi/passwordless-and-passkeys/).

---

## 1. What it is

Identity engineering for hospitals, clinics, care providers and health-tech — where patient data
protection (HIPAA, PHIPA, NHS DSPT and equivalents) is mandatory, and ⭐ **clinical workflow speed
overrides everything, including your design.**

⭐ **This is the only vertical where making authentication stronger can measurably harm people**, and
holding both facts at once is the job.

---

## 2. Why it is different

⭐ **A clinician at a bedside is not a knowledge worker at a desk**, and every assumption in a
standard identity design breaks:

| Standard assumption | ⭐ Clinical reality |
|---|---|
| User has a personal phone to hand | ⭐ **no phone at the bedside** — infection control, policy, gloves |
| One user per device | ⭐ **shared ward workstation**, 30 users a shift |
| A 20-second sign-in is fine | ⭐ **repeated 40× a shift** = ⭐ 13 minutes of clinical time |
| Users will follow policy | ⭐ they will follow the **patient** |
| Sessions can be long | ⭐ **an unlocked session in a corridor is a data breach** |

⭐ **The consequence is precise: any authentication costing more than a few seconds gets defeated.**
Shared logins, a propped session, a password taped under the keyboard. ⭐ **This is a design failure,
not a training failure** — and a bypassed control is worse than a weaker one that is used, because
it produces false assurance while leaving no audit trail.

⭐ **Test with a real clinician doing a real task before rollout.** Not a demo, not a pilot user from
IT.

---

## 3. ⚠ The terminology collision that will bite you

```
⭐ "BREAK THE GLASS" MEANS TWO COMPLETELY DIFFERENT THINGS

⭐ CLINICAL     emergency clinician access to a patient record they
                would not normally be authorised to see
                ▸ ⭐ REQUIRED BY REGULATION - HIPAA §164.312(a)(2)(ii)
                  "emergency access procedure"
                ▸ ⭐ access is GRANTED, then audited retrospectively
                ▸ implemented in the ⭐ EHR (Epic, Cerner, Meditech),
                  ⭐ NOT in Entra

⭐ IDENTITY     the two excluded emergency admin accounts that recover
                a tenant lockout
                ▸ Entra, ⭐ nothing to do with patient records
```

⭐ **Establish which one is meant in the first meeting, out loud.** ⭐ **Designing the wrong one is a
weeks-late discovery**, and it is embarrassing in a way that is hard to recover from — because it
reveals you did not understand the customer's world.

⭐ **The regulation genuinely requires the clinical one.** HIPAA's emergency access procedure is a
required implementation specification: ⭐ **a system that cannot be accessed in an emergency is
non-compliant**, which is the inverse of the instinct most security engineers bring.

---

## 4. Worked example — the shift-start walkthrough

⭐ **The single best discovery technique in this vertical: make them show you, tap by tap.**

```
⭐ OBSERVED   Ward 4B, day shift start, ⭐ measured with a stopwatch

  BEFORE (what the customer had)
  ─────────────────────────────────────────────────────────────
  1. Nurse taps workstation                             0s
  2. Previous user still logged in ⭐ ← FINDING             —
  3. Sign out, wait for profile unload                 22s
  4. Type username (⭐ 14 characters, gloved)             11s
  5. Type password (⭐ 16 characters, complex)            14s
  6. ⭐ MFA push — ⭐ phone is in a locker                  ⭐ FAILS
  7. ⭐ Nurse uses a colleague's already-open session     ⭐ ← THE REAL FINDING
  ─────────────────────────────────────────────────────────────
  ⭐ Effective control: NONE. ⭐ Audit trail: WRONG PERSON.

  AFTER (designed around the constraint)
  ─────────────────────────────────────────────────────────────
  1. Nurse taps badge on reader                         1s
  2. FIDO2 security key / badge + PIN                   3s
  3. ⭐ Signed in, correct identity in the audit log      ⭐ 4s total
  ─────────────────────────────────────────────────────────────
```

⭐ **Step 7 is the entire engagement.** The customer believed they had MFA; ⭐ **what they had was
one nurse's credentials being used by six people, and an audit trail that names the wrong clinician
on every record access.** That is simultaneously a security failure, a compliance failure and a
patient-safety failure.

⭐ **The fix is not more MFA — it is a different factor.** ⭐ **A FIDO2 key or badge is faster than a
password**, which is why it succeeds where policy fails: it is on the lanyard already there for
physical access, it needs no phone, and it works with gloves.

**The design that follows from the observation:**

```powershell
# ⭐ Split the population - shared clinical devices vs personal devices.
# ⭐ Sign-in frequency is the control that matters on a shared workstation.

# Policy A: shared clinical workstations
#   include:  GRP-Devices-ClinicalShared
#   grant:    ⭐ authenticationStrength = phishing-resistant MFA
#   session:  ⭐ signInFrequency = 4 hours   ⭐ (a shift boundary)
#             ⭐ persistentBrowser = never

# Policy B: personal/office devices
#   grant:    MFA
#   session:  signInFrequency = 30 days
```

⭐ **Short sessions on shared devices, long sessions on personal ones** — the opposite of the usual
blanket policy, and it is the reasoning that demonstrates you understood the environment.

⭐ **Automatic logoff is also a named HIPAA implementation specification** (§164.312(a)(2)(iii)) —
⭐ **so the corridor-session problem is a compliance requirement, not just good practice.**

---

## 5. Commands — the evidence a health customer actually needs

```powershell
# ⭐ Are shared clinical accounts in use?  ⭐ The signature: one account,
# ⭐ many devices, overlapping times.
Get-MgAuditLogSignIn -Filter "createdDateTime ge 2026-08-13T00:00:00Z" -All |
  Group-Object UserPrincipalName |
  ForEach-Object {
    [pscustomobject]@{
      User    = $_.Name
      SignIns = $_.Count
      Devices = ($_.Group.DeviceDetail.DeviceId | Select-Object -Unique).Count
    }
  } | Where-Object Devices -gt 5 | Sort-Object Devices -Descending
```

```
User                        SignIns  Devices
ward4b.shared@contoso.com       118       14   ⭐ shared account, confirmed
j.smith@contoso.com              42       11   ⭐ ← ⭐ credential sharing
```

⭐ **The second row is the dangerous one.** A named clinician signing in from eleven devices in a day
is ⭐ **either a very mobile doctor or shared credentials** — and telling those apart requires
talking to the ward, not more queries. ⭐ **Bring the list; do not accuse.**

**Registration readiness — before you promise passwordless:**

```powershell
Get-MgReportAuthenticationMethodUserRegistrationDetail -All |
  Where-Object { $_.UserPrincipalName -like '*@ward*' -or $_.IsAdmin -eq $false } |
  Group-Object { ($_.MethodsRegistered -join ',') } |
  Select-Object Name, Count | Sort-Object Count -Descending | Select-Object -First 4
```

```
Name                              Count
mobilePhone                         412   ⭐ ← ⭐ unusable at the bedside
                                    188   ⭐ ← nothing registered at all
fido2                                31
microsoftAuthenticator,mobilePhone   96
```

⭐ **412 users registered only for phone-based MFA in an environment where phones are in lockers is
a rollout that will fail on day one** — and this query finds it before you have committed to a date.
⭐ **188 with nothing registered is the second finding**, and it is the group that will flood the
service desk.

---

## 6. Design reference

| Control | Setting | ⭐ Clinical reason |
|---|---|---|
| Primary factor | ⭐ **FIDO2 / badge**, not phone | ⭐ no phone at the bedside; works with gloves |
| Shared device session | ⭐ 4–8 h, ⭐ no persistent browser | shift boundary; corridor risk |
| Personal device session | 30 days | ⭐ do not punish the desk workers |
| Automatic lock | short, ⭐ device-enforced | ⭐ HIPAA §164.312(a)(2)(iii) |
| Rotating staff | ⭐ **entitlement management** access packages, time-bound | ⭐ residents, locums, agency — high churn is the norm |
| Clinical break-glass | ⭐ **in the EHR**, audited retrospectively | ⭐ HIPAA §164.312(a)(2)(ii) — required |
| Identity break-glass | 2 Entra accounts | tenant recovery — a different thing |
| Documentation retention | ⭐ **6 years** for HIPAA-required documentation | ⚠ verify current rule text |

⚠ `⚠ check` — HIPAA citations and retention periods above are given to orient you; ⭐ **read the
current rule text or have the customer's compliance officer confirm** before writing them into a
deliverable. ⭐ **You do not interpret health law** — same boundary as
[`../fintech-and-banking/`](../fintech-and-banking/) §3.

⭐ **Microsoft will sign a Business Associate Agreement** for covered services; ⭐ **the customer must
still confirm which services are in scope.** A BAA covering M365 does not automatically cover every
Azure service you might add.

---

## 7. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| ⭐ Audit trail names the wrong clinician | ⭐ credential sharing | ⭐ faster factor, not stricter policy |
| Rollout abandoned after week one | phone-based MFA in a no-phone environment | ⭐ §5 registration query, first |
| ⭐ Wrong "break the glass" built | ⭐ terminology collision | ⭐ ask in the first meeting |
| Sessions left open in corridors | long session lifetime on shared devices | ⭐ short frequency + device lock |
| Locums cannot get access for 3 days | manual provisioning | ⭐ access packages with an expiry |
| Clinicians route around the control | ⭐ designed at a desk | ⭐ observe a real shift start |
| Emergency access blocked | ⭐ security instinct applied to a clinical requirement | ⭐ emergency access is **required** |

⭐ **The last row deserves emphasis because it is a genuine ethical point, not just a compliance
one.** ⭐ **A control that prevents a clinician reaching a record during an emergency can contribute
to harm.** The regulation's answer — grant access, log it prominently, review every use — ⭐ **is the
correct security answer too, and being able to say why is what makes you credible in this room.**

---

## 8. Customer discovery questions

1. ⭐ **"Walk me through a nurse starting a shift on a shared workstation — every tap."**
2. ⭐ **"When you say break the glass, do you mean patient records or tenant recovery?"**
3. "Do clinicians carry personal phones on the ward? Is that policy or habit?"
4. ⭐ **"How many people know the password to the ward workstation account?"**
5. "How long does a locum wait for access, and who provisions it?"
6. ⭐ **"Which system holds the emergency-access audit, and who reviews it?"**
7. "Is there a badge/proximity system already in place?" (⭐ often the answer to everything)

---

## 9. Remember it

**Hook — `S P E`: Shared devices, Phoneless factors, Emergency access is required.**

**Analogy — a hospital fire door.** ⭐ **It must be locked against intruders and openable instantly
by anyone fleeing a fire — and the resolution is not a stronger lock but a push-bar that logs
loudly.** The analogy predicts the whole vertical: ⭐ **emergency access is granted and audited, not
prevented**, ⭐ **a door that is hard to open gets propped** (the shared session), and ⭐ **the
propped door is more dangerous than the weaker lock would have been**, because everyone believes
the building is secure.

**The one line:** ⭐ **Make the fast path the secure path — a badge is quicker than a password, which
is why it works where policy does not.**

---

## 10. Self-test

1. What are the two meanings of "break the glass", and where does each live?
   → ⭐ Clinical emergency record access (in the EHR, required by HIPAA) and Entra emergency admin accounts.
2. Why is phone-based MFA often unusable in clinical settings?
   → ⭐ No personal phone at the bedside — infection control, policy, gloves.
3. Why is a bypassed control worse than a weaker one?
   → ⭐ It produces false assurance and a wrong audit trail.
4. Session policy on shared vs personal devices?
   → ⭐ Short on shared (shift boundary, no persistence), long on personal.
5. What does one named user signing in from eleven devices suggest?
   → ⭐ Credential sharing — or a very mobile clinician. Investigate by talking to the ward.
6. Which HIPAA specification makes emergency access mandatory?
   → ⭐ §164.312(a)(2)(ii), emergency access procedure. ⚠ verify wording.
7. Best discovery technique here?
   → ⭐ Observe a real shift start with a stopwatch.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | the registration-methods query, showing the phone-only population |
| `security` | ⭐ the multi-device sign-in analysis identifying shared credentials |
| `operations` | ⭐ the observed shift-start timing, before and after |
| `customer-use-cases` | the written statement of which "break the glass" is in scope |
| `architecture-decisions` | ⭐ the split session-lifetime design, with the clinical justification |
