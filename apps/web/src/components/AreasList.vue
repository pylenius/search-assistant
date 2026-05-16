<script setup lang="ts">
import { computed } from 'vue'
import { useSearchStore } from '../stores/searchStore'

defineEmits<{ remove: [areaId: string] }>()

const store = useSearchStore()

const items = computed(() =>
  [...store.areas.values()]
    .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
    .map((a) => ({
      id: a.id,
      title: a.title || 'Untitled area',
      color: a.color ?? store.participants.get(a.createdByParticipantId)?.color ?? '#888',
      authorName: store.participants.get(a.createdByParticipantId)?.displayName ?? 'unknown',
    })),
)
</script>

<template>
  <section v-if="items.length > 0" class="flex flex-col border-t border-slate-200">
    <header class="px-4 py-3 border-b border-slate-200">
      <h3 class="text-sm font-semibold text-slate-700">Areas</h3>
      <p class="text-xs text-slate-500">{{ items.length }} drawn</p>
    </header>
    <ul class="overflow-auto divide-y divide-slate-100">
      <li
        v-for="a in items"
        :key="a.id"
        class="flex items-center gap-3 px-4 py-2.5 group"
      >
        <span
          class="w-3 h-3 rounded-full shrink-0 ring-2 ring-white shadow"
          :style="{ backgroundColor: a.color }"
        ></span>
        <div class="min-w-0 flex-1">
          <p class="text-sm font-medium text-slate-900 truncate">{{ a.title }}</p>
          <p class="text-xs text-slate-500">by {{ a.authorName }}</p>
        </div>
        <button
          class="text-slate-300 hover:text-rose-600 text-lg leading-none opacity-0 group-hover:opacity-100 transition"
          :aria-label="`Remove ${a.title}`"
          @click="$emit('remove', a.id)"
        >×</button>
      </li>
    </ul>
  </section>
</template>
