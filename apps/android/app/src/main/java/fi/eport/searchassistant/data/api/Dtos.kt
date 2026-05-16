package fi.eport.searchassistant.data.api

import kotlinx.datetime.Instant
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeFormatterBuilder
import java.time.temporal.ChronoField
import java.util.UUID

// Mirrors apps/ios/SearchAssistant/Models/ApiTypes.swift.
// Server returns camelCase JSON with .NET-style ISO 8601 timestamps
// including 7-digit fractional seconds and "+00:00" offsets, e.g.
// "2026-05-16T08:25:50.2578890+00:00". The serializer below accepts both
// fractional + plain forms.

// MARK: - Serializers

/// Accepts .NET's 7-digit fractional ISO-8601 ("…T08:25:50.2578890+00:00")
/// as well as the plain "…T08:25:50+00:00" form. Emits the fractional form
/// so round-trips don't lose precision.
object InstantSerializer : KSerializer<Instant> {
    private val parseFormatter: DateTimeFormatter = DateTimeFormatterBuilder()
        .append(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
        .optionalStart()
        .appendFraction(ChronoField.NANO_OF_SECOND, 0, 9, true)
        .optionalEnd()
        .appendOffsetId()
        .toFormatter()

    private val emitFormatter: DateTimeFormatter = DateTimeFormatter.ISO_OFFSET_DATE_TIME

    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("Instant", PrimitiveKind.STRING)

    override fun deserialize(decoder: Decoder): Instant {
        val raw = decoder.decodeString()
        // OffsetDateTime accepts both fractional + plain ISO forms.
        val odt = OffsetDateTime.parse(raw, parseFormatter)
        return Instant.fromEpochMilliseconds(odt.toInstant().toEpochMilli())
    }

    override fun serialize(encoder: Encoder, value: Instant) {
        val odt = OffsetDateTime.ofInstant(
            java.time.Instant.ofEpochMilli(value.toEpochMilliseconds()),
            java.time.ZoneOffset.UTC,
        )
        encoder.encodeString(emitFormatter.format(odt))
    }
}

object UuidSerializer : KSerializer<UUID> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("UUID", PrimitiveKind.STRING)
    override fun deserialize(decoder: Decoder): UUID = UUID.fromString(decoder.decodeString())
    override fun serialize(encoder: Encoder, value: UUID) {
        encoder.encodeString(value.toString())
    }
}

// MARK: - Search lifecycle

@Serializable
data class CreateSearchRequest(
    val title: String,
    val centerLng: Double? = null,
    val centerLat: Double? = null,
    val zoom: Int? = null,
)

@Serializable
data class CreateSearchResponse(
    val slug: String,
    val ownerToken: String,
    val joinUrl: String,
)

@Serializable
data class JoinRequest(val displayName: String)

@Serializable
data class JoinResponse(
    @Serializable(with = UuidSerializer::class) val participantId: UUID,
    val sessionToken: String,
    val color: String,
)

// MARK: - GeoJSON geometries

@Serializable
data class PointGeometry(
    val type: String = "Point",
    val coordinates: List<Double>,  // [lng, lat]
) {
    val lng: Double get() = coordinates[0]
    val lat: Double get() = coordinates[1]

    companion object {
        fun of(lng: Double, lat: Double) = PointGeometry(coordinates = listOf(lng, lat))
    }
}

@Serializable
data class PolygonGeometry(
    val type: String = "Polygon",
    val coordinates: List<List<List<Double>>>,  // rings → [lng, lat]
) {
    companion object {
        fun ofRing(ring: List<List<Double>>) =
            PolygonGeometry(coordinates = listOf(ring))
    }
}

@Serializable
data class LineStringGeometry(
    val type: String = "LineString",
    val coordinates: List<List<Double>>,  // [lng, lat] points
)

// MARK: - Snapshot DTOs

@Serializable
data class ParticipantDto(
    @Serializable(with = UuidSerializer::class) val id: UUID,
    val displayName: String,
    val color: String,
    @Serializable(with = InstantSerializer::class) val joinedAt: Instant,
    @Serializable(with = InstantSerializer::class) val lastSeenAt: Instant,
    val lastPosition: PointGeometry? = null,
)

@Serializable
data class AreaDto(
    @Serializable(with = UuidSerializer::class) val id: UUID,
    @Serializable(with = UuidSerializer::class) val createdByParticipantId: UUID,
    @Serializable(with = InstantSerializer::class) val createdAt: Instant,
    val geometry: PolygonGeometry,
    val title: String? = null,
    val color: String? = null,
)

@Serializable
data class PathDto(
    @Serializable(with = UuidSerializer::class) val id: UUID,
    @Serializable(with = UuidSerializer::class) val participantId: UUID,
    @Serializable(with = InstantSerializer::class) val startedAt: Instant,
    @Serializable(with = InstantSerializer::class) val endedAt: Instant? = null,
    val geometry: LineStringGeometry,
)

@Serializable
data class SearchSnapshotDto(
    val slug: String,
    val title: String,
    @Serializable(with = InstantSerializer::class) val createdAt: Instant,
    @Serializable(with = InstantSerializer::class) val expiresAt: Instant? = null,
    val center: PointGeometry? = null,
    val defaultZoom: Int,
    val participants: List<ParticipantDto>,
    val areas: List<AreaDto>,
    val paths: List<PathDto>,
)

// MARK: - Hub events

@Serializable
data class PositionUpdateDto(
    @Serializable(with = UuidSerializer::class) val participantId: UUID,
    val lng: Double,
    val lat: Double,
    val accuracyMeters: Double,
    val headingDegrees: Double? = null,
    @Serializable(with = InstantSerializer::class) val recordedAt: Instant,
)

@Serializable
data class SearchUpdatedDto(
    val title: String,
    @Serializable(with = InstantSerializer::class) val expiresAt: Instant? = null,
)

// MARK: - Area / path requests

@Serializable
data class AddAreaRequest(
    val geometry: PolygonGeometry,
    val title: String? = null,
    val color: String? = null,
)

@Serializable
data class StartPathRequest(val points: List<List<Double>>)

@Serializable
data class UpdatePathRequest(
    val points: List<List<Double>>? = null,
    val finalize: Boolean? = null,
)

// MARK: - Manage (owner-only)

@Serializable
data class UpdateSearchRequest(
    val title: String? = null,
    @Serializable(with = InstantSerializer::class) val expiresAt: Instant? = null,
)

@Serializable
data class UpdateSearchResponse(
    val title: String,
    @Serializable(with = InstantSerializer::class) val expiresAt: Instant? = null,
)

@Serializable
data class ClearPathsResponse(val cleared: Int)
