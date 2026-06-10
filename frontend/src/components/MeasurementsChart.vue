<template>
  <section class="section">
    <v-card class="chart-card" rounded="xl" elevation="0">
      <v-card-title class="chart-title">
        Gráfica de mediciones
      </v-card-title>

      <v-card-text>
        <div class="filters-grid">
          <v-autocomplete
            v-model="selectedVariables"
            :items="variables"
            item-title="new_name"
            item-value="new_name"
            label="Variables"
            multiple
            chips
            closable-chips
            density="comfortable"
            variant="outlined"
            class="filter-field variables-field"
          />

          <v-text-field
            v-model.number="bucketMinutes"
            label="Media cada"
            type="number"
            min="1"
            suffix="min"
            density="comfortable"
            variant="outlined"
            class="filter-field"
          />

          <v-text-field
            v-model="startDate"
            label="Fecha inicio"
            type="datetime-local"
            step="1"
            density="comfortable"
            variant="outlined"
            class="filter-field"
          />
          <div class="date-limit-field">
            <v-text-field
              v-model="endDate"
              label="Fecha fin"
              type="datetime-local"
              step="1"
              density="comfortable"
              variant="outlined"
              class="filter-field"
            />

            <div class="date-limit-text">
              <div>Tiempo máximo: {{ maxRangeText }}</div>
              <div>
                Fecha fin máxima:
                <button
                  type="button"
                  class="date-limit-button"
                  @click="applyMaxEndDate"
                >
                  {{ maxEndDateText }}
                </button>
              </div>
            </div>
          </div>

          <v-btn
            height="48"
            color="primary"
            :loading="loading"
            :disabled="selectedVariables.length === 0"
            @click="loadChart"
            class="chart-button"
          >
            Ver gráfica
          </v-btn>
        </div>

        <v-alert
          v-if="error"
          type="error"
          variant="tonal"
          class="mb-4"
        >
          {{ error }}
        </v-alert>

        <div v-if="chartData.datasets.length > 0" class="chart-wrapper">
          <Line :data="chartData" :options="chartOptions" />
        </div>

        <v-alert
          v-else
          type="info"
          variant="tonal"
        >
          Selecciona una o varias variables, indica cada cuántos minutos quieres la media y pulsa “Ver gráfica”.
        </v-alert>
      </v-card-text>
    </v-card>
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
const chartVariables = ref([])
const bucketMinutes = ref(1)
const historyData = ref([])
const loading = ref(false)
const error = ref('')
const startDate = ref('')
const endDate = ref('')
const COLORS = [
  '#1976d2', // azul
  '#2e7d32', // verde
  '#d32f2f', // rojo
  '#ed6c02', // naranja
  '#9c27b0', // morado
  '#00acc1', // cyan
  '#fbc02d', // amarillo
  '#5d4037', // marrón
]

const MAX_POINTS = 500
const DEFAULT_START_DATE = '2026-06-02T08:20:00'

const maxEndDateText = computed(() => {
  if (!maxRangeMinutes.value) return '—'

  const start = startDate.value
    ? new Date(startDate.value)
    : new Date(DEFAULT_START_DATE)

  const maxEnd = new Date(start.getTime() + maxRangeMinutes.value * 60 * 1000)

  return maxEnd.toLocaleString('es', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
})

const chartData = computed(() => {
  const labels = [
    ...new Set(historyData.value.map((row) => formatLabel(row.time)))
  ]

  const datasets = chartVariables.value.map((variableName, index) => {
    const rows = historyData.value.filter(
      (row) => row.variable === variableName
    )



    const color = COLORS[index % COLORS.length]

    return {
      label: variableName,

      data: labels.map((label) => {
        const row = rows.find(
          (item) => formatLabel(item.time) === label
        )
        return row ? row.value : null
      }),

      borderColor: color,
      backgroundColor: color,

      pointBackgroundColor: color,
      pointBorderColor: color,

      pointRadius: 3,
      pointHoverRadius: 5,

      borderWidth: 2,
      tension: 0.25,
      fill: false,
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

const maxRangeMinutes = computed(() => {
  const selectedCount = selectedVariables.value.length
  const bucket = Number(bucketMinutes.value)

  if (!selectedCount || !bucket) return null

  return Math.floor((MAX_POINTS * bucket) / selectedCount)
})

const maxRangeText = computed(() => {
  if (!maxRangeMinutes.value) return '—'

  const hours = Math.floor(maxRangeMinutes.value / 60)
  const minutes = maxRangeMinutes.value % 60

  if (hours === 0) return `${minutes} min`
  if (minutes === 0) return `${hours} h`

  return `${hours} h ${minutes} min`
})

async function loadVariables() {
  const response = await getMeasurementVariables()
  variables.value = response.data || []
}

async function loadChart() {
  error.value = ''

  if (!validateChartRequest()) {
    historyData.value = []
    return
  }

  loading.value = true

  try {
    const response = await getAverageHistory({
      variables: selectedVariables.value,
      bucketMinutes: bucketMinutes.value,
      startDate: toIsoOrNull(startDate.value),
      endDate: toIsoOrNull(endDate.value),
    })

    historyData.value = response.data || []
    chartVariables.value = [...selectedVariables.value]
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

function toIsoOrNull(value){
  if (!value) return null
  return new Date(value).toISOString()
}

function validateChartRequest() {
  const selectedCount = selectedVariables.value.length
  const bucket = Number(bucketMinutes.value)

  if (!selectedCount) {
    error.value = 'Selecciona al menos una variable'
    return false
  }

  if (!bucket || bucket < 1) {
    error.value = 'La media debe ser de al menos 1 minuto'
    return false
  }

  if (!endDate.value) {
    error.value = 'Selecciona fecha inicio y fecha fin para evitar cargar demasiados datos'
    return false
  }

  const start = startDate.value
    ? new Date(startDate.value)
    : new Date(DEFAULT_START_DATE)
  const end = new Date(endDate.value)

  if (end <= start) {
    error.value = 'La fecha fin debe ser posterior a la fecha inicio'
    return false
  }

  const diffMinutes = (end - start) / 1000 / 60
  const estimatedPoints = selectedCount * (diffMinutes / bucket)

  if (estimatedPoints > MAX_POINTS) {
    error.value =
      `Demasiados datos para mostrar. ` +
      `Con ${selectedCount} variable(s) y media cada ${bucket} minuto(s), ` +
      `puedes seleccionar como máximo ${maxRangeText.value}.`

    return false
  }

  return true
}

function applyMaxEndDate() {
  if (!maxRangeMinutes.value) return

  const start = startDate.value
    ? new Date(startDate.value)
    : new Date(DEFAULT_START_DATE)

  const maxEnd = new Date(start.getTime() + maxRangeMinutes.value * 60 * 1000)

  endDate.value = toDatetimeLocalValue(maxEnd)
}

function toDatetimeLocalValue(date) {
  const offsetMs = date.getTimezoneOffset() * 60 * 1000
  const localDate = new Date(date.getTime() - offsetMs)

  return localDate.toISOString().slice(0, 19)
}

onMounted(loadVariables)
</script>
<style scoped>
.filters-grid {
  display: grid;
  grid-template-columns: 2fr 1fr 1fr 1fr auto;
  gap: 16px;
  align-items: start;
  margin-bottom: 16px;
}

.filter-field {
  min-width: 0;
}

.chart-button {
  min-width: 140px;
}

.chart-card {
  width: 100%;
}

.chart-wrapper {
  width: 100%;
  height: 420px;
  margin-top: 16px;
}
.date-limit-field {
  min-width: 0;
}

.date-limit-text {
  margin-top: -14px;
  padding-left: 12px;
  font-size: 12px;
  color: #64748b;
}

.date-limit-button {
  padding: 0;
  border: none;
  background: transparent;
  color: #1976d2;
  font-size: 12px;
  cursor: pointer;
  text-decoration: underline;
}

@media (max-width: 900px) {
  .filters-grid {
    grid-template-columns: 1fr;
  }

  .chart-button {
    width: 100%;
  }

  .chart-wrapper {
    height: 300px;
  }
}
</style>