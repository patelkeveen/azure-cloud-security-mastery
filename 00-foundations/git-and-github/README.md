# Git and GitHub

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **This repository is the worked example** — including a two-day CI failure caused by §5.
> Feeds [`../../30-identity-and-nhi/workload-identity-federation/`](../../30-identity-and-nhi/workload-identity-federation/).

---

## 1. What git actually is

**A content-addressed object store with a directed acyclic graph on top.** Not a diff tool — ⭐ **git
stores whole snapshots, addressed by the hash of their content.**

```
commit  ── points to ──▶ tree ── points to ──▶ blob (file content)
   │                       └────────────────▶ tree (subdirectory)
   └── parent ──▶ commit ──▶ commit ──▶ …          ⭐ the DAG

branch  = ⭐ a movable pointer to a commit — nothing more
tag     = a pointer that does not move
HEAD    = a pointer to the branch you are on
```

⭐ **"A branch is just a pointer" is the sentence that makes git stop being frightening.** Creating
one is free. Deleting one deletes no content. Everything scary in git is a pointer moving, and
`git reflog` remembers where the pointers used to be.

---

## 2. ⭐ The security fact: git never forgets

> **A secret committed and then removed in a later commit is still in the repository.** The blob is
> still there, reachable by hash, and it is in every clone anyone took.

```
commit A   config.yml contains a key      ⭐ blob exists forever
commit B   "removed the key"              the blob is still reachable
                                          the key is still in every clone
```

⭐ **This is the single most consequential thing to know about git.** The correct response to a
committed secret is:

```
1. ⭐ ROTATE THE SECRET.   Not "remove it" — rotate. It is compromised.
2. Then, optionally, rewrite history (filter-repo / BFG).
3. Then force-push, and tell everyone with a clone.
```

⭐ **Step 1 is the whole answer, and steps 2–3 are cosmetic by comparison.** History rewriting does
not reach clones, forks, CI caches, or anyone's laptop. **Treat exposure as permanent and rotate.**

```bash
# Has anything secret-shaped ever been committed? (searches ALL history, not the working tree)
git log -p --all -S 'BEGIN PRIVATE KEY' --oneline
git log -p --all -S 'client_secret'     --oneline
git rev-list --objects --all | wc -l          # every object ever, still reachable
```

⚠ Add secret scanning (`gitleaks`, GitHub secret scanning with **push protection**) so this is
prevented rather than discovered. ⭐ **Push protection is the control that matters** — detection after
the fact only tells you to rotate.

---

## 3. Worked example — commit history as an audit trail

⭐ **A repository is an audit log that most people never query.** These are the questions it answers:

```bash
# Who has ever committed, and under which identities?
git log --format='%an <%ae>' | sort | uniq -c | sort -rn
```

```
    142 Keveen Patel <patelkeveen@gmail.com>
     31 Keveen Patel <keveen@contoso.com>        <-- ⚠ two identities, same person
      4 root <root@build-agent>                   <-- ⚠⚠ who is this?
```

⭐ **Row three is the finding.** Commits authored by a build agent's local root account mean
something was committed by automation without an attributable identity — and **git author fields are
free text, so they are a claim, not evidence.**

```bash
# Which commits are actually SIGNED? (the difference between claim and evidence)
git log --format='%h %G? %an %s' -20
```

```
67c74d5 N Keveen Patel Complete 60-ai-and-secure-ai…     <-- N = unsigned
```

⭐ **`%G?` returns `G` (good), `B` (bad), `U` (unknown) or `N` (none).** Anyone can author a commit as
anyone — `git commit --author="Someone Else <them@corp.com>"` is not an attack, it is a documented
flag. **Only a signature turns authorship from a claim into evidence.** This is the same
claim-versus-evidence distinction as
[`../data-formats-and-apis/`](../data-formats-and-apis/) §3: a token's claims are readable, and only
the signature makes them trustworthy.

---

## 4. GitHub as a supply chain

⭐ **CI has write access to production and is often the least-governed identity in the estate** — the
finding from
[`../../60-ai-and-secure-ai/ai-pipeline-nhi/`](../../60-ai-and-secure-ai/ai-pipeline-nhi/) §5, at its
source.

| Control | ⭐ Why |
|---|---|
| ⭐ **OIDC / workload identity federation** | ⭐ **No stored secret at all** — the strongest control here |
| **Branch protection** | Nobody pushes to `main` unreviewed |
| **CODEOWNERS** | The right people must approve the right paths |
| ⭐ **Pin actions to a SHA** | `@v4` is a **moving tag someone else controls** |
| **Environment approvals** | A human gates the production deploy |
| **Least-privilege `permissions:`** | Default token scope is broader than most jobs need |

⭐ **Pinning actions is the one people skip.** `uses: actions/checkout@v4` resolves a tag that the
upstream owner can move at any time — **you have delegated code execution in your pipeline to
whoever controls that tag.** Pin to a commit SHA:

```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683   # v4.2.2
  # ⭐ a SHA cannot be moved; a tag can
```

**And the credential:**

```yaml
permissions:
  id-token: write        # ⭐ OIDC — federate, don't store a secret
  contents: read         # ⭐ least privilege, explicitly
```

⭐ **This is exactly `workload-identity-federation` applied to your own pipeline**, and it removes the
`gh-actions-ai-deploy` finding from
[`../../60-ai-and-secure-ai/ai-pipeline-nhi/`](../../60-ai-and-secure-ai/ai-pipeline-nhi/) §5 — an
identity holding two standing secrets *and* Contributor.

---

## 5. ⭐ `.gitattributes`, and the bug this repo actually had

**Git stores LF internally and can translate on checkout.** With no `.gitattributes`, Windows checks
out **CRLF** (`core.autocrlf` defaults to true) and Linux checks out **LF**.

⭐ **Usually harmless. It was not harmless here**, because `tools/Build-CoverageRegister.ps1`
**measures file sizes** — and CRLF costs one byte per line:

```
60-ai-and-secure-ai/azure-openai/README.md
   11,564 bytes as LF      ← authored here
   11,820 bytes as CRLF    ← checked out on the runner  (+256 lines)

⭐ 66 of 144 topics changed size → the register could NEVER match → CI red for two days
```

**The fix, on both sides:**

```gitattributes
* text=auto eol=lf          # ⭐ one canonical on-disk form, everywhere
*.png binary
```

…plus making the measurement itself line-ending independent, because ⭐ **an instrument whose reading
depends on where you stand is not an instrument.**

> ⭐ **The transferable lesson is bigger than git:** the failure was invisible, the code was correct,
> and the diagnosis required reproducing the *failing* environment rather than re-running the passing
> one — [`../troubleshooting-method/`](../troubleshooting-method/) §5. **Line endings are the first
> entry on the invisible-causes list for a reason.**

---

## 6. Recovering from the frightening things

⭐ **Almost nothing is lost, because commits stay reachable via the reflog for ~90 days:**

```bash
git reflog                       # ⭐ everywhere HEAD has been — the undo history
git reset --hard HEAD@{3}        # go back to where you were
git branch rescue <sha>          # ⭐ name a "lost" commit and it is safe
git fsck --lost-found            # find dangling commits
```

| Situation | Fix |
|---|---|
| Bad `reset --hard` | ⭐ `git reflog` → reset to the prior entry |
| Committed to the wrong branch | `git branch correct` then `git reset --hard HEAD~1` |
| Need to undo a **pushed** commit | ⭐ `git revert` — a new commit, safe for shared history |
| Committed a secret | §2 — ⭐ **rotate first** |

⭐ **`revert` versus `reset` is the shared-history rule:** `reset` rewrites, which breaks everyone
else's clone; `revert` adds a commit that undoes the change and is safe on a branch others have.

---

## 7. What breaks

**Deleting a secret in a later commit and calling it fixed.** §2 — ⭐ rotate.

**Trusting the author field.** §3 — free text; only signatures are evidence.

**Actions pinned to a tag.** §4 — ⭐ someone else can move it.

**Storing a deploy secret instead of federating.** §4.

**No branch protection on `main`.** Anyone pushes anything.

**Default workflow `permissions:`.** Broader than the job needs.

**No `.gitattributes` in a mixed-platform repo.** §5.

**`reset --hard` on shared history.** §6 — use `revert`.

**Believing something is lost.** §6 — check the reflog first.

**Not checking CI after pushing.** ⭐ This repo sat red for a day because nobody looked.

---

## 8. Customer discovery questions

1. Has anyone searched **full history** for secrets, not just the working tree? *(§2.)*
2. Is **push protection** on, or only after-the-fact scanning?
3. Are commits **signed**, and is signing required? *(§3.)*
4. Do any commits come from **unattributable identities**? *(§3.)*
5. Are GitHub Actions pinned to **SHAs** or to tags? *(§4.)*
6. Does CI authenticate by **OIDC federation** or a stored secret?
7. What is the **default `permissions:`** on your workflows?
8. Is `main` **branch-protected**, with CODEOWNERS on sensitive paths?
9. Who watches CI **after** a push?

---

## 9. Remember it

**Hook — "Git never forgets. Rotate, don't delete."**

**Analogy — a newspaper archive, not a whiteboard.** People treat a repository like a whiteboard:
write something, wipe it, it's gone. ⭐ **It is a newspaper.** Once an edition is printed and
distributed, "removing" the story means printing a *correction tomorrow* — **every copy already
delivered still has it**, and you have no idea who kept one. **The only real response to publishing a
secret is to make the secret worthless**, which is rotation.

**The one thing:** ⭐ **a committed secret is compromised the moment it is pushed, and rotation is the
fix — history rewriting is cosmetic.** `filter-repo` cannot reach forks, clones, CI caches, or a
laptop that pulled once. **Every hour spent rewriting history is an hour the live credential is still
valid.** Rotate first, rewrite later if you like, and turn on **push protection** so the next one
never lands.

**Runner-up:** ⭐ **pin actions to a SHA.** `@v4` is a pointer someone else controls, and it executes
in a pipeline holding your deploy credentials.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 10. Self-test

1. What does git actually store, and what is a branch?
2. ⭐ Why does removing a secret in a later commit not fix it? What is the correct first step?
3. What does `%G?` show, and why does it matter?
4. Why is the commit author field not evidence?
5. Why pin actions to a SHA rather than a tag?
6. Which two `permissions:` values does an OIDC-federated deploy job need?
7. ⭐ How did missing `.gitattributes` break this repo's CI, and how big was it?
8. Which principle from troubleshooting was required to diagnose it?
9. When must you use `revert` rather than `reset`?
10. Where do you look first when you think a commit is lost?

<details>
<summary>Answers</summary>

1. ⭐ **Whole snapshots**, content-addressed by hash, in a DAG. ⭐ A branch is **a movable pointer to a
   commit** — nothing more.
2. ⭐ The **blob stays reachable** and exists in every clone taken. First step: ⭐ **rotate the
   secret** — treat exposure as permanent.
3. Signature status: `G` good, `B` bad, `U` unknown, `N` none. ⭐ It is the difference between
   **claimed** and **proven** authorship.
4. ⭐ It is **free text** — `git commit --author=` is a documented flag, not an exploit.
5. ⭐ A **tag can be moved by whoever owns it**, and the action executes in a pipeline holding your
   deploy credentials. A SHA cannot move.
6. **`id-token: write`** (to request the OIDC token) and **`contents: read`**.
7. Windows checked out **CRLF**, adding one byte per line, and the coverage tool ⭐ **measures file
   sizes** — ⭐ **66 of 144 topics changed size**, so the committed register could never match. Two
   days red.
8. ⭐ **Reproduce the failing environment, not the passing one** — the tool passed locally both before
   and after the fix.
9. ⭐ On **shared/pushed history** — `reset` rewrites and breaks everyone else's clone; `revert` adds
   a new commit.
10. ⭐ **`git reflog`** — commits stay reachable for roughly 90 days.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** ⭐ — run the §2 history search and the §3 author/signature audit against this repository.
  **Runnable right now, no subscription, and this repo has a real finding in it.**
- **`break-fix/`** ⭐ — commit a fake secret, "remove" it in the next commit, then **recover it from
  history** to prove the point. Then enable push protection and watch the next attempt be blocked at
  the push. **Recovering your own "deleted" secret is the moment this topic lands.**
- **`security/`** — full-history secret scan results; signing policy and current `%G?` coverage;
  action pinning audit; workflow `permissions:` review; branch protection and CODEOWNERS state.
- **`operations/`** — post-push CI check as a standing habit; secret-rotation runbook that starts with
  rotation rather than history rewriting.
- **`architecture-decisions/`** — ADR: OIDC federation for CI, actions pinned to SHAs,
  `.gitattributes` mandatory in any repo whose tooling measures files.
- **`customer-use-cases/`** — §8 answered against a customer's repositories.
