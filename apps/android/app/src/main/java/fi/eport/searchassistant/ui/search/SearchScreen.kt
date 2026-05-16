package fi.eport.searchassistant.ui.search

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.SettingsApplications
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.android.gms.maps.model.LatLng
import fi.eport.searchassistant.AppContainer
import fi.eport.searchassistant.domain.ConnectionState
import fi.eport.searchassistant.domain.LoadPhase
import fi.eport.searchassistant.domain.SearchViewModel
import fi.eport.searchassistant.util.toComposeColor

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
