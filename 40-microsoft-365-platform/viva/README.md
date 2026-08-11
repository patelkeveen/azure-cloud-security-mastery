# Viva

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The sleeper topic: the only part of M365 whose primary risk is to your own employees, and whose
> main stakeholder is not IT.**
> Pairs with [`../purview-compliance/`](../purview-compliance/) §4.

---

## 1. What it is

**A family of employee-experience products sitting on data the platform already collects:**

| Module | ⭐ What it processes |
|---|---|
| ⭐ **Viva Insights** | ⭐ **behavioural metadata** — meeting hours, after-hours activity, collaboration graph |
| **Viva Engage** | an internal social network (formerly Yammer) — ⭐ user-generated content at scale |
| **Viva Connections** | a portal surface over SharePoint |
| **Viva Learning** | training content aggregation |
| **Viva Goals / Glint** | objectives; ⭐ survey responses, often expected to be confidential |

⭐ **Viva Insights is the one to understand.** It does not read message *content* — ⭐ **it analyses the
metadata of who talked to whom, when, and for how long**, which for many purposes is more revealing
than content and is far less protected by anyone's instincts.

---

## 2. ⭐ Metadata is the sensitive part

> **A collaboration graph answers questions that no individual email would: who is isolated, who is
> job-hunting, which two people started meeting privately last month, and which team is being wound
> down.**

⭐ **This is the same insight as the AI aggregate-disclosure problem** in
[`../../60-ai-and-secure-ai/ai-search-and-rag/`](../../60-ai-and-secure-ai/ai-search-and-rag/) §2:
**each individual data point is innocuous and permitted; the synthesis across all of them is a new
capability nobody granted.**

**The three tiers, and only the third is contentious:**

| Tier | Who sees it | ⭐ Risk |
|---|---|---|
| ⭐ **Personal insights** | ⭐ **only the individual** | low — and it is the default |
| **Manager / team insights** | aggregated, ⚠ minimum group size | ⭐ re-identification in small teams |
| ⭐ **Advanced Insights** (analyst) | ⭐ organisation-wide, custom queries | ⭐ **surveillance capability** |

⭐ **The minimum group size is the load-bearing control** for the middle tier — aggregate over five
people and one person's data is recoverable by subtraction. ⚠ **Verify the current default and raise
it deliberately**; teams smaller than the threshold should simply produce no report.

⭐ **Advanced Insights is where a works council conversation belongs.** It is a legitimate,
well-designed analytics product **and** it can answer "show me everyone whose external
communication increased before they resigned" — which is a different thing from an employee-experience
feature, and it should be governed as such.

---

## 3. Worked example — what is switched on, and for whom

```powershell
Connect-ExchangeOnline

# ① ⭐ Who is EXCLUDED from Viva Insights processing? (privacy settings live per-user)
Get-VivaInsightsSettings -Identity <upn> -EA SilentlyContinue
# ⚠ Cmdlet surface for Viva has changed repeatedly - verify the current module and names.
```

```powershell
# ② ⭐ Viva Engage: who can create communities, and are any PUBLIC to the whole tenant?
Connect-MgGraph -Scopes 'Group.Read.All'

Get-MgGroup -All -Property Id,DisplayName,Visibility,GroupTypes,CreatedDateTime |
  Where-Object { $_.GroupTypes -contains 'Unified' } |
  Where-Object { $_.DisplayName -match 'engage|yammer|community|social' -or $_.Visibility -eq 'Public' } |
  Select-Object DisplayName, Visibility, CreatedDateTime |
  Sort-Object CreatedDateTime -Descending | Select-Object -First 20
```

⭐ **Viva Engage communities are Microsoft 365 Groups** — so everything in
[`../microsoft-365-groups/`](../microsoft-365-groups/) applies, including ownerless and public
findings. **Engage is not a separate governance problem; it is the same one with a social UI**, and
that recognition saves inventing a new control set.

```powershell
# ③ ⭐ Engage content is discoverable - which surprises people who treat it as chat
#     Community conversations are stored in the group mailbox and are eDiscoverable.
```

⭐ **Employees treat Engage like a social network and it is retained and discoverable like email.** A
frank complaint posted in a community is a record: subject to retention
([`../purview-compliance/`](../purview-compliance/) §1), searchable by eDiscovery, and producible in
litigation. **Nobody tells them this**, and it is the single most useful thing to add to the rollout
communication.

---

## 4. ⭐ The stakeholder is not IT

**This is the governance point, and it is what makes the topic worth a senior engineer's attention:**

```
Viva Insights (advanced)  →  ⭐ HR, legal, works council  ← BEFORE deployment
Viva Engage               →  ⭐ comms + records management
Viva Glint surveys        →  ⭐ confidentiality promises made to employees
```

⭐ **Deploying Advanced Insights without HR and legal is the same class of mistake as deploying face
recognition without legal** ([`../../60-ai-and-secure-ai/azure-ai-services/`](../../60-ai-and-secure-ai/azure-ai-services/) §5)
**or Communication Compliance without works council consultation**
([`../purview-compliance/`](../purview-compliance/) §4). ⭐ **Three products, one judgement: some
capabilities are legal questions before they are configuration questions**, and recognising which is a
skill that does not appear on any certification.

⚠ **Glint deserves a specific warning.** Survey tools carry an explicit or implied confidentiality
promise to respondents. ⭐ **If the platform's aggregation thresholds allow a manager to infer an
individual response, the organisation has broken a promise it made in writing** — and the technical
setting that prevents it is a minimum-response threshold nobody reviews.

---

## 5. What breaks

**Treating metadata as non-sensitive.** §2 — ⭐ the collaboration graph is the revealing part.

**Default minimum group size accepted.** §2 — ⭐ re-identification by subtraction.

**Advanced Insights deployed by IT alone.** §4 — ⭐ a legal question, not a configuration one.

**Engage governed separately from Groups.** §3 — ⭐ it *is* Groups.

**Employees unaware Engage is discoverable.** §3 — a record they thought was a chat.

**Glint thresholds unreviewed.** §4 — ⭐ a broken confidentiality promise.

**No retention decision on Engage content.** It is retained by default or not at all — decide.

**Assuming Viva is "just" employee experience.** §1 — ⭐ it processes behavioural data about people.

**Ignoring it because it looks non-technical.** ⭐ The absence of a technical risk is not the absence
of a risk.

---

## 6. Customer discovery questions

1. Is **Advanced Insights** in use, and who approved it — ⭐ was **HR and legal** involved? *(§4.)*
2. What is the **minimum group size** for manager insights, and was it raised? *(§2.)*
3. Can employees **opt out**, and do they know they can?
4. Are **Engage communities** governed as Microsoft 365 Groups — ownerless, public? *(§3.)*
5. ⭐ Do employees know Engage posts are **retained and discoverable**? *(§3.)*
6. What **retention** applies to Engage content?
7. Are **Glint** aggregation thresholds sufficient to keep the confidentiality promise? *(§4.)*
8. Is there a **works council** or equivalent, and were they consulted?
9. ⭐ Could this capability answer *"who is likely to resign?"* — and is that an intended use?

---

## 7. Remember it

**Hook — "It reads the calendar, not the letters — and the calendar says more."**

**Analogy — the visitor log versus the conversations.** ⭐ **Nobody recorded what was said in any
meeting.** All you have is who booked a room with whom, how often, and at what hour. ⭐ **And from that
alone you can see the reorganisation forming, the person quietly interviewing elsewhere, and the team
that has stopped being included** — none of which appears in a single document, and all of which is
visible in the pattern. **Metadata is not the weaker copy of content; for some questions it is the
stronger one.**

**The one thing:** ⭐ **Viva Advanced Insights is a surveillance capability wearing an
employee-experience label, and the decision to deploy it belongs to HR and legal before it belongs to
IT.** The product is well built, the aggregation controls are real, and none of that answers whether
your organisation may lawfully analyse the collaboration patterns of named employees — which in many
jurisdictions requires consultation, not merely configuration. ⭐ **Knowing to route it there before
designing it is the same judgement as routing face recognition to legal**, and it is a mark of
seniority that no exam tests.

**Runner-up:** ⭐ **Viva Engage is Microsoft 365 Groups** — govern it there, and tell employees their
posts are discoverable.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 8. Self-test

1. What does Viva Insights process, and what does it not?
2. ⭐ Why is metadata the sensitive part, and which AI problem is that the same as?
3. Name the three insight tiers and who sees each.
4. ⭐ What is the load-bearing control for manager insights, and what defeats it?
5. Which tier requires a works council conversation, and why?
6. What are Viva Engage communities, technically — and what follows?
7. ⭐ What do employees usually not know about Engage?
8. What promise can Glint break, and via which setting?
9. ⭐ Name three capabilities in this repo that are legal questions before configuration questions.
10. Why is "it's just employee experience" the wrong frame?

<details>
<summary>Answers</summary>

1. ⭐ **Behavioural metadata** — meeting hours, after-hours activity, the collaboration graph. ⭐ **Not
   message content.**
2. ⭐ Because the **collaboration graph** reveals reorganisations, isolation and departures that no
   individual message contains. ⭐ Same as **aggregate disclosure in RAG** — innocuous points,
   revealing synthesis.
3. ⭐ **Personal** (only the individual), **manager/team** (aggregated, minimum group size),
   ⭐ **Advanced Insights** (organisation-wide, analyst).
4. ⭐ The **minimum group size**. ⭐ Small teams defeat it — one person's data is recoverable **by
   subtraction**.
5. ⭐ **Advanced Insights** — it can answer questions about named employees' behaviour, which is a
   surveillance capability rather than an experience feature.
6. ⭐ **Microsoft 365 Groups** — so ownerless, public-visibility and lifecycle findings all apply, and
   no new control set is needed.
7. ⭐ That posts are **retained and eDiscoverable** — a record they believed was a chat.
8. ⭐ A **confidentiality promise to respondents**, via an insufficient ⭐ **minimum-response
   threshold** allowing individual answers to be inferred.
9. ⭐ **Viva Advanced Insights, Communication Compliance, and face/biometric recognition.**
10. ⭐ Because it **processes behavioural data about identifiable people** — the absence of a technical
    risk is not the absence of a risk.

</details>

---

## 9. Evidence this topic needs

- **`lab/`** ⭐ — the §3 Engage community inventory as Microsoft 365 Groups (ownerless, public), and
  the Insights privacy settings review. **The Groups half is runnable today on the E5 licence.**
- **`break-fix/`** ⭐ — set the manager-insight minimum group size to its floor, run a report against a
  small team, and ⭐ **show that one member's figures are recoverable by subtraction**; then raise the
  threshold and show the report suppressed. **That demonstration is the privacy argument, made with
  arithmetic rather than opinion.**
- **`security/`** — Viva modules enabled with approval records; minimum group size values; Advanced
  Insights analyst list; Engage community governance status; Glint thresholds.
- **`operations/`** — employee communication stating what is processed and that Engage is
  discoverable; opt-out process; retention decision for Engage content.
- **`architecture-decisions/`** — ADR: ⭐ Advanced Insights requires HR and legal sign-off before
  enablement, with the jurisdictional reasoning recorded; minimum group size raised deliberately.
- **`customer-use-cases/`** — §6 answered; the works-council question raised before any technical
  design.
