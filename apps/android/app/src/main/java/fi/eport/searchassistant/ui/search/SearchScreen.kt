package fi.eport.searchassistant.ui.search

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.FiberManualRecord
import androidx.compose.material.icons.filled.LocationOff
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.RadioButtonChecked
import androidx.compose.material.icons.filled.SettingsApplications
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.android.gms.maps.model.LatLng
import fi.eport.searchassistant.AppContainer
import fi.eport.searchassistant.domain.ConnectionState
import fi.eport.searchassistant.domain.LoadPhase
import fi.eport.searchassistant.domain.SearchViewModel
import fi.eport.searchassistant.location.LocationService
import fi.eport.searchassistant.util.toComposeColor
import kotlinx.coroutines.flow.collect

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchScreen(
    slug: String,
    container: AppContainer,
    onBack: () -> Unit,
) {
    val viewModel: SearchViewModel = viewModel(
        key = slug,
        factory = SearchViewModel.Factory(
            slug = slug,
            apiClient = container.apiClient,
            sessionStore = container.sessionStore,
            recentSearchesStore = container.recentSearchesStore,
        ),
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    val phase by viewModel.phase.collectAsStateWithLifecycle()
    val needsJoin by viewModel.needsJoin.collectAsStateWithLifecycle()
    val joinError by viewModel.joinError.collectAsStateWithLifecycle()

    val context = LocalContext.current
    val locationController = container.locationController
    val isWatching by locationController.isWatching.collectAsStateWithLifecycle()
    val locationError by locationController.lastError.collectAsStateWithLifecycle()
    val isRecording by viewModel.isRecording.collectAsStateWithLifecycle()
    val recordError by viewModel.recordError.collectAsStateWithLifecycle()

    // Feed fixes from the service into the VM. The flow keeps emitting
    // while the service runs; the LaunchedEffect ends when the screen
    // leaves composition, which is also when LocationService.stop()
    // gets called downstream.
    LaunchedEffect(viewModel) {
        locationController.fixes.collect { fix ->
            viewModel.handleFix(fix)
        }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { results ->
        val granted = results[Manifest.permission.ACCESS_FINE_LOCATION] == true
            || results[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        if (granted) LocationService.start(context)
    }

    fun toggleShareLocation() {
        if (isWatching) {
            LocationService.stop(context)
        } else {
            val finePermission = ContextCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_FINE_LOCATION
            )
            if (finePermission == PackageManager.PERMISSION_GRANTED) {
                LocationService.start(context)
            } else {
                permissionLauncher.launch(arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                ))
            }
        }
    }

    fun toggleRecording() {
        if (isRecording) {
            viewModel.stopRecording()
        } else {
            // Path recording needs fixes; auto-enable Share Location if
            // it's off so the user doesn't have to flip two toggles.
            if (!isWatching) {
                val finePermission = ContextCompat.checkSelfPermission(
                    context, Manifest.permission.ACCESS_FINE_LOCATION
                )
                if (finePermission == PackageManager.PERMISSION_GRANTED) {
                    LocationService.start(context)
                } else {
                    permissionLauncher.launch(arrayOf(
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION,
                    ))
                    // User will see the prompt; recording starts on
                    // their next tap once permission is granted.
                    return
                }
            }
            viewModel.startRecording()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                title = {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                state.title.ifEmpty { "Search" },
                                fontWeight = FontWeight.SemiBold,
                                maxLines = 1,
                            )
                            Spacer(Modifier.width(6.dp))
                            ConnectionDot(state.connectionState)
                        }
                        state.me?.let { me ->
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(4.dp),
                            ) {
                                Box(
                                    Modifier.size(6.dp).clip(CircleShape)
                                        .background(me.color.toComposeColor())
                                )
                                Text(
                                    me.displayName,
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 1,
                                )
                            }
                        }
                    }
                },
                actions = {
                    IconButton(onClick = { /* ShareSheet — step 12 */ }) {
                        Icon(Icons.Filled.IosShare, contentDescription = "Share")
                    }
                    val isOwner = container.sessionStore.ownerToken(slug) != null
                    if (isOwner) {
                        IconButton(onClick = { /* Manage — step 12 */ }) {
                            Icon(Icons.Filled.SettingsApplications,
                                contentDescription = "Manage")
                        }
                    }
                },
                // Transparent so the map shows under it (matches the iOS
                // .toolbarBackground(.hidden) change from late iOS work).
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent,
                ),
            )
        },
        containerColor = Color.Transparent,
    ) { padding ->
        Box(Modifier.fillMaxSize()) {
            // Map fills the entire screen, including under the top bar.
            SearchMap(
                initialCenter = state.center?.let { LatLng(it.lat, it.lng) },
                initialZoom = state.defaultZoom,
                positions = state.positions,
                participants = state.participants,
                areas = state.areas,
                paths = state.paths,
                modifier = Modifier.fillMaxSize(),
            )
            // Loading + error overlays respect the scaffold padding so
            // they sit below the top bar.
            when (val p = phase) {
                LoadPhase.Loading -> {
                    Box(
                        Modifier.fillMaxSize().padding(padding),
                        contentAlignment = Alignment.Center,
                    ) { CircularProgressIndicator() }
                }
                is LoadPhase.Failed -> {
                    Surface(
                        modifier = Modifier
                            .padding(padding)
                            .padding(24.dp),
                        shape = RoundedCornerShape(12.dp),
                        tonalElevation = 4.dp,
                    ) {
                        Column(Modifier.padding(20.dp)) {
                            Text("Couldn't load search",
                                style = MaterialTheme.typography.titleMedium)
                            Spacer(Modifier.height(4.dp))
                            Text(p.message,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
                LoadPhase.Loaded -> Unit
            }

            // Floating chips, top-right under the toolbar.
            Row(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(padding)
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                RecordChip(
                    isRecording = isRecording,
                    enabled = state.me != null,
                    onToggle = { toggleRecording() },
                )
                ShareLocationChip(
                    isWatching = isWatching,
                    enabled = state.me != null,
                    onToggle = { toggleShareLocation() },
                )
            }

            // Bottom error toast for permission failures, path-flush
            // errors, etc.
            val bottomMsg = recordError ?: locationError
            bottomMsg?.let { msg ->
                Surface(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(20.dp),
                    tonalElevation = 4.dp,
                    shape = RoundedCornerShape(20.dp),
                    color = MaterialTheme.colorScheme.errorContainer,
                ) {
                    Text(
                        msg,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                        color = MaterialTheme.colorScheme.onErrorContainer,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        }

        if (needsJoin) {
            JoinSheet(
                searchTitle = state.title.ifEmpty { "Search" },
                joinError = joinError,
                onJoin = { viewModel.join(it) },
                onCancel = { viewModel.cancelJoin() },
            )
        }
    }
}

@Composable
private fun RecordChip(
    isRecording: Boolean,
    enabled: Boolean,
    onToggle: () -> Unit,
) {
    AssistChip(
        onClick = onToggle,
        enabled = enabled,
        label = { Text(if (isRecording) "Recording" else "Record") },
        leadingIcon = {
            Icon(
                if (isRecording) Icons.Filled.RadioButtonChecked
                else Icons.Filled.FiberManualRecord,
                contentDescription = null,
                tint = if (isRecording) MaterialTheme.colorScheme.error
                else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        },
        colors = if (isRecording)
            AssistChipDefaults.assistChipColors(
                containerColor = MaterialTheme.colorScheme.errorContainer,
                labelColor = MaterialTheme.colorScheme.onErrorContainer,
            )
        else AssistChipDefaults.assistChipColors(),
    )
}

@Composable
private fun ShareLocationChip(
    isWatching: Boolean,
    enabled: Boolean,
    onToggle: () -> Unit,
) {
    AssistChip(
        onClick = onToggle,
        enabled = enabled,
        label = { Text(if (isWatching) "Sharing" else "Share location") },
        leadingIcon = {
            Icon(
                if (isWatching) Icons.Filled.LocationOn else Icons.Filled.LocationOff,
                contentDescription = null,
            )
        },
        colors = if (isWatching)
            AssistChipDefaults.assistChipColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer,
                labelColor = MaterialTheme.colorScheme.onPrimaryContainer,
                leadingIconContentColor = MaterialTheme.colorScheme.onPrimaryContainer,
            )
        else AssistChipDefaults.assistChipColors(),
    )
}

@Composable
private fun ConnectionDot(state: ConnectionState) {
    val color = when (state) {
        ConnectionState.Connected -> Color(0xFF22C55E)
        ConnectionState.Connecting -> Color(0xFFF59E0B)
        ConnectionState.Failed -> Color(0xFFEF4444)
        ConnectionState.Idle -> Color.Transparent
    }
    Box(
        Modifier.size(8.dp).clip(CircleShape).background(color)
    )
}
