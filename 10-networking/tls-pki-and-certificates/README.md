# TLS, PKI and Certificates

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Live handshake captured **2026-08-10** — §4 is real output.
> The other thing that breaks by itself. Underpins AD FS token signing, LDAPS, mTLS and every
> OAuth token signature.

---

## 1. What it is

**TLS** encrypts and authenticates a connection. **PKI** is the trust system that makes the
authentication meaningful: a hierarchy of certificate authorities where a root you already trust
vouches for an intermediate, which vouches for the server.

A certificate binds a **public key** to an **identity**, signed by a CA. That is all it is.

---

## 2. Why it exists

Encryption alone is worthless without identity. An attacker in the middle can encrypt perfectly —
to themselves. TLS solves both at once, and the *authentication* half is the part that fails.

**Why this belongs in an identity repository:** every token you have studied is protected by this
machinery. AD FS token-signing certificates ([`../../35-active-directory-and-hybrid-identity/adfs-and-federation/`](../../35-active-directory-and-hybrid-identity/adfs-and-federation/)),
JWT signatures validated against JWKS, LDAPS, client certificates for CBA. Certificate expiry has
caused more identity outages than any attacker.

---

## 3. How it works underneath

**TLS 1.3 handshake** — one round trip, and it dropped everything negotiable that was dangerous:

```
Client ── ClientHello ─────────────►    supported ciphers, key share, SNI (in the clear)
       ◄─ ServerHello ──────────────    chosen cipher, key share
       ◄─ Certificate, Finished ────    encrypted from here on
Client ── Finished ────────────────►
                    application data
```

**TLS 1.2 needs two round trips** and permits RSA key exchange (no forward secrecy), CBC modes, and
renegotiation. **TLS 1.3 removed all of it**: only AEAD ciphers, forward secrecy always.

**SNI is sent in cleartext.** The hostname you are visiting is visible to anyone on the path, even
under TLS 1.3. This is how firewalls do domain filtering without decryption — and why "we use HTTPS
so nobody knows where we go" is false.

### Chain validation — what the client actually checks

```
   Leaf (learn.microsoft.com)
        │  signed by
   Intermediate CA
        │  signed by
   Root CA  ──────────► must already be in the client's trust store
```

Every one of these must pass:

1. **Signature chain** valid to a trusted root
2. **Not expired** — `NotBefore` ≤ now ≤ `NotAfter`
3. **Name matches** — the hostname is in the **SAN**. ⭐ Common Name is ignored by modern clients.
4. **Not revoked** — CRL or OCSP
5. **Key usage** permits this purpose

> **Servers must send the intermediates; the client only has roots.** ⭐ A server that sends only
> the leaf works in a browser (which caches intermediates from previous sites) and **fails from
> `curl`, PowerShell and containers**. Classic symptom: *"it works in Chrome but the API call
> fails."* Nothing is wrong with the API.

---

## 4. Worked example — a real handshake, dissected

✅ Actual output, captured 2026-08-10:

```
Protocol      : Tls13
Cipher        : TLS_AES_256_GCM_SHA384
Subject       : CN=learn.microsoft.com, O=Microsoft Corporation, L=Redmond, S=WA, C=US
Issuer        : CN=Microsoft TLS G2 ECC CA OCSP 02, O=Microsoft Corporation, C=US
NotAfter      : 12/11/2026 07:56:09
Chain depth   : 4
  - CN=learn.microsoft.com
  - CN=Microsoft TLS G2 ECC CA OCSP 02
  - CN=Microsoft TLS ECC Root G2
  - CN=DigiCert Global Root G3
```

Run it yourself — no OpenSSL required:

```powershell
$c=[Net.Sockets.TcpClient]::new('learn.microsoft.com',443)
$s=[Net.Security.SslStream]::new($c.GetStream(),$false,({$true}))
$s.AuthenticateAsClient('learn.microsoft.com')
"Protocol: $($s.SslProtocol)  Cipher: $($s.NegotiatedCipherSuite)"
$rc=[Security.Cryptography.X509Certificates.X509Certificate2]$s.RemoteCertificate
$ch=[Security.Cryptography.X509Certificates.X509Chain]::new(); $null=$ch.Build($rc)
$ch.ChainElements | ForEach-Object { $_.Certificate.Subject.Split(',')[0] }
$s.Dispose(); $c.Close()
```

**How to read that output like an engineer:**

- **`Tls13`** — good. If you see `Tls11` or lower, that is a finding.
- **`TLS_AES_256_GCM_SHA384`** — AEAD, forward secrecy. A cipher containing `CBC` or `RC4` is a finding.
- **Chain depth 4** — leaf → issuing CA → Microsoft root → **cross-signed to DigiCert Global Root
  G3**. That last hop exists so older clients that do not carry the Microsoft root still validate.
  This is how CAs migrate roots without breaking the world.
- **`NotAfter`** — put it in a calendar with an owner.

**Check the SAN**, which is what actually has to match:

```powershell
$rc.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Subject Alternative Name' } |
  ForEach-Object { $_.Format($true) }
```

**Expiry sweep** — the report that prevents outages:

```powershell
Get-ChildItem Cert:\LocalMachine\My |
  Select-Object Subject, NotAfter, Thumbprint,
    @{n='DaysLeft'; e={ [int]($_.NotAfter - (Get-Date)).TotalDays }} |
  Where-Object DaysLeft -lt 90 | Sort-Object DaysLeft
```

---

## 5. Certificate types, and choosing correctly

| Type | Use | Note |
|---|---|---|
| **Public CA** | Anything internet-facing | Must be publicly trusted |
| **Private/internal CA (AD CS)** | Internal services, LDAPS, mTLS | Root must be distributed to every client — via GPO or Intune |
| **Self-signed** | Lab only | ⚠ In production it means trust verification was disabled somewhere |
| **Wildcard** `*.contoso.com` | Many subdomains | ⭐ One private key on many servers — **compromise anywhere is compromise everywhere** |
| **SAN / multi-domain** | Several explicit names | Safer than wildcard; rotate per-name |
| **Client certificate** | mTLS, CBA | The client proves identity too |

**Lifetimes have collapsed and this is the operational story of the decade.** Public TLS
certificates are down to ~1 year or less and continuing to shorten. ⚠ Check the current maximum
before designing a renewal process — this number keeps moving.

**The consequence is not "renew more often" — it is "manual renewal has stopped being viable."**
Automate with ACME, Key Vault with auto-rotation, or cert-manager. An estate still renewing by
calendar reminder will have an outage; it is only a question of which service.

---

## 6. Revocation — the part that quietly fails

| Mechanism | How | Problem |
|---|---|---|
| **CRL** | Download the whole revocation list | Large; cached; slow to reflect reality |
| **OCSP** | Ask the CA about one certificate | ⭐ **Privacy leak** — the CA learns what you visit; adds latency |
| **OCSP stapling** | Server presents a signed, timestamped OCSP response | The right answer. Fixes both problems. |

**Soft-fail is the default almost everywhere.** If the revocation endpoint is unreachable, most
clients **proceed anyway**. So an attacker who can block OCSP can use a revoked certificate. This is
why revocation is considered weak, and why short lifetimes are the actual mitigation.

⭐ **In locked-down networks, the CRL/OCSP URL is frequently blocked by the proxy.** Symptom: TLS
handshakes take 10–20 seconds, then succeed. Nobody suspects certificates — they blame the
application. Look for a revocation check timing out.

---

## 7. What breaks

**Expiry.** The most predictable outage in computing. §4's sweep plus a calendar owner prevents it.

**Missing intermediates.** Works in browsers, fails from code. See §3.

**Name not in SAN.** Modern clients ignore CN entirely. A certificate "for" a name that lacks it in
the SAN fails everywhere.

**Internal root not distributed.** Works on domain-joined Windows via GPO, fails on Linux
containers, mobile devices and anything unmanaged — which is a growing share of every estate.

**TLS inspection breaking pinning.** Corporate interception re-signs traffic with the proxy's CA.
Applications that pin certificates — and many mobile and agent applications do — break with errors
that do not mention interception.

**Clock skew.** A wrong clock makes valid certificates appear expired or not yet valid. Same root
cause as the Kerberos 5-minute rule.

**Wildcard sprawl.** One key on thirty servers. When one is compromised, every name must be
re-issued at once.

---

## 8. Customer discovery questions

1. Is there a **certificate inventory** with expiry dates and named owners? *(Usually no — that is
   the finding.)*
2. Is renewal **automated**? What happens when the owner is on leave?
3. Minimum TLS version enforced, and is anything still on 1.0/1.1?
4. Are **wildcards** in use? On how many hosts does the private key live?
5. Is the internal CA root distributed to **non-Windows** and unmanaged devices?
6. Is **OCSP stapling** enabled? Are revocation endpoints reachable through the proxy?
7. Is TLS inspection in place, and what breaks because of it?
8. Where do AD FS token-signing certificates sit in this process? *(Links to the annual outage in
   [`../../35-active-directory-and-hybrid-identity/adfs-and-federation/`](../../35-active-directory-and-hybrid-identity/adfs-and-federation/) §5.)*

---

## 9. Remember it

**Hook — "Browsers forgive, `curl` does not."**

**Analogy — a chain of introductions.** You do not know the server, but you know the root CA, who
vouches for an intermediate, who vouches for the server. **The server must hand you the middle
introductions** — the client only carries roots. Browsers quietly reuse intermediates cached from
other sites, which is why a misconfigured server works in Chrome and fails from code.

**The one thing:** the hostname must be in the **SAN**; Common Name is ignored entirely by modern
clients. And handshakes that take 15 seconds then succeed are a **revocation check timing out**.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 10. Self-test

1. Works in Chrome, fails from `curl`. Most likely cause?
2. Which field must contain the hostname — CN or SAN?
3. Why is TLS 1.3 stronger by design rather than by configuration?
4. Is SNI encrypted? What does that mean for privacy claims?
5. Why is revocation considered weak?
6. Handshakes take 15 seconds then succeed. What would you check?
7. What is the real risk of a wildcard certificate?
8. Why does chain depth 4 end at a DigiCert root for a Microsoft site?
9. Certificate is valid, but a client says expired. Non-certificate cause?

<details>
<summary>Answers</summary>

1. **Missing intermediate certificates.** Browsers cache them from other sites; command-line clients
   and containers do not.
2. **SAN.** Modern clients ignore Common Name entirely.
3. It **removed** the dangerous options — no RSA key exchange, no CBC, no renegotiation. Only AEAD
   with forward secrecy. There is no insecure configuration to choose.
4. **No, SNI is cleartext.** The hostname is visible on the path, which is how domain filtering
   works without decryption.
5. **Soft-fail.** If the revocation endpoint is unreachable, clients usually proceed. Blocking OCSP
   re-enables a revoked certificate.
6. A **revocation check timing out** — CRL/OCSP URL blocked by the proxy.
7. One private key deployed across many servers: **compromise anywhere is compromise everywhere**,
   and remediation means re-issuing every name at once.
8. **Cross-signing.** Clients that do not carry the newer Microsoft root can still chain to a
   long-established DigiCert root.
9. **Clock skew** on the client.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — capture the §4 handshake against three sites and compare protocol, cipher and chain
  depth; extract and read a SAN.
- **`break-fix/`** — deliberately serve a certificate without its intermediate; prove it works in a
  browser and fails from `curl`. Then block the OCSP URL and time the handshake.
- **`security/`** — the §4 expiry sweep across all servers; TLS version and cipher audit; wildcard
  key locations enumerated.
- **`operations/`** — certificate inventory with owners and automated renewal, including **AD FS
  token-signing**.
- **`architecture-decisions/`** — ADR: public versus internal CA, and wildcard versus SAN.
