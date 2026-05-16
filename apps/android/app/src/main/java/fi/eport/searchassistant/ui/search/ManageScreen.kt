package fi.eport.searchassistant.ui.search

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import fi.eport.searchassistant.AppContainer
import fi.eport.searchassistant.data.api.UpdateSearchRequest
import fi.eport.searchassistant.data.api.httpStatus
import kotlinx.coroutines.launch
import kotlinx.datetime.Instant
import kotlinx.datetime.toJavaInstant
import kotlinx.datetime.toKotlinInstant
import java.text.DateFormat
import java.util.Date

/// Owner-only management screen. Guarded by the local owner token —
/// MainActivity checks before navigating here.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ManageScreen(
    slug: String,
    container: AppContainer,
    initialTitle: String,
    initialExpiresAt: Instant?,
    onDeleted: () -> Unit,
    onBack: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    val ownerToken = remember(slug) { container.sessionStore.ownerToken(slug) }

    if (ownerToken == null) {
        // Shouldn't happen normally — defensive landing.
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Manage") },
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(Icons.Filled.ArrowBack, "Back")
                        }
                    },
                )
            }
        ) { p ->
            Box(Modifier.fillMaxSize().padding(p), Alignment.Center) {
                Text("Only the creator of this search can manage it.")
            }
        }
        return
    }

    var title by rememberSaveable { mutableStateOf(initialTitle) }
    var hasExpiry by rememberSaveable { mutableStateOf(initialExpiresAt != null) }
    var expiresAtMs by rememberSaveable {
        mutableStateOf(initialExpiresAt?.toEpochMilliseconds()
            ?: (System.currentTimeMillis() + 24L * 3600 * 1000))
    }
    var saving by rememberSaveable { mutableStateOf(false) }
    var status by rememberSaveable { mutableStateOf<String?>(null) }
    var statusIsError by rememberSaveable { mutableStateOf(false) }
    var showClearDialog by rememberSaveable { mutableStateOf(false) }
    var showDeleteDialog by rememberSaveable { mutableStateOf(false) }
    var showDatePicker by rememberSaveable { mutableStateOf(false) }

    fun setStatus(message: String, isError: Boolean) {
        status = message; statusIsError = isError
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Manage search") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Filled.ArrowBack, "Back")
                    }
                },
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            OutlinedTextField(
                value = title,
                onValueChange = { title = it.take(200) },
                label = { Text("Title") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )

            Row(verticalAlignment = Alignment.CenterVertically) {
                Switch(checked = hasExpiry, onCheckedChange = { hasExpiry = it })
                Spacer(Modifier.width(8.dp))
                Text("Set an expiry")
            }
            if (hasExpiry) {
                OutlinedButton(
                    onClick = { showDatePicker = true },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Expires: " + DateFormat
                        .getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT)
                        .format(Date(expiresAtMs)))
                }
                Text(
                    expiryStatus(expiresAtMs),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            } else {
                Text(
                    "Never expires",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Button(
                onClick = {
                    if (saving) return@Button
                    saving = true
                    status = null
                    scope.launch {
                        try {
                            container.apiClient.service.updateSearch(
                                slug,
                                UpdateSearchRequest(
                                    title = title.trim(),
                                    expiresAt = if (hasExpiry)
                                        java.time.Instant.ofEpochMilli(expiresAtMs)
                                            .toKotlinInstant()
                                    else null,
                                ),
                                ownerToken,
                            )
                            setStatus("Saved.", isError = false)
                        } catch (t: Throwable) {
                            setStatus(
                                t.httpStatus?.let { "Save failed (HTTP $it)." }
                                    ?: "Network error.",
                                isError = true,
                            )
                        } finally {
                            saving = false
                        }
                    }
                },
                enabled = !saving && title.trim().isNotEmpty(),
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (saving) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.onPrimary,
                    )
                    Spacer(Modifier.width(8.dp))
                }
                Text(if (saving) "Saving…" else "Save changes")
            }

            HorizontalDivider()

            Text("Danger zone",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.error)

            OutlinedButton(
                onClick = { showClearDialog = true },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Clear all recorded paths") }

            Button(
                onClick = { showDeleteDialog = true },
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.error,
                    contentColor = MaterialTheme.colorScheme.onError,
                ),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Delete search") }

            status?.let { msg ->
                Text(msg, color = if (statusIsError)
                    MaterialTheme.colorScheme.error
                else MaterialTheme.colorScheme.onSurface)
            }
        }
    }

    if (showDatePicker) {
        val state = rememberDatePickerState(initialSelectedDateMillis = expiresAtMs)
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { expiresAtMs = it }
                    showDatePicker = false
                }) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text("Cancel") }
            },
        ) {
            DatePicker(state = state)
        }
    }

    if (showClearDialog) {
        AlertDialog(
            onDismissRequest = { showClearDialog = false },
            title = { Text("Clear all paths?") },
            text = { Text("This cannot be undone. Every recorded path will be removed for all participants.") },
            confirmButton = {
                TextButton(onClick = {
                    showClearDialog = false
                    scope.launch {
                        try {
                            val res = container.apiClient.service.clearPaths(slug, ownerToken)
                            setStatus("Cleared ${res.cleared} path${if (res.cleared == 1) "" else "s"}.", isError = false)
                        } catch (t: Throwable) {
                            setStatus(
                                t.httpStatus?.let { "Clear failed (HTTP $it)." }
                                    ?: "Network error.",
                                isError = true,
                            )
                        }
                    }
                }) { Text("Clear", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showClearDialog = false }) { Text("Cancel") }
            },
        )
    }

    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("Delete this search?") },
            text = { Text("Everyone loses access to the participants, areas, and paths. This cannot be undone.") },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteDialog = false
                    scope.launch {
                        try {
                            container.apiClient.service.deleteSearch(slug, ownerToken)
                            onDeleted()
                        } catch (t: Throwable) {
                            setStatus(
                                t.httpStatus?.let { "Delete failed (HTTP $it)." }
                                    ?: "Network error.",
                                isError = true,
                            )
                        }
                    }
                }) { Text("Delete", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) { Text("Cancel") }
            },
        )
    }
}

private fun expiryStatus(expiresAtMs: Long): String {
    val diff = expiresAtMs - System.currentTimeMillis()
    if (diff < 0) return "Already expired"
    val hours = (diff / 3_600_000L).toInt()
    if (hours < 1) return "Expires in <1h"
    val days = hours / 24
    val remH = hours % 24
    return if (days > 0) "Expires in ${days}d ${remH}h" else "Expires in ${hours}h"
}
