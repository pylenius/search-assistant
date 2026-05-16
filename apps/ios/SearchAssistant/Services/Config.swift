import Foundation

enum AppConfig {
    /// Base URL for REST + SignalR. Hardcoded to production for now;
    /// flip in DEBUG by setting `API_BASE` in scheme env vars and reading
    /// it here if needed.
    static let apiBaseURL: URL = URL(string: "https://searchassistant.eport.fi")!

    /// SignalR hub path, joined onto apiBaseURL at connect time.
    static let hubPath: String = "/hub/search"
}
