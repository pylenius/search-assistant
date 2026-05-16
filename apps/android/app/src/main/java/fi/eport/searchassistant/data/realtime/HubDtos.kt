package fi.eport.searchassistant.data.realtime

import fi.eport.searchassistant.data.api.AreaDto
import fi.eport.searchassistant.data.api.LineStringGeometry
import fi.eport.searchassistant.data.api.ParticipantDto
import fi.eport.searchassistant.data.api.PathDto
import fi.eport.searchassistant.data.api.PointGeometry
import fi.eport.searchassistant.data.api.PolygonGeometry
import fi.eport.searchassistant.data.api.PositionUpdateDto
import fi.eport.searchassistant.data.api.SearchUpdatedDto
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeFormatterBuilder
import java.time.temporal.ChronoField
import java.util.UUID
import kotlinx.datetime.Instant

// SignalR-Java's JsonHubProtocol uses Gson with a fixed config — we
// can't slot kotlinx-serialization adapters in. Easiest robust path:
// define a parallel set of plain Gson-friendly DTOs for hub payloads
// (Strings for dates + UUIDs, no kotlinx annotations) and convert to
// the domain types on receive.

internal data class HubPoint(
    val type: String? = null,
    val coordinates: List<Double> = emptyList(),
)

internal data class HubPolygon(
    val type: String? = null,
    val coordinates: List<List<List<Double>>> = emptyList(),
)

internal data class HubLineString(
    val type: String? = null,
    val coordinates: List<List<Double>> = emptyList(),
)

internal data class HubParticipant(
    val id: String,
    val displayName: String,
    val color: String,
    val joinedAt: String,
    val lastSeenAt: String,
    val lastPosition: HubPoint? = null,
)

internal data class HubArea(
    val id: String,
    val createdByParticipantId: String,
    val createdAt: String,
    val geometry: HubPolygon,
    val title: String? = null,
    val color: String? = null,
)

internal data class HubPath(
    val id: String,
    val participantId: String,
    val startedAt: String,
    val endedAt: String? = null,
    val geometry: HubLineString,
)

internal data class HubPositionUpdate(
    val participantId: String,
    val lng: Double,
    val lat: Double,
    val accuracyMeters: Double,
    val headingDegrees: Double? = null,
    val recordedAt: String,
)

internal data class HubSearchUpdated(
    val title: String,
    val expiresAt: String? = null,
)

internal data class HubJoinResult(
    val participantId: String,
    val searchId: String,
)

// MARK: - Converters

internal fun parseInstant(raw: String): Instant {
    val odt = OffsetDateTime.parse(raw, INSTANT_PARSER)
    return Instant.fromEpochMilliseconds(odt.toInstant().toEpochMilli())
}

private val INSTANT_PARSER: DateTimeFormatter = DateTimeFormatterBuilder()
    .append(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
    .optionalStart()
    .appendFraction(ChronoField.NANO_OF_SECOND, 0, 9, true)
    .optionalEnd()
    .appendOffsetId()
    .toFormatter()

internal fun HubPoint.toDomain() =
    PointGeometry(type = type ?: "Point", coordinates = coordinates)

internal fun HubPolygon.toDomain() =
    PolygonGeometry(type = type ?: "Polygon", coordinates = coordinates)

internal fun HubLineString.toDomain() =
    LineStringGeometry(type = type ?: "LineString", coordinates = coordinates)

internal fun HubParticipant.toDomain() = ParticipantDto(
    id = UUID.fromString(id),
    displayName = displayName,
    color = color,
    joinedAt = parseInstant(joinedAt),
    lastSeenAt = parseInstant(lastSeenAt),
    lastPosition = lastPosition?.toDomain(),
)

internal fun HubArea.toDomain() = AreaDto(
    id = UUID.fromString(id),
    createdByParticipantId = UUID.fromString(createdByParticipantId),
    createdAt = parseInstant(createdAt),
    geometry = geometry.toDomain(),
    title = title,
    color = color,
)

internal fun HubPath.toDomain() = PathDto(
    id = UUID.fromString(id),
    participantId = UUID.fromString(participantId),
    startedAt = parseInstant(startedAt),
    endedAt = endedAt?.let { parseInstant(it) },
    geometry = geometry.toDomain(),
)

internal fun HubPositionUpdate.toDomain() = PositionUpdateDto(
    participantId = UUID.fromString(participantId),
    lng = lng,
    lat = lat,
    accuracyMeters = accuracyMeters,
    headingDegrees = headingDegrees,
    recordedAt = parseInstant(recordedAt),
)

internal fun HubSearchUpdated.toDomain() = SearchUpdatedDto(
    title = title,
    expiresAt = expiresAt?.let { parseInstant(it) },
)
