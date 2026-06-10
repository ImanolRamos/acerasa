<template>
  <main class="page">
    <div class="content">

      <div class="stats-grid">
        <div class="stat-card">
          <div class="stat-label">Base de datos</div>
          <div
            class="stat-value"
            :class="health.db === 'ok' ? 'text-ok' : 'text-error'"
          >
            {{ health.db || '...' }}
          </div>
        </div>

        <div class="stat-card">
          <div class="stat-label">Datos guardados</div>
          <div class="stat-value">
            {{ measurementCount || 0 }}
          </div>
        </div>

        <div class="stat-card">
          <div class="stat-label">Última actualización</div>
          <div class="stat-value small">
            {{ lastCheck }}
          </div>
        </div>
      </div>


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
import { getHealth, getInfo, getMeasurementCount } from '../services/api.js'

const health = ref({})
const info = ref({})
const measurementCount = ref(0)
const lastCheck = ref('—')
const domain = import.meta.env.VITE_DOMAIN || ''


let timer = null

async function refresh() {
  try {
    const [healthData, infoData, count] = await Promise.all([
      getHealth(),
      getInfo(),
      getMeasurementCount(),
    ])

    health.value = healthData
    info.value = infoData
    measurementCount.value = count
    lastCheck.value = new Date().toLocaleString('es')
  } catch (error) {
    console.error(error)
  }
}

onMounted(() => {
  refresh()

  timer = setInterval(
    refresh,
    10 * 60 * 1000,
  )
})

onUnmounted(() => {
  clearInterval(timer)
})
</script>

<style scoped>
.page {
  padding: 24px;
}

.content {
  max-width: 1200px;
  margin: 0 auto;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 16px;
}
.links {
  margin-top: 24px;
}

.stat-card {
  background: white;
  border-radius: 14px;
  padding: 20px;
  border: 1px solid #e2e8f0;
}

.stat-label {
  font-size: 12px;
  color: #94a3b8;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-bottom: 8px;
}

.stat-value {
  font-size: 24px;
  font-weight: 700;
  color: #1b3a5c;
}

.stat-value.small {
  font-size: 14px;
  font-weight: 400;
  color: #64748b;
}

.text-ok {
  color: #059669;
}

.text-error {
  color: #dc2626;
}
.btn-link {
  display: inline-block;
  padding: 10px 20px;
  border-radius: 10px;
  font-size: 14px;
  font-weight: 600;
  text-decoration: none;
}

.grafana {
  background: #f97316;
  color: white;
}
</style>