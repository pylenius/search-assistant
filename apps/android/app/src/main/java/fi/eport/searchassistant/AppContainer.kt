package fi.eport.searchassistant

import android.content.Context
import fi.eport.searchassistant.data.api.ApiClient
import fi.eport.searchassistant.data.recents.RecentSearchesStore
import fi.eport.searchassistant.data.session.SessionStore
import fi.eport.searchassistant.location.LocationController

/// Service-locator-style DI container. Built once in
/// [SearchAssistantApp.onCreate]. Subsystems are exposed lazily so
/// activity-scoped consumers only pay for what they touch.
class AppContainer(private val context: Context) {
    val apiClient: ApiClient by lazy { ApiClient() }
    val sessionStore: SessionStore by lazy { SessionStore(context) }
    val recentSearchesStore: RecentSearchesStore by lazy { RecentSearchesStore(context) }
    /// Singleton — the foreground service writes to it; the VM reads.
    val locationController: LocationController by lazy { LocationController() }
}
