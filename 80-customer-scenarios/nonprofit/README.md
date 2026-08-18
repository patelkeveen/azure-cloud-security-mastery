# Nonprofit

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **Boundary:** [`../LAYER-7-INDUSTRY-VERTICALS.md`](../LAYER-7-INDUSTRY-VERTICALS.md) §10 is the
> brief. ⭐ **This is engagement depth — the vertical where the binding constraint is that nobody
> will operate what you build.** Pairs with
> [`../../75-architecture-and-consulting/handover/`](../../75-architecture-and-consulting/handover/).

---

## 1. What it is

Identity engineering for charities, NGOs and community organisations: small or no IT function,
volunteers alongside staff, trustees with email but no supervision, ⭐ **grant or donated
licensing**, and often genuinely sensitive data — beneficiary records, safeguarding case notes,
donor details.

⭐ **The constraint is not budget. It is that there is no operations team, and there never will
be.**

---

## 2. Why it is different

⭐ **In every other vertical you design for what the customer needs. Here you design for what will
still be working in two years with nobody maintaining it.**

| Standard assumption | ⭐ Nonprofit reality |
|---|---|
| There is an IT team | ⭐ **a part-time office manager, or a volunteer** |
| Someone reviews alerts | ⭐ **nobody. ⭐ Alerts go to an unread mailbox** |
| Access reviews run quarterly | ⭐ **the reviewer is the same person who requested it** |
| Staff are permanent | ⭐ **volunteers churn constantly; ⭐ nobody records departures** |
| Data is commercial | ⭐ **safeguarding and beneficiary data — ⭐ often more sensitive than a bank's** |
| Change is managed | ⭐ **a trustee's nephew "helped with the website"** |

⭐ **The sensitivity mismatch is the point that reframes the engagement.** ⭐ **A domestic-abuse
charity's client list is more dangerous if leaked than most corporate data**, and it is typically
protected by a shared mailbox password and goodwill. ⭐ **Saying this plainly, without condescension,
is how the conversation gets serious.**

---

## 3. How it works underneath — design for zero maintenance

```
   ⭐ THE TEST FOR EVERY CONTROL:
   ⭐ "Will this still be correct in two years if nobody touches it?"

   ✗ ⭐ FAILS THE TEST                  ✅ ⭐ PASSES THE TEST
   ────────────────────────           ────────────────────────
   ⭐ quarterly access reviews         ⭐ access packages that EXPIRE
     (nobody will run them)             (⭐ removal happens by itself)

   ⭐ alerts to a shared mailbox       ⭐ conditional access that BLOCKS
     (nobody reads it)                  (⭐ prevention, not detection)

   ⭐ "review the admin list yearly"   ⭐ PIM with time-bound activation
                                        (⭐ standing access cannot accumulate)

   ⭐ a documented offboarding SOP     ⭐ HR/roster-driven, or
     (there is no HR)                   ⭐ EXPIRY DATES on every volunteer account
```

⭐ **The principle: prefer controls that fail closed and expire by themselves over controls that
require a human to act.** ⭐ **Detection is worthless where nobody is watching; prevention and
expiry are not.**

⭐ **This inverts standard advice deliberately.** In a mature organisation, blocking rather than
alerting is heavy-handed. ⭐ **Here, an alert nobody reads is indistinguishable from no control at
all** — which is the same *"deployed is not enforced"* pattern arriving through the staffing door.

---

## 4. Worked example — expiry instead of review

⭐ **The volunteer problem: people help for six months and then stop, and nobody tells anyone.**

```powershell
# ⭐ Access package with a hard expiry - ⭐ the control operates itself
$policy = @{
  displayName = 'Volunteer access - 6 months'
  accessPackageId = $pkgId
  ⭐ expiration = @{ type = 'afterDuration'; duration = 'P180D' }   # ⭐ 180 days
  requestApprovalSettings = @{
    isApprovalRequired = $true
    approvalStages = @(@{ approvalStageTimeOutInDays = 14
                          primaryApprovers = @(@{ '@odata.type' = '#microsoft.graph.groupMembers'
                                                  groupId = $trusteeGroupId }) }) }
}
New-MgEntitlementManagementAccessPackageAssignmentPolicy -BodyParameter $policy
```

⭐ **`P180D` is the whole control.** ⭐ **In six months the access disappears whether or not anyone
remembered, whether or not the volunteer is still active, and whether or not the charity still has
the same office manager.** A volunteer who is still helping simply requests an extension — ⭐ **which
is a positive confirmation that they are still there, obtained for free.**

⭐ **Compare with the alternative:** a quarterly access review assigned to a trustee who checks email
weekly, does not know most of the volunteers, and will approve everything to clear the notification.
⭐ **That review produces a compliant-looking record and removes nobody.**

**Find what has already accumulated — ⭐ the first-visit query:**

```powershell
# ⭐ Who holds admin roles, and has anyone forgotten they do?
Get-MgDirectoryRole -All | ForEach-Object {
  $r = $_
  Get-MgDirectoryRoleMember -DirectoryRoleId $_.Id -All | ForEach-Object {
    $u = Get-MgUser -UserId $_.Id -Property UserPrincipalName,SignInActivity -ErrorAction SilentlyContinue
    if ($u) { [pscustomobject]@{ Role = $r.DisplayName; User = $u.UserPrincipalName
              LastSignIn = $u.SignInActivity.LastSignInDateTime } }
  }
} | Sort-Object LastSignIn
```

```
Role                    User                          LastSignIn
Global Administrator    consultant@webagency.example  2023-06-14   ⭐ ← ⭐ 2 YEARS
Global Administrator    admin@charity.org
Global Administrator    trustee.j@charity.org         2026-08-11
```

⭐ **A web agency's consultant holding Global Administrator, last seen two years ago, is the single
most common finding in this vertical** — and it is not malice. ⭐ **Someone helped set up the tenant
in 2023, was given the highest role because it was quickest, and nobody had a process to remove
it.**

⭐ **The blank `LastSignIn` on `admin@charity.org` is the second finding: a shared administrative
account that everyone uses and nobody owns.** ⭐ **Converting that into named accounts is usually the
highest-value hour of the entire engagement**, because it makes every subsequent audit trail
meaningful.

---

## 5. Licensing — ⭐ and the honesty this vertical deserves

⭐ **Microsoft offers nonprofit grants and discounts, and the terms have changed.** ⚠ `⚠ check` —
⭐ **the grant structure was revised in 2025; do not quote seat counts or SKUs from memory.**
⭐ **Verify current eligibility and entitlements at the time of the engagement**, because advising a
charity to plan around a grant that no longer exists is a real harm, not a footnote.

⭐ **What to do with the uncertainty:**

| Step | Why |
|---|---|
| ⭐ Check current grant terms **before** designing | ⭐ the design depends on which features are available |
| ⭐ Design to the **lowest** tier they reliably hold | ⭐ a P2-dependent design fails if the grant lapses |
| ⭐ Document what breaks if the grant changes | ⭐ they will not notice until something stops working |
| ⭐ Prefer free controls | ⭐ security defaults, ⭐ MFA, ⭐ restricting consent cost nothing |

⭐ **Security defaults deserve serious consideration here rather than dismissal.** ⭐ **For an
organisation with no operations capability, security defaults deliver most of the baseline with zero
maintenance** — and a hand-built Conditional Access estate that nobody can adjust is worse than the
managed option. ⭐ **Recommending the simpler thing when it fits is a senior judgement, not a
cop-out.**

⭐ **The trade to state explicitly:** security defaults cannot be tailored, so the moment the charity
needs one exception, the answer is to move to Conditional Access properly — ⭐ **and that is the
moment to have the conversation, not before.**

---

## 6. Design reference

| Control | Setting | ⭐ Nonprofit reason |
|---|---|---|
| Baseline | ⭐ **security defaults** if no operations capability | ⭐ zero maintenance |
| ⭐ Admin roles | ⭐ **named accounts, no shared admin** | ⭐ makes every audit trail meaningful |
| ⭐ Volunteers | ⭐ **access packages with hard expiry** | ⭐ removal without a human |
| Third parties | ⭐ **B2B guest, time-bound — ⭐ never a member account** | ⭐ the web agency problem |
| ⭐ Trustees | ⭐ mail only; ⭐ **no admin roles** | ⭐ well-meaning, unsupervised |
| MFA | ⭐ everyone, ⭐ including volunteers | ⭐ free, and the highest-value control |
| Sensitive data | ⭐ a small number of clearly-labelled locations | ⭐ simple beats complete |
| Handover | ⭐ **one page, ⭐ plus a self-check script** | ⭐ [`../../75-architecture-and-consulting/customer-training/`](../../75-architecture-and-consulting/customer-training/) |

⭐ **"Simple beats complete" is the governing rule.** ⭐ **A three-label sensitivity scheme that staff
actually apply protects more than a twelve-label taxonomy that nobody uses** — and in an
organisation with no IT function, the second one is guaranteed.

---

## 7. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| ⭐ Ex-supplier still Global Admin | ⭐ no removal process | ⭐ guests with expiry, ⭐ never member admins |
| ⭐ Shared admin account | ⭐ expedient at setup | ⭐ named accounts — ⭐ first hour's work |
| Access reviews approved blindly | ⭐ reviewer does not know the people | ⭐ expiry instead of review |
| Alerts unread for a year | ⭐ no one is watching | ⭐ prevention over detection |
| ⭐ Design broke when the grant changed | ⭐ built on an assumed licence | ⭐ design to the lowest reliable tier |
| ⭐ Volunteer left, ⭐ access remained | no offboarding | ⭐ expiry dates on every volunteer account |
| Nobody can operate it | ⭐ built for an IT team that does not exist | ⭐ the two-year test (§3) |

⭐ **The last row is the failure that matters most, and it is entirely the consultant's fault.**
⭐ **A sophisticated design handed to an organisation that cannot run it degrades within months and
leaves them worse off than a simple one** — because they now believe they are protected.

---

## 8. Customer discovery questions

1. ⭐ **"Who will look after this after we finish — a person, by name?"**
2. ⭐ **"Does anyone outside the organisation have administrative access?"**
3. "How do volunteers get access, and how does it stop?"
4. ⭐ **"What is the most sensitive information you hold, and where is it?"**
5. "Which licences do you hold today, and under what grant or discount?"
6. ⭐ **"If something suspicious happened, who would notice, and how?"**
7. ⭐ **"Are trustees using their own email or an organisational account?"**

---

## 9. Remember it

**Hook — ⭐ the **two-year test**: will this still be correct in two years if nobody touches it?**
⭐ **If not, choose a control that expires by itself.**

**Analogy — a village hall with one key-holder.** ⭐ **You do not install a system needing a
facilities manager; you fit a door that locks behind you and a booking system that expires.** The
analogy predicts every rule: ⭐ **prevention over detection because nobody is watching the CCTV**,
⭐ **expiry over review because nobody will audit the key register**, and ⭐ **the sophisticated
system installed by a well-meaning volunteer becomes the thing nobody can fix** when they move away.

**The one line:** ⭐ **Choose controls that operate themselves — expiry over review, prevention over
alerting — and design to the licence they will still have if the grant changes.**

---

## 10. Self-test

1. What is the binding constraint in this vertical?
   → ⭐ No operations capability — nobody will run what requires running.
2. State the two-year test.
   → ⭐ Will this still be correct in two years if nobody touches it?
3. Why prefer prevention over detection here?
   → ⭐ An alert nobody reads is indistinguishable from no control.
4. Why is an access package with `P180D` better than a quarterly review?
   → ⭐ Removal happens without a human, and renewal is positive confirmation the person is still there.
5. The most common finding in a nonprofit tenant?
   → ⭐ An external supplier still holding Global Administrator, unused for years.
6. When are security defaults the right recommendation?
   → ⭐ When there is no operations capability; zero maintenance beats an unmaintainable CA estate.
7. Why can a sophisticated design leave a charity worse off?
   → ⭐ It degrades unmaintained while they believe they are protected.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | ⭐ the admin-role query, showing any external or dormant holders |
| `security` | ⭐ shared admin account replaced with named accounts, with the date |
| `operations` | an access package with a hard expiry, and one expiry observed |
| `customer-use-cases` | ⭐ the one-page handover plus a self-check script |
| `architecture-decisions` | ⭐ the licence-tier assumption, and what breaks if the grant changes |
