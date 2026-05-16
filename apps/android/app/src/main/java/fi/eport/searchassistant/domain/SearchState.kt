package fi.eport.searchassistant.domain

import fi.eport.searchassistant.data.api.AreaDto
import fi.eport.searchassistant.data.api.ParticipantDto
import fi.eport.searchassistant.data.api.PathDto
import fi.eport.searchassistant.data.api.PointGeometry
import fi.eport.searchassistant.data.api.PositionUpdateDto
import kotlinx.datetime.Instant
import java.util.UUID

/// Mirror of apps/ios/.../Stores/SearchStore.swift's @Published surface.
/// Single source of truth for everything a [SearchScreen] needs to render.
data class SearchState(
    val slug: String? = null,
    val title: String = "",
    val expiresAt: Instant? = null,
    val center: PointGeometry? = null,
    val defaultZoom: Int = 13,
    val participants: Map<UUID, ParticipantDto> = emptyMap(),
    val areas: Map<UUID, AreaDto> = emptyMap(),
    val paths: Map<UUID, PathDto> = emptyMap(),
    val positions: Map<UUID, PositionUpdateDto> = emptyMap(),
    val me: Me? = null,
    val connectionState: ConnectionState = ConnectionState.Idle,
    val endedRemotely: Boolean = false,
)

data class Me(
    val id: UUID,
    val sessionToken: String,
    val color: String,
    val displayName: String,
)

enum class ConnectionState { Idle, Connecting, Connected, Failed }

/// What the screen should render at a high level — drives the "loading
/// spinner vs error view vs map" switch in [SearchScreen].
sealed interface LoadPhase {
    object Loading : LoadPhase
    object Loaded : LoadPhase
    data class Failed(val message: String) : LoadPhase
}
