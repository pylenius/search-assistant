import MapKit

/// Which basemap `SearchMapView` draws underneath the areas, paths and
/// participant markers.
///
/// Apple's is the default. OpenStreetMap is offered because it draws
/// forest tracks, footpaths and ditches that MapKit leaves out entirely
/// — which is most of the ground a search actually covers.
enum Basemap: String, CaseIterable, Identifiable {
    case apple
    case osm

    var id: String { rawValue }

    var label: String {
        switch self {
        case .apple: return "Apple Maps"
        case .osm: return "OpenStreetMap"
        }
    }
}

/// OpenStreetMap standard raster tiles.
///
/// `MKTileOverlay`'s built-in loader fetches with CFNetwork's default
/// User-Agent, and the OSM tile usage policy blocks generic library
/// defaults "without notice" — so `loadTile` is overridden to issue the
/// request ourselves with a UA that names the app.
///
/// <https://operations.osmfoundation.org/policies/tiles/>
final class OSMTileOverlay: MKTileOverlay {
    private static let template = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"

    /// Required by the tile policy: names the app and gives a contact URL.
    private static let userAgent: String = {
        let version = Bundle.main
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return "SearchAssistant/\(version) (+https://searchassistant.eport.fi)"
    }()

    /// A dedicated session so tile caching stays clear of API traffic.
    /// This is ordinary response caching against the tiles' own
    /// `Cache-Control` — *not* the pre-seeding or offline archiving the
    /// policy prohibits, which is why there is no "download this area"
    /// affordance anywhere in the app.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 8 << 20,
                                   diskCapacity: 64 << 20,
                                   diskPath: "osm-tiles")
        config.requestCachePolicy = .useProtocolCachePolicy
        return URLSession(configuration: config)
    }()

    init() {
        super.init(urlTemplate: Self.template)
        // Stops MapKit rendering its own basemap underneath — otherwise
        // we pay to draw two maps and Apple's shows through while tiles
        // are still loading.
        canReplaceMapContent = true
        tileSize = CGSize(width: 256, height: 256)
        minimumZ = 0
        maximumZ = 19
    }

    override func loadTile(at path: MKTileOverlayPath,
                           result: @escaping (Data?, Error?) -> Void) {
        var request = URLRequest(url: url(forTilePath: path))
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        Self.session.dataTask(with: request) { data, response, error in
            if let error {
                result(nil, error)
                return
            }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                result(nil, URLError(.badServerResponse))
                return
            }
            result(data, nil)
        }.resume()
    }
}
