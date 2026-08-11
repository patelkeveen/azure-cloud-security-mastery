# Incident Response

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> Consumes everything in this domain: [`../kql/`](../kql/) to scope,
> [`../sentinel/`](../sentinel/) to detect, [`../threat-hunting/`](../threat-hunting/) to find what
> detection missed, [`../defender-for-identity/`](../defender-for-identity/) for the identity signal.
> **The §5 eviction section is the part most IR guidance gets wrong.**

---

## 1. What it is

The process that takes an organisation from *"something is wrong"* to *"it is over, and it cannot
happen the same way again."*

Two frameworks, and they are the same thing:

| NIST SP 800-61 | SANS **PICERL** |
|---|---|
| Preparation | **P**reparation |
| Detection & Analysis | **I**dentification |
| Containment, Eradication & Recovery | **C**ontainment, **E**radication, **R**ecovery |
| Post-Incident Activity | **L**essons learned |

**PICERL is the one to memorise** — it is a word, and the order is the point.

---

## 2. Why the order is non-negotiable

Every instinct under pressure is wrong, and the framework exists to override instinct:

- **Instinct: fix it immediately.** Result: evidence destroyed, scope never established, attacker
  still present via a second foothold you never looked for.
- **Instinct: reset the password.** Result: ⭐ **the attacker keeps working** — see §5.
- **Instinct: keep it quiet.** Result: regulatory clocks breached, and the legal exposure exceeds
  the technical damage.

> **Preparation is the only phase you can do before it matters, and it is the only one that changes
> the outcome.** Everything else is executing decisions you should already have made. An
> organisation deciding *during* an incident who can authorise disconnecting a business unit has
> already lost hours.

---

## 3. The phases, with what actually happens in each

### Preparation

- Named **incident commander** role — and it is not the most technical person in the room
- Decision authority written down: **who can disable an executive's account at 03:00?**
- **Out-of-band communication.** ⭐ If the estate is compromised, Teams and email may be read by the
  attacker. A pre-agreed alternative channel is a preparation task, not an incident task.
- Break-glass accounts tested — cloud-only, `.onmicrosoft.com`, excluded from CA
- Logging that answers the questions you will ask, with retention that reaches back far enough
- Retainer with an IR firm, and legal/insurance contacts identified

### Identification

Establish scope before acting. The questions, in order:

```
What is the earliest evidence?        ← almost always earlier than the alert
Which identities are involved?        ← users AND service principals
Which devices?
What did the attacker access?
Is the attacker still active?         ← decides containment urgency
Is there a second foothold?           ← the question people skip
```

### Containment

**Short-term** — stop the bleeding: isolate devices, revoke sessions, block IPs.
**Long-term** — sustainable while you rebuild: temporary rules, tightened CA policies.

### Eradication

Remove the foothold: rebuild devices, rotate credentials, remove the attacker's persistence —
added SP credentials, mail forwarding rules, new federated domains, OAuth consent grants.

### Recovery

Restore service with monitoring **elevated on the specific indicators from this incident**.

### Lessons learned

**Blameless.** The output is a change to controls or process — not a name.

---

## 4. Worked example — identity compromise, end to end

**Alert:** the password-spray-then-success rule from [`../sentinel/`](../sentinel/) §4 fires for
`priya@contoso.com`.

**Step 1 — scope before you touch anything.** What did this identity do?

```kusto
let user = "priya@contoso.com";
let start = datetime(2026-08-09 14:00);
union
  (SigninLogs | where UserPrincipalName == user
     | project TimeGenerated, Type="Signin", IP=IPAddress, App=AppDisplayName, Result=tostring(ResultType)),
  (AuditLogs  | where tostring(InitiatedBy.user.userPrincipalName) == user
     | project TimeGenerated, Type="Audit", IP=tostring(InitiatedBy.user.ipAddress),
               App=OperationName, Result=tostring(Result)),
  (OfficeActivity | where UserId == user
     | project TimeGenerated, Type="Office", IP=ClientIP, App=Operation, Result=ResultStatus)
| where TimeGenerated > start
| sort by TimeGenerated asc
```

**One timeline across sign-ins, directory changes and Office activity.** That union is the single
most useful query in an identity incident, because attacker actions span all three and no single
table tells the story.

**Step 2 — look for persistence before containing.** ⭐ This is the step that separates a real
responder from someone closing a ticket:

```kusto
// Mail forwarding - the classic BEC persistence
OfficeActivity
| where TimeGenerated > ago(30d)
| where Operation in ("Set-Mailbox","New-InboxRule","Set-InboxRule","UpdateInboxRules")
| where UserId == "priya@contoso.com" or tostring(Parameters) has "ForwardingSmtpAddress"
| project TimeGenerated, Operation, UserId, Parameters
```

```kusto
// Did they consent an app, add SP credentials, or register an MFA method?
AuditLogs
| where TimeGenerated > ago(30d)
| where OperationName has_any ("Consent to application", "Add app role assignment",
        "Update application", "Add service principal credentials",
        "User registered security info", "Add domain", "Set domain authentication")
| mv-expand TargetResources
| project TimeGenerated, OperationName,
          Actor = tostring(InitiatedBy.user.userPrincipalName),
          Target = tostring(TargetResources.displayName)
```

> ⭐ **`Set domain authentication` and `Add domain` on that list are the crown-jewel events.**
> An attacker who federates a domain to their own IdP can mint tokens for **any user in the tenant**
> — the cloud equivalent of Golden SAML, and it survives every password reset you perform.

**Step 3 — contain, in the right order** (see §5 for why):

```powershell
Connect-MgGraph -Scopes 'User.ReadWrite.All','Directory.AccessAsUser.All'

# 1. Revoke refresh tokens FIRST - this is the one that actually evicts
Revoke-MgUserSignInSession -UserId priya@contoso.com

# 2. Then force a password change
Update-MgUser -UserId priya@contoso.com `
  -PasswordProfile @{ ForceChangePasswordNextSignIn = $true; Password = (New-Guid).Guid }

# 3. Remove attacker-registered MFA methods (check BEFORE deleting - record them as evidence)
Get-MgUserAuthenticationMethod -UserId priya@contoso.com |
  Select-Object Id, AdditionalProperties

# 4. If the account is to be disabled rather than recovered
Update-MgUser -UserId priya@contoso.com -AccountEnabled:$false
```

**Step 4 — eradicate persistence.** Remove the inbox rule, revoke the OAuth consent grant, delete
any SP credential the attacker added. **Missing one makes every other step cosmetic.**

**Step 5 — recover and monitor.** Re-enable with elevated monitoring on the specific IPs, apps and
techniques from this incident.

---

## 5. ⭐ The eviction problem — why a password reset does not work

The most important operational fact in identity incident response, and the one most guidance gets
wrong.

```
Attacker holds:
   ├── the password              ← password reset kills this
   ├── a REFRESH TOKEN           ← ⚠ survives a password reset unless sessions are revoked
   ├── an ACCESS TOKEN           ← valid until it expires, typically 60-90 minutes
   ├── a registered MFA method   ← survives EVERYTHING until removed
   └── an app consent / SP cred  ← ⭐ a SEPARATE identity. Nothing you do to the user touches it.
```

**Reset the password and walk away, and the attacker keeps working.** Their refresh token continues
to mint new access tokens; their registered authenticator satisfies MFA; and if they consented an
application, that application has its own permissions independent of the user entirely.

**The correct eviction sequence:**

```
1. Revoke-MgUserSignInSession      invalidate refresh tokens
2. Reset the password              close the original entry
3. Remove attacker MFA methods     record them as evidence first
4. Revoke OAuth consent grants     the separate identity
5. Remove SP credentials           the other separate identity
6. THEN verify - re-run step 1's timeline query and confirm silence
```

⚠ **Access tokens already issued remain valid until expiry.** **Continuous Access Evaluation (CAE)**
narrows this to near-real-time for CAE-capable clients and resources (Exchange Online, SharePoint,
Teams, Graph). Non-CAE paths still honour the original token lifetime. ⚠ Verify CAE coverage for the
applications in scope rather than assuming instantaneous revocation everywhere.

**For a compromised service principal**, the user-focused actions are all irrelevant:

```powershell
# Remove the attacker's credential - not the whole app, which destroys evidence
Get-MgApplication -Filter "appId eq '<appId>'" |
  Select-Object -ExpandProperty PasswordCredentials |
  Select-Object KeyId, DisplayName, StartDateTime, EndDateTime

Remove-MgApplicationPassword -ApplicationId <objectId> -KeyId <attackerKeyId>
```

> **Prefer disabling a service principal over deleting the app registration.** Deleting the app
> object deletes the SP, and **restoring the app does not restore the SP** — every role assignment
> and consent is gone. See
> [`../../30-identity-and-nhi/service-principals/`](../../30-identity-and-nhi/service-principals/).

**On-premises, the equivalent trap is krbtgt.** A Golden Ticket survives every user password reset
in the domain. **Reset krbtgt twice**, separated by more than one replication cycle — once leaves
the previous key valid.

---

## 6. The tip-off trade-off, and evidence

**Containment tells the attacker you have found them.** A sophisticated adversary responds by
burning their remaining footholds and accelerating — or by going quiet and returning in six weeks.

The decision is **a business decision, not a technical one**:

| Contain immediately when | Observe first when |
|---|---|
| Active data exfiltration | Scope is genuinely unknown |
| Ransomware staging | You suspect additional footholds |
| Privileged account compromise | You have the monitoring to watch safely |
| Regulated data at risk | Legal/IR counsel advises it |

**Preserve evidence before eradicating.** Once you rebuild a device or delete an app registration,
the evidence is gone:

- Export the relevant log queries **to a file**, not a portal view — retention will age them out
- Record attacker-registered MFA methods and credential `KeyId`s **before** deleting them
- Snapshot rather than reimage where feasible
- Note timestamps in **UTC** and say so — `TimeGenerated` is UTC and mixed time zones corrupt timelines

> ⭐ **Retention is an IR constraint discovered at the worst moment.** If sign-in logs are kept 30
> days and the intrusion began 45 days ago, the answer to "when did this start?" is *unknowable* —
> and that sentence will appear in the report. This is the argument that funds retention, and it
> lands far better before an incident than during one.

---

## 7. Communication and clocks

**Who needs to know, and when, is decided in Preparation.** Under way, three parallel tracks:

| Track | Owner | Note |
|---|---|---|
| Technical | Incident commander | The timeline and the actions |
| Business | Exec sponsor | Impact, and decisions needed |
| Legal / regulatory | Counsel | ⚠ Notification clocks start on **awareness**, not on conclusion |

⚠ Regulatory notification windows are jurisdiction-specific — GDPR's 72-hour breach notification is
the widely cited one, but sector and country rules differ. **Verify the applicable obligations for
the specific customer** rather than quoting a number; getting this wrong is a legal problem, not a
technical one.

**Out-of-band communication matters.** If the identity plane is compromised, the attacker may be
reading the incident channel. Discussing containment plans in Teams while the attacker holds a valid
token is a real and repeated failure.

---

## 8. What breaks

**Password reset without session revocation.** §5. The single most common eviction failure.

**Forgetting the service principal.** The user is clean and the app keeps working.

**Deleting the app registration.** Destroys evidence and the SP is unrecoverable.

**Single krbtgt reset.** The previous key remains valid; the Golden Ticket still works.

**Containing before scoping.** Attacker moves to a foothold you never found.

**Eradicating before preserving.** No evidence, no root cause, no defensible report.

**Retention shorter than dwell time.** "When did this start?" becomes unanswerable.

**Mixed time zones.** Corrupted timeline, wrong conclusions.

**Discussing the response in a compromised channel.**

**Blameful postmortems.** People stop reporting incidents early, which is the one thing that most
reduces damage.

---

## 9. Customer discovery questions

1. Is there a named **incident commander** role, and a deputy?
2. Who can authorise disabling an executive account at 03:00 — **by name**?
3. Is there an **out-of-band** communication plan if the tenant is compromised?
4. Does the eviction runbook include **session revocation**, or only a password reset? *(This is
   usually the finding.)*
5. Does it cover **service principals** and consent grants?
6. When was krbtgt last reset, and was it **twice**?
7. What is log retention, and does it exceed realistic dwell time?
8. Have break-glass accounts been **tested** this year?
9. When was the last **tabletop exercise**, and what changed as a result?
10. Are postmortems blameless, and does anyone track whether the actions actually get done?

---

## 10. Remember it

**Hook — PICERL:** **P**reparation, **I**dentification, **C**ontainment, **E**radication,
**R**ecovery, **L**essons learned. And for identity: **"Revoke, then reset — not the other way
round."**

**Analogy — changing the locks while the burglar is inside.** A password reset is a new front-door
lock. It does nothing about the **window they propped open** (the refresh token), the **key they
cut** (their registered MFA method), or the **lodger they signed up** (the consented app, which has
its own key and pays its own rent). Most organisations change one lock, declare victory, and are
surprised to find the house still occupied.

**The one thing:** the **consented application and the service principal are separate identities**.
Nothing you do to the user account touches them. That is why eviction is a checklist, not an action.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 11. Self-test

1. What does PICERL stand for, and why does the order matter?
2. You reset a compromised user's password. Name three ways the attacker may still have access.
3. Which single command actually begins eviction, and why must it come first?
4. Why can access tokens survive revocation, and what narrows that window?
5. A compromised service principal — do the user-focused steps help?
6. Why disable rather than delete an app registration during an incident?
7. Why must krbtgt be reset twice?
8. Which audit operations would most alarm you in a tenant compromise?
9. Why is retention an incident-response concern?
10. Why might you deliberately *not* contain immediately?

<details>
<summary>Answers</summary>

1. **P**reparation, **I**dentification, **C**ontainment, **E**radication, **R**ecovery, **L**essons
   learned. Acting out of order destroys evidence, misses scope, and leaves footholds.
2. A live **refresh token**, an unexpired **access token**, an attacker-registered **MFA method**,
   a **consented app** or added **SP credential**, or a mail-forwarding rule.
3. **`Revoke-MgUserSignInSession`** — it invalidates refresh tokens. A password reset alone does not
   reliably stop token renewal.
4. Access tokens are valid until expiry (typically 60–90 minutes). **Continuous Access Evaluation
   (CAE)** narrows this to near-real-time for CAE-capable clients and resources.
5. **No.** The SP is a separate identity. Remove the attacker's **credential** from the application.
6. Deleting the app object deletes the SP, and **restoring the app does not restore the SP** —
   role assignments and consents are lost, along with the evidence.
7. One reset leaves the **previous key valid**, so a forged Golden Ticket still works. Reset twice,
   more than one replication cycle apart.
8. **`Add domain` / `Set domain authentication`** — federating a domain lets an attacker mint tokens
   for any user. Also `Consent to application` and SP credential additions.
9. If retention is shorter than dwell time, **"when did this start?" is unanswerable** — and that
   goes in the report.
10. Containment **tips off the attacker**. When scope is unknown or additional footholds are
    suspected, observing first may be the better business decision — made with legal input.

</details>

---

## 12. Evidence this topic needs

- **`lab/`** — run the §4 union timeline query against a test account; execute the §5 eviction
  sequence and verify with a follow-up query that activity stopped.
- **`break-fix/`** ⭐ — reset a password **without** revoking sessions and prove an existing token
  still works; then revoke and prove it stops. **That single demonstration teaches this topic better
  than any document.**
- **`security/`** — the eviction runbook covering users, service principals, consent grants and
  krbtgt; break-glass accounts tested with a date.
- **`operations/`** — incident commander roster with out-of-hours authority named; out-of-band
  communication plan; retention versus realistic dwell time.
- **`architecture-decisions/`** — ADR: log retention driven by IR requirements, not cost alone.
- **`customer-use-cases/`** — a tabletop exercise run against §9, with the gaps it exposed.
