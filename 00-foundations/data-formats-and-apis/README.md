# Data Formats and APIs

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Contains the single most useful debugging skill in identity work** — §3.
> Feeds [`../../30-identity-and-nhi/oauth-oidc-saml-and-api-auth/`](../../30-identity-and-nhi/oauth-oidc-saml-and-api-auth/).

---

## 1. What it is

The formats systems exchange, and the contract they exchange them over. **The security relevance is
not the syntax — it is that ⭐ every trust decision in a modern estate is carried in one of these
formats, and most people never open one.**

---

## 2. The formats, and the trap in each

| Format | Used for | ⭐ The trap |
|---|---|---|
| **JSON** | APIs, tokens, ARM | ⭐ **duplicate keys** — parsers disagree on which wins |
| **YAML** | pipelines, Kubernetes | ⭐ **type coercion** — see below |
| **XML** | SAML, older SOAP | ⭐ **XXE**, and signature-wrapping in SAML |
| **JWT** | ⭐ **every access token** | ⭐ **signed, not encrypted** — §3 |
| **CSV** | exports, reports | formula injection (`=cmd|…`) |

⭐ **YAML's type coercion is the one that reaches production:**

```yaml
country:  NO          # ⭐ parses as BOOLEAN false in YAML 1.1
version:  1.10        # ⭐ parses as the NUMBER 1.1
enabled:  yes         # boolean true
port:     022         # may parse as octal
```

⭐ **Quote anything that must stay a string.** `NO` for Norway becoming `false` is the famous one, and
the general lesson is worth more than the anecdote: **a value that changes meaning between the file
and the parser is a config you cannot review by reading.**

> ⭐ **And the general principle behind half of this table: when two parsers disagree about the same
> bytes, that disagreement is a vulnerability class.** HTTP request smuggling, SAML signature
> wrapping and JSON duplicate-key confusion are all one idea — **the security check parsed it one
> way, and the thing acting on it parsed it another.**

---

## 3. ⭐ Read the token — the highest-value skill here

**A JWT is three base64url segments separated by dots.** ⭐ **It is signed, not encrypted — anyone
holding it can read every claim**, and so can you.

```
eyJhbGciOiJSUzI1NiIsImtpZCI6Ii4uLiJ9 . eyJhdWQiOiIuLi4iLCJyb2xlcyI6WyIuLi4iXX0 . <signature>
└────────── header ──────────────────┘ └────────────── payload ──────────────┘
```

```powershell
function Read-Jwt {
    param([Parameter(Mandatory)][string]$Token)
    $p = $Token.Split('.')[1].Replace('-','+').Replace('_','/')
    while ($p.Length % 4) { $p += '=' }          # ⭐ base64URL needs re-padding
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p)) | ConvertFrom-Json
}

Read-Jwt $token | Select-Object aud, appid, roles, scp, oid, tid,
    @{n='issued'; e={[DateTimeOffset]::FromUnixTimeSeconds($_.iat).LocalDateTime}},
    @{n='expires';e={[DateTimeOffset]::FromUnixTimeSeconds($_.exp).LocalDateTime}}
```

⭐ **The claims that answer real questions, and what each one settles:**

| Claim | Question it answers |
|---|---|
| `aud` | ⭐ **Is this token even for the API you're calling?** Most 401s are this |
| ⭐ `scp` vs `roles` | ⭐ **Delegated** (user present, intersection applies) vs **application** (no user, no intersection) |
| `oid` / `sub` | which principal |
| `appid` | which application |
| `iat` / `exp` | ⭐ **is this token older than the policy change?** |
| `amr` | how they authenticated — MFA evidence |

⭐ **`scp` versus `roles` is the single most valuable line in this topic.** It tells you instantly
whether you are looking at a **delegated** permission — bounded by what the signed-in user can do —
or an **application** permission, which has **no such bound**. That distinction drives the whole
finding in
[`../../30-identity-and-nhi/app-registrations/`](../../30-identity-and-nhi/app-registrations/) §3 and
in [`../../60-ai-and-secure-ai/ai-pipeline-nhi/`](../../60-ai-and-secure-ai/ai-pipeline-nhi/) §3, and
**you can settle it in ten seconds instead of reading a consent screen.**

⭐ **And `iat` closes the most common false diagnosis in identity**: *"the policy isn't working."*
Compare `iat` to when the change was made. **A token issued before the change does not know about
it** — [`../troubleshooting-method/`](../troubleshooting-method/) §6.

⚠ **Never paste a real token into an online decoder.** It is a live credential. Decode locally, with
the function above.

---

## 4. HTTP — the parts that decide security outcomes

**Status codes, read as a diagnosis rather than an error:**

| Code | ⭐ What it actually tells you |
|---|---|
| **401** | ⭐ **Authentication** — no token, bad token, wrong `aud`, expired |
| **403** | ⭐ **Authorisation** — the token is fine, the principal lacks the right |
| **429** | Throttled — ⭐ **read `Retry-After`, do not spin** |
| **404** | ⚠ Sometimes a **403 in disguise**, to avoid confirming existence |

⭐ **401 versus 403 halves the search space immediately** — it is exactly the
[`../troubleshooting-method/`](../troubleshooting-method/) §2 principle handed to you for free by the
protocol. **401 → look at the token. 403 → look at the role assignment.** People routinely spend an
hour on the wrong one.

**Idempotency, and why it is a security property:**

```
GET     ⭐ safe        no change; safe to retry, safe to log, safe to cache
PUT     idempotent    same result if repeated
DELETE  idempotent    already-gone is still gone
POST    ⭐ NOT         ⭐ a retry may create a SECOND thing
```

⭐ **A retried `POST` is how duplicate role assignments, duplicate users and double payments happen** —
and in a remediation script it is how you get two of something you meant to have one of.
[`../cli-and-scripting/`](../cli-and-scripting/) §3.

**Pagination — the silent-truncation trap:**

```powershell
# ✗ WRONG - the first page only, and it looks like a complete answer
(Invoke-RestMethod -Uri $uri -Headers $h).value

# ✅ RIGHT - follow the continuation
$all = @(); $next = $uri
do {
    $r = Invoke-RestMethod -Uri $next -Headers $h
    $all += $r.value
    $next = $r.'@odata.nextLink'
} while ($next)
"$($all.Count) objects"
```

⭐ **An audit that silently reads page one is worse than no audit**, because it produces a clean
report over 100 of 4,000 objects and nobody can tell. **Always check for a `nextLink`.**

---

## 5. Worked example — diagnosing a 403 in four commands

```powershell
# ① Is it auth or authz? The status code already told you: 403 = authz.
# ② Who does the API think you are, and with what?
Read-Jwt $token | Select-Object aud, appid, oid, scp, roles
```

```
aud   : https://graph.microsoft.com
appid : 8f3c...            <-- the app
oid   : 2b91...            <-- the principal
scp   :                    <-- ⭐ EMPTY
roles : {Sites.Read.All}   <-- ⭐ application permission, no user context
```

```powershell
# ③ So it is an app-only token. Does that principal hold the right the API wants?
Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId <spId> |
  Select-Object ResourceDisplayName, AppRoleId

# ④ And is the failure actually at a DIFFERENT layer? (403 can come from the resource, not Entra)
#    e.g. Azure RBAC on the target, or a network rule returning 403 at the front door.
az role assignment list --assignee <appId> --all -o table
```

⭐ **Step ④ is the one people miss.** A 403 can be issued by Entra (missing app role), by Azure RBAC
(missing data-plane role), **or by a firewall / private endpoint policy** that never let you reach the
resource. **Three different fixes, one status code** — so confirm *which layer* answered before
changing anything.

---

## 6. What breaks

**Never opening the token.** §3 — the answer is usually in `aud` or `scp`/`roles`.

**Pasting a real token into a web decoder.** ⭐ It is a live credential.

**Confusing 401 and 403.** §4 — an hour spent on the wrong half.

**Assuming a 403 came from the identity layer.** §5 — it may be RBAC or the network.

**Retrying a POST.** §4 — duplicates.

**Ignoring pagination.** §4 — ⭐ a clean report over a fraction of the data.

**Spinning on 429 without `Retry-After`.** Makes it worse and looks like an attack.

**Unquoted YAML strings.** §2 — `NO` becomes `false`.

**Trusting that two parsers agree.** §2 — ⭐ the disagreement is the vulnerability.

**Not comparing `iat` to the change time.** §3 — the most common false diagnosis in identity.

---

## 7. Customer discovery questions

1. When an API call fails, does the team distinguish **401 from 403**? *(§4.)*
2. Can someone on the team **decode a token** and read `aud`, `scp` and `roles`? *(§3.)*
3. Do your audit scripts **follow pagination**? *(§4 — ask to see the `nextLink` handling.)*
4. Are **retries** on POST guarded against duplicates?
5. Do you honour **`Retry-After`**?
6. Are pipeline YAML values **quoted** where type matters?
7. When a policy change "doesn't work", is **token age** checked first? *(§3.)*

---

## 8. Remember it

**Hook — "Read the token."** Then: **401 is the token, 403 is the role.**

**Analogy — a boarding pass you never look at.** ⭐ **A JWT is a boarding pass: printed, readable by
anyone holding it, and signed so it cannot be forged.** People argue for an hour about why the gate
rejected them without ever looking at the card that says **which flight, which seat, and what time it
was issued.** `aud` is the flight number. `exp` is the departure time. `scp` versus `roles` is whether
you are a passenger or the crew — and ⭐ **crew do not need a seat assignment**, which is exactly why
an application permission has no intersection with any user's rights.

**The one thing:** ⭐ **`scp` means delegated, `roles` means application — and application permissions
have no upper bound from any user.** A delegated token can only ever do what the signed-in user could
do; an app-only token does what it was granted, full stop. **Ten seconds with a token decoder settles
a question that otherwise takes a meeting**, and it is the same question underneath the findings in
app registrations, agent identity and AI pipeline NHI.

**Runner-up:** ⭐ **check `iat` before believing a policy is broken.** A token issued before the change
does not know about it.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. What are the three parts of a JWT, and is it encrypted?
2. ⭐ What does `scp` mean, what does `roles` mean, and why does the difference matter?
3. Which claim explains most 401s?
4. Which claim settles "the policy isn't working"?
5. Distinguish 401 from 403 in one line each, and say what each tells you to inspect.
6. Name three layers that can return a 403.
7. Which HTTP verb is not idempotent, and what does that cause in a remediation script?
8. What is the pagination failure, and why is it worse than no audit?
9. Give two YAML type-coercion examples.
10. State the general principle linking request smuggling, SAML signature wrapping and JSON duplicate
    keys.

<details>
<summary>Answers</summary>

1. **Header, payload, signature**, base64url-encoded and dot-separated. ⭐ **Signed, not encrypted** —
   anyone holding it can read every claim.
2. ⭐ **`scp` = delegated** (a user is present; the effective permission is the **intersection** of
   user rights and app consent). ⭐ **`roles` = application** (no user, **no intersection**, so no
   upper bound from anyone's rights).
3. **`aud`** — the token is for a different audience than the API being called.
4. **`iat`** — ⭐ a token issued before the change does not reflect it.
5. **401 = authentication → inspect the token.** **403 = authorisation → inspect the role
   assignment.**
6. ⭐ **Entra** (missing app role), **Azure RBAC** (missing data-plane role), and the **network**
   (firewall / private endpoint).
7. ⭐ **POST.** A retry can create a **second** object — duplicate assignments, users or payments.
8. Reading only page one. ⭐ It produces a **clean report over a fraction of the data**, and nobody
   can tell it is incomplete.
9. `NO` → boolean `false`; `1.10` → number `1.1`. (Also `yes` → `true`, `022` → octal.)
10. ⭐ **When two parsers disagree about the same bytes, the disagreement is the vulnerability** — the
    security check read it one way, the acting component read it another.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — decode a real token from your own tenant with the §3 function and read every claim.
  **Runnable now with the M365 licence alone, no Azure subscription.**
- **`break-fix/`** ⭐ — call Graph with a token whose `aud` is wrong and observe the 401; grant the
  wrong permission and observe the 403; then write an audit that reads only page one against a
  >100-object collection and show it under-reporting. **The pagination one is the most valuable
  because the failure is silent.**
- **`security/`** — token-inspection runbook; a list of audit scripts confirmed to follow pagination;
  YAML files reviewed for unquoted type-sensitive values.
- **`operations/`** — retry policy honouring `Retry-After`; POST idempotency keys where the API
  supports them.
- **`architecture-decisions/`** — ADR: delegated permissions preferred; application permissions
  require named justification, argued from §3.
- **`customer-use-cases/`** — §7 answered; a "your audit only read page one" finding written up.
