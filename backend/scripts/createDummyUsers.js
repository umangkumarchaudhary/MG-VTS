// scripts/createDummyUsers.js

require('dotenv').config();
const connectDB = require('../config/db'); // Adjust path as needed
const { User } = require('../user/userAuth'); // Adjust path as needed

const roles = [
  'Technician',
    'Service Advisor',
    'Quality Inspector',
    'Job Controller',
    'Washing',
    'Security Guard',
    'Driver',
    'Parts Team'
];

async function createUsers() {
  await connectDB(); // Uses your MONGO_URI from .env

  for (let role of roles) {
    for (let i = 1; i <= 5; i++) {
      // Make phone numbers unique for each user
      await User.create({
        name: `${role} ${i}`,
        phone: `9000${role[0]}${i}${Math.floor(1000 + Math.random()*9000)}`,
        role,
        password: 'Password@123'
      });
    }
  }
  console.log('Dummy users created!');
  process.exit();
}

createUsers();
