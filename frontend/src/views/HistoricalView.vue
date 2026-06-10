<template>
  <main class="page">
    <div class="content">


      <section class="section">
        <MeasurementsChart />
      </section>


    </div>
  </main>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { trackEvent, registerScreenTimeTracking } from '../lib/analytics.js'
import { getHealth, getInfo } from '../services/api.js'

import MeasurementsChart from '../components/MeasurementsChart.vue'

const clientName = import.meta.env.VITE_CLIENT_NAME || 'Koiote'

const health = ref({})
const info = ref({})
const mqttData = ref([])
const lastCheck = ref('—')
let timer = null

async function refresh() {
  try {
    const [h, i] = await Promise.all([
      getHealth(),
      getInfo(),
    ])
    health.value = h
    info.value = i
    mqttData.value = []
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

<style scoped>
.page {
  min-height: 100vh;
  background: #f0f4f8;
}

.content {
  width: 100%;
  max-width: 1600px;
  margin: 0 auto;
  padding: 24px;
}

.section {
  width: 100%;
  margin-bottom: 28px;
}

.links {
  display: flex;
  gap: 12px;
}

.btn-link {
  padding: 10px 20px;
  border-radius: 10px;
  font-size: 14px;
  font-weight: 600;
  text-decoration: none;
  border: none;
  cursor: pointer;
}

.grafana {
  background: #f97316;
  color: white;
}

@media (max-width: 768px) {
  .content {
    padding: 16px;
  }

  .links {
    flex-wrap: wrap;
  }
}
</style>
