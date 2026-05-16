<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import QRCode from 'qrcode'
import { API_BASE } from '../lib/apiClient'

const props = defineProps<{ url: string; count: number; slug: string }>()
const emit = defineEmits<{ close: [] }>()

const gpxUrl = computed(() => `${API_BASE}/api/searches/${encodeURIComponent(props.slug)}/export.gpx`)

const qrDataUrl = ref<string>('')
const copied = ref(false)
const copyError = ref<string | null>(null)

onMounted(async () => {
  try {
    qrDataUrl.value = await QRCode.toDataURL(props.url, { margin: 1, scale: 6 })
  } catch (e) {
    console.warn('qr render failed', e)
  }
})

async function copy() {
  copyError.value = null
  try {
    await navigator.clipboard.writeText(props.url)
    copied.value = true
    setTimeout(() => { copied.value = false }, 2000)
  } catch {
    copyError.value = 'Copy failed — long-press to copy manually.'
  }
}
</script>

<template>
  <div
    class="absolute inset-0 z-30 flex items-center justify-center bg-slate-900/40 px-6"
    @click.self="emit('close')"
  >
    <div class="w-full max-w-sm rounded-lg bg-white shadow-lg p-6 space-y-4">
      <div class="flex items-start justify-between">
        <div>
          <h2 class="text-lg font-semibold text-slate-900">Share this search</h2>
          <p class="text-sm text-slate-500">
            {{ count }} {{ count === 1 ? 'person' : 'people' }} joined so far
          </p>
        </div>
        <button
          class="text-slate-400 hover:text-slate-600 text-xl leading-none"
          @click="emit('close')"
          aria-label="Close"
        >×</button>
      </div>

      <div class="flex justify-center">
        <img
          v-if="qrDataUrl"
          :src="qrDataUrl"
          alt="QR code for this search"
          class="w-48 h-48 rounded border border-slate-200"
        />
        <div v-else class="w-48 h-48 rounded border border-slate-200 bg-slate-50" />
      </div>

      <div class="flex gap-2">
        <input
          readonly
          :value="url"
          class="flex-1 min-w-0 rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 font-mono"
          @focus="(($event.target as HTMLInputElement | null) ?? null)?.select()"
        />
        <button
          class="rounded-md px-4 py-2 text-sm font-medium transition shrink-0"
          :class="copied
            ? 'bg-emerald-100 text-emerald-700'
            : 'bg-slate-900 text-white hover:bg-slate-800'"
          @click="copy"
        >
          {{ copied ? 'Copied ✓' : 'Copy' }}
        </button>
      </div>

      <p v-if="copyError" class="text-xs text-amber-700">{{ copyError }}</p>

      <a
        :href="gpxUrl"
        :download="`${slug}.gpx`"
        class="block text-center w-full rounded-md border border-slate-300 bg-slate-50 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 transition"
      >
        Download GPX
      </a>
    </div>
  </div>
</template>
