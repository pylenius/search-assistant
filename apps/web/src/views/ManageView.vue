<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { api, ApiError } from '../lib/apiClient'
import { getOwnerToken } from '../lib/sessionStore'

const props = defineProps<{ slug: string }>()
const router = useRouter()

const token = ref<string | null>(null)
const loadError = ref<string | null>(null)
const saving = ref(false)
const message = ref<string | null>(null)

const title = ref('')
const expiresLocal = ref('')  // <input type="datetime-local"> binds as a local string

onMounted(async () => {
  token.value = getOwnerToken(props.slug)
  if (!token.value) {
    loadError.value = 'You can only manage searches you created on this device.'
    return
  }
  try {
    const snap = await api.getSearch(props.slug)
    title.value = snap.title
    expiresLocal.value = snap.expiresAt ? toLocalInput(snap.expiresAt) : ''
  } catch (e) {
    loadError.value = e instanceof ApiError && e.status === 404
      ? 'This search no longer exists.'
      : 'Failed to load search.'
  }
})

function toLocalInput(iso: string): string {
  const d = new Date(iso)
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}
function fromLocalInput(s: string): string | null {
  if (!s) return null
  return new Date(s).toISOString()
}

const expiryStatus = computed(() => {
  if (!expiresLocal.value) return 'Never expires'
  const expires = new Date(expiresLocal.value)
  const diffMs = expires.getTime() - Date.now()
  if (diffMs < 0) return 'Already expired'
  const days = Math.floor(diffMs / 86400000)
  const hours = Math.floor((diffMs % 86400000) / 3600000)
  return days > 0 ? `Expires in ${days}d ${hours}h` : `Expires in ${hours}h`
})

async function save() {
  if (!token.value || saving.value) return
  saving.value = true
  message.value = null
  try {
    await api.updateSearch(props.slug, {
      title: title.value.trim(),
      expiresAt: fromLocalInput(expiresLocal.value),
    }, token.value)
    message.value = 'Saved.'
  } catch (e) {
    message.value = e instanceof ApiError ? `Save failed (${e.status}).` : 'Network error.'
  } finally {
    saving.value = false
  }
}

async function clearPathsAction() {
  if (!token.value) return
  if (!confirm('Clear all recorded paths in this search? This cannot be undone.')) return
  try {
    const res = await api.clearPaths(props.slug, token.value)
    message.value = `Cleared ${res.cleared} path${res.cleared === 1 ? '' : 's'}.`
  } catch (e) {
    message.value = e instanceof ApiError ? `Clear failed (${e.status}).` : 'Network error.'
  }
}

async function deleteSearchAction() {
  if (!token.value) return
  if (!confirm('Delete this entire search? All participants, areas, and paths are removed for everyone.')) return
  try {
    await api.deleteSearch(props.slug, token.value)
    await router.push('/')
  } catch (e) {
    message.value = e instanceof ApiError ? `Delete failed (${e.status}).` : 'Network error.'
  }
}
</script>

<template>
  <div class="min-h-full bg-slate-50 py-10 px-6">
    <div class="max-w-lg mx-auto space-y-6">
      <header class="flex items-center justify-between">
        <h1 class="text-xl font-semibold text-slate-900">Manage search</h1>
        <router-link :to="`/s/${slug}`" class="text-sm text-emerald-700 hover:underline">
          ← Back to map
        </router-link>
      </header>

      <div v-if="loadError" class="rounded-md bg-amber-50 border border-amber-200 p-4 text-sm text-amber-800">
        {{ loadError }}
      </div>

      <section v-else class="space-y-5 bg-white rounded-lg shadow p-6">
        <div>
          <label class="block text-sm font-medium text-slate-700">Title</label>
          <input
            v-model="title"
            class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-slate-900 shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
            maxlength="200"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-slate-700">Expires at</label>
          <input
            v-model="expiresLocal"
            type="datetime-local"
            class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-slate-900 shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
          />
          <p class="mt-1 text-xs text-slate-500">{{ expiryStatus }} · leave empty to never expire</p>
        </div>
        <div class="flex gap-2">
          <button
            class="rounded-md bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-700 disabled:opacity-50"
            :disabled="saving || title.trim().length === 0"
            @click="save"
          >{{ saving ? 'Saving…' : 'Save changes' }}</button>
        </div>

        <hr class="border-slate-200" />

        <div class="space-y-3">
          <h2 class="text-sm font-semibold text-slate-700">Danger zone</h2>
          <button
            class="w-full rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50"
            @click="clearPathsAction"
          >Clear all recorded paths</button>
          <button
            class="w-full rounded-md bg-rose-600 px-4 py-2 text-sm font-medium text-white hover:bg-rose-700"
            @click="deleteSearchAction"
          >Delete search</button>
        </div>

        <p v-if="message" class="text-sm text-slate-700">{{ message }}</p>
      </section>
    </div>
  </div>
</template>
