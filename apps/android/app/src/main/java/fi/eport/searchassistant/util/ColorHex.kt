package fi.eport.searchassistant.util

import androidx.compose.ui.graphics.Color

/// Parses "#rrggbb" or "#rrggbbaa". Falls back to gray on bad input —
/// same fallback shape as iOS's `Color(hex:)` extension.
fun String.toComposeColor(): Color {
    var s = this
    if (s.startsWith("#")) s = s.drop(1)
    if (s.length != 6 && s.length != 8) return Color.Gray
    val value = s.toULongOrNull(radix = 16) ?: return Color.Gray
    return if (s.length == 6) {
        Color(
            red = ((value shr 16) and 0xFFu).toInt() / 255f,
            green = ((value shr 8) and 0xFFu).toInt() / 255f,
            blue = (value and 0xFFu).toInt() / 255f,
        )
    } else {
        Color(
            red = ((value shr 24) and 0xFFu).toInt() / 255f,
            green = ((value shr 16) and 0xFFu).toInt() / 255f,
            blue = ((value shr 8) and 0xFFu).toInt() / 255f,
            alpha = (value and 0xFFu).toInt() / 255f,
        )
    }
}
