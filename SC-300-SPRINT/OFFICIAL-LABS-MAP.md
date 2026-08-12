# Official Microsoft SC-300 labs — mapped to the sprint

> **Source:** [`MicrosoftLearning/SC-300-Identity-and-Access-Administrator`](https://github.com/MicrosoftLearning/SC-300-Identity-and-Access-Administrator)
> — the exam author's own lab content. ✅ Provenance and currency checked **2026-08-12**.
> **Local copy:** `C:\Users\patel\Downloads\SC-300-Identity-and-Access-Administrator-master\...\Instructions\Labs`
> ⚠ Move it out of `Downloads` — that folder gets cleared, and this is now a working dependency.

---

## 1. What this is, and what it is not

⭐ **These 28 labs were not generated — they were downloaded.** That matters, and in your favour:
they are written and maintained by Microsoft Learning, they track the course, and MCTs submit
corrections against them. **Trust them well above any generated walkthrough.**

**Currency check across all 29 files:**

| Signal | Count | Read |
|---|---|---|
| "Microsoft Entra" | **255** | ⭐ mostly modernised |
| "Azure AD" / "Azure Active Directory" | 71 | ⚠ **60 of them in Lab_07 alone** (Connect) |
| `entra.microsoft.com` | 34 | ✅ current portal |
| `portal.azure.com` | 8 | ✅ correct — those labs use Azure resources |

⭐ **Lab_07 carries nearly all the legacy naming**, and partly legitimately: the product's own
history is *Azure AD Connect → Microsoft Entra Connect*. Read it with
[`entra-connect-sync`](../35-active-directory-and-hybrid-identity/entra-connect-sync/) open.

---

## 2. ⭐ The gap — and it is exactly where the exam moved

**Checked every lab against the current skills-measured list (as of 27 April 2026):**

| Exam objective | Official lab |
|---|---|
| **Global Secure Access** (clients, Private Access, Internet Access, M365) | ⭐ **NOT COVERED** |
| **Authentication context** | ⭐ **NOT COVERED** |
| **Protected actions** | ⭐ **NOT COVERED** |
| **Continuous access evaluation** | ⭐ **NOT COVERED** |
| **Cross-tenant synchronization** | ⭐ **NOT COVERED** |
| **Custom security attributes** | ⭐ **NOT COVERED** |
| **Temporary Access Pass** | ⭐ **NOT COVERED** |
| Passkeys / FIDO2 | Lab_06 only |

> ⭐ **The official labs lag the April 2026 update by seven named objectives.** They are not wrong —
> they are behind. **Anyone doing "all 28 official labs" and stopping will walk into the exam
> having never touched Global Secure Access, which is an entire subsection.**

⭐ **This is why the two sets are complementary rather than competing:** the official labs give you
Microsoft's own walkthroughs across the breadth; [`DAY-2`](DAY-2.md) and [`DAY-3`](DAY-3.md) cover
the gap, and this sprint adds the **evidence capture** and **deliberate failures** the official
labs do not ask for.

---

## 3. The mapping

⭐ **Azure-dependent labs are marked — all of them are unblocked now the Azure trial exists.**

### Day 1 — baseline, roles, users, groups, licences
| Lab | Notes |
|---|---|
| `Lab_00_SetUpLabResources` | ⚠ Read it, don't follow it blindly — you already have a tenant and `Seed-LabTenant.ps1` |
| `Lab_01_ManageUserRoles` | |
| `Lab_02_WorkingWithTenantProperties` | pairs with [`tenant-architecture`](../40-microsoft-365-platform/tenant-architecture/) |
| `Lab_03_AssignLicensesToUsersByGroupMembership` | ⭐ group-based licensing — the finding from your own Day 0 |
| — | ⭐ **ADD: custom security attributes** (no official lab, named objective) |

### Day 2 — authentication methods, MFA, SSPR
| Lab | Notes |
|---|---|
| `Lab_08_EnableAzureADMultiFactorAuthentication` | |
| `Lab_09_ConfigureAndDeploySelfServicePasswordReset` | |
| `Lab_12_ManageAzureADSmartLockoutValues` | |
| `Lab_15_ConfigureAAD_MultiFactorAuthRegPolicy` | registration campaign |
| — | ⭐ **Temporary Access Pass — no official lab.** [`DAY-2`](DAY-2.md) §2.2 covers it |

### Day 3 — Conditional Access, risk
| Lab | Notes |
|---|---|
| `Lab_13_ImplementAndTestAConditionalAccessPolicy` | |
| `Lab_14_EnableSignRiskPolicy` | ⭐ needs the Day-1 telemetry to have data |
| — | ⭐ **auth context, protected actions, CAE, GSA — [`DAY-3`](DAY-3.md) §3.5** |

### Day 4 — PIM
| Lab | Notes |
|---|---|
| `Lab_26_ConfigurePrivilegedIdentityManagementForAADRoles` | ⭐ the core PIM lab |
| `Lab_11_AssignAzureResourceRolesInPrivilegedIdentityManagement` | ⭐ **needs Azure** — now unblocked |

### Day 5 — governance
| Lab | Notes |
|---|---|
| `Lab_22_CreateAndManageACatalogOfResourcesInAADEntitlementManagement` | |
| `Lab_23_AddTermsOfUseAcceptanceReporting` | |
| `Lab_24_ManageTheLifecycleOfExternalUsersInAADIdentityGovernance` | |
| `Lab_25_CreatingAccessReviewsForUsers` | ⭐ compare its defaults against [`DAY-5`](DAY-5.md) §5.1 |

### Day 6 — apps, consent, workload identity
| Lab | Notes |
|---|---|
| `Lab_19_RegisterAnApplication` | |
| `Lab_20_ImplementAccessManagementForApps` | |
| `Lab_21_GrantTenantWideAdminConsentToAnApplication` | ⭐ do the consent-workflow variant too |
| `Lab_16_UsingAzureKeyVaultForManagedIdentities` | ⭐ **needs Azure** — now unblocked |
| `Lab_17_DefenderForCloudAppsDiscoveryAndRestrictions` | ⭐ needs Day-1 MDCA connector data |
| `Lab_18_DefenderForCloudAppsAccessPolicies` | |

### Day 7 — external identities, monitoring, evidence
| Lab | Notes |
|---|---|
| `Lab_04_ConfigureExternalCollaborationSettings` | |
| `Lab_05_AddGuestUsersToTheDirectory` | |
| `Lab_06_AddFederatedIdentityProvider` | the only passkey/FIDO2 mention |
| `Lab_27_MicrosoftSentinelKustoQueries` | ⭐ **needs Azure** — now unblocked, and it is the SC-200 bridge |
| `Lab_28_MonitorIdentitySecureScore` | ⭐ capture Secure Score **before** Day 1 changes if you still can |
| — | ⭐ **cross-tenant synchronization — no official lab** |

### Deferred — heavier infrastructure
| Lab | Why |
|---|---|
| `Lab_07_AddHybridIdentityWithAzureADConnect` | ⚠ needs a domain controller VM. **Real Azure spend** — budget it, or defer |
| `Lab_10_AzureADAuthenticationForWindowsAndLinuxVM` | ⚠ Azure VMs — cheap, but delete them same-day |

---

## 4. How to run them without wasting the trial

⭐ **Do not follow the official lab and stop.** Each one is a walkthrough with a happy path; the
sprint adds the two things that make it worth your time:

```
① Run the official lab               → Microsoft's own steps, correct and current
② ⭐ BREAK it deliberately            → the sprint's failure drill for that day
③ ⭐ Capture evidence                 → New-LabEvidence.ps1, into the right facet
```

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/pim-and-access-reviews `
  -Facet lab -Name 'official-lab-26-pim-entra-roles' `
  -Note 'Completed Microsoft official Lab_26; captured role settings and an activation with approval' `
  -Command { Get-MgAuditLogDirectoryAudit -Filter "category eq 'RoleManagement'" -Top 20 |
             Select-Object ActivityDateTime, ActivityDisplayName }
```

⚠ **Azure spend guardrails** — the trial credit is finite:

- Set a **budget alert** before deploying anything with a cost
- **Delete Azure resources the same day** unless tomorrow's evidence needs them
- Labs 07 and 10 are the only expensive ones; everything else is identity-plane and free

---

## 5. Honest assessment

**Strengths:** exam-authored, current portal paths in most labs, maintained, and they cover the
breadth of the four domains properly. ⭐ **Better than anything generated.**

**Weaknesses:** ⭐ **seven current objectives uncovered**; Lab_07 carries legacy naming; the labs
are walkthroughs, so they teach *how* and rarely *why it fails*; and `Lab_00` assumes a fresh
tenant you do not have.

⭐ **Use them for coverage. Use the sprint for depth, failure and evidence.** Neither alone gets you
to *"I locked myself out with the default AND operator and recovered with break-glass"*, and that
sentence is what an interview actually buys.
