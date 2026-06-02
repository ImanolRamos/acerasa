const express = require("express");
const cors = require("cors");

const healthRoutes = require("./routes/health.routes");
const infoRoutes = require("./routes/info.routes");
const measurementsRoutes = require("./routes/measurements.routes");
const eventsRoutes = require("./routes/events.routes");
const metricsRoutes = require("./routes/metrics.routes");

const app = express();

app.use(cors({
  origin: process.env.CORS_ORIGIN || "*",
}));

app.use(express.json({ limit: "50kb" }));

app.use("/api/health", healthRoutes); // Estado de los servicios
app.use("/api/info", infoRoutes); // Información general
app.use("/api/measurements", measurementsRoutes); // Datos
app.use("/api/events", eventsRoutes); // Eventos del front

app.use("/metrics", metricsRoutes); //Prometheus

module.exports = app;