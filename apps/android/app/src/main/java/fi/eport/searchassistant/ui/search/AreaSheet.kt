package fi.eport.searchassistant.ui.search

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import fi.eport.searchassistant.util.toComposeColor

/// Bottom sheet: title + 12-color palette. Same palette as the iOS
/// AreaSheet + the server's ColorPalette.cs so areas drawn from any
/// client land on the same hexes.
private val PALETTE = listOf(
    "#ef4444", "#f97316", "#eab308", "#22c55e", "#14b8a6",
    "#3b82f6", "#6366f1", "#a855f7", "#ec4899", "#0ea5e9",
    "#84cc16", "#f43f5e",
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AreaSheet(
    defaultColor: String,
    onSave: (title: String?, color: String) -> Unit,
    onCancel: () -> Unit,
) {
    var title by rememberSaveable { mutableStateOf("") }
    var selected by rememberSaveable { mutableStateOf(defaultColor) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val keyboard = LocalSoftwareKeyboardController.current

    ModalBottomSheet(
        onDismissRequest = onCancel,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                "Save area",
                style = MaterialTheme.typography.titleMedium,
            )
            OutlinedTextField(
                value = title,
                onValueChange = { title = it.take(120) },
                label = { Text("Title (optional)") },
                placeholder = { Text("e.g. North hillside") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { keyboard?.hide() }),
            )
            Text(
                "Color",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            // 6-column swatch grid via plain layout (LazyVGrid overkill).
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                PALETTE.chunked(6).forEach { row ->
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        row.forEach { hex ->
                            ColorSwatch(
                                hex = hex,
                                isSelected = hex == selected,
                                onClick = { selected = hex },
                            )
                        }
                    }
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 6.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OutlinedButton(
                    onClick = onCancel,
                    modifier = Modifier.weight(1f),
                ) { Text("Cancel") }
                Button(
                    onClick = {
                        val t = title.trim().ifEmpty { null }
                        onSave(t, selected)
                    },
                    modifier = Modifier.weight(1f),
                ) { Text("Save") }
            }
            Spacer(Modifier.height(20.dp))
        }
    }
}

@Composable
private fun ColorSwatch(
    hex: String,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val color: Color = hex.toComposeColor()
    Box(
        modifier = Modifier
            .size(34.dp)
            .clip(CircleShape)
            .background(color)
            .border(
                width = if (isSelected) 3.dp else 0.dp,
                color = if (isSelected) MaterialTheme.colorScheme.onSurface
                else Color.Transparent,
                shape = CircleShape,
            )
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {}
}
