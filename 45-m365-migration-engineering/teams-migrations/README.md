# Teams Migrations

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Teams is not one thing to migrate. It is four, stored in four places.** Pairs with
> [`../sharepoint-and-onedrive-migrations/`](../sharepoint-and-onedrive-migrations/) and
> [`../tenant-to-tenant/`](../tenant-to-tenant/).

---

## 1. What it is

Moving Teams workloads between tenants, or into Teams from Slack, Google Chat or Skype for
Business. ⭐ **The hard part is that a "team" is a façade over four separate services**, and each
has its own migration path, its own fidelity ceiling, and its own answer to "can this move at all?"

---

## 2. Why it exists — where a Team actually lives

```
        ┌──────────────── A "TEAM" ────────────────┐
        │                                          │
  ⭐ M365 GROUP        SHAREPOINT SITE      ⭐ CHAT SERVICE       EXCHANGE
   (membership,        (Files tab =          (channel posts,      (group
    ownership,          "Documents"           1:1 and group        mailbox,
    the identity)       library)              chats)               calendar)
        │                    │                     │                  │
   ⭐ moves via         moves via            ⭐ ONLY via          moves via
   identity /           SPMT / ShareGate /   Graph import API     mailbox
   cross-tenant sync    cross-tenant move    or 3rd party         migration
```

⭐ **Files are easy — they are just SharePoint.** ⭐ **Messages are the hard part**, because there is
no supported "export chat, import chat" administrative path in the portal at all.

---

## 3. How it works underneath — the import mode that makes messages possible

Graph supports creating a team in a special state where messages can be **backdated**:

```
① CREATE team with  createdDateTime  in the past AND
                    teamCreationMode = "migration"        ⭐ the team is LOCKED
                                                             — no user can post
② IMPORT messages, each with its own historic createdDateTime
   and a `from` identity resolved in the TARGET tenant
③ COMPLETE migration  →  team unlocks, becomes a normal team
④ ADD members         ⭐ only after step ③
```

⭐ **The lock is the point.** A team in migration mode has no members and accepts no live traffic,
so imported history cannot interleave with new messages. **Once you complete the migration, you can
never re-enter the mode** — a second pass means a new team.

⭐ **Ordering trap:** members are added *last*. Every migration that adds members first ends with a
team full of people watching history appear out of order.

---

## 4. Worked example — importing one historic message

**Create the team in migration mode:**

```http
POST https://graph.microsoft.com/v1.0/teams
Content-Type: application/json

{
  "@microsoft.graph.teamCreationMode": "migration",
  "template@odata.bind": "https://graph.microsoft.com/v1.0/teamsTemplates('standard')",
  "displayName": "Finance Operations",
  "description": "Migrated from Slack #finance-ops",
  "createdDateTime": "2019-03-14T09:12:00.000Z"
}
```

```
HTTP/1.1 202 Accepted
Location: /teams('7f1a...c93b')/operations('4d2e...')
```

**Import a message with its original timestamp and author:**

```http
POST /v1.0/teams/7f1a...c93b/channels/19:a3f...@thread.tacv2/messages

{
  "createdDateTime": "2019-04-02T14:23:07.000Z",
  "from": {
    "user": {
      "id": "e6b2c418-77aa-4f3e-9d21-0c8b5a41e772",
      "displayName": "Aisha Khan",
      "userIdentityType": "aadUser"
    }
  },
  "body": { "contentType": "html", "content": "Q1 variance pack is in Files." }
}
```

⭐ **The `from.user.id` must be a real object in the *target* tenant.** This is the whole identity
problem in one field: **you cannot import Aisha's message until Aisha exists in the target
directory.** Identity migration is therefore a hard predecessor to Teams message migration — not a
parallel workstream.

**Complete and unlock:**

```http
POST /v1.0/teams/7f1a...c93b/completeMigration
```

```
HTTP/1.1 204 No Content
```

⚠ `⚠ check` — Graph import supports **standard channels**; support for private and shared channels
has changed over time. Verify the current capability in Graph documentation for the exact channel
types in scope before committing to a fidelity promise.

---

## 5. What survives, and what does not — say this out loud in the pre-sales meeting

| Element | Fidelity |
|---|---|
| Files (Files tab) | ⭐ **high** — it is SharePoint |
| Channel messages | ⭐ medium — imported as **new** messages with historic timestamps |
| Reactions, edits, read state | ⭐ **lost** |
| Threading / replies | partial (⭐ tool-dependent) |
| ⭐ **1:1 and group chats** | ⭐ **the hardest** — usually not migrated, or migrated as an HTML archive |
| Tabs, connectors, apps | ⭐ **reconfigured by hand**, not migrated |
| Meeting recordings | follow OneDrive/SharePoint |
| Private channels | ⭐ separate site collection each — treat as its own item |

⭐ **The sentence that prevents the escalation:** *"Chat history moves as an archive, not as live
chat. Channel conversations move with their original dates but without reactions."* Say it before
the contract, not after the cutover.

---

## 6. Commands

**Inventory before you promise anything:**

```powershell
Connect-MicrosoftTeams
Get-Team | ForEach-Object {
    $ch = Get-TeamChannel -GroupId $_.GroupId
    [pscustomobject]@{
        Team     = $_.DisplayName
        Visibility = $_.Visibility
        Channels = $ch.Count
        Private  = ($ch | Where-Object MembershipType -eq 'Private').Count
        Owners   = (Get-TeamUser -GroupId $_.GroupId -Role Owner).Count
    }
} | Export-Csv .\teams-inventory.csv -NoTypeInformation
```

```
Team                Visibility  Channels  Private  Owners
Finance Operations  Private            7        2       1
All Company         Public             3        0       0
```

⭐ **`Owners: 0` is a finding, not a curiosity.** An ownerless team cannot be managed, and after a
tenant move it cannot be reclaimed without an administrative fix — enumerate and fix these during
discovery.

---

## 7. What breaks

| Symptom / error | Cause | Fix |
|---|---|---|
| `403 Forbidden` on message import | ⭐ team not in migration mode, or migration already completed | you cannot re-enter — create a new team |
| `Invalid value for from.user.id` | ⭐ **author does not exist in the target tenant** | migrate identity first |
| Messages appear with today's date | `createdDateTime` omitted | supply it per message; ⭐ not fixable after import |
| Members see nothing | members added before `completeMigration` | add members **last** |
| Files missing but chat present | ⭐ SharePoint site not migrated | Teams files are a separate workstream |
| Private channel content absent | separate site collection | migrate each explicitly |

---

## 8. Customer discovery questions

1. ⭐ **"Do you need chat history, or channel history? They are different problems."**
2. "How many teams have private channels?"
3. "Which teams have no owner?"
4. "Are there third-party apps or tabs configured, and who set them up?"
5. ⭐ **"Will source and target users have the same UPN?"** — decides how identity mapping works
6. "Is Teams telephony (Phone System / Direct Routing) in scope?" (⭐ a wholly separate project)
7. "Do you have a retention policy applied to Teams chat?"

---

## 9. Remember it

**Hook — `G S C E`: Group, SharePoint, Chat, Exchange.** Four stores, four migrations, one icon.

**Analogy — a restaurant.** The team is the restaurant's *name and staff list* (the M365 group);
the food store is SharePoint; ⭐ **the conversations between waiters are the chat service, and they
were never written down anywhere you can move.** The analogy predicts the fidelity table: you can
move the building and the stock, but **reconstructing yesterday's conversation means writing it out
again by hand** — which is precisely what the import API does, and why reactions do not survive.

**The one line:** ⭐ **Files migrate; messages are re-created with an old date stamp.**

---

## 10. Self-test

1. Where do Teams files actually live?
   → The team's SharePoint site, `Documents` library.
2. Why must a team be created in migration mode before importing messages?
   → ⭐ It locks the team so imported history cannot interleave with live traffic, and it is the
   only state that accepts a historic `createdDateTime`.
3. When are members added?
   → ⭐ After `completeMigration`. Never before.
4. Why is identity migration a predecessor?
   → `from.user.id` must resolve to a real target-tenant object.
5. Name three things that never survive.
   → Reactions, read state, edit history (also: app/tab configuration).
6. A private channel's files are missing. Why?
   → ⭐ Each private channel has its own site collection; it must be migrated separately.
7. Can you re-enter migration mode to fix a bad import?
   → ⭐ No. Create a new team.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | `teams-inventory.csv` plus one successful `completeMigration` response |
| `security` | the permission scope used for import, and its removal afterwards |
| `operations` | the ordering runbook: create → import → complete → add members |
| `break-fix` | one failed import with its Graph error body and the resolution |
| `customer-use-cases` | ⭐ the written fidelity statement given to the customer pre-contract |
