package fi.eport.searchassistant.domain

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.google.android.gms.maps.model.LatLng
import fi.eport.searchassistant.data.api.AddAreaRequest
import fi.eport.searchassistant.data.api.ApiClient
import fi.eport.searchassistant.data.api.AreaDto
import fi.eport.searchassistant.data.api.JoinRequest
import fi.eport.searchassistant.data.api.ParticipantDto
import fi.eport.searchassistant.data.api.PathDto
import fi.eport.searchassistant.data.api.PolygonGeometry
import fi.eport.searchassistant.data.api.SearchSnapshotDto
import fi.eport.searchassistant.data.api.StartPathRequest
import fi.eport.searchassistant.data.api.UpdatePathRequest
import fi.eport.searchassistant.data.api.httpStatus
import fi.eport.searchassistant.data.realtime.HubEvent
import fi.eport.searchassistant.data.realtime.SignalRService
import fi.eport.searchassistant.data.recents.RecentSearchesStore
import fi.eport.searchassistant.data.session.SessionStore
import fi.eport.searchassistant.location.GeoFix
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.datetime.Clock
import java.util.UUID

/// Owns [SearchState] for a single slug. Mirrors the @MainActor
/// SearchStore from the iOS app. Created via a factory because the
/// slug must be passed in at construction time.
class SearchViewModel(
    private val slug: String,
    private val apiClient: ApiClient,
    private val sessionStore: SessionStore,
    private val recentSearchesStore: RecentSearchesStore,
) : ViewModel() {

    private val _state = MutableStateFlow(SearchState(slug = slug))
    val state: StateFlow<SearchState> = _state.asStateFlow()

    private val _phase = MutableStateFlow<LoadPhase>(LoadPhase.Loading)
    val phase: StateFlow<LoadPhase> = _phase.asStateFlow()

    private val _needsJoin = MutableStateFlow(false)
    val needsJoin: StateFlow<Boolean> = _needsJoin.asStateFlow()

    private val _joinError = MutableStateFlow<String?>(null)
    val joinError: StateFlow<String?> = _joinError.asStateFlow()

    private val signalR = SignalRService()
    private var eventsJob: Job? = null

    init {
        load()
        eventsJob = viewModelScope.launch {
            signalR.events.collect { handle(it) }
        }
    }

    // MARK: - Load + identity --------------------------------------

    fun load() {
        _phase.value = LoadPhase.Loading
        viewModelScope.launch {
            try {
                val snap = apiClient.service.getSearch(slug)
                hydrate(snap)
                _phase.value = LoadPhase.Loaded

                recentSearchesStore.upsert(
                    slug = slug,
                    title = snap.title,
                    isOwner = sessionStore.ownerToken(slug) != null,
                )

                resolveIdentityAndConnect()
            } catch (t: Throwable) {
                val message = when (t.httpStatus) {
                    404 -> {
                        recentSearchesStore.remove(slug)
                        "This search doesn't exist. It may have expired."
                    }
                    null -> t.localizedMessage ?: t.javaClass.simpleName
                    else -> "HTTP ${t.httpStatus} loading search."
                }
                _phase.value = LoadPhase.Failed(message)
            }
        }
    }

    private suspend fun resolveIdentityAndConnect() {
        val token = sessionStore.sessionToken(slug)
        if (token != null) {
            try {
                val me = apiClient.service.me(slug, token)
                _state.update {
                    it.copy(me = Me(me.id, token, me.color, me.displayName))
                }
                connectHub()
                return
            } catch (t: Throwable) {
                if (t.httpStatus == 401) {
                    sessionStore.clearSessionToken(slug)
                }
                // Else: soft fail. Fall through to join prompt.
            }
        }
        _needsJoin.value = true
    }

    fun join(displayName: String) {
        _joinError.value = null
        viewModelScope.launch {
            try {
                val resp = apiClient.service.joinSearch(
                    slug, JoinRequest(displayName = displayName))
                sessionStore.setSessionToken(resp.sessionToken, slug)
                val me = Me(resp.participantId, resp.sessionToken,
                    resp.color, displayName)
                // Optimistically add ourselves to the participant list
                // pre-snapshot so the UI shows the "(you)" indicator
                // before SignalR re-broadcasts.
                _state.update {
                    it.copy(
                        me = me,
                        participants = it.participants + (resp.participantId to
                            ParticipantDto(
                                id = resp.participantId,
                                displayName = displayName,
                                color = resp.color,
                                joinedAt = Clock.System.now(),
                                lastSeenAt = Clock.System.now(),
                                lastPosition = null,
                            )),
                    )
                }
                _needsJoin.value = false
                connectHub()
            } catch (t: Throwable) {
                _joinError.value = t.httpStatus?.let { "Couldn't join (HTTP $it)." }
                    ?: t.localizedMessage ?: t.javaClass.simpleName
            }
        }
    }

    fun cancelJoin() {
        _needsJoin.value = false
    }

    private fun connectHub() {
        val token = state.value.me?.sessionToken ?: return
        viewModelScope.launch {
            try {
                _state.update { it.copy(connectionState = ConnectionState.Connecting) }
                signalR.connect(slug, token)
                _state.update { it.copy(connectionState = ConnectionState.Connected) }
            } catch (t: Throwable) {
                _state.update { it.copy(connectionState = ConnectionState.Failed) }
            }
        }
    }

    fun sendPosition(lng: Double, lat: Double, accuracy: Double, heading: Double?) {
        signalR.sendPosition(lng, lat, accuracy, heading)
    }

    // MARK: - Location fix handling --------------------------------

    /// Client-side throttle to keep us from spamming the hub if the
    /// device emits faster. The server already rate-limits ~700 ms
    /// per participant; this is just bandwidth manners.
    private var lastSentEpochMs: Long = 0
    private val minSendIntervalMs = 1_000L

    fun handleFix(fix: GeoFix) {
        val now = kotlinx.datetime.Clock.System.now().toEpochMilliseconds()
        if (now - lastSentEpochMs >= minSendIntervalMs) {
            lastSentEpochMs = now
            signalR.sendPosition(fix.lng, fix.lat, fix.accuracyMeters, fix.headingDegrees)
        }
        // Tee fixes into the path recorder; no-op when not recording.
        if (_isRecording.value) {
            synchronized(pathBuffer) {
                pathBuffer.add(listOf(fix.lng, fix.lat))
            }
        }
    }

    // MARK: - Path recording ---------------------------------------

    private val _isRecording = MutableStateFlow(false)
    val isRecording: StateFlow<Boolean> = _isRecording.asStateFlow()

    private val _recordError = MutableStateFlow<String?>(null)
    val recordError: StateFlow<String?> = _recordError.asStateFlow()

    private val pathBuffer = ArrayDeque<List<Double>>()
    private var recordingPathId: UUID? = null
    private var recordingJob: Job? = null
    private var flushInFlight = false
    private val pathFlushMs = 5_000L

    fun startRecording() {
        if (_isRecording.value) return
        if (state.value.me == null) return
        _isRecording.value = true
        _recordError.value = null
        recordingPathId = null
        synchronized(pathBuffer) { pathBuffer.clear() }
        recordingJob = viewModelScope.launch {
            while (true) {
                delay(pathFlushMs)
                flushPath()
            }
        }
    }

    fun stopRecording() {
        if (!_isRecording.value) return
        _isRecording.value = false
        val job = recordingJob
        recordingJob = null
        viewModelScope.launch {
            job?.cancel()
            // Final drain + finalize.
            flushPath()
            val pid = recordingPathId
            val token = state.value.me?.sessionToken
            if (pid != null && token != null) {
                runCatching {
                    apiClient.service.updatePath(
                        slug, pid,
                        UpdatePathRequest(finalize = true),
                        token,
                    )
                }
            }
            recordingPathId = null
        }
    }

    // MARK: - Participant focus ------------------------------------

    /// When set, the map animates to follow this participant's position.
    /// Stays set across subsequent PositionUpdated events so the map
    /// "follows" the focused participant; cleared by tapping another
    /// or by tapping themselves with no position.
    private val _focusedParticipantId = MutableStateFlow<UUID?>(null)
    val focusedParticipantId: StateFlow<UUID?> = _focusedParticipantId.asStateFlow()

    fun focusOnParticipant(id: UUID?) {
        _focusedParticipantId.value = id
    }

    // MARK: - Drawing ---------------------------------------------

    private val _drawing = MutableStateFlow(false)
    val drawing: StateFlow<Boolean> = _drawing.asStateFlow()

    private val _draftPoints = MutableStateFlow<List<LatLng>>(emptyList())
    val draftPoints: StateFlow<List<LatLng>> = _draftPoints.asStateFlow()

    private val _areaSaveError = MutableStateFlow<String?>(null)
    val areaSaveError: StateFlow<String?> = _areaSaveError.asStateFlow()

    private val _areaSheetShown = MutableStateFlow(false)
    val areaSheetShown: StateFlow<Boolean> = _areaSheetShown.asStateFlow()

    fun toggleDrawing() {
        if (_drawing.value) {
            cancelDrawing()
        } else {
            _areaSaveError.value = null
            _draftPoints.value = emptyList()
            _drawing.value = true
        }
    }

    fun cancelDrawing() {
        _drawing.value = false
        _draftPoints.value = emptyList()
        _areaSheetShown.value = false
        _areaSaveError.value = null
    }

    fun appendDraftPoint(coord: LatLng) {
        _draftPoints.value = _draftPoints.value + coord
    }

    fun undoLastDraftPoint() {
        val current = _draftPoints.value
        if (current.isNotEmpty()) _draftPoints.value = current.dropLast(1)
    }

    fun openAreaSheet() {
        if (_draftPoints.value.size >= 3) {
            _areaSaveError.value = null
            _areaSheetShown.value = true
        }
    }

    fun dismissAreaSheet() {
        _areaSheetShown.value = false
        _draftPoints.value = emptyList()
        _drawing.value = false
    }

    fun commitArea(title: String?, colorHex: String) {
        val pts = _draftPoints.value
        if (pts.size < 3) {
            _areaSaveError.value = "Need at least 3 points to make an area."
            _areaSheetShown.value = false
            return
        }
        val token = state.value.me?.sessionToken
        if (token == null) {
            _areaSaveError.value = "You need to be joined to add areas."
            _areaSheetShown.value = false
            return
        }
        // GeoJSON ring is [lng, lat] and must close (first == last).
        val ring = pts.map { listOf(it.longitude, it.latitude) }.toMutableList()
        ring.add(ring.first())
        val geometry = PolygonGeometry.ofRing(ring)

        viewModelScope.launch {
            try {
                apiClient.service.addArea(
                    slug,
                    AddAreaRequest(geometry = geometry, title = title, color = colorHex),
                    token,
                )
                // Server broadcasts AreaAdded — store will reflect it.
                _areaSheetShown.value = false
                _drawing.value = false
                _draftPoints.value = emptyList()
                _areaSaveError.value = null
            } catch (t: Throwable) {
                _areaSaveError.value = t.httpStatus
                    ?.let { "Couldn't save area (HTTP $it)." }
                    ?: t.localizedMessage ?: "Network error."
                _areaSheetShown.value = false
            }
        }
    }

    private suspend fun flushPath() {
        if (flushInFlight) return
        val token = state.value.me?.sessionToken ?: return
        val points: List<List<Double>>
        synchronized(pathBuffer) {
            if (pathBuffer.isEmpty()) return
            points = pathBuffer.toList()
            pathBuffer.clear()
        }
        flushInFlight = true
        try {
            if (recordingPathId == null) {
                if (points.size < 2) {
                    // Server requires ≥2 points on the initial POST. Stash
                    // these back for the next flush.
                    synchronized(pathBuffer) {
                        pathBuffer.addAll(0, points)
                    }
                    return
                }
                val dto = apiClient.service.startPath(
                    slug, StartPathRequest(points = points), token)
                recordingPathId = dto.id
            } else {
                apiClient.service.updatePath(
                    slug, recordingPathId!!,
                    UpdatePathRequest(points = points),
                    token,
                )
            }
        } catch (t: Throwable) {
            _recordError.value = t.httpStatus?.let { "Couldn't save path (HTTP $it)." }
                ?: "Network error saving path."
            // Re-insert so the next flush retries.
            synchronized(pathBuffer) {
                pathBuffer.addAll(0, points)
            }
        } finally {
            flushInFlight = false
        }
    }

    // MARK: - Hydrate from REST ------------------------------------

    private fun hydrate(snap: SearchSnapshotDto) {
        _state.update { current ->
            current.copy(
                slug = snap.slug,
                title = snap.title,
                expiresAt = snap.expiresAt,
                center = snap.center,
                defaultZoom = snap.defaultZoom,
                participants = snap.participants.associateBy(ParticipantDto::id),
                areas = snap.areas.associateBy(AreaDto::id),
                paths = snap.paths.associateBy(PathDto::id),
                positions = snap.participants
                    .mapNotNull { p ->
                        p.lastPosition?.let { pos ->
                            p.id to fi.eport.searchassistant.data.api.PositionUpdateDto(
                                participantId = p.id,
                                lng = pos.lng,
                                lat = pos.lat,
                                accuracyMeters = 0.0,
                                headingDegrees = null,
                                recordedAt = p.lastSeenAt,
                            )
                        }
                    }
                    .toMap(),
            )
        }
    }

    // MARK: - Hub event handlers -----------------------------------

    private fun handle(event: HubEvent) {
        when (event) {
            is HubEvent.ParticipantJoined -> upsertParticipant(event.participant)
            is HubEvent.ParticipantLeft -> Unit  // keep in list for v1 (matches web)
            is HubEvent.PositionUpdated -> applyPosition(event.position)
            is HubEvent.AreaAdded -> upsertArea(event.area)
            is HubEvent.AreaRemoved -> removeArea(event.areaId)
            is HubEvent.PathStarted -> upsertPath(event.path)
            is HubEvent.PathUpdated -> upsertPath(event.path)
            is HubEvent.PathFinalized -> finalizePath(event.pathId)
            is HubEvent.SearchUpdated -> _state.update {
                it.copy(title = event.update.title, expiresAt = event.update.expiresAt)
            }
            is HubEvent.SearchEnded -> _state.update { it.copy(endedRemotely = true) }
            HubEvent.Connected -> _state.update {
                it.copy(connectionState = ConnectionState.Connected)
            }
            HubEvent.Reconnecting -> _state.update {
                it.copy(connectionState = ConnectionState.Connecting)
            }
            HubEvent.Reconnected -> _state.update {
                it.copy(connectionState = ConnectionState.Connected)
            }
            is HubEvent.Closed -> _state.update {
                it.copy(connectionState = ConnectionState.Failed)
            }
        }
    }

    private fun upsertParticipant(p: ParticipantDto) {
        _state.update { it.copy(participants = it.participants + (p.id to p)) }
    }

    private fun applyPosition(pos: fi.eport.searchassistant.data.api.PositionUpdateDto) {
        _state.update { current ->
            // Mirror lastSeenAt onto the participant so the UI staleness
            // logic stays in sync with new positions.
            val updatedParticipants = current.participants[pos.participantId]
                ?.let { it.copy(lastSeenAt = pos.recordedAt) }
                ?.let { current.participants + (pos.participantId to it) }
                ?: current.participants
            current.copy(
                positions = current.positions + (pos.participantId to pos),
                participants = updatedParticipants,
            )
        }
    }

    private fun upsertArea(a: AreaDto) {
        _state.update { it.copy(areas = it.areas + (a.id to a)) }
    }

    private fun removeArea(id: UUID) {
        _state.update { it.copy(areas = it.areas - id) }
    }

    private fun upsertPath(p: PathDto) {
        _state.update { it.copy(paths = it.paths + (p.id to p)) }
    }

    private fun finalizePath(id: UUID) {
        _state.update { current ->
            val existing = current.paths[id] ?: return@update current
            current.copy(paths = current.paths + (id to existing.copy(
                endedAt = existing.endedAt ?: Clock.System.now()
            )))
        }
    }

    override fun onCleared() {
        eventsJob?.cancel()
        // disconnect runs on Dispatchers.IO inside SignalRService; we
        // don't await it — onCleared is sync and the OS will drop the
        // socket anyway when the process detaches.
        viewModelScope.launch { signalR.disconnect() }
        super.onCleared()
    }

    class Factory(
        private val slug: String,
        private val apiClient: ApiClient,
        private val sessionStore: SessionStore,
        private val recentSearchesStore: RecentSearchesStore,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            SearchViewModel(slug, apiClient, sessionStore, recentSearchesStore) as T
    }
}
