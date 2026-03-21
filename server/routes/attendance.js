const express = require('express');
const Attendance = require('../models/Attendance');
const User = require('../models/User');
const { auth, adminOnly } = require('../middleware/auth');

const router = express.Router();

// POST /api/attendance/bulk - Mark attendance for multiple members
router.post('/bulk', auth, adminOnly, async (req, res) => {
  try {
    const { records, date } = req.body;
    // records: [{ userId, status }]
    const attendanceDate = date ? new Date(date) : new Date();
    attendanceDate.setHours(0, 0, 0, 0);

    const operations = records.map(record => ({
      updateOne: {
        filter: { userId: record.userId, date: attendanceDate },
        update: {
          $set: {
            status: record.status,
            markedBy: req.user._id
          }
        },
        upsert: true
      }
    }));

    await Attendance.bulkWrite(operations);

    res.json({
      message: `Attendance marked for ${records.length} members`,
      date: attendanceDate
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// GET /api/attendance/today - Today's attendance summary
router.get('/today', auth, async (req, res) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const records = await Attendance.find({ date: today })
      .populate('userId', 'name phone');

    const totalMembers = await User.countDocuments({ role: 'user', isActive: true });
    const presentCount = records.filter(r => r.status === 'present').length;
    const absentCount = records.filter(r => r.status === 'absent').length;

    res.json({
      date: today,
      records,
      totalMembers,
      presentCount,
      absentCount,
      notMarked: totalMembers - records.length
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// GET /api/attendance/user/:userId - Get user's attendance history
router.get('/user/:userId', auth, async (req, res) => {
  try {
    // Users can only view their own attendance
    if (req.user.role !== 'admin' && req.user._id.toString() !== req.params.userId) {
      return res.status(403).json({ message: 'Access denied' });
    }

    const { month, year } = req.query;
    const query = { userId: req.params.userId };

    // Filter by month/year if provided
    if (month && year) {
      const startDate = new Date(year, month - 1, 1);
      const endDate = new Date(year, month, 0);
      query.date = { $gte: startDate, $lte: endDate };
    }

    const records = await Attendance.find(query).sort({ date: -1 });

    // Calculate stats
    const totalPresent = records.filter(r => r.status === 'present').length;
    const totalAbsent = records.filter(r => r.status === 'absent').length;

    res.json({
      records,
      stats: {
        totalPresent,
        totalAbsent,
        total: records.length,
        consistency: records.length > 0
          ? Math.round((totalPresent / records.length) * 100)
          : 0
      }
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// GET /api/attendance/date/:date - Get attendance for a specific date
router.get('/date/:date', auth, adminOnly, async (req, res) => {
  try {
    const date = new Date(req.params.date);
    date.setHours(0, 0, 0, 0);

    const allMembers = await User.find({ role: 'user', isActive: true }).select('name phone');
    const records = await Attendance.find({ date });

    const recordMap = {};
    records.forEach(r => {
      recordMap[r.userId.toString()] = r.status;
    });

    const attendance = allMembers.map(m => ({
      userId: m._id,
      name: m.name,
      phone: m.phone,
      status: recordMap[m._id.toString()] || 'not_marked'
    }));

    res.json({ date, attendance });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
