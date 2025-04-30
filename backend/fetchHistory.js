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
        // Case-insensitive partial match
        query.vehicleNumber = { $regex: vehicleNumber, $options: 'i' };
      }
  
      if (fromDate || toDate) {
        query['securityGate.startTime'] = {};
        if (fromDate) {
          query['securityGate.startTime'].$gte = new Date(fromDate);
        }
        if (toDate) {
          query['securityGate.startTime'].$lte = new Date(toDate);
        }
      }
  
      // Fetch vehicles matching criteria
      const vehicles = await Vehicle.find(query).lean();
  
      // Separate IN and OUT vehicles
      const inVehicles = [];
      const outVehicles = [];
  
      vehicles.forEach(vehicle => {
        const sg = vehicle.securityGate;
        if (sg) {
          if (sg.isCompleted && sg.endTime && sg.outKM !== undefined) {
            // Vehicle has exited (OUT)
            outVehicles.push({
              vehicleNumber: vehicle.vehicleNumber,
              inKM: sg.inKM,
              outKM: sg.outKM,
              inTime: sg.startTime,
              outTime: sg.endTime
            });
          } else {
            // Vehicle is still IN
            inVehicles.push({
              vehicleNumber: vehicle.vehicleNumber,
              inKM: sg.inKM,
              inTime: sg.startTime
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


module.exports = router;