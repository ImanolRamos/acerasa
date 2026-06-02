const express = require("express");
const measurementsController = require("../controllers/measurements.controller");

const router = express.Router();

router.get("/variables", measurementsController.getVariables);
router.get("/latest", measurementsController.getLatestMeasurements);
router.get("/history", measurementsController.getMeasurementHistory);

module.exports = router;