package fi.eport.searchassistant.ui.search

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.GpsFixed
import androidx.compose.material.icons.filled.LocationDisabled
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import fi.eport.searchassistant.util.toComposeColor
import kotlinx.coroutines.delay
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import java.util.UUID
import kotlin.time.Duration.Companion.seconds

data class ParticipantRow(
    val id: UUID,
    val displayName: String,
    val color: String,
    val lastSeenAt: Instant,
    val hasPosition: Boolean,
    val isMe: Boolean,
    val isStale: Boolean,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ParticipantsSheet(
    rows: List<ParticipantRow>,
    onFocus: (UUID) -> Unit,
    onClose: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    // Tick "now" every 15 s so the relative-age strings refresh while
    // the sheet is open (same cadence as the iOS sheet).
    var now by remember { mutableStateOf(Clock.System.now()) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(15.seconds)
            now = Clock.System.now()
        }
    }

    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                "Participants",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
            )
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 480.dp),
            ) {
                items(rows, key = { it.id }) { row ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable(enabled = row.hasPosition) {
                                onFocus(row.id)
                            }
                            .padding(horizontal = 8.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        // Colored dot, faded when stale (and not me).
                        Box(
                            modifier = Modifier
                                .size(14.dp)
                                .clip(CircleShape)
                                .background(row.color.toComposeColor()
                                    .let { if (row.isStale && !row.isMe) it.copy(alpha = 0.55f) else it })
                                .border(
                                    width = 2.dp,
                                    color = Color.White,
                                    shape = CircleShape,
                                ),
                        )
                        Spacer(Modifier.width(12.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                row.displayName + (if (row.isMe) " (you)" else ""),
                                style = MaterialTheme.typography.bodyLarge,
                                maxLines = 1,
                            )
                            Text(
                                if (row.hasPosition) relativeAge(row.lastSeenAt, now)
                                else "No location yet",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1,
                            )
                        }
                        if (row.hasPosition) {
                            Icon(
                                Icons.Filled.GpsFixed,
                                contentDescription = "Center on this participant",
                                tint = MaterialTheme.colorScheme.primary,
                            )
                        } else {
                            Icon(
                                Icons.Filled.LocationDisabled,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.outline,
                            )
                        }
                    }
                    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}

private fun relativeAge(date: Instant, now: Instant): String {
    val seconds = (now.toEpochMilliseconds() - date.toEpochMilliseconds()) / 1000
    if (seconds < 30) return "now"
    if (seconds < 60) return "${seconds}s ago"
    val minutes = seconds / 60
    if (minutes < 60) return "${minutes}m ago"
    val hours = minutes / 60
    if (hours < 24) return "${hours}h ago"
    return "${hours / 24}d ago"
}
