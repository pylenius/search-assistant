package fi.eport.searchassistant

import android.content.Context
import fi.eport.searchassistant.data.api.ApiClient

/// Service-locator-style DI container. Built once in
/// [SearchAssistantApp.onCreate]. Subsystems are exposed lazily so
/// activity-scoped consumers only pay for what they touch.
class AppContainer(private val context: Context) {
    val apiClient: ApiClient by lazy { ApiClient() }
}
