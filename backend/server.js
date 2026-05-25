const express = require('express');
const cors = require('cors');
const client = require('prom-client');
const { Pool } = require('pg');

const app = express();
const port = process.env.PORT || 3000;
const clientName = process.env.CLIENT_NAME || 'koiote-client';

// ============================================================
// TIMESCALEDB — pool con reintentos al arrancar
// El healthcheck del docker-compose garantiza que timescaledb
// esté listo, pero añadimos reintentos defensivos igualmente.
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
  console.error('[DB] No se pudo conectar a TimescaleDB. Saliendo.');
  process.exit(1);
}

// ============================================================
// EXPRESS
// ============================================================

app.use(cors());
app.use(express.json({ limit: '50kb' }));

// ============================================================
// PROMETHEUS — métricas automáticas + contador HTTP
// ============================================================

client.collectDefaultMetrics({ prefix: 'koiote_' });

const httpRequests = new client.Counter({
  name: 'koiote_http_requests_total',
  help: 'Total de peticiones HTTP',
  labelNames: ['method', 'route', 'status'],
});

const dbQueryDuration = new client.Histogram({
  name: 'koiote_db_query_duration_seconds',
  help: 'Duración de consultas a TimescaleDB',
  labelNames: ['query'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1],
});

// Middleware contador HTTP
app.use((req, res, next) => {
  res.on('finish', () => {
    httpRequests.inc({
      method: req.method,
      route: req.route?.path || req.path,
      status: res.statusCode,
    });
  });
  next();
});

// ============================================================
// HEALTH — usado por Docker healthcheck
// ============================================================

app.get('/api/health', async (req, res) => {
  let dbOk = false;
  try {
    await pool.query('SELECT 1');
    dbOk = true;
  } catch (_) {}

  const status = dbOk ? 200 : 503;
  res.status(status).json({
    ok: dbOk,
    service: 'koiote-edge-backend',
    client: clientName,
    db: dbOk ? 'ok' : 'unavailable',
    timestamp: new Date().toISOString(),
  });
});

// ============================================================
// INFO
// ============================================================

app.get('/api/info', (req, res) => {
  res.json({
    client: clientName,
    backend: 'nodejs',
    framework: 'express',
    version: process.env.npm_package_version || '1.0.0',
    status: 'running',
  });
});

// ============================================================
// ANALYTICS — guardar eventos del frontend en TimescaleDB
// POST /api/events
// Body: { session_id, user_id?, event_type, page?, element?, metadata? }
// ============================================================

app.post('/api/events', async (req, res) => {
  const { session_id, user_id, event_type, page, element, metadata } = req.body;

  if (!event_type || typeof event_type !== 'string') {
    return res.status(400).json({ ok: false, error: 'event_type requerido' });
  }

  const end = dbQueryDuration.startTimer({ query: 'insert_event' });
  try {
    await pool.query(
      `INSERT INTO frontend_events
        (client_name, session_id, user_id, event_type, page, element, metadata)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        clientName,
        session_id || null,
        user_id || null,
        event_type,
        page || null,
        element || null,
        typeof metadata === 'object' ? metadata : {},
      ]
    );
    end();
    res.json({ ok: true });
  } catch (error) {
    end();
    console.error('[events] Error guardando evento:', error.message);
    res.status(500).json({ ok: false });
  }
});

// ============================================================
// MÉTRICAS DE SISTEMA (snapshot desde el backend)
// GET /api/metrics/system
// Devuelve CPU, RAM, disco leídos de /proc (dentro del contenedor)
// — complementa node-exporter con contexto de aplicación.
// ============================================================

app.get('/api/metrics/system', async (req, res) => {
  try {
    const { execSync } = require('child_process');

    // CPU — lectura de /proc/stat (dos snapshots de 100ms)
    const cpuPct = await getCpuPercent();

    // RAM — /proc/meminfo
    const memRaw = require('fs').readFileSync('/proc/meminfo', 'utf8');
    const memTotal = parseInt(memRaw.match(/MemTotal:\s+(\d+)/)?.[1] || 0);
    const memAvail = parseInt(memRaw.match(/MemAvailable:\s+(\d+)/)?.[1] || 0);
    const memPct = memTotal ? ((memTotal - memAvail) / memTotal * 100).toFixed(1) : null;

    // Disco — df sobre el rootfs del host (montado en node-exporter)
    let diskPct = null;
    try {
      const dfOut = execSync("df / --output=pcent | tail -1").toString().trim();
      diskPct = parseFloat(dfOut.replace('%', ''));
    } catch (_) {}

    res.json({
      ok: true,
      client: clientName,
      timestamp: new Date().toISOString(),
      cpu_pct: cpuPct,
      mem_pct: parseFloat(memPct),
      disk_pct: diskPct,
    });
  } catch (error) {
    console.error('[system] Error leyendo métricas:', error.message);
    res.status(500).json({ ok: false, error: error.message });
  }
});

function getCpuPercent() {
  return new Promise(resolve => {
    const fs = require('fs');
    const read = () => fs.readFileSync('/proc/stat', 'utf8').split('\n')[0].split(/\s+/).slice(1).map(Number);
    const s1 = read();
    setTimeout(() => {
      const s2 = read();
      const idle1 = s1[3] + s1[4];
      const idle2 = s2[3] + s2[4];
      const total1 = s1.reduce((a, b) => a + b, 0);
      const total2 = s2.reduce((a, b) => a + b, 0);
      const pct = (1 - (idle2 - idle1) / (total2 - total1)) * 100;
      resolve(parseFloat(pct.toFixed(1)));
    }, 100);
  });
}

// ============================================================
// PROMETHEUS METRICS ENDPOINT — scrapeado por Prometheus
// ============================================================

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

// ============================================================
// ARRANQUE
// ============================================================

async function main() {
  await waitForDb();

  app.listen(port, '0.0.0.0', () => {
    console.log(`[OK] Koiote backend corriendo en puerto ${port} — cliente: ${clientName}`);
  });
}

main().catch(err => {
  console.error('[FATAL]', err);
  process.exit(1);
});
