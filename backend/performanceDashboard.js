const express = require('express');
const router = express.Router();
const Vehicle = require('./models/vehicleModel');
const { authMiddleware } = require('./user/userAuth');
const { User } = require('./user/userAuth');


const moment = require('moment-timezone');

router.get('/driverPerformance', authMiddleware, async (req, res) => {
  try {
    const { date } = req.query;

    let query = {
      'pickupDrop.startTime': { $exists: true },
      'pickupDrop.performedBy': { $exists: true }
    };

    if (date) {
      const startOfDay = new Date(date + 'T00:00:00.000+05:30');
      const endOfDay = new Date(date + 'T23:59:59.999+05:30');
      query['pickupDrop.startTime'] = { $gte: startOfDay, $lte: endOfDay };
    }

    const vehicles = await Vehicle.find(query).populate('pickupDrop.performedBy', 'name role');

    const formatted = vehicles.map(v => {
      return {
        vehicleNumber: v.vehicleNumber,
        driverName: v.pickupDrop?.performedBy?.name || 'N/A',
        role: v.pickupDrop?.performedBy?.role || 'N/A',
        pickupKM: v.pickupDrop?.pickupKM || 'N/A',
        startTime: moment(v.pickupDrop.startTime).tz('Asia/Kolkata').format('DD-MM-YYYY hh:mm A'),
      };
    });

    res.json({ count: formatted.length, data: formatted });
  } catch (error) {
    console.error('Error in driverPerformance:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});







module.exports = router;