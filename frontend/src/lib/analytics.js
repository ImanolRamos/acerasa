const sessionId = crypto.randomUUID()
const pageOpenedAt = Date.now()

export async function trackEvent(eventType, extra = {}) {
  try {
    await fetch('/api/events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        session_id: sessionId,
        event_type: eventType,
        page: window.location.pathname,
        metadata: { ...extra, user_agent: navigator.userAgent }
      })
    })
  } catch (e) {
    console.warn('Analytics disabled', e)
  }
}

export function registerScreenTimeTracking() {
  window.addEventListener('beforeunload', () => {
    const seconds = Math.round((Date.now() - pageOpenedAt) / 1000)
    navigator.sendBeacon('/api/events', new Blob(
      [JSON.stringify({ session_id: sessionId, event_type: 'screen_time', metadata: { seconds } })],
      { type: 'application/json' }
    ))
  })
}
