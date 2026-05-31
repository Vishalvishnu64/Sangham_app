/**
 * Scheduler for monthly loan interest accrual
 * Runs on the 1st of every month to calculate interest for all active loans
 */

const cron = require('node-cron');
const Loan = require('../models/Loan');
const { calculateMonthlyInterest } = require('../utils/loanInterest');

/**
 * Initialize loan interest accrual scheduler
 * Runs every month on the 1st day at 00:00 (UTC)
 */
function initLoanInterestScheduler() {
  // Cron expression: 0 0 1 * * (every month on 1st at 00:00)
  cron.schedule('0 0 1 * *', async () => {
    try {
      console.log('[LOAN SCHEDULER] Starting monthly interest calculation...');
      
      // Find all active loans with remaining principal
      const activeLoans = await Loan.find({
        status: 'active',
        remainingPrincipal: { $gt: 0 }
      });

      let totalInterestAccrued = 0;
      let processedCount = 0;

      // Calculate interest for each active loan
      for (let loan of activeLoans) {
        const newInterest = calculateMonthlyInterest(loan.remainingPrincipal);
        
        // Add new month's interest to current month's interest
        loan.currentMonthInterest = newInterest;
        loan.outstandingBalance = loan.remainingPrincipal + newInterest;
        loan.interestCalculatedDate = new Date();
        
        await loan.save();
        
        totalInterestAccrued += newInterest;
        processedCount++;
      }

      console.log(`[LOAN SCHEDULER] ✅ Completed: ${processedCount} loans processed`);
      console.log(`[LOAN SCHEDULER] Total interest accrued: ₹${totalInterestAccrued.toFixed(2)}`);
    } catch (error) {
      console.error('[LOAN SCHEDULER] Error:', error.message);
    }
  });

  console.log('[LOAN SCHEDULER] ✓ Monthly interest scheduler initialized');
}

/**
 * Optional: Run interest calculation immediately for testing
 */
async function runImmediateInterestCalculation() {
  try {
    console.log('[LOAN SCHEDULER] Running immediate interest calculation...');
    
    const activeLoans = await Loan.find({
      status: 'active',
      remainingPrincipal: { $gt: 0 }
    });

    let totalInterestAccrued = 0;
    let processedCount = 0;

    for (let loan of activeLoans) {
      const newInterest = calculateMonthlyInterest(loan.remainingPrincipal);
      
      loan.currentMonthInterest = newInterest;
      loan.outstandingBalance = loan.remainingPrincipal + newInterest;
      loan.interestCalculatedDate = new Date();
      
      await loan.save();
      
      totalInterestAccrued += newInterest;
      processedCount++;
    }

    console.log(`✓ Processed ${processedCount} loans`);
    console.log(`✓ Total interest accrued: ₹${totalInterestAccrued.toFixed(2)}`);
  } catch (error) {
    console.error('Error running immediate calculation:', error.message);
  }
}

module.exports = {
  initLoanInterestScheduler,
  runImmediateInterestCalculation
};
