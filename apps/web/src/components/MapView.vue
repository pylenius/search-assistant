<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, useTemplateRef, watch } from 'vue'
import maplibregl, { type Map as MlMap, type Marker } from 'maplibre-gl'
import { TerraDraw, TerraDrawPolygonMode, TerraDrawSelectMode } from 'terra-draw'
import { TerraDrawMapLibreGLAdapter } from 'terra-draw-maplibre-gl-adapter'
import type { Polygon } from 'geojson'
import { osmRasterStyle } from '../lib/mapStyle'
import { useSearchStore } from '../stores/searchStore'

const props = defineProps<{
  initialCenter?: [number, number]
  initialZoom?: number
  drawing?: boolean
}>()

const emit = defineEmits<{
  polygonFinished: [Polygon]
}>()

const FALLBACK_CENTER: [number, number] = [24.94, 60.17]
const FALLBACK_ZOOM = 12

const mapEl = useTemplateRef<HTMLDivElement>('mapEl')
const locationStatus = ref<'pending' | 'granted' | 'denied' | 'unavailable'>('pending')
const store = useSearchStore()
const markers = new Map<string, Marker>()

let map: MlMap | null = null
let draw: TerraDraw | null = null
let mapLoaded = false

const AREA_SOURCE = 'search-areas'
const PATH_SOURCE = 'search-paths'

const STALE_POSITION_MS = 5 * 60 * 1000

function buildMarkerEl(color: string): HTMLDivElement {
  const el = document.createElement('div')
  el.className = 'sa-marker'
  el.style.cssText = [
    'width:16px', 'height:16px', 'border-radius:50%',
    `background:${color}`,
    'border:2px solid #fff',
    'box-shadow:0 1px 4px rgba(0,0,0,0.4)',
    'cursor:pointer',
    'transition:opacity 200ms',
  ].join(';')
  return el
}

function syncMarkers() {
  if (!map) return
  const now = Date.now()
  const seen = new Set<string>()
  for (const [id, p] of store.positions) {
    seen.add(id)
    const color = store.participants.get(id)?.color ?? '#888'
    const isStale = now - new Date(p.recordedAt).getTime() > STALE_POSITION_MS
    let m = markers.get(id)
    if (!m) {
      m = new maplibregl.Marker({ element: buildMarkerEl(color), anchor: 'center' })
        .setLngLat([p.lng, p.lat])
        .addTo(map)
      markers.set(id, m)
    } else {
      m.setLngLat([p.lng, p.lat])
    }
    const el = m.getElement() as HTMLElement
    if (el.style.background !== color) el.style.background = color
    el.style.opacity = isStale ? '0.4' : '1'
  }
  for (const id of [...markers.keys()]) {
    if (!seen.has(id)) {
      markers.get(id)!.remove()
      markers.delete(id)
    }
  }
}

function buildAreaFeatureCollection() {
  return {
    type: 'FeatureCollection' as const,
    features: [...store.areas.values()].map((a) => ({
      type: 'Feature' as const,
      id: a.id,
      geometry: a.geometry,
      properties: {
        id: a.id,
        // Per-area color overrides participant color when set.
        color: a.color ?? store.participants.get(a.createdByParticipantId)?.color ?? '#888',
      },
    })),
  }
}

function syncAreaLayer() {
  if (!map || !mapLoaded) return
  const fc = buildAreaFeatureCollection()
  const src = map.getSource(AREA_SOURCE) as maplibregl.GeoJSONSource | undefined
  if (src) {
    src.setData(fc)
  } else {
    map.addSource(AREA_SOURCE, { type: 'geojson', data: fc })
    map.addLayer({
      id: 'search-areas-fill',
      type: 'fill',
      source: AREA_SOURCE,
      paint: { 'fill-color': ['get', 'color'], 'fill-opacity': 0.18 },
    })
    map.addLayer({
      id: 'search-areas-line',
      type: 'line',
      source: AREA_SOURCE,
      paint: { 'line-color': ['get', 'color'], 'line-width': 2 },
    })
  }
}

function buildPathFeatureCollection() {
  return {
    type: 'FeatureCollection' as const,
    features: [...store.paths.values()].map((p) => ({
      type: 'Feature' as const,
      id: p.id,
      geometry: p.geometry,
      properties: {
        id: p.id,
        color: store.participants.get(p.participantId)?.color ?? '#888',
        finalized: p.endedAt !== null,
      },
    })),
  }
}

function syncPathLayer() {
  if (!map || !mapLoaded) return
  const fc = buildPathFeatureCollection()
  const src = map.getSource(PATH_SOURCE) as maplibregl.GeoJSONSource | undefined
  if (src) {
    src.setData(fc)
  } else {
    map.addSource(PATH_SOURCE, { type: 'geojson', data: fc })
    map.addLayer({
      id: 'search-paths-line',
      type: 'line',
      source: PATH_SOURCE,
      layout: { 'line-join': 'round', 'line-cap': 'round' },
      paint: {
        'line-color': ['get', 'color'],
        'line-width': 3,
        'line-opacity': ['case', ['get', 'finalized'], 0.9, 0.75],
        'line-dasharray': ['case', ['get', 'finalized'], ['literal', [1]], ['literal', [2, 1.5]]],
      },
    })
  }
}

function ensureDraw() {
  if (draw || !map) return
  // Need a passive mode to switch to when the user toggles draw off, otherwise
  // terra-draw stays in polygon mode and the next map click starts another polygon.
  draw = new TerraDraw({
    adapter: new TerraDrawMapLibreGLAdapter({ map }),
    modes: [new TerraDrawPolygonMode(), new TerraDrawSelectMode({ flags: {} })],
  })
  draw.start()
  draw.setMode('select')
  draw.on('finish', (id) => {
    const f = draw?.getSnapshotFeature(id)
    if (f?.geometry.type === 'Polygon') {
      emit('polygonFinished', f.geometry as Polygon)
    }
    draw?.clear()
    draw?.setMode('select')
  })
}

function applyDrawingMode(isDrawing: boolean) {
  if (!draw) return
  draw.clear()  // wipe any in-progress polygon when toggling
  draw.setMode(isDrawing ? 'polygon' : 'select')
}

onMounted(() => {
  if (!mapEl.value) return

  map = new maplibregl.Map({
    container: mapEl.value,
    style: osmRasterStyle,
    center: props.initialCenter ?? FALLBACK_CENTER,
    zoom: props.initialZoom ?? FALLBACK_ZOOM,
    attributionControl: { compact: true },
  })

  map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right')

  map.on('load', () => {
    mapLoaded = true
    syncAreaLayer()
    syncPathLayer()
    syncMarkers()
    ensureDraw()
    if (props.drawing) applyDrawingMode(true)
  })

  if (props.initialCenter) {
    locationStatus.value = 'granted'
  } else if (!('geolocation' in navigator)) {
    locationStatus.value = 'unavailable'
  } else {
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        locationStatus.value = 'granted'
        map?.easeTo({
          center: [pos.coords.longitude, pos.coords.latitude],
          zoom: 14,
          duration: 600,
        })
      },
      () => { locationStatus.value = 'denied' },
      { enableHighAccuracy: true, timeout: 8000, maximumAge: 30000 },
    )
  }
})

watch(() => store.positions, syncMarkers, { deep: true })
watch(() => store.participants, () => { syncMarkers(); syncAreaLayer(); syncPathLayer() }, { deep: true })
watch(() => store.areas, syncAreaLayer, { deep: true })
watch(() => store.paths, syncPathLayer, { deep: true })
watch(() => props.drawing, (v) => applyDrawingMode(!!v))

onBeforeUnmount(() => {
  for (const m of markers.values()) m.remove()
  markers.clear()
  draw?.stop()
  draw = null
  map?.remove()
  map = null
})
</script>

<template>
  <div class="relative h-full w-full">
    <div ref="mapEl" class="h-full w-full"></div>
    <div
      v-if="locationStatus !== 'granted'"
      class="absolute bottom-3 left-3 rounded-md bg-white/90 backdrop-blur px-3 py-2 shadow text-xs text-slate-700"
    >
      <template v-if="locationStatus === 'pending'">Locating you…</template>
      <template v-else-if="locationStatus === 'denied'">Location denied — showing default area.</template>
      <template v-else>Location not available on this device.</template>
    </div>
  </div>
</template>
