<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useSearchStore } from '../stores/searchStore'

const STALE_MS = 5 * 60 * 1000  // 5 min without an event → faded

const store = useSearchStore()

const emit = defineEmits<{
  focus: [participantId: string]
}>()

// Reactive "now" that ticks every 15s so age + stale flags refresh themselves.
const now = ref(Date.now())
let timer: ReturnType<typeof setInterval> | null = null
onMounted(() => { timer = setInterval(() => { now.value = Date.now() }, 15000) })
onBeforeUnmount(() => { if (timer) clearInterval(timer) })

function relativeAge(iso: string, nowMs: number): string {
  const ms = nowMs - new Date(iso).getTime()
  const s = Math.round(ms / 1000)
  if (s < 30) return 'now'
  if (s < 60) return `${s}s ago`
  const m = Math.round(s / 60)
  if (m < 60) return `${m}m ago`
  const h = Math.round(m / 60)
  return `${h}h ago`
}

// Who has anything to hide. The eye is disabled for people who haven't
// recorded a trail yet, so an inert toggle can't be mistaken for one that
// isn't working.
const withTrails = computed(() => {
  const ids = new Set<string>()
  for (const p of store.paths.values()) ids.add(p.participantId)
  return ids
})

const items = computed(() =>
  store.participantList.map((p) => {
    const ageMs = now.value - new Date(p.lastSeenAt).getTime()
    return {
      ...p,
      isMe: p.id === store.me?.id,
      isStale: ageMs > STALE_MS,
      hasPosition: store.positions.has(p.id),
      hasTrail: withTrails.value.has(p.id),
      trailHidden: store.hiddenTrails.has(p.id),
      age: relativeAge(p.lastSeenAt, now.value),
    }
  }),
)
</script>

<template>
  <section class="flex flex-col min-h-0">
    <header class="px-4 py-3 border-b border-slate-200">
      <h3 class="text-sm font-semibold text-slate-700">Participants</h3>
      <p class="text-xs text-slate-500">{{ items.length }} joined</p>
    </header>
    <ul class="flex-1 overflow-auto divide-y divide-slate-100">
      <li
        v-for="p in items"
        :key="p.id"
        class="transition-opacity"
        :class="p.isStale && !p.isMe ? 'opacity-50' : ''"
      >
        <!-- Two buttons side by side rather than one nested in the other:
             a button inside a button is invalid HTML and browsers recover
             from it by dropping the inner one. -->
        <div class="flex items-center">
          <button
            type="button"
            class="min-w-0 flex-1 flex items-center gap-3 pl-4 pr-2 py-2.5 text-left enabled:hover:bg-slate-50 enabled:active:bg-slate-100 disabled:cursor-default transition-colors"
            :disabled="!p.hasPosition"
            :title="p.hasPosition ? 'Center map on this person' : 'No location shared yet'"
            @click="emit('focus', p.id)"
          >
            <span
              class="w-3 h-3 rounded-full shrink-0 ring-2 shadow"
              :class="p.isStale && !p.isMe ? 'ring-slate-200' : 'ring-white'"
              :style="{ backgroundColor: p.color }"
            ></span>
            <div class="min-w-0 flex-1">
              <p class="text-sm font-medium text-slate-900 truncate">
                {{ p.displayName }}<span v-if="p.isMe" class="ml-1 text-xs text-slate-400">(you)</span>
              </p>
              <p class="text-xs text-slate-500">{{ p.age }}</p>
            </div>
          </button>
          <button
            type="button"
            class="shrink-0 mr-2 p-2 rounded-md text-slate-400 enabled:hover:bg-slate-100 enabled:hover:text-slate-600 disabled:opacity-30 disabled:cursor-default transition-colors"
            :class="p.trailHidden ? 'text-slate-600' : ''"
            :disabled="!p.hasTrail"
            :aria-pressed="p.trailHidden"
            :title="!p.hasTrail
              ? 'No trail recorded yet'
              : p.trailHidden ? 'Show this trail' : 'Hide this trail'"
            @click="store.toggleTrail(p.id)"
          >
            <svg v-if="p.trailHidden" class="w-4 h-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path d="M3.28 2.22a.75.75 0 1 0-1.06 1.06l14.5 14.5a.75.75 0 1 0 1.06-1.06l-1.94-1.94A9.9 9.9 0 0 0 19 10s-3.2-6-9-6a8.6 8.6 0 0 0-3.9.93L3.28 2.22Zm4.02 4.02 1.2 1.2a2.5 2.5 0 0 1 3.28 3.28l1.2 1.2a4 4 0 0 0-5.68-5.68Z" />
              <path d="M10 16c-5.8 0-9-6-9-6a12.5 12.5 0 0 1 2.9-3.44l2.06 2.06a4 4 0 0 0 5.42 5.42l1.4 1.4A8.7 8.7 0 0 1 10 16Z" />
            </svg>
            <svg v-else class="w-4 h-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path d="M10 4c5.8 0 9 6 9 6s-3.2 6-9 6-9-6-9-6 3.2-6 9-6Zm0 2.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7Zm0 1.5a2 2 0 1 1 0 4 2 2 0 0 1 0-4Z" />
            </svg>
            <span class="sr-only">{{ p.trailHidden ? 'Show' : 'Hide' }} {{ p.displayName }}'s trail</span>
          </button>
        </div>
      </li>
    </ul>
  </section>
</template>
