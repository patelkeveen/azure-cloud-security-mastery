# Exchange Online

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Where attacker persistence lives in M365** — and the persistence mechanisms are features, not
> exploits. Pairs with [`../mail-flow-and-hygiene/`](../mail-flow-and-hygiene/) and
> [`../../50-security-operations/incident-response/`](../../50-security-operations/incident-response/).

---

## 1. ⭐ The three delegation types, and why they are not interchangeable

| Permission | Lets the grantee | ⭐ Shows in the sent message as |
|---|---|---|
| **FullAccess** | ⭐ **read everything** in the mailbox | — (cannot send by itself) |
| ⭐ **SendAs** | send | ⭐ **the mailbox owner. Indistinguishable.** |
| **SendOnBehalf** | send | *"X on behalf of Y"* — ⭐ visible |

⭐ **SendAs is the one that matters for security.** A message sent with SendAs is, to every recipient
and most log views, **from the owner**. It is the legitimate feature that produces the same outcome as
spoofing, from inside, with valid authentication and no anomaly.

> ⭐ **So "who can send as the CFO?" is a question with a real answer, and almost nobody has asked
> it.** It takes one command (§3) and it is the highest-value single query in this topic.

⚠ **FullAccess on a shared mailbox is normal and expected.** ⭐ **FullAccess on an executive's
personal mailbox, granted eighteen months ago to an assistant who changed role, is not** — and neither
state is distinguishable without knowing the business context, which is why this is a review rather
than a scan.

---

## 2. ⭐ Inbox rules: the persistence mechanism of choice

**An attacker with a mailbox needs to keep access and stay quiet. A rule does both:**

```
⭐ Forward to external address        exfiltration, silent, survives password reset
⭐ Move "phish"/"password"/"invoice"  hide the security team's warnings from the user
   to Deleted Items / RSS Feeds       ⭐ the classic: a rule with a BLANK or "." name
⭐ Delete replies to sent items       hide the responses to a fraud attempt
```

⭐ **The single most useful detail: rules survive a password reset.** An incident response that
resets the password, revokes sessions and closes the ticket **leaves the forwarding rule running** —
and this is the most common way a "contained" business email compromise continues for months.

> ⭐ **Add "enumerate and remove inbox rules and forwarding" to the BEC runbook**, immediately after
> revoking sessions. It is one step, it is routinely missed, and its absence is why the same
> compromise reappears.

**Three forwarding mechanisms, and you must check all three:**

```
① inbox RULE           per-mailbox, user-created
② ⭐ ForwardingSmtpAddress   mailbox property — ⭐ NOT a rule, invisible in Outlook rules UI
③ ForwardingAddress     internal recipient object
```

⭐ **Mechanism ② is the one people miss**, because it does not appear where anyone looks for rules.

---

## 3. Worked example — the three queries that find compromise

```powershell
Connect-ExchangeOnline

# ① ⭐ Who can send AS someone else? The highest-value query in this topic.
Get-EXORecipient -ResultSize Unlimited | ForEach-Object {
  $r = $_
  Get-RecipientPermission -Identity $r.PrimarySmtpAddress -EA SilentlyContinue |
    Where-Object { $_.AccessRights -contains 'SendAs' -and $_.Trustee -notlike 'NT AUTHORITY\*' } |
    ForEach-Object {
      [pscustomobject]@{ Mailbox=$r.PrimarySmtpAddress; Trustee=$_.Trustee; Right='SendAs' }
    }
} | Sort-Object Mailbox
```

```
Mailbox                  Trustee                     Right
-----------------------  --------------------------  ------
cfo@contoso.com          j.temp@contoso.com          SendAs   <-- ⚠⚠⚠ who is this?
payments@contoso.com     ap-team@contoso.com         SendAs   ✅ expected
```

⭐ **Row one is a finding you can act on immediately**, and it is exactly the capability a
business-email-compromise fraud needs: send an invoice change request that genuinely comes from the
CFO.

```powershell
# ② ⭐ All three forwarding mechanisms, in one pass
Get-EXOMailbox -ResultSize Unlimited -Properties ForwardingSmtpAddress,ForwardingAddress,DeliverToMailboxAndForward |
  Where-Object { $_.ForwardingSmtpAddress -or $_.ForwardingAddress } |
  Select-Object UserPrincipalName, ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward
```

```powershell
# ③ ⭐ Suspicious inbox rules - blank names, deletes, external forwards
Get-EXOMailbox -ResultSize Unlimited | ForEach-Object {
  $m = $_
  Get-InboxRule -Mailbox $m.UserPrincipalName -EA SilentlyContinue | ForEach-Object {
    $suspicious = ($_.ForwardTo -or $_.RedirectTo -or $_.ForwardAsAttachmentTo -or
                   $_.DeleteMessage -eq $true -or
                   [string]::IsNullOrWhiteSpace($_.Name) -or $_.Name -match '^[.\s]+$')
    if ($suspicious) {
      [pscustomobject]@{
        Mailbox = $m.UserPrincipalName
        Rule    = if ([string]::IsNullOrWhiteSpace($_.Name)) { '⚠ (blank)' } else { $_.Name }
        Fwd     = ($_.ForwardTo + $_.RedirectTo) -join ';'
        Deletes = $_.DeleteMessage
        Enabled = $_.Enabled
      }
    }
  }
}
```

```
Mailbox                Rule        Fwd                          Deletes  Enabled
---------------------  ----------  ---------------------------  -------  -------
a.singh@contoso.com    ⚠ (blank)   attacker@mail.example        False    True     <-- ⚠⚠⚠
r.jones@contoso.com    .           (none)                       True     True     <-- ⚠⚠ deletes silently
```

⭐ **A blank or single-character rule name is close to a signature.** No legitimate user creates a rule
called `.` — they call it "Newsletters". **It is one of the few near-deterministic indicators in
M365**, and it costs nothing to hunt for.

---

## 4. ⭐ Application access policies — scoping app-only mail access

**An app with `Mail.Read` *application* permission can read every mailbox in the tenant** — the
no-intersection property from
[`../../00-foundations/data-formats-and-apis/`](../../00-foundations/data-formats-and-apis/) §3.

```powershell
# ⭐ Scope an app to only the mailboxes it needs
New-ApplicationAccessPolicy -AppId <appId> `
  -PolicyScopeGroupId sg-app-scoped-mailboxes@contoso.com `
  -AccessRight RestrictAccess `
  -Description "Ticketing integration: support mailboxes only"

Test-ApplicationAccessPolicy -Identity cfo@contoso.com -AppId <appId>   # ⭐ prove it
```

⭐ **This is the single most under-used control in Exchange Online.** Every integration that reads
mail — ticketing, CRM, archiving, an AI assistant — starts with tenant-wide access because that is
what the permission grants, and **almost nobody scopes it afterwards.** `Test-ApplicationAccessPolicy`
turns the configuration into evidence.

⚠ Verify the current mechanism and any successor before advising — this surface has moved and
Microsoft has signalled changes. **The principle survives: scope app-only mail access to a group of
mailboxes.**

---

## 5. Audit and retention

| Control | ⭐ Note |
|---|---|
| **Mailbox auditing** | on by default, ⭐ **but verify per-mailbox and check which actions** |
| **Unified audit log** | ⭐ retention depends on **licence** — [`../licensing-and-service-limits/`](../licensing-and-service-limits/) |
| **Litigation hold / retention** | preserves content against user deletion |
| ⭐ **`MailItemsAccessed`** | ⭐ the action that answers *"did the attacker read it?"* |

⭐ **`MailItemsAccessed` is the difference between "an account was compromised" and "these 240 emails
were accessed."** Regulators and customers ask the second question. ⚠ **It requires the right
licensing and it must be enabled and retained** — and if it was not on before the incident, the
question is simply unanswerable.

> ⭐ **That is the argument for enabling audit *before* you need it**, and it is the same shape as
> `tool_calls` in [`../../60-ai-and-secure-ai/ai-logging-and-evaluation/`](../../60-ai-and-secure-ai/ai-logging-and-evaluation/)
> §4: **telemetry you did not capture is gone, and the investigation is bounded by a decision made
> months earlier.**

---

## 6. What breaks

**Never auditing SendAs.** §1 — ⭐ indistinguishable from the owner.

**Password reset without removing rules.** §2 — ⭐ the compromise continues.

**Checking rules but not `ForwardingSmtpAddress`.** §2 — ⭐ invisible in the rules UI.

**Ignoring blank-named rules.** §3 — near-deterministic indicator.

**App-only mail permissions left tenant-wide.** §4 — every mailbox.

**Assuming mailbox auditing covers everything.** §5 — verify the action list.

**`MailItemsAccessed` not enabled.** §5 — ⭐ "what did they read?" becomes unanswerable.

**FullAccess grants never reviewed.** §1 — the assistant who changed role.

**Treating shared-mailbox FullAccess and personal-mailbox FullAccess the same.** §1.

**Auto-forwarding allowed tenant-wide.** ⭐ Block external auto-forward by outbound spam policy —
[`../mail-flow-and-hygiene/`](../mail-flow-and-hygiene/).

---

## 7. Customer discovery questions

1. ⭐ **Who can SendAs your executives?** *(§3 — run it in the meeting.)*
2. Does the BEC runbook remove **inbox rules and forwarding** after a reset? *(§2.)*
3. Do you check **all three** forwarding mechanisms? *(§2.)*
4. Is **external auto-forwarding blocked** tenant-wide?
5. Which apps hold **`Mail.Read` application** permission, and are they **scoped**? *(§4.)*
6. Is **`MailItemsAccessed`** enabled and retained? *(§5.)*
7. What is your **audit log retention**, and does the licence support what you assume?
8. When was **FullAccess** last reviewed on executive mailboxes?
9. Could you answer *"which emails did the attacker read?"* today?

---

## 8. Remember it

**Hook — "Rules survive the password reset."**

**Analogy — changing the locks while the mail redirection stays in place.** ⭐ **You discover someone
has been in the house, so you change every lock and feel finished.** Meanwhile they filed a
redirection at the post office weeks ago, ⭐ **and it keeps working, because it was never about the
keys.** Worse, they also arranged for the *warning letters* to be binned before you see them — which
is what a rule that moves anything containing "phishing" to Deleted Items actually is.

**The one thing:** ⭐ **inbox rules and mailbox forwarding survive a password reset and session
revocation.** They are the reason a "contained" business email compromise keeps leaking for months:
the account is secure, the attacker's access to *new mail* continues, and every dashboard says the
incident is closed. **Enumerate and remove rules and all three forwarding mechanisms as a required
step in the runbook**, immediately after revoking sessions — one step, routinely missed, and its
absence is the single most common reason BEC recurs.

**Runner-up:** ⭐ **SendAs is indistinguishable from the owner.** "Who can send as the CFO?" is one
command and nobody has run it.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Name the three delegation types and how each appears to a recipient.
2. ⭐ Why is SendAs the security-relevant one?
3. Name four things a malicious inbox rule does.
4. ⭐ Why does a password reset fail to contain BEC?
5. List the three forwarding mechanisms. Which is invisible in the Outlook rules UI?
6. What is close to a signature in rule metadata, and why?
7. ⭐ What does an app with `Mail.Read` application permission reach by default, and what scopes it?
8. Which cmdlet turns that scoping into evidence?
9. ⭐ Which audit action answers "what did they read?", and what is the precondition?
10. Which earlier topic makes the same telemetry argument?

<details>
<summary>Answers</summary>

1. **FullAccess** (read everything, cannot send), ⭐ **SendAs** (appears as the owner —
   indistinguishable), **SendOnBehalf** (visible as "on behalf of").
2. ⭐ Because the message is **indistinguishable from one sent by the owner** — the legitimate feature
   with the outcome of spoofing, authenticated and un-anomalous.
3. **Forward externally, hide security warnings by moving them to Deleted Items/RSS, delete replies to
   sent items, and run under a blank or "." name.**
4. ⭐ Because **rules and forwarding survive it** — the account is secured, the leak continues.
5. **Inbox rule, ⭐ `ForwardingSmtpAddress`, `ForwardingAddress`.** ⭐ `ForwardingSmtpAddress` is a
   **mailbox property**, invisible in the rules UI.
6. ⭐ A **blank or single-character rule name** — no legitimate user names a rule `.`.
7. ⭐ **Every mailbox in the tenant** (application permissions have no user intersection).
   ⭐ **Application access policies** scope it to a group of mailboxes.
8. ⭐ **`Test-ApplicationAccessPolicy`.**
9. ⭐ **`MailItemsAccessed`.** ⚠ It must be **licensed, enabled and retained before the incident**.
10. ⭐ **AI logging and evaluation** — `tool_calls` as a required input: telemetry you did not capture
    is gone, and the investigation is bounded by a decision made months earlier.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — the §3 three queries across the tenant. **Runnable today on the E5 licence** — and
  the SendAs query is the one to run first.
- **`break-fix/`** ⭐ — create a forwarding inbox rule on a test mailbox, **reset the password and
  revoke sessions**, then send mail to it and watch the forward still fire. ⭐ **That single
  demonstration is what gets the runbook changed** — nothing else argues it as well. Then remove the
  rule and confirm.
- **`security/`** — SendAs and FullAccess register for executive and finance mailboxes; forwarding
  inventory across all three mechanisms; suspicious rule report; apps with `Mail.Read` application
  permission and their access-policy scope.
- **`operations/`** — BEC runbook with ⭐ **rule and forwarding removal as a required post-revocation
  step**; audit configuration verified including `MailItemsAccessed`; retention matched to licence.
- **`architecture-decisions/`** — ADR: external auto-forwarding blocked by default; app-only mail
  access always scoped by application access policy.
- **`customer-use-cases/`** — §7 answered; "who can send as your CFO" run live as the opening finding.
