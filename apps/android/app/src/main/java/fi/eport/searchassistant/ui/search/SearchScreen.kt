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
import androidx.compose.material.icons.filled.Done
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.EditNote
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.FiberManualRecord
import androidx.compose.material.icons.filled.LocationOff
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.RadioButtonChecked
import androidx.compose.material.icons.filled.Undo
import androidx.compose.material.icons.filled.SettingsApplications
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
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
    onManage: () -> Unit,
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
    val drawing by viewModel.drawing.collectAsStateWithLifecycle()
    val draftPoints by viewModel.draftPoints.collectAsStateWithLifecycle()
    val areaSheetShown by viewModel.areaSheetShown.collectAsStateWithLifecycle()
    val areaSaveError by viewModel.areaSaveError.collectAsStateWithLifecycle()

    var shareSheetShown by rememberSaveable { mutableStateOf(false) }
    var participantsSheetShown by rememberSaveable { mutableStateOf(false) }

    val focusedParticipantId by viewModel.focusedParticipantId.collectAsStateWithLifecycle()
    val focusTarget = focusedParticipantId?.let { id ->
        state.positions[id]?.let { LatLng(it.lat, it.lng) }
    }

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
                    IconButton(onClick = { shareSheetShown = true }) {
                        Icon(Icons.Filled.IosShare, contentDescription = "Share")
                    }
                    val isOwner = container.sessionStore.ownerToken(slug) != null
                    if (isOwner) {
                        IconButton(onClick = onManage) {
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
                drawing = drawing,
                draftPoints = draftPoints,
                onTapWhileDrawing = { viewModel.appendDraftPoint(it) },
                focusTarget = focusTarget,
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
                DrawChip(
                    drawing = drawing,
                    enabled = state.me != null,
                    onToggle = { viewModel.toggleDrawing() },
                )
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

            if (drawing) {
                DrawingToolbar(
                    pointCount = draftPoints.size,
                    onCancel = { viewModel.cancelDrawing() },
                    onUndo = { viewModel.undoLastDraftPoint() },
                    onFinish = { viewModel.openAreaSheet() },
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 80.dp),
                )
            }

            // Participants FAB (bottom-right). Mirrors the iOS pill.
            FloatingActionButton(
                onClick = { participantsSheetShown = true },
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(end = 16.dp, bottom = 24.dp),
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.onSurface,
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(horizontal = 14.dp),
                ) {
                    Icon(Icons.Filled.Groups, contentDescription = "Participants")
                    Spacer(Modifier.width(6.dp))
                    Text(
                        "${state.participants.size}",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }

            // Bottom error toast for permission failures, path-flush
            // errors, area-save errors, etc.
            val bottomMsg = recordError ?: locationError ?: areaSaveError
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

        if (areaSheetShown) {
            AreaSheet(
                defaultColor = state.me?.color ?: "#3b82f6",
                onSave = { title, color -> viewModel.commitArea(title, color) },
                onCancel = { viewModel.dismissAreaSheet() },
            )
        }

        if (shareSheetShown) {
            ShareSheet(
                slug = slug,
                participantCount = state.participants.size,
                onClose = { shareSheetShown = false },
            )
        }

        if (participantsSheetShown) {
            val now = remember { kotlinx.datetime.Clock.System.now() }
            val staleAfter = 5L * 60  // seconds
            val myId = state.me?.id
            val rows = state.participants.values
                .sortedWith(compareByDescending<fi.eport.searchassistant.data.api.ParticipantDto> {
                    it.id == myId  // me first
                }.thenByDescending { it.lastSeenAt })
                .map { p ->
                    ParticipantRow(
                        id = p.id,
                        displayName = p.displayName,
                        color = p.color,
                        lastSeenAt = p.lastSeenAt,
                        hasPosition = state.positions[p.id] != null,
                        isMe = p.id == myId,
                        isStale = (now.toEpochMilliseconds() - p.lastSeenAt
                            .toEpochMilliseconds()) / 1000 > staleAfter,
                    )
                }
            ParticipantsSheet(
                rows = rows,
                onFocus = { id ->
                    viewModel.focusOnParticipant(id)
                    participantsSheetShown = false
                },
                onClose = { participantsSheetShown = false },
            )
        }
    }
}

@Composable
private fun DrawChip(
    drawing: Boolean,
    enabled: Boolean,
    onToggle: () -> Unit,
) {
    AssistChip(
        onClick = onToggle,
        enabled = enabled,
        label = { Text(if (drawing) "Drawing" else "Draw") },
        leadingIcon = {
            Icon(
                if (drawing) Icons.Filled.EditNote else Icons.Filled.Edit,
                contentDescription = null,
            )
        },
        colors = if (drawing)
            AssistChipDefaults.assistChipColors(
                containerColor = MaterialTheme.colorScheme.tertiaryContainer,
                labelColor = MaterialTheme.colorScheme.onTertiaryContainer,
                leadingIconContentColor = MaterialTheme.colorScheme.onTertiaryContainer,
            )
        else AssistChipDefaults.assistChipColors(),
    )
}

@Composable
private fun DrawingToolbar(
    pointCount: Int,
    onCancel: () -> Unit,
    onUndo: () -> Unit,
    onFinish: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(28.dp),
        tonalElevation = 6.dp,
        shadowElevation = 6.dp,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            TextButton(onClick = onCancel) {
                Text("Cancel")
            }
            TextButton(
                onClick = onUndo,
                enabled = pointCount > 0,
            ) {
                Icon(Icons.Filled.Undo, contentDescription = null,
                    modifier = Modifier.padding(end = 4.dp))
                Text("Undo")
            }
            Button(
                onClick = onFinish,
                enabled = pointCount >= 3,
            ) {
                Icon(Icons.Filled.Done, contentDescription = null,
                    modifier = Modifier.padding(end = 4.dp))
                Text("Finish")
            }
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
