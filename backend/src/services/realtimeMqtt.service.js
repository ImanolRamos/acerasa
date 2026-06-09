const mqtt = require('mqtt')

let client = null

const REALTIME_TOPICS = [
  'acerasa/pac3220/voltage/ln',
  'acerasa/pac3220/voltage/ll',
  'acerasa/pac3220/current',
  'acerasa/pac3220/power/active',
  'acerasa/pac3220/power/reactive',
  'acerasa/pac3220/power/apparent',
  'acerasa/pac3220/power/factor',
]

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

function extractTopicMeasurements(topic, payload) {
  let parsed

  try {
    parsed = JSON.parse(payload.toString())
  } catch (error) {
    console.error('[Realtime MQTT] Payload JSON inválido:', error.message)
    return null
  }

  const groupKey = Object.keys(parsed).find((key) => key !== 'Timestamp')

  if (!groupKey || !parsed[groupKey]) {
    return null
  }

  const measurements = Object.entries(parsed[groupKey]).map(
    ([originalName, data]) => ({
      original_name: originalName,
      value: Number(data.Value),
      unit: data.Unit || '',
    }),
  )

  return {
    topic,
    time: parsed.Timestamp,
    group: groupKey,
    measurements,
  }
}

module.exports = {
  getMqttClient,
  extractTopicMeasurements,
}