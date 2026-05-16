package fi.eport.searchassistant.data.realtime

import fi.eport.searchassistant.data.api.AreaDto
import fi.eport.searchassistant.data.api.ParticipantDto
import fi.eport.searchassistant.data.api.PathDto
import fi.eport.searchassistant.data.api.PositionUpdateDto
import fi.eport.searchassistant.data.api.SearchUpdatedDto
import java.util.UUID

/// One event per ISearchClient method on the .NET hub. Consumed by
/// [SearchViewModel] which mutates [SearchState] accordingly.
sealed interface HubEvent {
    data class ParticipantJoined(val participant: ParticipantDto) : HubEvent
    data class ParticipantLeft(val participantId: UUID) : HubEvent
    data class PositionUpdated(val position: PositionUpdateDto) : HubEvent
    data class AreaAdded(val area: AreaDto) : HubEvent
    data class AreaRemoved(val areaId: UUID) : HubEvent
    data class PathStarted(val path: PathDto) : HubEvent
    data class PathUpdated(val path: PathDto) : HubEvent
    data class PathFinalized(val pathId: UUID) : HubEvent
    data class SearchUpdated(val update: SearchUpdatedDto) : HubEvent
    data class SearchEnded(val slug: String) : HubEvent

    /// Lifecycle signals (not server-emitted but useful for UI).
    object Connected : HubEvent
    object Reconnecting : HubEvent
    object Reconnected : HubEvent
    data class Closed(val cause: Throwable?) : HubEvent
}
