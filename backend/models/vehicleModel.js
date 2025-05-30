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
  eventType: { type: String, enum: ['Start', 'Pause', 'Resume', 'End', 'AdditionalWorkNeeded'], required: true },
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
    outKM: Number,
    bringBy: { type: String, enum: ['Driver', 'Customer'] },
    customerName: String,
    takeOutBy: { type: String, enum: ['Driver', 'Customer'] },
    customerNameOut: String
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
    performedBy: { type: Schema.Types.ObjectId, ref: 'User' }, // This tracks the user who started the Job Card Creation
    isCompleted: { type: Boolean, default: false },
    concerns: [
      {
        comment: String, // The concern or issue noticed by the user
        addedAt: { type: Date, default: Date.now } // Timestamp of when the concern was added
      }
    ]
  },
  

  // 5. Bay Allocation (Start Only)
  bayAllocation: [{
  startTime: Date,
  performedBy: { type: Schema.Types.ObjectId, ref: 'User' },
  vehicleModel: String,
  jobDescription: String,
  serviceTypes: [String], // <-- Array of service types
  items: [{
    itemDescription: String,
    frtHours: Number
  }],                    // <-- Array of items with FRTs
  technicians: [{ type: Schema.Types.ObjectId, ref: 'User' }],
  isFirstAllocation: Boolean
}],

  

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
    resumeTime: Date,
  
    additionalWorkLogs: [
      {
        description: { type: String, required: true },
        addedAt: { type: Date, default: Date.now }
      }
    ]
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
    isCompleted: { type: Boolean, default: false }
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
    repairRequired: {
      type: Boolean,
      required: function () {
        return this.finalInspection?.startTime != null || this.finalInspection?.endTime != null;
      }
    },
    remarks: { type: String }
  },

  // 16. Job Card Received (Start Only)
  jobCardReceived: {
    startTime: Date,
    performedBy: { type: Schema.Types.ObjectId, ref: 'User' }
  },

  // 17. Ready for Washing (Start Only)
  readyForWashing: {
    startTime: Date,
    performedBy: { type: Schema.Types.ObjectId, ref: 'User' },
    isCompleted: { type: Boolean, default: false },
    washingType: { type: String, enum: ['Free', 'Paid'], default: 'Free' } // ✅ Add this
  },
  
  
  

  washing: [new Schema({
    startTime: Date,
    endTime: Date,
    performedBy: { type: Schema.Types.ObjectId, ref: 'User' },
    isCompleted: { type: Boolean, default: false }
  }, { _id: true })],

  // 19. VAS Activities
  vasActivities: stageSchema,

  // 20. Driver Drop (End Only)
  driverDrop: {
    endTime: Date,
    endedBy: { type: Schema.Types.ObjectId, ref: 'User' }, // 👈 drop driver
    isCompleted: { type: Boolean, default: false },
    dropKM: Number
  },

  // Full history of all events
  history: [eventSchema],

  isDeleted: { type: Boolean, default: false }

}, { timestamps: true });

module.exports = mongoose.model('Vehicle', vehicleSchema);