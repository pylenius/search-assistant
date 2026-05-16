<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import type { Polygon } from 'geojson'
import MapView from '../components/MapView.vue'
import JoinDialog from '../components/JoinDialog.vue'
import ParticipantList from '../components/ParticipantList.vue'
import ShareSheet from '../components/ShareSheet.vue'
import { useSearchStore } from '../stores/searchStore'
import { api, ApiError } from '../lib/apiClient'
import { SearchHubClient } from '../lib/searchHub'
import {
  clearSessionToken,
  getOwnerToken,
  getSessionToken,
  setSessionToken,
} from '../lib/sessionStore'
import { useGeolocation } from '../lib/useGeolocation'

const props = defineProps<{ slug: string }>()
const router = useRouter()
const store = useSearchStore()

const loadError = ref<string | null>(null)
const needsJoin = ref(false)
const joinError = ref<string | null>(null)
const joining = ref(false)
const drawing = ref(false)
const drawError = ref<string | null>(null)
const shareOpen = ref(false)
const shareUrl = computed(() => `${window.location.origin}/s/${props.slug}`)
const isOwner = computed(() => getOwnerToken(props.slug) !== null)
const recording = ref(false)
const recordingPathId = ref<string | null>(null)
const recordError = ref<string | null>(null)
const pathBuffer: [number, number][] = []
let flushTimer: ReturnType<typeof setInterval> | null = null
let flushInFlight = false
const PATH_FLUSH_MS = 5000

const hub = new SearchHubClient()

const geo = useGeolocation((fix) => {
  hub.sendPosition(fix.lng, fix.lat, fix.accuracyMeters, fix.headingDegrees)
    .catch((e) => console.warn('sendPosition failed', e))
  if (recording.value) pathBuffer.push([fix.lng, fix.lat])
})

function attachHubHandlers() {
  return {
    onParticipantJoined: store.upsertParticipant,
    onParticipantLeft: (_id: string) => { /* keep in list for v1 */ },
    onPositionUpdated: store.applyPosition,
    onAreaAdded: store.addArea,
    onAreaRemoved: store.removeArea,
    onPathStarted: store.upsertPath,
    onPathUpdated: store.upsertPath,
    onPathFinalized: (id: string) => {
      const p = store.paths.get(id)
      if (p) store.upsertPath({ ...p, endedAt: new Date().toISOString() })
    },
    onSearchUpdated: store.applySearchUpdated,
    onSearchEnded: (_slug: string) => {
      loadError.value = 'The owner ended this search.'
    },
  }
}

async function tryConnectWithToken(token: string) {
  store.connectionState = 'connecting'
  try {
    await hub.connect(props.slug, token, attachHubHandlers())
    store.connectionState = 'connected'
    return true
  } catch (e) {
    store.connectionState = 'failed'
    console.warn('Hub join failed, clearing session', e)
    clearSessionToken(props.slug)
    return false
  }
}

async function handleJoin(displayName: string) {
  joining.value = true
  joinError.value = null
  try {
    const res = await api.joinSearch(props.slug, { displayName })
    setSessionToken(props.slug, res.sessionToken)
    store.me = {
      id: res.participantId,
      sessionToken: res.sessionToken,
      color: res.color,
      displayName,
    }
    store.upsertParticipant({
      id: res.participantId,
      displayName,
      color: res.color,
      joinedAt: new Date().toISOString(),
      lastSeenAt: new Date().toISOString(),
      lastPosition: null,
    })
    needsJoin.value = false
    await tryConnectWithToken(res.sessionToken)
  } catch (e) {
    joinError.value = e instanceof ApiError
      ? `Couldn't join (${e.status}).`
      : 'Network error.'
  } finally {
    joining.value = false
  }
}

function toggleShareLocation() {
  if (geo.watching.value) geo.stop()
  else geo.start()
}

function toggleDrawing() {
  drawing.value = !drawing.value
  drawError.value = null
}

async function onPolygonFinished(geometry: Polygon) {
  drawing.value = false
  const token = getSessionToken(props.slug)
  if (!token) {
    drawError.value = 'You need to be joined to add areas.'
    return
  }
  try {
    await api.addArea(props.slug, geometry, token)
  } catch (e) {
    drawError.value = e instanceof ApiError
      ? `Couldn't save area (${e.status}).`
      : 'Network error.'
  }
}

async function flushPathBuffer() {
  if (flushInFlight || pathBuffer.length === 0) return
  const token = getSessionToken(props.slug)
  if (!token) return

  flushInFlight = true
  try {
    if (!recordingPathId.value) {
      if (pathBuffer.length < 2) return
      const points = pathBuffer.splice(0, pathBuffer.length)
      const dto = await api.startPath(props.slug, points, token)
      recordingPathId.value = dto.id
    } else {
      const points = pathBuffer.splice(0, pathBuffer.length)
      await api.appendToPath(props.slug, recordingPathId.value, points, token)
    }
  } catch (e) {
    recordError.value = e instanceof ApiError
      ? `Couldn't save path (${e.status}).`
      : 'Network error saving path.'
  } finally {
    flushInFlight = false
  }
}

async function toggleRecording() {
  recordError.value = null
  if (recording.value) {
    recording.value = false
    if (flushTimer) { clearInterval(flushTimer); flushTimer = null }
    await flushPathBuffer()
    if (recordingPathId.value) {
      const token = getSessionToken(props.slug)
      if (token) {
        try { await api.finalizePath(props.slug, recordingPathId.value, token) }
        catch (e) { console.warn('finalizePath failed', e) }
      }
      recordingPathId.value = null
    }
  } else {
    recording.value = true
    recordingPathId.value = null
    pathBuffer.length = 0
    if (!geo.watching.value) geo.start()
    flushTimer = setInterval(flushPathBuffer, PATH_FLUSH_MS)
  }
}

onMounted(async () => {
  try {
    const snap = await api.getSearch(props.slug)
    store.hydrate(snap)
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) {
      loadError.value = "This search doesn't exist. It may have expired."
      return
    }
    loadError.value = 'Could not load this search.'
    return
  }

  const existing = getSessionToken(props.slug)
  if (existing) {
    const ok = await tryConnectWithToken(existing)
    if (ok) return
  }
  needsJoin.value = true
})

onBeforeUnmount(() => {
  if (flushTimer) { clearInterval(flushTimer); flushTimer = null }
  geo.stop()
  hub.disconnect().catch(() => {})
  store.reset()
})
</script>

<template>
  <div v-if="loadError" class="min-h-full flex items-center justify-center bg-slate-50 px-6">
    <div class="max-w-sm text-center space-y-3">
      <h2 class="text-lg font-semibold text-slate-900">{{ loadError }}</h2>
      <button class="text-emerald-700 underline" @click="router.push('/')">Start a new search</button>
    </div>
  </div>

  <div v-else class="relative h-full w-full flex">
    <div class="relative flex-1">
      <MapView
        :initial-center="store.center ?? undefined"
        :initial-zoom="store.defaultZoom"
        :drawing="drawing"
        @polygon-finished="onPolygonFinished"
      />
      <div class="absolute top-3 left-3 flex items-center gap-3 rounded-md bg-white/90 backdrop-blur px-3 py-2 shadow text-sm text-slate-700">
        <div>
          <div class="font-medium truncate max-w-[14rem]">{{ store.title || 'Search' }}</div>
          <div class="text-xs text-slate-500">
            {{ store.participantList.length }}
            {{ store.participantList.length === 1 ? 'person' : 'people' }}
          </div>
        </div>
        <button
          class="rounded-md bg-emerald-600 text-white text-xs font-medium px-2.5 py-1.5 hover:bg-emerald-700 transition"
          @click="shareOpen = true"
        >Share</button>
        <router-link
          v-if="isOwner"
          :to="`/s/${slug}/manage`"
          class="rounded-md bg-slate-200 text-slate-700 text-xs font-medium px-2.5 py-1.5 hover:bg-slate-300 transition"
        >Manage</router-link>
      </div>

      <div v-if="!needsJoin" class="absolute top-3 right-16 flex gap-2">
        <button
          class="rounded-md px-3 py-2 shadow text-sm font-medium transition"
          :class="drawing
            ? 'bg-indigo-600 text-white hover:bg-indigo-700'
            : 'bg-white/90 backdrop-blur text-slate-700 hover:bg-white'"
          @click="toggleDrawing"
        >
          <span v-if="drawing">Drawing… click map ↵</span>
          <span v-else>Draw area</span>
        </button>
        <button
          class="rounded-md px-3 py-2 shadow text-sm font-medium transition"
          :class="recording
            ? 'bg-rose-600 text-white hover:bg-rose-700'
            : 'bg-white/90 backdrop-blur text-slate-700 hover:bg-white'"
          :disabled="!geo.supported"
          @click="toggleRecording"
        >
          <span v-if="recording">Recording path ●</span>
          <span v-else>Record path</span>
        </button>
        <button
          class="rounded-md px-3 py-2 shadow text-sm font-medium transition"
          :class="geo.watching.value
            ? 'bg-emerald-600 text-white hover:bg-emerald-700'
            : 'bg-white/90 backdrop-blur text-slate-700 hover:bg-white'"
          :disabled="!geo.supported"
          @click="toggleShareLocation"
        >
          <span v-if="geo.watching.value">Sharing location ●</span>
          <span v-else-if="!geo.supported">Location unsupported</span>
          <span v-else>Share my location</span>
        </button>
      </div>

      <div
        v-if="geo.error.value || drawError || recordError"
        class="absolute top-16 right-3 max-w-xs rounded-md bg-amber-50 border border-amber-200 px-3 py-2 shadow text-xs text-amber-800"
      >
        {{ recordError || drawError || geo.error.value }}
      </div>

      <JoinDialog
        v-if="needsJoin"
        :title="store.title || 'Search'"
        :submitting="joining"
        :error="joinError"
        @join="handleJoin"
      />

      <ShareSheet
        v-if="shareOpen"
        :url="shareUrl"
        :slug="slug"
        :count="store.participantList.length"
        @close="shareOpen = false"
      />
    </div>

    <ParticipantList class="hidden md:flex" />
  </div>
</template>
