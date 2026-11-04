const mongoose = require('mongoose');
const express = require('express');
const Transaction = require('../models/Transaction');
const AuditLog = require('../models/AuditLog');
const User = require('../models/User');
const { auth, adminOnly } = require('../middleware/auth');

const router = express.Router();

// GET /api/transactions - Get all transactions (admin)
router.get('/', auth, adminOnly, async (req, res) => {
  try {
    const transactions = await Transaction.find()
      .populate('userId', 'name phone')
      .populate('createdBy', 'name')
      .sort({ date: -1 })
      .limit(200);
    res.json(transactions);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// POST /api/transactions/bulk - Add contribution for multiple members
router.post('/bulk', auth, adminOnly, async (req, res) => {
  try {
    const { amount, memberIds, type, note, date } = req.body;

    if (!Number.isSafeInteger(amount) || amount <= 0 || !Array.isArray(memberIds) || memberIds.length === 0 || memberIds.length > 500 || new Set(memberIds).size !== memberIds.length || memberIds.some(id => !mongoose.isObjectIdOrHexString(id)) || (type && type !== 'contribution')) {
      return res.status(400).json({ message: 'Positive whole-rupee amount and unique selected members required' });
    }
    if (await User.countDocuments({ _id: { $in: memberIds }, role: 'user', isActive: true }) !== memberIds.length) {
      return res.status(400).json({ message: 'All selected members must be active' });
    }
    // Explicitly selected, validated members only
    let targetIds = memberIds;
    if (!targetIds || targetIds.length === 0) {
      const allMembers = await User.find({ role: 'user', isActive: true }).select('_id');
      targetIds = allMembers.map(m => m._id);
    }

    const transactions = targetIds.map(userId => ({
      userId,
      amount,
      type: type || 'contribution',
      note: note || 'Weekly contribution',
      date: date || new Date(),
      createdBy: req.user._id
    }));

    const created = await Transaction.insertMany(transactions);

    res.status(201).json({
      message: `Contribution of ₹${amount} added for ${created.length} members`,
      count: created.length
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// POST /api/transactions - Add single transaction
router.post('/', auth, adminOnly, async (req, res) => {
  try {
    const { userId, amount, type, note, date } = req.body;

    if (!mongoose.isObjectIdOrHexString(userId) || !Number.isSafeInteger(amount) || amount <= 0 || !['contribution', 'penalty', 'withdrawal'].includes(type || 'contribution')) {
      return res.status(400).json({ message: 'Invalid member, amount or manual receipt type' });
    }
    if (!await User.exists({ _id: userId, role: 'user', isActive: true })) return res.status(404).json({ message: 'Active member not found' });
    const transaction = new Transaction({
      userId,
      amount,
      type: type || 'contribution',
      note: note || '',
      date: date || new Date(),
      createdBy: req.user._id
    });
    await transaction.save();

    res.status(201).json({ message: 'Transaction added', transaction });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// GET /api/transactions/summary - Total fund & stats
router.get('/summary', auth, async (req, res) => {
  try {
    const totalFund = await Transaction.aggregate([
      { $group: { _id: null, total: { $sum: '$amount' } } }
    ]);

    // This week's collection
    const startOfWeek = new Date();
    startOfWeek.setDate(startOfWeek.getDate() - startOfWeek.getDay());
    startOfWeek.setHours(0, 0, 0, 0);

    const weeklyCollection = await Transaction.aggregate([
      { $match: { date: { $gte: startOfWeek }, type: 'contribution' } },
      { $group: { _id: null, total: { $sum: '$amount' } } }
    ]);

    // This month's collection
    const startOfMonth = new Date();
    startOfMonth.setDate(1);
    startOfMonth.setHours(0, 0, 0, 0);

    const monthlyCollection = await Transaction.aggregate([
      { $match: { date: { $gte: startOfMonth }, type: 'contribution' } },
      { $group: { _id: null, total: { $sum: '$amount' } } }
    ]);

    // Who paid this week
    const paidThisWeek = await Transaction.distinct('userId', {
      date: { $gte: startOfWeek },
      type: 'contribution'
    });

    const totalMembers = await User.countDocuments({ role: 'user', isActive: true });

    res.json({
      totalFund: totalFund[0]?.total || 0,
      weeklyCollection: weeklyCollection[0]?.total || 0,
      monthlyCollection: monthlyCollection[0]?.total || 0,
      paidThisWeek: paidThisWeek.length,
      notPaidThisWeek: totalMembers - paidThisWeek.length,
      totalMembers
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// GET /api/transactions/user/:userId - Get user's transactions
router.get('/user/:userId', auth, async (req, res) => {
  try {
    // Users can only view their own transactions
    if (req.user.role !== 'admin' && req.user._id.toString() !== req.params.userId) {
      return res.status(403).json({ message: 'Access denied' });
    }

    const transactions = await Transaction.find({ userId: req.params.userId })
      .sort({ date: -1 })
      .limit(100);

    // Calculate running balance.
    // Personal (savings) balance = contributions only. Loan disbursements,
    // repayments, interest, penalties and withdrawals belong to the whole
    // group fund, so they are still listed below for transparency but do not
    // move the member's own running balance.
    const allTransactions = await Transaction.find({ userId: req.params.userId })
      .sort({ date: 1 });

    let runningBalance = 0;
    const passbook = allTransactions.map(t => {
      if (t.type === 'contribution') {
        runningBalance += t.amount;
      }
      return {
        ...t.toObject(),
        runningBalance
      };
    });

    res.json({
      transactions: transactions,
      passbook: passbook.reverse(),
      currentBalance: runningBalance
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// PUT /api/transactions/:id - Edit transaction (admin, with audit log)
router.put('/:id', auth, adminOnly, (req, res) => {
  res.status(409).json({ message: 'Posted receipts cannot be changed; contact the administrator for reconciliation.' });
});

// DELETE /api/transactions/:id - Delete transaction (admin)
router.delete('/:id', auth, adminOnly, (req, res) => {
  res.status(409).json({ message: 'Posted receipts cannot be changed; contact the administrator for reconciliation.' });
});

// GET /api/transactions/weekly-status - Who paid / who didn't this week
router.get('/weekly-status', auth, adminOnly, async (req, res) => {
  try {
    const startOfWeek = new Date();
    startOfWeek.setDate(startOfWeek.getDate() - startOfWeek.getDay());
    startOfWeek.setHours(0, 0, 0, 0);

    const allMembers = await User.find({ role: 'user', isActive: true }).select('name phone');

    const paidUserIds = await Transaction.distinct('userId', {
      date: { $gte: startOfWeek },
      type: 'contribution'
    });

    const paidSet = new Set(paidUserIds.map(id => id.toString()));

    const paid = [];
    const notPaid = [];

    allMembers.forEach(m => {
      if (paidSet.has(m._id.toString())) {
        paid.push({ id: m._id, name: m.name, phone: m.phone });
      } else {
        notPaid.push({ id: m._id, name: m.name, phone: m.phone });
      }
    });

    res.json({ paid, notPaid });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
