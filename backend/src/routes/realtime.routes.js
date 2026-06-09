const express = require('express')
const realtimeController = require('../controllers/realtime.controller')

const router = express.Router()

router.get('/stream',realtimeController.streamRealTimeMeasurements)

module.exports = router