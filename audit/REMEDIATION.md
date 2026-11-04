# Sangham audit: corrected code patterns
Audit dates: 3–4 November 2026. These are proposed changes, not applied patches. Existing application source remains unchanged. Each block names the finding it addresses. Schema changes require migrations and the regression checks in REPORT.md. Retest the combined implementation; these excerpts are not a claim of a finished production patch.

## A01 — Only the administrator records received cash
Change the repayment route declaration, retain the ownership validation for reads, and remove member-side payment controls. A member may submit a separate pending claim; it must not change money or debt.
~~~js
router.post('/:id/repay', auth, adminOnly, async (req, res) => {
  // Existing handler, replaced by the atomic implementation in A02.
});
~~~
~~~dart
// Member loan-detail screen: replace Pay Interest / Pay Principal buttons.
const Text(
  'Cash repayments are recorded by your Sangham administrator. '
  'Contact the administrator if a receipt is missing.',
);
~~~
The admin action should say “Record cash received” and confirm member, loan, receipt number, cash amount, principal/interest allocation and receipt date.

## A02 — Transactional loan and ledger writes
A snapshot taken after processRepayment is not a rollback. Moving the snapshot earlier still does not solve concurrent updates. Use a MongoDB replica set and a database transaction, loading the loan INSIDE the transaction callback so retries reread the current version. Apply the same pattern to issuance, corrections and their audit records. Do not catch a failed ledger write and continue.

Add loanId to Transaction, and migrate/link existing loan entries before relying on it:
~~~js
loanId: { type: mongoose.Schema.Types.ObjectId, ref: 'Loan' }
~~~
Example repayment core, after auth/admin checks and integer-amount validation:
~~~js
const receipt = await mongoose.connection.transaction(async session => {
  const loan = await Loan.findById(req.params.id).session(session);
  if (!loan) throw Object.assign(new Error('Loan not found'), { status: 404 });
  if (loan.status === 'repaid') {
    throw Object.assign(new Error('Loan already closed'), { status: 409 });
  }

  const due = paymentType === 'principal' ? loan.remainingPrincipal
    : paymentType === 'interest' ? loan.currentMonthInterest
    : loan.remainingPrincipal + loan.currentMonthInterest;
  if (amount > due) {
    throw Object.assign(new Error('Amount exceeds debt'), { status: 400 });
  }

  // First correct processRepayment using A03.
  const { repaymentSummary } = processRepayment(loan, amount, paymentType);
  await loan.save({ session });

  const [entry] = await Transaction.create([{
    userId: loan.userId,
    loanId: loan._id,
    amount,
    type: paymentType === 'interest'
      ? 'loan_interest_payment' : 'loan_repayment',
    note: 'Cash receipt confirmed by administrator',
    date: new Date(),
    createdBy: req.user._id
  }], { session });
  await AuditLog.create([{
    action: 'create', entity: 'transaction', entityId: entry._id,
    newValue: {
      loanId: loan._id, amount,
      principalPaid: repaymentSummary.principalPaid,
      interestPaid: repaymentSummary.interestPaid
    },
    performedBy: req.user._id
  }], { session });
  return { loan, transaction: entry, repaymentSummary };
});
res.status(201).json(receipt);
~~~
This requires imports for mongoose and AuditLog. Add explicit principalPaid/interestPaid fields to receipts rather than storing the allocation only in note text. A04's idempotency record must commit in this SAME transaction, not a separate transaction. Avoid parallel operations inside a MongoDB transaction.

## A03 — Separate assessed interest, outstanding interest and next-period estimates
First agree the group's written policy: monthly boundary, rounding, part-month charges, carry-forward of arrears and waivers. Current code accidentally implements conflicting policies. For the usual policy that already-assessed unpaid interest remains owed, replace the closure/recalculation block in processRepayment:
~~~js
// Do not change assessed interest when principal is paid.
// The interest-payment branches above already subtract paid interest.
if (loan.remainingPrincipal === 0 && loan.currentMonthInterest === 0) {
  loan.status = 'repaid';
  loan.repaidDate = new Date();
} else {
  loan.status = 'active';
  loan.repaidDate = null;
}
loan.outstandingBalance = loan.remainingPrincipal;
// Do not set interestCalculatedDate here: repayment is not monthly accrual.
~~~
Remove the current principal-payment reassessment and the unconditional interest wipe. Rename currentMonthInterest to outstandingInterest during a migration; the current name cannot represent arrears clearly.

Create one interest-assessment record per loan and period:
~~~js
const assessmentSchema = new mongoose.Schema({
  loanId: { type: mongoose.Schema.Types.ObjectId, required: true },
  period: { type: String, required: true }, // agreed Asia/Kolkata YYYY-MM
  amount: { type: Number, required: true, min: 0 }
});
assessmentSchema.index({ loanId: 1, period: 1 }, { unique: true });
const InterestAssessment = mongoose.model('InterestAssessment', assessmentSchema);

async function assessPeriod(loanId, period) {
  return mongoose.connection.transaction(async session => {
    if (await InterestAssessment.exists({ loanId, period }).session(session)) return;
    const loan = await Loan.findById(loanId).session(session);
    if (!loan || loan.status === 'repaid' || loan.remainingPrincipal <= 0) return;
    const charge = calculateMonthlyInterest(loan.remainingPrincipal);
    await InterestAssessment.create([{ loanId, period, amount: charge }], { session });
    loan.currentMonthInterest += charge;
    loan.interestCalculatedDate = new Date();
    await loan.save({ session });
  });
}
~~~
Retry duplicate-key conflicts by checking the existing period record; never assess the same period twice. Backfill each missing period on restart from a durable job/assessment table. A historical period must use that period's principal and stored rate, not today's balance. Consolidate cron and both manual endpoints behind this service. Configure cron's timezone explicitly as Asia/Kolkata. Whole-rupee rounding above preserves the existing convention only; confirm it before launch.

## A04 — Duplicate cash postings and duplicate loan issuance
Add a durable Idempotency-Key contract for every money POST. Store the actor, operation, key, normalized request hash and response in a collection with this unique index:
~~~js
operationSchema.index({ actorId: 1, operation: 1, key: 1 }, { unique: true });
~~~
Inside the SAME database transaction as A02, before mutating money:
~~~js
const existing = await Operation.findOne({
  actorId: req.user._id, operation: 'repay', key
}).session(session);
if (existing) {
  if (existing.requestHash !== requestHash) {
    throw Object.assign(new Error('Key reused for a different request'), { status: 409 });
  }
  return existing.response;
}
// Apply the financial operation here, producing response.
await Operation.create([{
  actorId: req.user._id, operation: 'repay', key, requestHash, response
}], { session });
return response;
~~~
Define Operation's fields explicitly, require a bounded key, hash a canonical normalized payload, and return the committed result on duplicate-key races after rereading it. Do not treat a key alone as authentication. The client retains the same key through a timeout/retry; a new deliberate receipt gets a new key. A short client timeout does not cancel a server commit.

For bulk contributions, require explicit unique IDs; omission/empty must NOT mean all:
~~~js
if (!Array.isArray(memberIds) || memberIds.length === 0 ||
    memberIds.length > 500 ||
    memberIds.some(id => typeof id !== 'string' ||
      !mongoose.isObjectIdOrHexString(id)) ||
    new Set(memberIds).size !== memberIds.length) {
  return res.status(400).json({ message: 'Select unique valid member IDs' });
}
~~~
Validate all target members are active users before inserting. Pass the exact reviewed IDs from Flutter, even when “Select all” was used.

The issue-loan dialog also needs a real in-flight guard; setDialogState(() {}) currently changes nothing:
~~~dart
bool isSubmitting = false; // declared outside StatefulBuilder
// Wrap dialog with PopScope(canPop: !isSubmitting).
onPressed: isSubmitting ? null : () async {
  if (isSubmitting) return;
  // Validate and obtain cash-disbursement confirmation first.
  setDialogState(() => isSubmitting = true);
  try {
    await ApiService.issueLoan(selectedMember!.id, amount, noteCtrl.text.trim());
    if (!ctx.mounted) return;
    Navigator.pop(ctx);
    if (mounted) await _loadLoans();
  } finally {
    if (ctx.mounted) setDialogState(() => isSubmitting = false);
  }
},
~~~
Keep existing error feedback in catch. Add the Idempotency-Key argument/header to ApiService; the UI guard alone does not protect retries or parallel clients.

## A05 — Validate ledger semantics and prevent independent edits
Short-term policy: whole INR only until a paise migration is complete. Define the maximum as a business limit, not an arbitrary infinity:
~~~js
function validAmount(value, max) {
  return typeof value === 'number' && Number.isSafeInteger(value) &&
    value > 0 && value <= max;
}
const allowedManualTypes = new Set(['contribution', 'penalty', 'withdrawal']);
if (!validAmount(amount, MAX_RECEIPT_RUPEES) || !allowedManualTypes.has(type)) {
  return res.status(400).json({ message: 'Invalid amount or transaction type' });
}
const member = await User.findOne({ _id: userId, role: 'user', isActive: true });
if (!member) return res.status(404).json({ message: 'Active member not found' });
const signedAmount = type === 'withdrawal' ? -amount : amount;
~~~
MAX_RECEIPT_RUPEES must be validated configuration agreed with the Sangham. Validate ObjectId and date before the query; limit note length. Loan issuance/repayment types must only be produced through the loan service.

Containment for existing PUT/DELETE endpoints:
~~~js
return res.status(409).json({
  message: 'Posted receipts cannot be edited or deleted; record a correction.'
});
~~~
Then implement an append-only reversal/correction referencing the original receipt, with actor, reason and timestamp, committing debt, receipt and audit together. Do not erase the original. Define whether a member withdrawal reduces their savings; if “balance” is only lifetime contributions, label it explicitly.

## A06 — Credential exposed in Git history
Rotation is an operational fix; no code change can revoke a leaked database password. Revoke the historical database user/credential, replace deployment secrets, verify old credentials fail, inspect access logs, then coordinate history cleanup. The audit deliberately did not test the leaked credential.

Keep the current environment-variable approach, with startup checks:
~~~js
for (const key of ['MONGO_URI', 'JWT_SECRET']) {
  if (!process.env[key]) throw new Error('Missing required setting: ' + key);
}
if (Buffer.byteLength(process.env.JWT_SECRET, 'utf8') < 32) {
  throw new Error('JWT_SECRET must contain at least 32 bytes');
}
~~~
Length checks cannot prove randomness: generate the secret cryptographically. Put no live value in code, reports, logs or command-line arguments. Rotate JWT keys only if exposed or as a planned session reset; the confirmed historical leak was a MongoDB URI.

## A07 — Eliminate phone-derived passwords and throttle authentication
Delete the phone.slice(-4) fallback in both server and Flutter. As immediate containment, require a non-default password on both creation paths. Prefer verified, expiring invitations that let the member choose the password.
~~~js
if (typeof password !== 'string' || [...password].length < 15 ||
    Buffer.byteLength(password, 'utf8') > 72) {
  return res.status(400).json({
    message: 'Use a passphrase of at least 15 characters, within 72 UTF-8 bytes'
  });
}
~~~
The upper byte limit avoids bcrypt's silent truncation; a full solution should migrate to Argon2id so long Unicode passphrases are supported, use a compromised-password blocklist and provide recovery. Do not trim passwords in Flutter. Existing 4-digit accounts must be reset, not grandfathered.

After installing and reviewing express-rate-limit, add a login limiter before the handler:
~~~js
const { rateLimit } = require('express-rate-limit');
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  skipSuccessfulRequests: true
});
router.post('/login', loginLimiter, loginHandler);
~~~
This is a single-instance containment measure. Use a shared store and account-based throttling before scaling; configure the exact trusted proxy topology so forwarded IPs cannot bypass it. Rate-limit invitations/registration and password recovery too. Use MFA for administrators where practical.

## A08 — Close public admission and attendance data exposure
For this single-Sangham cash ledger, the simplest immediate rule is admin-created membership:
~~~js
router.post('/register', auth, adminOnly, registerHandler);
router.get('/today', auth, adminOnly, todayAttendanceHandler);
~~~
Move the existing route bodies to these handlers, keep role fixed to user, and remove public signup navigation. Members already have an owner-checked attendance-history route. If public registration is needed, accounts must remain pending and receive no group data until an invitation and administrator approval are verified. Do not use a client-supplied group ID as authorization.

Group-level financial totals may be intentionally visible to approved members. Document that decision. Do not expose names/phones/individual attendance through a summary endpoint.

## A09 — Revocable sessions and secure mobile persistence
Add tokenVersion to User, default 0, migrate existing users, and issue short-lived access tokens. This simple version invalidates all sessions on logout; per-device session records can replace it later.
~~~js
// User schema
tokenVersion: { type: Number, default: 0 }

// Login
const token = jwt.sign(
  { id: user.id, ver: user.tokenVersion },
  process.env.JWT_SECRET,
  { algorithm: 'HS256', expiresIn: '15m',
    issuer: 'sangham-api', audience: 'sangham-app' }
);

// Middleware, before authorization
const decoded = jwt.verify(token, process.env.JWT_SECRET, {
  algorithms: ['HS256'], issuer: 'sangham-api', audience: 'sangham-app'
});
const user = await User.findOne({ _id: decoded.id, isActive: true });
if (!user || decoded.ver !== user.tokenVersion) {
  return res.status(401).json({ message: 'Session expired' });
}

// Logout route
router.post('/logout', auth, async (req, res) => {
  await User.updateOne({ _id: req.user._id }, { $inc: { tokenVersion: 1 } });
  res.sendStatus(204);
});
~~~
Use a securely random, hashed, rotating refresh-token/session record for usable long sessions; revoke it on logout/reset and detect reuse. Do not simply shorten the token and leave users logging in every 15 minutes.

For Android, replace ALL token reads/writes with a reviewed Keystore-backed secure-storage implementation, including ApiService._getToken:
~~~dart
final storage = FlutterSecureStorage();
await storage.write(key: 'refreshToken', value: refreshToken);
await preferences.remove('token'); // migration cleanup
// Access token stays in memory.
~~~
FlutterSecureStorage is a proposed new dependency, not currently installed. Exclude auth storage from device backups and test restore behavior. For a shipped web client, prefer a same-origin backend session in an HttpOnly, Secure, SameSite cookie, with CSRF protection on writes; do not claim a browser localStorage wrapper protects against XSS.

## A10 — Vulnerable dependencies
Immediate mitigation for the confirmed affected parser configuration:
~~~js
app.use(express.json({ limit: '32kb', inflate: false }));
~~~
The current lockfile contains body-parser 1.20.4; the vendor fixes the compressed-body crash in 1.20.9 / 2.4.0. Update Express's compatible dependency tree; if necessary, use a reviewed override:
~~~json
{
  "overrides": {
    "body-parser": "^1.20.9",
    "proxy-addr": "^2.0.8",
    "path-to-regexp": "^0.1.13"
  }
}
~~~
Then update Mongoose to a patched compatible 8.x (at least 8.24.1 for the reported issue), review qs patches, and migrate node-cron 3 to a supported patched version. Do not apply major upgrades blindly. Regenerate and commit the lockfile; run npm audit --omit=dev and the audit regressions. Audit the dev-only follow-redirects dependency separately. Recheck advisories at implementation time.

## A11 — Make destructive test tooling impossible to point at live data
Apply this BEFORE dotenv/database connection in every destructive seed or remote mutation test. Safer still, have the harness create its own disposable database and pass the URI explicitly:
~~~js
const uri = process.env.MONGO_URI || '';
const parsed = new URL(uri);
const local = ['127.0.0.1', 'localhost', '[::1]'].includes(parsed.hostname);
const testDb = parsed.pathname.startsWith('/sangham_test');
if (process.env.NODE_ENV !== 'test' ||
    process.env.ALLOW_DESTRUCTIVE_TEST_SEED !== 'yes' ||
    !local || !testDb) {
  throw new Error('Destructive seed requires an explicit local test database');
}
~~~
Change e2e-verify.js's seed invocation to supply those flags. Remove the hardcoded Render endpoint from test-loan-flow.js; require an explicit loopback test origin. Its new URL('/auth/login', BASE_URL) also discards /api, and it uses user._id while login returns user.id. Never fix those bugs and then run it against the live endpoint.

## A12 — Android release networking, signing and target SDK
Add this directly under the MAIN manifest root, not just debug/profile:
~~~xml
<uses-permission android:name="android.permission.INTERNET" />
~~~
Replace the debug signing configuration and update the target for a normal phone app submitted to Play:
~~~kotlin
defaultConfig {
    applicationId = "your.owned.namespace.sangham" // choose once before release
    targetSdk = 36
}
signingConfigs {
    create("release") {
        storeFile = file(requireNotNull(System.getenv("SANGHAM_KEYSTORE_PATH")))
        storePassword = requireNotNull(System.getenv("SANGHAM_KEYSTORE_PASSWORD"))
        keyAlias = requireNotNull(System.getenv("SANGHAM_KEY_ALIAS"))
        keyPassword = requireNotNull(System.getenv("SANGHAM_KEY_PASSWORD"))
    }
}
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
~~~
Keep keys outside Git and backups under restricted access. Test Android 16 behavior and Play requirements. A release signed with a debug certificate is NOT the same claim as a debuggable release; this audit confirmed the certificate, not a debuggable flag. An exported launcher activity is expected and was not flagged as a vulnerability.

## A13 — Correct the bulk cash confirmation
Replace the malformed string interpolation and send the reviewed selection, not null/all:
~~~dart
final ids = List<String>.unmodifiable(_selectedIds);
final total = amount * ids.length;
final confirmed = await showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('Confirm cash contributions'),
    content: Text(
      'Record ${_currencyFormat.format(amount)} each for '
      '${ids.length} members?\n\n'
      'Total cash received: ${_currencyFormat.format(total)}',
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false),
        child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(ctx, true),
        child: const Text('Confirm cash received')),
    ],
  ),
);
if (confirmed == true && mounted) {
  await ApiService.addBulkContribution(amount, ids, _noteCtrl.text.trim());
}
~~~
Integrate with the existing submitting/error state and A04's idempotency key. Start with no members selected, or explicit unpaid selection, to avoid posting to everyone twice.

## A14 — Match the loan-detail API contract
Return a number, not a formatted display string, from getLoanDetails:
~~~js
interestRate: loan.interestRate ?? 0.01,
~~~
Use typed decoding and format only at the presentation layer:
~~~dart
final rawRate = loan['interestRate'];
if (rawRate is! num) {
  return const Center(child: Text('Loan data could not be read. Please retry.'));
}
final interestRate = rawRate.toDouble();
~~~
The existing _formatRate multiplies the fractional rate for display. Retest against the actual serialized server response. Do not “fix” this by falling back silently to 1% on malformed financial data.

