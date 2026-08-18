# Government and Public Sector

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **Boundary:** [`../LAYER-7-INDUSTRY-VERTICALS.md`](../LAYER-7-INDUSTRY-VERTICALS.md) §4 is the
> brief. ⭐ **This is engagement depth — and the first question here constrains every other decision
> in the project.** Pairs with [`../fintech-and-banking/`](../fintech-and-banking/).

---

## 1. What it is

Identity engineering for government departments, agencies, defence suppliers and public bodies —
where the tenant may not be in the commercial cloud at all, ⭐ **feature parity is not guaranteed**,
and the people permitted to administer the system may be legally restricted.

⭐ **Everywhere else you design and then check licensing. Here you establish the cloud instance
first, because it determines which features exist.**

---

## 2. Why it is different

```
⭐ MICROSOFT DOES NOT RUN ONE CLOUD. IT RUNS SEVERAL, AND THEY ARE NOT EQUAL.

  Commercial          the one everything is documented against
  ⭐ GCC               US government community, ⭐ commercial infrastructure
  ⭐ GCC High          ⭐ separate; ⭐ for ITAR/CUI/DFARS
  ⭐ DoD               separate again; highest impact levels
  ⭐ Sovereign/partner  e.g. ⭐ 21Vianet (China) — ⭐ operated by a partner,
                       ⭐ not by Microsoft
```

⭐ **Feature parity between these is not guaranteed and lags unpredictably.** A capability that is
generally available in commercial may be in preview, unavailable, or permanently absent in a
government cloud — ⭐ **and the public documentation is written for commercial by default.**

| Consequence | What it means in practice |
|---|---|
| ⭐ **Design to the wrong cloud** | ⭐ a rewrite, discovered late |
| ⭐ Cross-cloud B2B | ⭐ constrained — ⭐ collaboration with commercial partners is a **design problem** |
| ⭐ Personnel restrictions | ⭐ **only US persons may access certain data** — this includes *you* |
| Public documentation | ⭐ read the government-cloud variant of every page |

⭐ **The personnel restriction is the one that catches consultants personally.** ⭐ **An engagement in
GCC High may legally exclude you from touching the tenant**, regardless of skill or clearance
paperwork. ⭐ **Establish this before proposing, not after winning** — for an India-based consultant
this eliminates an entire segment of US federal work, and knowing that saves wasted pipeline.

---

## 3. How it works underneath — the frameworks, and who owns what

```
⭐ THE AUTHORISATION IS OF THE PLATFORM, NOT OF YOUR CONFIGURATION.

  ⭐ Microsoft provides   platform authorisation
                          (FedRAMP for the service, ⭐ at a given level)
        │
        ▼
  ⭐ YOU inherit          only the controls Microsoft actually operates
        │                 ⭐ listed in the Customer Responsibility Matrix
        ▼
  ⭐ CUSTOMER owns        everything above that line —
                          ⭐ which is most of the identity controls
```

⭐ **"We're on FedRAMP-authorised Azure so we're compliant" is the standard misconception**, and
correcting it politely is a credibility moment. ⭐ **The platform's authorisation covers the
platform.** Your Conditional Access design, your privileged access model and your logging are
inherited by nobody.

**Frameworks you should recognise by name** (⚠ verify current versions and dates — these move):

| Framework | Substance |
|---|---|
| **FedRAMP** | US federal cloud service authorisation — Low / Moderate / High |
| ⭐ **DoD Impact Levels** | IL2 → IL6; ⭐ higher levels need specific clouds |
| ⭐ **CMMC** | ⭐ US **defence supply chain** — ⭐ affects contractors, not just agencies |
| **CJIS** | US criminal justice information |
| ⭐ **ITAR / EAR** | ⭐ export control — ⭐ **the reason GCC High exists** |
| **NIST SP 800-53 / 800-171** | the control catalogues underneath most of the above |
| ⭐ Non-US | ⭐ UK NCSC principles · EU sovereignty requirements · ⭐ **India MeitY empanelment** |

⭐ **CMMC is the one most likely to appear unexpectedly**, because it reaches down the supply chain:
⭐ **a small manufacturer with a defence contract is in scope**, and they usually do not know it.
See [`../manufacturing-and-ot/`](../manufacturing-and-ot/).

---

## 4. Worked example — the question that reorders the project

⭐ **Ask this in the first ten minutes, and record the answer in writing:**

```
⭐ Q: "Which Microsoft cloud instance is your tenant in?"

A: "Azure Government, GCC High."

⭐ EVERYTHING THAT NOW CHANGES
─────────────────────────────────────────────────────────────────────
⭐ Endpoints        login.microsoftonline.us  ⭐ NOT .com
                    graph.microsoft.us        ⭐ NOT graph.microsoft.com
⭐ PowerShell       Connect-MgGraph -Environment USGov
                    Connect-AzAccount -Environment AzureUSGovernment
⭐ Feature set      ⭐ VERIFY EVERY feature in the design individually
⭐ Partners         ⭐ B2B with commercial-tenant partners is constrained
⭐ Personnel        ⭐ may exclude non-US-person consultants — INCLUDING ME
⭐ Documentation    read the ".us" / government variant of every page
─────────────────────────────────────────────────────────────────────
```

**The connection itself is different, and getting it wrong produces a confusing error:**

```powershell
Connect-MgGraph -Environment USGov `
  -Scopes 'Directory.Read.All','Policy.Read.All'
(Get-MgContext) | Select-Object Environment, TenantId, Scopes
```

```
Environment  TenantId                              Scopes
USGov        7c21e480-...                          {Directory.Read.All, Policy.Read.All}
```

⭐ **Connecting without `-Environment` targets the commercial cloud and fails in a way that looks
like a credential problem:**

```
Connect-MgGraph : ⭐ AADSTS50020: User account from identity provider
'https://sts.windows.net/...' does not exist in tenant 'Microsoft Services'
```

⭐ **`AADSTS50020` in a government engagement is almost always the wrong cloud, not a wrong
password** — and recognising that instantly saves an hour of the wrong diagnosis.

**Verify a feature exists before designing on it — ⭐ never assume from commercial documentation:**

```powershell
# ⭐ Does this tenant actually have the authentication strengths you planned to use?
Get-MgPolicyAuthenticationStrengthPolicy |
  Select-Object DisplayName, PolicyType | Sort-Object PolicyType
```

```
DisplayName                    PolicyType
Multifactor authentication     builtIn
Passwordless MFA               builtIn
Phishing-resistant MFA         builtIn
```

⭐ **Run the equivalent check for every feature the HLD depends on**, and put the output in the
design document as evidence. ⭐ **"Verified present in this tenant on this date" is worth more than
any documentation link**, because the documentation describes commercial.

---

## 5. Design reference

| Control | Setting | ⭐ Why |
|---|---|---|
| Authentication | ⭐ **PIV / CAC smart cards** where mandated | ⭐ certificate-based auth, not phone MFA |
| ⭐ Federation | ⭐ often existing AD FS or a smart-card PKI | ⭐ do not assume greenfield cloud auth |
| Privileged access | PIM, approval, short windows | standard, ⭐ but verify PIM availability |
| ⭐ External collaboration | ⭐ **cross-cloud B2B design, explicitly** | ⭐ partners are in a different cloud |
| Logging | ⭐ long retention, ⭐ often to a government-region workspace | residency |
| ⭐ Data residency | ⭐ tenant, workspace, and **every** service region | ⭐ a single misplaced resource is a finding |
| Documentation | ⭐ System Security Plan alignment | ⭐ the customer's assessor reads it |

⭐ **Certificate-based authentication is the norm rather than the exception here**, and it changes
the design: smart cards work with a physical reader, survive being phone-free, and are already
issued for building access. ⭐ **Entra supports certificate-based authentication natively** — ⚠
verify current capability and any cloud-specific limits.

⭐ **The System Security Plan is the artifact the customer's assessor actually reads.** ⭐ **Writing
your design so it maps cleanly onto their SSP control IDs — rather than making them translate — is a
genuine differentiator**, and it is the same evidence-artifact principle as
[`../fintech-and-banking/`](../fintech-and-banking/) §3.

---

## 6. What breaks

| Symptom / error | Cause | Fix |
|---|---|---|
| ⭐ `AADSTS50020` on connect | ⭐ **wrong cloud** | ⭐ `-Environment USGov` |
| Feature missing that docs describe | ⭐ commercial documentation | read the government variant; verify in tenant |
| Design needs rework late | cloud instance not established first | ⭐ ask in the first ten minutes |
| ⭐ Guest collaboration fails | cross-cloud B2B constraints | ⭐ design it deliberately, do not assume |
| ⭐ Consultant removed from the project | ⭐ personnel restrictions | ⭐ establish eligibility **before** proposing |
| "We're FedRAMP so we're compliant" | ⭐ inheritance misunderstood | ⭐ the responsibility matrix |
| Procurement stalls for months | public-sector timelines | ⭐ plan the calendar around it |

⭐ **Procurement timelines are a technical constraint here, not an inconvenience.** ⭐ **A licence
increase that takes an afternoon commercially can take a quarter in government**, which makes
capacity planning ([`../../70-operations-and-reliability/capacity-planning/`](../../70-operations-and-reliability/capacity-planning/))
genuinely load-bearing: ⭐ **the lead time, not the limit, is what blocks you.**

---

## 7. Customer discovery questions

⭐ **In this order. The first one gates the rest.**

1. ⭐ **"Which Microsoft cloud instance is your tenant in?"**
2. ⭐ **"Are there personnel restrictions on who may access this environment?"** (⭐ ask about
   yourself explicitly — before the proposal)
3. "Which framework are you assessed against, and at what level?"
4. ⭐ **"Do you have a System Security Plan, and may I see the identity control section?"**
5. "Do you need to collaborate with organisations in the commercial cloud?"
6. ⭐ **"Is smart-card authentication mandated?"**
7. "What is your procurement lead time for additional licences?"

---

## 8. Remember it

**Hook — ⭐ `CLOUD FIRST`.** ⭐ Instance → personnel eligibility → framework → features → design.
⭐ **Never design before the first two.**

**Analogy — driving licences between countries.** ⭐ **The vehicle looks identical, the controls are
in the same places, and the licence you hold may simply not be valid here.** The analogy predicts
every failure: ⭐ **the manual you downloaded describes the other country's model** (commercial
documentation), ⭐ **some options are not fitted to the local version** (feature parity), and
⭐ **the restriction on who may drive is about the driver, not the car** (personnel eligibility).

**The one line:** ⭐ **Establish the cloud instance and who is legally permitted to touch it before
anything else — both can invalidate the entire design.**

---

## 9. Self-test

1. What is the first question in a government engagement, and why?
   → ⭐ Which cloud instance — it determines which features exist at all.
2. Name the US government cloud instances.
   → ⭐ Commercial, GCC, GCC High, DoD (plus partner-operated sovereign clouds such as 21Vianet).
3. What does a FedRAMP authorisation cover?
   → ⭐ The platform. Your identity configuration is inherited by nobody; see the responsibility matrix.
4. Why does GCC High exist?
   → ⭐ Export control (ITAR/EAR) and CUI handling, including personnel restrictions.
5. `AADSTS50020` during a government engagement — first hypothesis?
   → ⭐ Connected to the wrong cloud; use `-Environment USGov`.
6. Which framework reaches non-government companies?
   → ⭐ CMMC, through the defence supply chain.
7. Why is procurement lead time a technical constraint here?
   → ⭐ Capacity actions that take hours commercially can take a quarter, so the order date dominates.

---

## 10. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | ⭐ a connection to a non-commercial cloud, with `Get-MgContext` showing the environment |
| `security` | the feature-availability verification for every feature the design depends on |
| `operations` | the data-residency check across tenant, workspace and services |
| `customer-use-cases` | ⭐ the written record of the cloud instance and personnel eligibility |
| `architecture-decisions` | ⭐ the design mapped onto the customer's SSP control IDs |
