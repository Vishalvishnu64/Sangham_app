const mongoose = require('mongoose');

const auditLogSchema = new mongoose.Schema({
  action: {
    type: String,
    enum: ['create', 'edit', 'delete'],
    required: true
  },
  entity: {
    type: String, // 'transaction', 'attendance', 'user'
    required: true
  },
  entityId: {
    type: mongoose.Schema.Types.ObjectId,
    required: true
  },
  oldValue: {
    type: mongoose.Schema.Types.Mixed
  },
  newValue: {
    type: mongoose.Schema.Types.Mixed
  },
  performedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  }
}, {
  timestamps: true
});

auditLogSchema.index({ entity: 1, entityId: 1 });
auditLogSchema.index({ performedBy: 1 });

module.exports = mongoose.model('AuditLog', auditLogSchema);
