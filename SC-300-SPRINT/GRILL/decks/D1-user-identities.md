# SC-300 Domain 1 — Implement and Manage User Identities

Exam weight: 20–25% of SC-300. Covers initial Microsoft Entra tenant configuration, user/group/device/license management, B2B external identities, and hybrid identity with Microsoft Entra Connect.

## Unit 1.1 — Implement initial configuration of Microsoft Entra ID

### Flashcards

- **Q:** What license is required to use custom company branding on sign-in pages? / **A:** Microsoft Entra ID P1, P2, or Office 365 (for Office 365 apps only).
- **Q:** What are the size limits for the sign-in page background image? / **A:** Max 1920x1080 pixels and max 300,000 bytes (.png or .jpg), anchored center and scaled to viewable space.
- **Q:** Where does the banner logo appear? / **A:** On the sign-in page after the user enters their username, and on the My Apps portal page.
- **Q:** Character limits for Username hint text vs Sign-in page text (company branding)? / **A:** Username hint: max 64 characters (Unicode, no links/code); sign-in page text: max 1,024 characters.
- **Q:** Who becomes the first Global Administrator of a new tenant? / **A:** The person who signs up for (creates) the Microsoft Entra tenant.
- **Q:** What happens when a Global Administrator elevates access via "Access management for Azure resources"? / **A:** They're granted the User Access Administrator Azure role on all subscriptions in that tenant — useful for regaining lost subscription access.
- **Q:** Do Entra roles or Azure roles span both systems by default? / **A:** By default they don't span. Some Entra roles (Global Administrator, User Administrator) also work in Microsoft 365 (Exchange, SharePoint), but Global Admin has no access to Azure resources by default.
- **Q:** At what scopes can an Entra role be assigned vs an Azure role? / **A:** Entra roles: tenant level or administrative unit scope. Azure roles: management group, subscription, resource group, or resource.
- **Q:** Which roles can be assigned at an administrative-unit scope? / **A:** Authentication Administrator, Helpdesk Administrator, License Administrator, Password Administrator, and User Administrator.
- **Q:** What object types can an administrative unit contain? / **A:** Only users, groups, and devices.
- **Q:** How do you create/assign custom Entra roles and at what scope can they be assigned? / **A:** Created via Roles and administrators → New custom role; assignable at directory-level scope or app registration resource scope only.
- **Q:** Domain name limits per tenant? / **A:** Up to 900 managed domain names; if configuring all domains for federation with on-prem AD, up to 450 per organization.
- **Q:** What happens when you add subdomain europe.contoso.com after verifying contoso.com? / **A:** The subdomain is automatically verified (refresh the domain list to see it). Verifying it in a *different* tenant requires adding a TXT record at DNS hosting.
- **Q:** Conditions that block deleting a custom domain name? / **A:** Any user with username/email/proxy address containing the domain, any group email/proxy address using it, or any app whose app ID URI includes it — those resources must be changed/deleted first.
- **Q:** ForceDelete limits for removing a custom domain? / **A:** Requires fewer than 1,000 references; Exchange-provisioned references must be handled in the Exchange Admin Center; fails if >1,000 objects need renaming or if one of the apps is multitenant. Renames UPN, EmailAddress, ProxyAddress, and identifierUris to the initial default domain.

### Understand-check questions

**Q:** Why is changing the primary domain described as "streamlining" rather than "renaming," and what does that imply for planning?
**A:** Changing the primary domain only sets the default suffix offered when creating new users; existing users keep their UPNs. Migration of old UPNs therefore requires explicit updates per user (or ForceDelete-style renaming), so plan UPN changes deliberately instead of assuming a primary-domain switch fixes branding.

**Q:** A hospital wants regional support staff to reset passwords only for users in their own region. Which two features combine to achieve this, and why not just assign Helpdesk Administrator?
**A:** Administrative units + scoped role assignment: put each region's users into an AU and assign Helpdesk Administrator (or Password/User Administrator) at AU scope. Assigning the built-in role directly grants rights over every user in the tenant, violating least privilege.

**Q:** Why does the training say PIM changes where you manage roles once you have Entra ID P2?
**A:** With P2 and PIM in use, all role-management tasks move to the PIM experience (just-in-time eligibility/elevation), and assignment there is limited to one role at a time — you can't bulk-select multiple roles for one user.

**Q:** You restrict "Users can register applications" to No, then a developer still needs to register an app. What's the correct grant?
**A:** Assign them the Application Developer role (they then become first owner of registrations they create). Note the same role covers consent delegation when "users can consent" is also disabled.

**Q:** Distinguish what the Application Administrator can do that the Cloud Application Administrator cannot, and what neither can do.
**A:** Application Administrator additionally manages Application Proxy settings (on-premises permission); Cloud App Administrator doesn't. Neither role can manage Conditional Access.

### Real-world use cases

**Branded contractor portal for a staffing agency.** A 200-person IT staffing agency places contractors at client sites who sign into Microsoft 365 daily. Contractors kept mistaking phishing lookalike pages for real ones. Using company branding (banner logo, background image, help-desk sign-in page text under the Office 365 license), every legitimate sign-in shows consistent agency visuals, making spoofed pages easier to spot.

**Delegated administration across a national retail chain.** A retail chain with stores in 12 states had three Global Administrators doing all password resets and account unlocks. They create administrative units per state, add store employees' accounts to each AU, and assign Password Administrator at AU scope to regional supervisors — least privilege without tenant-wide admin rights, managed through the portal or Graph.

**Domain cleanup after an acquisition.** A logistics firm acquired a company whose users were all on `acquired.onmicrosoft.com`. After verifying `acquired.com` as a custom domain (subdomains auto-verified from the verified root) and making it primary, they later needed to retire an old domain; because deletion was blocked by lingering proxyAddresses, they used ForceDelete (under the 1,000-reference limit) to rewrite references to the default domain.

## Unit 1.2 — Create, configure, and manage identities

### Flashcards

- **Q:** Three ways Microsoft Entra ID defines users? / **A:** Cloud-only identities (source: Microsoft Entra ID or External Microsoft Entra directory), directory-synchronized identities (source: Windows Server AD), and guest users (source: Invited user).
- **Q:** Which sync tool does the module recommend for most organizations, and why? / **A:** Microsoft Entra Cloud Sync — lightweight cloud-managed agent, supports multiple disconnected AD forests; config lives in the cloud.
- **Q:** When does the module say to keep using Microsoft Entra Connect Sync over Cloud Sync? / **A:** Complex scenarios such as device synchronization or groups larger than Cloud Sync's supported sizes.
- **Q:** What members can a security group include vs a Microsoft 365 group? / **A:** Security groups: users, devices, service principals. M365 groups provide collaboration assets (shared mailbox, calendar, files, SharePoint site) and can include people outside the org.
- **Q:** Who can create security groups vs Microsoft 365 groups by default? / **A:** Security groups require a Microsoft Entra administrator; M365 groups are available to users and admins.
- **Q:** What are the three membership types, and which applies only to security groups? / **A:** Assigned, Dynamic User, Dynamic Device — Dynamic Device is security-groups-only (M365 groups support dynamic users but not dynamic devices).
- **Q:** What license enables dynamic group membership rules? / **A:** Microsoft Entra ID P1 (or Intune for Education for device-based rules).
- **Q:** OS requirements for Microsoft Entra registered devices? / **A:** Windows 10+, macOS 10.15+, iOS 15+, Android, Linux (Ubuntu 20.04/22.04/24.04 LTS, RHEL 8/9 LTS); signed in with local credentials plus an attached Entra account.
- **Q:** Which Windows editions/devices cannot be Microsoft Entra joined? / **A:** Home editions are excluded; supported are Windows 10/11 (non-Home), Windows Server 2019+ VMs in Azure (Server Core not supported), macOS 13+ (preview).
- **Q:** Three deployment methods for Microsoft Entra join? / **A:** Self-service OOBE, bulk enrollment, and Windows Autopilot.
- **Q:** Hybrid joined devices: supported server versions and sign-in options? / **A:** Windows Server 2016, 2019, and 2022; sign-in with password or Windows Hello for Business; managed via Group Policy, Configuration Manager standalone, or co-management with Intune.
- **Q:** Device writeback status per this module? / **A:** No longer supported/recommended — replaced by Cloud Kerberos Trust for Entra joined/hybrid joined devices authenticating to on-premises resources.
- **Q:** Group-based licensing prerequisites and license math? / **A:** Requires paid/trial Entra ID P1+ or Office 365 Enterprise E3+; licenses attach to security groups only; you need at least enough licenses to cover all unique licensed members (e.g., 1,000 unique members → 1,000 licenses minimum).
- **Q:** What happens to usage location during group license assignment? / **A:** Users without a specified usage location inherit the directory's location; best practice is to set usage location at user creation.
- **Q:** Custom security attributes: what objects can they be assigned to, and where are they NOT supported? / **A:** Assigned to Entra users and enterprise applications (service principals). Not supported in Microsoft Entra Domain Services, SAML token claims, or JWT claims.

### Understand-check questions

**Q:** Why does dynamic membership solve a problem that manual assignment can't, and what triggers reevaluation?
**A:** Rules evaluate user attributes (department, job title, location), so membership self-corrects whenever attributes change (e.g., a user moves departments — all dynamic rules reevaluate and the user is added/removed automatically), eliminating stale manual memberships.

**Q:** A personal laptop needs email access behind a Conditional Access policy requiring compliant devices. Which device registration type fits and what enforces compliance?
**A:** Microsoft Entra registered (BYOD scenario): local credentials sign in, the work account is added, and Intune MDM/MAM policies (via the registered device/app protection policy) enforce compliance like encryption and password complexity before granting access.

**Q:** Why would an organization choose hybrid join over Entra join even though both get SSO to cloud resources?
**A:** Hybrid join preserves dependencies on on-premises AD: Win32 apps requiring AD machine authentication, continued Group Policy configuration, and existing imaging solutions — while still registering the device with Entra ID.

**Q:** Why is group-based licensing preferred over per-user PowerShell automation at scale, and what happens when the same license comes from multiple sources?
**A:** Membership-driven licensing assigns/removes licenses automatically as users join/leave groups (typically within minutes), replacing complex per-user scripts; a license assigned from multiple sources (groups + direct) is consumed only once.

**Q:** What problem does API-driven inbound provisioning solve that classic HR-driven provisioning couldn't?
**A:** HR systems without a SCIM endpoint: since GA March 2024, any script/automation tool can push workforce data from any system of record (Workday, SuccessFactors, custom) to the provisioning API, keeping lifecycle management possible regardless of HR platform capabilities.

### Real-world use cases

**Seasonal workforce onboarding at a theme park.** A theme park hires thousands of seasonal workers who need Microsoft 365 but no on-premises accounts. IT uses cloud-only Entra users created via bulk creation, puts them in a security group with dynamic membership based on department attribute, and attaches group-based licensing — licenses appear within minutes of hiring and vanish when workers leave the group.

**BYOD engineering floor at a software startup.** Engineers insist on using personal Macs and phones. The startup registers devices with Entra ID (macOS 10.15+/iOS 15+ supported) and applies Intune app protection policies, so corporate email works only inside protected containers while the company never owns the hardware.

**M&A identity consolidation at a bank.** After acquiring a competitor with four disconnected AD forests, the bank deploys Microsoft Entra Cloud Sync — lightweight agents bridge each forest to one tenant without full Connect servers — and keeps Connect Sync only for its legacy device-writeback scenario, satisfying the module's guidance on tool selection.

## Unit 1.3 — Implement and manage external identities

### Flashcards

- **Q:** What marks a B2B collaboration guest in your directory? / **A:** UserType = Guest, and #EXT# appears in the user principal name.
- **Q:** Default external collaboration invite setting? / **A:** All users, including guests, can invite guest users (options range from off → admins/Guest Inviter → +members → everyone).
- **Q:** Default directory visibility for guest users? / **A:** Limited permissions: blocked from listing users/groups/directory objects, but can see membership of non-hidden groups; admins can restrict further to viewing only their own profile.
- **Q:** Do B2B invitations expire? / **A:** No — an invitation does not expire; the guest redeems via invitation email link or direct app link.
- **Q:** Bulk invite CSV template rules? / **A:** Row 1 = version number, row 2 = column headings (must not be removed/modified), remove the examples row; additional columns are ignored.
- **Q:** What does the UserType property actually indicate? / **A:** Only the relationship to the host organization (Member vs Guest) — it has no relation to how the user signs in or their directory role.
- **Q:** Can guests hold admin roles? / **A:** Yes — guests can be added to any role (least privilege recommended; PIM suggested for granting elevated access to B2B/guest users).
- **Q:** Redemption order when no home directory is found? / **A:** If email OTP is enabled → passcode emailed to invited address; if disabled → user is prompted to create a consumer MSA with the invited email.
- **Q:** What changed about "direct federation"? / **A:** It's now called SAML/WS-Fed identity provider (IdP) federation; supports SAML 2.0 and WS-Fed providers; tied to domain namespaces.
- **Q:** Key constraint on the federated target domain? / **A:** Must NOT be DNS-verified in Microsoft Entra ID.
- **Q:** Effect of setting up SAML/WS-Fed federation on already-redeemed guests? / **A:** None — existing guests keep their previous authentication method; deleting the federation locks those users out until redemption status is reset.
- **Q:** Google federation scope? / **A:** Designed specifically for Gmail users (gmail.com/googlemail.com detection); G Suite domains use SAML-based federation instead.
- **Q:** Facebook as an IdP — what can it be used for? / **A:** Only self-service sign-up user flows; users cannot redeem invitations with Facebook accounts.
- **Q:** Deployment prerequisites for Microsoft Entra Verified ID? / **A:** Azure tenant with subscription, Entra ID Premium license, signed in as global admin, and a configured Azure Key Vault instance.
- **Q:** Cross-tenant access defaults? / **A:** B2B collaboration enabled by default; B2B direct connect blocked by default; trust settings can make your CA honor partner-tenant MFA/compliant-device/hybrid-joined claims.

### Understand-check questions

**Q:** Walk through how the redemption flow decides between Google, SAML/WS-Fed IdP, MSA, and OTP for an invited guest.
**A:** Entra checks: (1) managed-tenant discovery; (2) if UPN matches both an Entra account and personal MSA, user chooses; (3) domain suffix matches configured SAML/WS-Fed federation → redirect to that IdP; (4) gmail.com/googlemail.com suffix with Google federation enabled → Google; (5) existing personal MSA → sign in with it; (6) no home directory → OTP email (if enabled) else create consumer MSA.

**Q:** Why might an organization convert a B2B guest to Member, and why does Microsoft discourage treating PowerShell conversion as routine?
**A:** Partner organizations inside the same parent company may warrant Member treatment (internal-like privileges). But UserType encodes the relationship to the org — flipping it atomically via PowerShell ignores knock-on questions (UPN changes, mailbox, resource access), so Microsoft recommends against depending on it.

**Q:** Two suppliers want seamless Teams shared-channel collaboration without guest objects in either tenant. Which feature and what's the setup requirement?
**A:** B2B Direct Connect: requires a *mutual* cross-tenant access trust between both organizations (default is blocked); currently works with Teams shared channels, giving home-tenant credential SSO without creating guest objects.

**Q:** A government contractor collaborates with Azure Government tenants. Where is that configured?
**A:** In cross-tenant access settings under Microsoft cloud settings — cloud-specific configuration for Azure Government/Azure China beyond the standard organizational (per-tenant) settings.

**Q:** Your Gmail guest gets an error opening myapps.microsoft.com directly. Why, and what's the fix?
**A:** Google guests must use links containing tenant context (e.g., `https://myapps.microsoft.com/?tenantId=<id>` or `/contoso.onmicrosoft.com`); generic links fail. Also note embedded web-view sign-in deprecation affects Gmail flows in some native apps.

### Real-world use cases

**Supplier onboarding for an automotive OEM.** An OEM works with 300 small parts suppliers lacking IT departments. Instead of managing passwords, admins enable B2B collaboration with email OTP redemption and set invite policy to "admins and Guest Inviter role only" after a procurement-wide spam incident, restoring control while suppliers use whatever mailbox they have.

**Bulk conference-partner invites for an events company.** An events firm runs a partner expo needing 500 vendor guests into a Teams-connected SharePoint site. They fill the bulk-invite CSV template (preserving version row and headers, deleting the examples row), upload once, then assign guests to a dynamic security group keyed on userType=Guest for app access.

**Credential verification for a university alumni network.** A university issues verifiable credentials for diplomas via Microsoft Entra Verified ID (Key Vault-backed issuer, domain-bound DID so wallets show the verified symbol); employers verify diplomas through the free verifier REST API without calling the registrar.

## Unit 1.4 — Implement and manage hybrid identity

### Flashcards

- **Q:** Five capabilities of Microsoft Entra Connect? / **A:** Synchronization (incl. password hashes), password hash synchronization (PHS), pass-through authentication (PTA), federation integration (AD FS), and Health monitoring.
- **Q:** How often does the PHS synchronization process run, and can you change it? / **A:** Every 2 minutes; frequency cannot be modified.
- **Q:** What exactly is synchronized in PHS? / **A:** A hash of the hash of the user's on-premises password (one-way functions; plaintext never leaves AD), applied extra security processing before syncing to Entra.
- **Q:** Why enable PHS even with PTA or federation? / **A:** High availability/disaster recovery (cloud auth survives on-prem outages — hours back online vs weeks), and Identity Protection leaked-credentials reporting requires PHS.
- **Q:** How many PTA agents are recommended and where? / **A:** Three total — one installed on the Entra Connect server plus two additional redundant agents on other servers.
- **Q:** Placement constraint for PTA agents? / **A:** Agents need line-of-sight to DCs and outbound internet; deploying them in a perimeter network is not supported.
- **Q:** Which immediate-enforcement capability distinguishes PTA from PHS? / **A:** PTA enforces on-prem account state, password policy, and sign-in hours at sign-in time (disabled/locked-out/expired accounts denied immediately).
- **Q:** Does PTA fail over to PHS automatically during outages? / **A:** No — PHS can act as backup, but you must manually switch the sign-in method using Entra Connect.
- **Q:** When switching from AD FS to PTA, how long must AD FS stay running and why? / **A:** At least 12 hours — ensures Exchange ActiveSync clients keep signing in during transition.
- **Q:** Is Seamless SSO compatible with AD FS? / **A:** No — it combines only with PHS or PTA; it needs no extra on-prem components and rolls out via Group Policy.
- **Q:** Which computer account backs Seamless SSO Kerberos tickets? / **A:** AZUREADSSOACC — AD issues Kerberos tickets for this account representing Entra ID; browser flow starts with a 401 challenge.
- **Q:** sourceAnchor rules (name 4)? / **A:** Immutable for object lifetime (<60 chars, no special characters, globally unique, shouldn't derive from the user's name); single forest should use objectGUID.
- **Q:** Hard Match vs Soft Match attributes? / **A:** Hard match: sourceAnchor ↔ immutableId; soft match fallback: ProxyAddresses and UserPrincipalName.
- **Q:** InvalidSoftMatch cause in one sentence? / **A:** Hard match fails AND soft match finds an object whose immutableId differs from the incoming SourceAnchor — typically duplicate ProxyAddresses/UPN tied to different on-prem objects.
- **Q:** LargeObject sync error common causes and hard limit? / **A:** Oversized userCertificate/userSMIMECertificate (hard limit 15 certificates each), too-large thumbnailPhoto, too many proxyAddresses.
- **Q:** Existing Admin Role Conflict fix sequence? / **A:** Remove the cloud account from all admin roles → hard-delete the quarantined cloud object → next sync soft-matches → restore role memberships.
- **Q:** Staging-mode server behavior? / **A:** Reads from all connected directories and maintains updated identity data but writes nothing — standby for disaster recovery.
- **Q:** Topology rule for multiple tenants? / **A:** 1:1 relationship — one Entra Connect sync server per Microsoft Entra tenant; express install supports only single forest/single tenant.
- **Q:** Which component performs on-premises GALSync in multi-forest meshes? / **A:** Not Entra Connect — GALSync is implemented via FIM 2010 or MIM 2016 externally.
- **Q:** Connect Health license and ports? / **A:** Requires Entra ID Premium P1; TCP 443 always, 5671 for older agents (latest agent needs only 443); TLS inspection filtered/disabled; FIPS disabled; PowerShell 4.0+.
- **Q:** Where must the Health AD FS agent NOT be installed? / **A:** On the Entra Connect Sync server — AD FS agent belongs on AD FS servers.
- **Q:** Health RBAC roles and default owner? / **A:** Owner, Contributor, Reader; global administrators are Owners by default and this cannot be changed; diagnosing/remediating duplicated-attribute errors requires Contributor.
- **Q:** Sync error report refresh cadence in Connect Health? / **A:** Updated every 30 minutes with errors from the latest sync attempt.

### Understand-check questions

**Q:** A ransomware attack takes down a customer's entire on-prem estate. Contrast outcomes for two customers: one with PHS enabled alongside federation, one without.
**A:** The PHS-enabled org flips primary authentication to cloud (manual switch) and restores user access within hours via Microsoft 365; the org without PHS has no cached hashes, waits weeks rebuilding AD infrastructure, and falls back to consumer email. This is Microsoft's core argument for enabling PHS regardless of chosen method.

**Q:** Why does Contoso's `contoso.local` domain force a custom-install path in Entra Connect?
**A:** Non-routable domains can't be DNS-verified in Entra ID, and synced UPN suffixes must match a verified custom domain — otherwise Connect rewrites UPNs to `contoso.onmicrosoft.com`. Custom settings let admins pick a routable attribute (e.g., mail) as the sign-in UPN or configure alternate login ID.

**Q:** Bob Taylor's new AD account won't sync; error says ProxyAddresses conflict. Diagnose using the match model.
**A:** Likely AttributeValueMustBeUnique/InvalidSoftMatch: his proxyAddress matches Bob Smith's already-synced object, whose immutableId differs from Taylor's sourceAnchor — hard match fails, and the schema forbids duplicate values. Fix by removing the duplicated value in the sourcing directory (or deleting one object).

**Q:** Why does the module recommend staging-mode deployment as business continuity for PHS shops specifically?
**A:** PHS depends on the Connect sync pipeline; a second server in staging mode consumes the same import cycles and holds current metadata without exporting, so recovery means promoting the standby rather than reinstalling and waiting for a full resync.

**Q:** A user's UPN changed from bob@contoso.com to bob@fabrikam.com and sync now errors. Name the error and root condition.
**A:** FederatedDomainChangeError — the UPN suffix moved from one *federated* domain to another federated domain; the cloud UPN update fails under that combination.

### Real-world use cases

**Manufacturing group survives a domain-controller fire.** A mid-size manufacturer with AD FS loses both federation servers to a datacenter fire. Because leadership followed Microsoft guidance and kept PHS enabled as backup, IT switches sign-in to PHS in Entra Connect and employees reach Microsoft 365 the same morning while hardware is rebuilt.

**Hospital chain enforcing sign-in hours for shift workers.** A hospital chain must deny cloud logins outside scheduled shifts and instantly block disabled badge accounts. PHS's eventual consistency isn't sufficient, so they deploy three PTA agents (Connect server + two others, all inside the LAN near the DCs) to enforce account state and logon-hour policy at authentication time.

**Post-acquisition forest stitching at an insurance firm.** After acquiring a rival with isolated forests, the insurer runs one Entra Connect server (domain-joined, reachable to all forests) with objectGUID sourceAnchor, plans a staging-mode standby, and uses MIM for GALSync — matching the supported multi-forest topology the module describes.

## Exam traps

1. **PHS frequency is fixed at 2 minutes** — answers claiming configurable intervals or "every 30 minutes" confuse it with the Connect Health error-report refresh cadence (30 min).
2. **Seamless SSO ≠ federation** — Seamless SSO pairs only with PHS or PTA, never AD FS/PingFederate; and it relies on the AZUREADSSOACC computer account, not group-managed service accounts.
3. **PTA agent count and placement** — recommend 3 agents (including one on the Connect server); perimeter-network placement is unsupported; failover to PHS is manual, never automatic.
4. **Administrative units contain only users, groups, and devices** — not applications or service principals; and only five built-in roles (Authentication, Helpdesk, License, Password, User Administrator) are assignable at AU scope.
5. **ForceDelete domain gotchas** — fails above 1,000 references, fails for multitenant apps, and Exchange-provisioned objects must be cleaned in the Exchange Admin Center first; changing the primary domain never renames existing users.
6. **SAML/WS-Fed IdP federation constraints** — target domain must NOT be DNS-verified in your tenant; configuring federation does NOT change auth for guests who already redeemed; deleting federation locks them out (reset redemption status to fix). Facebook is self-service-sign-up-only — invitations can't be redeemed with it.
7. **Device writeback is dead** — exam answers pointing to device writeback for hybrid device scenarios are outdated; Cloud Kerberos Trust replaces it. Similarly, Cloud Sync is the recommended tool for most orgs (disconnected forests, HA agents), while Connect Sync persists for device sync/large-group complexity.
8. **Licensing tripwires** — company branding: P1/P2/O365 (not free tier); dynamic groups and Connect Health: P1; Identity Protection/leaked-credentials reporting: P2; group-based licensing attaches to security groups only and requires ≥1 license per unique member.
