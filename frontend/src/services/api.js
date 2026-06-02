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