// Read-only audit of application source; all writes use a throwaway local DB.
const { createRequire } = require('node:module');
const path = require('node:path');
const req = createRequire(path.resolve(__dirname, '../server/package.json'));
const mongoose = req('mongoose');
const express = req('express');
const jwt = req('jsonwebtoken');
const { MongoMemoryServer } = req('mongodb-memory-server');
const cachedBinary = path.resolve(__dirname, '../server/node_modules/.cache/mongodb-memory-server/mongod-x64-win32-8.2.6.exe');
if (!process.env.MONGOMS_SYSTEM_BINARY && require('node:fs').existsSync(cachedBinary)) {
  process.env.MONGOMS_SYSTEM_BINARY = cachedBinary;
}
const User = req('./models/User');
const Loan = req('./models/Loan');
const Transaction = req('./models/Transaction');
const Attendance = req('./models/Attendance');
const interest = req('./utils/loanInterest');
process.env.JWT_SECRET = require('node:crypto').randomBytes(32).toString('hex');
let mongo, listener;
const findings = [];
function record(name, evidence) { findings.push({ name, evidence }); console.log(JSON.stringify({ name, evidence })); }
(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri('audit_disposable'));
  await Promise.all([User.init(), Loan.init(), Transaction.init(), Attendance.init()]);
  const app = express(); app.use(express.json());
  for (const r of ['auth','members','transactions','attendance','loans']) app.use('/api/'+r, req('./routes/'+r));
  listener = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
  const base = 'http://127.0.0.1:'+listener.address().port+'/api';
  async function api(method, route, token, body) {
    const r = await fetch(base+route, { method, headers: { 'Content-Type':'application/json', ...(token ? {Authorization:'Bearer '+token} : {}) }, ...(body === undefined ? {} : {body: JSON.stringify(body)}) });
    return { status:r.status, data:await r.json() };
  }
  const admin = await User.create({name:'Audit Admin', phone:'9000000001', password:'audit-admin-long-password', role:'admin'});
  const member = await User.create({name:'Audit Member', phone:'9000000002', password:'audit-member-long-password'});
  const at = jwt.sign({id:admin.id}, process.env.JWT_SECRET);
  const mt = jwt.sign({id:member.id}, process.env.JWT_SECRET);
  const issued = await api('POST','/loans',at,{userId:member.id,amount:10000});
  const loanId = issued.data.loan._id;
  record('borrower can clear debt without money movement', await api('POST','/loans/'+loanId+'/repay',mt,{amount:10000,paymentType:'principal'}).then(r=>({status:r.status,principal:r.data.loan.remainingPrincipal,interest:r.data.loan.currentMonthInterest,loanStatus:r.data.loan.status})));
  await api('POST','/attendance/bulk',at,{records:[{userId:admin.id,status:'present'}]});
  const exposure = await api('GET','/attendance/today',mt);
  record('member receives other persons phone and attendance', {status:exposure.status,otherPersonExposed:exposure.data.records.some(r=>r.userId._id===admin.id && r.userId.phone===admin.phone)});
  const registration = await api('POST','/auth/register',null,{name:'Uninvited',phone:'not-a-phone',password:'123456'});
  const outsider = await api('POST','/auth/login',null,{phone:'not-a-phone',password:'123456'});
  record('unverified outsider immediately admitted', {registration:registration.status,groupSummary:(await api('GET','/transactions/summary',outsider.data.token)).status});
  const defaultMember = await api('POST','/members',at,{name:'Default Credential',phone:'9000009876'});
  record('predictable member password accepted', {created:defaultMember.status,login:(await api('POST','/auth/login',null,{phone:'9000009876',password:'9876'})).status});
  const injection = await api('POST','/auth/login',null,{phone:{$ne:null},password:'audit-admin-long-password'});
  record('login accepts query operator instead of phone (password still required)', {status:injection.status,role:injection.data.user?.role});
  const loan2 = await api('POST','/loans',at,{userId:member.id,amount:1000});
  const save = Transaction.prototype.save;
  Transaction.prototype.save = async function() { throw new Error('audit injected ledger failure'); };
  const failed = await api('POST','/loans/'+loan2.data.loan._id+'/repay',at,{amount:100,paymentType:'principal'});
  Transaction.prototype.save = save;
  const corrupted = await Loan.findById(loan2.data.loan._id);
  record('rollback retains mutated principal after failed ledger write', {http:failed.status,expectedPrincipal:1000,actualPrincipal:corrupted.remainingPrincipal,repayments:corrupted.repayments.length});
  const before = await Loan.countDocuments();
  Transaction.prototype.save = async function() { throw new Error('audit injected issuance ledger failure'); };
  const issueFailed = await api('POST','/loans',at,{userId:member.id,amount:777});
  Transaction.prototype.save = save;
  record('issuance leaves orphan debt on ledger failure', {http:issueFailed.status,extraLoans:(await Loan.countDocuments())-before});
  const malformed = await api('POST','/transactions',at,{userId:member.id,amount:-123,type:'contribution'});
  const ghost = await api('POST','/transactions',at,{userId:new mongoose.Types.ObjectId().toString(),amount:99,type:'loan_repayment'});
  record('negative contribution and loan-less repayment accepted', {negative:malformed.status,nonexistentMember:ghost.status});
  const badAttendance = await api('POST','/attendance/bulk',at,{records:[{userId:member.id,status:'invented'}]});
  record('attendance enum bypassed by bulk update', {http:badAttendance.status,persisted:!!await Attendance.findOne({userId:member.id,status:'invented'})});
  const principal = {remainingPrincipal:10000,currentMonthInterest:100,totalInterestPaid:0,status:'active',repayments:[]};
  interest.processRepayment(principal,100,'interest');
  interest.processRepayment(principal,100,'principal');
  record('principal payment resurrects already-paid interest', {interestExpected:0,interestActual:principal.currentMonthInterest});
  const unpaid = {remainingPrincipal:10000,currentMonthInterest:100,totalInterestPaid:0,status:'active'};
  interest.accrueMonthlyInterest([unpaid]);
  record('monthly accrual overwrites unpaid interest', {twoMonthsAt100:unpaid.currentMonthInterest});
  const loan3 = await api('POST','/loans',at,{userId:member.id,amount:10000});
  const parallel = await Promise.all(Array.from({length:8},()=>api('POST','/loans/'+loan3.data.loan._id+'/repay',at,{amount:100,paymentType:'principal'})));
  const after = await Loan.findById(loan3.data.loan._id);
  const successes = parallel.filter(r=>r.status===200).length;
  record('concurrent repayment reconciliation', {successes,errors:parallel.filter(r=>r.status!==200).map(r=>r.status),expectedPrincipal:10000-successes*100,actualPrincipal:after.remainingPrincipal,repaymentRows:after.repayments.length});
  const countBefore = await Transaction.countDocuments();
  await api('POST','/transactions/bulk',at,{memberIds:[member.id,member.id],amount:100});
  record('duplicate bulk member IDs duplicate money', {created:(await Transaction.countDocuments())-countBefore});
  const lt = await Transaction.findOne({type:'loan',amount:-10000});
  record('loan ledger can be deleted independently', {deleteStatus:(await api('DELETE','/transactions/'+lt.id,at)).status,loanStillExists:!!await Loan.findById(loanId)});
})().catch(e=>{console.error(e);process.exitCode=1;}).finally(async()=>{
  if(listener) await new Promise(r=>listener.close(r));
  await mongoose.disconnect(); if(mongo) await mongo.stop();
  require('node:fs').writeFileSync(path.join(__dirname,'probe-results.json'),JSON.stringify(findings,null,2));
});
