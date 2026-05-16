<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { api, ApiError } from '../lib/apiClient'
import { setOwnerToken } from '../lib/sessionStore'

const router = useRouter()
const creating = ref(false)
const error = ref<string | null>(null)
const title = ref('Quick search')

async function getCenter(): Promise<{ lng: number; lat: number } | null> {
  if (!('geolocation' in navigator)) return null
  return new Promise((resolve) => {
    navigator.geolocation.getCurrentPosition(
      (pos) => resolve({ lng: pos.coords.longitude, lat: pos.coords.latitude }),
      () => resolve(null),
      { enableHighAccuracy: true, timeout: 5000, maximumAge: 60000 },
    )
  })
}

async function startSearch() {
  if (creating.value) return
  creating.value = true
  error.value = null
  try {
    const center = await getCenter()
    const res = await api.createSearch({
      title: title.value.trim() || 'Quick search',
      centerLng: center?.lng ?? null,
      centerLat: center?.lat ?? null,
      zoom: 14,
    })
    setOwnerToken(res.slug, res.ownerToken)
    await router.push(`/s/${res.slug}`)
  } catch (e) {
    error.value = e instanceof ApiError
      ? `Couldn't create search (${e.status}).`
      : 'Network error — is the API running?'
    creating.value = false
  }
}
</script>

<template>
  <div class="min-h-full flex flex-col items-center justify-center bg-slate-50 px-6">
    <div class="max-w-md w-full text-center space-y-6">
      <h1 class="text-3xl font-semibold text-slate-900">Search Assistant</h1>
      <p class="text-slate-600">
        Share a search area and live positions with everyone you're searching with.
        No account needed.
      </p>
      <div class="space-y-3">
        <input
          v-model="title"
          class="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-slate-900 shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
          placeholder="What are you searching for?"
          maxlength="100"
        />
        <button
          class="w-full inline-flex items-center justify-center rounded-md bg-emerald-600 px-5 py-2.5 text-white font-medium shadow-sm hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition"
          :disabled="creating"
          @click="startSearch"
        >
          {{ creating ? 'Creating…' : 'Create new search' }}
        </button>
      </div>
      <p v-if="error" class="text-sm text-amber-700">{{ error }}</p>
    </div>
  </div>
</template>
