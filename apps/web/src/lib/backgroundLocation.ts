import { Capacitor, registerPlugin, type PluginListenerHandle } from '@capacitor/core'

export interface LocationEvent {
  lng: number
  lat: number
  accuracyMeters: number
  headingDegrees?: number
  recordedAt: string
}

export type AuthStatus =
  | 'notDetermined' | 'restricted' | 'denied' | 'whenInUse' | 'always' | 'unknown'

export interface BackgroundLocationPlugin {
  requestPermissions(): Promise<{ status: AuthStatus }>
  start(options?: { distanceFilter?: number }): Promise<{ status: AuthStatus }>
  stop(): Promise<void>
  drainBuffer(): Promise<{ locations: LocationEvent[] }>

  addListener(eventName: 'location', listener: (e: LocationEvent) => void): Promise<PluginListenerHandle>
  addListener(eventName: 'error', listener: (e: { message: string }) => void): Promise<PluginListenerHandle>
  addListener(eventName: 'authorizationChanged', listener: (e: { status: AuthStatus }) => void): Promise<PluginListenerHandle>
}

// `registerPlugin` returns a stub for unknown native impls when running on
// the web — guard with isNativePlatform() so we never call into it there.
const native = registerPlugin<BackgroundLocationPlugin>('BackgroundLocation')

export const BackgroundLocation: BackgroundLocationPlugin | null =
  Capacitor.isNativePlatform() ? native : null
