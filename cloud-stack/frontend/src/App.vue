<template>
  <main class="page">
    <header class="topbar">
      <div class="topbar-left">
        <div class="logo">K</div>
        <div>
          <div class="client-name">{{ clientName }}</div>
          <div class="subtitle">Koiote Cloud — Panel MQTT</div>
        </div>
      </div>
      <div class="topbar-right">
        <span class="badge" :class="info.mqtt_connected ? 'badge-ok' : 'badge-error'">
          MQTT {{ info.mqtt_connected ? 'Online' : 'Offline' }}
        </span>
        <span class="badge" :class="health.ok ? 'badge-ok' : 'badge-error'">
          API {{ health.ok ? 'Online' : 'Offline' }}
        </span>
        <button class="btn-refresh" @click="refresh">↺ Actualizar</button>
      </div>
    </header>

    <div class="content">

      <!-- Stats -->
      <div class="stats-grid">
        <div class="stat-card">
          <div class="stat-label">Topics activos</div>
          <div class="stat-value">{{ mqttData.length }}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Mensajes recibidos</div>
          <div class="stat-value">{{ info.mqtt_messages_total || 0 }}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Base de datos</div>
          <div class="stat-value" :class="health.db === 'ok' ? 'text-ok' : 'text-error'">
            {{ health.db || '...' }}
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Última actualización</div>
          <div class="stat-value small">{{ lastCheck }}</div>
        </div>
      </div>

      <!-- Topics MQTT -->
      <section class="section">
        <h2>Datos MQTT en tiempo real</h2>
        <div v-if="mqttData.length === 0" class="empty">
          Sin datos MQTT aún. El Teltonika publicará en:<br>
          <code>{{ clientName }}/#</code>
        </div>
        <div v-else class="topics-grid">
          <div v-for="row in mqttData" :key="row.topic" class="topic-card">
            <div class="topic-name">{{ row.topic }}</div>
            <div class="topic-value">{{ formatPayload(row.payload) }}</div>
            <div class="topic-time">{{ formatTime(row.time) }}</div>
          </div>
        </div>
      </section>

      <!-- Links -->
      <section class="section links">
        <a :href="`https://grafana.${domain}`" target="_blank" class="btn-link grafana">
          Grafana →
        </a>
      </section>

    </div>
  </main>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { trackEvent, registerScreenTimeTracking } from './lib/analytics.js'

const clientName = import.meta.env.VITE_CLIENT_NAME || 'Koiote'
const domain = import.meta.env.VITE_DOMAIN || ''

const health = ref({})
const info = ref({})
const mqttData = ref([])
const lastCheck = ref('—')
let timer = null

async function refresh() {
  try {
    const [h, i, m] = await Promise.all([
      fetch('/api/health').then(r => r.json()),
      fetch('/api/info').then(r => r.json()),
      fetch('/api/mqtt/latest').then(r => r.json()),
    ])
    health.value = h
    info.value = i
    mqttData.value = m.data || []
    lastCheck.value = new Date().toLocaleTimeString('es')
  } catch (e) {
    health.value = { ok: false }
  }
}

function formatPayload(payload) {
  if (!payload) return '—'
  if (typeof payload === 'object') {
    const entries = Object.entries(payload)
    if (entries.length === 1) return String(entries[0][1])
    return JSON.stringify(payload)
  }
  return String(payload)
}

function formatTime(t) {
  if (!t) return '—'
  return new Date(t).toLocaleString('es')
}

onMounted(() => {
  registerScreenTimeTracking()
  trackEvent('page_view')
  refresh()
  timer = setInterval(refresh, 10000)
})

onUnmounted(() => clearInterval(timer))
</script>

<style>
*, *::before, *::after { box-sizing: border-box; }
body { margin: 0; font-family: Arial, sans-serif; background: #f0f4f8; color: #1a202c; }

.topbar {
  position: sticky; top: 0; z-index: 10;
  background: #1b3a5c; color: white;
  display: flex; align-items: center; justify-content: space-between;
  padding: 12px 24px; gap: 16px;
}
.topbar-left { display: flex; align-items: center; gap: 14px; }
.topbar-right { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
.logo { width: 40px; height: 40px; border-radius: 10px; background: #2563eb; color: white; font-size: 20px; font-weight: 700; display: grid; place-items: center; flex-shrink: 0; }
.client-name { font-size: 16px; font-weight: 700; }
.subtitle { font-size: 12px; color: #93c5fd; }

.badge { padding: 4px 10px; border-radius: 20px; font-size: 12px; font-weight: 700; }
.badge-ok { background: #065f46; color: #6ee7b7; }
.badge-error { background: #7f1d1d; color: #fca5a5; }

.btn-refresh { padding: 6px 14px; border-radius: 8px; border: 1px solid #93c5fd; background: transparent; color: #93c5fd; cursor: pointer; font-size: 13px; }
.btn-refresh:hover { background: #1e40af; }

.content { max-width: 1200px; margin: 0 auto; padding: 24px; }

.stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 16px; margin-bottom: 28px; }
.stat-card { background: white; border-radius: 14px; padding: 20px; border: 1px solid #e2e8f0; }
.stat-label { font-size: 12px; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 8px; }
.stat-value { font-size: 24px; font-weight: 700; color: #1b3a5c; }
.stat-value.small { font-size: 14px; font-weight: 400; color: #64748b; }
.text-ok { color: #059669; }
.text-error { color: #dc2626; }

.section { margin-bottom: 28px; }
.section h2 { font-size: 16px; font-weight: 700; color: #1b3a5c; margin: 0 0 14px; }

.empty { background: white; border-radius: 14px; padding: 32px; text-align: center; color: #94a3b8; border: 2px dashed #e2e8f0; line-height: 1.8; }
.empty code { background: #f1f5f9; padding: 2px 8px; border-radius: 6px; font-size: 14px; color: #1b3a5c; }

.topics-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 14px; }
.topic-card { background: white; border-radius: 14px; padding: 18px; border: 1px solid #e2e8f0; }
.topic-name { font-size: 11px; color: #94a3b8; font-family: monospace; margin-bottom: 8px; word-break: break-all; }
.topic-value { font-size: 22px; font-weight: 700; color: #1b3a5c; margin-bottom: 6px; word-break: break-all; }
.topic-time { font-size: 11px; color: #cbd5e1; }

.links { display: flex; gap: 12px; }
.btn-link { padding: 10px 20px; border-radius: 10px; font-size: 14px; font-weight: 600; text-decoration: none; border: none; cursor: pointer; }
.grafana { background: #f97316; color: white; }
</style>
