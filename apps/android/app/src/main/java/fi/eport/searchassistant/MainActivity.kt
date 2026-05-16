package fi.eport.searchassistant

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.NavType
import androidx.navigation.navArgument
import fi.eport.searchassistant.ui.landing.LandingScreen
import fi.eport.searchassistant.ui.search.SearchScreen
import fi.eport.searchassistant.ui.theme.SearchAssistantTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val container = (application as SearchAssistantApp).container
        setContent {
            SearchAssistantTheme {
                AppNavHost(container)
            }
        }
    }
}

@Composable
private fun AppNavHost(container: AppContainer) {
    val navController = rememberNavController()
    NavHost(navController = navController, startDestination = Routes.LANDING) {
        composable(Routes.LANDING) {
            LandingScreen(
                apiClient = container.apiClient,
                sessionStore = container.sessionStore,
                recentSearchesStore = container.recentSearchesStore,
                onOpen = { slug ->
                    navController.navigate(Routes.searchFor(slug))
                },
            )
        }
        composable(
            route = Routes.SEARCH_PATTERN,
            arguments = listOf(navArgument(Routes.ARG_SLUG) { type = NavType.StringType }),
        ) { backStackEntry ->
            val slug = backStackEntry.arguments?.getString(Routes.ARG_SLUG).orEmpty()
            SearchScreen(slug = slug)
        }
    }
}

object Routes {
    const val LANDING = "landing"
    const val ARG_SLUG = "slug"
    const val SEARCH_PATTERN = "search/{$ARG_SLUG}"
    fun searchFor(slug: String) = "search/$slug"
}
