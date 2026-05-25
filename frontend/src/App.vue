<template>
  <main class="page">
    <section class="card">
      <div class="header">
        <div class="logo">K</div>
        <div>
          <h1>{{ clientName }}</h1>
          <p class="subtitle">Koiote Edge — Panel de control</p>
        </div>
      </div>

      <div class="grid">
        <div class="metric" :class="health.ok ? 'ok' : 'error'">
          <span class="metric-label">Backend</span>
          <span class="metric-value">{{ health.ok ? 'Online' : 'Offline' }}</span>
        </div>
        <div class="metric">
          <span class="metric-label">Base de datos</span>
          <span class="metric-value" :class="health.db === 'ok' ? 'ok' : 'error'">
            {{ health.db || '...' }}
          </span>
        </div>
        <div class="metric">
          <span class="metric-label">Versión</span>
          <span class="metric-value">{{ info.version || '...' }}</span>
        </div>
        <div class="metric">
          <span class="metric-label">Última comprobación</span>
          <span class="metric-value small">{{ lastCheck }}</span>
        </div>
      </div>

      <div class="links">
        <a href="/grafana/" target="_blank" class="btn-link grafana">Grafana</a>
        <a href="/prometheus/" target="_blank" class="btn-link prometheus">Prometheus</a>
        <a href="/cadvisor/" target="_blank" class="btn-link cadvisor">cAdvisor</a>
        <button class="btn-link refresh" @click="refresh">Actualizar</button>
      </div>
    </section>
  </main>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { registerScreenTimeTracking, trackEvent } from './lib/analytics.js'

const clientName = import.meta.env.VITE_CLIENT_NAME || 'Koiote Edge'
const health = ref({})
const info = ref({})
const lastCheck = ref('—')
let timer = null

async function refresh() {
  try {
    const [h, i] = await Promise.all([
      fetch('/api/health').then(r => r.json()),
      fetch('/api/info').then(r => r.json()),
    ])
    health.value = h
    info.value = i
    lastCheck.value = new Date().toLocaleTimeString('es')
  } catch (e) {
    health.value = { ok: false, db: 'error' }
  }
}

onMounted(() => {
  registerScreenTimeTracking()
  trackEvent('page_view')
  refresh()
  timer = setInterval(refresh, 30000)
})

onUnmounted(() => clearInterval(timer))
</script>

<style>
*, *::before, *::after { box-sizing: border-box; }
body { margin: 0; font-family: Arial, sans-serif; background: #f0f4f8; color: #1a202c; }
.page { min-height: 100vh; display: grid; place-items: center; padding: 24px; }
.card { width: min(760px, 100%); background: white; border-radius: 20px; padding: 36px; box-shadow: 0 8px 32px rgba(0,0,0,0.08); }
.header { display: flex; align-items: center; gap: 20px; margin-bottom: 32px; }
.logo { width: 52px; height: 52px; border-radius: 14px; background: #1b3a5c; color: white; font-size: 24px; font-weight: 700; display: grid; place-items: center; flex-shrink: 0; }
h1 { margin: 0; font-size: 22px; color: #1b3a5c; }
.subtitle { margin: 4px 0 0; color: #667085; font-size: 14px; }
.grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 28px; }
.metric { background: #f8fafc; border-radius: 14px; padding: 20px; border: 1px solid #e2e8f0; }
.metric-label { display: block; font-size: 12px; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 8px; }
.metric-value { display: block; font-size: 20px; font-weight: 700; color: #1a202c; }
.metric-value.ok { color: #059669; }
.metric-value.error { color: #dc2626; }
.metric-value.small { font-size: 14px; font-weight: 400; }
.links { display: flex; gap: 12px; flex-wrap: wrap; }
.btn-link { padding: 10px 20px; border-radius: 10px; font-size: 14px; font-weight: 600; text-decoration: none; border: none; cursor: pointer; transition: opacity .2s; }
.btn-link:hover { opacity: .85; }
.grafana { background: #f97316; color: white; }
.prometheus { background: #e5470c; color: white; }
.cadvisor { background: #2563eb; color: white; }
.refresh { background: #1b3a5c; color: white; }
</style>
