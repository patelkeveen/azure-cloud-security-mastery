# Computing and Operating Systems

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **One idea unifies this entire topic — and most of offensive security.**
> Underpins [`../linux-and-windows/`](../linux-and-windows/),
> [`../virtualization-and-containers/`](../virtualization-and-containers/), and
> [`../../50-security-operations/defender-for-endpoint/`](../../50-security-operations/defender-for-endpoint/).

---

## 1. ⭐ The one idea

> **A privilege boundary is any place where less-trusted code asks more-trusted code to do something
> on its behalf.**
>
> ⭐ **Every privilege escalation in existence is a boundary that failed to validate the request.**

That sentence covers exploits you have never heard of, in products that do not exist yet. **Learn the
boundaries and you can reason about any of them:**

```
┌─ VM ──────────────── hypervisor          ← VM escape
│  ┌─ kernel ───────── syscall interface   ← ⭐ the classic LPE boundary
│  │  ┌─ process ───── IPC, handles, RPC   ← process-to-process
│  │  │  ┌─ thread ─── shared memory
│  │  │  │  └─ code    sandbox, interpreter, ⭐ the CONTEXT WINDOW
```

⭐ **The bottom row is not a joke.** The context-window boundary in
[`../../60-ai-and-secure-ai/ai-fundamentals/`](../../60-ai-and-secure-ai/ai-fundamentals/) §2 is the
newest member of this list — and it is the only one with **no enforcement mechanism at all**, which
is exactly why AI security is hard.

---

## 2. Rings, user mode, kernel mode

```
Ring 0  KERNEL     ⭐ can do anything: memory, devices, other processes
Ring 3  USER       must ASK, via a syscall
```

**A syscall is the boundary crossing**: user code puts a request in registers and traps into the
kernel. ⭐ **The kernel must now validate everything** — pointers, lengths, permissions — because the
caller is untrusted by definition.

**Why this matters to you concretely:**

| Fact | Consequence |
|---|---|
| ⭐ **A kernel driver runs in ring 0** | A signed-but-vulnerable driver is a **full bypass** — BYOVD |
| EDR hooks syscalls | ⭐ It sees the boundary crossings, which is *why* it can detect behaviour |
| Ring 0 code can lie to ring 3 | Rootkits; and why boot-time integrity exists |

> ⭐ **This is why an orphaned, unused ring-0 driver is a genuine finding, not housekeeping.** It is
> code with full machine authority, loaded by an OS that trusts its signature, maintained by nobody.
> A vulnerability in it is a straight path to kernel — and it does not need to be "running" in any
> sense a task manager would show.

---

## 3. Processes, tokens and the thing people get wrong

**A process is a container for memory + handles + an identity.** ⭐ On Windows the identity is an
**access token**; on Linux it is a **set of uid/gid credentials**.

```
PROCESS
 ├─ virtual address space   ⭐ isolated from other processes BY THE KERNEL
 ├─ handles                 open files, sockets, other processes
 └─ ⭐ TOKEN / credentials  who this process IS for authorisation
```

⭐ **The mistake:** treating memory isolation as a security boundary of the same strength as a user
boundary. **It is not, when the token is the same.**

> **Two processes running as the same user are not meaningfully isolated from each other**, because
> one can open a handle to the other and read its memory. ⭐ **That is the entire mechanism behind
> credential theft from LSASS, browser cookie theft, and token stealing** — no exploit required, just
> a permission the OS was always willing to grant.

**The defensive consequences follow directly, and now they are memorable rather than arbitrary:**

| Control | ⭐ Why it exists |
|---|---|
| **Credential Guard** | Moves secrets **out of a process a same-user attacker can open** |
| **Protected Process Light** | Makes the OS refuse the handle |
| ⭐ **Separate admin accounts** | ⭐ Different token → the isolation becomes real |
| **PAW / SAW** | ⭐ Different *machine* → the strongest version of the same argument |

⭐ **"Don't browse the web from an admin session" is not hygiene advice — it is this paragraph.** The
browser and your admin tooling share a token, so they share a security boundary that does not exist.

---

## 4. Worked example — see the boundaries on a real machine

```powershell
# Which processes run with which identity? Same user = same blast radius.
Get-Process -IncludeUserName -EA SilentlyContinue |
  Group-Object UserName |
  Select-Object Count, Name |
  Sort-Object Count -Descending
```

```
Count Name
----- ----
   94 NT AUTHORITY\SYSTEM          <-- ⭐ ring-3, but the most privileged token
   61 CONTOSO\keveen               <-- ⭐ your browser AND your admin console
   12 NT AUTHORITY\LOCAL SERVICE
    8 NT AUTHORITY\NETWORK SERVICE
```

⭐ **Row two is the finding on almost every workstation.** Everything you run interactively shares one
token, so compromise of any of it is compromise of all of it.

**Now the ring-0 inventory — the boundary with no recovery:**

```powershell
# Kernel-mode drivers: full machine authority. Who still needs these?
Get-CimInstance Win32_SystemDriver |
  Where-Object { $_.State -eq 'Running' -or $_.StartMode -in 'Auto','Boot' } |
  Select-Object Name, State, StartMode, PathName |
  Sort-Object StartMode, Name
```

⭐ **Anything here you cannot name and justify is a ring-0 component you are trusting by accident.**
The correct question is not "is it running" but **"is it loadable"** — `StartMode` matters as much as
`State`. See
[`../../50-security-operations/security-baselines/`](../../50-security-operations/security-baselines/).

**And the syscall boundary as an attacker sees it:**

```powershell
# Can this process open a handle to another with the rights needed to read memory?
# (Read-only demonstration - it opens nothing.)
Get-Process lsass -EA SilentlyContinue |
  Select-Object Name, Id, @{n='ProtectedProcess';e={
      # PPL/protection is why this handle request should FAIL for a same-user caller
      'query with Process Explorer or sysinternals - see break-fix' }}
```

⭐ **The lab is the point here**: attempt the handle open with and without Credential Guard / PPL and
watch the OS refuse. **That refusal is the boundary, made visible.**

---

## 5. Memory, and why "it crashed" is a security event

**Virtual memory** gives each process the illusion of a private address space; the kernel maps it to
physical pages. ⭐ **Corruption of that mapping is the root of an entire vulnerability family:**

| Bug class | What it violates |
|---|---|
| Buffer overflow | ⭐ writes past a boundary the code was supposed to enforce |
| Use-after-free | reads memory that now belongs to something else |
| Type confusion | interprets bytes as the wrong structure |

**The mitigations are all "make the attacker's assumptions false":**

```
DEP / NX      data pages are not executable      → can't run what you wrote
ASLR          addresses are randomised           → can't predict where to jump
CFG / CET     control flow is validated          → can't jump anywhere useful
```

⭐ **So an unexplained crash in a network-facing service is a security event until proven otherwise** —
it is often the same bug an exploit would use, arriving by accident. **"It crashed, we restarted it"
closes a potential intrusion signal as an availability blip**, which is the §7 failure in
[`../troubleshooting-method/`](../troubleshooting-method/) with worse consequences.

---

## 6. What breaks

**Treating same-user processes as isolated.** §3 — ⭐ they are not.

**Browsing from an admin session.** §3 — one token, one boundary.

**Judging drivers by "running" rather than "loadable".** §4 — `StartMode` matters.

**Leaving an orphaned ring-0 driver installed.** §2 — full authority, maintained by nobody.

**Assuming a signed driver is a safe driver.** ⭐ Signature proves origin, not correctness — BYOVD.

**Restarting a crashing service without investigating.** §5.

**Believing memory isolation replaces identity separation.** §3 — the token is the boundary.

**Thinking the boundary list is fixed.** §1 — ⭐ the context window is the newest one, and it has no
enforcement at all.

---

## 7. Customer discovery questions

1. Do administrators use **separate accounts**, and are they used from **separate machines**? *(§3.)*
2. Is **Credential Guard** enabled, and has anyone verified it rather than assumed it?
3. Can you produce a **ring-0 driver inventory**, and is every entry justified? *(§4.)*
4. Are drivers judged on `State` or on ⭐ **`StartMode`**?
5. Is **BYOVD** covered — is there a vulnerable-driver blocklist in force?
6. How are **crashes in network-facing services** triaged — availability or security? *(§5.)*
7. Do you run web browsers in the same session as privileged tooling?

---

## 8. Remember it

**Hook — "A privilege boundary is where less-trusted code asks more-trusted code for a favour."**
Every escalation is a favour granted without checking.

**Analogy — a building with doors of very different quality.** ⭐ **The door between your desk and
your colleague's desk is not a door at all** — same floor, same badge, and either of you can walk to
the other's filing cabinet. **The door to the server room is real.** People spend enormous effort on
the server room door and then run their browser at the desk next to their admin console, **on the
same floor, behind no door**, and are surprised when something walks across. ⭐ **A separate admin
account is a wall; a separate machine is a different building.**

**The one thing:** ⭐ **two processes running as the same user are not isolated from each other.**
Memory separation is enforced by the kernel *against other users*, not against another process with
the same token — one can simply open a handle to the other. This single fact explains LSASS
credential dumping, browser cookie theft, token stealing, Credential Guard, PPL, separate admin
accounts and privileged access workstations. **Six controls, one sentence** — and you can now derive
them instead of memorising them.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Define a privilege boundary in one sentence.
2. List the boundary stack from hardware to code. Which is newest and what is unusual about it?
3. What is a syscall, and why must the kernel distrust its caller?
4. Why is a signed driver not necessarily a safe driver?
5. ⭐ Are two processes running as the same user isolated? Why does the answer matter?
6. Name four controls that exist because of that answer.
7. Why does "don't browse from an admin session" follow from first principles?
8. Which driver property matters more than `State`, and why?
9. Why is an unexplained crash in a network-facing service a security event?
10. What do DEP, ASLR and CFG have in common?

<details>
<summary>Answers</summary>

1. **Any place where less-trusted code asks more-trusted code to act on its behalf** — and every
   escalation is such a boundary failing to validate.
2. **Hypervisor → kernel → process → thread → code sandbox.** ⭐ The newest is the **AI context
   window**, and it has **no enforcement mechanism at all**.
3. The user-to-kernel boundary crossing. The kernel must validate pointers, lengths and permissions
   because ⭐ **the caller is untrusted by definition**.
4. ⭐ A signature proves **origin, not correctness** — hence bring-your-own-vulnerable-driver.
5. ⭐ **No.** One can open a handle to the other and read its memory. It matters because that is
   credential dumping, cookie theft and token stealing — **no exploit required**.
6. **Credential Guard, Protected Process Light, separate admin accounts, PAW/SAW.**
7. Because the browser and the admin tooling ⭐ **share a token**, so they share a boundary that does
   not exist.
8. ⭐ **`StartMode`** — the question is whether it is **loadable**, not whether it is running.
9. Because it is often ⭐ **the same memory-corruption bug an exploit would use**, arriving by
   accident.
10. They all ⭐ **make the attacker's assumptions false** — about executability, about addresses, and
    about control flow.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — the §4 process/token grouping and ring-0 driver inventory on this machine.
  **Runnable right now, no subscription, no licence.**
- **`break-fix/`** ⭐ — attempt a handle open against a protected process with and without Credential
  Guard / PPL, and watch the OS refuse. **The refusal is the boundary made visible, and it is the
  single most instructive thing in this topic.**
- **`security/`** — driver inventory with justification per entry; vulnerable-driver blocklist state;
  admin-account and PAW posture.
- **`operations/`** — monthly driver-baseline diff, cross-referenced to
  [`../../50-security-operations/security-baselines/`](../../50-security-operations/security-baselines/).
- **`architecture-decisions/`** — ADR: separate admin identities and separate admin devices, argued
  from §3 rather than from policy.
- **`customer-use-cases/`** — §7 answered against a real workstation fleet.
