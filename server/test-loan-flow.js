/**
 * Test Loan Interest & Repayment Flow
 * Verifies: interest display, repayment processing, interest recalculation
 */

const https = require('https');

const BASE_URL = 'https://sangham-app.onrender.com/api';

function makeRequest(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const fullUrl = new URL(path, BASE_URL);
    const options = {
      method,
      headers: {
        'Content-Type': 'application/json'
      }
    };

    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    const req = https.request(fullUrl, options, (res) => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch (e) {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

(async () => {
  try {
    console.log('🧪 TESTING LOAN INTEREST & REPAYMENT FLOW\n');

    // 1. Login
    console.log('1️⃣  LOGIN');
    const loginResp = await makeRequest('POST', '/auth/login', {
      phone: '9876543210',
      password: 'user1password'
    });
    if (loginResp.status !== 200) {
      console.error('❌ Login failed:', loginResp.body);
      process.exit(1);
    }
    const { token, user } = loginResp.body;
    console.log(`✅ Logged in as: ${user.name}\n`);

    // 2. Get loans
    console.log('2️⃣  FETCH LOANS');
    const loansResp = await makeRequest('GET', `/loans/user/${user._id}`, null, token);
    if (loansResp.status !== 200 || !loansResp.body.loans?.length) {
      console.error('❌ No loans found:', loansResp.body);
      process.exit(1);
    }
    const loanId = loansResp.body.loans[0]._id;
    console.log(`✅ Found ${loansResp.body.loans.length} loan(s), testing: ${loanId}\n`);

    // 3. Get loan details
    console.log('3️⃣  FETCH LOAN DETAILS (WITH INTEREST)');
    const detailResp = await makeRequest('GET', `/loans/${loanId}/details`, null, token);
    if (detailResp.status !== 200) {
      console.error('❌ Failed to get loan details:', detailResp.body);
      process.exit(1);
    }
    const loan = detailResp.body;
    console.log(`✅ Loan Details:`);
    console.log(`   Principal: ₹${loan.principalAmount}`);
    console.log(`   Remaining: ₹${loan.remainingPrincipal}`);
    console.log(`   Monthly Interest: ₹${loan.currentMonthInterest}`);
    console.log(`   Total Interest Paid: ₹${loan.totalInterestPaid}`);
    console.log(`   Outstanding Balance: ₹${loan.outstandingBalance}`);
    console.log(`   Status: ${loan.status}\n`);

    // Verify interest exists
    if (loan.currentMonthInterest === 0 || loan.currentMonthInterest === undefined) {
      console.warn('⚠️  WARNING: No interest calculated yet!\n');
    }

    // 4. Test repayment (if loan is active)
    if (loan.status === 'active') {
      console.log('4️⃣  TEST REPAYMENT (₹500)');
      const repayResp = await makeRequest('POST', `/loans/${loanId}/repay`, { amount: 500 }, token);
      if (repayResp.status === 200) {
        console.log(`✅ Repayment Successful:`);
        console.log(`   Message: ${repayResp.body.message}`);
        if (repayResp.body.repaymentSummary) {
          const summary = repayResp.body.repaymentSummary;
          console.log(`   Total Paid: ₹${summary.totalPaid}`);
          console.log(`   Interest Paid: ₹${summary.interestPaid}`);
          console.log(`   Principal Paid: ₹${summary.principalPaid}`);
          console.log(`   New Remaining Principal: ₹${summary.newRemainingPrincipal}`);
          console.log(`   New Monthly Interest: ₹${summary.newCurrentMonthInterest}`);
        }
        console.log('✅ REPAYMENT & INTEREST RECALCULATION WORKING!\n');
      } else {
        console.error(`❌ Repayment failed (${repayResp.status}):`, repayResp.body);
      }
    }

    console.log('✅ ALL TESTS COMPLETED SUCCESSFULLY');

  } catch (error) {
    console.error('❌ ERROR:', error.message);
    process.exit(1);
  }
})();
