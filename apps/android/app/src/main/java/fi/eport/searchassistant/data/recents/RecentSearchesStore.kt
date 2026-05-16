package fi.eport.searchassistant.data.recents

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
data class RecentSearch(
    val slug: String,
    val title: String,
    val visitedAt: Instant,
    val isOwner: Boolean,
)

/// Persistent list of searches the user has opened on this device.
/// JSON blob in SharedPreferences (parity with iOS
/// RecentSearchesStore.swift — same key, same shape).
/// Capped at 20 entries, oldest-first eviction by visitedAt.
class RecentSearchesStore(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("recents_store", Context.MODE_PRIVATE)

    private val _items = MutableStateFlow(load())
    val items: StateFlow<List<RecentSearch>> = _items.asStateFlow()

    fun upsert(slug: String, title: String, isOwner: Boolean) {
        val now = Clock.System.now()
        val updated = (_items.value.filterNot { it.slug == slug }
                + RecentSearch(slug, title, now, isOwner))
            .sortedByDescending { it.visitedAt }
            .take(CAP)
        _items.value = updated
        persist(updated)
    }

    fun remove(slug: String) {
        _items.value = _items.value.filterNot { it.slug == slug }
        persist(_items.value)
    }

    private fun persist(list: List<RecentSearch>) {
        val raw = json.encodeToString(list)
        prefs.edit().putString(KEY, raw).apply()
    }

    private fun load(): List<RecentSearch> {
        val raw = prefs.getString(KEY, null) ?: return emptyList()
        return runCatching {
            // kotlinx.serialization: passing the list KSerializer
            // implicitly via reified type inference.
            json.decodeFromString<List<RecentSearch>>(raw)
        }.getOrDefault(emptyList())
    }

    companion object {
        private const val KEY = "sa.recents.v1"
        private const val CAP = 20

        private val json = Json {
            ignoreUnknownKeys = true
            // Serializing kotlinx.datetime.Instant with the default
            // serializer (ISO-8601) is fine for local persistence —
            // no need to share with the .NET fractional format here.
        }
    }
}
