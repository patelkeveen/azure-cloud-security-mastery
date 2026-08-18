# Google Workspace to Microsoft 365

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The migration where the two products disagree about what a file *is*.** Pairs with
> [`../sharepoint-and-onedrive-migrations/`](../sharepoint-and-onedrive-migrations/) and
> [`../migration-tools/`](../migration-tools/).

---

## 1. What it is

Moving Gmail, Google Calendar, Contacts and Google Drive into Exchange Online, OneDrive and
SharePoint. Microsoft provides a native **Google Workspace migration** in the Exchange admin centre
for mail/calendar/contacts, and **Migration Manager** connectors for Drive content.

⭐ **Unlike an Exchange source, nothing here is a like-for-like move.** Every object crosses a
semantic boundary as well as a network one.

---

## 2. Why it exists — the four semantic mismatches

| Google concept | Microsoft equivalent | ⭐ What is lost or changed |
|---|---|---|
| ⭐ **Labels** (a message can have many) | Folders (a message is in one) | ⭐ **multi-label messages are duplicated or arbitrarily assigned** |
| ⭐ **Google Docs / Sheets / Slides** | ⭐ **no equivalent format** | ⭐ **must be converted to `.docx` / `.xlsx` / `.pptx`** |
| **Shared drives** | SharePoint site libraries | ownership model differs entirely |
| "Anyone with the link" sharing | ⭐ Anonymous / Anyone links | ⭐ **often disabled by target tenant policy** |

⭐ **The label→folder collapse is the one that generates user complaints**, because it is invisible
in any dashboard: the migration reports success, and a user finds one message where they expected
it in three places.

⭐ **Google Docs conversion is a fidelity decision, not a technical one.** A converted document is a
*new* document: comments, revision history and Apps Script attached to the original do not survive.
Native Google files must be enumerated at discovery and the conversion policy agreed in writing.

---

## 3. How it works underneath — the authorisation model is the hard part

Google does not have "give this migration tool admin rights". It has **service accounts with
domain-wide delegation**:

```
GOOGLE CLOUD PROJECT
   └── Service account  (⭐ a non-human identity, with a JSON private key)
          │
          └── DOMAIN-WIDE DELEGATION enabled
                 │  Client ID + explicit OAuth SCOPES authorised
                 │  in the Google Workspace admin console
                 ▼
          ⭐ can IMPERSONATE any user in the domain
                 │
                 ├─ gmail.readonly        →  mail
                 ├─ calendar.readonly     →  calendar
                 └─ contacts.readonly     →  contacts
                          │
                          ▼
          EXO Google Workspace migration reads per-user data
```

⭐ **Domain-wide delegation is the most powerful grant in Google Workspace: one key that can read
every mailbox in the organisation.** Treat that JSON key exactly as you would a Global Admin
credential — and this is the single best security observation to make in an interview about this
migration.

⭐ **The security controls that belong in the plan, not as an afterthought:**

| Control | Why |
|---|---|
| ⭐ Grant **read-only** scopes | the migration never needs write |
| Scope to the minimum APIs | Gmail, Calendar, Contacts — nothing else |
| ⭐ **Revoke delegation the day migration completes** | ⭐ otherwise a live master key outlives the project |
| Store the JSON key like a secret | Key Vault — [`../../30-identity-and-nhi/key-vault/`](../../30-identity-and-nhi/key-vault/) |
| Log the impersonations | Google admin audit log; keep as evidence |

---

## 4. Worked example — the delegation record and the label collapse

**The delegation entry, as it appears in the Google Workspace admin console:**

```
Client ID: 118273645509182736451
Scopes:
  https://www.googleapis.com/auth/gmail.readonly
  https://www.googleapis.com/auth/calendar.readonly
  https://www.googleapis.com/auth/contacts.readonly
```

⭐ **Three read-only scopes.** If a tool asks for `https://mail.google.com/` (full access) or
`gmail.modify`, ask why in writing before granting it.

**One message, traced across the boundary:**

```
GMAIL
  Subject : Q3 variance pack
  Labels  : Finance, Q3-2024, Follow-up      ⭐ three labels
  Starred : yes

EXCHANGE ONLINE (after migration)
  Subject : Q3 variance pack
  Folder  : /Finance                          ⭐ ONE folder — first label wins
  Category: (tool-dependent; may be blank)
  Flagged : (star mapping is ⭐ tool-dependent)
```

⭐ **"First label wins" is not a rule you can rely on across tools** — some duplicate the message
into each label folder instead, which inflates the target mailbox and breaks item-count
reconciliation. ⭐ **Establish which behaviour your tool has during the pilot, and state it to the
customer**, because both behaviours are defensible and only one matches their expectation.

**Drive content, sized honestly:**

```
Shared drive "Finance"           412 GB
  ├─ native Google Docs/Sheets    ⭐  8,140 files  →  converted to Office formats
  ├─ PDFs, images, Office files      31,002 files  →  moved as-is
  └─ files owned by ex-employees  ⭐    2,214 files →  ⭐ ORPHANED — no owner to migrate
```

⭐ **Orphaned files are a real category in every Google migration**, because Drive files belong to a
*person* by default. When that person left, their My Drive was deleted or suspended — and the files
shared from it are still visible to colleagues but have no valid owner to migrate from. **Find these
at discovery; reassigning ownership is customer work with a lead time.**

---

## 5. Commands

**Target-side pre-flight — OneDrive must exist before content can land in it:**

```powershell
Request-SPOPersonalSite -UserEmails 'a.khan@contoso.com','j.smith@contoso.com'
Get-SPOSite -IncludePersonalSite $true -Limit All -Filter "Url -like '-my.sharepoint.com/personal/'" |
  Select-Object Owner, StorageUsageCurrent
```

```
Owner                  StorageUsageCurrent
a.khan@contoso.com                       0
j.smith@contoso.com                      0
```

⭐ **A OneDrive is provisioned on first sign-in, not on licensing.** Migrating content for a user who
has never signed in fails until the personal site exists — `Request-SPOPersonalSite` is the fix, and
provisioning is asynchronous (⚠ allow time, then re-check).

**Verify a migrated mailbox against the source count:**

```powershell
Get-MailboxFolderStatistics a.khan@contoso.com |
  Where-Object FolderType -eq 'User' |
  Select-Object Name, ItemsInFolder, FolderSize
```

```
Name        ItemsInFolder  FolderSize
Finance             4,182  1.9 GB (2,040,109,332 bytes)
Q3-2024                 0  0 B
```

⭐ **`Q3-2024` with zero items is the label collapse, made visible.** The folder was created; the
messages went to `Finance`. This is exactly the check to run in the pilot — and exactly the
conversation to have with the customer before wave one.

---

## 6. When and where

| Scope | Approach |
|---|---|
| Mail, calendar, contacts only | ⭐ **native EXO Google Workspace migration** — free |
| Drive content | ⭐ **Migration Manager** Google connector |
| ⭐ High-fidelity, labels preserved as categories, Docs history | ⭐ third party (BitTitan, CloudM, AvePoint) |
| Google Vault / legal hold data | ⭐ **separate project** — export via Vault, ingest to Purview |
| < 10 users | manual export/import is genuinely defensible |

⚠ `⚠ check` — **Mover.io, formerly Microsoft's free Google Drive migration tool, was retired**;
Migration Manager connectors are the current path. Confirm connector availability for the specific
source (Drive, Box, Dropbox, Egnyte) before designing around it.

⭐ **Google Vault data is not part of the mailbox migration.** A customer under legal hold in Google
who assumes their hold travels with the mail is exposed. Raise it explicitly.

---

## 7. What breaks

| Symptom / error | Cause | Fix |
|---|---|---|
| `unauthorized_client` / `Client is unauthorized to retrieve access tokens` | ⭐ **delegation scopes not authorised for that client ID** | re-add scopes; ⭐ exact string match, no trailing spaces |
| Migration runs, one user always fails | user suspended or licence removed in Google | restore, or exclude explicitly |
| Messages missing that "were definitely there" | ⭐ label collapse | §4 — a design consequence, not a fault |
| Drive files fail with no owner | ⭐ orphaned files | reassign ownership in Google first |
| Google Docs arrive as `.gdoc` shortcut stubs | conversion not enabled | ⭐ enable conversion; ⭐ stubs are useless in M365 |
| OneDrive target not found | personal site not provisioned | `Request-SPOPersonalSite` |
| Shared link stops working | anonymous links disabled in target tenant | ⭐ a **policy** decision — escalate, do not silently enable |

⭐ **`.gdoc` stubs are the worst outcome, because the migration reports success.** The file arrives,
is a few hundred bytes, and contains a link back to a Google Drive the customer is about to
decommission. Check file sizes in the pilot.

---

## 8. Customer discovery questions

1. ⭐ **"How many native Google Docs, Sheets and Slides are there?"** — the conversion scope
2. "Do users rely on multiple labels per message?"
3. ⭐ **"Are there files owned by people who have left?"**
4. "Do you use Google Vault, and is anything on hold?"
5. "How many shared drives, and who owns each?"
6. "Are there Apps Scripts or AppSheet apps in use?" (⭐ nothing migrates them)
7. ⭐ **"Who can approve creating a service account with domain-wide delegation, and who will revoke it?"**

---

## 9. Remember it

**Hook — `L D O S`: Labels, Docs, Orphans, Scopes.** The four things that are not a network problem.

**Analogy — translating a book, not shipping it.** ⭐ **A shipping company moves the physical book;
here you are translating it into another language.** Most sentences survive; ⭐ **puns do not** —
and labels, Google Docs revision history and Apps Scripts are the puns. The analogy predicts the
practice: **you agree the translation policy before starting, and you accept that some meaning is
chosen rather than preserved.**

**The one line:** ⭐ **Nothing is a like-for-like move; a service account with domain-wide delegation
is the master key, and it must be revoked the day you finish.**

---

## 10. Self-test

1. Why can Gmail labels not migrate faithfully to Exchange folders?
   → ⭐ Labels are many-to-one per message; folders are one-to-one.
2. What is domain-wide delegation, and why is it a security event?
   → ⭐ A service account authorised to impersonate every user in the domain — a master key.
3. Which three OAuth scopes should a mail/calendar/contacts migration need?
   → `gmail.readonly`, `calendar.readonly`, `contacts.readonly`.
4. A migrated Google Doc is 300 bytes. What happened?
   → ⭐ It came across as a `.gdoc` shortcut stub; conversion was not enabled.
5. Why do some Drive files have no migratable owner?
   → ⭐ Drive files belong to a person; the owner left and their My Drive is gone.
6. Content migration fails for a licensed user. First check?
   → ⭐ OneDrive personal site not provisioned — `Request-SPOPersonalSite`.
7. What must happen on the last day of the project, security-wise?
   → ⭐ Revoke the domain-wide delegation and destroy the JSON key.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | the scope list granted, plus one pilot mailbox's folder statistics showing the label collapse |
| `security` | ⭐ delegation grant **and** the dated revocation record |
| `operations` | the Drive inventory: native files, orphans, shared drives |
| `break-fix` | one `unauthorized_client` failure traced to a scope mismatch |
| `architecture-decisions` | ⭐ the written conversion and label-mapping policy, agreed with the customer |
