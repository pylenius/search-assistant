package fi.eport.searchassistant

object AppConfig {
    /// Production .NET 10 backend. Override at build time later if a
    /// staging environment is added.
    const val API_BASE_URL = "https://searchassistant.eport.fi/"

    /// SignalR hub path joined onto [API_BASE_URL] at connect time.
    const val HUB_PATH = "hub/search"

    /// Host expected on App Links — used by MainActivity to parse
    /// `/s/{slug}` deep links.
    const val APP_LINKS_HOST = "searchassistant.eport.fi"
}
