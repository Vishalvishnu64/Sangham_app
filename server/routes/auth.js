const express = require('express');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { auth } = require('../middleware/auth');

const router = express.Router();

// POST /api/auth/register - Admin creates a user account
router.post('/register', async (req, res) => {
  try {
    const { name, phone, password, role } = req.body;

    // Check if phone already exists
    const existing = await User.findOne({ phone });
    if (existing) {
      return res.status(400).json({ message: 'Phone number already registered' });
    }

    const user = new User({ name, phone, password, role: role || 'user' });
    await user.save();

    res.status(201).json({
      message: 'User registered successfully',
      user: { id: user._id, name: user.name, phone: user.phone, role: user.role }
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// POST /api/auth/login
router.post('/login', async (req, res) => {
  try {
    const { phone, password } = req.body;

    const user = await User.findOne({ phone });
    if (!user) {
      return res.status(400).json({ message: 'Invalid phone number or password' });
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid phone number or password' });
    }

    const token = jwt.sign(
      { id: user._id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      token,
      user: {
        id: user._id,
        name: user.name,
        phone: user.phone,
        role: user.role
      }
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// GET /api/auth/me - Get current user
router.get('/me', auth, async (req, res) => {
  try {
    res.json({ user: req.user });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
