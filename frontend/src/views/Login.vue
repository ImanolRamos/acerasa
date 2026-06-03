<template>
  <v-container class="login-page" fluid>
    <v-card class="login-card" elevation="6">
      <v-card-title class="text-h5">
        Koiote Cloud
      </v-card-title>

      <v-card-subtitle>
        Acceso Acerasa
      </v-card-subtitle>

      <v-card-text>
        <v-form @submit.prevent="handleLogin">
          <v-text-field
            v-model="usernameOrEmail"
            label="Usuario o correo"
            autocomplete="username"
            :disabled="loading"
            required
          />

          <v-text-field
            v-model="password"
            label="Contraseña"
            type="password"
            autocomplete="current-password"
            :disabled="loading"
            required
          />

          <v-alert
            v-if="error"
            type="error"
            variant="tonal"
            class="mb-4"
          >
            {{ error }}
          </v-alert>

          <v-btn
            type="submit"
            color="primary"
            block
            :loading="loading"
          >
            Entrar
          </v-btn>
        </v-form>
      </v-card-text>
    </v-card>
  </v-container>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { login } from '../services/api'

const router = useRouter()

const usernameOrEmail = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')

async function handleLogin() {
  error.value = ''
  loading.value = true

  try {
    const data = await login({
      usernameOrEmail: usernameOrEmail.value,
      password: password.value,
    })

    localStorage.setItem('token', data.token)
    localStorage.setItem('user', JSON.stringify(data.user))

    router.push('/')
  } catch (err) {
    error.value = 'Usuario/correo o contraseña incorrectos'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
}

.login-card {
  width: 100%;
  max-width: 420px;
}
</style>