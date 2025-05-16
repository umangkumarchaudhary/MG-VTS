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
    const commentText = data.commentText;



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
        
            if (!data.bringBy || !['Driver', 'Customer'].includes(data.bringBy)) {
              return res.status(400).json({ message: 'Invalid or missing bringBy value (Driver or Customer expected).' });
            }
        
            if (data.bringBy === 'Customer' && !data.customerName) {
              return res.status(400).json({ message: 'Customer name is required when bringBy is Customer.' });
            }
        
            vehicle.securityGate = {
              startTime: now,
              performedBy: userId,
              inKM: data.inKM,
              bringBy: data.bringBy,
              customerName: data.bringBy === 'Customer' ? data.customerName : undefined,
            };
        
          } else if (eventType === 'End') {
            console.log('End event for Security Gate');
        
            if (!vehicle.securityGate) vehicle.securityGate = {};
        
            if (!data.takeOutBy || !['Driver', 'Customer'].includes(data.takeOutBy)) {
              return res.status(400).json({ message: 'Invalid or missing takeOutBy value (Driver or Customer expected).' });
            }
        
            if (data.takeOutBy === 'Customer' && !data.customerNameOut) {
              return res.status(400).json({ message: 'Customer name is required when takeOutBy is Customer.' });
            }
        
            vehicle.securityGate.endTime = now;
            vehicle.securityGate.performedBy = userId;
            vehicle.securityGate.outKM = data.outKM;
            vehicle.securityGate.takeOutBy = data.takeOutBy;
            vehicle.securityGate.customerNameOut = data.takeOutBy === 'Customer' ? data.customerNameOut : undefined;
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
        
            // Validate if the user has provided a comment (concern)
            if (!commentText || commentText.trim() === '') {
              return res.status(400).json({
                message: 'You must provide a concern/comment when starting the job card creation process.'
              });
            }
        
            console.log('Start event for Job Card Creation');
            vehicle.jobCardCreation = {
              startTime: now,
              performedBy: userId,
              isCompleted: false,
              concern: commentText, // Storing the comment/concern provided by the user
              addedAt: now // Timestamp when the concern/comment was added
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
      console.log('Restart not allowed. Last start time:', lastStart);
      return res.status(400).json({
        message: 'You must wait 10 minutes before restarting Ready for Washing.'
      });
    }

    const { washingType } = data;
    console.log('Washing Type from client:', washingType);

    if (!washingType || !['Free', 'Paid'].includes(washingType)) {
      return res.status(400).json({
        message: 'You must provide washingType as either "Free" or "Paid".'
      });
    }

    vehicle.readyForWashing = {
      startTime: now,
      performedBy: userId,
      isCompleted: false,
      washingType
    };

    console.log('vehicle.readyForWashing set to:', vehicle.readyForWashing);

    vehicle.history.push(createEvent(stage, eventType, userId, { washingType }));
    console.log('Event pushed to history:', vehicle.history[vehicle.history.length - 1]);
  }
  break;

    



      case 'bayAllocation':
  console.log('Handling Bay Allocation stage...');

  // Ensure userId is available (from auth middleware)
  if (!userId) {
    return res.status(400).json({ message: 'User authentication required' });
  }

  const existingAllocations = vehicle.bayAllocation || [];
  const isFirstAllocation = existingAllocations.length === 0;

  // Create new allocation with required fields (arrays for serviceTypes and items)
  const newAllocation = {
    startTime: new Date(),
    performedBy: userId,
    vehicleModel: data.vehicleModel,
    jobDescription: data.jobDescription,
    serviceTypes: Array.isArray(data.serviceTypes) ? data.serviceTypes : [data.serviceTypes],
    items: Array.isArray(data.items) ? data.items : [],
    technicians: data.technicians || [],
    isFirstAllocation: isFirstAllocation
  };

  // Validate required fields
  if (!newAllocation.startTime || !newAllocation.performedBy) {
    return res.status(400).json({ message: 'Required fields missing for bay allocation' });
  }
  if (!newAllocation.serviceTypes.length) {
    return res.status(400).json({ message: 'At least one service type is required.' });
  }
  if (!newAllocation.items.length) {
    return res.status(400).json({ message: 'At least one item is required.' });
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
  } 
    

      

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

  // Ensure bayWork exists before accessing nested fields
  if (!vehicle.bayWork) {
    vehicle.bayWork = {};
  }

  if (eventType === 'Start') {
    console.log('Start event for Bay Work');
    vehicle.bayWork = {
      startTime: now,
      performedBy: userId,
      workType: data.workType,
      bayNumber: data.bayNumber,
      additionalWorkLogs: [] // Initialize logs
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

  } else if (eventType === 'AdditionalWorkNeeded') {
    console.log('Technician reported additional work needed');

    const commentText = data?.additionalData?.commentText;

if (!commentText || commentText.trim() === '') {
  return res.status(400).json({ message: 'Please provide a description for the additional work.' });
}


    if (!vehicle.bayWork.additionalWorkLogs) {
      vehicle.bayWork.additionalWorkLogs = [];
    }

    vehicle.bayWork.additionalWorkLogs.push({
      description: commentText,
      addedAt: now
    });
  }

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

router.get('/user-stage-history', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;
    
    // Find all vehicles where the user has performed any of these stages
    const vehicles = await Vehicle.find({
      $or: [
        { 'jobCardCreation.performedBy': userId },
        { 'additionalWork.performedBy': userId },
        { 'readyForWashing.performedBy': userId }
      ]
    });

    // Filter history to only include these specific stages performed by this user
    const userHistory = vehicles.map(vehicle => {
      return {
        vehicleNumber: vehicle.vehicleNumber,
        stages: vehicle.history.filter(event => 
          (event.stage === 'jobCardCreation' || 
           event.stage === 'additionalWork' || 
           event.stage === 'readyForWashing') &&
          event.performedBy.toString() === userId.toString()
        )
      };
    }).filter(vehicle => vehicle.stages.length > 0); // Only include vehicles with matching stages

    res.status(200).json(userHistory);
  } catch (error) {
    console.error('Error fetching user stage history:', error);
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

// GET /vehicle-history/:vehicleNumber
router.get('/vehicle-history/:vehicleNumber', authMiddleware, async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    if (!vehicleNumber) {
      return res.status(400).json({ message: 'Vehicle number is required' });
    }

    // Find the vehicle by vehicleNumber
    const vehicle = await Vehicle.findOne({ vehicleNumber })
      .populate('history.performedBy', 'name email') // Optional: populate user info
      .lean();

    if (!vehicle) {
      return res.status(404).json({ message: 'Vehicle not found' });
    }

    // Get history, sort from latest to oldest
    const history = (vehicle.history || [])
      .slice() // clone array
      .sort((a, b) => new Date(b.time || b.timestamp || b.startTime) - new Date(a.time || a.timestamp || a.startTime));

    // Format output for each history entry
    const formattedHistory = history.map(event => ({
      stage: event.stage,
      eventType: event.eventType,
      performedBy: event.performedBy?.name || event.performedBy || 'Unknown',
      time: event.time || event.timestamp || event.startTime,
      comment: event.commentText || event.comment || undefined,
      extra: event.extra || undefined
    }));

    res.json({
      vehicleNumber: vehicle.vehicleNumber,
      history: formattedHistory
    });
  } catch (error) {
    console.error('Error in /vehicle-history/:vehicleNumber:', error);
    res.status(500).json({ message: 'Server error' });
  }
});


module.exports = router;