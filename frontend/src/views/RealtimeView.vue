<template>
  <main class="realtime-view">
    <h1>Monitorización en tiempo real</h1>

    <v-card class="pa-4 mb-4">
      <div class="d-flex align-center justify-space-between">
        <div>
          <h2>Estado SSE</h2>
          <p>{{ statusText }}</p>
        </div>

        <v-btn :color="isMonitoring ? 'error' : 'primary'" @click="toggleMonitoring">
          {{ isMonitoring ? 'Detener monitorización' : 'Iniciar monitorización' }}
        </v-btn>
      </div>

      <v-alert v-if="errorMessage" type="error" variant="tonal" class="mt-4">
        {{ errorMessage }}
      </v-alert>
    </v-card>

    <RealtimeTopicChart
      v-for="[topic, messages] in topicEntries"
      :key="topic"
      :topic="topic"
      :messages="messages"
    />

  </main>
</template>

<script setup>
import { computed, onBeforeUnmount, ref } from 'vue'
import { createRealtimeStream } from '../services/realtime'
import RealtimeTopicChart from '../components/RealtimeTopicChart.vue'

const MAX_POINTS = 30

const isMonitoring = ref(false)
const lastMessage = ref(null)
const messagesByTopic = ref({})
const errorMessage = ref('')

let stream = null

const statusText = computed(() => {
  return isMonitoring.value
    ? 'Monitorizando datos MQTT'
    : 'Monitorización detenida'
})

const formattedLastMessage = computed(() => {
  return lastMessage.value
    ? JSON.stringify(lastMessage.value, null, 2)
    : ''
})

const topicEntries = computed(() => {
  return Object.entries(messagesByTopic.value)
})

function startMonitoring() {
  if (stream) return

  errorMessage.value = ''

  stream = createRealtimeStream({
    onOpen: () => {
      isMonitoring.value = true
      console.log('SSE conectado')
    },

    onMessage: (data) => {
      console.log('Mensaje SSE recibido:', data)

      lastMessage.value = data

      const topic = data.topic || 'sin-topic'
      const currentMessages = messagesByTopic.value[topic] || []

      messagesByTopic.value[topic] = [
        ...currentMessages,
        data,
      ].slice(-MAX_POINTS)
    },

    onError: (error) => {
      console.error('Error en conexión SSE:', error)
      errorMessage.value = 'Se ha perdido la conexión con el streaming en tiempo real.'
      stopMonitoring()
    },
  })
}

function stopMonitoring() {
  if (stream) {
    stream.close()
    stream = null
  }

  isMonitoring.value = false
}

function toggleMonitoring() {
  if (isMonitoring.value) {
    stopMonitoring()
  } else {
    startMonitoring()
  }
}

onBeforeUnmount(() => {
  stopMonitoring()
})
</script>

<style scoped>
.realtime-view {
  padding: 24px;
}

pre {
  white-space: pre-wrap;
  background: #111827;
  color: #e5e7eb;
  padding: 16px;
  border-radius: 8px;
  overflow-x: auto;
}
</style>