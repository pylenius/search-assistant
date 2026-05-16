package fi.eport.searchassistant

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import fi.eport.searchassistant.domain.SearchViewModel
import fi.eport.searchassistant.ui.landing.LandingScreen
import fi.eport.searchassistant.ui.search.ManageScreen
import fi.eport.searchassistant.ui.search.SearchScreen
import fi.eport.searchassistant.ui.theme.SearchAssistantTheme

class MainActivity : ComponentActivity() {

    /// Deep-link slug captured from a launching Intent (cold or warm).
    /// AppNavHost observes it and routes; clears after consume so we
    /// don't loop on recompositions.
    private val pendingDeepLinkSlug = mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        consumeIntent(intent)
        val container = (application as SearchAssistantApp).container
        setContent {
            SearchAssistantTheme {
                AppNavHost(
                    container = container,
                    pendingSlug = pendingDeepLinkSlug.value,
                    onDeepLinkConsumed = { pendingDeepLinkSlug.value = null },
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        consumeIntent(intent)
    }

    private fun consumeIntent(intent: Intent?) {
        val data = intent?.data ?: return
        if (intent.action != Intent.ACTION_VIEW) return
        parseSlug(data)?.let { pendingDeepLinkSlug.value = it }
    }
}

/// Pulls `/s/{slug}` out of any URL we get handed. Lax on host so a
/// future custom-scheme or a test build aimed at a different domain
/// still routes.
fun parseSlug(uri: Uri): String? {
    val parts = uri.path?.trim('/')?.split('/') ?: return null
    if (parts.size < 2 || parts[0] != "s") return null
    return parts[1].takeIf { it.isNotEmpty() }
}

@Composable
private fun AppNavHost(
    container: AppContainer,
    pendingSlug: String?,
    onDeepLinkConsumed: () -> Unit,
) {
    val navController = rememberNavController()

    LaunchedEffect(pendingSlug) {
        val slug = pendingSlug ?: return@LaunchedEffect
        val current = navController.currentDestination?.route
        val currentSlug = navController.currentBackStackEntry
            ?.arguments?.getString(Routes.ARG_SLUG)
        when {
            // Same slug already on top — no-op.
            current == Routes.SEARCH_PATTERN && currentSlug == slug -> Unit
            // Different search currently — replace top of stack.
            current == Routes.SEARCH_PATTERN -> {
                navController.popBackStack(Routes.LANDING, inclusive = false)
                navController.navigate(Routes.searchFor(slug))
            }
            else -> navController.navigate(Routes.searchFor(slug))
        }
        onDeepLinkConsumed()
    }

    NavHost(navController = navController, startDestination = Routes.LANDING) {
        composable(Routes.LANDING) {
            LandingScreen(
                apiClient = container.apiClient,
                sessionStore = container.sessionStore,
                recentSearchesStore = container.recentSearchesStore,
                onOpen = { slug ->
                    if (navController.currentBackStackEntry
                            ?.arguments?.getString(Routes.ARG_SLUG) == slug) return@LandingScreen
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
