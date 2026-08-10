# Workload Identity Federation

> **Concept facet.** Full depth in
> [Layer 4 §4](../service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md).
> **Not on SC-300. Asked in every senior platform/security interview.**

## What it is

Trusting tokens from an **external** identity provider — GitHub, a Kubernetes cluster, AWS, Google
Cloud — so a workload outside Azure can obtain an Entra access token **without holding any secret
at all**.

## The problem it eliminates

A CI/CD pipeline deploying to Azure traditionally holds a client secret in repository variables.
That secret leaks in logs, gets copied between repositories, is shared once in chat, expires at the
worst possible moment, and is **the most common real breach path in modern estates**.

Federation removes the credential rather than protecting it better. There is nothing to rotate,
nothing to expire, nothing to leak.

## How it works

Configure a **federated identity credential** on a **user-assigned managed identity** or an **app
registration**, declaring which external tokens to trust.

```
1. Pipeline asks GitHub for an OIDC token
2. GitHub issues a short-lived JWT  (sub = repo:org/repo:ref:refs/heads/main)
3. Pipeline sends that JWT to Entra's token endpoint
4. Entra checks the federated credential and validates the token against the
   external IdP's published OIDC issuer URL
5. Entra issues an access token
6. Pipeline uses it. No secret existed at any point.
```

## The three values that must match — and the failure mode

> **`issuer`, `subject`, and `audience` must match the incoming token
> *case-sensitively*.**

That sentence is the entire troubleshooting guide. Nearly every failure is a `subject` mismatch,
because **GitHub's subject format changes with the trigger type**:

| Trigger | Subject |
|---|---|
| Branch push | `repo:<org>/<repo>:ref:refs/heads/<branch>` |
| Tag | `repo:<org>/<repo>:ref:refs/tags/<tag>` |
| **Pull request** | `repo:<org>/<repo>:pull_request` |
| Environment | `repo:<org>/<repo>:environment:<name>` |

**A credential configured for `main` will not work from a pull request.** You need one federated
credential per subject pattern you intend to allow — and that is a **feature**, not a limitation:
it is precisely how you stop a PR from any fork deploying to production.

Read the audience value from **your own configuration**, not from a blog — including this file.

## Supported platforms — this is multi-cloud

- **Any Kubernetes** — AKS, EKS, GKE, on-premises
- **GitHub Actions**
- **Azure Pipelines** service connections
- **AWS** — via IAM Outbound Identity Federation
- **Google Cloud**
- **SPIFFE / SPIRE** — the vendor-neutral workload identity standard

> *"We can federate your EKS workloads to Entra without secrets"* is a differentiating sentence in
> a multi-cloud shop, and very few people can say it with confidence.

## Two limits worth knowing

- **Entra-issued tokens cannot be used in federated identity flows.** You cannot chain Entra to
  itself.
- Entra stores only the **first 100 signing keys** from the external IdP's OIDC endpoint; an IdP
  exposing more produces intermittent failures.

## When and where

**Whenever a workload runs outside Azure and needs Entra-protected resources.** If it runs *on*
Azure compute, use a [managed identity](../managed-identities/) instead — same benefit, less
configuration.

Decision order: managed identity → federation → certificate → secret.

## The traps

1. **Subject mismatch from a changed trigger type** — the dominant failure.
2. **Case sensitivity.** `Repo:` and `repo:` are different.
3. **Configuring one credential and expecting it to cover all branches and PRs.**
4. **Leaving the old client secret in place** after migrating. Delete it, or you have added
   complexity without removing risk.
5. **Over-broad subjects** — a wildcard-ish pattern that allows any branch to deploy to production.

## Evidence this topic needs

- `lab/` ⭐ — **federate a GitHub Actions workflow to Azure with zero secrets.** This is the
  portfolio artifact of this topic.
- `break-fix/` — run the same workflow from a **pull request** and watch the `sub` mismatch fail it;
  read the exact error; add the second credential.
- `security/` — before/after: the secret that existed, and its deletion. Subject scoping rationale.
- `architecture-decisions/` — ADR: federation over stored secrets, and what it costs in setup.
