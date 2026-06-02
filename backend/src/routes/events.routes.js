const express = require("express");
const eventsController = require("../controllers/events.controller");

const router = express.Router();

router.post("/", eventsController.createEvent);

module.exports = router;