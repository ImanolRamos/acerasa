const express = require("express");
const cors = require("cors");

const healthRoutes = require("./routes/health.routes");
const infoRoutes = require("./routes/info.routes");
const measurementsRoutes = require("./routes/measurements.routes");
const eventsRoutes = require("./routes/events.routes");
const metricsRoutes = require("./routes/metrics.routes");
const loginRoutes = require("./routes/login.routes");
const realtimeRoutes = require("./routes/realtime.routes");

const app = express();

app.use(cors({
  origin: process.env.CORS_ORIGIN || "*",
}));

app.use(express.json({ limit: "50kb" }));

app.use("/api/health", healthRoutes); // Estado de los servicios
app.use("/api/info", infoRoutes); // Información general
app.use("/api/measurements", measurementsRoutes); // Datos
app.use("/api/events", eventsRoutes); // Eventos del front
app.use("/api/realtime", realtimeRoutes); // Medidas en tiempo real

app.use("/metrics", metricsRoutes); //Prometheus

app.use("/api/login", loginRoutes); //Login

module.exports = app;