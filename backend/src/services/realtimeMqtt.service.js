const mqtt = require('mqtt')

let client = null

function getTopicFromOriginalName(originalName) {
  if (originalName.startsWith('V_LN/')) return 'acerasa/pac3220/voltage/ln'
  if (originalName.startsWith('V_LL/')) return 'acerasa/pac3220/voltage/ll'
  if (originalName.startsWith('I/')) return 'acerasa/pac3220/current'
  if (originalName.startsWith('Power/W/')) return 'acerasa/pac3220/power/active'
  if (originalName.startsWith('Power/var/')) return 'acerasa/pac3220/power/reactive'
  if (originalName.startsWith('Power/VA/')) return 'acerasa/pac3220/power/apparent'
  if (originalName.startsWith('Power/Factor/')) return 'acerasa/pac3220/power/factor'

  return null
}

function getMqttClient() {
  if (client) return client

  const mqttUrl = process.env.MQTT_URL || 'mqtt://mosquitto:1883'

  client = mqtt.connect(mqttUrl, {
    clientId:
      process.env.MQTT_REALTIME_CLIENT_ID ||
      `backend_realtime_${process.env.CLIENT_NAME || 'acerasa'}`,
    username: process.env.MQTT_USER,
    password: process.env.MQTT_PASSWORD,
    clean: true,
  })

  client.on('connect', () => {
    console.log('[Realtime MQTT] Conectado')
  })

  client.on('reconnect', () => {
    console.log('[Realtime MQTT] Reconectando...')
  })

  client.on('error', (error) => {
    console.error('[Realtime MQTT] Error:', error.message)
  })

  client.on('close', () => {
    console.log('[Realtime MQTT] Conexión cerrada')
  })

  return client
}

function extractMeasurementsFromPayload(topic, payload, variables) {
  let parsed

  try {
    parsed = JSON.parse(payload.toString())
  } catch (error) {
    console.error('[Realtime MQTT] Payload JSON inválido:', error.message)
    return []
  }

  const measurements = []

  for (const variable of variables) {
    const expectedTopic = getTopicFromOriginalName(variable.original_name)

    if (!expectedTopic || topic !== expectedTopic) continue

    for (const value of Object.values(parsed)) {
      if (
        value &&
        typeof value === 'object' &&
        value[variable.original_name]
      ) {
        const rawValue = value[variable.original_name]

        measurements.push({
          time: parsed.Timestamp,
          variable: variable.new_name,
          original_name: variable.original_name,
          value: Number(rawValue.Value),
          unit: rawValue.Unit || variable.unit || '',
        })
      }
    }
  }

  return measurements
}

module.exports = {
  getMqttClient,
  getTopicFromOriginalName,
  extractMeasurementsFromPayload,
}