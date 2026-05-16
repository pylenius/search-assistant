package fi.eport.searchassistant.data.realtime

import com.microsoft.signalr.HubConnection
import com.microsoft.signalr.HubConnectionBuilder
import com.microsoft.signalr.HubConnectionState
import fi.eport.searchassistant.AppConfig
import io.reactivex.rxjava3.core.Single
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.withContext
import java.util.UUID

/// Wraps the Microsoft SignalR Java client. The Java client is
/// RxJava-3 flavoured; we bridge to coroutines with `blockingAwait`
/// on Dispatchers.IO for the connect/disconnect/invoke calls, and
/// emit incoming events through a [SharedFlow] for the VM to collect.
class SignalRService {
    private var connection: HubConnection? = null

    private val _events = MutableSharedFlow<HubEvent>(extraBufferCapacity = 64)
    val events: SharedFlow<HubEvent> = _events.asSharedFlow()

    /// Builds + starts the hub, joins the search, and returns the
    /// participant id the server assigned (matches iOS contract).
    /// Caller must already hold a valid X-Session-Token, since
    /// [JoinSearch] is what authenticates the WebSocket session.
    suspend fun connect(slug: String, sessionToken: String): UUID =
        withContext(Dispatchers.IO) {
            disconnect()  // tear down any prior connection

            val url = AppConfig.API_BASE_URL.trimEnd('/') + "/" + AppConfig.HUB_PATH
            val conn = HubConnectionBuilder.create(url)
                .withAccessTokenProvider(Single.defer { Single.just(sessionToken) })
                .withHeader("X-Session-Token", sessionToken)
                .build()

            registerHandlers(conn)
            connection = conn

            conn.start().blockingAwait()
            _events.tryEmit(HubEvent.Connected)

            val result = conn.invoke(
                HubJoinResult::class.java,
                "JoinSearch",
                slug,
                sessionToken,
            ).blockingGet()
            UUID.fromString(result.participantId)
        }

    fun sendPosition(
        lng: Double,
        lat: Double,
        accuracy: Double,
        heading: Double?,
    ) {
        val conn = connection ?: return
        if (conn.connectionState != HubConnectionState.CONNECTED) return
        // headingDegrees? — Java client converts null Kotlin Double? via
        // boxed Double, server tolerates null.
        conn.send("SendPosition", lng, lat, accuracy, heading)
    }

    suspend fun disconnect() = withContext(Dispatchers.IO) {
        val conn = connection ?: return@withContext
        connection = null
        runCatching { conn.stop().blockingAwait() }
    }

    private fun registerHandlers(conn: HubConnection) {
        conn.on("ParticipantJoined", { p: HubParticipant ->
            _events.tryEmit(HubEvent.ParticipantJoined(p.toDomain()))
        }, HubParticipant::class.java)

        conn.on("ParticipantLeft", { id: String ->
            _events.tryEmit(HubEvent.ParticipantLeft(UUID.fromString(id)))
        }, String::class.java)

        conn.on("PositionUpdated", { u: HubPositionUpdate ->
            _events.tryEmit(HubEvent.PositionUpdated(u.toDomain()))
        }, HubPositionUpdate::class.java)

        conn.on("AreaAdded", { a: HubArea ->
            _events.tryEmit(HubEvent.AreaAdded(a.toDomain()))
        }, HubArea::class.java)

        conn.on("AreaRemoved", { id: String ->
            _events.tryEmit(HubEvent.AreaRemoved(UUID.fromString(id)))
        }, String::class.java)

        conn.on("PathStarted", { p: HubPath ->
            _events.tryEmit(HubEvent.PathStarted(p.toDomain()))
        }, HubPath::class.java)

        conn.on("PathUpdated", { p: HubPath ->
            _events.tryEmit(HubEvent.PathUpdated(p.toDomain()))
        }, HubPath::class.java)

        conn.on("PathFinalized", { id: String ->
            _events.tryEmit(HubEvent.PathFinalized(UUID.fromString(id)))
        }, String::class.java)

        conn.on("SearchUpdated", { u: HubSearchUpdated ->
            _events.tryEmit(HubEvent.SearchUpdated(u.toDomain()))
        }, HubSearchUpdated::class.java)

        conn.on("SearchEnded", { slug: String ->
            _events.tryEmit(HubEvent.SearchEnded(slug))
        }, String::class.java)

        conn.onClosed { t ->
            _events.tryEmit(HubEvent.Closed(t))
        }
    }
}
