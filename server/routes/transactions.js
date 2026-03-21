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

    // If no memberIds provided, apply to all active members
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

    // Calculate running balance
    const allTransactions = await Transaction.find({ userId: req.params.userId })
      .sort({ date: 1 });

    let runningBalance = 0;
    const passbook = allTransactions.map(t => {
      runningBalance += t.amount;
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
router.put('/:id', auth, adminOnly, async (req, res) => {
  try {
    const transaction = await Transaction.findById(req.params.id);
    if (!transaction) {
      return res.status(404).json({ message: 'Transaction not found' });
    }

    const oldValue = {
      amount: transaction.amount,
      type: transaction.type,
      note: transaction.note
    };

    const { amount, type, note } = req.body;
    if (amount !== undefined) transaction.amount = amount;
    if (type) transaction.type = type;
    if (note !== undefined) transaction.note = note;
    await transaction.save();

    // Audit log for transparency
    await AuditLog.create({
      action: 'edit',
      entity: 'transaction',
      entityId: transaction._id,
      oldValue,
      newValue: { amount: transaction.amount, type: transaction.type, note: transaction.note },
      performedBy: req.user._id
    });

    res.json({ message: 'Transaction updated', transaction });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// DELETE /api/transactions/:id - Delete transaction (admin)
router.delete('/:id', auth, adminOnly, async (req, res) => {
  try {
    const transaction = await Transaction.findById(req.params.id);
    if (!transaction) {
      return res.status(404).json({ message: 'Transaction not found' });
    }

    // Audit log
    await AuditLog.create({
      action: 'delete',
      entity: 'transaction',
      entityId: transaction._id,
      oldValue: transaction.toObject(),
      performedBy: req.user._id
    });

    await Transaction.findByIdAndDelete(req.params.id);
    res.json({ message: 'Transaction deleted' });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
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
