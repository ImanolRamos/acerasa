<template>
  <section class="section">
    <h2>Gráfica de mediciones</h2>

    <div class="chart-panel">
      <div class="chart-controls">
        <div>
          <label class="control-label">Media</label>
          <select v-model.number="bucketMinutes" class="select">
            <option :value="1">1 minuto</option>
            <option :value="5">5 minutos</option>
            <option :value="15">15 minutos</option>
            <option :value="60">1 hora</option>
          </select>
        </div>

        <button class="btn-primary" :disabled="selectedVariables.length === 0 || loading" @click="loadChart">
          {{ loading ? 'Cargando...' : 'Ver gráfica' }}
        </button>
      </div>

      <div class="variables-list">
        <label v-for="variable in variables" :key="variable.id" class="variable-option">
          <input
            v-model="selectedVariables"
            type="checkbox"
            :value="variable.new_name"
          >
          <span>{{ variable.new_name }} <small>({{ variable.unit }})</small></span>
        </label>
      </div>

      <div v-if="error" class="error-box">
        {{ error }}
      </div>

      <div v-if="chartData.datasets.length > 0" class="chart-wrapper">
        <Line :data="chartData" :options="chartOptions" />
      </div>

      <div v-else class="empty">
        Selecciona una o varias variables y pulsa “Ver gráfica”.
      </div>
    </div>
  </section>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
} from 'chart.js'
import { Line } from 'vue-chartjs'
import { getAverageHistory, getMeasurementVariables } from '../services/api.js'

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
)

const variables = ref([])
const selectedVariables = ref([])
const bucketMinutes = ref(1)
const historyData = ref([])
const loading = ref(false)
const error = ref('')

const chartData = computed(() => {
  const labels = [...new Set(historyData.value.map((row) => formatLabel(row.time)))]

  const datasets = selectedVariables.value.map((variableName) => {
    const rows = historyData.value.filter((row) => row.variable === variableName)

    return {
      label: variableName,
      data: labels.map((label) => {
        const row = rows.find((item) => formatLabel(item.time) === label)
        return row ? row.value : null
      }),
      tension: 0.25,
    }
  })

  return {
    labels,
    datasets,
  }
})

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  interaction: {
    mode: 'index',
    intersect: false,
  },
  plugins: {
    legend: {
      position: 'bottom',
    },
  },
}

async function loadVariables() {
  const response = await getMeasurementVariables()
  variables.value = response.data || []
}

async function loadChart() {
  loading.value = true
  error.value = ''

  try {
    const response = await getAverageHistory({
      variables: selectedVariables.value,
      bucketMinutes: bucketMinutes.value,
    })

    historyData.value = response.data || []
  } catch (e) {
    error.value = 'No se ha podido cargar la gráfica'
  } finally {
    loading.value = false
  }
}

function formatLabel(date) {
  return new Date(date).toLocaleString('es', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  })
}

onMounted(loadVariables)
</script>