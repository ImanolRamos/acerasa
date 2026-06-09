const express = require("express");
const measurementsController = require("../controllers/measurements.controller");

const router = express.Router();

router.get("/variables", measurementsController.getVariables);
router.get("/latest", measurementsController.getLatestMeasurements);
router.get("/count", measurementsController.getMeasurementCount);

router.get("/history", measurementsController.getMeasurementHistory);
router.get("/history/average", measurementsController.getAverageHistory);

module.exports = router;