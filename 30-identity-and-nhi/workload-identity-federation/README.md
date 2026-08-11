# Workload Identity Federation

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (updated 2026-07-23).
> **Not on SC-300. Asked in every senior platform/security interview.**
> Completes the credential-free story begun in [`../managed-identities/`](../managed-identities/) §3.
> Full depth in [Layer 4 §4](../service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md).

---

## 1. What it is

Configuring a **user-assigned managed identity** or an **app registration** to **trust tokens from
an external identity provider** — GitHub, a Kubernetes cluster, AWS, Google Cloud — so a workload
outside Azure obtains an Entra access token **with no secret at all**.

⚠ **User-assigned managed identity, not system-assigned.** Federated credentials attach to
user-assigned identities and app registrations only.

---

## 2. The problem it eliminates

A CI/CD pipeline deploying to Azure traditionally holds a client secret in repository variables.
That secret leaks in logs, gets copied between repositories, is shared once in chat, expires at the
worst possible moment, and is **the most common real breach path in modern estates**.

> **Federation removes the credential rather than protecting it better.** Nothing to rotate, nothing
> to expire, nothing to leak. That framing — *eliminate the class of problem, don't manage it* — is
> what makes this an interview answer rather than a feature.

---

## 3. How it works — the six steps ✅

```
1. Workload asks its own IdP for a token          (GitHub, Kubernetes, AWS, GCP…)
2. IdP issues a short-lived JWT                    sub = repo:org/repo:ref:refs/heads/main
3. Workload sends that JWT to Microsoft identity platform
4. Entra checks the FEDERATED CREDENTIAL and validates the token against the
   external IdP's published OIDC issuer URL
5. Entra issues an access token
6. Workload uses it. NO SECRET EXISTED AT ANY POINT.
```

Step 3 is the **client credentials flow**, passing the IdP's JWT **instead of an assertion you
signed yourself with a stored certificate**. That is the whole mechanical difference.

### The three values that must match — and the failure mode

> ✅ **The `issuer`, `subject` and `audience` must *case-sensitively* match** the corresponding
> values in the token sent by the external IdP.

**That sentence is the entire troubleshooting guide.** Nearly every failure is a `subject` mismatch,
because **GitHub's subject format changes with the trigger type**:

| Trigger | Subject |
|---|---|
| Branch push | `repo:<org>/<repo>:ref:refs/heads/<branch>` |
| Tag | `repo:<org>/<repo>:ref:refs/tags/<tag>` |
| **Pull request** | ⭐ `repo:<org>/<repo>:pull_request` |
| Environment | `repo:<org>/<repo>:environment:<name>` |

⭐ **A credential configured for `main` will not work from a pull request.** You need one federated
credential per subject pattern you intend to allow — **and that is a feature, not a limitation.** It
is precisely how you stop a PR from a fork deploying to production.

---

## 4. Worked example — federating GitHub Actions with zero secrets

**Step 1 — create the federated credential:**

```bash
az ad app federated-credential create --id <appObjectId> --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:contoso/deploy-infra:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"],
  "description": "Deploy from main branch"
}'
```

⚠ **Read the audience from your own configuration, not from a blog — including this file.**

**Step 2 — the workflow. Note what is absent: any secret.**

```yaml
permissions:
  id-token: write        # ⭐ REQUIRED — without it GitHub issues no OIDC token
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: azure/login@v2
        with:
          client-id:       ${{ vars.AZURE_CLIENT_ID }}   # vars, not secrets
          tenant-id:       ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

⭐ **`permissions: id-token: write` is the single most common omission.** Without it GitHub never
mints an OIDC token, and the failure reads like an Azure trust problem when it is a workflow
permission problem.

**Step 3 — verify, and read the failure properly.** From a pull request the same workflow fails:

```
AADSTS70021: No matching federated identity record found for presented assertion.
Assertion Issuer: 'https://token.actions.githubusercontent.com'.
Assertion Subject: 'repo:contoso/deploy-infra:pull_request'.
Assertion Audience: 'api://AzureADTokenExchange'.
```

⭐ **`AADSTS70021` prints the exact subject presented.** Diff it against what you configured — the
error contains its own fix, which is unusual and worth remembering.

**List what is actually trusted — a first-visit audit question:**

```bash
az ad app federated-credential list --id <appObjectId> \
  --query "[].{name:name, issuer:issuer, subject:subject}" -o table
```

```
Name           Issuer                                          Subject
-------------  ----------------------------------------------  ------------------------------------------
github-main    https://token.actions.githubusercontent.com     repo:contoso/deploy-infra:ref:refs/heads/main
github-pr      https://token.actions.githubusercontent.com     repo:contoso/deploy-infra:pull_request      <-- ⚠
```

⚠ **That second row lets *any* pull request against the repo obtain the identity's token.** For a
read-only validation identity that may be intended; for one holding Contributor on production it is
a critical finding. **Scope by environment instead.**

---

## 5. Supported scenarios ✅ — this is a multi-cloud skill

| Platform | Notes |
|---|---|
| **Any Kubernetes** | AKS, **EKS, GKE, on-premises** — see [`../workload-identity-for-aks/`](../workload-identity-for-aks/) |
| **GitHub Actions** | The canonical case |
| ⭐ **Azure compute using app identities** | Managed identity as FIC — [`../managed-identities/`](../managed-identities/) §3 |
| **AWS** | Via IAM Outbound Identity Federation |
| **Google Cloud** | |
| **SPIFFE / SPIRE** | The vendor-neutral workload identity standard |
| **Azure Pipelines** | ARM service connection using workload identity federation |

> *"We can federate your EKS workloads to Entra without secrets"* is a differentiating sentence in a
> multi-cloud shop, and very few people can say it with confidence.

---

## 6. Two limits worth knowing ✅

- ⭐ **Entra-issued tokens cannot be used in federated identity flows.** You cannot chain Entra to
  itself. This surprises people trying to federate one tenant to another.
- ⭐ **Entra stores only the first 100 signing keys** from the external IdP's OIDC endpoint. An IdP
  exposing more produces **intermittent** failures — which is the worst kind, because it looks like
  a transient network fault rather than a configuration ceiling.

⚠ Separately: **20 federated identity credentials** when using managed identities as FIC on an Entra
app.

---

## 7. When and where

```
Runs on Azure compute?          → MANAGED IDENTITY
Needs an Entra app anyway?      → managed identity as FIC
Runs OUTSIDE Azure?             → ⭐ WORKLOAD IDENTITY FEDERATION
None of the above?              → certificate. Never a secret.
```

---

## 8. What breaks

**Subject mismatch from a changed trigger type.** §3 — the dominant failure.

**Case sensitivity.** `Repo:` and `repo:` are different.

**Missing `id-token: write`** in the GitHub workflow. §4.

**One credential expected to cover all branches and PRs.** It cannot, and should not.

**Over-broad subjects** — a `pull_request` credential on an identity with production write access.

**Leaving the old client secret in place** after migrating. Delete it, or you have added complexity
without removing risk.

**Attaching a federated credential to a system-assigned identity.** Not supported — user-assigned
or app registration only.

**Trying to federate Entra to Entra.** §6.

**An IdP exposing more than 100 signing keys.** Intermittent, confusing failures.

---

## 9. Customer discovery questions

1. Do any pipelines hold **client secrets** for Azure deployment? How many, and where are they stored?
2. Is federation in use? For which repos and which **subject patterns**?
3. Are there **`pull_request` credentials** on identities with write access to production?
4. Were the **old secrets deleted** after migrating, or left in place?
5. Are federated credentials attached to **user-assigned managed identities** or app registrations?
6. Any non-Azure workloads — EKS, GKE, on-premises Kubernetes — still using stored credentials?
7. Is SPIFFE/SPIRE in use anywhere in the estate?
8. Who can add a federated credential? *(It is equivalent to issuing a credential.)*

---

## 10. Remember it

**Hook — "Issuer, subject, audience — case-sensitive."** That is the entire troubleshooting guide.

**Analogy — a visa waiver, not a key.** A client secret is a **key you post to the pipeline** —
copyable, interceptable, expiring. Federation is a **visa waiver agreement**: Entra says *"I trust
passports issued by GitHub, for this exact traveller, on this exact route."* The traveller shows
their own passport, freshly issued, valid for minutes. **And the "exact route" is the subject** —
which is why arriving from a pull request instead of `main` is a different journey and gets refused.

**The one thing:** ⭐ **the `subject` changes with the GitHub trigger type**, so a credential built
for `main` fails from a pull request. **That is the security feature** — it is how you stop a fork's
PR from deploying to production — and `AADSTS70021` prints the exact subject presented, so the error
contains its own fix.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 11. Self-test

1. Which three values must match, and how exactly?
2. Why does a workflow that works on `main` fail from a pull request?
3. Which GitHub workflow permission is required, and what happens without it?
4. What does `AADSTS70021` tell you, and why is that unusually helpful?
5. Can a federated credential attach to a system-assigned managed identity?
6. Can you use an Entra-issued token in a federated identity flow?
7. What happens if the external IdP exposes 150 signing keys?
8. Why is a `pull_request` subject on a production identity a critical finding?
9. Name four non-GitHub platforms this supports.
10. What is the final step of a migration to federation that people skip?

<details>
<summary>Answers</summary>

1. **`issuer`, `subject`, `audience`** — **case-sensitively**, against the token presented by the
   external IdP.
2. The **`subject` changes with trigger type**: `…:ref:refs/heads/main` versus `…:pull_request`.
3. **`id-token: write`.** Without it GitHub never mints an OIDC token, and the failure looks like an
   Azure trust problem.
4. It prints the **exact issuer, subject and audience presented**, so you can diff against what you
   configured. **The error contains its own fix.**
5. **No** — user-assigned managed identities or app registrations only.
6. **No.** Entra-issued tokens are not supported in federated identity flows.
7. Only the **first 100** are stored, producing **intermittent** failures that look transient.
8. **Any pull request against the repo** can obtain that identity's token — including from a fork.
9. Any **Kubernetes** (EKS/GKE/on-prem), **AWS**, **Google Cloud**, **SPIFFE/SPIRE**, **Azure
   Pipelines**.
10. **Deleting the old client secret.** Otherwise you have added complexity without removing risk.

</details>

---

## 12. Evidence this topic needs

- **`lab/`** ⭐ — **federate a GitHub Actions workflow to Azure with zero secrets.** This is the
  portfolio artifact of the topic, and it is **publicly demonstrable** — a repo anyone can read.
- **`break-fix/`** — run the same workflow **from a pull request**, capture `AADSTS70021` verbatim,
  then add the second credential and prove it passes. Also omit `id-token: write` and compare the
  failure.
- **`security/`** — federated credential inventory with subject patterns reviewed; proof the old
  secrets were **deleted**; identities holding production write scoped to environment, not repo.
- **`operations/`** — who may add a federated credential, and the review path.
- **`architecture-decisions/`** — ADR: federation over stored secrets, with the subject-scoping model
  and what it costs in setup.
- **`customer-use-cases/`** — §9 answered; a multi-cloud example federating EKS or GKE to Entra.
