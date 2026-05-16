<script setup lang="ts">
import { computed } from 'vue'
import { useSearchStore } from '../stores/searchStore'

const store = useSearchStore()

function relativeAge(iso: string): string {
  const ms = Date.now() - new Date(iso).getTime()
  const s = Math.round(ms / 1000)
  if (s < 30) return 'now'
  if (s < 60) return `${s}s ago`
  const m = Math.round(s / 60)
  if (m < 60) return `${m}m ago`
  const h = Math.round(m / 60)
  return `${h}h ago`
}

const items = computed(() =>
  store.participantList.map((p) => ({
    ...p,
    isMe: p.id === store.me?.id,
    age: relativeAge(p.lastSeenAt),
  })),
)
</script>

<template>
  <aside class="w-64 bg-white/95 backdrop-blur shadow-lg border-l border-slate-200 flex flex-col">
    <header class="px-4 py-3 border-b border-slate-200">
      <h3 class="text-sm font-semibold text-slate-700">Participants</h3>
      <p class="text-xs text-slate-500">{{ items.length }} joined</p>
    </header>
    <ul class="flex-1 overflow-auto divide-y divide-slate-100">
      <li v-for="p in items" :key="p.id" class="flex items-center gap-3 px-4 py-2.5">
        <span
          class="w-3 h-3 rounded-full shrink-0 ring-2 ring-white shadow"
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
  </aside>
</template>
