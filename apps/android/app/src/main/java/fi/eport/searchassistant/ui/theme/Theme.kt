package fi.eport.searchassistant.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Emerald accent — matches the iOS AccentColor (#10965C) so a user
// switching between platforms gets the same brand color.
private val Emerald = Color(0xFF10965C)
private val EmeraldDark = Color(0xFF22C55E)

private val LightColors = lightColorScheme(
    primary = Emerald,
    onPrimary = Color.White,
)

private val DarkColors = darkColorScheme(
    primary = EmeraldDark,
    onPrimary = Color.Black,
)

@Composable
fun SearchAssistantTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content,
    )
}
