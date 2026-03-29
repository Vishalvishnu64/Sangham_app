const express = require('express');
const Loan = require('../models/Loan');
const Transaction = require('../models/Transaction');
const User = require('../models/User');
const { auth, adminOnly } = require('../middleware/auth');

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

    const loan = new Loan({
      userId,
      amount,
      outstandingBalance: amount,
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
    const totalLoaned = loans.reduce((sum, l) => sum + l.amount, 0);
    const totalOutstanding = loans
      .filter(l => l.status === 'active')
      .reduce((sum, l) => sum + l.outstandingBalance, 0);

    res.json({
      loans,
      summary: {
        totalLoaned,
        totalOutstanding,
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

// POST /api/loans/:id/repay - Record a repayment (admin only)
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

    if (amount > loan.outstandingBalance) {
      return res.status(400).json({
        message: `Repayment amount (₹${amount}) exceeds outstanding balance (₹${loan.outstandingBalance})`
      });
    }

    // Update loan balance
    loan.outstandingBalance -= amount;
    if (loan.outstandingBalance === 0) {
      loan.status = 'repaid';
      loan.repaidDate = new Date();
    }
    await loan.save();

    // Create a repayment transaction
    const transaction = new Transaction({
      userId: loan.userId,
      amount: amount, // Positive because money is coming back
      type: 'loan_repayment',
      note: `Loan repayment: ₹${amount}`,
      date: new Date(),
      createdBy: req.user._id
    });
    await transaction.save();

    const populated = await Loan.findById(loan._id)
      .populate('userId', 'name phone')
      .populate('createdBy', 'name');

    res.json({
      message: loan.status === 'repaid'
        ? 'Loan fully repaid!'
        : `Repayment of ₹${amount} recorded. Outstanding: ₹${loan.outstandingBalance}`,
      loan: populated
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
