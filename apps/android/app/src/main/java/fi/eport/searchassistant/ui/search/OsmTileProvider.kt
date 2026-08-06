package fi.eport.searchassistant.ui.search

import com.google.android.gms.maps.model.Tile
import com.google.android.gms.maps.model.TileProvider
import fi.eport.searchassistant.BuildConfig
import okhttp3.Cache
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.util.concurrent.TimeUnit

/// OpenStreetMap standard raster tiles.
///
/// Deliberately *not* a `UrlTileProvider`: that only hands a URL back to
/// the Maps SDK, which then fetches it with its own User-Agent. The OSM
/// tile usage policy requires a UA naming the app and blocks generic
/// library defaults "without notice", so the fetch happens here instead.
///
/// The disk cache is ordinary response caching against the tiles' own
/// `Cache-Control` — *not* the pre-seeding or offline archiving the
/// policy prohibits, which is why the app has no "download this area"
/// affordance anywhere.
///
/// Build one per process (see `AppContainer`): two instances pointed at
/// the same OkHttp cache directory fight over its lock.
///
/// https://operations.osmfoundation.org/policies/tiles/
class OsmTileProvider(cacheDir: File) : TileProvider {
    private val client = OkHttpClient.Builder()
        .cache(Cache(File(cacheDir, "osm-tiles"), CACHE_BYTES))
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build()

    /// Called on a Maps SDK background thread, so blocking here is both
    /// expected and correct.
    override fun getTile(x: Int, y: Int, zoom: Int): Tile {
        if (zoom > MAX_ZOOM) return TileProvider.NO_TILE
        val request = Request.Builder()
            .url("https://tile.openstreetmap.org/$zoom/$x/$y.png")
            .header("User-Agent", USER_AGENT)
            .build()
        return try {
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return TileProvider.NO_TILE
                val bytes = response.body?.bytes() ?: return TileProvider.NO_TILE
                Tile(TILE_PX, TILE_PX, bytes)
            }
        } catch (e: Exception) {
            // A dropped tile leaves a gap the SDK re-requests on the next
            // camera move. Never let one take the map down.
            TileProvider.NO_TILE
        }
    }

    private companion object {
        const val TILE_PX = 256

        /// OSM standard tiles stop here; asking for z20+ returns 404s.
        const val MAX_ZOOM = 19

        const val CACHE_BYTES = 64L * 1024 * 1024

        /// Required by the tile policy: names the app, links a contact.
        val USER_AGENT =
            "SearchAssistant/${BuildConfig.VERSION_NAME} (+https://searchassistant.eport.fi)"
    }
}
