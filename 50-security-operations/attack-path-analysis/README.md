# Attack Path Analysis

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified 2026-08-10 — **requires the paid Defender CSPM plan**. See
> [`../defender-for-cloud/`](../defender-for-cloud/) §3.
> ⭐ **The feature that converts a list of findings into a decision.**

---

## 1. What it is

A **graph** of your cloud environment — resources, identities, permissions, network exposure and
vulnerabilities as nodes and edges — queried to find the **routes** an attacker could take from an
internet-facing entry point to something that matters.

Two features sit on the same engine ✅:

| Feature | Direction |
|---|---|
| **Attack path analysis** | ⭐ Microsoft finds the paths *for* you |
| **Cloud security explorer** | You query the graph *yourself* |

---

## 2. Why it exists — the problem with lists

A posture tool produces 3,000 findings. Every one is real. Nobody can fix 3,000 things, so the team
fixes the easy ones, the count stays roughly constant, and after six months everyone quietly stops
looking.

**The list has no notion of consequence.** These two findings score identically:

```
VM missing patch KB5034441       ← on an isolated dev box, no data, no identity
VM missing patch KB5034441       ← internet-facing, managed identity with
                                    Owner on the production subscription
```

The second is a **path to total compromise**. The first is homework.

> ⭐ **A vulnerability is not a risk until it is reachable and it leads somewhere.** Attack path
> analysis supplies the two missing halves — **reachability** and **consequence** — and that is why
> it changes the conversation with a customer from "you have 3,000 problems" to "you have four."

**The reframe that gets budget:** *"Of your 3,000 findings, 11 lie on a path from the internet to
production data. Fix these 6 and all 11 paths break."* That is a plan an executive can approve.

---

## 3. How it works underneath — the cloud security graph

Defender CSPM continuously builds a graph:

```
   NODES                          EDGES
   ─────                          ─────
   VM, storage, database          "is exposed to internet"
   managed identity, SP           "can authenticate as"
   role assignment                "has permission on"
   NSG, public IP                 "can reach over the network"
   vulnerability (CVE)            "is vulnerable to"
   secret, key                    "contains credential for"
   data classification            "contains sensitive data"
```

**The insight is that the edges matter more than the nodes.** Every scanner enumerates nodes;
almost none reason about the edges between them. A path is a chain of edges — and it is the chain,
not any individual link, that is the finding.

**A worked path, and how to read it:**

```
[Internet]
     │  exposed via public IP + NSG allows 3389
     ▼
[VM: web-prod-01]  ── vulnerable to ── [CVE-2024-XXXXX  RCE, no auth]
     │  has assigned
     ▼
[Managed identity: mi-web-prod]
     │  has role assignment
     ▼
[Owner on subscription: sub-production]
     │  can read
     ▼
[Storage: customer-data]  ── contains ── [SENSITIVE: PII]
```

**Five nodes, and only the middle one is a "vulnerability."** The others are configuration choices
nobody reviewed together: a management port open, an over-privileged managed identity, and sensitive
data. Individually, three medium findings. Together, **an unauthenticated internet-to-PII path.**

⭐ **The cheapest break in that chain is usually not the patch.** Removing `Owner` from the managed
identity is a five-minute change that also breaks every *future* path through that identity. Patching
fixes one CVE; the next one arrives next month.

---

## 4. Worked example — querying the graph yourself

**Attack paths are what Microsoft found. The cloud security explorer is where you ask your own
question** — and asking your own question is the senior skill, because it encodes what *this*
customer cares about.

**Questions the explorer answers that no recommendation list can:**

| Question | Why it matters |
|---|---|
| Internet-exposed VMs with a **managed identity holding Owner or Contributor** | The §3 path |
| Storage accounts with **sensitive data** reachable from the internet | Regulatory exposure |
| VMs with **high-severity CVEs** that are also internet-exposed | The genuinely urgent patches |
| Identities that can reach production **from a non-production subscription** | Environment boundary failure |
| Key vaults **without purge protection** holding keys used by production | Unrecoverable deletion |
| Containers running as **privileged** with cluster-admin bindings | Kubernetes escape route |

**Pull the paths programmatically** so they become a tracked backlog rather than a portal view:

```bash
# Attack paths surface as assessments; export them with owners attached
az security assessment list \
  --query "[?contains(displayName,'attack path') && status.code=='Unhealthy'].{Path:displayName, Resource:resourceDetails.id}" \
  -o tsv > attack-paths.tsv
```

⚠ Attack path and explorer data are also queryable via **Azure Resource Graph** and are surfaced in
the Defender portal; the exact API surface has moved as Defender for Cloud migrates portals.
**Verify the current query interface before automating against it.**

**Then apply the ranking that makes it a plan:**

```
1. Group paths by their SHARED nodes          ← the choke points
2. Rank by (paths broken) ÷ (effort to fix)   ⭐ not by CVSS
3. Present the top 5 as "fix these, break N paths"
```

> **Ranking by choke point rather than severity is the whole technique.** One over-privileged
> managed identity may sit on nine paths. Removing it outperforms nine patches, and it is a
> permission change rather than a maintenance window.

---

## 5. Where this connects to identity — and why you specifically should care

Read the §3 path again. **Three of the five edges are identity edges**: the managed identity, its
role assignment, and what that role can reach.

This is the same lesson as **lateral movement paths** in
[`../defender-for-identity/`](../defender-for-identity/) §6 — on-premises, an attacker chains from a
workstation to Domain Admin through cached credentials; in cloud, they chain from a VM to Owner
through a managed identity. **The graph is the same shape; only the nouns change.**

That equivalence is worth being able to state out loud:

| On-premises (MDI) | Cloud (Defender CSPM) |
|---|---|
| Lateral movement path | Attack path |
| Cached privileged credential | **Over-privileged managed identity** |
| Domain Admin | **Owner / Contributor** |
| Tiering model | Least privilege + environment separation |

**The remediation is the same principle in both: reduce standing privilege.** See
[`../../30-identity-and-nhi/managed-identities/`](../../30-identity-and-nhi/managed-identities/)
and PIM in
[`../../30-identity-and-nhi/pim-and-access-reviews/`](../../30-identity-and-nhi/pim-and-access-reviews/).

---

## 6. What breaks

**Assuming it is available.** ⭐ **Defender CSPM is a paid plan.** On Foundational CSPM there is no
attack path analysis and no security explorer. Check first — see
[`../defender-for-cloud/`](../defender-for-cloud/) §4.

**Treating paths as a list.** The value is in the **shared nodes**. Fixing paths one at a time
misses that six of them run through the same identity.

**Ranking by CVSS.** A critical CVE on an unreachable host outranks nothing.

**Fixing the vulnerability, not the privilege.** The patch closes one link; the over-privileged
identity is on every future path through that resource.

**No data classification.** Without DSPM the graph does not know which storage account matters, so
paths cannot be ranked by consequence.

**Stale graph after remediation.** Re-run and confirm the path is actually broken — remediation that
was never verified is the norm, not the exception.

**Ignoring non-production.** A path from a dev subscription into production is a boundary failure,
and it is exactly the path nobody models.

---

## 7. Customer discovery questions

1. Is **Defender CSPM** enabled — or only Foundational? *(Determines whether this conversation is
   possible at all.)*
2. How many attack paths currently exist, and how many reach **sensitive data**?
3. Which **shared nodes** appear on the most paths?
4. Are there internet-exposed resources with **managed identities holding Owner or Contributor**?
5. Is **data classification** on, so consequence can be ranked?
6. Are there paths from **non-production into production**?
7. Who owns remediation of a path that crosses three teams? *(Usually nobody — that is the finding.)*
8. Is remediation **verified** by re-running the analysis?

---

## 8. Remember it

**Hook — "A vulnerability is not a risk until it is reachable and it leads somewhere."**
And: **rank by choke point, not by CVSS.**

**Analogy — a burglary route, not a list of unlocked windows.** A surveyor hands you 3,000 unlocked
windows. A burglar cares about **one route**: over the bin, through the bathroom window, into the
hallway where the car keys hang. **Attack path analysis is the route; the recommendation list is the
window inventory.** And the cheapest fix is rarely the window — it is moving the car keys, because
that breaks every route that ends there.

**The one thing:** find the **shared nodes**. One over-privileged managed identity sitting on nine
paths beats nine patches — it is a permission change, not a maintenance window, and it breaks every
*future* path through that identity too.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Which Defender for Cloud plan is required, and what happens without it?
2. Why do two identical CVE findings differ enormously in risk?
3. In the §3 path, what is the cheapest effective break — and why not the patch?
4. What is the difference between attack path analysis and cloud security explorer?
5. Why rank by choke point rather than CVSS?
6. What does DSPM contribute to path ranking?
7. What is the on-premises equivalent of an attack path?
8. Why is a path from dev into production especially significant?
9. What must you do after remediating a path?
10. Why do edges matter more than nodes?

<details>
<summary>Answers</summary>

1. **Defender CSPM** (paid). On Foundational CSPM neither attack path analysis nor the cloud
   security explorer exists.
2. **Reachability and consequence.** One is on an isolated dev box; the other is internet-facing with
   a managed identity holding Owner over production.
3. **Remove `Owner` from the managed identity.** It is a five-minute permission change that also
   breaks every future path through that identity; patching fixes one CVE until the next one.
4. Attack path analysis = **Microsoft finds paths for you**. Cloud security explorer = **you query
   the graph yourself**.
5. One shared node may sit on many paths. Breaking it removes all of them at once.
6. **Data classification** — without it the graph cannot tell which storage account is worth
   protecting, so consequence cannot be ranked.
7. **A lateral movement path** in Defender for Identity. Same graph shape, different nouns.
8. It is an **environment boundary failure** — and it is the path nobody models.
9. **Re-run the analysis** and confirm the path is gone. Unverified remediation is the norm.
10. Every scanner enumerates nodes. **The chain of edges is the finding** — no single link is the
    problem.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — build the §3 path deliberately: internet-facing VM, managed identity with Owner,
  storage with sensitive data. Watch the path appear. ✗ Requires an Azure subscription **and**
  Defender CSPM.
- **`break-fix/`** ⭐ — break the same path **two ways** — patch the CVE, versus remove the role
  assignment — and compare which other paths each removes. **That comparison is the entire lesson.**
- **`security/`** — attack path inventory ranked by shared node; internet-exposed resources with
  privileged managed identities.
- **`operations/`** — remediation tracked to a named owner per path, with re-run verification.
- **`architecture-decisions/`** — ADR: managed identity privilege standard, and environment
  separation between non-production and production.
- **`customer-use-cases/`** — the §2 reframe delivered to a real customer: "3,000 findings, 11 on a
  path, fix 6."
