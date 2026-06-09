const realtimeMqttService = require('../services/realtimeMqtt.service')

function sendSse(res, event, data) {
  res.write(`event: ${event}\n`)
  res.write(`data: ${JSON.stringify(data)}\n\n`)
}

async function streamRealTimeMeasurements(req, res) {
  try {
    res.setHeader('Content-Type', 'text/event-stream')
    res.setHeader('Cache-Control', 'no-cache')
    res.setHeader('Connection', 'keep-alive')
    res.flushHeaders?.()

    sendSse(res, 'connected', {
      ok: true,
    })

    const mqttClient = realtimeMqttService.getMqttClient()

    mqttClient.subscribe(
        realtimeMqttService.REALTIME_TOPICS,
        { qos: 1 },
        (error) => {
            if (error) {
            console.error('[Realtime MQTT] Error suscribiendo:', error.message)
            } else {
            console.log('[Realtime MQTT] Suscrito a topics realtime')
            }
        },
    )

    const onMessage = (topic, payload) => {
      const measurement =
        realtimeMqttService.extractTopicMeasurements(
          topic,
          payload,
        )

      if (!measurement) {
        return
      }

      sendSse(
        res,
        'measurement',
        measurement,
      )
    }

    mqttClient.on('message', onMessage)

    req.on('close', () => {
      mqttClient.off('message', onMessage)

      mqttClient.unsubscribe(
        realtimeMqttService.REALTIME_TOPICS,
      )

      res.end()
    })
  } catch (error) {
    console.error(error)

    if (!res.headersSent) {
      return res.status(500).json({
        ok: false,
        error: error.message,
      })
    }

    sendSse(res, 'error', {
      ok: false,
      error: error.message,
    })

    res.end()
  }
}

module.exports = {
  streamRealTimeMeasurements,
}