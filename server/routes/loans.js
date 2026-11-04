const mongoose = require('mongoose');
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

    if (!mongoose.isObjectIdOrHexString(userId) || !Number.isSafeInteger(amount) || amount <= 0) {
      return res.status(400).json({ message: 'Valid userId and amount are required' });
    }

    // Verify user exists
    const user = await User.findById(userId);
    if (!user || !user.isActive || user.role !== 'user') {
      return res.status(404).json({ message: 'User not found' });
    }

    // Calculate initial monthly interest (separate from principal)
    const initialInterest = calculateMonthlyInterest(amount);

    const loan = new Loan({
      userId,
      amount,
      principalAmount: amount,
      remainingPrincipal: amount,
      outstandingBalance: amount, // Principal only, interest is separate
      currentMonthInterest: initialInterest,
      interestRate: 0.01,
      interestCalculatedDate: new Date(),
      note: note || '',
      issuedDate: new Date(),
      createdBy: req.user._id
    });
    await mongoose.connection.transaction(async session => {
    await loan.save({ session });

    // Also create a transaction record for the loan
    const transaction = new Transaction({
      userId,
      amount: -amount, // Negative because it's money given out
      type: 'loan',
      note: note || `Loan issued: ₹${amount}`,
      date: new Date(),
      createdBy: req.user._id
    });
    await transaction.save({ session });
    });

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

    // Calculate summary - principal and interest are separate
    const totalLoaned = loans.reduce((sum, l) => sum + l.principalAmount, 0);
    const totalPrincipalOutstanding = loans
      .filter(l => l.status === 'active')
      .reduce((sum, l) => sum + l.remainingPrincipal, 0);
    const totalInterestDue = loans
      .filter(l => l.status === 'active')
      .reduce((sum, l) => sum + l.currentMonthInterest, 0);

    res.json({
      loans,
      summary: {
        totalLoaned,
        totalOutstanding: totalPrincipalOutstanding, // Principal only
        totalInterestDue,
        activeCount: loans.filter(l => l.status === 'active').length,
        repaidCount: loans.filter(l => l.status === 'repaid').length
      }
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// POST /api/admin/loans/calculate-all-interests - Batch calculate interest for all active loans
// IMPORTANT: Must be before /:id routes to avoid route matching issues
router.post('/admin/calculate-all-interests', auth, adminOnly, async (req, res) => {
  try {
    const activeLoans = await Loan.find({ status: 'active', remainingPrincipal: { $gt: 0 } });
    
    let totalInterestAccrued = 0;
    let processedCount = 0;

    for (let loan of activeLoans) {
      const newInterest = calculateMonthlyInterest(loan.remainingPrincipal);
      loan.currentMonthInterest = newInterest;
      loan.outstandingBalance = loan.remainingPrincipal; // Principal only
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
      .reduce((sum, l) => sum + l.remainingPrincipal, 0);
    const totalInterestDue = loans
      .filter(l => l.status === 'active')
      .reduce((sum, l) => sum + l.currentMonthInterest, 0);

    // Get loan-related transactions for this user (includes interest payments)
    const loanTransactions = await Transaction.find({
      userId: req.params.userId,
      type: { $in: ['loan', 'loan_repayment', 'loan_interest_payment'] }
    }).sort({ date: -1 });

    res.json({
      loans,
      totalOutstanding,
      totalInterestDue,
      loanTransactions
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// POST /api/loans/:id/repay - Record a repayment (principal or interest, separately)
router.post('/:id/repay', auth, adminOnly, async (req, res) => {
  const { amount, paymentType = 'principal' } = req.body;
  if (!mongoose.isObjectIdOrHexString(req.params.id) || !Number.isSafeInteger(amount) || amount <= 0 ||
      !['principal', 'interest', 'both'].includes(paymentType)) {
    return res.status(400).json({ message: 'Valid loan, whole-rupee amount and payment type required' });
  }
  try {
    const result = await mongoose.connection.transaction(async session => {
      const loan = await Loan.findById(req.params.id).session(session);
      if (!loan) throw Object.assign(new Error('Loan not found'), { status: 404 });
      const due = paymentType === 'principal' ? loan.remainingPrincipal : paymentType === 'interest'
        ? loan.currentMonthInterest : loan.remainingPrincipal + loan.currentMonthInterest;
      if (loan.status === 'repaid' || amount > due) {
        throw Object.assign(new Error('Amount exceeds outstanding debt'), { status: 400 });
      }
      const { repaymentSummary } = processRepayment(loan, amount, paymentType);
      await loan.save({ session });
      await Transaction.create([{
        userId: loan.userId, loanId: loan._id, amount,
        type: paymentType === 'interest' ? 'loan_interest_payment' : 'loan_repayment',
        principalPaid: repaymentSummary.principalPaid, interestPaid: repaymentSummary.interestPaid,
        note: 'Cash repayment confirmed by administrator', date: new Date(), createdBy: req.user._id
      }], { session });
      return { loan, repaymentSummary };
    });
    res.json({ message: 'Cash repayment recorded', ...result });
  } catch (error) {
    res.status(error.status || 500).json({ message: error.status ? error.message : 'Repayment could not be recorded' });
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
    loan.outstandingBalance = loan.remainingPrincipal; // Principal only
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

module.exports = router;
