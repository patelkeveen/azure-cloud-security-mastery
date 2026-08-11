# AI Search and RAG

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10**.
> **SC-500 core.** Where the permission problem in
> [`../sensitive-data-leakage/`](../sensitive-data-leakage/) becomes concrete.

---

## 1. What it is

**Retrieval-Augmented Generation**: instead of relying on what a model memorised, **retrieve relevant
documents at query time** and put them in the prompt.

```
User question
   → EMBED the question
   → SEARCH an index (vector / keyword / hybrid)
   → retrieve top N chunks
   → ⭐ INJECT them into the prompt as context
   → model answers FROM THAT CONTEXT
```

**It solves three real problems:** stale training data, hallucination (answers are grounded in
retrieved text), and the impossibility of fine-tuning on constantly changing corporate content.

---

## 2. ⭐ The security problem in one sentence

> **The index is a copy of your data with a copy of your permissions — and copies drift.**

That is the whole topic. Every RAG security failure is a variation of it:

| Drift | Consequence |
|---|---|
| Document permissions changed; index not refreshed | ⭐ Retrieval authorises against **stale ACLs** |
| Document deleted at source; chunk remains indexed | Deleted content still answerable |
| Sensitivity label applied later | Label-based restrictions not honoured |
| Chunking split a document | ⭐ A restricted paragraph inherits a permissive parent's context |

⭐ **And a second, subtler problem: retrieval is a *summarisation* channel.** A user permitted to read
100 documents individually may never have read all of them — but the model will happily synthesise
across all 100 at once. **Aggregate disclosure is a genuinely new exposure**, and no permission model
addresses it.

---

## 3. ⭐ Document-level access control — now built in ✅

The old approach was a manual **security filter**: store group IDs in a field and filter on them at
query time. That still exists as a fallback, but Azure AI Search now supports **document-level access
control natively** ✅:

```
SOURCE SYSTEM               INDEX                        QUERY TIME
SharePoint ACLs        →   permission metadata      →   ⭐ Entra principal in the QUERY TOKEN
ADLS Gen2 ACLs/RBAC        stored alongside              compared against stored ACLs
Purview labels             the chunks                    → unauthorised items EXCLUDED
```

✅ **Azure AI Search checks the Microsoft Entra principal in the query token against the ACL metadata
in the index and excludes any items the caller is not authorised to access.** No custom permission
code, and **results stay aligned with the source identity system**.

⭐ **Purview label-based access goes further** ✅: the service evaluates **the document's sensitivity
label, the user's Entra token, and the organisation's Purview policies** together — so a labelled
document is withheld unless both identity *and* label permit it. That is the direct payoff of the
label taxonomy in
[`../../50-security-operations/purview/`](../../50-security-operations/purview/) §4.

**Ingestion routes for permission metadata** ✅: the **SharePoint indexer** (including **site group
memberships**, honoured at query time), the **ADLS Gen2 indexer**, and the **push REST API** for
custom pipelines.

---

## 4. ⚠ The refresh gotcha that decides whether any of it works ✅

> **In the 2026-05-01-preview REST API, SharePoint ACL synchronisation detects changes on items with
> *unique* permissions and refreshes them on each successful indexer run — but ⭐ changes inherited
> from parent scopes require an *explicit* refresh.**

**Read that carefully, because it is the security failure hiding in a feature description:**

```
Remove access at the FOLDER level (inherited by 400 documents)
        │
        └── the indexer does NOT pick this up automatically
                 │
                 └── ⭐ 400 documents remain retrievable by someone who lost access
```

⭐ **The most common way permissions are revoked in SharePoint is at a parent scope** — remove a
group from a site or a library. That is precisely the case requiring an explicit refresh. **Anyone
who assumes ACL sync is fully automatic has a live exposure they cannot see**, and no error is raised.

⚠ Verify the current behaviour and API version in the target tenant — this is preview surface and it
will move. **But ask the question regardless**, because the general principle survives any version:
*"what is the lag between a permission change at source and the index reflecting it?"*

---

## 5. Worked example — proving the trimming actually works

**Configuration is not evidence. Two identities and one question are.**

```bash
# The index must carry permission metadata, and queries must be user-token based
az search index show --service-name <svc> -n <index> \
  --query "fields[?contains(name,'acl') || contains(name,'permission') || contains(name,'group')]" -o table
```

**Then the real test:**

```
1. Pick a document only ALICE may read.
2. Query the RAG app as ALICE   → the answer cites it            ✅ expected
3. Query the RAG app as BOB     → ⭐ the answer must NOT cite it, and must not
                                   contain its content in paraphrase
4. Remove Alice's access AT THE PARENT FOLDER.
5. Re-run step 2 immediately    → ⭐ does the index still return it?
```

⭐ **Step 5 is the test almost nobody runs**, and it is the one that exposes §4. Record the lag in
minutes; that number is your actual revocation window and belongs in the risk register.

**Then check the query pattern in code — this is where trimming is silently lost:**

```python
# ✗ WRONG — the app queries with ITS OWN identity; every user sees everything
search_client = SearchClient(endpoint, index, DefaultAzureCredential())

# ✅ RIGHT — query carries the END USER's token, so ACLs are enforced per caller
search_client = SearchClient(endpoint, index, on_behalf_of_credential(user_token))
```

⭐ **An application that queries with its own managed identity bypasses document-level security
entirely** — every user gets the union of everything indexed. **The code looks correct, the feature
is enabled, and the control does nothing.** This is the single highest-value line to review in a RAG
codebase.

---

## 6. What breaks

**App queries with its own identity.** §5 — trimming silently disabled.

**Parent-scope permission changes not refreshed.** §4 — stale authorisation.

**Deleted documents left in the index.** Answerable after removal.

**Chunking across permission boundaries.** A restricted section indexed under a permissive parent.

**No label evaluation.** Sensitivity labels ignored unless Purview integration is configured.

**Assuming trimming was tested because it was configured.** §5.

**Ignoring aggregate disclosure.** §2 — no permission model covers synthesis across many documents.

**Indexing everything "because we can".** The index is a new copy of sensitive data with its own
access surface, backups and blast radius.

**No index-level network controls.** The index itself needs private endpoints and Entra auth, exactly
like the model endpoint — see [`../private-ai-networking/`](../private-ai-networking/).

---

## 7. Customer discovery questions

1. Does the application query with the **end user's token**, or its own identity? *(§5 — ask to see
   the line of code.)*
2. Is **document-level access control** configured, or a hand-rolled security filter?
3. What is the **lag** between a permission change at source and the index reflecting it?
4. Are **parent-scope** permission changes explicitly refreshed? *(§4.)*
5. Are **sensitivity labels** evaluated at query time?
6. What happens to indexed chunks when the source document is **deleted**?
7. Has trimming been **tested with two real identities**, and when?
8. What is in the index that should never have been indexed?
9. Is the search service itself **privately networked and Entra-authenticated**?

---

## 8. Remember it

**Hook — "The index is a copy of your data *and* a copy of your permissions."** Copies drift.

**Analogy — a photocopied filing cabinet.** RAG builds a **second filing cabinet**: copies of the
documents, plus a copy of the list of who may open each drawer. **When someone loses access to the
original, nobody walks over and updates the photocopied list** — especially when the change was made
at the cabinet level rather than per file. ⭐ **And the new cabinet has a research assistant who will
read across every drawer at once and summarise** — which nobody was ever able to do before, and
which no access list was designed to prevent.

**The one thing:** ⭐ **if the application queries with its own identity, document-level security does
nothing.** The feature is enabled, the metadata is indexed, the configuration review passes — and
every user receives the union of everything. **Ask to see the credential used on the search client.
That one line is the control.**

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. State the RAG security problem in one sentence.
2. What does Azure AI Search compare at query time, and against what?
3. Which three sources of permission metadata can be ingested?
4. What does Purview label-based access evaluate?
5. ⭐ Which permission changes do **not** refresh automatically, and why is that dangerous?
6. What is the single line of application code that determines whether trimming works?
7. What is aggregate disclosure, and which control addresses it?
8. Why is a deleted source document still a risk?
9. What must a trimming test involve to be evidence rather than configuration?

<details>
<summary>Answers</summary>

1. **The index is a copy of your data with a copy of your permissions — and copies drift.**
2. The **Entra principal in the query token** against **ACL metadata stored in the index**;
   unauthorised items are excluded.
3. **SharePoint** (including site group memberships), **ADLS Gen2**, and the **push REST API**.
4. The document's **sensitivity label**, the user's **Entra token**, and the organisation's
   **Purview policies** — all three.
5. ⭐ **Changes inherited from parent scopes** — they require an **explicit refresh**. Dangerous
   because revoking at a parent scope is the *most common* way access is removed.
6. **The credential on the search client** — the end user's token versus the app's own identity.
7. Synthesis across many documents a user could read individually but never would have read together.
   ⭐ **No permission model addresses it.**
8. The **indexed chunk persists**, so the content remains answerable after the source is removed.
9. **Two real identities**, a document only one may read, and a **re-test immediately after revoking
   access at the parent scope**.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — build a RAG app over a document library; run the §5 five-step test with two
  identities and **record the revocation lag in minutes**. ✗ Requires an Azure subscription.
- **`break-fix/`** — query with the **app's own identity** and demonstrate every user seeing
  everything; switch to the user's token and prove trimming engages. Then revoke at a **parent
  scope** and show the stale result.
- **`security/`** — index inventory (what is indexed, from where, classified how); trimming test
  evidence with dates; measured permission-change lag.
- **`operations/`** — indexer refresh schedule including explicit parent-scope refresh; deletion
  handling for removed source documents.
- **`architecture-decisions/`** — ADR: on-behalf-of querying mandatory; what may be indexed and what
  may not; label evaluation at query time.
- **`customer-use-cases/`** — §7 answered; a RAG security review as an engagement deliverable.
