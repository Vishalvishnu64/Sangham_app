/**
 * Loan Interest Calculation Service
 * Rate: 1% per month (100 Rs per 10,000 Rs)
 * 
 * IMPORTANT: Interest is SEPARATE from the loan principal.
 * - outstandingBalance = remainingPrincipal only (no interest added)
 * - currentMonthInterest = 1% of remainingPrincipal (separate monthly charge)
 * - When principal is repaid, next month's interest recalculates on new lower principal
 * 
 * Example: Loan = 10000, Interest = 100/month
 *   Member repays 500 → remainingPrincipal = 9500, next month interest = 95
 */

/**
 * Calculate monthly interest based on remaining principal
 * @param {number} remainingPrincipal - The remaining principal amount
 * @returns {number} - Monthly interest amount
 */
function calculateMonthlyInterest(remainingPrincipal) {
  const interestRate = 0.01; // 1% per month
  return Math.round(remainingPrincipal * interestRate);
}

/**
 * Get total amount due breakdown
 * Principal and interest are SEPARATE
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
 * 
 * Repayment goes ONLY to principal (interest is paid separately).
 * After principal is reduced, interest is recalculated for next month.
 * 
 * If the member pays interest separately, use processInterestPayment().
 * 
 * @param {object} loan - Loan document from DB
 * @param {number} amountPaid - Amount user is paying
 * @param {string} paymentType - 'principal', 'interest', or 'both'
 * @returns {object} - Updated loan object with new calculation
 */
function processRepayment(loan, amountPaid, paymentType = 'principal') {
  let remaining = amountPaid;
  let interestPaid = 0;
  let principalPaid = 0;

  if (paymentType === 'interest') {
    // Pay only interest
    if (remaining >= loan.currentMonthInterest) {
      interestPaid = loan.currentMonthInterest;
      remaining -= loan.currentMonthInterest;
      loan.currentMonthInterest = 0;
    } else {
      interestPaid = remaining;
      loan.currentMonthInterest -= remaining;
      remaining = 0;
    }
  } else if (paymentType === 'both') {
    // Pay interest first, then principal
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
    // Remaining goes to principal
    if (remaining > 0) {
      principalPaid = remaining;
      loan.remainingPrincipal -= remaining;
      remaining = 0;
    }
  } else {
    // Default: pay only principal
    principalPaid = amountPaid;
    loan.remainingPrincipal -= amountPaid;
  }

  // Update cumulative interest paid
  loan.totalInterestPaid += interestPaid;

  // Check if loan is fully repaid
  if (loan.remainingPrincipal <= 0) {
    loan.remainingPrincipal = 0;
    loan.currentMonthInterest = 0;
    loan.status = 'repaid';
    loan.repaidDate = new Date();
  } else {
    // Recalculate interest for next month based on new remaining principal
    loan.currentMonthInterest = calculateMonthlyInterest(loan.remainingPrincipal);
  }

  // Outstanding balance = remaining principal only (interest is separate)
  loan.outstandingBalance = loan.remainingPrincipal;

  // Record repayment in history
  if (!loan.repayments) {
    loan.repayments = [];
  }
  
  loan.repayments.push({
    date: new Date(),
    principalPaid,
    interestPaid,
    totalPaid: amountPaid,
    remainingBalance: loan.remainingPrincipal
  });

  // Mark interest calculation date
  loan.interestCalculatedDate = new Date();

  return {
    loan,
    repaymentSummary: {
      totalPaid: amountPaid,
      principalPaid,
      interestPaid,
      paymentType,
      newRemainingPrincipal: loan.remainingPrincipal,
      newCurrentMonthInterest: loan.currentMonthInterest,
      totalOutstanding: loan.remainingPrincipal
    }
  };
}

/**
 * Calculate accrued interest for all active loans
 * Called monthly via cron job
 * Interest is recalculated based on current remaining principal
 * @param {array} loans - Array of active loan documents
 * @returns {array} - Updated loans
 */
function accrueMonthlyInterest(loans) {
  return loans.map(loan => {
    if (loan.status === 'active' && loan.remainingPrincipal > 0) {
      // Calculate new month's interest based on current remaining principal
      const newMonthlyInterest = calculateMonthlyInterest(loan.remainingPrincipal);
      
      // Set this month's interest (not accumulated - fresh calculation each month)
      loan.currentMonthInterest = newMonthlyInterest;

      // Update interest calculated date
      loan.interestCalculatedDate = new Date();
      
      // Outstanding balance = principal only (interest is separate)
      loan.outstandingBalance = loan.remainingPrincipal;
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
    outstandingBalance: loan.remainingPrincipal, // principal only
    status: loan.status,
    issuedDate: loan.issuedDate,
    interestRate: `${(loan.interestRate || 0.01) * 100}% per month`,
    interestCalculatedDate: loan.interestCalculatedDate,
    repayments: loan.repayments || [],
    repaidDate: loan.repaidDate,
    note: loan.note,
    createdAt: loan.createdAt
  };
}

module.exports = {
  calculateMonthlyInterest,
  getTotalAmountDue,
  processRepayment,
  accrueMonthlyInterest,
  getLoanDetails
};
