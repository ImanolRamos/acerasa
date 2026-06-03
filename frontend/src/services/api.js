import axios from 'axios'

const api = axios.create({
  baseURL: '/api',
  timeout: 5000,
})

export function getHealth() {
  return api.get('/health').then((response) => response.data)
}

export function getInfo() {
  return api.get('/info').then((response) => response.data)
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