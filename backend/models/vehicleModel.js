const mongoose = require('mongoose');
const { Schema } = mongoose;

// Common stage fields
const stageSchema = {
  startTime: Date,
  endTime: Date,
  performedBy: { type: Schema.Types.ObjectId, ref: 'User' },
  isCompleted: { type: Boolean, default: false }
};

// Track all events
const eventSchema = new Schema({
  stage: { type: String, required: true },
  eventType: { type: String, enum: ['Start', 'Pause', 'Resume', 'End'], required: true },
  performedBy: { type: Schema.Types.ObjectId, ref: 'User', required: true },
  timestamp: { type: Date, default: Date.now },
  additionalData: Schema.Types.Mixed
}, { _id: false });

const vehicleSchema = new Schema({
  vehicleNumber: { type: String, required: true, unique: true },

  // 1. Pickup (Start Only)
  pickupDrop: {
    startTime: Date,
    performedBy: { type: Schema.Types.ObjectId, ref: 'User' }, // 👈 pickup driver
    pickupKM: Number
  },

  // 2. Security Gate
  securityGate: {
    ...stageSchema,
    inKM: Number,
    outKM: Number
  },

  // 3. Interactive Bay (with endedBy)
  interactiveBay: {
    startTime: Date,
    endTime: Date,
    performedBy: { type: Schema.Types.ObjectId, ref: 'User' },
    endedBy: { type: Schema.Types.ObjectId, ref: 'User' }, // 👈
    isCompleted: { type: Boolean, default: false },
    workType: String
  },

  // 4. Job Card Creation (Start Only)
  jobCardCreation: {
    startTime: Date,
    performedBy: { type: Schema.Types.ObjectId, ref: 'User' }
  },

  // 5. Bay Allocation (Start Only)
  bayAllocation: {
    startTime: Date,
    performedBy: { type: Schema.Types.ObjectId, ref: 'User' },
    vehicleModel: String,
    workType: String,
    frt: String,
    technicianName: String
  },

  // 6. Road Test
  roadTest: stageSchema,

  // 7. Bay Work (with endedBy)
  bayWork: {
    startTime: Date,
    endTime: Date,
    performedBy: { type: Schema.Types.ObjectId, ref: 'User' },
    endedBy: { type: Schema.Types.ObjectId, ref: 'User' },
    isCompleted: { type: Boolean, default: false },
    workType: String,
    bayNumber: String,
    pauseTime: Date,
    resumeTime: Date
  },

  // 8. Assign Expert (Start Only)
  assignExpert: {
    startTime: Date,
    performedBy: { type: Schema.Types.ObjectId, ref: 'User' },
    expertName: String
  },

  // 9. Expert Stage (with endedBy)
  expertStage: {
    startTime: Date,
    endTime: Date,
    performedBy: { type: Schema.Types.ObjectId, ref: 'User' },
    endedBy: { type: Schema.Types.ObjectId, ref: 'User' },
    isCompleted: { type: Boolean, default: false }
  },

  // 10. Parts Estimation
  partsEstimation: stageSchema,

  // 11. Additional Work Approval (Start Only)
  additionalWork: {
    startTime: Date,
    performedBy: { type: Schema.Types.ObjectId, ref: 'User' },
    status: { type: String, enum: ['Approved', 'Not Approved'] }
  },

  // 12. Parts Order (Start Only)
  partsOrder: {
    startTime: Date,
    performedBy: { type: Schema.Types.ObjectId, ref: 'User' },
    deliveryTime: Date,
    poNumber: String
  },

  // 15. Final Inspection
  finalInspection: {
    ...stageSchema,
    repairRequired: Boolean,
    remarks: String
  },

  // 16. Job Card Received (Start Only)
  jobCardReceived: {
    startTime: Date,
    performedBy: { type: Schema.Types.ObjectId, ref: 'User' }
  },

  // 17. Ready for Washing (Start Only)
  readyForWashing: {
    startTime: Date,
    performedBy: { type: Schema.Types.ObjectId, ref: 'User' }
  },

  // 18. Washing
  washing: stageSchema,

  // 19. VAS Activities
  vasActivities: stageSchema,

  // 20. Driver Drop (End Only)
  driverDrop: {
    endTime: Date,
    endedBy: { type: Schema.Types.ObjectId, ref: 'User' }, // 👈 drop driver
    isCompleted: { type: Boolean, default: false }
  },

  // Full history of all events
  history: [eventSchema],

  isDeleted: { type: Boolean, default: false }

}, { timestamps: true });

module.exports = mongoose.model('Vehicle', vehicleSchema);
