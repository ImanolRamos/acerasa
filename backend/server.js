const express = require('express');
const cors = require('cors');
const mqtt = require('mqtt');
const client_prom = require('prom-client');
const { Pool } = require('pg');

const app = express();
const port = process.env.PORT || 3000;
const clientName = process.env.CLIENT_NAME || 'koiote';

// ============================================================
// TIMESCALEDB
// ============================================================

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

async function waitForDb(retries = 10, delayMs = 3000) {
  for (let i = 1; i <= retries; i++) {
    try {
      await pool.query('SELECT 1');
      console.log('[DB] Conexión establecida con TimescaleDB');
      return;
    } catch (err) {
      console.warn(`[DB] Intento ${i}/${retries} fallido: ${err.message}`);
      if (i < retries) await new Promise(r => setTimeout(r, delayMs));
    }
  }
  console.error('[DB] No se pudo conectar. Saliendo.');
  process.exit(1);
}

// ============================================================
// MQTT — suscripción a todos los topics del cliente
// ============================================================

let mqttConnected = false;
let mqttMessagesTotal = 0;

function connectMqtt() {
  const mqttUrl = process.env.MQTT_URL || 'mqtt://mosquitto:1883';
  const mqttClient = mqtt.connect(mqttUrl, {
    username: process.env.MQTT_USER,
    password: process.env.MQTT_PASSWORD,
    clientId: `koiote-backend-${clientName}-${Date.now()}`,
    reconnectPeriod: 5000,
    connectTimeout: 10000,
  });

  mqttClient.on('connect', () => {
    mqttConnected = true;
    console.log(`[MQTT] Conectado a ${mqttUrl}`);
    // Suscribirse a todos los topics del cliente
    mqttClient.subscribe(`${clientName}/#`, { qos: 1 }, (err) => {
      if (err) console.error('[MQTT] Error suscripción:', err.message);
      else console.log(`[MQTT] Suscrito a ${clientName}/#`);
    });
    // También suscribirse al topic genérico koiote/
    mqttClient.subscribe('koiote/#', { qos: 1 });
  });

  mqttClient.on('message', async (topic, message) => {
    mqttMessagesTotal++;
    const raw = message.toString();
    let payload = {};
    try {
      payload = JSON.parse(raw);
    } catch (_) {
      payload = { value: raw };
    }

    console.log(`[MQTT] ${topic}: ${raw.slice(0, 100)}`);

    try {
      await pool.query(
        `INSERT INTO mqtt_messages (client_name, topic, payload, raw)
         VALUES ($1, $2, $3, $4)`,
        [clientName, topic, payload, raw]
      );
    } catch (err) {
      console.error('[MQTT] Error guardando en DB:', err.message);
    }
  });

  mqttClient.on('error', (err) => {
    console.error('[MQTT] Error:', err.message);
    mqttConnected = false;
  });

  mqttClient.on('reconnect', () => {
    console.log('[MQTT] Reconectando...');
    mqttConnected = false;
  });

  mqttClient.on('offline', () => {
    mqttConnected = false;
  });

  return mqttClient;
}

// ============================================================
// EXPRESS
// ============================================================

app.use(cors());
app.use(express.json({ limit: '50kb' }));

// ── Health ───────────────────────────────────────────────────
app.get('/api/health', async (req, res) => {
  let dbOk = false;
  try { await pool.query('SELECT 1'); dbOk = true; } catch (_) {}
  res.status(dbOk ? 200 : 503).json({
    ok: dbOk,
    service: 'koiote-cloud-backend',
    client: clientName,
    db: dbOk ? 'ok' : 'unavailable',
    mqtt: mqttConnected ? 'ok' : 'disconnected',
    timestamp: new Date().toISOString(),
  });
});

// ── Info ─────────────────────────────────────────────────────
app.get('/api/info', (req, res) => {
  res.json({
    client: clientName,
    backend: 'nodejs',
    version: '1.0.0',
    status: 'running',
    mqtt_connected: mqttConnected,
    mqtt_messages_total: mqttMessagesTotal,
  });
});

// ── MQTT — últimos mensajes por topic ─────────────────────────
app.get('/api/mqtt/latest', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT time, topic, payload, raw
       FROM mqtt_latest
       WHERE client_name = $1
       ORDER BY time DESC`,
      [clientName]
    );
    res.json({ ok: true, data: result.rows });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

// ── MQTT — histórico de un topic ──────────────────────────────
app.get('/api/mqtt/history', async (req, res) => {
  const { topic, limit = 100, from, to } = req.query;
  if (!topic) return res.status(400).json({ ok: false, error: 'topic requerido' });
  try {
    const result = await pool.query(
      `SELECT time, topic, payload, raw
       FROM mqtt_messages
       WHERE client_name = $1
         AND topic = $2
         AND time >= COALESCE($3::timestamptz, NOW() - INTERVAL '24 hours')
         AND time <= COALESCE($4::timestamptz, NOW())
       ORDER BY time DESC
       LIMIT $5`,
      [clientName, topic, from || null, to || null, parseInt(limit)]
    );
    res.json({ ok: true, data: result.rows });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

// ── Analytics frontend ────────────────────────────────────────
app.post('/api/events', async (req, res) => {
  const { session_id, user_id, event_type, page, element, metadata } = req.body;
  if (!event_type) return res.status(400).json({ ok: false, error: 'event_type requerido' });
  try {
    await pool.query(
      `INSERT INTO frontend_events
        (client_name, session_id, user_id, event_type, page, element, metadata)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [clientName, session_id || null, user_id || null, event_type,
       page || null, element || null, typeof metadata === 'object' ? metadata : {}]
    );
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ ok: false });
  }
});

// ── Prometheus metrics ────────────────────────────────────────
client_prom.collectDefaultMetrics({ prefix: 'koiote_' });

const mqttMsgCounter = new client_prom.Counter({
  name: 'koiote_mqtt_messages_total',
  help: 'Total mensajes MQTT recibidos',
  labelNames: ['topic'],
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client_prom.register.contentType);
  res.end(await client_prom.register.metrics());
});

// ============================================================
// ARRANQUE
// ============================================================

async function main() {
  await waitForDb();
  connectMqtt();
  app.listen(port, '0.0.0.0', () => {
    console.log(`[OK] Koiote cloud backend — puerto ${port} — cliente: ${clientName}`);
  });
}

main().catch(err => {
  console.error('[FATAL]', err);
  process.exit(1);
});
