const realtimeRepository = require('../repositories/realtime.repository')
const realtimeMqttService = require('../services/realtimeMqtt.service')

function sendSse(res, event, data) {
  res.write(`event: ${event}\n`)
  res.write(`data: ${JSON.stringify(data)}\n\n`)
}

async function streamRealTimeMeasurements(req, res) {
  const variablesParam = String(req.query.variables || '')

  const variableNames = variablesParam
    .split(',')
    .map((variable) => variable.trim())
    .filter(Boolean)

  if (variableNames.length === 0) {
    return res.status(400).json({
      ok: false,
      error: 'Debes indicar al menos una variable',
    })
  }

  try {
    const variables = await realtimeRepository.findActiveVariablesByNames(variableNames)

    if (variables.length === 0) {
      return res.status(404).json({
        ok: false,
        error: 'No se han encontrado variables activas',
      })
    }

    res.setHeader('Content-Type', 'text/event-stream')
    res.setHeader('Cache-Control', 'no-cache')
    res.setHeader('Connection', 'keep-alive')
    res.flushHeaders?.()

    sendSse(res, 'connected', {
      ok: true,
      variables,
    })

    const mqttClient = realtimeMqttService.getMqttClient()

    const topics = [
      ...new Set(
        variables
          .map((variable) =>
            realtimeMqttService.getTopicFromOriginalName(variable.original_name),
          )
          .filter(Boolean),
      ),
    ]

    mqttClient.subscribe(topics, { qos: 1 })

    const onMessage = (topic, payload) => {
      const measurements = realtimeMqttService.extractMeasurementsFromPayload(
        topic,
        payload,
        variables,
      )

      for (const measurement of measurements) {
        sendSse(res, 'measurement', measurement)
      }
    }

    mqttClient.on('message', onMessage)

    req.on('close', () => {
        mqttClient.off('message', onMessage)

        if (topics.length > 0) {
            mqttClient.unsubscribe(topics, (error) => {
            if (error) {
                console.error('[Realtime MQTT] Error desuscribiendo:', error.message)
            }
            })
        }

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