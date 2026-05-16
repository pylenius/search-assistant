package fi.eport.searchassistant

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import fi.eport.searchassistant.ui.theme.SearchAssistantTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            SearchAssistantTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { inner ->
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(inner),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text("Search Assistant — scaffold ready")
                    }
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun ScaffoldPreview() {
    SearchAssistantTheme {
        Text("Search Assistant — scaffold ready")
    }
}
