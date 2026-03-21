const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  amount: {
    type: Number,
    required: [true, 'Amount is required']
  },
  type: {
    type: String,
    enum: ['contribution', 'loan', 'loan_repayment', 'penalty', 'withdrawal'],
    default: 'contribution'
  },
  note: {
    type: String,
    default: ''
  },
  date: {
    type: Date,
    default: Date.now
  },
  week: {
    type: Number // Week number for tracking weekly contributions
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }
}, {
  timestamps: true
});

// Index for fast lookups
transactionSchema.index({ userId: 1, date: -1 });
transactionSchema.index({ date: -1 });

module.exports = mongoose.model('Transaction', transactionSchema);
