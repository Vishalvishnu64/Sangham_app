const express = require('express');
const User = require('../models/User');
const Transaction = require('../models/Transaction');
const AuditLog = require('../models/AuditLog');
const { auth, adminOnly } = require('../middleware/auth');

const router = express.Router();

// GET /api/members - List all members
router.get('/', auth, adminOnly, async (req, res) => {
  try {
    const members = await User.find({ role: 'user', isActive: true })
      .select('-password')
      .sort({ name: 1 });

    // Calculate balance for each member from transactions
    const membersWithBalance = await Promise.all(
      members.map(async (member) => {
        const result = await Transaction.aggregate([
          { $match: { userId: member._id } },
          { $group: { _id: null, total: { $sum: '$amount' } } }
        ]);
        const balance = result.length > 0 ? result[0].total : 0;
        return { ...member.toObject(), balance };
      })
    );

    res.json({ members: membersWithBalance });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// POST /api/members - Add new member
router.post('/', auth, adminOnly, async (req, res) => {
  try {
    const { name, phone, password } = req.body;

    const existing = await User.findOne({ phone });
    if (existing) {
      return res.status(400).json({ message: 'Phone number already registered' });
    }

    const user = new User({
      name,
      phone,
      password: password || phone.slice(-4), // Default password = last 4 digits of phone
      role: 'user'
    });
    await user.save();

    // Audit log
    await AuditLog.create({
      action: 'create',
      entity: 'user',
      entityId: user._id,
      newValue: { name, phone },
      performedBy: req.user._id
    });

    res.status(201).json({
      message: 'Member added successfully',
      member: { id: user._id, name: user.name, phone: user.phone, role: user.role }
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// PUT /api/members/:id - Edit member
router.put('/:id', auth, adminOnly, async (req, res) => {
  try {
    const { name, phone } = req.body;
    const member = await User.findById(req.params.id);

    if (!member) {
      return res.status(404).json({ message: 'Member not found' });
    }

    const oldValue = { name: member.name, phone: member.phone };

    if (name) member.name = name;
    if (phone) member.phone = phone;
    await member.save();

    // Audit log
    await AuditLog.create({
      action: 'edit',
      entity: 'user',
      entityId: member._id,
      oldValue,
      newValue: { name: member.name, phone: member.phone },
      performedBy: req.user._id
    });

    res.json({
      message: 'Member updated successfully',
      member: { id: member._id, name: member.name, phone: member.phone }
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// DELETE /api/members/:id - Soft delete member
router.delete('/:id', auth, adminOnly, async (req, res) => {
  try {
    const member = await User.findById(req.params.id);
    if (!member) {
      return res.status(404).json({ message: 'Member not found' });
    }

    member.isActive = false;
    await member.save();

    // Audit log
    await AuditLog.create({
      action: 'delete',
      entity: 'user',
      entityId: member._id,
      oldValue: { name: member.name, phone: member.phone, isActive: true },
      newValue: { isActive: false },
      performedBy: req.user._id
    });

    res.json({ message: 'Member removed successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
