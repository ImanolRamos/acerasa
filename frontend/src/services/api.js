import axios from 'axios'

export const API_BASE_URL = 'https://acerasa.koiote.es/api'
const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 5000,
})

export function getHealth() {
  return api.get('/health').then((response) => response.data)
}

export function getInfo() {
  return api.get('/info').then((response) => response.data)
}

export function getMeasurementCount() {
  return api.get('/measurements/count').then((response) => response.data.data)
}

export function getMeasurementVariables() {
  return api.get('/measurements/variables').then((response) => response.data)
}

export function getAverageHistory({ variables, bucketMinutes, startDate, endDate }) {
  return api
    .get('/measurements/history/average', {
      params: {
        variables: variables.join(','),
        bucket_minutes: bucketMinutes,
        startDate,
        endDate,
      },
    })
    .then((response) => response.data)
}

export function login({ usernameOrEmail, password }) {
  return api
    .post('/login', {
      usernameOrEmail,
      password,
    })
    .then((response) => response.data)
}

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')

  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }

  return config
})

export function getLatestMeasurements() {
  return api
    .get('/measurements/latest')
    .then((response) => response.data)
}