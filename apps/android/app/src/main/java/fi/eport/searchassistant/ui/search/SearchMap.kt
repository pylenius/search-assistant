package fi.eport.searchassistant.ui.search

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.Dash
import com.google.android.gms.maps.model.Gap
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.CameraPositionState
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapType
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.Polygon
import com.google.maps.android.compose.Polyline
import com.google.maps.android.compose.rememberCameraPositionState
import fi.eport.searchassistant.data.api.AreaDto
import fi.eport.searchassistant.data.api.ParticipantDto
import fi.eport.searchassistant.data.api.PathDto
import fi.eport.searchassistant.data.api.PositionUpdateDto
import fi.eport.searchassistant.util.toComposeColor
import kotlinx.coroutines.delay
import kotlinx.datetime.Clock
import java.util.UUID
import kotlin.time.Duration.Companion.seconds
import androidx.compose.ui.graphics.Color as ComposeColor

/// Helsinki fallback — same as iOS.
private val FallbackCenter = LatLng(60.17, 24.94)

/// How long without an update before a marker fades.
private const val STALE_AFTER_SECONDS = 5L * 60

private const val FALLBACK_COLOR = "#888888"

@Composable
fun SearchMap(
    initialCenter: LatLng?,
    initialZoom: Int,
    positions: Map<UUID, PositionUpdateDto>,
    participants: Map<UUID, ParticipantDto>,
    areas: Map<UUID, AreaDto>,
    paths: Map<UUID, PathDto>,
    modifier: Modifier = Modifier,
) {
    val center = initialCenter ?: FallbackCenter
    val cameraPositionState: CameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(center, initialZoom.toFloat())
    }
    var seated by remember { mutableStateOf(initialCenter != null) }
    LaunchedEffect(initialCenter) {
        if (!seated && initialCenter != null) {
            cameraPositionState.position =
                CameraPosition.fromLatLngZoom(initialCenter, initialZoom.toFloat())
            seated = true
        }
    }

    val nowEpoch by produceState(initialValue = Clock.System.now().epochSeconds) {
        while (true) {
            value = Clock.System.now().epochSeconds
            delay(15.seconds)
        }
    }

    GoogleMap(
        modifier = modifier.fillMaxSize(),
        cameraPositionState = cameraPositionState,
        properties = MapProperties(
            mapType = MapType.NORMAL,
            isMyLocationEnabled = false,
        ),
        uiSettings = MapUiSettings(
            zoomControlsEnabled = false,
            compassEnabled = true,
            myLocationButtonEnabled = false,
            mapToolbarEnabled = false,
        ),
    ) {
        // Areas first so they sit under paths + markers.
        areas.values.forEach { area ->
            val outer = area.geometry.coordinates.firstOrNull() ?: return@forEach
            val points = outer.map { LatLng(it[1], it[0]) }
            // Per-area override → creator color → gray. Same fallback
            // chain as iOS diffAreas.
            val hex = area.color
                ?: participants[area.createdByParticipantId]?.color
                ?: FALLBACK_COLOR
            val color = hex.toComposeColor()
            Polygon(
                points = points,
                strokeColor = color,
                fillColor = color.copy(alpha = 0.18f),
                strokeWidth = 4f,
            )
        }

        // Paths.
        paths.values.forEach { path ->
            val coords = path.geometry.coordinates
            if (coords.size < 2) return@forEach
            val points = coords.map { LatLng(it[1], it[0]) }
            val hex = participants[path.participantId]?.color ?: FALLBACK_COLOR
            val color = hex.toComposeColor()
            val finalized = path.endedAt != null
            Polyline(
                points = points,
                color = color,
                width = 8f,
                jointType = com.google.android.gms.maps.model.JointType.ROUND,
                startCap = com.google.android.gms.maps.model.RoundCap(),
                endCap = com.google.android.gms.maps.model.RoundCap(),
                pattern = if (!finalized) listOf(Dash(24f), Gap(16f)) else null,
            )
        }

        // Markers above everything.
        positions.forEach { (id, pos) ->
            val p = participants[id]
            val color = p?.color ?: FALLBACK_COLOR
            val stale = (nowEpoch - pos.recordedAt.epochSeconds) > STALE_AFTER_SECONDS
            val markerState = remember(id) {
                MarkerState(position = LatLng(pos.lat, pos.lng))
            }
            LaunchedEffect(pos.lat, pos.lng) {
                markerState.position = LatLng(pos.lat, pos.lng)
            }
            Marker(
                state = markerState,
                icon = MarkerBitmaps.circle(color, stale),
                anchor = androidx.compose.ui.geometry.Offset(0.5f, 0.5f),
                title = p?.displayName,
            )
        }
    }
}
