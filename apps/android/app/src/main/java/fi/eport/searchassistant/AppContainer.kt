package fi.eport.searchassistant

import android.content.Context

/// Service-locator-style DI container. Built once in
/// [SearchAssistantApp.onCreate]; each subsystem (ApiClient, stores,
/// SignalR, location) lazy-initialises here. Real wiring lands in
/// step 2 (ApiClient) and step 3 (SessionStore / RecentSearchesStore).
class AppContainer(private val context: Context) {
    // Singletons land here as we wire each subsystem in subsequent steps.
}
