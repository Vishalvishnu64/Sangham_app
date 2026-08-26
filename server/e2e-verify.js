/**
 * Phase-1 verification harness (local E2E).
 * Boots an in-memory MongoDB, seeds it with the real seed.js, spawns
 * server.js locally and exercises auth/members/attendance/contribution/loan
 * flows plus the Phase-1 security fixes.
 *
 * Run:  node e2e-verify.js
 */
const { spawn } = require('child_process');
const mongoose = require('mongoose');

const PORT = 5001;
const CORS_PORT = 5002;
const BASE = `http://localhost:${PORT}/api`;
const CORS_BASE = `http://localhost:${CORS_PORT}/api`;
const JWT_SECRET = 'e2e-verify-secret-not-used-in-prod';

let mongo;
let serverProc;
let corsProc;
let db;

/** @type {{group:string,name:string,pass:boolean,detail?:string}[]} */
const results = [];

function check(group, name, pass, detail = '') {
  results.push({ group, name, pass, detail });
  console.log(`${pass ? 'PASS' : 'FAIL'} [${group}] ${name}${detail ? ' | ' + detail : ''}`);
}

async function api(base, method, path, { token, body, headers } = {}) {
  const res = await fetch(base + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(headers || {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch (_) { data = text; }
  return { status: res.status, data, headers: res.headers };
}

async function waitForHealth(base, label, timeoutMs = 90000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const r = await fetch(base + '/health');
      if (r.ok) { console.log(`${label} is up`); return; }
    } catch (_) { /* not up yet */ }
    await new Promise(r => setTimeout(r, 500));
  }
  throw new Error(`${label} did not become healthy in ${timeoutMs}ms`);
}

function runNode(script, env, timeoutMs = 120000) {
  return new Promise((resolve) => {
    let out = '';
    const p = spawn(process.execPath, [script], {
      cwd: __dirname,
      env: { ...process.env, ...env },
    });
    const timer = setTimeout(() => { p.kill(); resolve({ code: -1, out }); }, timeoutMs);
    p.stdout.on('data', d => { out += d.toString(); });
    p.stderr.on('data', d => { out += d.toString(); });
    p.on('exit', code => { clearTimeout(timer); resolve({ code, out }); });
  });
}

async function main() {
  // ─── Boot infrastructure ────────────────────────────────────────────
  const { MongoMemoryServer } = require('mongodb-memory-server');
  console.log('Starting in-memory MongoDB...');
  mongo = await MongoMemoryServer.create();
  const uri = mongo.getUri('sangham_test');
  console.log('MongoDB ready');

  // Connect a control connection so tests can inspect raw collections.
  db = await mongoose.createConnection(uri).asPromise();

  // Seed using the REAL seed script against the throwaway DB.
  const seeded = await runNode('seed.js', { MONGO_URI: uri, NODE_ENV: 'development' });
  check('setup', 'seed.js completes in development mode', seeded.code === 0,
    seeded.code === 0 ? '' : seeded.out.slice(-200));

  // Main server under test.
  serverProc = spawn(process.execPath, ['server.js'], {
    cwd: __dirname,
    env: { ...process.env, MONGO_URI: uri, JWT_SECRET, PORT: String(PORT), NODE_ENV: 'development' },
  });
  serverProc.stderr.on('data', d => process.stderr.write('[srv] ' + d));
  await waitForHealth(BASE, 'API server');

  // ═══════════════════════ AUTH / SECURITY ════════════════════════════
  const G = 'auth-security';

  // Health + unauthenticated access
  const health = await api(BASE, 'GET', '/health');
  check(G, 'health endpoint responds ok', health.status === 200 && health.data?.status === 'ok');

  const noTok = await api(BASE, 'GET', '/members');
  check(G, 'protected route without token -> 401 JSON message', noTok.status === 401 && typeof noTok.data?.message === 'string',
    JSON.stringify(noTok.data));

  // Registration: role escalation attempt
  const uniq = Date.now().toString().slice(-6);
  const testPhone = `700000${uniq}`.slice(-10);
  let reg = await api(BASE, 'POST', '/auth/register', {
    body: { name: 'E2E Test Member', phone: testPhone, password: 'testpass123', role: 'admin' },
  });
  check(G, 'register succeeds', reg.status === 201 && !!reg.data?.user, JSON.stringify(reg.data));
  check(G, 'ROLE STRIP: role:"admin" in body lands as "user"', reg.data?.user?.role === 'user',
    `got role=${reg.data?.user?.role}`);

  const dbUser = await db.collection('users').findOne({ phone: testPhone });
  check(G, 'ROLE STRIP persisted in DB', dbUser?.role === 'user', `db role=${dbUser?.role}`);

  // Duplicate phone
  reg = await api(BASE, 'POST', '/auth/register', {
    body: { name: 'Dup', phone: testPhone, password: 'testpass123' },
  });
  check(G, 'duplicate phone rejected 400', reg.status === 400, JSON.stringify(reg.data));

  // Weak password
  reg = await api(BASE, 'POST', '/auth/register', {
    body: { name: 'Weak', phone: `71${uniq}00`.slice(-10), password: '123' },
  });
  check(G, 'short password (<6) rejected 400', reg.status === 400, JSON.stringify(reg.data));

  // Login failures / success
  const badLogin = await api(BASE, 'POST', '/auth/login', { body: { phone: testPhone, password: 'wrongpass' } });
  check(G, 'bad password login -> 400 with message', badLogin.status === 400 && typeof badLogin.data?.message === 'string');

  const memLogin = await api(BASE, 'POST', '/auth/login', { body: { phone: testPhone, password: 'testpass123' } });
  check(G, 'member login returns token+user', memLogin.status === 200 && !!memLogin.data?.token);
  const memToken = memLogin.data?.token;
  const memId = memLogin.data?.user?.id || memLogin.data?.user?._id;

  const me = await api(BASE, 'GET', '/auth/me', { token: memToken });
  check(G, '/auth/me round-trip', me.status === 200 && me.data?.user?.phone === testPhone);

  const admLogin = await api(BASE, 'POST', '/auth/login', { body: { phone: '9999999999', password: 'admin123' } });
  check(G, 'seeded admin login', admLogin.status === 200 && admLogin.data?.user?.role === 'admin');
  const admToken = admLogin.data?.token;

  // Seeded member login (from seed.js output contract)
  const seedMem = await api(BASE, 'POST', '/auth/login', { body: { phone: '9876500000', password: '0000' } });
  check(G, 'seeded member login (9876500000/0000)', seedMem.status === 200 && seedMem.data?.user?.role === 'user');
  const seedToken = seedMem.data?.token;

  // Member forbidden from admin routes
  const forb = await api(BASE, 'GET', '/dashboard/admin', { token: memToken });
  check(G, 'member blocked from admin dashboard 403', forb.status === 403, JSON.stringify(forb.data));

  // ═══════════════════════ MEMBERS ════════════════════════════════════
  const GM = 'members';

  const mkRes = await api(BASE, 'POST', '/members', {
    token: admToken, body: { name: 'Admin Made Member', phone: `72${uniq}11`.slice(-10), password: 'mmmm66' },
  });
  check(GM, 'admin creates member 201', mkRes.status === 201 && !!mkRes.data?.member, JSON.stringify(mkRes.data));
  const madeId = mkRes.data?.member?.id;

  const auditCreate = await db.collection('auditlogs').findOne({ entity: 'user', action: 'create', entityId: new mongoose.Types.ObjectId(madeId) });
  check(GM, 'AuditLog written for member create', !!auditCreate);

  const updRes = await api(BASE, 'PUT', `/members/${madeId}`, {
    token: admToken, body: { name: 'Renamed Member' },
  });
  check(GM, 'admin edits member', updRes.status === 200 && updRes.data?.member?.name === 'Renamed Member');
  const auditEdit = await db.collection('auditlogs').findOne({ entity: 'user', action: 'edit', entityId: new mongoose.Types.ObjectId(madeId) });
  check(GM, 'AuditLog written for member edit', !!auditEdit);

  const listRes = await api(BASE, 'GET', '/members', { token: admToken });
  const listedMember = (listRes.data?.members || []).find(m => m._id === madeId || m.id === madeId);
  check(GM, 'GET /members includes new member with balance field', listRes.status === 200 && listedMember && typeof listedMember.balance === 'number');
  check(GM, 'passwords never leak in member list', listedMember && !('password' in listedMember));

  // ═══════════════════════ CONTRIBUTIONS ══════════════════════════════
  const GC = 'contributions';

  // Fresh user starts in notPaid this week
  const wkBefore = await api(BASE, 'GET', '/transactions/weekly-status', { token: admToken });
  const beforePaid = (wkBefore.data?.paid || []).some(m => m.id === memId || m._id === memId);
  const beforeNotPaid = (wkBefore.data?.notPaid || []).some(m => m.id === memId || m._id === memId);
  check(GC, 'weekly-status shape {paid[],notPaid[]}', Array.isArray(wkBefore.data?.paid) && Array.isArray(wkBefore.data?.notPaid));
  check(GC, 'fresh user listed as NOT PAID', !beforePaid && beforeNotPaid);

  const singleAdd = await api(BASE, 'POST', '/transactions', {
    token: admToken, body: { userId: memId, amount: 50, type: 'contribution', note: 'e2e single' },
  });
  check(GC, 'single contribution recorded 201', singleAdd.status === 201);

  const bulkAll = await api(BASE, 'POST', '/transactions/bulk', {
    token: admToken, body: { amount: 25, type: 'contribution', note: 'e2e bulk all' },
  });
  check(GC, 'bulk contribution (all members) reports count', bulkAll.status === 201 && typeof bulkAll.data?.count === 'number' && bulkAll.data.count >= 10,
    `count=${bulkAll.data?.count}`);

  const bulkSome = await api(BASE, 'POST', '/transactions/bulk', {
    token: admToken, body: { amount: 10, memberIds: [memId], type: 'contribution', note: 'e2e bulk subset' },
  });
  check(GC, 'bulk contribution (subset) count=1', bulkSome.status === 201 && bulkSome.data?.count === 1);

  const wkAfter = await api(BASE, 'GET', '/transactions/weekly-status', { token: admToken });
  const afterPaid = (wkAfter.data?.paid || []).some(m => m.id === memId || m._id === memId);
  check(GC, 'weekly-status flips user to PAID after contribution', afterPaid);

  const balCheck = (list => (list.find(m => m._id === memId || m.id === memId) || {}).balance)(listRes.status === 200 ? (await api(BASE, 'GET', '/members', { token: admToken })).data.members : []);
  check(GC, 'member balance reflects 50+10 (+25 if counted)', balCheck >= 60, `balance=${balCheck}`);

  // Member self-transactions readable; other users' forbidden
  const ownTx = await api(BASE, 'GET', `/transactions/user/${memId}`, { token: memToken });
  check(GC, 'user reads own transactions w/ running balance', ownTx.status === 200 && Array.isArray(ownTx.data?.passbook) && 'runningBalance' in (ownTx.data.passbook[0] || {}));
  const foreignTx = await api(BASE, 'GET', `/transactions/user/${memId}`, { token: seedToken });
  check(GC, 'other member denied foreign transactions 403', foreignTx.status === 403);

  // ═══════════════════════ ATTENDANCE ═════════════════════════════════
  const GA = 'attendance';

  const attDate = new Date().toISOString();
  const bulkAtt = await api(BASE, 'POST', '/attendance/bulk', {
    token: admToken,
    body: { records: [{ userId: memId, status: 'present' }, { userId: madeId, status: 'absent' }], date: attDate },
  });
  check(GA, 'bulk attendance marked', bulkAtt.status === 200 && /marked for 2/.test(bulkAtt.data?.message || ''), JSON.stringify(bulkAtt.data));

  const today = await api(BASE, 'GET', '/attendance/today', { token: memToken });
  check(GA, '/attendance/today shape {records,totalMembers,presentCount}', today.status === 200 && Array.isArray(today.data?.records) && typeof today.data.totalMembers === 'number');
  const myToday = (today.data.records || []).find(r => (r.userId?._id || r.userId)?.toString?.() === memId);
  check(GA, 'today record shows member PRESENT', myToday?.status === 'present');

  const now = new Date();
  const hist = await api(BASE, 'GET', `/attendance/user/${memId}?month=${now.getMonth() + 1}&year=${now.getFullYear()}`, { token: memToken });
  const st = hist.data?.stats || {};
  check(GA, 'attendance history stats math consistent',
    hist.status === 200 && st.totalPresent + st.totalAbsent === st.total &&
    st.consistency === (st.total > 0 ? Math.round(st.totalPresent / st.total * 100) : 0),
    JSON.stringify(st));

  const foreignAtt = await api(BASE, 'GET', `/attendance/user/${memId}`, { token: seedToken });
  check(GA, 'other member denied foreign attendance 403', foreignAtt.status === 403);

  // ═══════════════════════ LOANS ══════════════════════════════════════
  const GL = 'loans';

  const issue = await api(BASE, 'POST', '/loans', {
    token: admToken, body: { userId: memId, amount: 10000, note: 'e2e loan' },
  });
  const loanId = issue.data?.loan?._id;
  check(GL, 'issue loan 201', issue.status === 201 && !!loanId);
  check(GL, 'initial interest exactly 1% (100 of 10000)', issue.data?.loan?.currentMonthInterest === 100,
    `interest=${issue.data?.loan?.currentMonthInterest}`);

  const negIssue = await api(BASE, 'POST', '/loans', { token: admToken, body: { userId: memId, amount: -5 } });
  check(GL, 'negative loan amount rejected 400', negIssue.status === 400);
  const memIssue = await api(BASE, 'POST', '/loans', { token: memToken, body: { userId: memId, amount: 100 } });
  check(GL, 'non-admin cannot issue loan 403', memIssue.status === 403);

  const details = await api(BASE, 'GET', `/loans/${loanId}/details`, { token: memToken });
  check(GL, 'loan details: principal 10000, interest 100, active',
    details.status === 200 && details.data?.remainingPrincipal === 10000 && details.data?.currentMonthInterest === 100 && details.data?.status === 'active');

  // Interest-only partial payment: no principal change, NO recalculation
  const payInt1 = await api(BASE, 'POST', `/loans/${loanId}/repay`, { token: memToken, body: { amount: 40, paymentType: 'interest' } });
  check(GL, 'interest-only pay 40 -> interestPaid=40', payInt1.status === 200 && payInt1.data?.repaymentSummary?.interestPaid === 40);
  const d1 = await api(BASE, 'GET', `/loans/${loanId}/details`, { token: memToken });
  check(GL, 'after interest-only: principal unchanged 10000, interest 60 (not recalculated)',
    d1.data?.remainingPrincipal === 10000 && d1.data?.currentMonthInterest === 60 && d1.data?.totalInterestPaid === 40,
    `p=${d1.data?.remainingPrincipal} i=${d1.data?.currentMonthInterest}`);

  // Principal payment triggers dynamic recalculation
  const payPrin = await api(BASE, 'POST', `/loans/${loanId}/repay`, { token: memToken, body: { amount: 3000, paymentType: 'principal' } });
  check(GL, 'principal repay 3000 accepted', payPrin.status === 200 && payPrin.data?.repaymentSummary?.principalPaid === 3000);
  const d2 = await api(BASE, 'GET', `/loans/${loanId}/details`, { token: memToken });
  check(GL, 'dynamic recalc: principal 7000 -> interest 70', d2.data?.remainingPrincipal === 7000 && d2.data?.currentMonthInterest === 70,
    `p=${d2.data?.remainingPrincipal} i=${d2.data?.currentMonthInterest}`);

  // Validation guards
  const overPrin = await api(BASE, 'POST', `/loans/${loanId}/repay`, { token: memToken, body: { amount: 99999, paymentType: 'principal' } });
  check(GL, 'principal overpay rejected 400', overPrin.status === 400 && /exceeds/i.test(overPrin.data?.message || ''));
  const overInt = await api(BASE, 'POST', `/loans/${loanId}/repay`, { token: memToken, body: { amount: 5000, paymentType: 'interest' } });
  check(GL, 'interest overpay rejected 400', overInt.status === 400 && /exceeds/i.test(overInt.data?.message || ''));

  // Full repayment zeroes interest and closes loan
  const payOff = await api(BASE, 'POST', `/loans/${loanId}/repay`, { token: memToken, body: { amount: 7000, paymentType: 'principal' } });
  check(GL, 'full principal payoff succeeds', payOff.status === 200);
  const d3 = await api(BASE, 'GET', `/loans/${loanId}/details`, { token: memToken });
  check(GL, 'loan REPAID: principal 0, interest wiped, repaidDate set',
    d3.data?.status === 'repaid' && d3.data?.remainingPrincipal === 0 && d3.data?.currentMonthInterest === 0 && !!d3.data?.repaidDate);

  const reRepay = await api(BASE, 'POST', `/loans/${loanId}/repay`, { token: memToken, body: { amount: 100, paymentType: 'principal' } });
  check(GL, 'repay on repaid loan rejected 400', reRepay.status === 400 && /already fully repaid/i.test(reRepay.data?.message || ''));

  // Repayment history recorded with breakdown rows:
  // interest 40 + principal 3000 + payoff 7000 = 3 successful payments
  // (rejected overpays must NOT create entries)
  check(GL, 'repayment history has exactly 3 entries (rejected pays excluded)', Array.isArray(d3.data?.repayments) && d3.data.repayments.length === 3,
    `entries=${d3.data?.repayments?.length}`);

  // Loan transactions visible in user feed
  const loanTx = await api(BASE, 'GET', `/loans/user/${memId}`, { token: memToken });
  check(GL, 'user loans feed: totals zeroed after repay, history present',
    loanTx.status === 200 && loanTx.data?.totalOutstanding === 0 && (loanTx.data?.loanTransactions || []).length >= 4);

  // ═══════════════════════ isActive ENFORCEMENT (Phase-1 fix) ═════════
  const GX = 'isactive-fix';
  const delRes = await api(BASE, 'DELETE', `/members/${memId}`, { token: admToken });
  check(GX, 'admin soft-deletes test member', delRes.status === 200);
  const goneDoc = await db.collection('users').findOne({ _id: new mongoose.Types.ObjectId(memId) });
  check(GX, 'soft delete: document kept with isActive=false', goneDoc && goneDoc.isActive === false);
  const stale = await api(BASE, 'GET', '/transactions/summary', { token: memToken });
  check(GX, 'STALE TOKEN BLOCKED: removed member gets 401', stale.status === 401, `status=${stale.status}`);
  const relogin = await api(BASE, 'POST', '/auth/login', { body: { phone: testPhone, password: 'testpass123' } });
  check(GX, 'removed member cannot even log back in', relogin.status !== 200);

  // ═══════════════════════ SEED GUARD (Phase-1 fix) ═══════════════════
  const GS = 'seed-guard';
  const guardRun = await runNode('seed.js', { MONGO_URI: uri, NODE_ENV: 'production' }, 60000);
  check(GS, 'NODE_ENV=production refuses to wipe database', guardRun.code === 1 && /refusing/i.test(guardRun.out),
    `exit=${guardRun.code}`);
  const survivors = await db.collection('users').countDocuments({});
  check(GS, 'database untouched after refused seed', survivors >= 12, `users=${survivors}`);

  // ═══════════════════════ CORS (Phase-1 fix) ═════════════════════════
  const GCORS = 'cors-fix';
  corsProc = spawn(process.execPath, ['server.js'], {
    cwd: __dirname,
    env: { ...process.env, MONGO_URI: uri, JWT_SECRET, PORT: String(CORS_PORT), CORS_ORIGIN: 'http://allowed.example', NODE_ENV: 'development' },
  });
  await waitForHealth(CORS_BASE, 'CORS-scoped server');

  const optAllowed = await fetch(CORS_BASE + '/auth/login', {
    method: 'OPTIONS',
    headers: { Origin: 'http://allowed.example', 'Access-Control-Request-Method': 'POST' },
  });
  check(GCORS, 'preflight from ALLOWED origin permitted', optAllowed.status < 400 &&
    optAllowed.headers.get('access-control-allow-origin') === 'http://allowed.example',
    `status=${optAllowed.status} acao=${optAllowed.headers.get('access-control-allow-origin')}`);

  const optEvil = await fetch(CORS_BASE + '/auth/login', {
    method: 'OPTIONS',
    headers: { Origin: 'http://evil.example', 'Access-Control-Request-Method': 'POST' },
  }).catch(e => ({ error: String(e) }));
  const evilBlocked = optEvil.error || optEvil.status >= 400 ||
    !optEvil.headers?.get('access-control-allow-origin');
  check(GCORS, 'preflight from FOREIGN origin rejected/blocked', evilBlocked,
    optEvil.error ? optEvil.error.slice(0, 80) : `status=${optEvil.status} acao=${optEvil.headers?.get('access-control-allow-origin')}`);

  const defCors = await fetch(BASE + '/auth/login', {
    method: 'OPTIONS',
    headers: { Origin: 'http://whatever.example', 'Access-Control-Request-Method': 'POST' },
  });
  check(GCORS, 'no CORS_ORIGIN configured -> allow-all (dev default)', defCors.status < 400 &&
    !!defCors.headers.get('access-control-allow-origin'),
    `status=${defCors.status} acao=${defCors.headers.get('access-control-allow-origin')}`);

  // ═══════════════════════ SUMMARY ════════════════════════════════════
  console.log('\n================ RESULTS ================');
  const groups = [...new Set(results.map(r => r.group))];
  let failed = 0;
  for (const g of groups) {
    const rs = results.filter(r => r.group === g);
    const f = rs.filter(r => !r.pass);
    failed += f.length;
    console.log(`${f.length === 0 ? 'PASS' : 'FAIL'} ${g}: ${rs.length - f.length}/${rs.length}`);
    for (const x of f) console.log(`     - ${x.name}${x.detail ? ' | ' + x.detail : ''}`);
  }
  console.log(`=========================================`);
  console.log(`TOTAL: ${results.length - failed}/${results.length} passed`);
  return failed;
}

async function cleanup(failed) {
  try { if (serverProc) serverProc.kill(); } catch (_) {}
  try { if (corsProc) corsProc.kill(); } catch (_) {}
  try { if (db) await db.close(); } catch (_) {}
  try { if (mongoose.connection.readyState) await mongoose.disconnect(); } catch (_) {}
  try { if (mongo) await mongo.stop(); } catch (_) {}
  process.exit(failed > 0 ? 1 : 0);
}

main()
  .then(failed => { console.log(failed === 0 ? '\nALL CHECKS PASSED' : `\n${failed} CHECK(S) FAILED`); return failed; })
  .then(cleanup)
  .catch(async err => {
    console.error('\nHARNESS ERROR:', err);
    await cleanup(1);
  });
