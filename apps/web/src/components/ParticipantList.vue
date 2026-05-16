<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useSearchStore } from '../stores/searchStore'

const STALE_MS = 5 * 60 * 1000  // 5 min without an event → faded

const store = useSearchStore()

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

const items = computed(() =>
  store.participantList.map((p) => {
    const ageMs = now.value - new Date(p.lastSeenAt).getTime()
    return {
      ...p,
      isMe: p.id === store.me?.id,
      isStale: ageMs > STALE_MS,
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
        class="flex items-center gap-3 px-4 py-2.5 transition-opacity"
        :class="p.isStale && !p.isMe ? 'opacity-50' : ''"
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
      </li>
    </ul>
  </section>
</template>
