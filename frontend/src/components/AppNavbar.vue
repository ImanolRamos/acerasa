<template>
  <header class="topbar">
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
      <button class="btn-logout" @click="logout">Salir</button>
    </nav>

    <v-menu v-model="menuOpen" location="bottom end">
      <template #activator="{ props }">
        <button class="menu-button" v-bind="props">
          ☰
        </button>
      </template>

      <v-list class="mobile-menu-list">
        <v-list-item to="/historic" @click="closeMenu">
          Histórico
        </v-list-item>

        <v-list-item to="/realtime" @click="closeMenu">
          Tiempo real
        </v-list-item>

        <v-list-item to="/info" @click="closeMenu">
          Info
        </v-list-item>

        <v-list-item @click="logout">
          Salir
        </v-list-item>
      </v-list>
    </v-menu>
  </header>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'

const router = useRouter()
const menuOpen = ref(false)

function closeMenu() {
  menuOpen.value = false
}

function logout() {
  closeMenu()
  localStorage.removeItem('token')
  localStorage.removeItem('user')
  router.push('/login')
}
</script>

<style scoped>
.topbar {
  position: sticky;
  top: 0;
  z-index: 20;
  background: #1b3a5c;
  color: white;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 24px;
  gap: 16px;
}

.brand {
  display: flex;
  align-items: center;
  gap: 14px;
}

.logo {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  background: #2563eb;
  color: white;
  font-size: 20px;
  font-weight: 700;
  display: grid;
  place-items: center;
  flex-shrink: 0;
}

.client-name {
  font-size: 16px;
  font-weight: 700;
}

.subtitle {
  font-size: 12px;
  color: #93c5fd;
}

.nav-links {
  display: flex;
  align-items: center;
  gap: 8px;
}

.nav-link,
.btn-logout {
  color: #93c5fd;
  text-decoration: none;
  font-size: 13px;
  font-weight: 600;
  padding: 6px 10px;
  border-radius: 8px;
  border: none;
  background: transparent;
  cursor: pointer;
}

.nav-link:hover,
.nav-link.router-link-active {
  background: #2563eb;
  color: white;
}

.btn-logout {
  border: 1px solid #93c5fd;
  color: white;
}

.btn-logout:hover {
  background: #dc2626;
  border-color: #dc2626;
}

.menu-button {
  display: none;
}

.mobile-menu-list {
  min-width: 180px;
}

@media (max-width: 768px) {
  .topbar {
    padding: 12px 16px;
  }

  .nav-links {
    display: none;
  }

  .menu-button {
    display: block;
    border: 1px solid #93c5fd;
    background: transparent;
    color: white;
    border-radius: 8px;
    font-size: 22px;
    padding: 4px 10px;
    cursor: pointer;
  }
}
</style>