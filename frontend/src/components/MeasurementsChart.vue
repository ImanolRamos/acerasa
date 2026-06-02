<template>
  <section class="section">
    <v-card class="chart-card" rounded="xl" elevation="0">
      <v-card-title class="chart-title">
        Gráfica de mediciones
      </v-card-title>

      <v-card-text>
        <v-row dense>
          <v-col cols="12" md="8">
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
            />
          </v-col>

          <v-col cols="12" md="2">
            <v-text-field
              v-model.number="bucketMinutes"
              label="Media cada"
              type="number"
              min="1"
              suffix="min"
              density="comfortable"
              variant="outlined"
            />
          </v-col>

          <v-col cols="12" md="2">
            <v-btn
              block
              height="48"
              color="primary"
              :loading="loading"
              :disabled="selectedVariables.length === 0"
              @click="loadChart"
            >
              Ver gráfica
            </v-btn>
          </v-col>
        </v-row>

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
const bucketMinutes = ref(1)
const historyData = ref([])
const loading = ref(false)
const error = ref('')
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

const chartData = computed(() => {
  const labels = [...new Set(historyData.value.map((row) => formatLabel(row.time)))]

  const datasets = selectedVariables.value.map((variableName, index) => {
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
      pointRadius: 2,
      borderWidth: 2,
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