const express = require('express');
const router = express.Router();
const Vehicle = require('./models/vehicleModel');
const { authMiddleware } = require('./user/userAuth');
const moment = require('moment-timezone');


function createEvent(stage, eventType, userId, additionalData = {}) {
  return {
    stage,
    eventType,
    performedBy: userId,
    timestamp: new Date(),
    additionalData
  };
}

function closeOpenStages(vehicle, now) {
  const stages = [
    'pickupDrop', 'interactiveBay', 'jobCardCreation', 'bayAllocation',
    'roadTest', 'bayWork', 'assignExpert', 'expertStage', 'partsEstimation',
    'additionalWork', 'partsOrder', 'finalInspection', 'jobCardReceived',
    'readyForWashing', 'washing', 'vasActivities'
  ];

  stages.forEach(stage => {
    if (vehicle[stage]?.startTime && !vehicle[stage]?.endTime) {
      vehicle[stage].endTime = now;
      vehicle[stage].isCompleted = true;
    }
  });
}

// Unified vehicle check endpoint
router.post('/vehicle-check', authMiddleware, async (req, res) => {
  try {
    console.log('Request Body:', req.body);

    const { vehicleNumber, stage, eventType, role, ...data } = req.body;
    const userId = req.user._id;
    const now = new Date();
    const TEN_MINUTES = 10 * 60 * 1000; // 10 minutes in milliseconds


    console.log('Parsed data:', { vehicleNumber, stage, eventType, role, userId, now });

    let vehicle = await Vehicle.findOne({ vehicleNumber }) || new Vehicle({ vehicleNumber });
    console.log('Vehicle found or created:', vehicle);

    // Push to history
    vehicle.history.push(createEvent(stage, eventType, userId, data));
    console.log('Event added to history:', vehicle.history);

    // Stage-specific logic
    switch (stage) {
      case 'pickupDrop':
        console.log('Handling Pickup & Drop stage...');
        if (eventType === 'Start') {
          console.log('Start event for Pickup & Drop');
          vehicle.pickupDrop = {
            startTime: now,
            performedBy: userId,
            pickupKM: data.pickupKM
          };
        }
        break;

      case 'securityGate':
        console.log('Handling Security Gate stage...');
        if (eventType === 'Start') {
          console.log('Start event for Security Gate');
          vehicle.securityGate = { 
            startTime: now, 
            performedBy: userId, 
            inKM: data.inKM 
          };
        } else if (eventType === 'End') {
          console.log('End event for Security Gate');
          if (!vehicle.securityGate) vehicle.securityGate = {};
          vehicle.securityGate.endTime = now;
          vehicle.securityGate.performedBy = userId;
          vehicle.securityGate.outKM = data.outKM;
          vehicle.securityGate.isCompleted = true;
          closeOpenStages(vehicle, now);
        }
        break;

      case 'interactiveBay':
        console.log('Handling Interactive Bay stage...');
        if (eventType === 'Start') {
          console.log('Start event for Interactive Bay');
          vehicle.interactiveBay = { 
            startTime: now, 
            performedBy: userId, 
            workType: data.workType 
          };
        } else if (eventType === 'End') {
          console.log('End event for Interactive Bay');
          vehicle.interactiveBay.endTime = now;
          vehicle.interactiveBay.endedBy = userId;
          vehicle.interactiveBay.isCompleted = true;
        }
        break;

      case 'jobCardCreation':
  console.log('Handling Job Card Creation stage...');
  if (eventType === 'Start') {
    // ✅ Check only if startTime exists
    if (vehicle.jobCardCreation?.startTime) {
      return res.status(400).json({
        message: 'Job card creation has already been started for this vehicle'
      });
    }

    console.log('Start event for Job Card Creation');
    vehicle.jobCardCreation = {
      startTime: now,
      performedBy: userId,
      isCompleted: false
    };
  }
  break;


  case 'additionalWork':
    console.log('Handling Additional Work Approval stage...');
    if (eventType === 'Start') {
      const lastStart = vehicle.additionalWork?.startTime;
      const canRestart = !lastStart || (now - new Date(lastStart)) > TEN_MINUTES;
  
      if (!canRestart) {
        return res.status(400).json({
          message: 'You must wait 10 minutes before restarting Additional Work Approval.'
        });
      }
  
      console.log('Start event for Additional Work Approval');
      vehicle.additionalWork = {
        startTime: now,
        performedBy: userId,
        isCompleted: false
      };
    }
    break;
  

    case 'readyForWashing':
      console.log('Handling Ready for Washing stage...');
      if (eventType === 'Start') {
        const lastStart = vehicle.readyForWashing?.startTime;
        const canRestart = !lastStart || (now - new Date(lastStart)) > TEN_MINUTES;
    
        if (!canRestart) {
          return res.status(400).json({
            message: 'You must wait 10 minutes before restarting Ready for Washing.'
          });
        }
    
        console.log('Start event for Ready for Washing');
        vehicle.readyForWashing = {
          startTime: now,
          performedBy: userId,
          isCompleted: false
        };
      }
      break;

      case 'bayAllocation':
        console.log('Handling Bay Allocation stage...');
        
        if (!vehicle.jobCardCreation?.startTime) {
          return res.status(400).json({
            message: 'Job card must be created before bay allocation'
          });
        }
      
        // Ensure userId is available (from auth middleware)
        if (!userId) {
          return res.status(400).json({ message: 'User authentication required' });
        }
      
        const existingAllocations = vehicle.bayAllocation || [];
        const isFirstAllocation = existingAllocations.length === 0;
      
        // Create new allocation with required fields
        const newAllocation = {
          startTime: new Date(),  // Explicitly set current time
          performedBy: userId,    // From authenticated user
          vehicleModel: data.vehicleModel,
          serviceType: data.serviceType,
          jobDescription: data.jobDescription,
          itemDescription: data.itemDescription,
          frtHours: data.frtHours,
          technicians: data.technicians || [], // Default empty array
          isFirstAllocation: isFirstAllocation
        };
      
        // Validate required fields
        if (!newAllocation.startTime || !newAllocation.performedBy) {
          console.error('Missing required fields:', {
            startTime: newAllocation.startTime,
            performedBy: newAllocation.performedBy
          });
          return res.status(400).json({ 
            message: 'Required fields missing for bay allocation' 
          });
        }
      
        // Update related stages
        if (isFirstAllocation) {
          if (vehicle.jobCardCreation && !vehicle.jobCardCreation.isCompleted) {
            vehicle.jobCardCreation.endTime = new Date();
            vehicle.jobCardCreation.isCompleted = true;
          }
        } else {
          if (vehicle.additionalWork && !vehicle.additionalWork.isCompleted) {
            vehicle.additionalWork.endTime = new Date();
            vehicle.additionalWork.isCompleted = true;
          }
        }
      
        // Add to bayAllocation array
        vehicle.bayAllocation = [...existingAllocations, newAllocation];
        break;
      


      case 'assignExpert':
      console.log('Handling Assign Expert stage...');
      if (eventType === 'Start') {

    console.log('Start event for Assign Expert');
    vehicle.assignExpert = {
      startTime: now,
      performedBy: userId,
      expertName: data.expertName,
      isCompleted: false
    };
  }
  break;

case 'jobCardReceived':
  console.log('Handling Job Card Received stage...');
  if (eventType === 'Start') {

    console.log('Start event for Job Card Received');
    vehicle.jobCardReceived = {
      startTime: now,
      performedBy: userId,
      isCompleted: false
    };
    
    // Auto-close if washing starts
  } else if (eventType === 'End') {
    console.log('End event for Job Card Received');
    if (!vehicle.jobCardReceived) vehicle.jobCardReceived = {};
    vehicle.jobCardReceived.endTime = now;
    vehicle.jobCardReceived.isCompleted = true;
  }
  break;
    

      

      case 'roadTest':
        console.log('Handling Road Test stage...');
        if (eventType === 'Start') {
          console.log('Start event for Road Test');
          vehicle.roadTest = { 
            startTime: now, 
            performedBy: userId 
          };
        } else if (eventType === 'End') {
          console.log('End event for Road Test');
          vehicle.roadTest.endTime = now;
          vehicle.roadTest.isCompleted = true;
        }
        break;

      case 'bayWork':
        console.log('Handling Bay Work stage...');
        if (eventType === 'Start') {
          console.log('Start event for Bay Work');
          vehicle.bayWork = { 
            startTime: now, 
            performedBy: userId,
            workType: data.workType,
            bayNumber: data.bayNumber
          };
        } else if (eventType === 'Pause') {
          console.log('Pause event for Bay Work');
          vehicle.bayWork.pauseTime = now;
        } else if (eventType === 'Resume') {
          console.log('Resume event for Bay Work');
          vehicle.bayWork.resumeTime = now;
        } else if (eventType === 'End') {
          console.log('End event for Bay Work');
          vehicle.bayWork.endTime = now;
          vehicle.bayWork.endedBy = userId; 
          vehicle.bayWork.isCompleted = true;
        }
        break;

      case 'assignExpert':
        console.log('Handling Assign Expert stage...');
        vehicle.assignExpert = { 
          startTime: now, 
          performedBy: userId,
          expertName: data.expertName
        };
        break;

      

      case 'partsEstimation':
        console.log('Handling Parts Estimation stage...');
        if (eventType === 'Start') {
          console.log('Start event for Parts Estimation');
          vehicle.partsEstimation = { 
            startTime: now, 
            performedBy: userId 
          };
        } else if (eventType === 'End') {
          console.log('End event for Parts Estimation');
          vehicle.partsEstimation.endTime = now;
          vehicle.partsEstimation.isCompleted = true;
        }
        break;

      case 'partsOrder':
        console.log('Handling Parts Order stage...');
        if (eventType === 'Start') {
          console.log('Start event for Parts Order');
          vehicle.partsOrder = { 
            startTime: now, 
            performedBy: userId,
            deliveryTime: data.deliveryTime,
            poNumber: data.poNumber
          };
        }
        break;

      case 'finalInspection':
        console.log('Handling Final Inspection stage...');
        if (eventType === 'Start') {
          console.log('Start event for Final Inspection');
          vehicle.finalInspection = { 
            startTime: now, 
            performedBy: userId,
            repairRequired: false,
            isCompleted: false
          };
        } else if (eventType === 'End') {
          console.log('End event for Final Inspection');
          if (typeof data.repairRequired !== 'boolean') {
            return res.status(400).json({ 
              error: 'repairRequired is required and must be a boolean (true or false)' 
            });
          }
          if (!vehicle.finalInspection) vehicle.finalInspection = {};
          vehicle.finalInspection.endTime = now;
          vehicle.finalInspection.isCompleted = true;
          vehicle.finalInspection.repairRequired = data.repairRequired;
          if (data.remarks !== undefined) {
            vehicle.finalInspection.remarks = data.remarks;
          }
        }
        break;

      case 'washing':
        console.log('Handling Washing stage...');
        if (!Array.isArray(vehicle.washing)) vehicle.washing = [];
        const lastWash = vehicle.washing[vehicle.washing.length - 1];

        if (eventType === 'Start') {
          console.log('Start event for Washing');
          // Close readyForWashing if open
          if (vehicle.readyForWashing && !vehicle.readyForWashing.isCompleted) {
            vehicle.readyForWashing.endTime = now;
            vehicle.readyForWashing.isCompleted = true;
          }
          if (lastWash && !lastWash.isCompleted) {
            return res.status(400).json({
              message: 'Cannot start new washing session while previous one is in progress'
            });
          }
          vehicle.washing.push({
            startTime: now,
            performedBy: userId,
            isCompleted: false
          });
        } else if (eventType === 'End') {
          console.log('End event for Washing');
          if (!lastWash) {
            return res.status(400).json({ message: 'No washing session has been started yet' });
          }
          lastWash.endTime = now;
          lastWash.isCompleted = true;
        }
        break;

      case 'vasActivities':
        console.log('Handling VAS Activities stage...');
        if (eventType === 'Start') {
          console.log('Start event for VAS Activities');
          vehicle.vasActivities = { 
            startTime: now, 
            performedBy: userId 
          };
        } else if (eventType === 'End') {
          console.log('End event for VAS Activities');
          vehicle.vasActivities.endTime = now;
          vehicle.vasActivities.isCompleted = true;
        }
        break;

      case 'driverDrop':
        console.log('Handling Driver Drop stage...');
        if (eventType === 'End') {
          console.log('End event for Driver Drop');
          if (!vehicle.driverDrop) vehicle.driverDrop = {};
          vehicle.driverDrop.endTime = now;
          vehicle.driverDrop.endedBy = userId;
          vehicle.driverDrop.isCompleted = true;
          vehicle.driverDrop.dropKM = data.dropKM;
        }
        break;

      default:
        console.log('Invalid stage encountered:', stage);
        return res.status(400).json({ error: 'Invalid stage' });
    }

    await vehicle.save();
    console.log('Vehicle saved:', vehicle);
    res.status(200).json({ 
      message: `${stage} stage ${eventType} recorded successfully`,
      vehicle 
    });
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});


router.get("/vehicles", async (req, res) => {
  try {
    const vehicles = await Vehicle.find().sort({ entryTime: -1 });

    if (vehicles.length === 0) {
      return res.status(404).json({ success: false, message: "No vehicles found." });
    }

    return res.status(200).json({ success: true, vehicles });
  } catch (error) {
    console.error("❌ Error in GET /vehicles:", error);
    res.status(500).json({ success: false, message: "Server error", error });
  }
});

router.get('/vehicles/:vehicleNumber/full-journey', async (req, res) => {
  try {
    const { vehicleNumber } = req.params;

    const vehicle = await Vehicle.findOne({ vehicleNumber })
      .populate([
        { path: 'pickupDrop.performedBy', select: 'name role' },
        { path: 'securityGate.performedBy', select: 'name role' },
        { path: 'interactiveBay.performedBy interactiveBay.endedBy', select: 'name role' },
        { path: 'jobCardCreation.performedBy', select: 'name role' },
        { path: 'bayAllocation.performedBy', select: 'name role' },
        { path: 'roadTest.performedBy', select: 'name role' },
        { path: 'bayWork.performedBy bayWork.endedBy', select: 'name role' },
        { path: 'assignExpert.performedBy', select: 'name role' },
        { path: 'expertStage.performedBy expertStage.endedBy', select: 'name role' },
        { path: 'partsEstimation.performedBy', select: 'name role' },
        { path: 'additionalWork.performedBy', select: 'name role' },
        { path: 'partsOrder.performedBy', select: 'name role' },
        { path: 'finalInspection.performedBy', select: 'name role' },
        { path: 'jobCardReceived.performedBy', select: 'name role' },
        { path: 'readyForWashing.performedBy', select: 'name role' },
        { path: 'driverDrop.endedBy', select: 'name role' },
        { path: 'washing.performedBy', select: 'name role' },
        { path: 'vasActivities.performedBy', select: 'name role' },
        { path: 'history.performedBy', select: 'name role' }
      ]);

    if (!vehicle) {
      return res.status(404).json({ message: 'Vehicle not found' });
    }

    const latestEvents = {};
    for (const event of vehicle.history || []) {
      const { stage, eventType, timestamp } = event;
      if (!latestEvents[stage] || new Date(timestamp) > new Date(latestEvents[stage].timestamp)) {
        latestEvents[stage] = {
          eventType,
          timestamp
        };
      }
    }

    const stageOrder = [
      'pickupDrop', 'securityGate', 'interactiveBay', 'jobCardCreation', 'bayAllocation',
      'roadTest', 'bayWork', 'assignExpert', 'expertStage', 'partsEstimation',
      'additionalWork', 'partsOrder', 'finalInspection', 'jobCardReceived',
      'readyForWashing', 'washing', 'vasActivities', 'driverDrop'
    ];

    const journey = [];

    for (const stage of stageOrder) {
      const value = vehicle[stage];
      if (!value) continue;

      const hasActivity = Array.isArray(value)
        ? value.some(session => session.startTime || session.performedBy)
        : value.startTime || value.performedBy || value.endedBy;

      if (!hasActivity) continue;

      const eventInfo = latestEvents[stage];
      const label = eventInfo ? `${stage} (${eventInfo.eventType})` : stage;

      const sortTime = eventInfo?.timestamp ||
        (Array.isArray(value)
          ? value[value.length - 1]?.startTime
          : value.startTime) || new Date(0);

      const formattedTime = moment(sortTime).tz('Asia/Kolkata').format('DD-MM-YYYY hh:mm A');

      journey.push({
        label,
        data: value,
        time: sortTime,
        formattedTime
      });
    }

    // Sort by most recent activity
    journey.sort((a, b) => new Date(b.time) - new Date(a.time));

    const formatted = {};
    for (const item of journey) {
      formatted[item.label] = {
        ...item.data,
        formattedActivityTime: item.formattedTime
      };
    }

    res.json({
      vehicleNumber: vehicle.vehicleNumber,
      journey: formatted
    });
  } catch (error) {
    console.error('Error fetching vehicle journey:', error);
    res.status(500).json({ message: 'Server error' });
  }
});





module.exports = router;