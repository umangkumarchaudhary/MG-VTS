const express = require('express');
const router = express.Router();
const Vehicle = require('./models/vehicleModel');
const { authMiddleware } = require('./user/userAuth');


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
    console.log('Request Body:', req.body);  // Debug: check the incoming request

    const { vehicleNumber, stage, eventType, role, ...data } = req.body;
    const userId = req.user._id;
    const now = new Date();

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
        
            // Initialize if missing
            if (!vehicle.securityGate) {
              vehicle.securityGate = {};
            }
        
            vehicle.securityGate.endTime = now;
            vehicle.securityGate.performedBy = userId; // ensure this is set
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
        vehicle.jobCardCreation = { 
          startTime: now, 
          performedBy: userId 
        };
        break;

      case 'bayAllocation':
        console.log('Handling Bay Allocation stage...');
        vehicle.bayAllocation = { 
          startTime: now, 
          performedBy: userId, 
          vehicleModel: data.vehicleModel, 
          workType: data.workType,
          technicianName: data.technicianName,
          frt: data.frt
        };

        const existingAllocations = vehicle.bayAllocations || [];
        if (existingAllocations.length === 0) {
          console.log('First Bay Allocation, closing Job Card Creation and Customer Approval if not already closed');
          if (vehicle.jobCardCreation && !vehicle.jobCardCreation.endTime) {
            vehicle.jobCardCreation.endTime = now;
            vehicle.jobCardCreation.isCompleted = true;
          }
          if (vehicle.customerApproval && !vehicle.customerApproval.endTime) {
            vehicle.customerApproval.endTime = now;
            vehicle.customerApproval.isCompleted = true;
          }
        } else {
          console.log('Subsequent Bay Allocation, closing Additional Work if not already closed');
          if (vehicle.additionalWork && !vehicle.additionalWork.endTime) {
            vehicle.additionalWork.endTime = now;
            vehicle.additionalWork.isCompleted = true;
          }
        }

        // Save allocation history (if you support multiple)
        vehicle.bayAllocations = [...existingAllocations, vehicle.bayAllocation];
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

      case 'expertStage':
        console.log('Handling Expert Stage...');
        if (eventType === 'Start') {
          console.log('Start event for Expert Stage');
          vehicle.expertStage = { 
            startTime: now, 
            performedBy: userId 
          };
        } else if (eventType === 'End') {
          console.log('End event for Expert Stage');
          vehicle.expertStage.endTime = now;
          vehicle.expertStage.endedBy = userId;
          vehicle.expertStage.isCompleted = true;
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

      case 'additionalWork':
        console.log('Handling Additional Work stage...');
        if (eventType === 'Start') {
          console.log('Start event for Additional Work');
          vehicle.additionalWork = { 
            startTime: now, 
            performedBy: userId,
            status: data.status
          };
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
            performedBy: userId 
          };
        } else if (eventType === 'End') {
          console.log('End event for Final Inspection');
          vehicle.finalInspection.endTime = now;
          vehicle.finalInspection.isCompleted = true;
          vehicle.finalInspection.repairRequired = data.repairRequired;
          vehicle.finalInspection.remarks = data.remarks;
        }
        break;

      case 'jobCardReceived':
        console.log('Handling Job Card Received stage...');
        vehicle.jobCardReceived = { 
          startTime: now, 
          performedBy: userId 
        };
        break;

      case 'readyForWashing':
        console.log('Handling Ready for Washing stage...');
        vehicle.readyForWashing = { 
          startTime: now, 
          performedBy: userId 
        };
        break;

      case 'washing':
        console.log('Handling Washing stage...');
        if (eventType === 'Start') {
          console.log('Start event for Washing');
          vehicle.washing = { 
            startTime: now, 
            performedBy: userId 
          };
        } else if (eventType === 'End') {
          console.log('End event for Washing');
          vehicle.washing.endTime = now;
          vehicle.washing.isCompleted = true;
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
            
            // Initialize if null
            if (!vehicle.driverDrop) vehicle.driverDrop = {};
        
            vehicle.driverDrop.endTime = now;
            vehicle.driverDrop.endedBy = userId; // ✅ store dropping driver
            vehicle.driverDrop.isCompleted = true;
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



module.exports = router;