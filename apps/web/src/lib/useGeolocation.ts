import { onBeforeUnmount, ref } from 'vue'

const MIN_INTERVAL_MS = 1000

export interface GeoFix {
  lng: number
  lat: number
  accuracyMeters: number
  headingDegrees: number | null
}

export function useGeolocation(onFix: (fix: GeoFix) => void) {
  const supported = 'geolocation' in navigator
  const watching = ref(false)
  const error = ref<string | null>(null)

  let watchId: number | null = null
  let lastSentAt = 0

  function start() {
    if (!supported || watching.value) return
    watching.value = true
    error.value = null

    watchId = navigator.geolocation.watchPosition(
      (pos) => {
        const now = Date.now()
        if (now - lastSentAt < MIN_INTERVAL_MS) return
        lastSentAt = now
        onFix({
          lng: pos.coords.longitude,
          lat: pos.coords.latitude,
          accuracyMeters: pos.coords.accuracy,
          headingDegrees: pos.coords.heading,
        })
      },
      (err) => {
        error.value = err.message || 'Geolocation failed.'
        stop()
      },
      { enableHighAccuracy: true, maximumAge: 1000, timeout: 15000 },
    )
  }

  function stop() {
    if (watchId !== null) {
      navigator.geolocation.clearWatch(watchId)
      watchId = null
    }
    watching.value = false
  }

  onBeforeUnmount(stop)

  return { supported, watching, error, start, stop }
}
