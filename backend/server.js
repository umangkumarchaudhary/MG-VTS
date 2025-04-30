const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const cookieParser = require("cookie-parser");
require("dotenv").config();
const { userRoutes } = require("./user/userAuth");
const vehicleRoute = require("./VehicleRoute");
const fetchHistory = require("./fetchHistory");


const app = express();

app.use(express.json({limit : "10mb"}));
app.use(cookieParser());

app.use(cors({origin: "*", credentials:true}));

mongoose
  .connect(process.env.MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => console.log("✅ MongoDB Connected"))
  .catch((err) => console.error("❌ MongoDB Connection Failed:", err));

mongoose.connection.on("disconnected", () => {
  console.log("❌ MongoDB disconnected! Reconnecting...");
  mongoose.connect(process.env.MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true });
});


app.use("/api", userRoutes);
app.use("/api", vehicleRoute);
app.use("/api", fetchHistory);

app.get("/health", (req, res) => {
    res.status(200).json({ status: "Server is healthy" });
  });
  
  // ✅ Start Server
  const PORT = process.env.PORT || 5000;
  app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));