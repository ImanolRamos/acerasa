import { API_BASE_URL } from './api'

export function createRealtimeStream({ onOpen, onMessage, onError }) {
  const eventSource = new EventSource(`${API_BASE_URL}/realtime/stream`)

  eventSource.onopen = () => {
    onOpen?.()
  }

  eventSource.onmessage = (event) => {
    const data = JSON.parse(event.data)
    onMessage?.(data)
  }

  eventSource.onerror = (error) => {
    onError?.(error)
  }

  return eventSource
}