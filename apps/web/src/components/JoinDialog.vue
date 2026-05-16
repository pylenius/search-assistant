<script setup lang="ts">
import { ref } from 'vue'

const emit = defineEmits<{ join: [displayName: string] }>()
defineProps<{ title: string; submitting?: boolean; error?: string | null }>()

const name = ref('')

function submit() {
  const trimmed = name.value.trim()
  if (trimmed.length === 0) return
  emit('join', trimmed)
}
</script>

<template>
  <div class="absolute inset-0 z-20 flex items-center justify-center bg-slate-900/40 px-6">
    <div class="w-full max-w-sm rounded-lg bg-white shadow-lg p-6 space-y-4">
      <div>
        <p class="text-sm text-slate-500">Joining</p>
        <h2 class="text-lg font-semibold text-slate-900 truncate">{{ title }}</h2>
      </div>
      <label class="block text-sm font-medium text-slate-700">
        Your display name
        <input
          v-model="name"
          class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-slate-900 shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
          placeholder="e.g. Alice"
          maxlength="60"
          autofocus
          @keydown.enter="submit"
        />
      </label>
      <button
        class="w-full inline-flex items-center justify-center rounded-md bg-emerald-600 px-4 py-2 text-white font-medium shadow-sm hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition"
        :disabled="submitting || name.trim().length === 0"
        @click="submit"
      >
        {{ submitting ? 'Joining…' : 'Join search' }}
      </button>
      <p v-if="error" class="text-sm text-amber-700">{{ error }}</p>
    </div>
  </div>
</template>
