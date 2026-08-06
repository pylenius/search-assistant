package fi.eport.searchassistant

import android.content.Context
import fi.eport.searchassistant.data.api.ApiClient
import fi.eport.searchassistant.data.recents.RecentSearchesStore
import fi.eport.searchassistant.data.session.SessionStore
import fi.eport.searchassistant.data.settings.BasemapStore
import fi.eport.searchassistant.location.LocationController
import fi.eport.searchassistant.ui.search.OsmTileProvider

/// Service-locator-style DI container. Built once in
/// [SearchAssistantApp.onCreate]. Subsystems are exposed lazily so
/// activity-scoped consumers only pay for what they touch.
class AppContainer(private val context: Context) {
    val apiClient: ApiClient by lazy { ApiClient() }
    val sessionStore: SessionStore by lazy { SessionStore(context) }
    val recentSearchesStore: RecentSearchesStore by lazy { RecentSearchesStore(context) }
    val basemapStore: BasemapStore by lazy { BasemapStore(context) }
    /// Singleton — the foreground service writes to it; the VM reads.
    val locationController: LocationController by lazy { LocationController() }
    /// One per process: it owns an OkHttp disk cache, and a second
    /// instance on the same directory would fight over the cache lock.
    val osmTileProvider: OsmTileProvider by lazy { OsmTileProvider(context.cacheDir) }
}
