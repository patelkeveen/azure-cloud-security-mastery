# Budgets and Cost Controls

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Cost is a security telemetry stream, and it is the one nobody routes to the SOC.**
> Pairs with [`../../60-ai-and-secure-ai/model-access-control/`](../../60-ai-and-secure-ai/model-access-control/) §4.

---

## 1. ⭐ Why this is a security topic

**Several attacks have no signature, no malware and no anomalous login — and a very obvious cost
curve.**

| Attack | Security signal | ⭐ Cost signal |
|---|---|---|
| **Crypto-mining** on compromised compute | ⚠ often none — it is just CPU | ⭐ **immediate and enormous** |
| ⭐ **Denial of wallet** (leaked AI key) | none — valid credential, valid calls | ⭐ **the only signal there is** |
| **Data exfiltration** at volume | maybe none, if it looks like normal egress | ⭐ **egress charges spike** |
| Resource sprawl from a compromised CI identity | ⚠ diffuse | ⭐ new resources, new spend |

> ⭐ **For denial of wallet, the finance alert *is* the security alert.** A leaked API key on an
> uncapped endpoint produces perfectly valid, perfectly authenticated traffic
> ([`../../60-ai-and-secure-ai/azure-openai/`](../../60-ai-and-secure-ai/azure-openai/) §3) — nothing
> in the security stack has anything to flag. **The bill is the detection.**

⭐ **So the finding in most organisations is organisational, not technical: cost alerts go to finance
and security never sees them.** Routing budget alerts into the same queue as security alerts costs
nothing and closes a real gap.

---

## 2. ⭐ Budgets alert. Quotas stop.

**This is the distinction that decides whether you have a control or a notification.**

```
⭐ BUDGET   →  sends an email / triggers an action group   ⭐ SPENDING CONTINUES
⭐ QUOTA    →  the API refuses to allocate                 ⭐ SPENDING STOPS
```

| Mechanism | Enforces? | ⭐ Use for |
|---|---|---|
| **Budget + alert** | ⭐ **No** | visibility, trend, the 2 a.m. signal |
| **Budget + action group → automation** | partly | ⭐ automated response you wrote |
| ⭐ **Quota / limits** | ⭐ **Yes** | ⭐ the actual ceiling |
| ⭐ **AI deployment TPM ceiling** | ⭐ **Yes** | denial-of-wallet containment |
| **Policy denying expensive SKUs** | ⭐ Yes | prevention at deploy time |

⭐ **A budget is a smoke alarm, not a sprinkler.** Anyone presenting budgets as protection against
runaway spend has confused detection with control — the same category error as presenting a lock as a
security control ([`../resource-locks/`](../resource-locks/) §2), and this domain now has three
instances of it. **That pattern — *does this stop it, or just tell me about it?* — is the question to
ask of every control in this domain.**

⭐ **The real ceilings are quotas** ([`../subscriptions-and-management-groups/`](../subscriptions-and-management-groups/)
§5): vCPU quota per region caps a mining incident at the quota rather than the credit card, and a TPM
ceiling caps a leaked AI key at a bounded incident.

---

## 3. Worked example — a budget wired to security, not just finance

```bash
# ① The budget, with a forecast alert - forecast fires BEFORE the money is spent
az consumption budget create \
  --budget-name bg-sub-prod --amount 5000 --time-grain Monthly \
  --category Cost --start-date 2026-08-01 --end-date 2027-08-01 \
  --notifications '{
    "actual80":  {"enabled":true,"operator":"GreaterThan","threshold":80,
                  "contactGroups":["/subscriptions/<sub>/resourceGroups/rg-ops/providers/microsoft.insights/actionGroups/ag-secops"]},
    "forecast100":{"enabled":true,"operator":"GreaterThan","threshold":100,
                  "thresholdType":"Forecasted",
                  "contactGroups":["/subscriptions/<sub>/resourceGroups/rg-ops/providers/microsoft.insights/actionGroups/ag-secops"]}
  }'
```

⭐ **Two details make this a security control rather than a finance one:**

1. ⭐ **`Forecasted` fires on trajectory, not on damage.** An actual-80% alert on a mining incident
   arrives after the money is gone; a forecast alert fires when the *rate* changes. **Rate is the
   signal; total is the aftermath.**
2. ⭐ **The action group is `ag-secops`.** That one string is the organisational fix in §1.

**② Then the query that turns spend into a finding:**

```kusto
// ⭐ Sudden cost appearance by service - what started costing money that did not before?
Usage
| where TimeGenerated > ago(14d)
| summarize Cost = sum(Quantity) by bin(TimeGenerated, 1d), DataType
| order by TimeGenerated asc
```

```powershell
# Or straight from the consumption API - ⭐ compare this week against last
$rows = az consumption usage list --start-date (Get-Date).AddDays(-14).ToString('yyyy-MM-dd') `
        --end-date (Get-Date).ToString('yyyy-MM-dd') -o json | ConvertFrom-Json

$rows | Group-Object { $_.instanceName } | ForEach-Object {
    $recent = @($_.Group | Where-Object { [datetime]$_.usageStart -ge (Get-Date).AddDays(-7) })
    $prior  = @($_.Group | Where-Object { [datetime]$_.usageStart -lt (Get-Date).AddDays(-7) })
    $r = ($recent | Measure-Object pretaxCost -Sum).Sum
    $p = ($prior  | Measure-Object pretaxCost -Sum).Sum
    if ($p -gt 0 -and $r -gt ($p * 3)) {
        [pscustomobject]@{ Resource=$_.Name; Prior=[math]::Round($p,2); Recent=[math]::Round($r,2) }
    } elseif ($p -eq 0 -and $r -gt 50) {
        [pscustomobject]@{ Resource=$_.Name; Prior=0; Recent=[math]::Round($r,2) }
    }
}
```

```
Resource              Prior   Recent
--------------------  ------  ------
vm-datasci-gpu-04       0.00  1842.55     <-- ⚠⚠⚠ appeared from nothing
foundry-prod          112.40   987.20     <-- ⚠⚠ 8x on an AI endpoint
```

⭐ **Row one is a GPU VM that cost nothing and now costs £1,842 — that is a mining incident until
proven otherwise.** Row two is an 8× jump on a model endpoint, which is **denial of wallet until
proven otherwise**. ⭐ **Neither generated a security alert.** Both are visible in one query, and
`Prior = 0` is the highest-signal pattern in the whole dataset.

---

## 4. The controls that actually stop spend

**In order of strength:**

```
① ⭐ POLICY at deploy time   deny expensive SKUs / GPU sizes outside approved scopes
② ⭐ QUOTA                   request small, raise deliberately — a free ceiling
③ ⭐ AI TPM ceilings         per-deployment, bounds a leaked key
④   Auto-shutdown / TTL      dev and sandbox resources expire
⑤   Budget + automation      an action group that disables, not just emails
```

```bash
# ⭐ ① Prevention beats detection: deny GPU SKUs outside the approved resource group
az policy assignment create -n deny-gpu-outside-ml \
  --policy /providers/Microsoft.Authorization/policyDefinitions/cccc23c7-8427-4f53-ad12-b6a63eb452b3 \
  --scope /subscriptions/<sub> \
  --params '{"listOfAllowedSKUs":{"value":["Standard_D2s_v5","Standard_D4s_v5"]}}' \
  --not-scopes /subscriptions/<sub>/resourceGroups/rg-ml-approved
```

⭐ **`--not-scopes` is the pattern to know**: allow the exception explicitly and narrowly, rather than
weakening the policy everywhere. It is the Policy equivalent of scoping a role assignment tightly
instead of granting it broadly.

⚠ **`mg-sandbox` needs a hard budget and a short TTL**
([`../landing-zones/`](../landing-zones/) §3) — a permissive management group without a cost ceiling
is where an incident becomes expensive.

---

## 5. What breaks

**Budget alerts going only to finance.** §1 — ⭐ the organisational finding.

**Treating a budget as a control.** §2 — ⭐ it alerts; it does not stop.

**Only actual-threshold alerts, no forecast.** §3 — ⭐ you learn after the money is gone.

**Oversized quota requested by default.** §2 — discards a free ceiling.

**No TPM ceiling on AI deployments.** ⭐ Unbounded denial of wallet.

**No cost anomaly detection.** §3 — ⭐ `Prior = 0` is the highest-signal pattern and nobody queries it.

**Permissive sandbox with no budget.** §4.

**Weakening a policy instead of using `--not-scopes`.** §4.

**Investigating cost anomalies as billing errors.** ⭐ Mining and exfiltration are closed as
"someone left a VM on".

**No auto-shutdown in dev.** Cost and attack surface, both permanent.

---

## 6. Customer discovery questions

1. ⭐ **Who receives budget alerts — does security see them?** *(§1.)*
2. Are alerts **forecast-based** or actual-only? *(§3.)*
3. Is there a **quota** posture, or was maximum requested by habit? *(§2.)*
4. Do AI deployments have **TPM ceilings**? *(§4.)*
5. Would a **leaked key** produce a bounded incident or an unbounded bill?
6. Is there **cost anomaly detection**, especially ⭐ `Prior = 0` resources? *(§3.)*
7. Does the **sandbox** have a hard budget and a TTL?
8. When a cost anomaly is found, is it triaged as **billing** or as **security**? *(§5.)*
9. Which expensive SKUs are **denied by policy**, and where are the exceptions scoped?

---

## 7. Remember it

**Hook — "Budgets alert. Quotas stop."**

**Analogy — a smoke alarm versus a sprinkler.** ⭐ **A budget is a smoke alarm: loud, useful, and the
building still burns.** ⭐ **A quota is a sprinkler** — it acts without waiting for anyone to read an
email. Most organisations install alarms, route them to the accounts department, and describe the
result as fire protection. **And the specific reason it matters here: for denial of wallet, ⭐ the
smoke alarm is the only detector in the building** — there is no security telemetry, because every
request was valid and authenticated.

**The one thing:** ⭐ **route budget alerts to security, not only to finance.** Crypto-mining, denial
of wallet and bulk exfiltration are attacks whose clearest — sometimes only — signal is a cost curve,
and in most organisations that signal arrives in an inbox belonging to people who will treat it as an
overspend. **It is one `contactGroups` value in a budget definition**, it costs nothing, and it
connects an entire telemetry stream to the team that can act on it.

**Runner-up:** ⭐ **`Prior = 0` is the highest-signal pattern in cost data** — a resource that cost
nothing last week and a fortune this week is an incident until proven otherwise.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 8. Self-test

1. Name four attacks whose clearest signal is cost.
2. ⭐ Why is the finance alert the security alert for denial of wallet?
3. State the budget/quota distinction in one line each.
4. Which earlier topics in this domain made the same detection-versus-control error?
5. ⭐ Why prefer forecast alerts to actual-threshold alerts?
6. What single field turns a budget into a security control?
7. ⭐ Which cost pattern is highest-signal, and what does it usually mean?
8. List the controls that actually stop spend, strongest first.
9. What does `--not-scopes` achieve, and what is its RBAC analogue?
10. How is a cost anomaly usually mis-triaged?

<details>
<summary>Answers</summary>

1. **Crypto-mining, denial of wallet, bulk data exfiltration (egress), and sprawl from a compromised
   CI identity.**
2. ⭐ Because the traffic is **valid and authenticated** — nothing in the security stack has anything
   to flag. **The bill is the detection.**
3. ⭐ **A budget alerts and spending continues; a quota refuses allocation and spending stops.**
4. ⭐ **Locks** (accidents, not adversaries) and ⭐ **tags** (metadata, not enforcement) — the same
   *"does it stop it, or just tell me?"* question.
5. ⭐ **Forecast fires on trajectory; actual fires after the money is gone.** Rate is the signal, total
   is the aftermath.
6. ⭐ The **`contactGroups`** action group — pointing it at security operations.
7. ⭐ **`Prior = 0`** — a resource that cost nothing and now costs a lot. Usually **mining** or a
   compromised identity deploying resources.
8. ⭐ **Policy denying expensive SKUs → quota → AI TPM ceilings → auto-shutdown/TTL → budget plus
   automation.**
9. It ⭐ **scopes an exception narrowly** instead of weakening the policy everywhere — the analogue of
   scoping a role assignment tightly rather than granting broadly.
10. ⭐ As a **billing error** — "someone left a VM on" — closing a mining or exfiltration incident.

</details>

---

## 9. Evidence this topic needs

- **`lab/`** ⭐ — the §3 budget with a **forecast** notification pointed at a security action group,
  plus the anomaly query. ✗ Requires an Azure subscription.
- **`break-fix/`** ⭐ — set a TPM ceiling on an AI deployment, drive it past the limit, and show the
  **bounded** failure; then remove the ceiling and show the spend curve is unbounded. **That contrast
  is the denial-of-wallet argument in one screen.**
- **`security/`** — budget alert recipients (⭐ does security receive them?); quota posture per region;
  TPM ceilings per AI deployment; SKU-denial policy and where exceptions are scoped.
- **`operations/`** — cost anomaly triage runbook that ⭐ **starts with "is this an incident?"**;
  sandbox TTL and hard budget; auto-shutdown in dev.
- **`architecture-decisions/`** — ADR: quotas requested deliberately as containment; budget alerts
  routed to security operations; every AI deployment carries a TPM ceiling.
- **`customer-use-cases/`** — §6 answered; the §3 anomaly table run against a real subscription as the
  deliverable.
