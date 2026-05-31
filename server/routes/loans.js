const express = require('express');
const Loan = require('../models/Loan');
const Transaction = require('../models/Transaction');
const User = require('../models/User');
const { auth, adminOnly } = require('../middleware/auth');
const {
  calculateMonthlyInterest,
  getTotalAmountDue,
  processRepayment,
  accrueMonthlyInterest,
  getLoanDetails
} = require('../utils/loanInterest');

const router = express.Router();

// POST /api/loans - Issue a new loan (admin only)
router.post('/', auth, adminOnly, async (req, res) => {
  try {
    const { userId, amount, note } = req.body;

    if (!userId || !amount || amount <= 0) {
      return res.status(400).json({ message: 'Valid userId and amount are required' });
    }

    // Verify user exists
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Calculate initial monthly interest
    const initialInterest = calculateMonthlyInterest(amount);

    const loan = new Loan({
      userId,
      amount,
      principalAmount: amount,
      remainingPrincipal: amount,
      outstandingBalance: amount + initialInterest,
      currentMonthInterest: initialInterest,
      interestRate: 0.01,
      interestCalculatedDate: new Date(),
      note: note || '',
      issuedDate: new Date(),
      createdBy: req.user._id
    });
    await loan.save();

    // Also create a transaction record for the loan
    const transaction = new Transaction({
      userId,
      amount: -amount, // Negative because it's money given out
      type: 'loan',
      note: note || `Loan issued: ₹${amount}`,
      date: new Date(),
      createdBy: req.user._id
    });
    await transaction.save();

    const populated = await Loan.findById(loan._id)
      .populate('userId', 'name phone')
      .populate('createdBy', 'name');

    res.status(201).json({ message: 'Loan issued successfully', loan: populated });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// GET /api/loans - Get all loans (admin only)
router.get('/', auth, adminOnly, async (req, res) => {
  try {
    const { status } = req.query;
    const filter = {};
    if (status) filter.status = status;

    const loans = await Loan.find(filter)
      .populate('userId', 'name phone')
      .populate('createdBy', 'name')
      .sort({ createdAt: -1 });

    // Calculate summary
    const totalLoaned = loans.reduce((sum, l) => sum + l.principalAmount, 0);
    const totalOutstanding = loans
      .filter(l => l.status === 'active')
      .reduce((sum, l) => sum + l.outstandingBalance, 0);
    const totalInterestDue = loans
      .filter(l => l.status === 'active')
      .reduce((sum, l) => sum + l.currentMonthInterest, 0);

    res.json({
      loans,
      summary: {
        totalLoaned,
        totalOutstanding,
        totalInterestDue,
        activeCount: loans.filter(l => l.status === 'active').length,
        repaidCount: loans.filter(l => l.status === 'repaid').length
      }
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// GET /api/loans/user/:userId - Get a user's loans
router.get('/user/:userId', auth, async (req, res) => {
  try {
    // Users can only view their own loans
    if (req.user.role !== 'admin' && req.user._id.toString() !== req.params.userId) {
      return res.status(403).json({ message: 'Access denied' });
    }

    const loans = await Loan.find({ userId: req.params.userId })
      .populate('createdBy', 'name')
      .sort({ createdAt: -1 });

    const totalOutstanding = loans
      .filter(l => l.status === 'active')
      .reduce((sum, l) => sum + l.outstandingBalance, 0);

    // Get loan-related transactions for this user
    const loanTransactions = await Transaction.find({
      userId: req.params.userId,
      type: { $in: ['loan', 'loan_repayment'] }
    }).sort({ date: -1 });

    res.json({
      loans,
      totalOutstanding,
      loanTransactions
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// POST /api/loans/:id/repay - Record a repayment with interest deduction
router.post('/:id/repay', auth, adminOnly, async (req, res) => {
  try {
    const { amount } = req.body;

    if (!amount || amount <= 0) {
      return res.status(400).json({ message: 'Valid repayment amount is required' });
    }

    const loan = await Loan.findById(req.params.id);
    if (!loan) {
      return res.status(404).json({ message: 'Loan not found' });
    }

    if (loan.status === 'repaid') {
      return res.status(400).json({ message: 'Loan is already fully repaid' });
    }

    const totalDue = loan.remainingPrincipal + loan.currentMonthInterest;
    if (amount > totalDue) {
      return res.status(400).json({
        message: `Repayment amount (₹${amount}) exceeds total due (₹${totalDue})`,
        totalDue,
        remainingPrincipal: loan.remainingPrincipal,
        interestDue: loan.currentMonthInterest
      });
    }

    // Process the repayment with interest calculation
    const { loan: updatedLoan, repaymentSummary } = processRepayment(loan, amount);
    
    // Save updated loan
    await updatedLoan.save();

    // Create a repayment transaction
    const transaction = new Transaction({
      userId: loan.userId,
      amount: amount,
      type: 'loan_repayment',
      note: `Loan repayment - Principal: ₹${repaymentSummary.principalPaid}, Interest: ₹${repaymentSummary.interestPaid}`,
      date: new Date(),
      createdBy: req.user._id
    });
    await transaction.save();

    const populated = await Loan.findById(updatedLoan._id)
      .populate('userId', 'name phone')
      .populate('createdBy', 'name');

    res.json({
      message: updatedLoan.status === 'repaid'
        ? 'Loan fully repaid!'
        : `Repayment recorded successfully`,
      loan: populated,
      repaymentSummary
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// GET /api/loans/:id/details - Get detailed loan info with interest
router.get('/:id/details', auth, async (req, res) => {
  try {
    const loan = await Loan.findById(req.params.id)
      .populate('userId', 'name phone')
      .populate('createdBy', 'name');

    if (!loan) {
      return res.status(404).json({ message: 'Loan not found' });
    }

    // Users can only view their own loans
    if (req.user.role !== 'admin' && req.user._id.toString() !== loan.userId._id.toString()) {
      return res.status(403).json({ message: 'Access denied' });
    }

    const details = getLoanDetails(loan);
    res.json(details);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// POST /api/loans/:id/calculate-interest - Manually calculate interest for a loan
router.post('/:id/calculate-interest', auth, adminOnly, async (req, res) => {
  try {
    const loan = await Loan.findById(req.params.id);
    if (!loan) {
      return res.status(404).json({ message: 'Loan not found' });
    }

    if (loan.status === 'repaid' || loan.remainingPrincipal <= 0) {
      return res.status(400).json({ message: 'Cannot calculate interest for fully repaid loan' });
    }

    const oldInterest = loan.currentMonthInterest;
    const newInterest = calculateMonthlyInterest(loan.remainingPrincipal);
    
    loan.currentMonthInterest = newInterest;
    loan.outstandingBalance = loan.remainingPrincipal + newInterest;
    loan.interestCalculatedDate = new Date();
    
    await loan.save();

    res.json({
      message: 'Interest calculated',
      previousMonthInterest: oldInterest,
      currentMonthInterest: newInterest,
      remainingPrincipal: loan.remainingPrincipal,
      totalOutstanding: loan.outstandingBalance
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// POST /api/admin/loans/calculate-all-interests - Batch calculate interest for all active loans
router.post('/admin/calculate-all-interests', auth, adminOnly, async (req, res) => {
  try {
    const activeLoans = await Loan.find({ status: 'active', remainingPrincipal: { $gt: 0 } });
    
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

    res.json({
      message: `Interest calculated for ${processedCount} loans`,
      processedCount,
      totalInterestAccrued,
      timestamp: new Date()
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
