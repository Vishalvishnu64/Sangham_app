# Sangham App Changes Explained

Implementation update for the app owner | 4 November 2026

## What this update means

The first implementation batch addresses serious access-control and cash-recording defects found in the audit. Sangham is being tested for Kerala members aged 30 to 65 and records cash transactions; it does not transfer money online.

The changes reduce the risk of members changing their own debt, simultaneous receipts producing incorrect balances, and failed requests leaving partially written loan records. They also fix several visible errors and Android configuration problems.

This is a record of completed local code changes, not a statement that all 36 audit findings are resolved. Nothing has been deployed. Production signing, credential rotation, monthly interest scheduling, session improvements and other work remain outstanding.

## How the cash workflow now works

- An approved administrator creates the member account and supplies a required passphrase. Public self-registration is blocked.

- Members can view loan details, but their payment button is hidden and the server rejects member repayment requests.

- An administrator records cash actually received. Loan and receipt updates commit together, or the operation fails without a partial repayment.

- Posted receipts cannot be independently edited or deleted. A proper correction workflow is still required.

## Important operating changes

Loan transactions require MongoDB running as a replica set. A standalone database will reject these financial writes. Financial endpoints now require positive whole-rupee amounts. Duplicate retries are not yet deduplicated, so do not assume that retrying a timed-out receipt is safe.

Existing member passwords were not automatically reset. No historical balances were migrated or reconciled. Previously saved credentials and existing data need a separate review before real use.

## Cash recording and accounting changes

### Administrator control of repayments

Change: The repayment API requires the administrator role. Member loan screens hide the repayment action.

Reason: A member previously could mark their own loan repaid without confirmation that cash had been received. Server enforcement protects the record even if someone bypasses the screen.

Files: server/routes/loans.js; lib/screens/user/loan_details_screen.dart

### Atomic loan and receipt updates

Change: Loan issuance and repayment use database transactions. Repayments load the loan inside the transaction; repayment receipts include loan ID and principal and interest allocation.

Reason: Concurrent updates previously lost balance changes. A failed receipt insert could still reduce debt. Related financial writes must succeed together. Full audit-log integration remains outstanding.

Files: server/routes/loans.js; server/models/Transaction.js

### Preserving already assessed interest

Change: Paying principal no longer recalculates current assessed interest. A loan closes only when both principal and assessed interest are zero.

Reason: Paid interest previously reappeared after a principal payment, and a principal payoff could silently erase unpaid interest. Monthly accrual and waiver policy still need separate implementation.

Files: server/utils/loanInterest.js

### Validating manual cash entries

Change: Single receipts require an active member, a positive whole-rupee amount and an allowed manual type. Withdrawals are stored with a negative sign. Bulk contributions require explicit, unique, active member IDs, with a maximum batch of 500.

Reason: Negative contributions, duplicate member IDs and manually invented loan repayments could distort cash totals. An empty list no longer means all members.

Files: server/routes/transactions.js; lib/screens/admin/add_contribution_screen.dart

### Protecting posted receipts

Change: Independent receipt edit and delete endpoints return a conflict response.

Reason: Changing a receipt separately from its loan can make the cash book and debt book disagree. This is containment; an append-only reversal and correction workflow is not yet built.

Files: server/routes/transactions.js

## Access and application changes

### Controlled membership and passwords

Change: Registration requires an administrator. The login screen directs new users to their administrator. Phone-derived default passwords were removed; creation requires a valid Indian mobile number and a passphrase of at least 15 characters within 72 UTF-8 bytes.

Reason: The previous last-four-phone-digits password was predictable. Public signup admitted unapproved accounts. The byte limit avoids bcrypt truncation; recovery, invitations and stronger session controls remain pending.

Files: server/routes/auth.js; server/routes/members.js; login_screen.dart; members_screen.dart

### Attendance and API protection

Change: Today’s full attendance roster is administrator-only. Bulk attendance checks statuses, ID shape, array size and date validity. Login rejects non-string credentials and invalid phone formats.

Reason: These changes reduce roster disclosure and prevent the demonstrated query-operator login input and invented attendance status. Full cross-record validation is still needed.

Files: server/routes/attendance.js; server/routes/auth.js

### Safer server and test defaults

Change: JSON requests are limited to 32 KB and compressed-body inflation is disabled. Production no longer allows every browser origin when its allowlist is empty. Destructive seeds require an explicit local test database and authorization flag.

Reason: This contains the parser issue and accidental database-wipe risk. Dependency upgrades are still needed. Existing test harness seed settings must be updated to satisfy the new guards.

Files: server/server.js; server/seed.js; server/seed_ux.js

### Loan detail and confirmation repairs

Change: The API returns a numeric interest rate. Bulk contribution confirmation formats the amount and total correctly.

Reason: Loan details previously threw a type error. The confirmation previously displayed formatter expressions instead of readable money.

Files: server/utils/loanInterest.js; lib/screens/admin/add_contribution_screen.dart

### Small usability fixes

Change: Attendance timestamps convert to local time before choosing the calendar day. History checks whether its screen is still mounted. Login preserves password whitespace and labels its visibility toggle.

Reason: These address previous-day calendar markers, updates to a disposed screen, altered passwords and an unnamed accessibility control. Date-only attendance storage and broader accessibility work remain pending.

Files: attendance_calendar.dart; history_screen.dart; login_screen.dart

## Android release changes

The main Android manifest now declares INTERNET permission, and targetSdk changed from 34 to 36. The previous release APK lacked permission to call the API. Updating the target prepares the app for newer platform requirements, but does not by itself establish device compatibility or store readiness.

Production signing has not been configured. The earlier audit built and inspected the old APK; a new release build and real-device test are still required after these changes.

## What was verified

- Flutter static analysis completed with no issues after the client changes.

- A new disposable MongoDB replica-set regression test confirmed that a member repayment receives HTTP 403.

- Eight simultaneous administrator receipts of 100 rupees reduced a 10000-rupee principal to exactly 9200 rupees.

- An injected receipt-write failure left principal unchanged, confirming repayment rollback.

- The regression test confirmed that paid interest remains zero after a subsequent principal payment and that the API rate is numeric.

- JavaScript syntax checks passed for the modified loan, transaction and attendance routes. The later transaction and attendance validation additions have not received the same depth of behavioral testing.

Regression script: audit/fix-regression.cjs. The old audit probes intentionally characterize defects and should not be treated as acceptance tests for the corrected app. The original 59-test suite also contains expectations that now conflict with the safer behavior.

## Work still required

- Accounting: receipt idempotency, monthly interest assessments with restart recovery, immutable correction receipts, comprehensive audit logs, and historical reconciliation.

- Security: revoke the historical database credential, reset weak accounts, add login throttling and recovery, implement revocable sessions and secure mobile token storage, and upgrade affected dependencies.

- Release and operations: production signing, deployment configuration, full regression and release-device testing, staging separation, monitoring, and a demonstrated backup restore.

- User experience: Malayalam, contrast and text sizing, responsive layouts, session-expiry navigation, stale-data refresh, complete history, receipt export and administrator support.

- Privacy: publish notices and retention rules, establish account deletion and export processes, and decide store distribution requirements.

Before real cash use, agree the group’s interest and withdrawal rules, complete the remaining financial controls, and reconcile the test ledger against independently recorded receipts.
