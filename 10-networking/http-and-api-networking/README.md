# HTTP and API Networking

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> The protocol every identity flow rides on. Direct prerequisite for
> [Layer 1](../../30-identity-and-nhi/oauth-oidc-saml-and-api-auth/LAYER-1-IDENTITY-PROTOCOLS.md) —
> OAuth, OIDC and Graph are all just HTTP.

---

## 1. What it is

A request/response protocol: a method, a path, headers, an optional body — and a response with a
status code, headers and a body. Stateless by design; every request carries everything needed to
process it.

**That statelessness is why bearer tokens exist**, and why stealing one is sufficient to impersonate
the caller. There is no session on the server to invalidate.

---

## 2. Why an identity engineer needs this

Every authentication problem you will debug is an HTTP problem underneath:

- A token is an `Authorization: Bearer` header
- A consent prompt is a `302` redirect chain
- A Graph failure is a status code plus a body you must read
- Throttling is `429` with a `Retry-After` header
- A CORS failure looks exactly like an auth failure and is not

> **The people who debug identity fastest are the ones who read the raw HTTP** instead of the SDK's
> exception message. The SDK tells you it failed; the response body tells you why.

---

## 3. How it works underneath

### Status codes — read them precisely

| Code | Meaning | In identity work |
|---|---|---|
| `200` / `201` | OK / Created | |
| `204` | No content | Successful DELETE or PATCH in Graph |
| **`301` / `302`** | Redirect | ⭐ The OAuth authorize dance |
| `304` | Not modified | Caching |
| **`400`** | Bad request | Malformed — **read the body**, Entra explains itself |
| **`401`** | **Unauthenticated** | No token, expired, or bad signature → **get a new token** |
| **`403`** | **Authorized but forbidden** | Token is valid; **the scope or role is missing** |
| `404` | Not found | Or hidden by permissions |
| **`429`** | **Throttled** | ⭐ Honour `Retry-After` |
| `500` / `503` | Server-side | Retry with backoff |

> ⭐ **401 versus 403 is the most useful distinction in API debugging.**
> **401 = who are you** — the token is missing, expired, or invalid. Refresh it.
> **403 = I know who you are and you may not** — the token is fine; the **permission** is wrong.
> Refreshing a token to fix a 403 is the single most common wasted hour in Graph development.

### Headers that carry the identity story

```http
GET /v1.0/users/priya@contoso.com HTTP/1.1
Host: graph.microsoft.com
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIs...
Accept: application/json
ConsistencyLevel: eventual          ← required for advanced Graph queries
client-request-id: 6f3a...          ← YOUR correlation id
```

Response headers worth capturing when something fails:

```http
HTTP/1.1 403 Forbidden
request-id: 8c1e2f44-...            ← ⭐ give this to Microsoft support
client-request-id: 6f3a...
Retry-After: 32                     ← on 429, wait exactly this long
WWW-Authenticate: Bearer error="insufficient_claims", claims="..."
```

**`WWW-Authenticate` on a 401/403 often names the exact problem** — including a Conditional Access
claims challenge, which tells you the API is demanding step-up authentication rather than rejecting
the identity.

---

## 4. Worked example — reading a real response

```powershell
$r = Invoke-WebRequest -Uri 'https://learn.microsoft.com' -Method Head -UseBasicParsing
$r.StatusCode
$r.Headers.GetEnumerator() | Where-Object Key -in 'Content-Type','Strict-Transport-Security','X-Content-Type-Options' |
  ForEach-Object { "{0,-28} {1}" -f $_.Key, ($_.Value -join '; ') }
```

**Capture the full exchange when something fails** — this is the habit worth building:

```powershell
try {
  Invoke-RestMethod -Uri 'https://graph.microsoft.com/v1.0/users' `
    -Headers @{ Authorization = "Bearer $token" } -ErrorAction Stop
}
catch {
  $resp = $_.Exception.Response
  "Status : $([int]$resp.StatusCode) $($resp.StatusCode)"
  "request-id : $($resp.Headers['request-id'])"
  $reader = [IO.StreamReader]::new($resp.GetResponseStream())
  "Body   : $($reader.ReadToEnd())"
}
```

A real Graph permission failure looks like this — and it tells you exactly what to fix:

```
Status : 403 Forbidden
request-id : 8c1e2f44-9b0a-4d31-8e77-2c5a1f0b3d92
Body   : {"error":{"code":"Authorization_RequestDenied",
          "message":"Insufficient privileges to complete the operation."}}
```

**`Authorization_RequestDenied` means the permission is missing or unconsented** — not that the
token is bad. Check the token's `scp` (delegated) or `roles` (application) claim against what the
endpoint requires. See
[`../../30-identity-and-nhi/service-principals/`](../../30-identity-and-nhi/service-principals/).

**Handle throttling properly** — `429` is normal at scale, not an error:

```powershell
do {
  try { $result = Invoke-RestMethod @params; $done = $true }
  catch {
    if ([int]$_.Exception.Response.StatusCode -eq 429) {
      $wait = [int]($_.Exception.Response.Headers['Retry-After'] ?? 10)
      Start-Sleep -Seconds $wait          # honour the server, do not invent a backoff
    } else { throw }
  }
} until ($done)
```

---

## 5. CORS — why it looks like an auth failure and is not

CORS is a **browser** restriction. It does not exist for server-to-server calls, and it is not a
security control on the API.

```
Browser at https://app.contoso.com  →  https://api.contoso.com
      │
      ├─ preflight:  OPTIONS /resource
      │              Origin: https://app.contoso.com
      │              Access-Control-Request-Method: POST
      │
      └─ server must reply:
                     Access-Control-Allow-Origin: https://app.contoso.com
                     Access-Control-Allow-Headers: authorization, content-type
```

⭐ **The single most common CORS bug in identity work:** the server allows the origin but **not the
`authorization` header**. The preflight passes, the real request is blocked, and the browser
console reports it in a way that looks like the token was rejected. It never left the browser.

**`Access-Control-Allow-Origin: *` cannot be combined with credentials.** Wildcarding it to "fix"
the problem silently breaks authenticated requests.

---

## 6. HTTP/2, HTTP/3 and what changes

| | HTTP/1.1 | HTTP/2 | HTTP/3 |
|---|---|---|---|
| Transport | TCP | TCP | **QUIC over UDP 443** |
| Multiplexing | ✗ (one at a time per connection) | ✅ | ✅ |
| Head-of-line blocking | Yes | At TCP layer | **Eliminated** |
| Header compression | ✗ | HPACK | QPACK |

**Operational consequence:** HTTP/3 runs over **UDP 443**. Firewalls that permit only TCP 443
silently force clients to fall back — usually invisibly, sometimes after a delay that presents as
"the site is slow." Worth checking when a modern application is inexplicably sluggish through a
corporate proxy.

---

## 7. What breaks

**Treating 403 as 401.** Refreshing tokens forever against a permissions problem.

**Ignoring `Retry-After`.** Aggressive retries make throttling worse; some services extend the
penalty.

**Not logging `request-id`.** Microsoft support cannot investigate without it. Capture it on every
failure.

**Assuming CORS is server-to-server.** It is a browser rule only.

**Not reading the response body.** Entra and Graph return specific, actionable error codes and
people discard them by catching only the status.

**Missing `ConsistencyLevel: eventual`** on advanced Graph queries (`$count`, `$search`, some
`$filter`), producing a confusing 400.

**Proxy stripping the `Authorization` header.** Some corporate proxies do this on redirect. The API
sees no token and returns 401, and the client swears it sent one.

---

## 8. Customer discovery questions

1. Do applications log `request-id` and `client-request-id` on failures?
2. Is throttling handled with `Retry-After`, or a hand-rolled backoff?
3. Do any corporate proxies strip or rewrite `Authorization` headers?
4. Is HTTP/3 (UDP 443) permitted, or forced to fall back?
5. Are security headers (HSTS, CSP, `X-Content-Type-Options`) set on public endpoints?
6. Any wildcard CORS origins in production?
7. Are TLS inspection proxies breaking certificate pinning for API clients?

---

## 9. Remember it

**Hook — "401 = who?  403 = no."**

**Analogy — a guest list.** 401: you showed no ID, or it expired — go and get a valid one. 403: your
ID is perfect and **you are not on the list** — a new ID will never help. Refreshing tokens against
a 403 is the most common wasted hour in Graph development.

**The one thing:** **read the response body.** Entra and Graph name the exact problem —
`Authorization_RequestDenied` means the permission is missing, not the token. And capture
`request-id`; support cannot investigate without it.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 10. Self-test

1. 401 versus 403 — meaning, and the correct response to each?
2. Which header do you give Microsoft support, and where does it come from?
3. Correct handling of a 429?
4. Preflight succeeds, real request blocked. Most likely CORS cause?
5. Why can `Access-Control-Allow-Origin: *` break authenticated calls?
6. Which transport does HTTP/3 use, and what firewall issue follows?
7. Graph returns 400 on a `$count` query. What is probably missing?
8. Where does Graph tell you *why* a 403 happened?

<details>
<summary>Answers</summary>

1. **401** = unauthenticated — token missing, expired or invalid → get a new token. **403** =
   authenticated but **not permitted** → fix the scope/role/consent. A new token will not help.
2. **`request-id`** from the response headers.
3. Wait exactly the number of seconds in **`Retry-After`**, then retry. Do not invent a backoff.
4. The server did not allow the **`authorization` header** in `Access-Control-Allow-Headers`.
5. The wildcard origin **cannot be used with credentials**, so authenticated requests are rejected.
6. **QUIC over UDP 443.** Firewalls permitting only TCP 443 cause a silent fallback.
7. **`ConsistencyLevel: eventual`.**
8. In the **response body** — e.g. `Authorization_RequestDenied` — which is discarded if you only
   read the status code.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — call Graph with a deliberately under-scoped token and capture the full 403 body and
  `request-id`; then with the correct scope and compare.
- **`break-fix/`** — trigger a 429 and implement `Retry-After` handling; reproduce the CORS
  `authorization` header failure in a browser.
- **`security/`** — security header review of public endpoints; CORS origin inventory; confirmation
  that no proxy strips `Authorization`.
- **`operations/`** — logging standard requiring `request-id` capture on every API failure.
- **`architecture-decisions/`** — ADR: retry and throttling policy for Graph-dependent automation.
