const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const router = express.Router();

// ===== Allowed Roles =====
const allowedRoles = [
    'Admin',
    'Technician',
    'Service Advisor',
    'Quality Inspector',
    'Job Controller',
    'Washing',
    'Security Guard',
    'Driver',
    'Parts Team'
];

// ===== User Schema =====
const userSchema = new mongoose.Schema({
    name: { type: String, required: true },
    phone: { type: String, required: true, unique: true },
    email: { type: String, default: null },
    role: { type: String, enum: allowedRoles, required: true },
    team: { type: String, enum: ['A', 'B'], default: 'Default' },
    password: { type: String, required: true },
}, {
    timestamps: true
});

const User = mongoose.model('User', userSchema);

// ===== JWT Middleware =====
const authMiddleware = async (req, res, next) => {
    try {
      const authHeader = req.headers.authorization;
      console.log("🔐 Incoming Auth Header:", authHeader);
  
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ message: 'Authorization header missing or malformed' });
      }
  
      const token = authHeader.split(' ')[1];
  
      // Decode the token
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      console.log("✅ JWT Decoded:", decoded);
  
      const user = await User.findById(decoded.userId);
      if (!user) {
        return res.status(401).json({ message: 'User not found' });
      }
  
      req.user = user;
      next();
    } catch (error) {
      console.error("❌ Token verification failed:", error.message);
      return res.status(401).json({ message: 'Token is not valid' });
    }
  };
  

// ===== JWT Token Generator =====
const generateToken = (user) => {
    return jwt.sign(
        { userId: user._id, role: user.role },
        process.env.JWT_SECRET,
        { expiresIn: '7d' }
    );
};

// ===== Register Route =====
router.post('/register', async (req, res) => {
    const { name, phone, email, role, team, password } = req.body;

    if (!name || !phone || !role || !password) {
        return res.status(400).json({ message: 'Please fill all required fields' });
    }

    if (!allowedRoles.includes(role)) {
        return res.status(400).json({ message: 'Invalid role selected' });
    }

    const existingUser = await User.findOne({ phone });
    if (existingUser) {
        return res.status(409).json({ message: 'User already exists with this phone number' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const newUser = new User({
        name,
        phone,
        email,
        role,
        team: team || 'Default',
        password: hashedPassword
    });

    await newUser.save();

    res.status(201).json({
        message: 'User registered successfully',
        token: generateToken(newUser),
        user: {
            id: newUser._id,
            name: newUser.name,
            phone: newUser.phone,
            role: newUser.role,
            team: newUser.team
        }
    });
});

// ===== Login Route =====
router.post('/login', async (req, res) => {
    const { phone, password } = req.body;

    const user = await User.findOne({ phone });
    if (!user) {
        return res.status(401).json({ message: 'Invalid phone number or password' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
        return res.status(401).json({ message: 'Invalid phone number or password' });
    }

    res.json({
        message: 'Login successful',
        token: generateToken(user),
        user: {
            id: user._id,
            name: user.name,
            phone: user.phone,
            role: user.role,
            team: user.team
        }
    });
});

// ===== Protected Route Example =====
router.get('/me', authMiddleware, async (req, res) => {
    const user = await User.findById(req.user.userId).select('-password');
    res.json(user);
});

// ===== Final Exports =====
module.exports = {
    authMiddleware,
    User,
    userRoutes: router
};
