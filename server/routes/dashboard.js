const express = require('express');
const User = require('../models/User');
const Transaction = require('../models/Transaction');
const Attendance = require('../models/Attendance');
const Loan = require('../models/Loan');
const { auth, adminOnly } = require('../middleware/auth');

const router = express.Router();

// GET /api/dashboard/admin - Admin dashboard stats
router.get('/admin', auth, adminOnly, async (req, res) => {
  try {
    // Total fund
    const totalFundResult = await Transaction.aggregate([
      { $group: { _id: null, total: { $sum: '$amount' } } }
    ]);
    const totalFund = totalFundResult[0]?.total || 0;

    // Member count
    const totalMembers = await User.countDocuments({ role: 'user', isActive: true });

    // This month's collection
    const startOfMonth = new Date();
    startOfMonth.setDate(1);
    startOfMonth.setHours(0, 0, 0, 0);

    const monthlyResult = await Transaction.aggregate([
      { $match: { date: { $gte: startOfMonth }, type: 'contribution' } },
      { $group: { _id: null, total: { $sum: '$amount' } } }
    ]);
    const monthlyCollection = monthlyResult[0]?.total || 0;

    // Last month for comparison
    const startOfLastMonth = new Date(startOfMonth);
    startOfLastMonth.setMonth(startOfLastMonth.getMonth() - 1);
    const lastMonthResult = await Transaction.aggregate([
      { $match: { date: { $gte: startOfLastMonth, $lt: startOfMonth }, type: 'contribution' } },
      { $group: { _id: null, total: { $sum: '$amount' } } }
    ]);
    const lastMonthCollection = lastMonthResult[0]?.total || 0;
    const monthGrowth = lastMonthCollection > 0
      ? Math.round(((monthlyCollection - lastMonthCollection) / lastMonthCollection) * 100)
      : 0;

    // Today's attendance
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const presentToday = await Attendance.countDocuments({ date: today, status: 'present' });

    // Weekly collection status
    const startOfWeek = new Date();
    startOfWeek.setDate(startOfWeek.getDate() - startOfWeek.getDay());
    startOfWeek.setHours(0, 0, 0, 0);

    const paidThisWeek = await Transaction.distinct('userId', {
      date: { $gte: startOfWeek },
      type: 'contribution'
    });

    // Recent transactions
    const recentTransactions = await Transaction.find()
      .populate('userId', 'name')
      .sort({ date: -1 })
      .limit(10);

    // Total loans outstanding
    const loansOutstandingResult = await Loan.aggregate([
      { $match: { status: 'active' } },
      { $group: { _id: null, total: { $sum: '$outstandingBalance' } } }
    ]);
    const totalLoansOutstanding = loansOutstandingResult[0]?.total || 0;
    const activeLoansCount = await Loan.countDocuments({ status: 'active' });

    res.json({
      totalFund,
      totalMembers,
      monthlyCollection,
      monthGrowth,
      presentToday,
      paidThisWeek: paidThisWeek.length,
      notPaidThisWeek: totalMembers - paidThisWeek.length,
      recentTransactions,
      totalLoansOutstanding,
      activeLoansCount
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// GET /api/dashboard/user/:id - User dashboard
router.get('/user/:id', auth, async (req, res) => {
  try {
    // Users can only view their own dashboard
    if (req.user.role !== 'admin' && req.user._id.toString() !== req.params.id) {
      return res.status(403).json({ message: 'Access denied' });
    }

    const user = await User.findById(req.params.id).select('-password');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Calculate balance from transactions
    const balanceResult = await Transaction.aggregate([
      { $match: { userId: user._id } },
      { $group: { _id: null, total: { $sum: '$amount' } } }
    ]);
    const balance = balanceResult[0]?.total || 0;

    // Total contributions
    const contributionResult = await Transaction.aggregate([
      { $match: { userId: user._id, type: 'contribution' } },
      { $group: { _id: null, total: { $sum: '$amount' } } }
    ]);
    const totalContributions = contributionResult[0]?.total || 0;

    // Recent transactions
    const recentTransactions = await Transaction.find({ userId: user._id })
      .sort({ date: -1 })
      .limit(10);

    // Attendance stats
    const attendanceRecords = await Attendance.find({ userId: user._id });
    const totalPresent = attendanceRecords.filter(r => r.status === 'present').length;
    const totalAttendance = attendanceRecords.length;

    // Loan balance
    const loanResult = await Loan.aggregate([
      { $match: { userId: user._id, status: 'active' } },
      { $group: { _id: null, total: { $sum: '$outstandingBalance' } } }
    ]);
    const loanBalance = loanResult[0]?.total || 0;
    const activeLoans = await Loan.countDocuments({ userId: user._id, status: 'active' });

    res.json({
      user: {
        id: user._id,
        name: user.name,
        phone: user.phone
      },
      balance,
      totalContributions,
      recentTransactions,
      attendance: {
        totalPresent,
        totalAbsent: totalAttendance - totalPresent,
        total: totalAttendance,
        consistency: totalAttendance > 0 ? Math.round((totalPresent / totalAttendance) * 100) : 0
      },
      loanBalance,
      activeLoans
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
