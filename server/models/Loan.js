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
  principalAmount: {
    type: Number,
    required: true
  },
  remainingPrincipal: {
    type: Number,
    required: true
  },
  outstandingBalance: {
    type: Number,
    required: true
  },
  interestRate: {
    type: Number,
    default: 0.01 // 1% per month (100 per 10,000)
  },
  currentMonthInterest: {
    type: Number,
    default: 0
  },
  totalInterestPaid: {
    type: Number,
    default: 0
  },
  interestCalculatedDate: {
    type: Date,
    default: null
  },
  repayments: [{
    date: {
      type: Date,
      default: Date.now
    },
    principalPaid: Number,
    interestPaid: Number,
    totalPaid: Number,
    remainingBalance: Number
  }],
  status: {
    type: String,
    enum: ['active', 'repaid', 'overdue'],
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
