package fi.eport.searchassistant.ui.search

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.google.zxing.BarcodeFormat
import com.journeyapps.barcodescanner.BarcodeEncoder
import fi.eport.searchassistant.AppConfig
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShareSheet(
    slug: String,
    participantCount: Int,
    onClose: () -> Unit,
) {
    val context = LocalContext.current
    val shareUrl = remember(slug) { "https://${AppConfig.APP_LINKS_HOST}/s/$slug" }
    val gpxUrl = remember(slug) {
        AppConfig.API_BASE_URL.trimEnd('/') +
            "/api/searches/$slug/export.gpx"
    }
    val qrBitmap = remember(shareUrl) { generateQr(shareUrl, 600) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var copied by rememberSaveable { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                "Share this search",
                style = MaterialTheme.typography.titleMedium,
            )
            Text(
                "$participantCount ${if (participantCount == 1) "person" else "people"} joined so far",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            qrBitmap?.let { bm ->
                Image(
                    bitmap = bm.asImageBitmap(),
                    contentDescription = "QR code linking to the search",
                    modifier = Modifier
                        .size(220.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(Color.White),
                )
            } ?: Box(
                modifier = Modifier
                    .size(220.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            )

            Text(
                shareUrl,
                style = MaterialTheme.typography.bodySmall.copy(
                    fontFamily = FontFamily.Monospace,
                ),
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )

            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OutlinedButton(
                    onClick = {
                        copyToClipboard(context, shareUrl)
                        copied = true
                        scope.launch {
                            delay(1800)
                            copied = false
                        }
                    },
                    modifier = Modifier.weight(1f),
                ) {
                    Icon(
                        if (copied) Icons.Filled.Check else Icons.Filled.ContentCopy,
                        contentDescription = null,
                        modifier = Modifier.padding(end = 6.dp),
                    )
                    Text(if (copied) "Copied" else "Copy link")
                }
                Button(
                    onClick = { sendShareIntent(context, shareUrl) },
                    modifier = Modifier.weight(1f),
                ) {
                    Icon(
                        Icons.Filled.IosShare,
                        contentDescription = null,
                        modifier = Modifier.padding(end = 6.dp),
                    )
                    Text("Share")
                }
            }

            OutlinedButton(
                onClick = { openInBrowser(context, gpxUrl) },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(
                    Icons.Filled.ArrowDownward,
                    contentDescription = null,
                    modifier = Modifier.padding(end = 6.dp),
                )
                Text("Download GPX")
            }

            Spacer(Modifier.height(16.dp))
        }
    }
}

private fun generateQr(content: String, sizePx: Int): Bitmap? = try {
    BarcodeEncoder().encodeBitmap(
        content, BarcodeFormat.QR_CODE, sizePx, sizePx
    )
} catch (_: Throwable) {
    null
}

private fun copyToClipboard(context: Context, text: String) {
    val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    cm.setPrimaryClip(ClipData.newPlainText("Search Assistant", text))
}

private fun sendShareIntent(context: Context, url: String) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, url)
    }
    context.startActivity(
        Intent.createChooser(intent, "Share this search")
    )
}

private fun openInBrowser(context: Context, url: String) {
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
    context.startActivity(intent)
}
