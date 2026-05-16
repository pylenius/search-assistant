package fi.eport.searchassistant

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.NavType
import androidx.navigation.navArgument
import androidx.lifecycle.viewmodel.compose.viewModel
import fi.eport.searchassistant.domain.SearchViewModel
import fi.eport.searchassistant.ui.landing.LandingScreen
import fi.eport.searchassistant.ui.search.ManageScreen
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
            SearchScreen(
                slug = slug,
                container = container,
                onBack = { navController.popBackStack() },
                onManage = { navController.navigate(Routes.manageFor(slug)) },
            )
        }
        composable(
            route = Routes.MANAGE_PATTERN,
            arguments = listOf(navArgument(Routes.ARG_SLUG) { type = NavType.StringType }),
        ) { backStackEntry ->
            val slug = backStackEntry.arguments?.getString(Routes.ARG_SLUG).orEmpty()
            // Snapshot the current title + expiresAt at navigation time
            // so we don't need to plumb a shared VM through both screens.
            // Falls back to a quick refresh if the user came here cold.
            val vm: SearchViewModel = viewModel(
                key = slug,
                factory = SearchViewModel.Factory(
                    slug = slug,
                    apiClient = container.apiClient,
                    sessionStore = container.sessionStore,
                    recentSearchesStore = container.recentSearchesStore,
                ),
            )
            val state by vm.state.collectAsStateWithLifecycle()
            ManageScreen(
                slug = slug,
                container = container,
                initialTitle = state.title,
                initialExpiresAt = state.expiresAt,
                onDeleted = {
                    navController.popBackStack(Routes.LANDING, inclusive = false)
                },
                onBack = { navController.popBackStack() },
            )
        }
    }
}

object Routes {
    const val LANDING = "landing"
    const val ARG_SLUG = "slug"
    const val SEARCH_PATTERN = "search/{$ARG_SLUG}"
    const val MANAGE_PATTERN = "manage/{$ARG_SLUG}"
    fun searchFor(slug: String) = "search/$slug"
    fun manageFor(slug: String) = "manage/$slug"
}
