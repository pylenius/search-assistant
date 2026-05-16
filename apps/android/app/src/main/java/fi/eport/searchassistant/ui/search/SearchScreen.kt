package fi.eport.searchassistant.ui.search

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier

/// Stub — full search UI ships in step 5.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchScreen(slug: String) {
    Scaffold(
        topBar = { TopAppBar(title = { Text(slug) }) }
    ) { padding ->
        Box(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentAlignment = Alignment.Center,
        ) {
            Text("Search /s/$slug — full UI in step 5")
        }
    }
}
