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
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.CameraPositionState
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapType
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.rememberCameraPositionState
import fi.eport.searchassistant.data.api.ParticipantDto
import fi.eport.searchassistant.data.api.PositionUpdateDto
import kotlinx.coroutines.delay
import kotlinx.datetime.Clock
import java.util.UUID
import kotlin.time.Duration.Companion.seconds

/// Helsinki fallback — same as iOS.
private val FallbackCenter = LatLng(60.17, 24.94)

/// How long without an update before a marker fades.
private const val STALE_AFTER_SECONDS = 5L * 60

@Composable
fun SearchMap(
    initialCenter: LatLng?,
    initialZoom: Int,
    positions: Map<UUID, PositionUpdateDto>,
    participants: Map<UUID, ParticipantDto>,
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

    // Tick a "now" state every 15 s so marker staleness re-evaluates
    // without depending on new PositionUpdated events.
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
        positions.forEach { (id, pos) ->
            val p = participants[id]
            val color = p?.color ?: "#888888"
            val stale = (nowEpoch - pos.recordedAt.epochSeconds) > STALE_AFTER_SECONDS
            // MarkerState is remembered by id+coord, so identical
            // back-to-back position updates won't recreate it.
            val markerState = remember(id) {
                MarkerState(position = LatLng(pos.lat, pos.lng))
            }
            // Keep the marker's position in sync when the participant moves.
            LaunchedEffect(pos.lat, pos.lng) {
                markerState.position = LatLng(pos.lat, pos.lng)
            }
            // anchor (0.5, 0.5) centres the circle bitmap on the
            // coordinate; the default (0.5, 1.0) would hang it off
            // the lat/lng like a pin tail.
            Marker(
                state = markerState,
                icon = MarkerBitmaps.circle(color, stale),
                anchor = androidx.compose.ui.geometry.Offset(0.5f, 0.5f),
                title = p?.displayName,
            )
        }
    }
}
