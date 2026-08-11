# Purview — Compliance

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The *compliance* half of Purview — retention, records, eDiscovery, insider risk.** The
> *security* half (labels, DLP, DSPM) is
> [`../../50-security-operations/purview/`](../../50-security-operations/purview/); this topic
> deliberately does not repeat it.

---

## 1. ⭐ Retention is the only control that fights the user

**Every other control in this repo restricts what someone may *do*. ⭐ Retention overrides what they
already did.**

```
User deletes an email / file
   ├─ ⭐ retention policy set to RETAIN  →  ⭐ a copy is preserved, invisibly
   └─ no policy                          →  recycle bin, then gone
```

⭐ **Content preserved by retention lives where the user cannot see it** — the Recoverable Items
folder in a mailbox, the preservation hold library in SharePoint
([`../sharepoint-online/`](../sharepoint-online/) §5). **It is discoverable by eDiscovery and invisible
to its owner**, which is precisely the point and precisely the privacy conversation.

**Retention has two opposite jobs, and confusing them is the classic error:**

| Goal | Setting | ⭐ Failure if wrong |
|---|---|---|
| **Keep** (legal, regulatory) | retain for N years | ⭐ you cannot answer an investigation |
| ⭐ **Delete** (minimisation, GDPR) | delete after N years | ⭐ you hold data you promised to destroy |

⭐ **Most organisations deploy only the first and describe it as compliance.** Data minimisation —
*deleting* on schedule — is the half that reduces breach impact, and it is the half nobody funds
because its benefit is invisible until an incident.

⚠ **Retention wins over deletion, and the strictest policy wins over the others.** ⭐ So a retain
policy plus a delete policy means **retain** — which is why "we have a deletion policy" does not mean
data is being deleted.

---

## 2. ⭐ eDiscovery is an access-control question

> **eDiscovery lets a holder read anything in the tenant — every mailbox, every site, ⭐ including
> content preserved from deletion.**

⭐ **It is the most powerful read permission in Microsoft 365, and it is routinely granted to legal
and HR staff who are not treated as privileged users.**

```
eDiscovery Manager   ⭐ can search everything they are scoped to
eDiscovery Administrator ⭐ can access ALL cases, including others'
```

⭐ **`eDiscovery Administrator` deserves the same treatment as Global Administrator**: PIM-eligible,
access-reviewed, alerted on use. ⚠ It usually is not, because it is granted in a compliance portal by
a compliance process, **outside the identity governance that covers admin roles** — the same shape as
the AI indexer in
[`../../60-ai-and-secure-ai/ai-pipeline-nhi/`](../../60-ai-and-secure-ai/ai-pipeline-nhi/) §2:
⭐ **a read-everything capability issued outside the process that governs read-everything
capabilities.**

⭐ **And every search is audited.** `SearchQueryInitiatedExchange` / `SearchQueryInitiatedSharePoint`
and case-level events belong in your detection set — **an eDiscovery search against an executive's
mailbox by someone with no open case is a genuine insider-risk signal.**

---

## 3. Worked example — who can read everything

```powershell
Connect-IPPSSession

# ① ⭐ eDiscovery role holders - the most powerful read permission in the tenant
'eDiscovery Manager','eDiscovery Administrator','Compliance Administrator' | ForEach-Object {
  $rg = Get-RoleGroup -Identity $_ -EA SilentlyContinue
  if ($rg) {
    [pscustomobject]@{
      RoleGroup = $_
      Members   = ($rg.Members -join '; ')
      Count     = @($rg.Members).Count
    }
  }
}
```

```
RoleGroup                 Members                                   Count
------------------------  ----------------------------------------  -----
eDiscovery Manager        legal-team; h.reid; contractor.j            3
eDiscovery Administrator  h.reid                                      1   <-- ⭐ can open ALL cases
Compliance Administrator  h.reid; a.khan                              2
```

⭐ **`contractor.j` in eDiscovery Manager is the finding.** A contractor with the ability to search
mailboxes tenant-wide is an access decision nobody in identity governance made, reviewed or set an
expiry on.

```powershell
# ② ⭐ Retention: are you keeping, deleting, or only keeping?
Get-RetentionCompliancePolicy | ForEach-Object {
  $p = $_
  $rules = @(Get-RetentionComplianceRule -Policy $p.Name -EA SilentlyContinue)
  [pscustomobject]@{
    Policy   = $p.Name
    Enabled  = $p.Enabled
    Mode     = $p.Mode
    Actions  = ($rules | ForEach-Object {
                  if ($_.RetentionDuration -and $_.ExpirationDateOption) { 'retain-then-delete' }
                  elseif ($_.RetentionDuration) { 'retain' } else { 'delete' } }) -join ','
    Locations= (@('Exchange','SharePoint','OneDrive','Teams') |
                Where-Object { $p."$($_)Location" }) -join ','
  }
}
```

```
Policy                 Enabled  Mode      Actions            Locations
---------------------  -------  --------  -----------------  ------------------
Keep everything 7y        True  Enforce   retain             Exchange,SharePoint
                                          ▲
                     ⭐ retain only - nothing is ever deleted, ever
```

⭐ **"Retain, no delete, all locations, forever" is a common and expensive posture.** It maximises
eDiscovery exposure, maximises breach impact, and satisfies a *keep* obligation while quietly
breaching a *destroy* one.

```powershell
# ③ ⭐ What is actually on hold - the exposure nobody sizes
Get-Mailbox -ResultSize Unlimited |
  Where-Object { $_.LitigationHoldEnabled -or $_.InPlaceHolds } |
  Select-Object UserPrincipalName, LitigationHoldEnabled, LitigationHoldDuration,
                @{n='Holds';e={ ($_.InPlaceHolds) -join ',' }} |
  Select-Object -First 20
```

⭐ **Mailboxes on hold cannot be fully emptied, and their content survives account deletion** — which
is a control for litigation and an exposure for a subject-deletion request. **Both facts are true and
you must be able to state both.**

---

## 4. Insider risk and communication compliance — the privacy line

⭐ **These features monitor employees, and deploying them badly is a legal problem rather than a
technical one:**

| Feature | Watches | ⭐ Requirement |
|---|---|---|
| **Insider Risk Management** | ⭐ user behaviour — downloads, exfil patterns, leaver activity | ⭐ pseudonymisation, HR/legal sign-off |
| **Communication Compliance** | message content against policy | ⭐ works council / employee consultation in many jurisdictions |

⭐ **Turn on pseudonymisation by default.** Analysts see anonymised identifiers until an investigation
is escalated — which makes the capability defensible to a works council and to a regulator, and costs
nothing. ⚠ **In parts of Europe, deploying communication compliance without consultation is a labour
law issue before it is a privacy one**, and the technical team is usually unaware.

> ⭐ **The senior move here is the same as the biometric one in
> [`../../60-ai-and-secure-ai/azure-ai-services/`](../../60-ai-and-secure-ai/azure-ai-services/) §5:
> route it to legal and HR before designing it.** The junior answer is to configure the policy well.

⭐ **Leaver detection is the highest-value, least controversial use.** Insider Risk's *departing
employee* indicators correlate an HR leave date with a spike in downloads — which is a genuine, well
understood risk with a clear business case, and it is the one to start with.

---

## 5. What breaks

**Retention deployed only to retain.** §1 — ⭐ no minimisation, maximal exposure.

**Assuming a delete policy deletes.** §1 — ⭐ retain wins.

**eDiscovery roles outside identity governance.** §2 — ⭐ read-everything, ungoverned.

**`eDiscovery Administrator` not treated as privileged.** §2 — can open all cases.

**No detection on eDiscovery searches.** §2 — a real insider-risk signal, unused.

**Contractors in compliance role groups.** §3.

**Not sizing what is on hold.** §3 — the exposure nobody measures.

**Insider risk without pseudonymisation.** §4 — indefensible to a works council.

**Communication compliance without consultation.** §4 — ⚠ a labour-law problem.

**Treating "we deleted it" as true.** §1 — preservation hold and Recoverable Items.

---

## 6. Customer discovery questions

1. Do your retention policies **delete**, or only **retain**? *(§3 — run it.)*
2. ⭐ Who holds **eDiscovery Manager** and **eDiscovery Administrator**? *(§3.)*
3. Are those roles in **PIM** and **access reviews**? *(§2.)*
4. Do you **alert** on eDiscovery searches, especially against executives?
5. How many mailboxes are **on hold**, and for how long? *(§3.)*
6. What is your answer to a **subject deletion request** given holds and preservation? *(§3.)*
7. Is **Insider Risk** pseudonymised? *(§4.)*
8. Was **Communication Compliance** consulted on with HR, legal and any works council?
9. ⭐ Which obligation are you *failing* — keeping too little, or destroying too little?

---

## 7. Remember it

**Hook — "Retention overrides the user. eDiscovery reads everyone."**

**Analogy — the archive in the basement, and who has the key.** ⭐ **Retention is a rule that every
document you throw away is quietly retrieved from the bin and filed downstairs**, where you cannot see
it and cannot reach it. That is exactly what you want when a regulator asks what happened in 2023. ⭐
**eDiscovery is the key to that basement — and it opens everyone's shelf, not just yours.** ⭐ **The
key is usually handed out by the legal department, in a different building, using a different process
from the one that governs every other master key in the organisation.**

**The one thing:** ⭐ **eDiscovery is the most powerful read permission in Microsoft 365 and it is
granted outside identity governance.** A holder can search every mailbox and every site, **including
content users deleted**, and the role is typically assigned in a compliance portal by a compliance
process — so it does not appear in the privileged-role review, is not PIM-eligible, and has no expiry.
**Put eDiscovery role groups into the same review as Global Administrator, and alert on searches** —
it is the same finding shape as the AI indexer: a read-everything capability issued outside the
process that governs read-everything capabilities.

**Runner-up:** ⭐ **retain beats delete**, so a tenant with both policies is retaining — and "we have a
deletion policy" is not evidence that anything is deleted.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 8. Self-test

1. ⭐ What makes retention different in kind from every other control here?
2. Where does preserved content live, and who can see it?
3. Name retention's two opposite jobs and the failure mode of each.
4. ⭐ What happens when a retain policy and a delete policy both apply?
5. ⭐ Why is eDiscovery an access-control question?
6. What extra power does eDiscovery Administrator have?
7. Which detection should exist around eDiscovery, and what does it catch?
8. What is the effect of a hold on account deletion and on a subject deletion request?
9. ⭐ What must be true before deploying Insider Risk and Communication Compliance?
10. Which insider-risk use case is the least controversial place to start?

<details>
<summary>Answers</summary>

1. ⭐ Every other control restricts what someone may **do**; retention ⭐ **overrides what they already
   did** — it preserves content the user deleted.
2. ⭐ **Recoverable Items** (mailbox) and the ⭐ **preservation hold library** (SharePoint) — invisible
   to the owner, discoverable by eDiscovery.
3. ⭐ **Keep** (failure: cannot answer an investigation) and ⭐ **delete/minimise** (failure: holding
   data you promised to destroy).
4. ⭐ **Retain wins**, and the strictest policy wins — so nothing is deleted.
5. ⭐ Because it is a **read-everything permission over every mailbox and site**, including deleted
   content — the most powerful read in the tenant.
6. ⭐ **Access to all cases**, including other people's.
7. ⭐ **Alert on search-initiated events** — an eDiscovery search against an executive with no open
   case is an insider-risk signal.
8. Content ⭐ **survives account deletion** and cannot be fully purged — a litigation control and a
   ⭐ **subject-deletion-request problem** simultaneously.
9. ⭐ **Pseudonymisation on**, and ⭐ **HR, legal and (in many jurisdictions) works council
   consultation** — a labour-law question before a technical one.
10. ⭐ **Departing-employee detection** — correlating an HR leave date with a download spike.

</details>

---

## 9. Evidence this topic needs

- **`lab/`** ⭐ — the §3 three queries: eDiscovery role holders, retention actions, and mailboxes on
  hold. **Runnable today on the E5 licence** — and the role-holder query is the one to run first.
- **`break-fix/`** ⭐ — apply a retain policy to a test mailbox, **delete a message as the user**, then
  **recover it via eDiscovery**. ⭐ **Watching your own "deleted" message come back is what makes
  retention real to a team**, and it doubles as the privacy conversation starter.
- **`security/`** — eDiscovery and compliance role membership with review dates; retention policy
  matrix showing retain vs delete per location; mailboxes on hold with durations; eDiscovery search
  alerting.
- **`operations/`** — subject-deletion-request procedure accounting for holds; hold release process;
  insider-risk escalation path with pseudonymisation lifting recorded.
- **`architecture-decisions/`** — ADR: eDiscovery roles governed as privileged access (PIM + reviews);
  ⭐ retention includes a **deletion** schedule, not only preservation.
- **`customer-use-cases/`** — §6 answered; "a contractor can search every mailbox" as the headline.
