# Transcript series — honest assessment and gaps

> Measured **2026-08-12**. Read this before trusting the 19 processed day files.

---

## 1. ⚠ Days 01–05 raw transcripts are GONE

```
raw_transcripts\Day-06-RAW.md … Day-19-RAW.md   ✅ present (14 files)
Day-01 … Day-05                                 ⭐ NO BACKUP ANYWHERE ON DISK
```

Searched `C:\IT` and `Downloads`. **No other copy exists.** The backup practice began at Day 06 —
after the question was asked, not before.

**Consequence:** for Days 01–05 the processed file is now the *only* copy. Anything cut is
unrecoverable locally.

**Recovery:** re-pull those five transcripts from the source YouTube videos and store them in
`raw_transcripts/` before doing any further editing of Days 01–05.

⭐ **Rule from here: never transform a source you cannot re-fetch, without writing the original
down first.** This is the git lesson from
[`../../00-foundations/git-and-github/`](../../00-foundations/git-and-github/) §2 — an append-only
copy costs nothing and an irreversible transform costs everything.

---

## 2. Compression is aggressive — 85–91%

| Day | Raw | Processed | Removed |
|---|---:|---:|---:|
| 06 | 141 KB | 21 KB | 85% |
| 13 | 130 KB | 17 KB | 87% |
| 17 | 151 KB | 16 KB | 89% |
| **19** | **175 KB** | **15 KB** | ⭐ **91%** |

Transcript→notes normally sheds 60–75% (spoken filler, repetition, "um"). ⭐ **At 91%, roughly one
word in eleven survived.** That is past filler removal and into content loss.

---

## 3. ⭐ The cross-domain material was largely lost

Counting mentions of non-Microsoft tools, frameworks and career context
(Okta · SailPoint · CyberArk · AWS · GCP · Splunk · ServiceNow · Terraform · ITIL · SOC 2 ·
ISO 27001 · NIST · GDPR · Zero Trust · interview · salary) across each processed file:

```
Day-12:  2 hits      ← identity governance & external auth
Day-17:  2 hits      ← app registration & SSO
Day-09:  3           Day-15:  4
...
Day-07: 44 hits      Day-16: 41      Day-18: 30
```

⭐ **Days 12 and 17 are exactly where an SC-300 candidate most needs the comparative context** —
external identity providers next to Okta/Ping, app registration next to SAML/OIDC practice
elsewhere — and they have **two mentions between them.**

**This is the specific loss to fix.** The structure that survived is good; the connective tissue to
the wider industry is not.

---

## 4. What is genuinely good

The surviving structure is professional and worth keeping:

```
Executive summary → numbered modules → hands-on labs with real
PowerShell/CLI steps → knowledge check → first-principles matrix
→ explicit hand-off to the next day
```

Day 13's PIM file, for example, carries Graph API activation payloads, role-policy configuration
via PowerShell, and CLI JIT activation. ⭐ **That is usable material, not summary fluff.**

---

## 5. What the 19 days actually cover

| Days | Content | Reality |
|---|---|---|
| **01** | Cloud fundamentals + identity | AZ-900 level |
| **02–06** | ⭐ **VNets, peering, NSGs, storage, RBAC, compute, monitoring** | ⭐ **AZ-104 prerequisite — not on SC-300** |
| **07–19** | Entra, hybrid, auth, CA, PIM, governance, apps, Sentinel | ⭐ **SC-300 proper** |

⭐ **Only 13 of 19 days are SC-300.** Five days are Azure infrastructure groundwork. That is not
wasted — SC-300 assumes Azure familiarity — but it changes the maths on "19 days of SC-300".

---

## 6. Priority fixes, in order

1. ⭐ **Re-pull Days 01–05 raw transcripts.** Highest priority: it is the only irreversible gap.
2. ⭐ **Re-expand Days 12 and 17** from their raw files, restoring the comparative/industry
   content. Both raws exist.
3. Set a floor: **processed ≥ 20% of raw**, and treat anything below as a review trigger.
4. Cross-link each day to the matching topic README in this repo, so the theory has a home.
