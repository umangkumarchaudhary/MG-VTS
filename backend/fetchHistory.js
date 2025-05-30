const express = require('express');
const router = express.Router();
const Vehicle = require('./models/vehicleModel');
const { authMiddleware } = require('./user/userAuth');
const { User } = require('./user/userAuth');


router.get('/security-gate-history', authMiddleware, async (req, res) => {
  try {
    const { vehicleNumber, fromDate, toDate } = req.query;

    // Build query object
    let query = {
      'securityGate.startTime': { $exists: true } // Only vehicles with IN recorded
    };

    if (vehicleNumber) {
      query.vehicleNumber = { $regex: vehicleNumber, $options: 'i' }; // Case-insensitive
    }

    if (fromDate || toDate) {
      query['securityGate.startTime'] = {};
      if (fromDate) query['securityGate.startTime'].$gte = new Date(fromDate);
      if (toDate) query['securityGate.startTime'].$lte = new Date(toDate);
    }

    const vehicles = await Vehicle.find(query).lean();

    const inVehicles = [];
    const outVehicles = [];

    // Format date to Indian format with 12-hour clock and AM/PM
    const formatToIST = (date) => {
      return new Date(date).toLocaleString('en-IN', {
        timeZone: 'Asia/Kolkata',
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        hour12: true,
      });
    };

    vehicles.forEach(vehicle => {
      const sg = vehicle.securityGate;
      if (sg) {
        if (sg.isCompleted && sg.endTime && sg.outKM !== undefined) {
          // OUT vehicles
          outVehicles.push({
            vehicleNumber: vehicle.vehicleNumber,
            inKM: sg.inKM,
            outKM: sg.outKM,
            inTime: formatToIST(sg.startTime),
            outTime: formatToIST(sg.endTime),
            bringBy: sg.bringBy || '',
            customerName: sg.customerName || '',
            takeOutBy: sg.takeOutBy || '',
            customerNameOut: sg.customerNameOut || ''
          });
        } else {
          // IN vehicles
          inVehicles.push({
            vehicleNumber: vehicle.vehicleNumber,
            inKM: sg.inKM,
            inTime: formatToIST(sg.startTime),
            bringBy: sg.bringBy || '',
            customerName: sg.customerName || ''
          });
        }
      }
    });

    res.status(200).json({
      inVehicles,
      outVehicles
    });

  } catch (error) {
    console.error('Error fetching security gate history:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

  
  router.get('/vehicle-progress/interactiveBay', authMiddleware, async (req, res) => {
  try {
    const vehicles = await Vehicle.find({
      "interactiveBay.startTime": { $exists: true }
    }).populate([
      { path: 'interactiveBay.performedBy', select: 'name' },
      { path: 'interactiveBay.endedBy', select: 'name' }
    ]);

    const now = new Date();
    const inProgress = [];
    const completed = [];

    for (const v of vehicles) {
      const stage = v.interactiveBay;

      const base = {
        vehicleNumber: v.vehicleNumber,
        stageName: 'Interactive Bay',
        workType: stage?.workType || '',
        startedBy: stage?.performedBy?.name || 'N/A',
        startedAt: stage?.startTime,
        startedAtFormatted: stage?.startTime?.toLocaleString(),
      };

      if (!stage.endTime) {
        const elapsedMs = now - new Date(stage.startTime);
        inProgress.push({
          ...base,
          status: 'In Progress',
          totalTime: msToDuration(elapsedMs),
        });
      } else {
        const durationMs = new Date(stage.endTime) - new Date(stage.startTime);
        completed.push({
          ...base,
          status: 'Completed',
          endedBy: stage?.endedBy?.name || 'System',
          endedAt: stage.endTime,
          endedAtFormatted: stage.endTime.toLocaleString(),
          totalTime: msToDuration(durationMs),
        });
      }
    }

    res.json({ inProgress, completed });
  } catch (err) {
    console.error('Error in progress route:', err);
    res.status(500).json({ message: 'Internal server error' });
  }
});


router.get('/vehicle-progress/bayWork', authMiddleware, async (req, res) => {
  try {
    const vehicles = await Vehicle.find({
      "bayWork.startTime": { $exists: true }
    }).populate([
      { path: 'bayWork.performedBy', select: 'name' },
      { path: 'bayWork.endedBy', select: 'name' }
    ]);

    const now = new Date();
    const inProgress = [];
    const completed = [];

    for (const v of vehicles) {
      const stage = v.bayWork;

      const base = {
        vehicleNumber: v.vehicleNumber,
        stageName: 'Bay Work',
        workType: stage?.workType || '',
        bayNumber: stage?.bayNumber || '',
        startedBy: stage?.performedBy?.name || 'N/A',
        startedAt: stage?.startTime,
        startedAtFormatted: stage?.startTime?.toLocaleString(),
      };

      if (!stage.endTime) {
        const elapsedMs = now - new Date(stage.startTime);
        inProgress.push({
          ...base,
          status: 'In Progress',
          totalTime: msToDuration(elapsedMs),
        });
      } else {
        const durationMs = new Date(stage.endTime) - new Date(stage.startTime);
        completed.push({
          ...base,
          status: 'Completed',
          endedBy: stage?.endedBy?.name || 'System',
          endedAt: stage.endTime,
          endedAtFormatted: stage.endTime.toLocaleString(),
          totalTime: msToDuration(durationMs),
        });
      }
    }

    res.json({ inProgress, completed });
  } catch (err) {
    console.error('Error in bayWork progress route:', err);
    res.status(500).json({ message: 'Internal server error' });
  }
});

function msToDuration(ms) {
  const mins = Math.floor(ms / 60000);
  const hrs = Math.floor(mins / 60);
  const remainingMin = mins % 60;
  return `${hrs}h ${remainingMin}m`;
}

router.get('/vehicle-progress/expertStage', authMiddleware, async (req, res) => {
  try {
    const vehicles = await Vehicle.find({
      "expertStage.startTime": { $exists: true },
      isDeleted: false
    }).populate([
      { path: 'expertStage.performedBy', select: 'name' },
      { path: 'expertStage.endedBy', select: 'name' }
    ]);

    const now = new Date();
    const inProgress = [];
    const completed = [];

    for (const v of vehicles) {
      const stage = v.expertStage;
      if (!stage?.startTime) continue;

      const base = {
        vehicleNumber: v.vehicleNumber,
        stageName: 'Expert Stage',
        startedBy: stage?.performedBy?.name || 'N/A',
        startedAt: stage.startTime,
        startedAtFormatted: stage.startTime.toISOString()
      };

      if (!stage.endTime) {
        const elapsedMs = now - new Date(stage.startTime);
        inProgress.push({
          ...base,
          status: 'In Progress',
          totalTime: msToDuration(elapsedMs)
        });
      } else {
        const durationMs = new Date(stage.endTime) - new Date(stage.startTime);
        completed.push({
          ...base,
          status: 'Completed',
          endedBy: stage?.endedBy?.name || 'System',
          endedAt: stage.endTime,
          endedAtFormatted: stage.endTime.toISOString(),
          totalTime: msToDuration(durationMs)
        });
      }
    }

    res.json({ inProgress, completed });
  } catch (err) {
    console.error('Error in expertStage progress route:', err);
    res.status(500).json({ message: 'Internal server error' });
  }
});

function msToDuration(ms) {
  const mins = Math.floor(ms / 60000);
  const hrs = Math.floor(mins / 60);
  const remainingMin = mins % 60;
  return `${hrs}h ${remainingMin}m`;
}

router.get('/washing-history', authMiddleware, async (req, res) => {
  try {
    const { vehicleNumber, fromDate, toDate } = req.query;

    const dateFilter = {};
    if (fromDate) dateFilter.$gte = new Date(fromDate);
    if (toDate) dateFilter.$lte = new Date(toDate);

    const query = {
      'washing.startTime': { $exists: true },
    };
    if (vehicleNumber) {
      query.vehicleNumber = { $regex: vehicleNumber, $options: 'i' };
    }

    const vehicles = await Vehicle.find(query)
      .populate('washing.performedBy', 'name')
      .lean();

    const formatDate = (date) =>
      new Date(date).toLocaleString('en-IN', {
        timeZone: 'Asia/Kolkata',
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: 'numeric',
        minute: '2-digit',
        hour12: true,
      });

    const inProgress = [];
    const completed = [];

    for (const vehicle of vehicles) {
      const washes = Array.isArray(vehicle.washing) ? vehicle.washing : [];

      for (const wash of washes) {
        if (!wash.startTime) continue;

        // Apply date filter if provided
        if ((fromDate || toDate) && wash.startTime) {
          const washTime = new Date(wash.startTime);
          if ((fromDate && washTime < new Date(fromDate)) || (toDate && washTime > new Date(toDate))) {
            continue;
          }
        }

        const base = {
          vehicleNumber: vehicle.vehicleNumber,
          startTime: formatDate(wash.startTime),
          performedBy: wash.performedBy?.name || 'N/A',
        };

        if (wash.isCompleted && wash.endTime) {
          completed.push({
            ...base,
            endTime: formatDate(wash.endTime),
            durationMinutes: Math.round((new Date(wash.endTime) - new Date(wash.startTime)) / 60000),
          });
        } else {
          inProgress.push(base);
        }
      }
    }

    res.status(200).json({ inProgress, completed });

  } catch (error) {
    console.error('Error fetching washing history:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/vehicle/pickup-drop-summary', authMiddleware, async (req, res) => {
  try {
    const vehicles = await Vehicle.find({
      'pickupDrop.startTime': { $exists: true },
      'securityGate.startTime': { $exists: true },
      'securityGate.endTime': { $exists: true },
      'driverDrop.endTime': { $exists: true }
    }).lean();

    const msToDuration = (ms) => {
      const mins = Math.floor(ms / 60000);
      const hrs = Math.floor(mins / 60);
      const remainingMin = mins % 60;
      return `${hrs}h ${remainingMin}m`;
    };

    const results = vehicles.map(v => {
      const pickupStart = new Date(v.pickupDrop.startTime);
      const pickupEnd = new Date(v.securityGate.startTime);
      const dropStart = new Date(v.securityGate.endTime);
      const dropEnd = new Date(v.driverDrop.endTime);

      const pickupDurationMs = pickupEnd - pickupStart;
      const dropDurationMs = dropEnd - dropStart;

      return {
        vehicleNumber: v.vehicleNumber,
        pickupStart: pickupStart.toLocaleString(),
        arrivalAtWorkshop: pickupEnd.toLocaleString(),
        pickupDuration: msToDuration(pickupDurationMs),

        workshopExit: dropStart.toLocaleString(),
        dropComplete: dropEnd.toLocaleString(),
        dropDuration: msToDuration(dropDurationMs)
      };
    });

    res.status(200).json(results);
  } catch (err) {
    console.error('Error in pickup-drop summary:', err);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// ✅ Driver-only history check (no need for securityGate)
router.get('/vehicle/driver-history', authMiddleware, async (req, res) => {
  try {
    // Find vehicles with either pickup or drop records
    const vehicles = await Vehicle.find({
      $or: [
        { 'pickupDrop.startTime': { $exists: true } },
        { 'driverDrop.endTime': { $exists: true } }
      ]
    })
    .populate('pickupDrop.performedBy', 'name phone') // Populate driver info for pickup
    .populate('driverDrop.endedBy', 'name phone')     // Populate driver info for drop
    .lean();

    // Format the response data
    const result = vehicles.map(vehicle => {
      return {
        vehicleNumber: vehicle.vehicleNumber,
        
        // Pickup Information
        pickup: vehicle.pickupDrop ? {
          time: vehicle.pickupDrop.startTime 
            ? new Date(vehicle.pickupDrop.startTime).toLocaleString() 
            : null,
          km: vehicle.pickupDrop.pickupKM || null,
          driver: vehicle.pickupDrop.performedBy 
            ? { 
                name: vehicle.pickupDrop.performedBy.name,
                phone: vehicle.pickupDrop.performedBy.phone
              }
            : null
        } : null,
        
        // Drop Information
        drop: vehicle.driverDrop ? {
          time: vehicle.driverDrop.endTime 
            ? new Date(vehicle.driverDrop.endTime).toLocaleString() 
            : null,
          km: vehicle.driverDrop.dropKM || null,
          driver: vehicle.driverDrop.endedBy 
            ? { 
                name: vehicle.driverDrop.endedBy.name,
                phone: vehicle.driverDrop.endedBy.phone
              }
            : null,
          isCompleted: vehicle.driverDrop.isCompleted || false
        } : null,
        
        // Calculated fields
        totalKM: vehicle.pickupDrop?.pickupKM && vehicle.driverDrop?.dropKM
          ? vehicle.driverDrop.dropKM - vehicle.pickupDrop.pickupKM
          : null,
        
        // History reference
        historyId: vehicle._id
      };
    });

    res.status(200).json({
      success: true,
      count: result.length,
      data: result
    });

  } catch (err) {
    console.error('Error in driver-history route:', err);
    res.status(500).json({ 
      success: false,
      message: 'Internal server error',
      error: err.message 
    });
  }
});


router.get('/final-inspection-history', authMiddleware, async (req, res) => {
  try {
    const { vehicleNumber, fromDate, toDate, repairRequired } = req.query;

    const query = {
      'finalInspection.startTime': { $exists: true }
    };

    if (vehicleNumber) {
      query.vehicleNumber = { $regex: vehicleNumber, $options: 'i' };
    }

    if (fromDate || toDate) {
      query['finalInspection.startTime'] = {};
      if (fromDate) query['finalInspection.startTime'].$gte = new Date(fromDate);
      if (toDate) query['finalInspection.startTime'].$lte = new Date(toDate);
    }

    if (repairRequired !== undefined) {
      query['finalInspection.repairRequired'] = repairRequired === 'true';
    }

    const vehicles = await Vehicle.find(query)
      .populate('finalInspection.performedBy', 'name')
      // .populate('finalInspection.endedBy', 'name')  // Removed this line
      .lean();

    const formatDate = (date) => {
      if (!date) return 'N/A';
      return new Date(date).toLocaleString('en-IN', {
        timeZone: 'Asia/Kolkata',
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: 'numeric',
        minute: '2-digit',
        hour12: true,
      });
    };

    const calculateDuration = (start, end) => {
      if (!start || !end) return 'N/A';
      return Math.round((new Date(end) - new Date(start)) / 60000);
    };

    const inProgress = [];
    const completed = [];

    for (const vehicle of vehicles) {
      if (!vehicle.finalInspection) continue;

      const baseInfo = {
        vehicleNumber: vehicle.vehicleNumber,
        startTime: formatDate(vehicle.finalInspection.startTime),
        performedBy: vehicle.finalInspection.performedBy?.name || 'N/A',
        repairRequired: vehicle.finalInspection.repairRequired ? 'Yes' : 'No',
        remarks: vehicle.finalInspection.remarks || 'N/A'
      };

      if (vehicle.finalInspection.isCompleted && vehicle.finalInspection.endTime) {
        completed.push({
          ...baseInfo,
          endTime: formatDate(vehicle.finalInspection.endTime),
          // endedBy: vehicle.finalInspection.endedBy?.name || 'N/A',  // remove or comment out
          durationMinutes: calculateDuration(
            vehicle.finalInspection.startTime,
            vehicle.finalInspection.endTime
          )
        });
      } else {
        inProgress.push(baseInfo);
      }
    }

    res.status(200).json({
      inProgress,
      completed,
      stats: {
        totalInspections: completed.length + inProgress.length,
        completed: completed.length,
        inProgress: inProgress.length,
        repairsRequired: completed.filter(i => i.repairRequired === 'Yes').length
      }
    });

  } catch (error) {
    console.error('Error fetching final inspection history:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});


router.get('/vehicle/:vehicleNumber/parts-estimation-history', async (req, res) => {
  try {
    const { vehicleNumber } = req.params;

    const vehicle = await Vehicle.findOne({ vehicleNumber })
      .populate('partsEstimation.performedBy', 'name role')
      .populate('history.performedBy', 'name role');

    if (!vehicle) {
      return res.status(404).json({ message: 'Vehicle not found' });
    }

    const partsEstimationHistory = vehicle.history.filter(h => h.stage === 'partsEstimation');

    res.json({
      vehicleNumber: vehicle.vehicleNumber,
      currentStatus: vehicle.partsEstimation || null,
      history: partsEstimationHistory
    });

  } catch (error) {
    console.error('Error fetching parts estimation history:', error);
    res.status(500).json({ message: 'Server error' });
  }
});


router.get('/vehicle/:vehicleNumber/parts-order-history', async (req, res) => {
  try {
    const { vehicleNumber } = req.params;

    const vehicle = await Vehicle.findOne({ vehicleNumber })
      .populate('partsOrder.performedBy', 'name role');

    if (!vehicle) {
      return res.status(404).json({ message: 'Vehicle not found' });
    }

    const partsOrderData = vehicle.partsOrder;

    res.json({
      vehicleNumber: vehicle.vehicleNumber,
      currentStatus: partsOrderData || null,
      history: partsOrderData ? [partsOrderData] : []
    });

  } catch (error) {
    console.error('Error fetching parts order history:', error);
    res.status(500).json({ message: 'Server error' });
  }
});



router.get('/dashboard/status', async (req, res) => {
  try {
    const vehicles = await Vehicle.find().sort({ updatedAt: -1 });

    const statusMap = vehicles.map(vehicle => {
      return {
        vehicleNumber: vehicle.vehicleNumber,
        status: determineVehicleStatus(vehicle),
        lastUpdated: vehicle.updatedAt,
        currentStage: getCurrentActiveStage(vehicle),
        timeline: generateTimeline(vehicle) // Optional: for displaying stage timeline
      };
    });

    res.status(200).json({ success: true, vehicles: statusMap });
  } catch (error) {
    console.error('Error in dashboard status:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Add this route to your existing routes file
// GET /api/vehicle/driver-performance
router.get('/driver-performance', authMiddleware, async (req, res) => {
  try {
    const vehicles = await Vehicle.find().populate('pickupDrop.performedBy').populate('driverDrop.endedBy');

    const driverStats = {};

    vehicles.forEach(vehicle => {
      const pickup = vehicle.pickupDrop;
      const security = vehicle.securityGate;
      const drop = vehicle.driverDrop;

      if (!pickup || !security || !drop) return;

      const driverId = pickup.performedBy?._id?.toString();
      const driverName = pickup.performedBy?.name || 'Unknown Driver';

      if (!driverStats[driverId]) {
        driverStats[driverId] = {
          driverId,
          driverName,
          totalPickups: 0,
          trips: []
        };
      }

      // Compute distances
      const pickupKM = pickup.pickupKM || 0;
      const securityInKM = security.inKM || 0;
      const securityOutKM = security.outKM || 0;
      const dropKM = drop.dropKM || 0;

      const pickupDistance = securityInKM - pickupKM;
      const dropDistance = dropKM - securityOutKM;

      driverStats[driverId].totalPickups += 1;
      driverStats[driverId].trips.push({
        vehicleNumber: vehicle.vehicleNumber,
        pickupTime: pickup.startTime,
        securityGateEntryTime: security.startTime,
        pickupKM,
        securityInKM,
        dropKM,
        securityOutKM,
        pickupDistance,
        dropDistance,
      });
    });

    const result = Object.values(driverStats);
    res.json({ success: true, data: result });
  } catch (error) {
    console.error('Error in driver-performance:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});


// Enhanced status determination logic
function determineVehicleStatus(vehicle) {
  // 11. Check if washing ended but security not ended
  if (hasWashingEnded(vehicle) && 
      vehicle.securityGate?.startTime && 
      !vehicle.securityGate?.endTime) {
    return "Waiting for dispatch";
  }

  // 12. Security ended but no driver drop
  if (vehicle.securityGate?.endTime && 
      (!vehicle.driverDrop || !vehicle.driverDrop.endTime)) {
    return "Car has been sent to customer";
  }

  // 13. Driver drop completed
  if (vehicle.driverDrop?.endTime) {
    return "Delivered to customer";
  }

  // Original status checks (1-10)
  // 1. Driver pickup check
  if (vehicle.pickupDrop?.startTime && !vehicle.securityGate?.startTime) {
    return "Vehicle about to arrive (driver picked up)";
  }

  // 2. Security gate to job card creation
  if (vehicle.securityGate?.startTime && !vehicle.jobCardCreation?.startTime) {
    return "Waiting for customer approval";
  }

  // 3. Job card created but no bay allocation
  if (vehicle.jobCardCreation?.startTime && 
      (!vehicle.bayAllocation || vehicle.bayAllocation.length === 0)) {
    return "Waiting for allocation";
  }

  // 4. Bay allocated but work not started
  if ((vehicle.bayAllocation?.length > 0) && 
      !vehicle.bayWork?.startTime) {
    return "Waiting for work to start";
  }

  // 5. Bay work in progress
  if (vehicle.bayWork?.startTime && !vehicle.bayWork?.endTime) {
    return "Work in progress";
  }

  // 6. Expert stage
  if (vehicle.expertStage?.startTime && !vehicle.expertStage?.endTime) {
    return "Under expert inspection";
  }

  // 7. Final inspection
  if (vehicle.finalInspection?.startTime && !vehicle.finalInspection?.endTime) {
    return "Final inspection";
  }

  // 8. Washing in progress
  if (isWashingInProgress(vehicle)) {
    return "In washing";
  }

  // 9. Ready for washing but not started
  if (vehicle.readyForWashing?.startTime && 
      !isWashingInProgress(vehicle)) {
    return "Waiting for washing";
  }

  // 10. Job card received
  if (vehicle.jobCardReceived?.startTime) {
    return "Completion of work (waiting for FI)";
  }

  return "Status unknown - check vehicle details";
}

// Helper functions
function hasWashingEnded(vehicle) {
  if (!vehicle.washing || vehicle.washing.length === 0) return false;
  const lastWash = vehicle.washing[vehicle.washing.length - 1];
  return lastWash.endTime !== undefined;
}

function isWashingInProgress(vehicle) {
  if (!vehicle.washing || vehicle.washing.length === 0) return false;
  const lastWash = vehicle.washing[vehicle.washing.length - 1];
  return lastWash.startTime && !lastWash.endTime;
}

function getCurrentActiveStage(vehicle) {
  const stages = [
    'driverDrop', 'securityGate', 'pickupDrop', 'jobCardCreation',
    'bayAllocation', 'bayWork', 'expertStage', 'finalInspection',
    'washing', 'readyForWashing', 'jobCardReceived'
  ];

  for (const stage of stages) {
    if (stage === 'bayAllocation' && vehicle.bayAllocation?.length > 0) {
      return stage;
    }
    if (stage === 'washing' && isWashingInProgress(vehicle)) {
      return stage;
    }
    if (vehicle[stage]?.startTime && !vehicle[stage]?.endTime) {
      return stage;
    }
  }
  return 'unknown';
}

// Optional: Generate a timeline of completed stages
function generateTimeline(vehicle) {
  const timeline = [];
  const stages = [
    'pickupDrop', 'securityGate', 'jobCardCreation', 'bayAllocation',
    'bayWork', 'expertStage', 'finalInspection', 'washing',
    'jobCardReceived', 'driverDrop'
  ];

  stages.forEach(stage => {
    if (stage === 'bayAllocation' && vehicle.bayAllocation?.length > 0) {
      timeline.push({
        stage,
        startTime: vehicle.bayAllocation[0].startTime,
        status: 'completed'
      });
    } else if (vehicle[stage]?.startTime) {
      timeline.push({
        stage,
        startTime: vehicle[stage].startTime,
        endTime: vehicle[stage].endTime || null,
        status: vehicle[stage].endTime ? 'completed' : 'in-progress'
      });
    }
  });

  return timeline.sort((a, b) => new Date(a.startTime) - new Date(b.startTime));
}


router.get('/job-card-listings', authMiddleware, async (req, res) => {
  try {
    const { date } = req.query; // Optional query param for filtering by date
    let startOfDay, endOfDay;

    if (date) {
      const selectedDate = new Date(date);
      startOfDay = new Date(selectedDate.setHours(0, 0, 0, 0));
      endOfDay = new Date(selectedDate.setHours(23, 59, 59, 999));
    }

    const filter = {
      'jobCardCreation.startTime': { $exists: true }
    };

    if (date) {
      filter['jobCardCreation.startTime'] = { $gte: startOfDay, $lte: endOfDay };
    }

    const vehicles = await Vehicle.find(filter)
      .populate('jobCardCreation.performedBy', 'name role')
      .select('vehicleNumber jobCardCreation');

    const results = vehicles.map(v => {
      const jc = v.jobCardCreation;
      return {
        vehicleNumber: v.vehicleNumber,
        concern: jc.concern || '',
        addedBy: jc.performedBy?.name || 'Unknown',
        role: jc.performedBy?.role || 'Unknown',
        addedAtIST: new Date(jc.addedAt || jc.startTime).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }),
        status: jc.isCompleted ? 'Completed' : 'Waiting for Customer Approval'
      };
    });

    res.status(200).json(results);
  } catch (err) {
    console.error('Error fetching job card listings:', err);
    res.status(500).json({ message: 'Internal server error' });
  }
});


// GET /api/work-in-progress
router.get('/work-in-progress', async (req, res) => {
  try {
    const search = req.query.search || '';

    const query = {
      'bayWork.isCompleted': false,
      vehicleNumber: { $regex: search, $options: 'i' }
    };

    const vehicles = await Vehicle.find(query)
      .sort({ 'bayWork.startTime': -1 }) // Newest first
      .select('vehicleNumber bayWork')   // Only needed fields
      .populate('bayWork.performedBy', 'name') // Optional: show technician name

    const formatted = vehicles.map(v => {
      const bw = v.bayWork || {};
      const istStart = bw.startTime ? new Date(bw.startTime).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }) : '-';

      return {
        vehicleNumber: v.vehicleNumber,
        bayNumber: bw.bayNumber || '-',
        workType: bw.workType || '-',
        startTimeIST: istStart,
        status: (bw.additionalWorkLogs && bw.additionalWorkLogs.length > 0) ? 'Additional work needed' : 'In Progress',
        additionalWorkLogs: bw.additionalWorkLogs || []
      };
    });

    res.json(formatted);
  } catch (err) {
    console.error('Error fetching work-in-progress:', err);
    res.status(500).json({ message: 'Server error' });
  }
});


// GET /washing-summary
router.get('/washing-summary', async (req, res) => {
  try {
    const vehicles = await Vehicle.find({ 'readyForWashing.startTime': { $exists: true } })
      .populate('readyForWashing.performedBy', 'name role');

    const summary = vehicles.map(vehicle => ({
      vehicleNumber: vehicle.vehicleNumber,
      dateTime: vehicle.readyForWashing.startTime,
      serviceAdvisor: vehicle.readyForWashing.performedBy?.name || 'N/A',
      washingType: vehicle.readyForWashing.washingType || 'N/A',
    }));

    res.json(summary);
  } catch (err) {
    console.error('Error fetching washing summary:', err);
    res.status(500).json({ message: 'Internal server error' });
  }
});


router.get('/jobcard-concerns/:vehicleNumber', async (req, res) => {
  const { vehicleNumber } = req.params;

  try {
    const vehicle = await Vehicle.findOne({ vehicleNumber });

    if (!vehicle) {
      return res.status(404).json({ message: 'Vehicle not found.' });
    }

    // Use vehicle.history instead of vehicle.events
    if (!Array.isArray(vehicle.history) || vehicle.history.length === 0) {
      return res.status(404).json({ message: 'No history found for this vehicle.' });
    }

    const jobCardStartEvent = vehicle.history.find(
      (event) =>
        event.stage === 'jobCardCreation' &&
        event.eventType === 'Start' &&
        event.additionalData?.commentText
    );

    if (!jobCardStartEvent) {
      return res.status(404).json({ message: 'No concern found for this vehicle.' });
    }

    const advisor = await User.findById(jobCardStartEvent.performedBy).select('name');

    res.json({
      vehicleNumber: vehicle.vehicleNumber,
      concern: jobCardStartEvent.additionalData.commentText,
      serviceAdvisor: advisor?.name || 'Unknown',
      addedAt: jobCardStartEvent.timestamp,
    });

  } catch (error) {
    console.error('Error fetching concern:', error);
    res.status(500).json({ message: 'Server error while retrieving concern.' });
  }
});


/**
 * @route GET /api/history/bay-allocations
 * @description Get all bay allocation records across all vehicles
 * @returns {Array} All bay allocation records with complete details
 */
router.get('/history/bay-allocations', async (req, res) => {
  try {
    const vehicles = await Vehicle.find({})
      .populate('bayAllocation.performedBy', 'name email')
      .populate('bayAllocation.technicians', 'name role')
      .select('vehicleNumber bayAllocation');

    const allAllocations = vehicles.flatMap(vehicle => 
      vehicle.bayAllocation.map(allocation => ({
        vehicleNumber: vehicle.vehicleNumber,
        startTime: allocation.startTime,
        performedBy: allocation.performedBy,
        vehicleModel: allocation.vehicleModel,
        serviceType: allocation.serviceType,
        jobDescription: allocation.jobDescription,
        itemDescription: allocation.itemDescription,
        frtHours: allocation.frtHours,
        technicians: allocation.technicians,
        isFirstAllocation: allocation.isFirstAllocation
      }))
    );

    res.json(allAllocations);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching bay allocations', error: error.message });
  }
});



/**
 * @route GET /api/history/expert-assignments
 * @description Get all expert assignment records across all vehicles
 * @returns {Array} All expert assignment records with complete details
 */
router.get('/history/expert-assignments', async (req, res) => {
  try {
    const vehicles = await Vehicle.find({ 'assignExpert': { $exists: true } })
      .populate('assignExpert.performedBy', 'name email')
      .select('vehicleNumber assignExpert');

    const expertAssignments = vehicles.map(vehicle => ({
      vehicleNumber: vehicle.vehicleNumber,
      startTime: vehicle.assignExpert.startTime,
      performedBy: vehicle.assignExpert.performedBy,
      expertName: vehicle.assignExpert.expertName,
      isCompleted: vehicle.assignExpert.isCompleted,
      endTime: vehicle.assignExpert.endTime || null
    }));

    res.json(expertAssignments);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching expert assignments', error: error.message });
  }
});

/**
 * @route GET /api/history/job-card-receipts
 * @description Get all job card receipt records across all vehicles
 * @returns {Array} All job card receipt records with complete details
 */
router.get('/history/job-card-receipts', async (req, res) => {
  try {
    const vehicles = await Vehicle.find({ 'jobCardReceived': { $exists: true } })
      .populate('jobCardReceived.performedBy', 'name email')
      .select('vehicleNumber jobCardReceived');

    const jobCardReceipts = vehicles.map(vehicle => ({
      vehicleNumber: vehicle.vehicleNumber,
      startTime: vehicle.jobCardReceived.startTime,
      performedBy: vehicle.jobCardReceived.performedBy,
      isCompleted: vehicle.jobCardReceived.isCompleted,
      endTime: vehicle.jobCardReceived.endTime || null
    }));

    res.json(jobCardReceipts);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching job card receipts', error: error.message });
  }
});


/**
 * @route GET /api/history/all
 * @description Get complete history across all stages and vehicles
 * @returns {Object} Complete history organized by stage
 */
router.get('/history/all', async (req, res) => {
  try {
    const vehicles = await Vehicle.find({})
      .populate('bayAllocation.performedBy', 'name email')
      .populate('bayAllocation.technicians', 'name role')
      .populate('assignExpert.performedBy', 'name email')
      .populate('jobCardReceived.performedBy', 'name email');

    const response = {
      bayAllocations: vehicles.flatMap(vehicle => 
        vehicle.bayAllocation.map(allocation => ({
          vehicleNumber: vehicle.vehicleNumber,
          startTime: allocation.startTime,
          performedBy: allocation.performedBy,
          vehicleModel: allocation.vehicleModel,
          serviceType: allocation.serviceType,
          jobDescription: allocation.jobDescription,
          itemDescription: allocation.itemDescription,
          frtHours: allocation.frtHours,
          technicians: allocation.technicians,
          isFirstAllocation: allocation.isFirstAllocation
        }))
      ),
      expertAssignments: vehicles
        .filter(v => v.assignExpert)
        .map(vehicle => ({
          vehicleNumber: vehicle.vehicleNumber,
          startTime: vehicle.assignExpert.startTime,
          performedBy: vehicle.assignExpert.performedBy,
          expertName: vehicle.assignExpert.expertName,
          isCompleted: vehicle.assignExpert.isCompleted,
          endTime: vehicle.assignExpert.endTime || null
        })),
      jobCardReceipts: vehicles
        .filter(v => v.jobCardReceived)
        .map(vehicle => ({
          vehicleNumber: vehicle.vehicleNumber,
          startTime: vehicle.jobCardReceived.startTime,
          performedBy: vehicle.jobCardReceived.performedBy,
          isCompleted: vehicle.jobCardReceived.isCompleted,
          endTime: vehicle.jobCardReceived.endTime || null
        }))
    };

    res.json(response);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching complete history', error: error.message });
  }
});



module.exports = router;