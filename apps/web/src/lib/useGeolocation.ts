import { onBeforeUnmount, ref } from 'vue'
import { BackgroundLocation, type LocationEvent } from './backgroundLocation'

const MIN_INTERVAL_MS = 1000

export interface GeoFix {
  lng: number
  lat: number
  accuracyMeters: number
  headingDegrees: number | null
}

export function useGeolocation(onFix: (fix: GeoFix) => void) {
  const usingNative = BackgroundLocation !== null
  const supported = usingNative || 'geolocation' in navigator
  const watching = ref(false)
  const error = ref<string | null>(null)

  let watchId: number | null = null
  let nativeRemove: (() => Promise<void>) | null = null
  let lastSentAt = 0

  function deliver(fix: GeoFix) {
    const now = Date.now()
    if (now - lastSentAt < MIN_INTERVAL_MS) return
    lastSentAt = now
    onFix(fix)
  }

  async function startNative() {
    const perm = await BackgroundLocation!.requestPermissions()
    if (perm.status === 'denied' || perm.status === 'restricted') {
      error.value = 'Location permission denied.'
      watching.value = false
      return
    }
    const sub = await BackgroundLocation!.addListener('location', (e: LocationEvent) => {
      deliver({
        lng: e.lng,
        lat: e.lat,
        accuracyMeters: e.accuracyMeters,
        headingDegrees: e.headingDegrees ?? null,
      })
    })
    nativeRemove = () => sub.remove()
    await BackgroundLocation!.start({ distanceFilter: 5 })
  }

  function startBrowser() {
    watchId = navigator.geolocation.watchPosition(
      (pos) => deliver({
        lng: pos.coords.longitude,
        lat: pos.coords.latitude,
        accuracyMeters: pos.coords.accuracy,
        headingDegrees: pos.coords.heading,
      }),
      (err) => {
        error.value = err.message || 'Geolocation failed.'
        stop()
      },
      { enableHighAccuracy: true, maximumAge: 1000, timeout: 15000 },
    )
  }

  async function start() {
    if (!supported || watching.value) return
    watching.value = true
    error.value = null
    try {
      if (usingNative) await startNative()
      else startBrowser()
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Geolocation failed.'
      watching.value = false
    }
  }

  async function stop() {
    if (watchId !== null) {
      navigator.geolocation.clearWatch(watchId)
      watchId = null
    }
    if (nativeRemove) {
      try { await nativeRemove() } catch { /* listener already gone */ }
      nativeRemove = null
    }
    if (usingNative && BackgroundLocation) {
      try { await BackgroundLocation.stop() } catch { /* already stopped */ }
    }
    watching.value = false
  }

  onBeforeUnmount(() => { void stop() })

  return { supported, watching, error, start, stop }
}
