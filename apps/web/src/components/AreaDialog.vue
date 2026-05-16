<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{
  defaultColor: string
  submitting?: boolean
  error?: string | null
}>()

const emit = defineEmits<{
  save: [payload: { title: string | null; color: string }]
  cancel: []
}>()

// Hand-picked colors with good contrast against OSM base.
const palette = [
  '#ef4444', '#f97316', '#eab308', '#22c55e', '#14b8a6',
  '#3b82f6', '#6366f1', '#a855f7', '#ec4899', '#0ea5e9',
]

const title = ref('')
const color = ref(props.defaultColor)

function submit() {
  emit('save', {
    title: title.value.trim() === '' ? null : title.value.trim(),
    color: color.value,
  })
}
</script>

<template>
  <div class="absolute inset-0 z-20 flex items-center justify-center bg-slate-900/40 px-6">
    <div class="w-full max-w-sm rounded-lg bg-white shadow-lg p-6 space-y-4">
      <h2 class="text-lg font-semibold text-slate-900">Save area</h2>

      <label class="block text-sm font-medium text-slate-700">
        Title <span class="text-slate-400 font-normal">(optional)</span>
        <input
          v-model="title"
          class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-slate-900 shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
          placeholder="e.g. North hillside"
          maxlength="80"
          autofocus
          @keydown.enter="submit"
        />
      </label>

      <div>
        <p class="text-sm font-medium text-slate-700 mb-2">Color</p>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="c in palette"
            :key="c"
            type="button"
            class="w-7 h-7 rounded-full ring-2 transition"
            :class="color === c ? 'ring-slate-900' : 'ring-white shadow'"
            :style="{ backgroundColor: c }"
            :aria-label="`Pick color ${c}`"
            @click="color = c"
          ></button>
        </div>
      </div>

      <p v-if="error" class="text-sm text-amber-700">{{ error }}</p>

      <div class="flex justify-end gap-2 pt-2">
        <button
          class="rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50"
          @click="emit('cancel')"
        >Cancel</button>
        <button
          class="rounded-md bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-700 disabled:opacity-50"
          :disabled="submitting"
          @click="submit"
        >{{ submitting ? 'Saving…' : 'Save area' }}</button>
      </div>
    </div>
  </div>
</template>
