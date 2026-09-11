package com.chesslab

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.chesslab.analysis.AnalysisScreen
import com.chesslab.nav.Route
import com.chesslab.play.PlayScreen
import com.chesslab.courses.CourseListScreen
import com.chesslab.courses.CourseRepository
import com.chesslab.courses.CourseScreen
import com.chesslab.puzzles.PuzzleScreen
import com.chesslab.settings.SettingsScreen
import com.chesslab.twoplayer.TwoPlayerScreen
import com.chesslab.ui.HomeScreen
import com.chesslab.ui.Palette

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(
                colorScheme = darkColorScheme(
                    background = Palette.background,
                    surface = Palette.surface,
                    primary = Palette.accent,
                )
            ) {
                Surface(Modifier.fillMaxSize(), color = Palette.background) { App() }
            }
        }
    }
}

/**
 * La navigation de l'app : une pile explicite plutôt qu'une bibliothèque.
 * Le comportement du bouton « retour » se lit d'un coup d'œil, et rien
 * n'est empilé en double.
 */
@Composable
private fun App() {
    val stack = remember { mutableStateListOf<Route>(Route.Home) }
    val current = stack.last()

    BackHandler(enabled = stack.size > 1) { stack.removeAt(stack.lastIndex) }

    Column(Modifier.fillMaxSize().safeDrawingPadding()) {
        if (current != Route.Home) {
            TopBar(current.title) { stack.removeAt(stack.lastIndex) }
        }
        when (current) {
            Route.Home -> HomeScreen { stack.add(it) }
            Route.PlayVsEngine -> PlayScreen()
            Route.TwoPlayer -> TwoPlayerScreen()
            Route.Analysis -> AnalysisScreen()
            Route.Puzzles -> PuzzleScreen()
            Route.Openings -> CourseListScreen(endgames = false) { stack.add(reader(it)) }
            Route.Endgames -> CourseListScreen(endgames = true) { stack.add(reader(it)) }
            is Route.CourseReader -> CourseScreen(current.id)
            Route.Settings -> SettingsScreen()
            else -> Placeholder(current.title)
        }
    }
}

/** Le titre d'un cours vient du catalogue : la liste l'a déjà en mémoire. */
private fun reader(id: String): Route.CourseReader =
    Route.CourseReader(id, CourseRepository.cachedName(id) ?: id)

@Composable
private fun TopBar(title: String, onBack: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 2.dp),
        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
    ) {
        IconButton(onClick = onBack, modifier = Modifier.testTag("retour")) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, "Retour", tint = Palette.textPrimary)
        }
        Text(title, style = MaterialTheme.typography.titleMedium, color = Palette.textPrimary)
    }
}

@Composable
private fun Placeholder(title: String) {
    Box(Modifier.fillMaxSize(), androidx.compose.ui.Alignment.Center) {
        Text("$title — bientôt", color = Palette.textSecondary)
    }
}
