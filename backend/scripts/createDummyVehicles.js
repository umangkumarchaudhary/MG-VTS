require('dotenv').config();
const connectDB = require('../config/db');
const Vehicle = require('../models/vehicleModel');
const { User } = require('../user/userAuth');

const allowedRoles = [
  'Technician',
  'Service Advisor',
  'Quality Inspector',
  'Job Controller',
  'Washing',
  'Security Guard',
  'Driver',
];

// Only MG models
const vehicleModels = [
  "MG Hector", "MG Astor", "MG Gloster", "MG ZS EV", "MG Comet"
];

// Work types
const workTypes = ["pm", "gr", "body", "paint"];

// Random date in May 2025 (between 1 and 20)
function randomMayDate() {
  const day = Math.floor(Math.random() * 20) + 1;
  // Random hour/minute for more realism
  const hour = Math.floor(Math.random() * 9) + 8; // 8am to 5pm
  const min = Math.floor(Math.random() * 60);
  return new Date(2025, 4, day, hour, min); // Month is 0-indexed, 4 = May
}

function randomPlate() {
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  return (
    letters[Math.floor(Math.random()*26)] +
    letters[Math.floor(Math.random()*26)] +
    String(Math.floor(10 + Math.random()*90)) +
    letters[Math.floor(Math.random()*26)] +
    letters[Math.floor(Math.random()*26)] +
    String(Math.floor(1000 + Math.random()*9000))
  );
}

function randomModel() {
  return vehicleModels[Math.floor(Math.random() * vehicleModels.length)];
}

function randomWorkType() {
  return workTypes[Math.floor(Math.random() * workTypes.length)];
}

async function getRandomUser(role) {
  const users = await User.find({ role });
  if (!users.length) throw new Error(`No users found for role: ${role}`);
  return users[Math.floor(Math.random() * users.length)];
}

function addMinutes(date, min) {
  return new Date(date.getTime() + min * 60000);
}

async function createDummyVehicles(count = 200) {
  await connectDB();

  for (let i = 0; i < count; i++) {
    const vehicleNumber = randomPlate();
    const model = randomModel();
    const workType = randomWorkType();
    let now = randomMayDate();

    // Fetch random users for each role
    const security = await getRandomUser('Security Guard');
    const tech = await getRandomUser('Technician');
    const advisor = await getRandomUser('Service Advisor');
    const driver = await getRandomUser('Driver');
    const washing = await getRandomUser('Washing');
    const inspector = await getRandomUser('Quality Inspector');
    const jobController = await getRandomUser('Job Controller');

    // 1. pickupDrop - Start
    now = addMinutes(now, 10);
    const pickupDrop = {
      startTime: now,
      performedBy: driver._id,
      pickupKM: 10000 + Math.floor(Math.random() * 5000)
    };

    // 2. securityGate - Start
    now = addMinutes(now, 10);
    const securityGate = {
      startTime: now,
      performedBy: security._id,
      inKM: pickupDrop.pickupKM,
      bringBy: 'Driver',
      customerName: 'John Doe'
    };

    // 3. jobCardCreation - Start
    now = addMinutes(now, 10);
    const jobCardCreation = {
      startTime: now,
      performedBy: advisor._id,
      isCompleted: false,
      concerns: [{ comment: "Engine noise", addedAt: now }]
    };

    // 4. bayAllocation - Start (First)
    now = addMinutes(now, 10);
    const bayAllocation = [{
      startTime: now,
      performedBy: jobController._id,
      vehicleModel: model,
      jobDescription: "General Service",
      serviceTypes: ["Oil Change", "Brake Check"],
      items: [
        { itemDescription: "Oil Filter", frtHours: 0.5 },
        { itemDescription: "Brake Pads", frtHours: 1.0 }
      ],
      technicians: [tech._id],
      isFirstAllocation: true,
      workType // <-- Added workType here
    }];

    // 5. assignExpert - Start/End (randomly required)
    let assignExpert, expertStage;
    if (Math.random() > 0.5) {
      now = addMinutes(now, 10);
      assignExpert = {
        startTime: now,
        performedBy: advisor._id,
        expertName: "Expert Joe",
        isCompleted: false
      };
      now = addMinutes(now, 10);
      expertStage = {
        startTime: now,
        endTime: addMinutes(now, 10),
        performedBy: inspector._id,
        endedBy: advisor._id,
        isCompleted: true
      };
    }

    // 6. roadTest - Start/End (randomly required)
    let roadTest;
    if (Math.random() > 0.3) {
      now = addMinutes(now, 10);
      roadTest = {
        startTime: now,
        endTime: addMinutes(now, 15),
        performedBy: driver._id,
        isCompleted: true
      };
    }

    // 7. bayWork - Start & End (First)
    now = addMinutes(now, 10);
    const bayWork = {
      startTime: now,
      endTime: addMinutes(now, 60),
      performedBy: tech._id,
      endedBy: tech._id,
      isCompleted: true,
      workType, // <-- Use random workType here
      bayNumber: "B1",
      additionalWorkLogs: []
    };

    // 8. jobCardReceived - Start (First)
    now = addMinutes(now, 10);
    const jobCardReceived = {
      startTime: now,
      performedBy: advisor._id
    };

    // 9. additionalWork - Start (randomly required)
    let additionalWork;
    if (Math.random() > 0.6) {
      now = addMinutes(now, 10);
      additionalWork = {
        startTime: now,
        performedBy: advisor._id,
        isCompleted: false
      };
    }

    // 10. bayAllocation - Start (Second, if additionalWork)
    if (additionalWork) {
      now = addMinutes(now, 10);
      bayAllocation.push({
        startTime: now,
        performedBy: jobController._id,
        vehicleModel: model,
        jobDescription: "Additional Work",
        serviceTypes: ["AC Check"],
        items: [
          { itemDescription: "AC Filter", frtHours: 0.5 }
        ],
        technicians: [tech._id],
        isFirstAllocation: false,
        workType // <-- Use same random workType
      });
    }

    // 11. bayWork - Start & End (Second, if additionalWork)
    let bayWork2;
    if (additionalWork) {
      now = addMinutes(now, 10);
      bayWork2 = {
        startTime: now,
        endTime: addMinutes(now, 45),
        performedBy: tech._id,
        endedBy: tech._id,
        isCompleted: true,
        workType, // <-- Use same random workType
        bayNumber: "B2",
        additionalWorkLogs: []
      };
    }

    // 12. jobCardReceived - Start (Second, if additionalWork)
    let jobCardReceived2;
    if (additionalWork) {
      now = addMinutes(now, 10);
      jobCardReceived2 = {
        startTime: now,
        performedBy: advisor._id
      };
    }

    // 13. finalInspection - Start & End
    now = addMinutes(now, 10);
    const finalInspection = {
      startTime: now,
      endTime: addMinutes(now, 15),
      performedBy: inspector._id,
      isCompleted: true,
      repairRequired: false,
      remarks: "All good"
    };

    // 14. readyForWashing - Start
    now = addMinutes(now, 10);
    const readyForWashing = {
      startTime: now,
      performedBy: washing._id,
      isCompleted: false,
      washingType: Math.random() > 0.5 ? "Free" : "Paid"
    };

    // 15. washing - Start & End
    now = addMinutes(now, 10);
    const washingArr = [{
      startTime: now,
      endTime: addMinutes(now, 20),
      performedBy: washing._id,
      isCompleted: true
    }];

    // 16. securityGate - End
    now = addMinutes(now, 10);
    securityGate.endTime = now;
    securityGate.performedBy = security._id;
    securityGate.outKM = pickupDrop.pickupKM + Math.floor(Math.random() * 100);
    securityGate.takeOutBy = 'Driver';
    securityGate.customerNameOut = 'John Doe';
    securityGate.isCompleted = true;

    // 17. driverDrop - End
    now = addMinutes(now, 10);
    const driverDrop = {
      endTime: now,
      endedBy: driver._id,
      isCompleted: true,
      dropKM: securityGate.outKM
    };

    // Build vehicle doc
    const vehicleDoc = {
      vehicleNumber,
      pickupDrop,
      securityGate,
      jobCardCreation,
      bayAllocation,
      assignExpert,
      expertStage,
      roadTest,
      bayWork,
      jobCardReceived,
      additionalWork,
      finalInspection,
      readyForWashing,
      washing: washingArr,
      driverDrop,
      // Optionally, add jobCardReceived2, bayWork2, etc. as needed
      history: [] // Optionally, fill with events
    };

    // Add optional second allocations if additionalWork exists
    if (bayWork2) vehicleDoc.bayWork2 = bayWork2;
    if (jobCardReceived2) vehicleDoc.jobCardReceived2 = jobCardReceived2;

    await Vehicle.create(vehicleDoc);
    console.log(`Vehicle ${i + 1}/200 (${vehicleNumber}, ${model}, ${workType}) created`);
  }

  console.log('All dummy vehicles created!');
  process.exit();
}

createDummyVehicles(200); // Generates 200 vehicles
