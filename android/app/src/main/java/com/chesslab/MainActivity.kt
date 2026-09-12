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
import com.chesslab.analysis.AnalysisEntryScreen
import com.chesslab.analysis.AnalysisScreen
import com.chesslab.lab.LabScreen
import com.chesslab.nav.Route
import com.chesslab.play.NewGameSetupRoute
import com.chesslab.play.PlayScreen
import com.chesslab.courses.CourseListScreen
import com.chesslab.courses.CourseRepository
import com.chesslab.courses.CourseScreen
import com.chesslab.training.TrainMode
import com.chesslab.training.TrainScreen
import com.chesslab.editor.PositionEditorScreen
import com.chesslab.help.HelpScreen
import com.chesslab.progression.ProgressionScreen
import com.chesslab.puzzles.PuzzleScreen
import com.chesslab.scanner.ScannerScreen
import com.chesslab.settings.SettingsScreen
import com.chesslab.twoplayer.TwoPlayerScreen
import com.chesslab.ui.HomeScreen
import com.chesslab.variants.VariantCatalog
import com.chesslab.variants.VariantListScreen
import com.chesslab.variants.VariantPlayScreen
import com.chesslab.ui.AppBackground
import com.chesslab.ui.LocalTopBarSlot
import com.chesslab.ui.Palette
import com.chesslab.ui.TopBarSlot
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalContext
import com.chesslab.R
import androidx.compose.ui.res.stringResource

class MainActivity : ComponentActivity() {
    /** Le choix de langue s'applique avant toute résolution de ressource. */
    override fun attachBaseContext(newBase: android.content.Context) {
        super.attachBaseContext(com.chesslab.settings.AppLanguage.wrap(newBase))
    }

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
                // Le fond signature remplace la surface unie : c'est lui qui
                // donne à l'app son atmosphère, sur Android comme sur iOS.
                AppBackground { App() }
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
    val context = LocalContext.current
    // Les écrans sont composés SOUS la barre : ils y déposent leurs boutons
    // par ce relais plutôt que de la reconstruire chacun pour soi.
    val topBar = remember { TopBarSlot() }

    BackHandler(enabled = stack.size > 1) { stack.removeAt(stack.lastIndex) }

    // `systemBarsPadding` et non `safeDrawingPadding` : ce dernier inclut le
    // CLAVIER, si bien que son ouverture redimensionnait tout l'arbre de
    // l'écran. Combiné à un changement d'écran dans la même image, Compose
    // remesurait un nœud déjà détaché et plantait. Les écrans qui saisissent
    // du texte gèrent l'encart du clavier eux-mêmes.
    Column(Modifier.fillMaxSize().systemBarsPadding()) {
        if (current != Route.Home) {
            TopBar(
                title = if (current.hasOwnTitle) "" else current.title(context),
                actions = topBar.content,
                onBack = { stack.removeAt(stack.lastIndex) },
            )
        }
        CompositionLocalProvider(LocalTopBarSlot provides topBar) {
        when (current) {
            Route.Home -> HomeScreen { stack.add(it) }
            Route.NewGame -> NewGameSetupRoute { settings ->
                // On REMPLACE la configuration dans la pile : revenir depuis
                // la partie doit ramener à l'accueil, pas à l'écran qu'on
                // vient de valider.
                stack[stack.lastIndex] = Route.PlayVsEngine(settings)
            }
            is Route.PlayVsEngine -> PlayScreen(
                settings = current.settings, resume = current.resume,
                startFen = current.startFen,
                onOpenTwoPlayer = { stack.add(Route.TwoPlayer(it)) },
                onAnalyze = { stack.add(Route.AnalysisBoard(fen = it)) },
                onAnalyzeGame = { stack.add(Route.AnalysisBoard(pgn = it)) },
                onOpenLab = { stack.add(Route.Laboratory(it)) },
            )
            is Route.TwoPlayer -> TwoPlayerScreen(
                startFen = current.startFen,
                onPlayVsEngine = { stack.add(Route.PlayVsEngine(startFen = it)) },
                onAnalyze = { stack.add(Route.AnalysisBoard(fen = it)) },
                onOpenLab = { stack.add(Route.Laboratory(it)) },
            )
            Route.Analysis -> AnalysisEntryScreen(
                onScan = { stack.add(Route.Scanner) },
                onLibrary = { stack.add(Route.AnalysisBoard()) },
                onLastGame = { pgn -> stack.add(Route.AnalysisBoard(pgn = pgn)) },
                onPaste = { stack.add(Route.AnalysisBoard()) },
                onEditor = { stack.add(Route.PositionEditor) },
            )
            is Route.AnalysisBoard -> AnalysisScreen(
                initialFen = current.fen, initialPgn = current.pgn,
                onPlayVsEngine = { stack.add(Route.PlayVsEngine(startFen = it)) },
                onOpenLab = { stack.add(Route.Laboratory(it)) },
            )
            Route.Puzzles -> PuzzleScreen(
                onPlayVsEngine = { stack.add(Route.PlayVsEngine(startFen = it)) },
                onOpenTwoPlayer = { stack.add(Route.TwoPlayer(it)) },
                onOpenLab = { stack.add(Route.Laboratory(it)) },
            )
            Route.Openings -> CourseListScreen(
                endgames = false,
                onTrain = { kind -> stack.add(trainRoute(context, kind)) },
                onPlayVsEngine = { stack.add(Route.NewGame) },
                onOpenTwoPlayer = { stack.add(Route.TwoPlayer()) },
                onOpenLab = { stack.add(Route.Laboratory()) },
            ) { stack.add(reader(it)) }
            Route.Endgames -> CourseListScreen(
                endgames = true,
                onTrain = { kind -> stack.add(trainRoute(context, kind)) },
                onPlayVsEngine = { stack.add(Route.NewGame) },
                onOpenTwoPlayer = { stack.add(Route.TwoPlayer()) },
                onOpenLab = { stack.add(Route.Laboratory()) },
            ) { stack.add(reader(it)) }
            is Route.CourseReader -> CourseScreen(
                courseId = current.id,
                onPlayVsEngine = { stack.add(Route.PlayVsEngine(startFen = it)) },
                onOpenTwoPlayer = { stack.add(Route.TwoPlayer(it)) },
                onOpenLab = { stack.add(Route.Laboratory(it)) },
            ) { id, name ->
                stack.add(Route.Train("line", id, context.getString(R.string.route_train_named, name)))
            }
            is Route.Train -> TrainScreen(
                mode = when (current.kind) {
                    "line" -> TrainMode.FullLine(current.courseId ?: "")
                    "hardest" -> TrainMode.Hardest
                    else -> TrainMode.Daily
                },
                onPlayVsEngine = { stack.add(Route.PlayVsEngine(startFen = it)) },
                onOpenTwoPlayer = { stack.add(Route.TwoPlayer(it)) },
                onOpenLab = { stack.add(Route.Laboratory(it)) },
            )
            Route.Settings -> SettingsScreen()
            Route.Scanner -> ScannerScreen { fen -> stack.add(Route.AnalysisBoard(fen = fen)) }
            Route.Progression -> ProgressionScreen()
            Route.Help -> HelpScreen()
            Route.PositionEditor -> PositionEditorScreen { fen -> stack.add(Route.AnalysisBoard(fen = fen)) }
            is Route.Laboratory -> LabScreen(startFen = current.startFen)
            Route.Variants -> VariantListScreen { id ->
                stack.add(Route.VariantGame(id, VariantCatalog.byId(id)?.let { context.getString(it.titleRes) } ?: id))
            }
            is Route.VariantGame -> VariantPlayScreen(
                variantId = current.id,
                onAnalyze = { stack.add(Route.AnalysisBoard(fen = it)) },
            )
            else -> Placeholder(current.title(context))
        }
        }
    }
}

/** Le titre d'un cours vient du catalogue : la liste l'a déjà en mémoire. */
private fun trainRoute(context: android.content.Context, kind: String): Route.Train = Route.Train(
    kind,
    label = context.getString(if (kind == "hardest") R.string.train_hardest else R.string.train_daily),
)

private fun reader(id: String): Route.CourseReader =
    Route.CourseReader(id, CourseRepository.cachedName(id) ?: id)

@Composable
private fun TopBar(
    title: String,
    actions: (@Composable RowScope.() -> Unit)?,
    onBack: () -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 2.dp),
        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
    ) {
        IconButton(onClick = onBack, modifier = Modifier.testTag("retour")) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, "Retour", tint = Palette.textPrimary)
        }
        Text(title, style = MaterialTheme.typography.titleMedium, color = Palette.textPrimary)
        Spacer(Modifier.weight(1f))
        actions?.invoke(this)
    }
}

@Composable
private fun Placeholder(title: String) {
    Box(Modifier.fillMaxSize(), androidx.compose.ui.Alignment.Center) {
        Text(stringResource(R.string.soon, title), color = Palette.textSecondary)
    }
}
