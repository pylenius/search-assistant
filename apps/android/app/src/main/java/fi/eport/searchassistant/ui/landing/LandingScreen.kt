package fi.eport.searchassistant.ui.landing

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import fi.eport.searchassistant.data.api.ApiClient
import fi.eport.searchassistant.data.api.CreateSearchRequest
import fi.eport.searchassistant.data.api.httpStatus
import fi.eport.searchassistant.data.recents.RecentSearch
import fi.eport.searchassistant.data.recents.RecentSearchesStore
import fi.eport.searchassistant.data.session.SessionStore
import kotlinx.coroutines.launch
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import java.text.DateFormat
import java.util.Date

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LandingScreen(
    apiClient: ApiClient,
    sessionStore: SessionStore,
    recentSearchesStore: RecentSearchesStore,
    onOpen: (slug: String) -> Unit,
) {
    val scope = rememberCoroutineScope()
    var title by rememberSaveable { mutableStateOf("Quick search") }
    var creating by rememberSaveable { mutableStateOf(false) }
    var errorMessage by rememberSaveable { mutableStateOf<String?>(null) }
    val keyboard = LocalSoftwareKeyboardController.current

    val recents by recentSearchesStore.items.collectAsStateWithLifecycle()

    fun create() {
        val trimmed = title.trim()
        if (trimmed.isEmpty() || creating) return
        creating = true
        errorMessage = null
        keyboard?.hide()
        scope.launch {
            try {
                val resp = apiClient.service.createSearch(
                    CreateSearchRequest(title = trimmed, zoom = 14)
                )
                sessionStore.setOwnerToken(resp.ownerToken, resp.slug)
                onOpen(resp.slug)
            } catch (t: Throwable) {
                errorMessage = t.httpStatus?.let { "Couldn't create search (HTTP $it)." }
                    ?: "Network error — ${t.localizedMessage ?: t.javaClass.simpleName}"
            } finally {
                creating = false
            }
        }
    }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("Search Assistant") }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item { Hero() }

            item {
                NewSearchCard(
                    title = title,
                    onTitleChange = { title = it },
                    creating = creating,
                    onCreate = { create() },
                )
            }

            if (errorMessage != null) {
                item {
                    Text(
                        errorMessage!!,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }

            if (recents.isNotEmpty()) {
                item {
                    SectionHeader("Recent searches")
                }
                items(recents, key = { it.slug }) { item ->
                    RecentRow(
                        item = item,
                        onClick = { onOpen(item.slug) },
                        onDelete = { recentSearchesStore.remove(item.slug) },
                    )
                }
            }

            item {
                PrivacyFooter()
            }

            item { Spacer(Modifier.height(48.dp)) }
        }
    }
}

@Composable
private fun PrivacyFooter() {
    val context = androidx.compose.ui.platform.LocalContext.current
    TextButton(
        onClick = {
            context.startActivity(
                android.content.Intent(
                    android.content.Intent.ACTION_VIEW,
                    android.net.Uri.parse("https://searchassistant.eport.fi/privacy"),
                )
            )
        },
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(
            "Privacy policy",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun Hero() {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            Icons.Filled.Map,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(56.dp),
        )
        Text(
            "Share a search area and live positions with everyone " +
                "you're searching with. No account needed.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 24.dp),
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun NewSearchCard(
    title: String,
    onTitleChange: (String) -> Unit,
    creating: Boolean,
    onCreate: () -> Unit,
) {
    ElevatedCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                "New search",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            OutlinedTextField(
                value = title,
                onValueChange = onTitleChange,
                label = { Text("What are you searching for?") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions.Default.copy(
                    imeAction = androidx.compose.ui.text.input.ImeAction.Done
                ),
                keyboardActions = KeyboardActions(onDone = { onCreate() }),
            )
            Button(
                onClick = onCreate,
                modifier = Modifier.fillMaxWidth(),
                enabled = !creating && title.trim().isNotEmpty(),
            ) {
                if (creating) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.onPrimary,
                    )
                    Spacer(Modifier.width(10.dp))
                }
                Text(if (creating) "Creating…" else "Create new search")
            }
        }
    }
}

@Composable
private fun SectionHeader(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(top = 8.dp, start = 4.dp),
    )
}

@Composable
private fun RecentRow(
    item: RecentSearch,
    onClick: () -> Unit,
    onDelete: () -> Unit,
) {
    ElevatedCard(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                if (item.isOwner) Icons.Filled.WorkspacePremium else Icons.Filled.Group,
                contentDescription = null,
                tint = if (item.isOwner) MaterialTheme.colorScheme.tertiary
                else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier
                    .size(24.dp)
                    .padding(end = 12.dp),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    item.title.ifEmpty { "Search" },
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                )
                Text(
                    buildString {
                        append("/s/${item.slug}")
                        append(" · ")
                        append(relativeAge(item.visitedAt))
                        if (item.isOwner) append(" · owner")
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                )
            }
            Icon(
                Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.outlineVariant,
            )
            // Quick "Forget" affordance — pragmatic stand-in for
            // swipe-to-dismiss; cheaper to ship and clearer to a new user.
            TextButton(onClick = onDelete) { Text("Forget") }
        }
    }
}

private fun relativeAge(visitedAt: Instant): String {
    val seconds = Clock.System.now().toEpochMilliseconds() / 1000 -
        visitedAt.toEpochMilliseconds() / 1000
    if (seconds < 60) return "just now"
    val minutes = seconds / 60
    if (minutes < 60) return "${minutes}m ago"
    val hours = minutes / 60
    if (hours < 24) return "${hours}h ago"
    val days = hours / 24
    if (days < 7) return "${days}d ago"
    return DateFormat.getDateInstance(DateFormat.MEDIUM)
        .format(Date(visitedAt.toEpochMilliseconds()))
}
