package fi.eport.searchassistant.ui.search

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
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
import com.google.maps.android.compose.rememberCameraPositionState

/// Helsinki fallback — same as iOS.
private val FallbackCenter = LatLng(60.17, 24.94)

@Composable
fun SearchMap(
    initialCenter: LatLng?,
    initialZoom: Int,
    modifier: Modifier = Modifier,
) {
    val center = initialCenter ?: FallbackCenter
    val cameraPositionState: CameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(center, initialZoom.toFloat())
    }
    // Lazily reseat the camera if the initialCenter prop arrives later
    // (parent hasn't loaded snapshot.center when first rendered).
    var seated by remember { mutableStateOf(initialCenter != null) }
    LaunchedEffect(initialCenter) {
        if (!seated && initialCenter != null) {
            cameraPositionState.position =
                CameraPosition.fromLatLngZoom(initialCenter, initialZoom.toFloat())
            seated = true
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
    )
}
