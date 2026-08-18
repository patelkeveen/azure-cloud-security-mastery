# SOPs and Runbooks (delivered to the customer)

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **Boundary:** these are the **procedures you hand over** so the customer can operate what you
> built. Internal incident runbooks live in
> [`../../70-operations-and-reliability/runbooks/`](../../70-operations-and-reliability/runbooks/).
> Pairs with [`../handover/`](../handover/) and [`../customer-training/`](../customer-training/).

---

## 1. What it is

Written procedures for the routine operational tasks your design creates: onboarding a user,
activating a privileged role, adding a break-glass review, responding to a risky sign-in, offboarding
a leaver. They are the difference between a system that works and a system the customer can **run**.

⭐ **The design is not delivered until the person who inherits it can operate it without you.**

---

## 2. Why it exists

⭐ **Every design creates operational debt, and the debt is invisible at handover.** PIM eligibility
is elegant on a slide; someone must approve activations at 02:00. Access reviews are a control;
someone must action the results.

| Task your design created | Who does it, and from what? |
|---|---|
| ⭐ Approve PIM activation | on-call engineer — ⭐ **from what instruction?** |
| Review quarterly access review results | ⭐ nobody, unless assigned |
| ⭐ Rotate the break-glass password after use | ⭐ the control that decays fastest |
| Respond to a risky sign-in alert | service desk, ⭐ tier 1, at 03:00, in month two |
| Onboard a new admin | whoever is free |

⭐ **A control nobody operates degrades to decoration within one quarter** — the same *"deployed is
not enforced"* pattern that recurs across this whole repo, arriving this time through the
operations door rather than the configuration door.

---

## 3. How it works underneath — SOP vs runbook vs checklist

⭐ **Three different documents, three different readers. Using the wrong one is why documentation
gets ignored.**

```
⭐ SOP        WHAT and WHY, repeatable process, ⭐ role-based
              reader: someone in a role, doing a known task
              e.g. "Onboarding a privileged administrator"
              ⭐ includes the reasoning - so judgement is possible

⭐ RUNBOOK    STEP BY STEP for one specific scenario, often with branches
              reader: ⭐ someone under pressure, possibly at 03:00
              e.g. "Risky sign-in alert - triage and response"
              ⭐ NO reasoning inline - decisions are pre-made as branches

⭐ CHECKLIST  the ≤9 items that must not be omitted, at a pause point
              reader: ⭐ an expert who already knows how
              → ../configuration-checklists/
```

⭐ **The distinguishing question: does the reader need to think, or must they not?** ⭐ **An SOP
teaches judgement; a runbook removes the need for it.** A runbook full of *"consider whether…"* has
failed at exactly the moment it is used.

---

## 4. Worked example — a runbook page, written for 03:00

```
RUNBOOK  RB-03   Risky sign-in detected (Identity Protection, High)
Owner  Service Desk Tier 1     Escalation  Security on-call (rota: <link>)
Last tested  2026-08-15  by L. Petrov      ⭐ Review  quarterly

⭐ TRIGGER   Email/Teams alert "User at risk detected", risk level High

STEPS
 1  Open  entra.microsoft.com → Protection → Identity Protection
          → Risky users. Locate the user.

 2  Read the risk detection TYPE. ⭐ Branch on it:

    ┌ "Anonymous IP address" or "Atypical travel" ──────────► go to 3
    ├ ⭐ "Leaked credentials" ──────────────────────────────► go to 5 IMMEDIATELY
    └ "Unfamiliar sign-in properties" ──────────────────────► go to 4

 3  ⭐ Contact the user by a channel that is NOT email
    (phone, or Teams call to a known number).
    ⭐ WHY: if the account is compromised, email reaches the attacker.
    Ask: "did you sign in from <location> at <time>?"
       ▸ YES, confirmed  → step 7 (dismiss)
       ▸ NO, or ⭐ NO ANSWER within 15 min → step 5

 4  Check whether the device is compliant and the location expected.
       ▸ Both normal → step 7      ▸ Either abnormal → step 3

 5  ⭐ CONTAIN - in this order, do not reorder:
       a  Block sign-in     Update-MgUser -UserId <upn> -AccountEnabled:$false
       b  ⭐ Revoke sessions  Revoke-MgUserSignInSession -UserId <upn>
       c  ⭐ CHECK INBOX RULES and forwarding  ⭐ ← most-missed step
       d  Reset password (⭐ user must not choose it over email)

 6  Escalate to Security on-call. ⭐ Do not close the ticket.

 7  Dismiss the risk, note the reason, close.

⭐ TIME EXPECTED  10-20 minutes.  ⭐ If longer, escalate - do not persist alone.
```

⭐ **Step 3's "not by email" carries its reason inline, and it is the one exception to the
no-reasoning rule** — because a tired tier-1 engineer will otherwise "just email them", and the
consequence is warning the attacker. ⭐ **Put the *why* in a runbook only where omitting it causes
the wrong action.**

⭐ **Step 5c is the highest-value line in the document.** Blocking and resetting looks like
containment, but **inbox rules survive a password reset** — a forwarding rule keeps exfiltrating
after the ticket is closed. This is the mechanism documented in
[`../../40-microsoft-365-platform/exchange-online/`](../../40-microsoft-365-platform/exchange-online/),
converted into an operational step where it will actually be performed.

⭐ **`Last tested` in the header, not `Last updated`.** An untested runbook is a hypothesis. ⭐ **A
date and a person's name against "tested" is the only claim worth anything** — everything else is a
document that was edited.

---

## 5. Commands — make the runbook executable where you can

```powershell
# RB-03 step 5, as one containment block the operator can paste
param([Parameter(Mandatory)][string]$Upn)

Update-MgUser -UserId $Upn -AccountEnabled:$false -ErrorAction Stop
Revoke-MgUserSignInSession -UserId $Upn -ErrorAction Stop

# ⭐ 5c - the step everyone forgets, made unmissable
Get-InboxRule -Mailbox $Upn | Select-Object Name, Enabled, ForwardTo,
    ForwardAsAttachmentTo, RedirectTo, DeleteMessage
Get-Mailbox $Upn | Select-Object ForwardingSmtpAddress, ForwardingAddress,
    DeliverToMailboxAndForward
```

```
Name    Enabled ForwardTo                        DeleteMessage
.        True   {SMTP:attacker@proton.me}                 True
```

⭐ **A rule named `.` that forwards externally and deletes the original is the textbook business
email compromise artifact** — and it is invisible to a password reset. Printing it in the
containment block is what turns knowledge into practice.

⭐ **Note both mechanisms are queried:** an inbox *rule*, and the mailbox's `ForwardingSmtpAddress`
property. ⭐ **The second does not appear in Outlook's rules UI at all**, which is why it survives
user-led cleanup.

**Verify the SOP set is actually maintained — a query, not a belief:**

```powershell
Get-ChildItem .\sops\*.md | ForEach-Object {
  $t = Select-String -Path $_ -Pattern '^Last tested\s+(\d{4}-\d{2}-\d{2})' |
       ForEach-Object { [datetime]$_.Matches[0].Groups[1].Value }
  [pscustomobject]@{ Doc=$_.BaseName
                     LastTested=$t
                     DaysAgo= if($t){(New-TimeSpan -Start $t).Days}else{'NEVER'} }
} | Sort-Object DaysAgo -Descending
```

```
Doc                        LastTested  DaysAgo
RB-05-breakglass-recovery              NEVER
RB-03-risky-signin         2026-08-15        3
```

⭐ **`RB-05-breakglass-recovery : NEVER` is the finding.** The recovery procedure for the account
that recovers everything else has never been rehearsed — and that is a genuine audit finding you can
hand a customer on day one of a managed service.

---

## 6. When and where

| Deliver an SOP for | Do not write one for |
|---|---|
| ⭐ Anything your design made someone responsible for | tasks Microsoft documents adequately |
| ⭐ Anything done under time pressure | ⭐ one-off project activities |
| Anything with a compliance obligation | exploratory work |
| ⭐ Anything only you currently know how to do | ⭐ things that should be automated instead |

⭐ **The last row is a real decision, not a joke.** If an SOP describes twelve manual steps performed
weekly, ⭐ **the right deliverable is a script plus a two-step SOP**, and saying so is worth more
than writing the twelve steps beautifully.

---

## 7. What breaks

| Symptom | Root cause | Fix |
|---|---|---|
| Documents never opened | ⭐ wrong type for the reader | §3 — SOP teaches, runbook removes thinking |
| ⭐ Runbook fails when used | ⭐ never tested | ⭐ `Last tested` header + quarterly rehearsal |
| Steps reference a UI that changed | ⭐ screenshot-driven | ⭐ describe by name and path; prefer PowerShell |
| Nobody owns the procedure | no role in the header | one role, plus an escalation |
| ⭐ Containment incomplete | ⭐ forwarding not checked | ⭐ step 5c, in the paste block |
| Documents drift from reality | no review cadence | ⭐ the §5 query, run monthly |

⭐ **"Never tested" is the defining failure of handover documentation**, because it is invisible
until the worst possible moment. A runbook is a claim about what will happen; ⭐ **rehearsal is the
only thing that converts it into knowledge.**

---

## 8. Customer discovery questions

1. ⭐ **"Who will perform this task, and what is their skill level?"** — sets the writing level
2. "What hours are they available, and what happens outside them?"
3. ⭐ **"Which of these tasks happen at 3 a.m.?"** — those become runbooks, not SOPs
4. "Where do your procedures live today, and does anyone read them?"
5. ⭐ **"When did you last rehearse a recovery procedure?"**
6. "What is your escalation path, and is it staffed?"
7. "Would you rather have a script or a procedure?" (⭐ usually the script)

---

## 9. Remember it

**Hook — `S R C`: SOP teaches, Runbook removes thinking, Checklist prevents omission.**

**Analogy — a driving lesson, a satnav, and the pre-flight walk-around.** ⭐ **The lesson explains
why you check the mirror (SOP); the satnav says "turn left in 200 metres" and does not explain the
road network (runbook); the walk-around is the short list of things that must not be missed
(checklist).** The analogy predicts each failure: ⭐ **a satnav that explains urban planning while
you approach a junction is useless**, and a driving lesson that only says "turn left" teaches
nothing.

**The one line:** ⭐ **Write for the person who will do it at 03:00 in their second week — and put
`Last tested`, not `Last updated`, in the header.**

---

## 10. Self-test

1. SOP or runbook — which carries reasoning, and why?
   → ⭐ SOP. A runbook's decisions are pre-made as branches; reasoning under pressure is a defect.
2. What belongs in a runbook header that most documents omit?
   → ⭐ `Last tested`, with a date and a person.
3. Why contact a possibly-compromised user by phone rather than email?
   → ⭐ Email reaches the attacker.
4. Which containment step is most often missed, and why does it matter?
   → ⭐ Inbox rules and forwarding — they survive a password reset.
5. Name the two forwarding mechanisms that must both be checked.
   → ⭐ Inbox rules, and the mailbox `ForwardingSmtpAddress` property (invisible in the rules UI).
6. Twelve manual steps performed weekly — what is the right deliverable?
   → ⭐ A script plus a two-step SOP.
7. What does "never tested" make a runbook?
   → ⭐ A hypothesis.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | one runbook, rehearsed, with the tester's name and date |
| `operations` | ⭐ the `Last tested` audit query output across the SOP set |
| `break-fix` | ⭐ one real containment showing rules/forwarding found after a reset |
| `customer-use-cases` | the SOP index handed over, mapped to roles |
| `architecture-decisions` | ⭐ one procedure replaced by automation, with the reasoning |
