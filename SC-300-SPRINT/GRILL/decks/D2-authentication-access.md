# SC-300 Domain 2 — Authentication & Access Management

> **Exam weight: 25–30% — the LARGEST domain on SC-300.** Covers MFA, authentication methods policy, passwordless (passkeys (FIDO2), WHfB), SSPR, password protection & smart lockout, Conditional Access, Identity Protection risk policies, Azure RBAC / managed identities / Key Vault access, and Global Secure Access.

---

## Unit 2.1 — Secure Microsoft Entra users with multifactor authentication

### Flashcards

- **Q:** What are the three categories of authentication factors in MFA? **A:** Something you **know** (password, security question), something you **possess** (mobile app receiving notification, token device), something you **are** (biometric such as fingerprint or face scan).
- **Q:** Why is password complexity/expiry policy alone insufficient against determined attackers? **A:** Passwords can be obtained via social engineering or poor physical practices (e.g., a sticky note under the keyboard) — features that deter guessing/brute-force don't stop an intruder who already has the valid password; only a second factor does.
- **Q:** Through which offerings can you get Microsoft Entra MFA? **A:** Entra ID P1 or P2 and Microsoft 365 Business support MFA via **security defaults**; even Entra ID Free and standalone Microsoft 365 licenses get MFA for users/admins via security defaults. Granular enforcement needs Conditional Access (**Entra ID P1**).
- **Q:** What deployment strategy does Microsoft recommend for rolling out MFA? **A:** Roll out in **waves** — start with a small pilot group to find setup issues/unsupported apps, then broaden with evaluation each pass — plus a full **communication plan** (Microsoft provides posters/email templates).
- **Q:** How is Microsoft Entra MFA enforced? **A:** With **Conditional Access policies**, which are IF-THEN statements (IF user accesses resource X, THEN require MFA) — e.g., specific cloud app, specific network, specific client app, or new-device registration.
- **Q:** How does the Authenticator app's verification code method work? **A:** It generates an **OATH code that changes every 30 seconds**; works even with limited connectivity; this approach doesn't work in China on Android devices.
- **Q:** Which MFA method is "preferred for backups"? **A:** **Voice call** to phone — the user approves via keypad. Note: voice call isn't available on the free/trial Entra tier.
- **Q:** What are FIDO2 security keys? **A:** An **unphishable, standards-based, passwordless** method in any form factor — typically USB but also Bluetooth or NFC.
- **Q:** Describe Windows Hello for Business as an authentication method. **A:** Replaces passwords with **strong two-factor authentication tied to the device** — a device-bound credential unlocked with a biometric or PIN.
- **Q:** What are the constraints of OATH hardware tokens? **A:** Entra ID supports **OATH-TOTP SHA-1** tokens with **30-second or 60-second** time steps; secret keys are limited to **128 characters** (may not fit all vendors' tokens); tokens come from any vendor.
- **Q:** What is the easiest way to have users register MFA methods? **A:** A **registration campaign** via Microsoft Entra ID Protection (P2): configure it so users are prompted to register for MFA the next time they sign in. Alternatives: prompt at first use of an app requiring MFA, or a CA policy targeting a group containing all users (requires manual group maintenance).
- **Q:** Which methods serve BOTH MFA and SSPR? **A:** Password, WHfB, FIDO2 key, Microsoft Authenticator app, OATH hardware token, OATH software token, text message, voice call. **Security questions and email address are SSPR-only.**
- **Q:** Rules for the security questions method? **A:** SSPR only, available only for **non-administrative accounts**; answers stored privately on the user object (admins can't read/change them); **35 predefined questions** localized by browser locale; custom questions max **200 characters**.
- **Q:** Which single authentication method can never be disabled? **A:** **Password** — it's the only method you can't turn off.
- **Q:** What are app passwords used for? **A:** Certain **non-browser apps that don't support MFA**; they let those apps keep authenticating when per-user MFA is enabled.
- **Q:** Where do you monitor MFA/SSPR adoption? **A:** **Usage & insights** view (Monitoring section) — registration success/failure per method, computed from the **last 30 days** of audit logs from combined registration and SSPR registration.

### Understand-check questions

1. A payroll manager must complete MFA before opening the payroll app. What construct implements this?
   **A:** A Conditional Access policy — IF target resource = payroll app, THEN grant control = Require multifactor authentication.
2. Why should you always enable more than one MFA method?
   **A:** So users have a backup option if their primary method (e.g., lost phone) is unavailable during sign-in.
3. Which two methods can be enabled for SSPR but NOT for MFA?
   **A:** Security questions (non-admin accounts only) and email address.
4. True or false: you must enable per-user MFA for every account in the tenant to protect everyone.
   **A:** False — MFA is enforced at scale with Conditional Access policies rather than per-user enforcement.
5. What data powers the Usage & insights adoption charts?
   **A:** The last 30 days of audit logs from combined security-info registration and SSPR registration experiences.

### Real-world use cases

1. **Manufacturing firm protecting client IP (module scenario):** Confidential electronics designs live in Azure; leaked passwords would expose contracts. Enforcing MFA via CA on the design repositories means a stolen password alone can't sign in — layered defense where the second factor (phone/biometric) stops the intrusion.
2. **Retail chain, phased national rollout:** 40,000 store managers and HQ staff can't all flip on day one. Waves starting with an IT pilot group surface unsupported POS apps early, while Microsoft's communication templates (posters, emails) set expectations about registration dates and help channels — cutting support tickets at each wave.
3. **Law firm reducing lockouts:** Attorneys travel constantly and lose phones. Supporting multiple methods — Authenticator push plus voice call as backup — keeps partners productive; Usage & insights shows which methods register cleanly so IT can retire weak ones (SMS) deliberately.

---

## Unit 2.2 — Manage user authentication

### Flashcards

- **Q:** Which capabilities make up Entra's authentication story beyond username/password? **A:** SSPR, MFA, hybrid integration writing password changes back on-premises (writeback), hybrid password protection for on-prem AD DS, passwordless authentication, and Entra authentication to Azure VMs.
- **Q:** Which sign-in events are considered most secure? **A:** Passwordless methods — **Windows Hello for Business, passkeys (FIDO2 security keys), and Microsoft Authenticator app**. Microsoft also recommends enabling **combined security information registration** (one flow registers both MFA + SSPR) and requiring users register multiple methods for resiliency.
- **Q:** Which methods can be PRIMARY vs SECONDARY factors? **A:** Primary: WHfB, FIDO2 key, password; Authenticator app (passwordless, preview) and SMS (preview). Secondary only: **OATH hardware tokens, OATH software tokens, voice call** (MFA + SSPR). Security questions and email address are secondary for SSPR only.
- **Q:** OATH token specifics for Entra ID? **A:** Supports **OATH TOTP** (Time-based One-Time Password) open standard; **OATH HOTP is NOT supported**. Software tokens = Authenticator/third-party apps; Entra generates the secret key (seed) input into the app. Users may hold up to **five** OATH hardware tokens/authenticator apps.
- **Q:** Key facts about passkeys (FIDO2)? **A:** FIDO (Fast IDentity Online) Alliance open specification; FIDO2 incorporates **WebAuthn**; keys are unphishable, any form factor (USB/Bluetooth/NFC); work for Entra joined/hybrid joined Windows 10/11 devices and supported browsers; great where employees can't/won't use phones as a factor.
- **Q:** How do you enable the FIDO2 security key method? **A:** Entra admin center → **Protection → Authentication methods → Policies → FIDO2 Security Key**: Enable Yes/No, Target All users or Select users, Save.
- **Q:** What must exist before a user adds a FIDO2 key in My Security Info? **A:** The user must already have **at least one MFA method registered** (myprofile.microsoft.com → Security Info → Add method → Security key; then set key PIN + gesture and name the key).
- **Q:** Platform prerequisites for FIDO2? **A:** Browser sign-in on **Windows 10 version 1903+** or Windows 11; cloud-only WHfB-style deployment baseline is **Windows 10 1511+**; Intune optional; Premium optional for automatic MDM enrollment.
- **Q:** What is a Temporary Access Pass (TAP)? **A:** A standard Entra feature: a **time-limited passcode** issued by admins to onboard users onto passwordless credentials (WHfB/passkeys/Authenticator) without knowing their password; can be configured single-use — ideal for new hires and recovery.
- **Q:** Certificate-based authentication (CBA) in one line? **A:** Direct-to-Entra passwordless authentication using **X.509 client certificates** validated against CAs trusted in the tenant — modernizes smart-card scenarios without AD FS.
- **Q:** How does WHfB represent its credential? **A:** A certificate or **asymmetric key pair bound to the device**; the IdP (AD, Entra ID, or Microsoft account) maps the **public key** to the account at registration; the gesture unlocks local signing — the private key never leaves the device when TPM is used.
- **Q:** WHfB privacy/TPM facts? **A:** Keys generated in hardware (**TPM 1.2 or 2.0 enterprise; TPM 2.0 consumer**) or software per policy; PIN never stored/shared; biometric templates stay local; gesture doesn't roam; personal + corporate keys share one container but are separated per IdP domain. **Pluton** goes further — a security processor built into the CPU (AMD/Intel/Qualcomm collaboration, technology from Azure Sphere/Xbox) that first emulates a TPM.
- **Q:** Which groups matter for hybrid WHfB deployment? **A:** **KeyCredential Admins** (granted read/write on the msDS-KeyCredentialLink attribute for Entra Connect sync) — skip it if WS2016 DCs exist because the first 2016 DC creates **KeyAdmins**; and **Windows Hello for Business Users** for phased GPO/certificate-template rollout.
- **Q:** SSPR licensing? **A:** Cloud-only users: Entra ID **Premium P1/P2** or Microsoft 365 Business **Standard**. On-premises users (with writeback): Entra ID Premium P1/P2 or Microsoft 365 Business **Premium**.
- **Q:** How is SSPR enabled, and what portals do users hit? **A:** Admin: Entra admin center → **Protection → Password reset → Properties → Selected group**. Users register at **aka.ms/ssprsetup** and reset at **aka.ms/sspr**.
- **Q:** How does Microsoft Entra Password Protection work on-premises? **A:** Global + custom banned-password lists evaluated by a DC Agent; proxy service brokers downloads from Entra (DCs never touch the internet directly). Defaults start in **audit mode** (blocked passwords logged, not blocked) then switch to **enforce**. Validates only at **set/change** time — pre-existing passwords keep working until rotated ("password never expires" accounts exempt). Requires DFSR sysvol, .NET on agents, restarts on install; **never co-install the Password Protection proxy with Application Proxy**; RODCs need no agent and can't host the proxy; ~**two proxies** give HA via round-robin with cached policy.
- **Q:** Smart lockout defaults and mechanics? **A:** Always on for all tenants: locks sign-ins for **one minute after 10 failed attempts**, growing after each subsequent failure (growth rate undisclosed); tracks the **last three bad-password hashes** so repeating one wrong password doesn't compound; familiar vs unfamiliar locations have separate counters; each datacenter tracks independently (effective attempts ≈ threshold × datacenter count). Customizing values requires **Premium P1**.
- **Q:** Hybrid smart-lockout tuning rule? **A:** With pass-through auth: set **AD DS threshold ≥ 2–3× the Entra threshold** (e.g., Entra 5 → AD 10) and make the **Entra duration LONGER than the AD duration** (e.g., Entra 120 seconds vs AD 60 seconds) so attacks die in the cloud before locking on-prem accounts.
- **Q:** How does Kerberos SSO work for on-prem IWA apps via Application Proxy? **A:** Entra pre-authenticates and issues a token; the Connector extracts UPN + SPN over a secure channel, performs **Kerberos Constrained Delegation (KCD)** impersonating the user to fetch a Kerberos ticket from AD, then delivers it to the app. Prereqs: IWA-enabled apps, correct SPNs, domain-joined connector server, connector permission to read **TokenGroupsGlobalAndUniversal**.

### Understand-check questions

1. Why can't an OATH hardware token ever be the primary sign-in credential?
   **A:** By design OATH hardware/software tokens are secondary factors only — they verify an already-authenticated identity during MFA or SSPR; primary factors are things like password, FIDO2 key, WHfB.
2. You enable Password Protection in enforce mode today. Does the CFO's current weak password get rejected?
   **A:** No — validation happens only on password change/set operations; existing passwords continue working until each user next changes theirs (unless "password never expires" is set).
3. In a PTA deployment your AD lockout threshold is 10. What Entra smart-lockout threshold protects on-prem accounts?
   **A:** Around 3–5 (AD threshold must be at least 2–3× greater than Entra's), with the Entra lockout duration set longer than the AD duration.
4. A new hire must set up a FIDO2 key day one without a phone. Name a compliant path.
   **A:** Issue a Temporary Access Pass, use it to satisfy sign-in/first MFA-method requirement, then register the passkey (FIDO2) at aka.ms/mysecurityinfo (myprofile.microsoft.com → Security Info).
5. Which license unlocks the CUSTOM banned-password list for users synced from AD?
   **A:** Microsoft Entra ID Premium P1 or P2 (the global banned list works for cloud-only users even on Free).

### Real-world use cases

1. **Factory floor staff with no corporate phones:** Workers share terminals and can't receive SMS. Enable passkeys (FIDO2) in Authentication methods policies, issue USB/NFC badges as keys — unphishable primary sign-in with SSO to cloud and on-prem resources.
2. **SaaS company drowning in password-reset tickets:** 30% of helpdesk volume is resets. Roll out SSPR to a pilot security group first, validate notifications/customization, then expand; pairing SSPR with MFA methods means one combined registration flow covers both.
3. **Municipal government replacing smart cards:** Legacy AD FS smart-card auth is costly. Move to Entra CBA (map issuing CA certificates) for phishing-resistant sign-in, and WHfB on managed endpoints for everyday unlock.
4. **Credential-stuffing wave against a university:** Attackers spray common passwords. Smart lockout throttles them (default 10 failures/1 minute, three bad-hash memory), while Password Protection blocks the sprayed dictionary patterns at set/change time.

---

## Unit 2.3 — Plan, implement, and administer Conditional Access

### Flashcards

- **Q:** What do security defaults enforce? **A:** Preconfigured protections Microsoft manages: all users must **register MFA** (Authenticator), administrators perform MFA **every sign-in**, **legacy authentication protocols are blocked**, users get MFA when necessary, privileged activities like Azure portal access are protected.
- **Q:** Availability and management of security defaults? **A:** Free for everyone; tenants created **on/after October 22, 2019** may have them enabled automatically; toggle at Entra ID → Overview → Properties → **Manage security defaults** (minimum role: Conditional Access Administrator). Not appropriate once orgs adopt premium licenses/complex CA needs.
- **Q:** How does security-defaults MFA registration behave, and what thwarts MFA fatigue attacks? **A:** Registration is required immediately — **no grace period** — and prompts use **number matching** (type the number shown on screen into Authenticator).
- **Q:** Define legacy authentication and why it's dangerous. **A:** Requests from clients that don't use modern auth (OAuth 2.0) — e.g., Office 2010 clients — or mail protocols **IMAP, SMTP, POP3** (and Exchange ActiveSync basic auth). Most compromising sign-in attempts use legacy protocols, which **can't perform MFA**, so attackers bypass MFA policies with them.
- **Q:** Anatomy of a Conditional Access policy? **A:** IF **Assignments** (Users/Groups incl. directory roles & guest types; **Target resources** — cloud apps or User actions; **Conditions** — risk, platform, location, client apps, device state) THEN **Access controls** (**Grant** and/or **Session**).
- **Q:** If NO assignment matches and NO CA policy applies, what happens to the access token? **A:** It is **issued by default** — CA is default-allow. Excluding Group 1 from an "IF Group 1 THEN MFA" policy does NOT block others; you'd need a separate policy to block everyone else.
- **Q:** Multiple grant controls selected — how are they combined? **A:** **AND by default** (all required). Tick **"Require one of the selected controls"** to switch to OR logic.
- **Q:** How does Block interact with other controls? **A:** **Block wins** — it overrides all other assignments/grants and can lock an entire organization out of the tenant if misconfigured.
- **Q:** Recommended safe-rollout toolkit? **A:** Create **two or more emergency access (break-glass) accounts**; deploy new policies in **Report-only** first, validate in **sign-in logs**, simulate with the **What If** tool; phase from test users → expanding groups (always excluding some admins) → all users.
- **Q:** What are named locations and a classic use? **A:** Admin-defined **IP ranges or countries/regions** (optionally include unknown areas, optionally mark trusted). Classic: create a named location of countries you never expect sign-ins from and BLOCK it for all apps — exempting administrators.
- **Q:** Which license enables sign-in/user-risk conditions in CA, and where do you assign risk policies? **A:** **Entra ID Premium P2**. Assign a given risk policy in ONE place — Conditional Access **or** Identity Protection, not both.
- **Q:** How do you restrict MFA/SSPR registration to trusted networks? **A:** CA policy → Target resources → **User actions → Register security information**; Conditions: Locations include Any, exclude All trusted locations; Grant: Block access (a block policy — anything included is blocked unless excluded). Device state (hybrid joined/compliant) can substitute for location. Always exclude break-glass accounts.
- **Q:** What signals back "Require device to be marked as compliant," and gotchas? **A:** Intune compliance (PIN, encryption, OS version, jailbreak/root status) flows to Entra. This control does **not block Intune enrollment**. On iOS/Android/macOS/some browsers, users must select the Entra-provisioned **client certificate** at first browser sign-in.
- **Q:** BYOD scenario: allow email only through Outlook mobile? **A:** Grant **Require approved client app** (+ app protection policy) targeting Exchange Online/SharePoint Online, conditions Device platforms Android/iOS and Client apps Mobile apps & desktop clients / Modern auth (+ a separate EAS policy); back it with Intune **app protection policies (MAM)** — including **MAM-WE** for unenrolled personal devices.
- **Q:** Default sign-in frequency and behavior? **A:** A **rolling window of 90 days** before reauthentication; applies to OAuth2/OIDC apps (Office web, Teams, Azure portal…) and SAML apps that return to Entra; also triggers MFA re-challenge; unlocking/signing into an Entra joined/registered device satisfies it. Session control alternative: **persistent browser session** — default shows the "Stay signed in?" prompt on personal devices.
- **Q:** What do Terms of Use add to CA? **A:** Identity Governance-hosted **PDF terms** users must accept via a CA grant control; consents can expire or be revised forcing re-attestation.
- **Q:** What is Continuous Access Evaluation (CAE)? **A:** Two-way conversation between Entra and CAE-capable services so critical events enforce in **near real time**: user termination/password change/reset revokes sessions, network-location-change enforces location policies. Flow: service returns **401 + claim challenge**, client re-presents refresh token, Entra re-evaluates. Default access-token lifetime otherwise is one hour.
- **Q:** What is the Conditional Access Optimization agent? **A:** A Security Copilot-powered agent (needs **Entra ID P1** + Security Compute Units; activated by Security Administrator; device controls need Intune) that finds coverage gaps and suggests one-click fixes: extend **Require MFA** to uncovered users, enforce device-based controls, **block legacy authentication**, **block device code flow**, and consolidate overlapping policies.

### Understand-check questions

1. Policy: IF user in Group1 THEN require MFA (App1). A user NOT in Group1 opens App1. Result?
   **A:** Token issued normally — the assignment didn't match, and CA is default-allow. To restrict App1 to Group1, add a separate policy blocking all users except Group1.
2. Your policy selects Grant controls [Require MFA] AND [Require compliant device], and a user passes only MFA. Outcome?
   **A:** Denied — selected grant controls combine with AND unless "Require one of the selected controls" (OR) is checked.
3. A user reports "you can't access this app" — fastest way to find the culprit policy?
   **A:** Entra sign-in logs → locate event (filter by user/correlation ID/Conditional Access failure) → Conditional Access tab → click Policy Name for details (left side = collected signals, right side = whether requirements were satisfied); Troubleshooting and support tab gives the plain-language reason.
4. Which portal hosts session-level filtering like blocking download/print in risky sessions?
   **A:** **Conditional Access App Control** (reverse-proxy via Microsoft Defender for Cloud Apps) — session policies can block download/cut/copy/print, label files on download, prevent unlabeled uploads, monitor sessions, and block custom activities like sensitive Teams messages.
5. Order of operations for launching a high-blast-radius policy safely?
   **A:** Exclude break-glass accounts → Report-only → review sign-in log impact → pilot small group → expand while keeping admin exclusions → all users only after thorough testing (keep at least one unaffected admin).
6. Which two configurations should you NEVER ship (documented anti-patterns)?
   **A:** For all users/all cloud apps: Block access; and broad requirements like hybrid-joined-device or app-protection-policy for everyone — each risks total tenant lockout.

### Real-world use cases

1. **Financial services firm killing legacy attack surface:** SIEM shows constant IMAP password-spray. Security defaults (or a CA policy blocking legacy authentication for all users, excluding break-glass) closes the MFA bypass that IMAP/POP3/SMTP basic auth represents.
2. **Consulting agency with contractor BYOD:** Data must stay inside managed containers on personal phones. CA grants Require approved client app + app protection policy for Exchange/SharePoint with MAM-WE — corporate data gets PIN/container controls without enrolling personal devices.
3. **Payroll processing company (module example):** Only payroll managers touch the payroll app, and only from offices. Named location for office IPs + CA policy: IF payroll app AND outside trusted location THEN require MFA + compliant device; report-only first, then phased enablement.
4. **Global retailer geo-blocking:** Sign-in attempts from countries with zero customers. Countries named location + Block for all cloud apps (admins excluded) shrinks the attack map overnight.

---

## Unit 2.4 — Manage Microsoft Entra Identity Protection

### Flashcards

- **Q:** Three key tasks of Identity Protection? **A:** **Automate detection and remediation** of identity-based risks, **investigate** risks with portal data, and **export** risk-detection data (Graph APIs/SIEM) for further analysis.
- **Q:** License and scale of Identity Protection? **A:** Requires **Microsoft Entra ID Premium P2**; Microsoft analyzes **~6.5 trillion signals per day** across Entra ID, Microsoft accounts, and Xbox telemetry.
- **Q:** Name the core risk detections. **A:** Anonymous IP address, Atypical travel, Malicious IP address, Unfamiliar sign-in properties, Leaked credentials, Password spray, Microsoft Entra threat intelligence, Anomalous token, Token issuer anomaly, Suspicious browser, Verified threat actor IP.
- **Q:** Which detections arrive via Microsoft Defender for Cloud Apps (MDCA)? **A:** New country, Activity from anonymous IP address, Suspicious inbox forwarding.
- **Q:** Role permissions in Identity Protection? **A:** **Security Administrator** — full access (password reset handled through user admin rights elsewhere); **Security Operator** — view reports, dismiss user risk, confirm compromised/safe; cannot configure policies; **Security Reader** — view reports only; **Global Reader** — view. Conditional Access Administrators can build policies factoring sign-in risk.
- **Q:** What do Free/P1 tenants see vs P2? **A:** Free/P1: risky-users/sign-ins reports show **only medium/high risk, no details drawer or history**; no risk policies, no weekly digest/at-risk alerts, **no MFA registration policy**. P2: full reports, both risk policies, notifications, MFA registration policy.
- **Q:** Sign-in risk vs user risk — definitions? **A:** **Sign-in risk** = probability the authentication request isn't from the legitimate identity owner (analyzes the sign-in itself). **User risk** = probability the whole account is compromised (atypical risk events for that user).
- **Q:** Microsoft's recommended risk-policy configurations? **A:** **User risk policy: threshold High → Allow access but Require password change**; **Sign-in risk policy: Medium and above → Allow access but Require multifactor authentication**. High thresholds minimize interruptions; lower thresholds trade friction for earlier blocking.
- **Q:** Prerequisite for self-remediation to work? **A:** Affected users must already be registered for **both MFA and SSPR** (enable the combined security information registration experience); exclusions (break-glass) apply to risk policies too, and trusted network locations reduce false positives.
- **Q:** Anything configurable in the MFA registration policy's Controls? **A:** No — the sole control, **Require Microsoft Entra multifactor authentication registration**, is fixed; you choose assignments/exclusions and toggle Enforce on/off.
- **Q:** Report windows and export limits? **A:** **Risky sign-ins: past 30 days; Risk detections: past 90 days**; CSV/JSON downloads capped at the **most recent 2,500 entries** (risky users/sign-ins) and **5,000 records** (risk detections); Graph APIs (riskDetection, riskyUsers, signIn) for everything else.
- **Q:** Actions available on a risky user? **A:** Reset password, Confirm user compromised, Dismiss user risk, Block user from signing in — plus investigate in Microsoft Defender for Identity.
- **Q:** Remediation options and the dismiss caveat? **A:** Self-remediation via risk policy (MFA challenge or secure password change closes detections); manual password reset (temporary password you communicate vs "require user to reset" — latter needs MFA+SSPR registration); dismiss user risk (closes events but does NOT secure the identity); manually close individual detections. Some detections close automatically as **"Closed (system)" / "AI confirmed sign-in safe."**
- **Q:** Unblock paths differ how? **A:** **User-risk block:** reset password, dismiss/close risk detections, exclude from policy, disable policy. **Sign-in-risk block:** try a familiar location/device, exclude user, disable policy.
- **Q:** Graph APIs for risk data? **A:** **riskDetection** (user + sign-in linked detections; filter `detectionTimingType eq 'offline'` for offline ones), **riskyUsers** (risky users; e.g., `riskDetail eq 'userPassedMFADrivenByRiskBasedPolicy'`), **signIn** (sign-ins with risk state/detail/level).
- **Q:** Workload identity protection essentials? **A:** Extends risk detection to service principals/apps (they **can't do MFA**, often lack lifecycle, store secrets). Needs **P2** + Security admin/operator/reader. Detections are offline: Entra threat intelligence, Suspicious sign-ins (learns baseline over **2–60 days**), Unusual addition of credentials to OAuth app (via MDCA), Leaked credentials, Admin confirmed compromise. CA for workload identities targets **single-tenant service principals registered in your tenant** — third-party/multi-tenant SaaS and managed identities are out of scope.
- **Q:** What is Microsoft Defender for Identity? **A:** Cloud-based solution (formerly Azure Advanced Threat Protection) using on-prem AD signals to detect advanced threats/compromised identities; components: **Microsoft Defender portal (security.microsoft.com)**, sensors installed directly on **domain controllers and AD FS** servers, and a cloud service (US/Europe/Asia) tied to Microsoft threat intel.
- **Q:** What is the Identity Risk Management agent? **A:** An LLM-based agent in ID Protection (needs **P2** + SCUs; activated/viewable-actionable by Security Administrator; Readers view only) that investigates risky users, produces findings/risk summaries, suggests remediation (**Dismiss risk / Reset password**), supports chat with memory. Triggers: continuous monitoring every **5 minutes**, daily, or manual; default scope = most recent **100 risky users within last 90 days**.

### Understand-check questions

1. Admin clicks Dismiss user risk on a phished account instead of resetting the password. Why is the identity still unsafe?
   **A:** Dismiss only closes the risk state/reports — the compromised password remains valid, so the attacker retains usable credentials; remediation requires a password change/self-remediation.
2. Which report covers the longest window and what's its download cap?
   **A:** Risk detections — 90 days, downloadable up to 5,000 records (CSV/JSON).
3. A risky-sign-in policy challenged a user who passed MFA. What Graph query surfaces that outcome?
   **A:** `GET /identityProtection/riskyUsers?$filter=riskDetail eq 'userPassedMFADrivenByRiskBasedPolicy'` — useful for spotting false positives.
4. Why do workload identities need different protection than users?
   **A:** They can't perform MFA, usually lack lifecycle governance, and must store credentials/secrets somewhere — raising compromise risk; hence offline detections + CA for single-tenant service principals.
5. Where do Defender for Identity sensors install, and why no dedicated servers?
   **A:** Directly on domain controllers and AD FS servers — the sensor monitors traffic locally without port mirroring or dedicated capture boxes.
6. Your SOC wants automated nightly triage of risky users with summaries. Which capability fits, and what must be licensed?
   **A:** The Identity Risk Management agent — Entra ID P2 plus available Security Compute Units, activated by a Security Administrator (daily trigger or manual run).

### Real-world use cases

1. **E-commerce company hit by breach-feed dumps:** Leaked-credentials detections flag hundreds of accounts. The user risk policy (High → require password change) lets registered users self-remediate within minutes — no helpdesk queue — while admins audit outcomes in the risky-users report.
2. **Sales team globetrotters triggering atypical travel:** VPN hopping causes false positives. Configure trusted named locations so Identity Protection suppresses noise, keep sign-in risk at Medium+, and teach users that a familiar-location sign-in clears sign-in-risk blocks.
3. **Fintech SOC automating response:** Risk events stream via Graph (riskDetection/riskyUsers/signIn) into Sentinel; playbooks auto-confirm compromises and reset passwords, closing detections fast — because "time matters when working with risk."
4. **ISV with leaked app secrets on GitHub:** Workload identity protection flags leaked credentials/unusual SP sign-ins (after its 2–60-day baseline), and a CA policy for the single-tenant service principal blocks access while risk is active.

---

## Unit 2.5 — Implement access management for Azure resources

### Flashcards

- **Q:** What is Azure RBAC? **A:** The **authorization system for Azure resources**: to grant access you assign a role to a **user, group, service principal, or managed identity** at a particular **scope**.
- **Q:** The four scope levels, most→least broad? **A:** **Management group → Subscription → Resource group → Resource** — parent-child hierarchy; lower levels inherit permissions assigned higher.
- **Q:** Scope inheritance example from the module? **A:** Reader assigned at management-group scope can read everything in all subscriptions under it; Billing Reader at subscription scope reads billing for every RG/resource below; Contributor on a resource-group scope manages resources only inside that RG.
- **Q:** Distinguish Owner, Contributor, Reader, User Access Administrator. **A:** **Owner** — full access including granting access; **Contributor** — create/manage all resource types but **cannot grant access**; **Reader** — view everything; **User Access Administrator** — assigns access to Azure resources.
- **Q:** Assignment-count limits? **A:** Up to **4,000 role assignments per subscription** (across subscription/RG/resource scopes) and **500 per management group**.
- **Q:** Where in the portal do assignments happen? **A:** The **Access control (IAM)** page — available on users, groups, resource groups, subscriptions, and resources; assignable via portal, PowerShell (`New-AzRoleAssignment`), CLI (`az role assignment create`), SDKs, REST.
- **Q:** Custom Azure roles — storage and limits? **A:** Stored in **Microsoft Entra ID** and shareable across subscriptions; up to **5,000 custom roles per directory**; assignable like built-ins (MG in preview, subscription, resource group); defined via JSON `actions/notActions/dataActions/notDataActions`, `assignableScopes`, wildcard `*` allowed at any level.
- **Q:** Why prefer managed identities for apps? **A:** They provide an **automatically managed Entra identity** — apps obtain Entra tokens **without managing any credentials**; credentials aren't accessible to you; works with any resource supporting Entra auth; **no extra cost**.
- **Q:** System-assigned vs user-assigned managed identity? **A:** **System-assigned:** created in Entra, tied 1:1 to the Azure resource's lifecycle (auto-deleted with the resource; only that resource can use it). **User-assigned:** standalone Azure resource, assigned to one or more service instances, managed separately from them.
- **Q:** How do you give a managed identity access to a storage account? **A:** On the **target** resource → Access control (IAM) → Add role assignment → pick least-privilege role → assignee = the managed identity → Review + assign.
- **Q:** Default user permissions differences worth knowing? **A:** Members can enumerate users/contacts, create security/M365 groups, register applications, invite guests; guests get slightly less (e.g., restricted directory reads). **User settings** can restrict registering apps, Azure portal access, LinkedIn connections, external-collab settings; roles add permissions back per least privilege.
- **Q:** Two ways to authorize Key Vault data operations? **A:** **Azure RBAC** (recommended; scopes MG/sub/RG/vault; unified management; separate permissions per keys/secrets/certs) or legacy **access policies** (per-vault; max **1024 entries** — assign to groups; slightly granular but harder to manage). Recommendation: **one vault per app per environment**.
- **Q:** Map Key Vault built-in roles. **A:** **Administrator** — all data-plane ops, can't manage vault resource/role assignments; **Certificates Officer / Crypto Officer / Secrets Officer** — full actions on respective object type except permissions; **Crypto Service Encryption User** — wrap/unwrap; **Crypto User** — cryptographic operations; **Secrets User** — read secret contents; **Reader** — metadata only, cannot read secret values/key material.
- **Q:** Retrieve a secret via CLI/PowerShell? **A:** `az keyvault secret show --name <secret> --vault-name <vault> --query value`; PowerShell: `Get-AzKeyVaultSecret -VaultName <vault> -Name <secret> -AsPlainText`. Portal: open secret → Show secret value.
- **Q:** What is Microsoft Entra Permissions Management? **A:** A CIEM capability to **gather, review, and restrict** permissions assigned across multi-cloud solutions (module capstone topic alongside RBAC/MI/Key Vault).
- **Q:** Core principle repeated throughout the module? **A:** **Least privilege** — grant security principals only the permissions needed; limiting roles and scopes limits blast radius if an identity is compromised.

### Understand-check questions

1. Team needs to manage VMs in one RG but never touch IAM. Which built-in role?
   **A:** Contributor (scoped to that resource group) — full management of resources there, but cannot grant access.
2. You delete an App Service that had a system-assigned identity used to read Key Vault. Cleanup needed?
   **A:** The identity is deleted automatically by Azure with the resource; any role assignments referencing it become orphaned/stale and should be reviewed.
3. Which Key Vault role can read a secret's VALUE, and which can't even see contents?
   **A:** Secrets User (read secret contents) vs Reader (metadata of vaults/secrets/keys only — no sensitive values or key material).
4. Why does the module recommend groups for Key Vault access policies?
   **A:** The 1024-entry-per-vault limit — assigning to groups scales far better than per-user entries and simplifies management.
5. Where do custom roles live and how widely can they be used?
   **A:** In Microsoft Entra ID (the directory) — shared across subscriptions, with up to 5,000 per directory and explicit `assignableScopes`.
6. An app in a VM must write blobs daily. Least-privilege pattern end to end?
   **A:** System-assigned (or user-assigned) managed identity on the VM + least-privilege role (e.g., Storage Blob Data Contributor) on just the target storage account — zero stored credentials.

### Real-world use cases

1. **Media startup with rotating dev teams:** Instead of sharing connection strings, every Function App gets a system-assigned managed identity; a role assignment on the single storage account grants blob write only. Credentials vanish from code, and deleting the app cleans up automatically.
2. **Enterprise finance department needs billing visibility:** Assign Billing Reader to the finance group at subscription scope — they read cost data across every RG without gaining resource control; least privilege preserved via group-based inheritance.
3. **Bank segregating secret custody:** Per-app/per-environment vaults with Entra RBAC: Crypto Officer for the payments team, Secrets User for the API runtime identity, Reader for auditors — nobody holds vault-wide Administrator, and role assignments are governed centrally.

---

## Unit 2.6 — Deploy and configure Microsoft Entra Global Secure Access

### Flashcards

- **Q:** What is Microsoft's SSE solution? **A:** **Global Secure Access** = **Microsoft Entra Internet Access + Microsoft Entra Private Access** — an identity-aware, cloud-delivered perimeter merging network, identity, and endpoint controls on Zero Trust principles (least privilege, explicit verification, assume breach), delivered from Microsoft's WAN edge locations.
- **Q:** What does Microsoft Entra Internet Access secure? **A:** Access to Microsoft services, SaaS, and public internet via the **Secure Web Gateway (SWG)**; key features: **compliant network checks preventing stolen-token replay**, **universal tenant restrictions** against exfiltration, enriched logs, web content-category/domain filtering, universal CA for internet destinations.
- **Q:** What does Microsoft Entra Private Access provide? **A:** VPN-less Zero Trust access to **private resources — any port, protocol, IP/FQDN** — building on Application Proxy across hybrid/multicloud/datacenters, with **per-app adaptive access** via Conditional Access.
- **Q:** Licensing and admin role for Global Secure Access? **A:** Entra ID **P1 or P2** plus **Microsoft Entra Internet Access and/or Private Access licenses**; configure in entra.microsoft.com with the **Global Secure Access Administrator** role (tenant restrictions setup also uses Security Administrator).
- **Q:** What are traffic forwarding profiles, and what does the Microsoft profile route? **A:** Toggles defining which traffic Global Secure Access acquires: **Microsoft**, **Private**, **Internet**. Microsoft profile captures **Exchange Online; SharePoint Online/OneDrive; Entra ID + Microsoft Graph** traffic by FQDN/IP subnets, creating matching network-routing policies.
- **Q:** How is the Global Secure Access client deployed? **A:** Windows client (downloaded from Entra admin center → Connect → Client download) installed manually or via **Intune**; Android client via Intune or Defender for Endpoint; connected state shown by a green icon after Entra sign-in.
- **Q:** Tenant restrictions v2 — what and where? **A:** Cross-tenant access settings (Identity → External Identities → Cross-tenant access settings → Organizational settings) allowing/blocking external tenants; enforced via **Session management → Tenant restrictions → Enable tagging** in Global Secure Access. Provides **authentication-plane** blocking of unsanctioned external identities AND **data-plane** protection — replayed external tokens trigger mismatch, reauth, and block (anonymous SharePoint access blocked too).
- **Q:** What must be enabled before compliant-network/source-IP features work in CA? **A:** **Adaptive access signaling**: Global Secure Access → Global settings → Session management → Adaptive access → *Enable Global Secure Access signaling* (CAE signaling auto-enables for Office 365 preview). Then a **named location "All Compliant Network locations" (type: Network Access)** appears — optionally marked trusted.
- **Q:** Which services enforce compliant-network at the DATA plane (CAE/token-theft-replay)? **A:** Currently **Exchange Online and SharePoint Online**; authentication-plane enforcement applies at user authentication time generally.
- **Q:** Typical compliant-network CA policy shape? **A:** Assignments: All users (exclude break-glass) → Target: **select specific apps** (Exchange Online, SharePoint Online, SaaS) — the umbrella **"Office 365" cloud app is NOT supported** → Conditions: Location include Any, exclude **All Compliant Network locations** → Grant: **Block access**.
- **Q:** Private Access deployment building blocks? **A:** (1) **Private network connector(s)** — lightweight outbound agents on **Windows Server 2012 R2+** (.NET 4.7.1+, TLS 1.2; outbound 80/443), grouped for HA; (2) **Quick Access app** with application segments; (3) enable the **Private Access traffic forwarding profile**; (4) install the client.
- **Q:** Quick Access application segments accept which destination types? **A:** IP address, FQDN (including wildcard FQDNs — NetBIOS NOT supported), CIDR ranges, IP-to-IP ranges, each with ports. Common ports: **22 SSH, 80 HTTP, 443 HTTPS, 445 SMB, 3389 RDP**. Users/groups are assigned to the Quick Access app.
- **Q:** What are remote networks? **A:** Branch-office connectivity: an **IPsec tunnel between the customer premises equipment (CPE) router and nearest Global Secure Access endpoint** (IKE negotiation both sides) — five steps: Basics, Connectivity, Traffic forwarding, Review configuration, then **configure the on-premises router** (skipping that step leaves IPsec incomplete).
- **Q:** Dashboard/alert widgets worth citing? **A:** Snapshot (users/devices/workloads seen in last **24 hours**), Alerts: **Unhealthy remote network, Increased external tenants activity, Token and device inconsistency, Web content blocked**; usage profiling/top destinations; cross-tenant access (incl. unseen tenants vs previous 7 days); web category filtering; device status (active/inactive).
- **Q:** Log types and retention in Global Secure Access? **A:** **Audit logs** (categories like forwarding profiles, remote networks; retention varies by Entra license); **Traffic logs** structured as **Session → Connection → Transaction** (retained **30 days**); **Enriched Office 365 logs** (improved latency/accurate IPs; routed via Diagnostic settings category `EnrichedOffice365AuditLogs` to Log Analytics/storage/event hub/partner); Office logs kept only **24 hours**.
- **Q:** Source IP restoration — purpose and limits? **A:** Preserves the **original user source IP** toward resources despite the cloud proxy, so IP-based CA/location policies, Identity Protection scoring, and sign-in logs keep working; enabled automatically with Global Secure Access signaling; currently for **Microsoft traffic** (SharePoint, Exchange, Teams, Graph); when on, you see the user IP but not the GSA service IP.

### Understand-check questions

1. Sales rep opens customer CRM from a coffee shop. Which component applies and why (module scenario)?
   **A:** Microsoft Entra Private Access — the client tunnels traffic over Microsoft's network, identity is verified, and per-app Conditional Access applies Zero Trust without exposing data to the public internet or a legacy VPN.
2. An attacker steals a user's session token and replays it off-network. Which stack defeats this?
   **A:** Compliant-network check in Conditional Access (Internet Access signaling) — with CAE data-plane enforcement on Exchange/SharePoint Online, the token fails the network check and reauthentication is forced.
3. Why does the compliant-network walkthrough tell you NOT to target the "Office 365" app picker entry?
   **A:** The umbrella Office 365 cloud app is currently not supported for this pattern — select individual workloads (e.g., Office 365 Exchange Online, Office 365 SharePoint Online) or your SaaS apps instead.
4. Remote network created, but branch users still aren't tunneled. Likely miss?
   **A:** The final step — configuring the on-premises router/CPE with the Microsoft-side connectivity details; IKE/IPsec is bidirectional and won't establish until both ends are set.
5. Which exclusion list applies to Global Secure Access-era CA policies too?
   **A:** Break-glass/emergency access accounts and non-interactive service accounts/service principals (e.g., the Entra Connect Sync Account) — programmatic identities can't satisfy interactive controls.

### Real-world use cases

1. **Distributed consultancy retiring its VPN appliance:** Engineers reach RDP (3389), SMB file shares, and internal web apps via Quick Access segments and the Private Access profile — per-app CA replaces flat-network VPN, connectors give HA, and no client-side config beyond the Global Secure Access agent.
2. **SaaS vendor stopping token theft and shadow tenants:** Universal tenant restrictions block contractors signing into unsanctioned tenants (auth plane), while data-plane tagging catches pasted foreign tokens; the cross-tenant dashboard widget surfaces "increased external tenants activity" alerts for follow-up.
3. **Retail branch network without per-device agents:** 300 stores connect CPE routers as remote networks (IPsec to nearest edge), assigning the Internet Access forwarding profile — web category filtering and SWG inspection apply to all store traffic with zero device installs.
4. **Healthcare org proving compliance in audits:** Enriched Office 365 logs streamed to Log Analytics document latency and true source IPs, while traffic logs (session/connection/transaction, 30-day retention) evidence exactly who reached what resource and from where.

---

## Exam traps

1. **Grant-control logic:** Multiple selected grant controls combine with **AND by default**; only ticking "Require **one** of the selected controls" switches to OR. Expect a question where the user satisfies one of two controls — default answer: access denied.
2. **Block wins:** A Block grant overrides every other assignment/control; a misconfigured all-users/all-apps Block (or blanket hybrid-join/app-protection requirement) locks the whole tenant out — the documented anti-pattern set.
3. **Default-allow ≠ exclusion-blocks:** With no matching assignment/policy, the access token IS issued. Excluding users from an "IF Group1 THEN MFA" policy merely leaves them untouched — it does NOT deny them; denial requires a separate block policy.
4. **Exclusion scope discipline:** Emergency/break-glass accounts (two or more) belong in EVERY policy's exclude list; exclude service accounts/service principals (e.g., Entra Connect Sync Account) because MFA can't be completed programmatically — and remember calls made by **service principals aren't blocked by Conditional Access at all**.
5. **License gating:** Conditional Access = Entra ID **P1**; risk-based conditions, Identity Protection policies, workload identity protection, MFA-registration policy = **P2**; smart-lockout customization = P1; custom banned-password list = P1/P2 (global list free for cloud-only); security defaults free — and mutually exclusive with a mature CA strategy.
6. **Method capability corners:** Security questions (non-admin only) and email address are **SSR-only**; password is the one method you **cannot disable**; OATH hardware/software tokens and voice call are **secondary-factor only**; passkeys (FIDO2)/WHfB/Authenticator(passwordless)/SMS are primary-capable.
7. **Smart-lockout numbers & inversion:** Lock = 1 minute after **10 failed attempts**; last **three** bad-password hashes don't increment counters; counters are **per datacenter** (≈ threshold × datacenter count) with separate familiar/unfamiliar tallies. For PTA hybrids, AD DS threshold must be 2–3× Entra's while the **Entra duration stays LONGER** than AD's (seconds vs minutes units!).
8. **Password protection persistence:** Validates ONLY on password set/change — existing passwords survive deployment until rotation; "password never expires" accounts are exempt; audit mode is the default start; DC agent needs **DFSR**, restarts on install; **never co-install the Password Protection proxy with Application Proxy**; RODCs host neither agent config nor proxy.
9. **Risk-policy placement & thresholds:** Assign each risk policy in ONE place — Conditional Access **or** Identity Protection, never both. Recommendations look inverted: **user risk = High threshold + require password change**, **sign-in risk = Medium-and-above + require MFA**. Self-remediation silently fails for users lacking prior MFA+SSPR registration, and "Dismiss user risk" does NOT secure a compromised identity.
