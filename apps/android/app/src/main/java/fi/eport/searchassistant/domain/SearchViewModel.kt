package fi.eport.searchassistant.domain

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import fi.eport.searchassistant.data.api.ApiClient
import fi.eport.searchassistant.data.api.AreaDto
import fi.eport.searchassistant.data.api.ParticipantDto
import fi.eport.searchassistant.data.api.PathDto
import fi.eport.searchassistant.data.api.SearchSnapshotDto
import fi.eport.searchassistant.data.api.httpStatus
import fi.eport.searchassistant.data.recents.RecentSearchesStore
import fi.eport.searchassistant.data.session.SessionStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/// Owns [SearchState] for a single slug. Mirrors the @MainActor
/// SearchStore from the iOS app. Created via a factory because we
/// can't use Hilt and the slug must be passed in at construction time.
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

    init {
        load()
    }

    fun load() {
        _phase.value = LoadPhase.Loading
        viewModelScope.launch {
            try {
                val snap = apiClient.service.getSearch(slug)
                hydrate(snap)
                _phase.value = LoadPhase.Loaded

                // Remember this search on the device so the landing
                // screen can offer it as a quick re-entry next time.
                recentSearchesStore.upsert(
                    slug = slug,
                    title = snap.title,
                    isOwner = sessionStore.ownerToken(slug) != null,
                )
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
