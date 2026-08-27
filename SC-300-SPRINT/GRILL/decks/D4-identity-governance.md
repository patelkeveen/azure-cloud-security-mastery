# SC-300 Domain 4 — Identity Governance (exam weight: 20–25%)

Grounded in MS Learn modules 04-01 through 04-04. License shorthand:
**Entra ID P2** = prerequisite for entitlement management + PIM; **Entra ID Governance / Entra Suite** = full access reviews; **P1/P2** = sign-in log ingestion into Sentinel.

---

## Unit 4.1 — Plan and implement entitlement management

### Flashcards

- **Q:** What is an access package in entitlement management?
  **A:** A bundle of ALL the resources (with their roles) a user needs to work on a project or task, governed by policies. Used for internal employees AND external users. An access package is always contained inside a catalog.
- **Q:** What is a catalog and why does it exist?
  **A:** A container of related resources and access packages. Its purpose is DELEGATION — non-administrators (catalog owners) can create and manage access packages without IT involvement. Whoever creates a catalog automatically becomes its first owner.
- **Q:** Who can create new catalogs?
  **A:** Members of the "catalog creator" collection. When an authorized non-administrator creates a catalog, they become the catalog's first owner (and can add more owners).
- **Q:** Which four resource types can be managed DIRECTLY by access packages?
  **A:** (1) Membership of Microsoft Entra security groups, (2) membership of Microsoft 365 Groups and Teams, (3) assignment to Microsoft Entra enterprise applications (SaaS and custom federated/SSO-provisioned apps), (4) membership of SharePoint Online sites.
- **Q:** How do you deliver Microsoft 365 licenses through an access package?
  **A:** Indirectly — put a security group in the access package and configure group-based licensing on that group.
- **Q:** How do you grant Azure resource access via entitlement management?
  **A:** Indirectly — put a security group in the package and create an Azure role assignment for that group.
- **Q:** How do you grant a Microsoft Entra role via an access package?
  **A:** Indirectly — include groups assignable to roles in the package and assign the Entra role to that group.
- **Q:** What does an access package POLICY define?
  **A:** The rules/guardrails for assignment: which existing users are eligible to request, the approval process, and how long access lasts before it expires or must be renewed. One package can have multiple policies (e.g., one for employees, one for external users).
- **Q:** What is a connected organization?
  **A:** An external Microsoft Entra directory OR domain you have a relationship with. Its users can be named in a policy as allowed to request access; when approved they're auto-invited into your directory as B2B guests.
- **Q:** What are the three ways to specify who forms a connected organization?
  **A:** (1) Users in another Entra directory (from any Microsoft cloud), (2) users in a non-Entra directory configured for direct federation, (3) users in a non-Entra directory whose email addresses all share one domain name. You may add only ONE directory or domain per connected organization.
- **Q:** Default lifecycle behavior when an external user loses their last access package assignment?
  **A:** By default they are BLOCKED from signing in to your directory, and after 30 DAYS their guest account is removed. Removal day count is configurable (0 = remove immediately); removal only applies to accounts invited through entitlement management.
- **Q:** Why should you NOT enable "Block external user from signing in" for partners who might return?
  **A:** A blocked user cannot re-request the same access package or request any other access in your directory.
- **Q:** Terms of use documents use what format and font guidance?
  **A:** PDF format; recommended font size is 24 point to support mobile devices. Can contain EULAs; enforced as a Conditional Access grant control.
- **Q:** Caveat of "Require users to consent on every device" for terms of use?
  **A:** Users must register EACH device with Microsoft Entra ID before getting access.
- **Q:** Two ways to schedule terms-of-use reacceptance?
  **A:** (1) Expire consents on a fixed calendar: "Expire starting on" date + Frequency (all users expire together), or (2) "Duration before reacceptance requires (days)": each user follows their own accept-date schedule (e.g., 30 days → Alice accepted Jan 1 expires Jan 31; Bob accepted Jan 15 expires Feb 14).
- **Q:** Can you edit an uploaded terms-of-use document?
  **A:** No — you can't modify an existing document. You can add a language, upload a NEW version (with optional "Require reaccept" so existing consents expire; otherwise prior consent stays current), or must create a brand-new terms of use for some setting changes.

### Understand-check questions

Why do catalogs exist at all — what problem would remain if access packages were tenant-global objects?
**A:** Delegation. Catalogs let departments/package managers own a bounded set of resources and create packages without global admin rights; deletion of a catalog is only possible when it contains no access packages.

An access package needs different rules for employees vs. supplier staff. How do you structure this?
**A:** One package, TWO policies — policy 1 scoped to internal directory users, policy 2 scoped to a connected organization (external users). Policies carry their own approvers, duration, and renewal rules.

A supplier's last contractor assignment expired yesterday. Walk through what happens by default.
**A:** Sign-in to your directory is blocked immediately upon losing the last assignment; the guest object itself remains for 30 days by default, then is deleted (configurable down to 0 days). Guests present BEFORE receiving assignments stay unless invited via entitlement management.

Your legal team updated the contract PDF mid-year. What are your options for pushing the new version?
**A:** Edit terms → Language options → Update → upload new PDF → toggle "Require reaccept" ON to force all users to accept at next sign-in. Without the toggle, only new/unexpired-consent users see the new version.

How would you audit exactly who holds a given package right now, including failed deliveries?
**A:** Open the package → Assignments: active list, filter status = Delivering (provisioning errors; details on Requests page), Expired; download CSV. Roles: Identity Governance Administrator, User Administrator, catalog owner, access package manager, access package assignment manager. Graph/PowerShell scope: EntitlementManagement.Read.All (ReadWrite for changes).

### Real-world use cases

1. **Manufacturing supply chain (B2B):** A parts maker gives 40 supplier engineers time-boxed access to one SharePoint site + one app. Connected organization for the supplier's domain, one access package with two policies (internal buyers / external engineers), external-user lifecycle set to block-on-loss but NOT delete (they rotate back every quarter). Why: no manual guest invites, access dies automatically when projects end.
2. **Contractor onboarding at a logistics firm:** New warehouse-management contractors need M365 license, Teams membership, and a custom SaaS app on day one. One access package bundles group (group-based licensing), M365 group, and app assignment; manager approval required; 90-day expiration with renewal. Why: IT stopped writing per-resource tickets; HR offboarding triggers assignment expiry instead.
3. **Marketing department self-service:** Marketing owns its SharePoint sites but hates IT latency. IT creates a "Marketing" catalog, makes the marketing lead catalog owner and access package manager; she builds packages and approval rules herself. Why: least-privilege delegation — she never gets Global Administrator.
4. **Compliance-driven ToU for partner portal:** A law firm requires suppliers to acknowledge a data-handling EULA before reaching any cloud app. PDF terms of use enforced via Conditional Access grant control on all cloud apps, consent expiring monthly, per-device consent enabled. Why: auditable acceptance records stored for the life of the ToU.

---

## Unit 4.2 — Plan, implement, and manage access reviews

### Flashcards

- **Q:** What license fully unlocks access reviews?
  **A:** Microsoft Entra ID Governance or Microsoft Entra Suite subscription. Some capabilities work with Microsoft Entra ID P2 — confirm licensing before deployment.
- **Q:** Exactly WHO needs a P2/Governance license for an access review?
  **A:** Each member or guest user who: is assigned as a reviewer, performs a self-review, is a group owner performing a review, or is an application owner performing a review. Global Administrator / User Administrator who merely SET UP reviews, configure settings, or APPLY decisions need NO license.
- **Q:** Five resource types you can review?
  **A:** (1) Application access (SSO-integrated apps), (2) group memberships (cloud or synced, incl. Microsoft Teams/M365), (3) access packages, (4) Microsoft Entra roles and Azure resource roles (managed inside PIM UX), (5) custom data resources (preview).
- **Q:** When is the reviewer selection locked for a review?
  **A:** At creation — reviewers chosen when the review is created cannot be changed once the review has started.
- **Q:** What is a fallback reviewer?
  **A:** When you pick "Managers of users" or "Group owner(s)," a fallback reviewer completes the review when the user has NO manager or the group has NO owner.
- **Q:** Available recurrence frequencies and the monthly duration limit?
  **A:** Weekly, Monthly, Quarterly, Semi-annually, Annually. Maximum duration for a MONTHLY review is 27 DAYS, to avoid overlapping instances.
- **Q:** Scope option for inactive users in group reviews?
  **A:** "Inactive users (on tenant level)" with configurable days inactive — up to 730 DAYS.
- **Q:** Four options for "If reviewers don't respond"?
  **A:** No change (default), Remove access, Approve access, Take recommendations (system applies its approve/deny recommendation for unreviewed users). This never overrides manually reviewed users.
- **Q:** Options for "Action to apply on denied guest users"?
  **A:** (1) Remove user's membership from the resource (sign-in to tenant keeps working), or (2) Block user from signing in for 30 DAYS, then remove from tenant (re-enable possible within those 30 days; then deletion). Not configurable on reviews beyond guests or on "All M365 groups with guest users" — default becomes remove-membership.
- **Q:** What drives system recommendations during a review?
  **A:** (1) No sign-in within 30 DAYS → recommend deny (last sign-in shown; covers interactive AND non-interactive sign-ins), (2) peer outlier analysis — user lacks access peers have, measured by distance in reporting structure.
- **Q:** Two reviewers disagree — whose decision stands?
  **A:** The LAST submitted response is recorded (Bob denies after Alice approves → denial wins).
- **Q:** What does a reviewer's "Don't know" choice do?
  **A:** The user KEEPS access and the choice is recorded in audit logs.
- **Q:** When are denied users actually removed?
  **A:** Not immediately — at the END of the review period, or earlier if an administrator stops the review, provided Auto apply results to resource is ENABLED.
- **Q:** Access reviews on groups synced from on-prem AD?
  **A:** Reviews CANNOT change membership — source of authority is on-premises (synced groups also can't have owners in Entra). Schedule the review anyway; reviewers act in the on-prem group; export decisions as CSV or via Graph.
- **Q:** Review statuses between end and effect?
  **A:** Completing → Auto-Reviewing → Auto-Reviewed (system records decisions for all unreviewed users) → Applying → Applied. Failed = review couldn't progress (tenant deletion, license change, internal tenant change).
- **Q:** Which audit-log category captures access review events, and what activities?
  **A:** Category **Policy**: Create/Update/Delete access review, Access review ended, Approve/Deny/Reset/Apply decision. For deeper analysis export audit logs to Log Analytics or Event Hubs.
- **Q:** Graph automation permissions/cmdlet for access reviews?
  **A:** Read: AccessReview.Read.All; create/manage: AccessReview.ReadWrite.All (delegated w/ Identity Governance Administrator, or application permission). PowerShell: New-MgIdentityGovernanceAccessReviewDefinition.
- **Q:** Updating a recurring series — instance vs. series?
  **A:** Changes can target just the CURRENT instance (active review) or the SERIES (all future recurrences), e.g., replace a departed reviewer across the series.
- **Q:** Access Review Agent signals it scores?
  **A:** User inactivity, user-to-group affiliation, account enabled (accountEnabled), employment ended (employeeLeaveDateTime), lifecycle workflow history (mover workflow in past 30 days), decisions from previous iterations, access request history (for package assignments). Runs in Teams with justification summaries. Requires ID Governance/Suite licenses + Security Copilot onboarded with ≥1 SCU; admins need Identity Governance Administrator + Lifecycle Workflows Administrator + Security Copilot Contributor. Once started, agents can't be stopped or paused.

### Understand-check questions

Finance wants quarterly attestation of 500 users on a sensitive app at minimum cost. Who must hold licenses?
**A:** Only decision-makers: the assigned reviewers (or self-reviewers/group owners/app owners performing reviews) — one license each. Admins configuring the review and applying results need no license even without P2.

You inherit a review where half the users were never touched by reviewers. What happened at completion?
**A:** With auto-apply on, the "If reviewers don't respond" rule executed during Auto-Reviewing/Auto-Reviewed: No change kept them, Remove removed them, Approve granted them, or Take recommendations applied the system's recommendation (deny if no sign-in in 30 days).

Why start a pilot with auto-apply DISABLED?
**A:** So you control implications while tuning process/comms: verify everyone has valid emails, document every removal for quick restore, monitor audit logs (category Policy) before automating destruction.

Sales team members are EXCLUDED from a CA network-location policy via a group. Governance concern?
**A:** Exclusion groups are high-value attack surface — schedule periodic reviews of that group's membership so exceptions don't silently grow.

Why is there no "application owner" reviewer option like group owner?
**A:** Applications in Entra ID don't necessarily HAVE an owner; group ownership is well-defined for M365/Entra-created groups (Teams creator becomes owner), while synced groups lack owners entirely.

### Real-world use cases

1. **Quarterly guest hygiene (professional services):** Consulting firm accumulates ex-client B2B guests. Recurring QUARTERLY review of "All Microsoft 365 groups with guest users," scope Guest users only, reviewers = group owners, non-response = Take recommendations, denied-guest action = block 30 days then remove. Why: satisfies client-data clauses without IT sifting thousands of guests.
2. **SOX attestation (fintech):** Auditors demand annual proof that only current finance staff reach the ERP SaaS app. Annual application review, reviewers = selected delegates from finance controllers, justification REQUIRED, auto-apply enabled, results exported via Graph API into evidence pack. Why: turns audit season from weeks of screenshots into a report pull.
3. **CA exception governance (retail):** Traveling sales staff sit in an exclusion group bypassing location-based Conditional Access. Monthly review by the security team with 730-day inactivity scoping off. Why: exception lists are the classic privilege-drift vector auditors flag first.
4. **Privileged role certification (healthcare):** Compliance requires proof nobody retains unneeded admin roles. Reviews for Global Administrator, User Administrator, Privileged Authentication Administrator, Conditional Access Administrator, Security Administrator run semi-annually inside the PIM experience, reviewers = Members (self) with reason required. Why: regulators get signed attestations; stale admins drop out.

---

## Unit 4.3 — Plan and implement privileged access

### Flashcards

- **Q:** License requirement for PIM?
  **A:** Microsoft Entra ID Premium P2 (for every eligible member/guest being managed).
- **Q:** Eligible vs. Active role assignment?
  **A:** ELIGIBLE = must perform an action to use the role (MFA check, business justification, and/or approval from designated approvers). ACTIVE = no action needed; privileges permanently assigned to the user. Eligible exists ONLY in PIM; permanent-active is the normal Entra/Azure assignment.
- **Q:** Core capabilities of PIM?
  **A:** Just-in-time activation; time-bound assignments with start/end dates; require approval to activate; enforce Azure MFA on activation; justification capture; notifications on activation; access reviews of role members; downloadable audit history.
- **Q:** Who can bring an Azure subscription/mgmt group under PIM management?
  **A:** Only OWNERS of the subscription or management group. A Global Administrator can "elevate access to manage all Azure subscriptions" for discovery, but should get owner approval first. Managing a mgmt group or subscription makes child resources manageable too.
- **Q:** Which two Entra roles does Microsoft say to protect with PIM FIRST?
  **A:** Global Administrator and Security Administrator — most harm when compromised. Also manage ALL roles that have GUEST USERS assigned (vulnerable accounts). Top-10 most-managed roles include GA, Security Admin, User Admin, Exchange Admin, SharePoint Admin, Intune Admin, Security Reader, Service Admin, Billing Admin, Skype for Business Admin.
- **Q:** Minimum PIM coverage for Azure resources, even on non-critical subscriptions?
  **A:** Protect Owner and User Access Administrator on EVERY subscription/resource. On critical ones, put all roles under PIM. PIM supports TIME-BOUND service accounts — treat them like regular users.
- **Q:** Microsoft's standing-administrator goal?
  **A:** ZERO permanently active assignments for both Entra and Azure roles — except TWO break-glass emergency accounts holding PERMANENT Global Administrator.
- **Q:** Decision factors for permanent (standing) vs. eligible?
  **A:** Frequency of elevation (one-off need → never permanent; daily need + productivity hit → consider permanent) and org-specific cases (distant teams/high-ranking executives hard to bind to elevation process). If permanent is unavoidable, set up RECURRING ACCESS REVIEWS on those users.
- **Q:** Approval mechanics — multiple approvers configured?
  **A:** Approval completes as soon as ONE approver acts; you cannot require approval from two users. Default approver set = ALL Privileged Role Administrators (permanent AND eligible). A user who is both eligible for a role and its approver CANNOT approve their own activation.
- **Q:** Activation duration bounds?
  **A:** Configurable per role (module examples: 1 hour for Global Administrator, 2 hours Exchange Admin, 8 hours Helpdesk Admin); established maximum is 24 hours. After expiry, privileges lapse automatically.
- **Q:** Expiration choices for AZURE role assignments (active and eligible)?
  **A:** 15 days, 1 month, 3 months, 6 months, 1 year, or permanent(ly eligible). Active assignments for Azure roles can carry a set expiry — hence called "active admin" not "permanent admin."
- **Q:** Who gets notified when an eligible user activates a role?
  **A:** Global Administrators, Privileged Role Administrators, and Security Administrators (email). Admin accounts lacking mailboxes need an ALTERNATE EMAIL configured or notifications are lost. Optional incident/ticket number ties activations to internal systems.
- **Q:** What is a privileged access group (PAG)?
  **A:** A role-assignable group brought under PIM management ("enable for privileged access" in the group's Activity section). Members activate MEMBERSHIP individually via PIM — the group itself is never activated — inheriting every role the group holds. One JIT request → multiple roles (e.g., Tier 0 Office Admins → Exchange, Office Apps, Teams, Search Admin). Separate PAGs allow different policies (lenient for employees, approval-enforced for B2B partners).
- **Q:** Who manages membership of a role-assignable group?
  **A:** Only Privileged Role Administrator, Global Administrator, and the group's owners. Recommendation: make owners ELIGIBLE for the group's Owner role so even membership changes go through activation.
- **Q:** Which Azure roles can PIM for Azure resources manage?
  **A:** Built-in AND custom — e.g., Owner, User Access Administrator, Contributor, Security Admin, Security Manager.
- **Q:** Restricted scopes for certain Entra role assignments in PIM?
  **A:** Administrative unit, service principal, or application scope (for supported roles), instead of whole-directory.
- **Q:** Break-glass account requirements (count & construction)?
  **A:** TWO OR MORE accounts: cloud-only on the .onmicrosoft.com domain, NOT federated/synchronized, not associated with any individual (no employee phones/hardware tokens), credentials that never expire and aren't caught by automated cleanup, devices secured in known locations with ≥2 independent network paths, authentication mechanism DISTINCT from other admins, PERMANENT Global Administrator role.
- **Q:** Break-glass MFA / Conditional Access exclusions?
  **A:** Exclude AT LEAST ONE account from phone-based MFA mechanisms (incl. third-party/per-user MFA policies), and exclude AT LEAST ONE from ALL Conditional Access policies so a bad policy can't lock out recovery. Federated shops can let ADFS assert the MFA claim (cert-backed) — but still keep cloud-only accounts for federation outage.
- **Q:** Operating cadence for break-glass accounts?
  **A:** Monitor sign-in/audit logs with alerts (e.g., Log Analytics email/SMS alert on any break-glass sign-in). Validate AT LEAST every 90 DAYS, plus on IT-staff changes and subscription changes: update passwords, test sign-in + admin task, confirm no individual registered MFA/SSPR to personal devices.
- **Q:** PIM audit views for privileged access groups?
  **A:** Resource audit (all activity) and My audit (personal activity) under Groups → Activity. Note: role assignments authorized via Azure delegated resource management (service providers) are NOT shown.

### Understand-check questions

Helpdesk admins need elevated rights all day. Does zero-standing-admin mean they suffer PIM friction constantly?
**A:** Evaluate elevation frequency: if activation is constant and productivity tanks, permanent assignment MAY be justified — but then run recurring access reviews over those permanent holders and require justification.

An attacker phishes an eligible Global Admin. What layers did PIM add versus a standing admin?
**A:** Activation gate: fresh MFA challenge, optional approval by another human (self-approval impossible), justification text, incident ticket number, notification emails to GA/PRA/Security Admins, and time-bounded expiry — plus full audit trail.

Why TWO break-glass accounts rather than one, and why .onmicrosoft.com?
**A:** Resilience: one may be excluded from CA, another from phone-MFA — separate failure domains; cloud-only avoids federation/AD sync outages (the exact scenarios that necessitate break-glass) and automated cleanup of dormant credentials.

Tier-0 operators need four Office-related roles for incident work. Compare assigning four PIM roles vs. one PAG.
**A:** Four roles = four activations/policies to maintain. One role-assignable group made privileged-access: single activation grants all four; membership manageable only by PRA/GA/owners; distinct policy possible per group (partners stricter than employees).

Global Administrator wants to onboard all company subscriptions into PIM. Correct path and etiquette?
**A:** Use "Elevate access to manage all Azure subscriptions" for discovery, but obtain each subscription OWNER's approval before managing their resources; owners themselves are the natural PIM onboarding authority.

### Real-world use cases

1. **Financial services production lockdown:** Trading-platform subscription hosts sensitive data. Owner onboards it to PIM; ALL roles become eligible with MFA + approval by other Owners; 1-hour activation; Owner/UAA protected even on dev subscriptions with 6-month eligible expiry. Why: eliminates standing Contributor access that a single credential theft would exploit.
2. **Hospital Tier-0 consolidation:** Identity team replaces scattered admin rights with "Tier 0 Office Admins" PAG covering Exchange/Office Apps/Teams/Search Admin; owners must activate Owner eligibility before changing members. Why: one JIT request per shift instead of four, with cleaner audit lines per clinician-admin.
3. **Break-glass program (airline):** After an ADFS outage grounded sign-ins, the org created two cloud-only .onmicrosoft.com GAs: one excluded from all CA policies, one using a hardware FIDO method stored in a safe; Log Analytics alerts fire on any usage; 90-day validation drills documented for auditors. Why: recovery works precisely when everything else fails.
4. **MSP oversight caveat:** A managed service provider administers customer subscriptions via Azure Lighthouse (delegated resource management). Customer's PIM reports show provider-made assignments missing — team learns delegated-provider authorizations aren't reflected and monitors separately. Why: closes a blind spot before an audit finding.

---

## Unit 4.4 — Monitor and maintain Microsoft Entra ID

### Flashcards

- **Q:** Components of the Entra reporting architecture?
  **A:** ACTIVITY logs: Sign-ins, Audit logs, Provisioning logs (provisioning service activity, e.g., group created in ServiceNow, user imported from Workday). SECURITY reports: Risky sign-ins (attempt by someone who isn't the legitimate owner) and Users flagged for risk (possibly compromised account).
- **Q:** The four sign-in log categories in Entra?
  **A:** Interactive, Non-interactive (e.g., service-to-service/token refreshes), Service principal (app-only), Managed identity. The basic Sign-ins report displays INTERACTIVE only.
- **Q:** Latency of sign-in records appearing in the portal?
  **A:** Up to TWO HOURS.
- **Q:** License needed to view the sign-in activity report? Provisioning logs?
  **A:** Sign-in report available in ALL editions (also via Microsoft Graph API). Provisioning logs require P1/P2 (established distinction from the free tier).
- **Q:** Roles that can read sign-in/audit data?
  **A:** Security Administrator, Security Reader, Global Reader, Report Reader (+ Global Administrator); ANY user (non-admin) can view their OWN sign-ins.
- **Q:** Default columns of the sign-ins list view — and the multi-value restriction?
  **A:** Date, user, application, sign-in status, risk detection status, MFA requirement status. Fields holding MULTIPLE values for one sign-in (authentication details, Conditional Access data, network location) canNOT be columns.
- **Q:** Conditional Access column statuses and meanings?
  **A:** Not applied (no policy matched), Success (policy applied and satisfied), Failure (user+app conditions matched but grant controls unsatisfied or blocked). The CA tab enables per-policy troubleshooting directly in sign-in reports.
- **Q:** Download limits for sign-in and audit logs?
  **A:** CSV or JSON, up to 250,000 RECORDS, constrained by retention policies. Audit date-range filters: 24 hours, 7 days, Custom.
- **Q:** Default retention of Entra activity logs, and the fix for longer needs?
  **A:** Established default: 30 days (premium editions; 7 days on Free tier). Route via DIAGNOSTIC SETTINGS to a Log Analytics workspace, storage account, or Event Hubs for long retention — multiple diagnostic settings per resource are supported.
- **Q:** Sentinel ingestion licensing nuance?
  **A:** Ingesting SIGN-IN logs into Microsoft Sentinel requires P1 or P2. ANY Entra license (Free/O365/P1/P2) suffices for the OTHER log types (audit etc.). Extra per-GB charges may apply for Log Analytics/Sentinel.
- **Q:** Role prerequisites to connect Entra logs to Sentinel?
  **A:** Microsoft Sentinel Contributor on the workspace, Security Administrator on the source tenant, read/write permission on Entra diagnostic settings. The built-in connector streams sign-in + audit logs.
- **Q:** Recommended integration pattern for third-party SIEMs (Splunk, QRadar, ArcSight)?
  **A:** Route logs via Azure Monitor diagnostic settings to Azure EVENT HUBS; SIEM connectors consume from there (Microsoft's recommended approach going forward). Splunk → Azure Monitor Add-On; QRadar → Microsoft Azure DSM + Event Hubs Protocol; ArcSight → Event Hubs smart connector. AzLog is legacy.
- **Q:** Default audit-log list view fields?
  **A:** Date/time, service that logged the event, category + activity name (what), status (success/failure), target, initiator/actor (who).
- **Q:** Pre-filtered audit entry points and their preset categories?
  **A:** Users blade → UserManagement; Groups blade → GroupManagement; Enterprise applications → ApplicationManagement. Service dropdown includes PIM, Entitlement Management, Access Reviews, Terms of Use, Hybrid Authentication, Identity Protection.
- **Q:** Usage & insights report — location, questions answered, prerequisites?
  **A:** Enterprise applications → Activity → Usage & insights. Answers: most-used apps, apps with most FAILED sign-ins, top sign-in ERRORS per app. Needs Entra ID P1/P2 and Security Administrator / Security Reader / Report Reader.
- **Q:** App-usage and Identity Protection graphs' default windows?
  **A:** Both aggregate WEEKLY over a default period of 30 DAYS (top-three apps on Overview; weekly sign-in graph in Identity Protection).
- **Q:** What are Microsoft Entra workbooks used for?
  **A:** Interactive prebuilt dashboards over log data (e.g., sign-ins, Conditional Access analytics) — the analysis layer once diagnostic settings stream logs to Log Analytics; complements Sentinel queries (KQL excluded from exam scope here).
- **Q:** What is Identity Secure Score?
  **A:** A percentage indicating alignment with Microsoft best-practice identity recommendations. Available in ALL editions (Microsoft Entra ID → Security → Identity Secure Score). Dashboard shows: score, comparison vs. tenants of same industry/similar size, trend graph over time, list of improvement actions tailored to your configuration.
- **Q:** How are secure score controls scored?
  **A:** Binary controls give 100% of their points when configured; others are PARTIAL — proportional to coverage. Example: max 10.71% for protecting all users with MFA, 5 of 100 protected → 5/100 × 10.71% ≈ 0.53%. Score also improves for security TASKS like reading reports.
- **Q:** IP-address-to-location caveat in reports?
  **A:** Best-effort only: VPNs and mobile carriers issue IPs from central pools far from the device — never treat geolocation as definitive.

### Understand-check questions

A user says "I can't sign in since yesterday." Which report, which filters, what latency expectation?
**A:** Sign-ins report (interactive view) filtered by UPN + date range/status Failure/Interrupted; inspect the Conditional Access tab per record. Remember up-to-2-hour ingest lag before concluding absence.

Security wants 12 months of audit history for regulators. Design the pipeline.
**A:** Diagnostic settings on Microsoft Entra ID → send Audit (and Sign-in) logs to a Log Analytics workspace (query/workbooks/Sentinel) or storage account/archive; Event Hub route if Splunk/QRadar/ArcSight must consume. Portal retention alone caps at ~30 days and downloads cap at 250k rows.

Which license combination mistake trips teams wiring Sentinel?
**A:** Assuming any license streams everything: sign-IN logs specifically require P1/P2; other log types stream even from Free. Budget separately for Sentinel/Log Analytics per-GB ingestion.

Audit asks "who added that user to the Payroll group?" Fastest portal path?
**A:** Users/Groups blade audit shortcut (GroupManagement category preselected) or Monitoring → Audit logs filtered Service=All/Category=GroupManagement, Target=group name (case-sensitive), Status=Success — actor appears as Initiator.

Secure Score dropped although nothing was changed by IT. Plausible causes?
**A:** Partial-scored controls recompute as population changes (new unprotected users dilute MFA coverage), tenant size/industry comparison shifts, or improvement actions reset when settings drift. Interpret as trend, not absolute truth.

### Real-world use cases

1. **SaaS outage triage (e-commerce):** Checkout support app shows login failures post-migration. Ops filters sign-ins by application + status Failure, opens CA tab, sees a newly scoped policy failing grant controls, excludes migration service account. Why: sign-in + CA-per-record data pinpoints policy-level cause within minutes despite 2-hour lag on older entries.
2. **Regulatory retention (bank):** Regulator demands 7-year identity audit trail. Diagnostic settings archive audit + sign-in logs to storage with immutable policy, mirror to Log Analytics for querying, Event Hub feed into corporate Splunk via the recommended hub pattern. Why: satisfies retention beyond the 30-day native window without custom scraping.
3. **SOC modernization (insurance):** Alerts buried in mailbox email. Team connects Entra connector to Microsoft Sentinel (P2 already owned), builds analytics rules on risky sign-ins + PIM activation events, uses workbooks for exec reporting and Secure Score trend for quarterly board metrics. Why: unified SIEM/SOAR correlation across identity signals.
4. **License-hygiene program (university):** Semester churn leaves orphaned app usage. Usage & insights report (P1) surfaces apps with zero recent successful sign-ins and top-failure apps; feeds access reviews for cleanup and Secure Score actions for MFA rollout tracking. Why: data-driven decommissioning instead of tribal knowledge.

---

## Exam traps

1. **Eligible vs. Active wording:** Eligible = MUST act to use (activate: MFA/justification/approval); Active = privileges always on. "Permanent administrator" is Entra-role terminology; Azure roles use "Active assignment WITH expiry" (15 days/1 mo/3 mo/6 mo/1 yr/permanent). Zero standing admins is the goal EXCEPT two permanent-GA break-glass accounts.
2. **Reviewer non-response behavior:** Default is "No change" (access KEPT) — not automatic removal. Only "Take recommendations"/explicit rules strip it. Multiple reviewers = LAST submitted decision wins; "Don't know" keeps access but logs. Denied users leave only at period end/admin stop WHEN auto-apply is on.
3. **Four sign-in log types:** Interactive, Non-interactive, Service principal, Managed identity. The portal Sign-ins report shows INTERACTIVE only; non-interactive/service-principal live in their own logs. Records take up to 2 hours; downloads cap at 250,000 rows.
4. **License distinctions:** Entitlement management & PIM → P2. Full access reviews → Entra ID Governance/Suite (some features on P2); reviewers/self/owner-reviewers consume licenses, but Global/User Admins configuring or applying decisions DON'T. Sentinel sign-in ingestion → P1/P2; other log types → ANY edition. Secure Score & sign-in report viewing → all editions.
5. **Guest lifecycle numbers:** External user losing last package assignment → sign-in BLOCKED by default, guest REMOVED after 30 DAYS (configurable; 0 = immediate; only EM-invited guests removed). Blocked guests can't re-request — don't enable blocking for returning partners.
6. **Review timing numbers:** Monthly review max duration = 27 DAYS (overlap avoidance); inactive-users scope up to 730 DAYS; recommendation threshold = no sign-in in 30 DAYS (interactive AND non-interactive); denied-guest block window = 30 DAYS before tenant removal.
7. **Break-glass specifics:** TWO OR MORE cloud-only .onmicrosoft.com accounts, never federated/synced, permanent GA, credentials never expire, at least ONE excluded from phone-based MFA and at least ONE excluded from ALL Conditional Access policies, validated at least every 90 DAYS — and any sign-in should trigger monitoring alerts.
