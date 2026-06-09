<template>
  <v-card class="chart-card" rounded="xl" elevation="0">
    <v-card-title class="chart-title">
      {{ title }}
    </v-card-title>

    <v-card-text>
      <div v-if="chartData.datasets.length > 0" class="chart-wrapper">
        <Line :data="chartData" :options="chartOptions" />
      </div>

      <v-alert v-else type="info" variant="tonal">
        Esperando datos...
      </v-alert>
    </v-card-text>
  </v-card>
</template>

<script setup>
import { computed } from 'vue'
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Tooltip,
  Legend,
} from 'chart.js'
import { Line } from 'vue-chartjs'

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Tooltip,
  Legend,
)

const props = defineProps({
  topic: {
    type: String,
    required: true,
  },
  messages: {
    type: Array,
    default: () => [],
  },
})

const COLORS = [
  '#1976d2',
  '#2e7d32',
  '#d32f2f',
  '#ed6c02',
  '#9c27b0',
  '#00acc1',
  '#fbc02d',
  '#5d4037',
]
const TOPIC_TITLES = {
  'acerasa/pac3220/voltage/ln': 'Tensión fase-neutro (V)',
  'acerasa/pac3220/voltage/ll': 'Tensión entre fases (V)',
  'acerasa/pac3220/current': 'Corriente (A)',
  'acerasa/pac3220/power/active': 'Potencia activa (W)',
  'acerasa/pac3220/power/reactive': 'Potencia reactiva (var)',
  'acerasa/pac3220/power/apparent': 'Potencia aparente (VA)',
  'acerasa/pac3220/power/factor': 'Factor de potencia cos(φ)',
}

const title = computed(() => {
  return TOPIC_TITLES[props.topic] || props.topic
})

const chartData = computed(() => {
  const labels = props.messages.map((message) => formatLabel(message.time))

  const variableNames = [
    ...new Set(
      props.messages.flatMap((message) =>
        message.measurements.map((measurement) => measurement.original_name)
      )
    ),
  ]

  const datasets = variableNames.map((variableName, index) => {
    const color = COLORS[index % COLORS.length]

    return {
      label: simplifyName(variableName),
      data: props.messages.map((message) => {
        const measurement = message.measurements.find(
          (item) => item.original_name === variableName
        )

        return measurement ? measurement.value : null
      }),
      borderColor: color,
      backgroundColor: color,
      pointRadius: 2,
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
  animation: false,
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

function formatLabel(date) {
  if (!date) return ''

  const normalizedDate = date.replace(/([+-]\d{2})$/, '$1:00')
  const parsedDate = new Date(normalizedDate)

  if (Number.isNaN(parsedDate.getTime())) {
    return ''
  }

  return parsedDate.toLocaleTimeString('es', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  })
}

function simplifyName(name) {
  return name.split('/').at(-1)
}
</script>

<style scoped>
.chart-card {
  margin-bottom: 24px;
}

.chart-title {
  font-weight: 700;
}

.chart-wrapper {
  height: 320px;
}
</style>