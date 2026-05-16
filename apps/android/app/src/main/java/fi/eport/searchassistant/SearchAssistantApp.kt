package fi.eport.searchassistant

import android.app.Application

/// Application entry. Hosts the manual DI container ([AppContainer])
/// — the plan flagged Hilt as optional, and AGP 9.x doesn't yet have
/// a compatible Hilt release, so we wire singletons by hand instead.
/// The graph is small (ApiClient, two preferences-backed stores, the
/// SignalR service, the location controller), so a service-locator
/// pattern keeps cognitive overhead lower than a DI framework.
class SearchAssistantApp : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }
}
