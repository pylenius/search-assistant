package fi.eport.searchassistant.location

import kotlinx.datetime.Instant

data class GeoFix(
    val lng: Double,
    val lat: Double,
    val accuracyMeters: Double,
    val headingDegrees: Double?,
    val timestamp: Instant,
)
