// routes/securityGuardDashboard.js

const express = require('express');
const router = express.Router();
const Vehicle = require('../models/vehicleModel');

// Helper: Format date/time in Indian format
function formatIndianDate(date) {
  if (!date) return null;
  return new Date(date).toLocaleString('en-IN', {
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
    hour12: true,
    timeZone: 'Asia/Kolkata'
  });
}

// GET /api/security-dashboard
router.get('/api/security-dashboard', async (req, res) => {
  try {
    const {
      date,                // YYYY-MM-DD
      month,               // 1-12
      year,                // YYYY
      vehicleNumber,       // partial or full
      bringBy,
      takeOutBy,
      status,              // 'inside' or 'exited'
      limit,               // for pagination, optional
      skip                 // for pagination, optional
    } = req.query;

    // --- Date Calculations ---
    const now = new Date();
    const todayStr = now.toISOString().slice(0, 10);

    // Today
    const startOfDay = new Date(todayStr + "T00:00:00.000+05:30");
    const endOfDay = new Date(todayStr + "T23:59:59.999+05:30");

    // Month/year for stats (default: current month)
    const monthNum = month ? parseInt(month, 10) - 1 : now.getMonth();
    const yearNum = year ? parseInt(year, 10) : now.getFullYear();
    const startOfMonth = new Date(yearNum, monthNum, 1, 0, 0, 0);
    const endOfMonth = new Date(yearNum, monthNum + 1, 0, 23, 59, 59, 999);

    // --- Stats ---
    const [enteredToday, exitedToday, enteredThisMonth, exitedThisMonth, vehiclesInside] = await Promise.all([
      Vehicle.countDocuments({
        'securityGate.startTime': { $gte: startOfDay, $lte: endOfDay }
      }),
      Vehicle.countDocuments({
        'securityGate.endTime': { $gte: startOfDay, $lte: endOfDay }
      }),
      Vehicle.countDocuments({
        'securityGate.startTime': { $gte: startOfMonth, $lte: endOfMonth }
      }),
      Vehicle.countDocuments({
        'securityGate.endTime': { $gte: startOfMonth, $lte: endOfMonth }
      }),
      Vehicle.find({
        $and: [
          { 'securityGate.startTime': { $exists: true } },
          { $or: [{ 'securityGate.endTime': { $exists: false } }, { 'securityGate.endTime': null }] }
        ]
      }, {
        vehicleNumber: 1,
        securityGate: 1
      })
    ]);

    // --- Build List Filter ---
    const filter = { isDeleted: { $ne: true } };

    // Vehicle number (partial, case-insensitive)
    if (vehicleNumber) {
      filter.vehicleNumber = { $regex: vehicleNumber, $options: 'i' };
    }

    // BringBy, TakeOutBy
    if (bringBy) filter['securityGate.bringBy'] = bringBy;
    if (takeOutBy) filter['securityGate.takeOutBy'] = takeOutBy;

    // Date filter (for entry/exit on a specific date)
    if (date) {
      const start = new Date(date + "T00:00:00.000+05:30");
      const end = new Date(date + "T23:59:59.999+05:30");
      filter['securityGate.startTime'] = { $gte: start, $lte: end };
    }

    // Month/year filter (for entry in a specific month)
    if (month && year) {
      filter['securityGate.startTime'] = { $gte: startOfMonth, $lte: endOfMonth };
    }

    // Status toggle
    if (status === 'inside') {
      filter['securityGate.endTime'] = { $exists: false };
    } else if (status === 'exited') {
      filter['securityGate.endTime'] = { $exists: true };
    }

    // --- Pagination (optional) ---
    const listLimit = limit ? parseInt(limit, 10) : 100;
    const listSkip = skip ? parseInt(skip, 10) : 0;

    // --- Fetch Vehicle List ---
    const vehicles = await Vehicle.find(filter, {
      vehicleNumber: 1,
      securityGate: 1
    })
      .sort({ 'securityGate.startTime': -1 })
      .skip(listSkip)
      .limit(listLimit);

    // --- Prepare Table and Alerts ---
    const entryExitTable = [];
    const longStayAlerts = [];
    const odometerAlerts = [];
    const nowMs = Date.now();

    vehicles.forEach(v => {
      const sg = v.securityGate || {};
      const entryTime = sg.startTime ? formatIndianDate(sg.startTime) : null;
      const exitTime = sg.endTime ? formatIndianDate(sg.endTime) : null;
      const status = sg.endTime ? 'Exited' : 'Inside';

      // Alerts
      if (!sg.endTime && sg.startTime) {
        const hoursInside = (nowMs - new Date(sg.startTime).getTime()) / (1000 * 60 * 60);
        if (hoursInside > 48) {
          longStayAlerts.push({
            vehicleNumber: v.vehicleNumber,
            entryTime,
            hoursInside: Math.round(hoursInside)
          });
        }
      }
      if (sg.outKM && sg.inKM && sg.outKM < sg.inKM) {
        odometerAlerts.push({
          vehicleNumber: v.vehicleNumber,
          inKM: sg.inKM,
          outKM: sg.outKM
        });
      }

      entryExitTable.push({
        vehicleNumber: v.vehicleNumber,
        entryTime,
        exitTime,
        inKM: sg.inKM,
        outKM: sg.outKM,
        bringBy: sg.bringBy,
        takeOutBy: sg.takeOutBy,
        customerName: sg.customerName,
        customerNameOut: sg.customerNameOut,
        performedBy: sg.performedBy,
        status
      });
    });

    // --- Top Vehicles Inside (no exit) ---
    const topVehiclesInside = vehiclesInside
      .map(v => ({
        vehicleNumber: v.vehicleNumber,
        entryTime: v.securityGate && v.securityGate.startTime ? formatIndianDate(v.securityGate.startTime) : null,
        inKM: v.securityGate && v.securityGate.inKM,
        bringBy: v.securityGate && v.securityGate.bringBy,
        customerName: v.securityGate && v.securityGate.customerName
      }))
      .sort((a, b) => new Date(a.entryTime) - new Date(b.entryTime))
      .slice(0, 10); // Show top 10 by oldest entry

    res.json({
      stats: {
        enteredToday,
        exitedToday,
        enteredThisMonth,
        exitedThisMonth,
        insideCount: vehiclesInside.length
      },
      topVehiclesInside,
      entryExitTable,
      longStayAlerts,
      odometerAlerts
    });
  } catch (err) {
    console.error('Security dashboard error:', err);
    res.status(500).json({ error: 'Security dashboard error' });
  }
});

// GET /api/security-dashboard/vehicle/:vehicleNumber
router.get('/api/security-dashboard/vehicle/:vehicleNumber', async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    const vehicle = await Vehicle.findOne({ vehicleNumber: vehicleNumber.toUpperCase() });
    if (!vehicle || !vehicle.securityGate) return res.status(404).json({ error: 'Vehicle or SecurityGate data not found' });

    const sg = vehicle.securityGate;
    res.json({
      vehicleNumber: vehicle.vehicleNumber,
      entryTime: formatIndianDate(sg.startTime),
      exitTime: formatIndianDate(sg.endTime),
      inKM: sg.inKM,
      outKM: sg.outKM,
      bringBy: sg.bringBy,
      takeOutBy: sg.takeOutBy,
      customerName: sg.customerName,
      customerNameOut: sg.customerNameOut,
      performedBy: sg.performedBy,
      status: sg.endTime ? 'Exited' : 'Inside'
    });
  } catch (err) {
    console.error('Security dashboard detail error:', err);
    res.status(500).json({ error: 'Security dashboard detail error' });
  }
});

module.exports = router;
