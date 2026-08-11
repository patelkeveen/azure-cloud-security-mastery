# Linux and Windows

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> Builds on [`../computing-and-operating-systems/`](../computing-and-operating-systems/).
> ⭐ **Two authorisation philosophies, and knowing which one you are in tells you where to look.**

---

## 1. ⭐ The difference that explains everything else

> **Windows authorises by ACL. Linux authorises by ownership.**

```
WINDOWS   every object carries a DACL: a LIST of (SID → allowed/denied rights)
          ⭐ arbitrarily many principals, arbitrarily granular

LINUX     every object carries: owner, group, and NINE permission bits
          ⭐ exactly three principals — owner, group, everyone else
```

**Everything downstream follows from that one design choice:**

| | Windows | Linux |
|---|---|---|
| Granularity | ⭐ very high — 14+ distinct rights | ⭐ low by default — r/w/x |
| Who can be granted | any number of SIDs | ⭐ **one user, one group, everyone** |
| Failure mode | ⭐ **sprawl** — nobody knows who has what | ⭐ **over-granting** — `chmod 777` to make it work |
| Where to look | the ACL, and inheritance | ownership, group membership, **sudoers** |

⭐ **So the audit question differs by platform.** On Windows you ask *"who is on the list, and why?"*
On Linux you ask *"who owns it, and who is in that group, and what can they sudo?"* — because the
model has nowhere else to hide the answer.

⚠ Linux does have ACLs (`setfacl`) and capabilities, but ⭐ **they are the exception in practice**,
which is itself the finding: an unusual ACL on Linux is a deliberate act worth reading.

---

## 2. Identity: SIDs versus UIDs

| | Windows | Linux |
|---|---|---|
| Identifier | ⭐ **SID** — globally unique, never reused | ⭐ **UID** — a small integer, **locally scoped** |
| Renaming a user | keeps the SID → ⭐ access follows | keeps the UID → access follows |
| Two machines | different SIDs for the same name | ⭐ **UID 1000 is "the first user" on BOTH** |
| Superuser | `SYSTEM` (S-1-5-18) and Administrators | `root` = **UID 0** |

⭐ **"UID 1000 means different people on different machines" is a real problem**, and it is why NFS
and shared-volume permissions surprise people: **the filesystem stores the number, not the name.**
Mount that volume elsewhere and the number resolves to somebody else.

> ⭐ **SYSTEM and root are not equivalents, and saying so in an interview is a tell.**
> `root` is a *user* (UID 0) with the ability to do anything. `SYSTEM` is a **machine identity** — it
> is how the computer authenticates to the network, as `DOMAIN\MACHINE$`. ⭐ **Compromising SYSTEM on
> a domain-joined host gives you the machine's domain credentials**, which is a network-wide
> consequence with no Linux equivalent. That connects directly to
> [`../../35-active-directory-and-hybrid-identity/ad-ds/`](../../35-active-directory-and-hybrid-identity/ad-ds/).

---

## 3. Worked example — reading permissions on both

**Windows — the ACL, and what to look for:**

```powershell
(Get-Acl C:\IT\azure-cloud-security-mastery).Access |
  Select-Object IdentityReference, FileSystemRights, AccessControlType, IsInherited |
  Format-Table -AutoSize
```

```
IdentityReference       FileSystemRights   AccessControlType  IsInherited
---------------------   ----------------   -----------------  -----------
BUILTIN\Administrators  FullControl        Allow              True
NT AUTHORITY\SYSTEM     FullControl        Allow              True
BUILTIN\Users           ReadAndExecute     Allow              True
CREATOR OWNER           FullControl        Allow              True        <-- ⚠ read §4
```

⭐ **`IsInherited` is the column people skip and the one that matters.** An explicit (non-inherited)
ACE is someone's deliberate act — **that is the row to question.** Inherited ACEs come from the
parent, so fixing them at the leaf is whack-a-mole.

**Linux — ownership and the bits:**

```bash
ls -l /etc/shadow /usr/bin/passwd
```

```
-rw-r-----  1 root shadow  1.9K  /etc/shadow
-rwsr-xr-x  1 root root     59K  /usr/bin/passwd
   ▲
   ⭐ 's' = setuid — this runs AS ROOT no matter who launches it
```

⭐ **`setuid` is the Linux privilege boundary in one character**, and it is exactly the §1 pattern
from [`../computing-and-operating-systems/`](../computing-and-operating-systems/): less-trusted code
asking more-trusted code for a favour. **Every setuid binary is an attack surface, and the list should
be short and known:**

```bash
# Every setuid/setgid binary on the system - the audit that matters
find / -xdev \( -perm -4000 -o -perm -2000 \) -type f -exec ls -l {} \; 2>/dev/null
```

⭐ **Anything on that list you cannot justify is a privilege-escalation candidate.** It is the Linux
equivalent of the ring-0 driver inventory.

---

## 4. ⭐ The two findings that recur everywhere

**Windows: overly broad principals.** These four names are where over-permission hides, because they
read as harmless:

```
Everyone                     ⭐ literally everyone
Authenticated Users          ⭐ every account in the domain, including machines
BUILTIN\Users                every local user
CREATOR OWNER                whoever created it — inherited, so often surprising
```

⭐ **`Authenticated Users` is the one that catches people**, because it *sounds* like a control. It
means **every domain account, including every computer account** — which is why it appears as a
finding in
[`../../35-active-directory-and-hybrid-identity/ad-ds/`](../../35-active-directory-and-hybrid-identity/ad-ds/)
§4, and in SharePoint as *"Everyone except external users"* in
[`../../60-ai-and-secure-ai/sensitive-data-leakage/`](../../60-ai-and-secure-ai/sensitive-data-leakage/) §4.
⭐ **Same finding, three products, three different names** — that recognition is worth more than any
one of them.

**Linux: sudo, and the rules that are not what they look like:**

```bash
sudo -l          # what can THIS user actually do?
grep -rvE '^\s*(#|$)' /etc/sudoers /etc/sudoers.d/ 2>/dev/null
```

```
%devs ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart app     <-- looks scoped
%ops  ALL=(ALL) NOPASSWD: /usr/bin/find                      <-- ⚠⚠ this is root
```

⭐ **The second rule is full root**, because `find` has `-exec`. **A sudo rule is only as narrow as
the binary's own capabilities**, and any binary that can run another command, write arbitrary files,
or spawn an editor is equivalent to `ALL`. ⭐ **`vi`, `less`, `find`, `awk`, `tar`, `git` — all of
them.** The rule *looks* least-privilege and is not, which is the most dangerous shape a control can
have.

---

## 5. Where secrets live

⭐ **Know these paths on both platforms; it is where an attacker goes and where a reviewer should
look:**

| Windows | Linux |
|---|---|
| **DPAPI** (user- or machine-bound) | `~/.ssh/`, ⭐ often mode 600 and often not |
| **Credential Manager** | keyring (gnome-keyring, kwallet) |
| Registry, incl. ⭐ autologon in plaintext | ⭐ **environment variables** — visible in `/proc` |
| ⭐ **LSASS process memory** | `/etc/shadow` (hashes) |
| Group Policy Preferences ⚠ historically | shell history — ⭐ `~/.bash_history` |

⭐ **Environment variables are the cross-platform mistake.** They are inherited by every child
process, they appear in crash dumps and process listings, and on Linux another same-user process can
read them straight from `/proc/<pid>/environ` — which is
[`../computing-and-operating-systems/`](../computing-and-operating-systems/) §3 again. **This is the
first-principles argument for
[`../../30-identity-and-nhi/managed-identities/`](../../30-identity-and-nhi/managed-identities/):
there is no good place to put a secret, so do not have one.**

---

## 6. What breaks

**Auditing ACLs without reading `IsInherited`.** §3 — you fix leaves and miss the source.

**Treating `Authenticated Users` as a restriction.** §4 — ⭐ it is every account in the domain.

**Assuming a scoped sudo rule is scoped.** §4 — ⭐ `find`, `vi`, `awk`, `tar` are all root.

**No setuid inventory.** §3 — the Linux ring-0 equivalent.

**Assuming UIDs mean the same thing across machines.** §2 — the filesystem stores the number.

**Saying SYSTEM ≈ root.** §2 — ⭐ SYSTEM is a *domain* identity; the blast radius is the network.

**Secrets in environment variables.** §5 — inherited, dumped, and readable via `/proc`.

**`chmod 777` to make it work.** ⭐ The Linux failure mode, exactly as ACL sprawl is the Windows one.

**Applying one platform's audit questions to the other.** §1.

---

## 7. Customer discovery questions

1. On Windows: which ACEs are **explicit** rather than inherited, and who added them? *(§3.)*
2. Where does **`Authenticated Users`** or **`Everyone`** appear on anything sensitive? *(§4.)*
3. On Linux: what is on the **setuid** list, and is every entry justified?
4. Show me `/etc/sudoers.d/` — ⭐ **does any rule name a binary with `-exec` or a shell escape?**
5. Are **UIDs** consistent across machines that share storage? *(§2.)*
6. Where do application **secrets** live on each platform, and are any in environment variables?
7. Is **LSASS** protected (Credential Guard / PPL)?

---

## 8. Remember it

**Hook — "Windows lists, Linux owns."** ACL versus ownership, and the audit question follows.

**Analogy — a guest list versus a set of keys.** ⭐ **Windows is a nightclub with a guest list**: any
number of names, each with their own conditions, and the failure is that after ten years nobody knows
why half the names are on it. ⭐ **Linux is a house with three keys** — yours, the family's, and the
one under the mat — and the failure is that when a plumber needs in, somebody puts a key under the
mat and leaves it there. **Sprawl versus over-granting: same problem, opposite shapes.**

**The one thing:** ⭐ **a sudo rule is only as narrow as the binary it names.** `%ops ALL=(ALL)
NOPASSWD: /usr/bin/find` reads as tightly scoped least privilege and is **unrestricted root**,
because `find` has `-exec`. The same is true of `vi`, `less`, `awk`, `tar` and `git`. ⭐ **A control
that looks like least privilege and is not is more dangerous than no control at all**, because it
closes the conversation — and the Windows twin of this is `Authenticated Users`, which sounds like a
restriction and means everybody.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. State the core difference in one sentence, and give each platform's failure mode.
2. What is the audit question on each platform?
3. What does `IsInherited` tell you, and why does it change your action?
4. Which four Windows principals hide over-permission?
5. What does `Authenticated Users` actually include?
6. What is `setuid`, and how does it map to the privilege-boundary definition?
7. ⭐ Why is `NOPASSWD: /usr/bin/find` equivalent to full root? Name three other such binaries.
8. Why are UIDs dangerous across machines?
9. Why is SYSTEM not the equivalent of root?
10. Why are environment variables a poor place for a secret — on both platforms?

<details>
<summary>Answers</summary>

1. ⭐ **Windows authorises by ACL, Linux by ownership.** Windows fails by **sprawl**; Linux fails by
   **over-granting** (`chmod 777`).
2. Windows: **"who is on the list, and why?"** Linux: **"who owns it, who is in that group, and what
   can they sudo?"**
3. That the ACE came from the **parent**. ⭐ An **explicit** ACE was somebody's deliberate act — fix
   inherited ones at the source, not the leaf.
4. **Everyone, Authenticated Users, BUILTIN\Users, CREATOR OWNER.**
5. ⭐ **Every account in the domain, including every computer account.**
6. A bit making a binary run as its **owner** regardless of who launches it — ⭐ exactly *less-trusted
   code asking more-trusted code for a favour*.
7. ⭐ Because `find` has **`-exec`**, so it can run any command as root. Also `vi`, `less`, `awk`,
   `tar`, `git`.
8. ⭐ The filesystem stores the **number, not the name** — UID 1000 resolves to a different person on
   another machine.
9. ⭐ `root` is a local superuser; **SYSTEM is a machine identity** authenticating to the network as
   `DOMAIN\MACHINE$`, so compromise has **network-wide** consequences.
10. They are ⭐ **inherited by every child process**, appear in crash dumps and process listings, and
    on Linux are readable by a same-user process via `/proc/<pid>/environ`.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — the §3 ACL read and setuid sweep. **Runnable now on this laptop and any WSL/VM, no
  subscription needed.**
- **`break-fix/`** ⭐ — write a sudo rule that *looks* scoped (`NOPASSWD: /usr/bin/find`), escalate to
  root through it, then replace it with something genuinely narrow. **The escalation takes one
  command and permanently changes how you read a sudoers file.**
- **`security/`** — explicit-ACE report on sensitive paths; `Everyone`/`Authenticated Users`
  occurrences; setuid inventory with justification; sudoers reviewed for shell-escape binaries;
  secret-location audit.
- **`operations/`** — UID/GID consistency policy for shared storage; secret-handling standard that
  forbids environment variables.
- **`architecture-decisions/`** — ADR: managed identity over stored secrets, argued from §5.
- **`customer-use-cases/`** — §7 answered across a mixed estate.
