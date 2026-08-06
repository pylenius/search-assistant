package fi.eport.searchassistant.data.settings

import android.content.Context
import android.content.SharedPreferences

/// Which basemap [fi.eport.searchassistant.ui.search.SearchMap] draws
/// underneath the areas, paths and participant markers.
///
/// Google's is the default. OpenStreetMap is offered because it draws
/// forest tracks, footpaths and ditches that Google leaves out — which
/// is most of the ground a search actually covers. Mirrors the iOS
/// `Basemap` enum.
enum class Basemap { GOOGLE, OSM }

/// Device-wide basemap choice, not per-search: which basemap reads best
/// is a property of the user and the terrain, not of any one search.
/// Separate prefs file from [fi.eport.searchassistant.data.session.SessionStore]
/// so clearing tokens never clears preferences.
class BasemapStore(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("settings_store", Context.MODE_PRIVATE)

    fun get(): Basemap {
        val raw = prefs.getString(KEY, null) ?: return Basemap.GOOGLE
        return runCatching { Basemap.valueOf(raw) }.getOrDefault(Basemap.GOOGLE)
    }

    fun set(value: Basemap) {
        prefs.edit().putString(KEY, value.name).apply()
    }

    private companion object {
        const val KEY = "sa.basemap"
    }
}
