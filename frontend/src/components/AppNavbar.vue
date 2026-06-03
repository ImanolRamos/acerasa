<template>
  <header class="topbar">
    <div class="topbar-left">
      <div class="logo">K</div>
      <div>
        <div class="client-name">{{ clientName }}</div>
        <div class="subtitle">Koiote Cloud — Panel industrial</div>
      </div>
    </div>

    <div class="topbar-right">
      <span class="badge" :class="mqttConnected ? 'badge-ok' : 'badge-error'">
        MQTT {{ mqttConnected ? 'Online' : 'Offline' }}
      </span>

      <span class="badge" :class="apiOnline ? 'badge-ok' : 'badge-error'">
        API {{ apiOnline ? 'Online' : 'Offline' }}
      </span>

      <button class="btn-refresh" @click="$emit('refresh')">
        ↺ Actualizar
      </button>

      <v-btn size="small" variant="outlined" @click="logout">
        Salir
      </v-btn>
    </div>
  </header>
</template>

<script setup>
import { useRouter } from 'vue-router'

defineProps({
  clientName: {
    type: String,
    required: true,
  },
  mqttConnected: {
    type: Boolean,
    default: false,
  },
  apiOnline: {
    type: Boolean,
    default: false,
  },
})

defineEmits(['refresh'])

const router = useRouter()

function logout() {
  localStorage.removeItem('token')
  localStorage.removeItem('user')
  router.push('/login')
}
</script>