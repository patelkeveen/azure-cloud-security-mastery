# Migration Tools

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **You are not choosing a tool. You are choosing which failures you are willing to own.**
> Pairs with [`../discovery-and-assessment/`](../discovery-and-assessment/) and
> [`../migration-reconciliation/`](../migration-reconciliation/).

---

## 1. What it is

The landscape of native Microsoft tooling and the third-party market that exists because of its
gaps. ⭐ **The native tools are free and sufficient for the common case; the paid tools exist almost
entirely to solve two problems — cross-tenant, and fidelity of things Microsoft does not move.**

---

## 2. Why the third-party market exists

Map each product to the specific native gap it fills, and the market stops looking like a catalogue:

| Native gap | What it costs you | The market's answer |
|---|---|---|
| ⭐ **No native Teams *message* migration between tenants** | rebuild history by hand | Quest, AvePoint, BitTitan |
| ⭐ **Cross-tenant needs heavy pre-staging** | weeks of scripting | tools that auto-match and pre-stage identities |
| ⭐ **No Outlook profile reconfiguration at the endpoint** | ⭐ 500 desk visits | BitTitan **DeploymentPro** |
| SharePoint permission remapping is manual | error-prone | ShareGate, AvePoint |
| No unified reporting across workloads | ⭐ **you cannot prove completion** | every commercial suite |
| IMAP moves mail only | no calendar/contacts | any commercial mailbox tool |

⭐ **"How do 500 users' Outlook profiles get reconfigured?" is the question that decides most
tenant-to-tenant tool purchases**, and it is almost never asked in the first meeting. Ask it.

---

## 3. How it works underneath — three architectures, three failure modes

```
① AGENT-BASED        agent on-prem ──► reads source directly ──► pushes to M365
   (SPMT, Migration     ⭐ fails when: the agent host runs out of disk,
    Manager, ShareGate)     CPU, or its service account's password expires

② SERVICE-SIDE       MRS in EXO ──pulls──► source over HTTPS
   (native Exchange     ⭐ fails when: the endpoint is unreachable or throttled.
    hybrid + T2T)          ⭐ You cannot make it faster. You can only wait.

③ SaaS BROKER        vendor cloud ──reads source──► writes target
   (BitTitan,           ⭐ fails when: credentials expire mid-run, and
    Quest On Demand)    ⭐ CUSTOMER DATA TRANSITS A THIRD PARTY
                           — this is a security review item, not a footnote
```

⭐ **Architecture ③ is a data-processing arrangement.** Customer mail and files pass through a
vendor's cloud. That requires a DPA, a data-residency answer, and — in regulated sectors —
⭐ **explicit sign-off before the pilot, not before go-live.** Raising this unprompted is a
distinguishing move in a consulting conversation, and it is a genuine SC-300-adjacent control
question: *which non-human identity in my tenant can this vendor use, and with what permissions?*

---

## 4. Worked example — the selection matrix, applied

**Scenario:** acquisition. 1,400 users, source and target both Microsoft 365. Teams history is
contractually required. Six-week deadline.

| Requirement | Native | ⭐ Third party |
|---|---|---|
| Mailboxes cross-tenant | ✅ (heavy pre-staging) | ✅ automated |
| OneDrive / SharePoint | ⚠ check current cross-tenant scope | ✅ |
| ⭐ **Teams channel messages** | ⭐ Graph import, ⭐ **custom code** | ✅ productised |
| ⭐ **1,400 Outlook profiles** | ⭐ **manual** | ✅ DeploymentPro-style agent |
| Unified completion report | ✗ | ✅ |

**Decision:** third party. **The reasoning, stated as cost rather than preference:**

```
Native path
  pre-staging + Graph import development   ≈ 15 consultant-days
  ⭐ 1,400 profile reconfigurations
     x 15 min, ⭐ at 40 % helpdesk overhead ≈ 41 consultant-days
                                    TOTAL  ≈ 56 days

Third-party licence
  1,400 users x ~USD 12–15 per user        ≈ USD 17,000 – 21,000
  plus ≈ 10 consultant-days of setup
```

⭐ **At any realistic day rate, 46 saved consultant-days exceeds the licence cost — and the licence
is a fixed, quotable number while the manual path is an open-ended risk.** ⭐ **That is the argument
that wins the budget conversation**, and it is the same argument in every migration: convert the
unbounded manual effort into a bounded line item.

⚠ `⚠ check` — per-user pricing is indicative only. It varies by volume, workload bundle, region and
promotion. **Get a quote; never state a vendor price from memory in front of a customer.**

---

## 5. The tools worth knowing by name

| Tool | Best at | Watch out for |
|---|---|---|
| ⭐ **SPMT** | file share / SP Server → SPO | agent host resources; ⭐ no permission remapping |
| ⭐ **Migration Manager** | many file servers, Google/Box/Dropbox | agent fleet management |
| ⭐ **Native EXO migration batches** | anything Exchange → EXO | ⭐ nothing but mailboxes |
| **BitTitan MigrationWiz** | mailboxes at scale, ⭐ **DeploymentPro** for profiles | per-user licences; SaaS broker |
| **Quest On Demand Migration** | ⭐ tenant-to-tenant incl. Teams and identity | cost at small scale |
| **AvePoint Fly** | SharePoint/Teams fidelity | complexity |
| **ShareGate** | SharePoint content + permissions, ⭐ pre-migration reports | SharePoint-focused |
| **CodeTwo** | SMB mailbox migration | smaller feature set |

⭐ **Do not memorise feature grids — they are stale within a quarter.** Memorise the *gaps* in §2;
they change far more slowly, and they are what the customer is actually buying.

---

## 6. Commands — measure the tool, do not trust its dashboard

**① Measure real throughput, so the tool choice is evidence-based:**

```powershell
$s = Get-MigrationUser a.khan@contoso.com | Get-MigrationUserStatistics
[pscustomobject]@{
    GB      = [math]::Round($s.BytesTransferred.ToBytes()/1GB, 2)
    Hours   = [math]::Round(((Get-Date) - $s.SyncStart).TotalHours, 2)
    GBPerHr = [math]::Round(($s.BytesTransferred.ToBytes()/1GB) /
                            ((Get-Date) - $s.SyncStart).TotalHours, 2)
}
```

```
  GB  Hours  GBPerHr
4.71   6.83     0.69
```

⭐ **0.69 GB/hour is your measured rate — the only number worth putting in a plan.** Multiply it by
your concurrency to get the real project duration, and re-measure after any concurrency change.
⚠ `⚠ check` — property names on migration statistics vary by workload and module version; confirm
with `Get-MigrationUserStatistics a.khan@contoso.com | Format-List *` before scripting.

**② Audit the migration service account — the standing security exception:**

```powershell
Get-MgIdentityConditionalAccessPolicy -All |
  Where-Object State -ne 'disabled' | ForEach-Object {
    if ($svcId -in $_.Conditions.Users.ExcludeUsers) {
        [pscustomobject]@{ Policy = $_.DisplayName; Excluded = $true }
    }
  }
```

```
Policy                      Excluded
Require MFA for all users   True
```

⭐ **Every row here is a control you have deliberately switched off.** Print this list on day one,
put a removal date against each row, and re-run it on the last day of the project. ⭐ **An
exclusion nobody scheduled for removal becomes permanent** — the same failure mode as break-glass
accounts that were never reviewed.

**③ Confirm the account is being used from where you expect:**

```powershell
Get-MgAuditLogSignIn -Filter "userPrincipalName eq 'svc-migration@contoso.com'" -Top 5 |
  Select-Object CreatedDateTime, IpAddress, AppDisplayName, @{n='Status';e={$_.Status.ErrorCode}}
```

```
CreatedDateTime      IpAddress       AppDisplayName        Status
18/08/2026 19:02:11  203.0.113.44    MigrationWiz              0
18/08/2026 18:44:03  203.0.113.44    MigrationWiz              0
```

⭐ **An unexpected IP on a migration account is an incident, not a curiosity** — that credential can
read every mailbox in scope.

---

## 7. When and where

| Situation | Choose |
|---|---|
| Exchange → EXO, any size | ⭐ **native**. Paying here is waste |
| File share → SPO, simple permissions | ⭐ native (SPMT / Migration Manager) |
| ⭐ **Tenant-to-tenant with Teams history** | ⭐ **third party. Effectively always** |
| Google → M365, mail only | native |
| Google → M365, Drive with fidelity | third party |
| ⭐ Regulated data, vendor cloud prohibited | ⭐ **native or agent-based only** — architecture ③ is out |

⭐ **The last row is a hard constraint that overrules cost.** If the customer's data cannot transit a
third party, the tool shortlist is decided before any feature comparison — and finding this out in
week six instead of week one is a project-level failure.

---

## 8. What breaks

| Symptom | Architecture | Cause |
|---|---|---|
| Run stops overnight, resumes on restart | ① agent | ⭐ agent host slept, or the service account's password expired |
| Throughput far below expectation | ② service-side | ⭐ throttling — not fixable by licensing |
| `401` mid-run after hours of success | ③ SaaS | ⭐ **token or app-password expiry**, or MFA newly enforced |
| Tool reports success, users report loss | any | ⭐ **skipped items not surfaced** — [`../migration-reconciliation/`](../migration-reconciliation/) |
| Permissions did not migrate | ① SPMT | ⭐ by design — SPMT does not remap identities |
| Security review blocks go-live | ③ | ⭐ DPA not signed. **Start this in week one** |

⭐ **The MFA case deserves attention:** a migration service account exempted from MFA is a standing
security exception. It must be **time-boxed, conditional-access scoped to known IPs, and removed on
completion** — the same discipline as break-glass. See
[`../../30-identity-and-nhi/conditional-access/`](../../30-identity-and-nhi/conditional-access/).

---

## 9. Customer discovery questions

1. ⭐ **"May customer data transit a third-party cloud service?"** — ask first; it eliminates a tier
2. ⭐ **"How will 1,400 Outlook profiles be reconfigured, and by whom?"**
3. "Do you need Teams message history, contractually or practically?"
4. "Who signs a data processing agreement, and how long does that take?"
5. "Is there an existing enterprise agreement with any of these vendors?"
6. ⭐ **"What does the completion report need to show, and who reads it?"**
7. "Are source credentials subject to MFA or conditional access?"

---

## 10. Remember it

**Hook — `A S B`: Agent, Service-side, SaaS Broker.** Three architectures — and each has exactly one
characteristic failure: **resources**, **throttling**, **credentials/data-residency**.

**Analogy — hiring movers.** ⭐ **Doing it yourself with a van (agent) means your van, your fuel,
your back. Using the building's own goods lift (service-side) means their schedule, their speed —
you cannot make the lift faster. Hiring a full-service firm (SaaS broker) is fastest and easiest,
but strangers now handle every box.** The analogy predicts each failure mode and predicts the
security question: **you would ask a removals firm who has keys to the warehouse.**

**The one line:** ⭐ **Native for like-for-like; pay only for cross-tenant, Teams history, and the
endpoint problem.**

---

## 11. Self-test

1. Name the three tool architectures and their characteristic failure.
   → Agent (host resources), service-side (throttling), SaaS broker (credentials / data residency).
2. Which native gap most often justifies a third-party purchase in tenant-to-tenant?
   → ⭐ Teams message history, and endpoint Outlook profile reconfiguration.
3. Why is throttling not solvable with a better tool?
   → ⭐ It is enforced service-side by Microsoft, per tenant.
4. What must be signed before a SaaS broker touches production data?
   → ⭐ A data processing agreement, with a data-residency answer.
5. SPMT migrated files but not permissions. Bug?
   → ⭐ No — SPMT does not remap identities. Design choice.
6. How do you turn a tool licence into a budget argument?
   → ⭐ Price the manual alternative in consultant-days; the licence is bounded, the manual path is not.
7. What is the risk of the migration service account, and the control?
   → ⭐ A standing MFA exception; time-box it, scope CA to known IPs, remove on completion.

---

## 12. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | one native run and — if available — one trial run of a commercial tool, compared |
| `security` | ⭐ the migration service account's permissions, CA scoping, and removal record |
| `operations` | the throughput measured per architecture, with timestamps |
| `customer-use-cases` | ⭐ the selection matrix filled in for a real scenario, with the cost argument |
| `architecture-decisions` | the written tool decision, including the data-residency constraint |
