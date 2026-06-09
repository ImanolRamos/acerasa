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

    <button class="menu-button" @click="menuOpen = !menuOpen">
      ☰
    </button>

    <div v-if="menuOpen" class="mobile-menu">
      <RouterLink to="/historic" class="mobile-link" @click="closeMenu">Histórico</RouterLink>
      <RouterLink to="/realtime" class="mobile-link" @click="closeMenu">Tiempo real</RouterLink>
      <RouterLink to="/info" class="mobile-link" @click="closeMenu">Info</RouterLink>
      <button class="mobile-link logout" @click="logout">Salir</button>
    </div>
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
  border: 1px solid #93c5fd;
  background: transparent;
  color: white;
  border-radius: 8px;
  font-size: 22px;
  padding: 4px 10px;
}

.mobile-menu {
  display: none;
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
  }

  .mobile-menu {
    position: absolute;
    top: 72px;
    left: 16px;
    right: 16px;
    display: flex;
    flex-direction: column;
    background: #1b3a5c;
    border: 1px solid #34577a;
    border-radius: 12px;
    padding: 8px;
    box-shadow: 0 12px 24px rgba(0, 0, 0, 0.2);
  }

  .mobile-link {
    color: white;
    text-decoration: none;
    padding: 12px;
    border-radius: 8px;
    background: transparent;
    border: none;
    text-align: left;
    font-size: 15px;
  }

  .mobile-link.router-link-active {
    background: #2563eb;
  }

  .mobile-link.logout {
    color: #fecaca;
  }
}
</style>