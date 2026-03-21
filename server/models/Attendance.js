const mongoose = require('mongoose');

const attendanceSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  date: {
    type: Date,
    required: true
  },
  status: {
    type: String,
    enum: ['present', 'absent'],
    required: true
  },
  markedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }
}, {
  timestamps: true
});

// One attendance record per user per date
attendanceSchema.index({ userId: 1, date: 1 }, { unique: true });

module.exports = mongoose.model('Attendance', attendanceSchema);
