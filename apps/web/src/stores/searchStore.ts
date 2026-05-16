import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type {
  AreaDto,
  ParticipantDto,
  PathDto,
  PositionUpdateDto,
  SearchSnapshotDto,
} from '../types/api'

export const useSearchStore = defineStore('search', () => {
  const slug = ref<string | null>(null)
  const title = ref<string>('')
  const expiresAt = ref<string | null>(null)
  const center = ref<[number, number] | null>(null)
  const defaultZoom = ref(13)

  const participants = ref<Map<string, ParticipantDto>>(new Map())
  const areas = ref<Map<string, AreaDto>>(new Map())
  const paths = ref<Map<string, PathDto>>(new Map())
  const positions = ref<Map<string, PositionUpdateDto>>(new Map())

  const me = ref<{ id: string; sessionToken: string; color: string; displayName: string } | null>(null)
  const connectionState = ref<'idle' | 'connecting' | 'connected' | 'failed'>('idle')

  function hydrate(snap: SearchSnapshotDto) {
    slug.value = snap.slug
    title.value = snap.title
    expiresAt.value = snap.expiresAt
    center.value = snap.center ? [snap.center.coordinates[0], snap.center.coordinates[1]] : null
    defaultZoom.value = snap.defaultZoom
    participants.value = new Map(snap.participants.map((p) => [p.id, p]))
    areas.value = new Map(snap.areas.map((a) => [a.id, a]))
    paths.value = new Map(snap.paths.map((p) => [p.id, p]))
    positions.value = new Map(
      snap.participants
        .filter((p) => p.lastPosition)
        .map((p) => [p.id, {
          participantId: p.id,
          lng: p.lastPosition!.coordinates[0],
          lat: p.lastPosition!.coordinates[1],
          accuracyMeters: 0,
          headingDegrees: null,
          recordedAt: p.lastSeenAt,
        }]),
    )
  }

  function upsertParticipant(p: ParticipantDto) {
    participants.value = new Map(participants.value).set(p.id, p)
  }

  function applyPosition(u: PositionUpdateDto) {
    positions.value = new Map(positions.value).set(u.participantId, u)
  }

  function addArea(a: AreaDto) { areas.value = new Map(areas.value).set(a.id, a) }
  function removeArea(id: string) {
    const next = new Map(areas.value); next.delete(id); areas.value = next
  }
  function upsertPath(p: PathDto) { paths.value = new Map(paths.value).set(p.id, p) }

  const participantList = computed(() =>
    [...participants.value.values()].sort((a, b) => a.joinedAt.localeCompare(b.joinedAt)),
  )

  function applySearchUpdated(u: { title: string; expiresAt: string | null }) {
    title.value = u.title
    expiresAt.value = u.expiresAt
  }

  function reset() {
    slug.value = null
    title.value = ''
    expiresAt.value = null
    center.value = null
    defaultZoom.value = 13
    participants.value = new Map()
    areas.value = new Map()
    paths.value = new Map()
    positions.value = new Map()
    me.value = null
    connectionState.value = 'idle'
  }

  return {
    slug, title, expiresAt, center, defaultZoom,
    participants, participantList, areas, paths, positions,
    me, connectionState,
    hydrate, upsertParticipant, applyPosition, addArea, removeArea, upsertPath,
    applySearchUpdated, reset,
  }
})
