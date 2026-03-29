const mongoose = require('mongoose');

const loanSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  amount: {
    type: Number,
    required: [true, 'Loan amount is required'],
    min: [1, 'Loan amount must be positive']
  },
  outstandingBalance: {
    type: Number,
    required: true
  },
  status: {
    type: String,
    enum: ['active', 'repaid'],
    default: 'active'
  },
  note: {
    type: String,
    default: ''
  },
  issuedDate: {
    type: Date,
    default: Date.now
  },
  repaidDate: {
    type: Date,
    default: null
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }
}, {
  timestamps: true
});

// Index for fast lookups
loanSchema.index({ userId: 1, status: 1 });
loanSchema.index({ status: 1 });

module.exports = mongoose.model('Loan', loanSchema);
