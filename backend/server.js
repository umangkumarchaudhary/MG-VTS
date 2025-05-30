const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const cookieParser = require("cookie-parser");
require("dotenv").config();

const { userRoutes } = require("./user/userAuth");
const vehicleRoute = require("./VehicleRoute");
const fetchHistory = require("./fetchHistory");
const dashboardRoutes = require("./dashboard/dashboardRoute");

const app = express();

app.use(express.json({ limit: "10mb" }));
app.use(cookieParser());

// ✅ CORS setup to allow React web, Flutter web (optional), and Flutter mobile apps
const allowedOrigins = [
  "http://localhost:3000",    // React Web Dev
  "http://127.0.0.1:3000",    
  "http://localhost:8081",    // Flutter Web Dev (if used)
  "http://127.0.0.1:8081",
  "http://localhost:19006",   // Expo Web (optional)
  "capacitor://localhost",    // Flutter mobile (PWA-style or hybrid)
  "ionic://localhost",        // Optional
  "http://your-production-domain.com",  // Replace with your actual deployed frontend
  "https://mg-vts-ukc.netlify.app",     // ✅ Your deployed React app
];

app.use(
  cors({
    origin: function (origin, callback) {
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error("CORS not allowed from this origin: " + origin));
      }
    },
    credentials: true,
  })
);

// ✅ MongoDB connection
mongoose
  .connect(process.env.MONGO_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  })
  .then(() => console.log("✅ MongoDB Connected"))
  .catch((err) => console.error("❌ MongoDB Connection Failed:", err));

// Auto reconnect if disconnected
mongoose.connection.on("disconnected", () => {
  console.log("❌ MongoDB disconnected! Reconnecting...");
  mongoose.connect(process.env.MONGO_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  });
});

// ✅ Routes
app.use("/api", userRoutes);
app.use("/api", vehicleRoute);
app.use("/api", fetchHistory);
app.use("/api", dashboardRoutes);

// ✅ Health Check
app.get("/health", (req, res) => {
  res.status(200).json({ status: "Server is healthy" });
});

// ✅ Start Server
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
