# Architecture

> **Read this first.** It explains what this repository is, how it is built, why it is built that
> way, and how to extend it without degrading it.
> Written **2026-08-10**. Every number below is **measured**, not asserted — regenerate with
> `tools/Build-CoverageRegister.ps1`.

---

## 1. What this is

A **mastery track for Azure cloud security roles**, spanning six certifications and the tooling
those roles actually require. SC-300 is the entry point, not the scope — see
[`CERT-MAP.md`](CERT-MAP.md).

It is **not** a notes folder and **not** an exam crammer. The design goal is that a topic read once
leaves you able to explain the mechanism to an interviewer, run the commands in a real tenant, and
recognise the failure when it happens at a customer.

---

## 2. The shape

```
azure-cloud-security-mastery/
├── ARCHITECTURE.md          ← you are here
├── CONTENT-STANDARD.md      ← what a topic must contain (the contract)
├── COVERAGE.md              ← GENERATED. The honest state. Never edit.
├── RETENTION.md             ← interleaved memory layer across all written topics
├── CERT-MAP.md              ← which domain serves which certification
├── tools/
│   └── Build-CoverageRegister.ps1
├── .github/workflows/
│   └── coverage.yml         ← CI: register current, links resolve
│
└── NN-domain/               ← numbered domains, roughly dependency-ordered
    └── topic-name/
        ├── README.md        ← THE TOPIC. 11 required sections.
        ├── lab/             ┐
        ├── break-fix/       │
        ├── security/        ├─ six EVIDENCE facets — artifacts, not intentions
        ├── operations/      │
        ├── customer-use-cases/
        └── architecture-decisions/
```

**Domains are numbered to encode dependency, not importance.** `00-foundations` and `10-networking`
come first because `30-identity-and-nhi` silently assumes them — Conditional Access failures are
usually DNS or TLS failures wearing a costume.

---

## 3. The two axes, and why there are two

This is the most important design decision in the repository, and it exists because of a specific
failure.

**The original register measured only evidence.** It reported `PARTIAL` for both an 18 KB topic with
worked examples and a 1.1 KB one with none. That blindness is *how 123 placeholder topics survived
unnoticed.* An instrument that cannot see the failure will not report it.

So there are now **two orthogonal axes**:

| Axis | Question | Values |
|---|---|---|
| **State** | Did you *do* it in a tenant? | `WRITTEN` (≥3 of 6 facets) · `PARTIAL` · `STUB` · `EMPTY` |
| **Depth** | Can you *learn* from it? | `DEEP` (≥8 KB **and** ≥4 worked examples) · `THIN` · `NONE` |

```
        DEPTH →      NONE          THIN          DEEP
STATE
  ↓  STUB        placeholder        —             —
     PARTIAL          —        prose only    ⭐ good study material,
                                              lab not yet run
     WRITTEN          —             —         complete
```

⭐ **`PARTIAL` + `DEEP` is the correct state for most of this repo right now** — the material is
genuinely studiable; the labs need a tenant that does not yet have the licences. Conflating that with
`PARTIAL` + `THIN` is what went wrong before.

**`WRITTEN` is 0 and that is honest.** Evidence facets require a tenant with Entra ID P2, an Azure
subscription, and Defender licensing. See §8.

---

## 4. The content contract

Every topic README carries **11 sections** — [`CONTENT-STANDARD.md`](CONTENT-STANDARD.md) is the
authority. The three that do the work:

| § | Section | Why it exists |
|---|---|---|
| **4** | **Worked example** | ⭐ Real values, traced end to end. **Computed, not invented** — the immutableId conversion, the TLS chain, the subnet boundaries were all *run* before being written down. |
| **7** | **What breaks** | Failure modes with **verbatim error text**. Recognition beats theory in an incident. |
| **9** | **Remember it** | ⭐ Hook, **load-bearing analogy**, and the one line that regenerates the topic. Explaining without retention aids is lecturing. |

**Disqualifiers**, enforced by review and partly by CI:

- Boilerplate that *describes* work ("Explain, implement, secure, operate…") — that is a plan
- No worked example — that is sections 1–3 of 11
- Commands with no expected output — the reader cannot tell success from failure
- Links that 404
- Claiming hands-on where none happened

**Verification marking is mandatory:** **`✅ verified`** (run, or read from a live doc, with a date)
· **`⚠ check`** (correct to current knowledge, not re-verified) · **`✗ unrunnable`** (blocked, and by
what). **An unmarked claim is treated as `⚠ check`.**

---

## 5. The retention layer, and why it is one file

[`RETENTION.md`](RETENTION.md) holds the mnemonics, analogies, confusion pairs, the numbers table,
the symptom→cause reflex table and the 90-second refresher **for every written topic, interleaved**.

**Deliberately not 22 appendices.** Interleaved retrieval beats blocked review for durable recall;
reviewing one topic at a time feels productive and is not. Each topic still carries a short §9, and
every hook is folded back into the deck.

⭐ It also holds **§3b cross-cutting patterns** — the rules that transfer to products you have never
seen:

| Pattern | What it predicts |
|---|---|
| **"Watch first"** | Every enforcement control has an observe mode — CA report-only, ASR audit, LDAP Event 2889, `Audit` before `Deny`, notify before remediate |
| **"Two identities"** | The service principal / consented app is a **separate principal**. Nothing you do to the user touches it. |
| **"It changes by itself"** | Certificates expire, DNS TTLs lapse. The two silent clocks. |
| **"Deployed is not enforced"** | Firewall without a UDR; private endpoint without a linked DNS zone; ASR in audit |

**Those four patterns are worth more than any individual fact**, because they generalise.

---

## 6. How truth is measured

```
tools/Build-CoverageRegister.ps1   walks the filesystem → writes COVERAGE.md
        │
        ├── -Check                 CI mode: fails if the register is stale
        └── .github/workflows/coverage.yml
                ├── coverage-is-current
                ├── links-resolve            (relative links)
                └── external-links-resolve   (fails on 404/410 only)
```

> ⭐ **The register is generated so the repository cannot overstate itself.** A hand-maintained
> inventory drifts within weeks and always drifts optimistically. **If a claim about coverage is not
> produced by that script, it is not a claim — it is a hope.**

---

## 7. ⚠ Two governance systems — reconciled here

**Finding, 2026-08-10.** The repository accreted **two overlapping governance layers** that did not
reference each other:

| Original layer | Later layer | Resolution |
|---|---|---|
| `MASTERY-STANDARD.md` | **`CONTENT-STANDARD.md`** | ⭐ **CONTENT-STANDARD is authoritative** for topic READMEs. MASTERY-STANDARD remains the broader aspiration (diagrams, HLD/LLD, customer artefacts) and is a superset not yet enforced. |
| **`COMPLETENESS-REGISTER.md`** — "the authoritative inventory", hand-maintained | **`COVERAGE.md`** — generated | ⭐ **COVERAGE.md is authoritative.** A hand-maintained register is exactly the asserted-vs-measured failure this repo exists to avoid. |
| `CERTIFICATION-MAP.md` | **`CERT-MAP.md`** | CERT-MAP is authoritative — it carries the corrected SC-200 mapping. |
| `STAGE-GATES.md`, `CURRICULUM-MAP.md`, `OPERATING-MODEL.md`, `EXPERT-REPOSITORY-ARCHITECTURE.md`, `EVIDENCE-SCHEMA.md`, `VERIFICATION-CHECKLIST.md` | — | **Kept as process documents.** They describe *how work moves*; CONTENT-STANDARD describes *what a topic must contain*. Complementary, not duplicative. |

**Nothing is deleted.** Superseded files carry a pointer to the authoritative one. **Two authorities
is the defect; the fix is naming which one wins, not destroying history.**

⚠ **Root accretion is a live risk.** There are **25 root markdown files**. Any new index must
justify why it is not a section of an existing one.

---

## 8. Honest state — measured 2026-08-10

| Domain | DEEP | Topics | Content |
|---|---:|---:|---:|
| `10-networking` | **14** | 14 ✅ | 149.5 KB |
| `35-active-directory-and-hybrid-identity` | **8** | 8 ✅ | 119.5 KB |
| `50-security-operations` | **14** | 14 ✅ | 194.1 KB |
| `30-identity-and-nhi` | **6** | 20 ⚠ | 248.5 KB |
| `60-ai-and-secure-ai` | 0 | 14 | 25.4 KB |
| `80-customer-scenarios` | 0 | 9 | 25.2 KB |
| Everything else | 0 | 65 | ~48 KB |
| **Total** | **42** | **144** | **~810 KB** |

**Three domains complete. `30-identity-and-nhi` is the live gap** — it is **SC-300 core**, the
certification being sat first, and 14 of its 20 topics remain THIN.

**`WRITTEN` is 0 of 144, and the reason is licensing, not effort:**

| Blocked capability | Needs |
|---|---|
| Conditional Access, PIM, Identity Protection, entitlement management | **Entra ID P2** |
| Defender for Identity | EMS E5 / M365 E5 |
| Defender for Endpoint P2 | M365 E5 / E5 Security — ⚠ **EMS E5 does not cover this** |
| Managed identities, Key Vault, Log Analytics, attack paths | **An Azure subscription** |

Current tenant `Kev@KWin.onmicrosoft.com` holds **Microsoft 365 E5 (trial, expires 2026-09-10)** and, since **2026-08-19**, **Azure subscription `912ac3b8-d003-48d1-8266-e4d029ba1fd7`** in tenant `K-Win` (`b6464ac2-0b24-4e5f-be10-b4270b90d4ce`). Lab resource group: `sc-300-lab-cin-rg-01` (centralindia, tagged `expires=2026-09-07`).
**One EMS E5 trial unblocks four of those rows.**

---

## 9. How to extend it without degrading it

1. **Read [`CONTENT-STANDARD.md`](CONTENT-STANDARD.md).** Match
   [`entra-connect-sync`](35-active-directory-and-hybrid-identity/entra-connect-sync/README.md) for depth.
2. **Verify before writing.** Product boundaries, licensing and dates drift. Cite the date. Mark
   `⚠ check` rather than inventing precision.
3. **Compute the worked example.** Run it; paste real output. Invented values are the thing this
   repo exists to avoid.
4. **Add the §9 hook to [`RETENTION.md`](RETENTION.md)** — a topic-local memory aid that is not
   interleaved does half its job.
5. **Regenerate the register.** `tools/Build-CoverageRegister.ps1`. Never hand-edit `COVERAGE.md`.
6. **Check links resolve** before committing; CI will fail otherwise.
7. **Cross-link.** The value compounds — attack paths ↔ lateral movement paths, app registrations ↔
   the SP credential hunt, PIM activation ↔ the CA token-issuance gap.

---

## 10. The design decisions, stated plainly

| Decision | Why | Rejected alternative |
|---|---|---|
| Generated coverage register | A repo must not be able to overstate itself | Hand-maintained inventory — drifts, always optimistically |
| **Two axes** (State × Depth) | An instrument blind to the failure will not report it | One axis — hid 123 placeholders |
| 11-section contract | Forces mechanism, examples, failures and recall | Free-form prose — becomes filler |
| **Computed worked examples** | Invented values teach wrong details confidently | Plausible-looking illustrations |
| Interleaved retention deck | Interleaving beats blocked review for recall | Per-topic appendices |
| **Scope cut to ~32 priority topics** | 144 × 15 KB ≈ 2 MB of verified writing is a textbook | Pretending 144 was achievable |
| Six evidence facets per topic | Separates *read it* from *did it* | Marking a topic done on prose alone |
| Numbered domains | Encodes dependency order | Alphabetical — hides prerequisites |
| Nothing deleted on supersession | History has value; ambiguity does not | Deleting legacy indexes |

---

## 11. Where to start reading

**If you are studying:** [`START-HERE.md`](START-HERE.md) → [`CERT-MAP.md`](CERT-MAP.md) → the
domain your next exam needs → [`RETENTION.md`](RETENTION.md) for recall.

**If you are assessing the repo:** [`COVERAGE.md`](COVERAGE.md) — it is generated and it will not
flatter anyone.

**If you want the exemplar:**
[`35-active-directory-and-hybrid-identity/entra-connect-sync/`](35-active-directory-and-hybrid-identity/entra-connect-sync/README.md).
