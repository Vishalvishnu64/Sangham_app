/**
 * Loan Interest Calculation Service
 * Rate: 1% per month (100 Rs per 10,000 Rs)
 */

/**
 * Calculate monthly interest based on remaining principal
 * @param {number} remainingPrincipal - The remaining principal amount
 * @returns {number} - Monthly interest amount
 */
function calculateMonthlyInterest(remainingPrincipal) {
  const interestRate = 0.01; // 1% per month
  return remainingPrincipal * interestRate;
}

/**
 * Get total amount due (principal + current month interest)
 * @param {number} remainingPrincipal
 * @param {number} currentMonthInterest
 * @returns {object} - { remainingPrincipal, interestDue, totalDue }
 */
function getTotalAmountDue(remainingPrincipal, currentMonthInterest) {
  return {
    remainingPrincipal,
    interestDue: currentMonthInterest,
    totalDue: remainingPrincipal + currentMonthInterest
  };
}

/**
 * Process a loan repayment
 * Priority: Interest first, then Principal
 * @param {object} loan - Loan document from DB
 * @param {number} amountPaid - Amount user is paying
 * @returns {object} - Updated loan object with new calculation
 */
function processRepayment(loan, amountPaid) {
  let remaining = amountPaid;
  let interestPaid = 0;
  let principalPaid = 0;

  // Step 1: Pay interest first (if there is outstanding interest)
  if (loan.currentMonthInterest > 0) {
    if (remaining >= loan.currentMonthInterest) {
      interestPaid = loan.currentMonthInterest;
      remaining -= loan.currentMonthInterest;
      loan.currentMonthInterest = 0;
    } else {
      interestPaid = remaining;
      loan.currentMonthInterest -= remaining;
      remaining = 0;
    }
  }

  // Step 2: Pay remaining amount towards principal
  if (remaining > 0) {
    principalPaid = remaining;
    loan.remainingPrincipal -= remaining;
  }

  // Step 3: Update cumulative interest paid
  loan.totalInterestPaid += interestPaid;

  // Step 4: Recalculate interest for next month (based on new principal)
  if (loan.remainingPrincipal > 0) {
    loan.currentMonthInterest = calculateMonthlyInterest(loan.remainingPrincipal);
  } else {
    loan.remainingPrincipal = 0;
    loan.currentMonthInterest = 0;
    loan.status = 'repaid';
  }

  // Step 5: Update outstanding balance
  loan.outstandingBalance = loan.remainingPrincipal + loan.currentMonthInterest;

  // Step 6: Record repayment in history
  if (!loan.repayments) {
    loan.repayments = [];
  }
  
  loan.repayments.push({
    date: new Date(),
    principalPaid,
    interestPaid,
    totalPaid: amountPaid,
    remainingBalance: loan.outstandingBalance
  });

  // Step 7: Mark interest calculation date
  loan.interestCalculatedDate = new Date();

  return {
    loan,
    repaymentSummary: {
      totalPaid: amountPaid,
      principalPaid,
      interestPaid,
      newRemainingPrincipal: loan.remainingPrincipal,
      newCurrentMonthInterest: loan.currentMonthInterest,
      totalOutstanding: loan.outstandingBalance
    }
  };
}

/**
 * Calculate accrued interest for all active loans
 * Called monthly via cron job
 * @param {array} loans - Array of active loan documents
 * @returns {array} - Updated loans
 */
function accrueMonthlyInterest(loans) {
  return loans.map(loan => {
    if (loan.status === 'active' && loan.remainingPrincipal > 0) {
      // Calculate new month's interest based on current remaining principal
      const newMonthlyInterest = calculateMonthlyInterest(loan.remainingPrincipal);
      
      // For the first calculation, use the full amount
      // Otherwise, add new month's interest to existing
      if (!loan.interestCalculatedDate) {
        loan.currentMonthInterest = newMonthlyInterest;
      } else {
        // Add new month's interest to any unpaid interest
        loan.currentMonthInterest += newMonthlyInterest;
      }

      // Update interest calculated date
      loan.interestCalculatedDate = new Date();
      
      // Update outstanding balance
      loan.outstandingBalance = loan.remainingPrincipal + loan.currentMonthInterest;
    }
    return loan;
  });
}

/**
 * Get detailed loan information with interest breakdown
 * @param {object} loan - Loan document
 * @returns {object} - Detailed loan info
 */
function getLoanDetails(loan) {
  return {
    loanId: loan._id,
    userId: loan.userId,
    principalAmount: loan.principalAmount,
    remainingPrincipal: loan.remainingPrincipal,
    currentMonthInterest: loan.currentMonthInterest,
    totalInterestPaid: loan.totalInterestPaid,
    outstandingBalance: loan.outstandingBalance,
    status: loan.status,
    issuedDate: loan.issuedDate,
    interestRate: `${loan.interestRate * 100}% per month`,
    lastInterestCalculated: loan.interestCalculatedDate,
    repaymentHistory: loan.repayments || [],
    note: loan.note
  };
}

module.exports = {
  calculateMonthlyInterest,
  getTotalAmountDue,
  processRepayment,
  accrueMonthlyInterest,
  getLoanDetails
};
