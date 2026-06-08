<template>
  <header class="topbar">
    <div class="topbar-left">
      <div class="brand">
        <div class="logo">K</div>
        <div>
          <div class="client-name">Koiote Cloud</div>
          <div class="subtitle">Panel industrial</div>
        </div>
      </div>

      <nav class="nav-links">
        <RouterLink to="/historic" class="nav-link">Histórico</RouterLink>
        <RouterLink to="/realtime" class="nav-link">Tiempo real</RouterLink>
        <RouterLink to="/info" class="nav-link">Info</RouterLink>
      </nav>
    </div>

    <button class="btn-logout" @click="logout">
      Salir
    </button>
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
<style scoped>
.topbar {
  position: sticky;
  top: 0;
  z-index: 10;
  background: #1b3a5c;
  color: white;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 24px;
  gap: 16px;
}

.topbar-left {
  display: flex;
  align-items: center;
  gap: 28px;
}

.brand {
  display: flex;
  align-items: center;
  gap: 14px;
}

.nav-links {
  display: flex;
  align-items: center;
  gap: 8px;
}

.nav-link {
  color: #93c5fd;
  text-decoration: none;
  font-size: 13px;
  font-weight: 600;
  padding: 6px 10px;
  border-radius: 8px;
}

.nav-link:hover {
  background: #1e40af;
  color: white;
}

.nav-link.router-link-active {
  background: #2563eb;
  color: white;
}

.btn-logout {
  padding: 6px 12px;
  border-radius: 8px;
  border: 1px solid #93c5fd;
  background: transparent;
  color: white;
  cursor: pointer;
  font-size: 13px;
}

.btn-logout:hover {
  background: #dc2626;
  border-color: #dc2626;
  color: white;
}
</style>