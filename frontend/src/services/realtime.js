import { API_BASE_URL } from './api'

export function createRealtimeStream({ onOpen, onMessage, onError }) {
  const eventSource = new EventSource(`${API_BASE_URL}/realtime/stream`)

  eventSource.onopen = () => {
    onOpen?.()
  }

  eventSource.addEventListener('measurement', (event) => {
    const data = JSON.parse(event.data)
    onMessage?.(data)
  })

  eventSource.addEventListener('connected', () => {
    console.log('SSE backend conectado')
  })

  eventSource.addEventListener('error', (event) => {
    onError?.(event)
  })

  eventSource.onerror = (error) => {
    onError?.(error)
  }

  return eventSource
}