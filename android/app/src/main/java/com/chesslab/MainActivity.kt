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
import androidx.compose.runtime.LaunchedEffect
import com.chesslab.discovery.DiscoveryAnchors
import com.chesslab.discovery.DiscoveryDestination
import com.chesslab.discovery.DiscoveryTourController
import com.chesslab.discovery.DiscoveryTourMemory
import com.chesslab.discovery.DiscoveryTourOverlay
import com.chesslab.discovery.LocalDiscoveryAnchors
import com.chesslab.discovery.LocalDiscoveryTour
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first

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

    // La visite guidée. Une NOUVELLE installation la montre, une seconde
    // après l'accueil — jamais par-dessus une reprise proposée. L'empreinte
    // est `firstInstallTime`, pas un booléen : voir `DiscoveryTourMemory`.
    // Le crochet `discoveryStep` (extra d'intent, builds débogables
    // seulement) saute à une étape sans attendre : captures et outillage.
    val tour = remember { DiscoveryTourController(onSeen = { DiscoveryTourMemory.markSeen(context) }) }
    val anchors = remember { DiscoveryAnchors() }
    LaunchedEffect(Unit) {
        val debuggable = (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        val requested = (context as? android.app.Activity)?.intent?.getIntExtra("discoveryStep", -1) ?: -1
        if (debuggable && requested >= 0) {
            tour.start(requested)
            return@LaunchedEffect
        }
        delay(1000)
        val resumable = com.chesslab.library.LibraryDatabase.get(context).autosaves().all().first()
        if (DiscoveryTourMemory.shouldOffer(context) && resumable.isEmpty() && !tour.isActive) tour.start()
    }
    // La visite PILOTE la navigation : chaque étape déclare son écran, et la
    // bascule qui se joue sous les yeux EST l'explication.
    LaunchedEffect(tour.isActive, tour.currentStepIndex) {
        val step = tour.currentStep ?: return@LaunchedEffect
        val wanted: List<Route> = when (step.destination) {
            DiscoveryDestination.home -> listOf(Route.Home)
            DiscoveryDestination.newGame -> listOf(Route.Home, Route.NewGame)
            DiscoveryDestination.analysisEntry -> listOf(Route.Home, Route.Analysis)
            DiscoveryDestination.openings -> listOf(Route.Home, Route.Openings)
        }
        if (stack.toList() != wanted) {
            stack.clear()
            stack.addAll(wanted)
        }
    }

    // `systemBarsPadding` et non `safeDrawingPadding` : ce dernier inclut le
    // CLAVIER, si bien que son ouverture redimensionnait tout l'arbre de
    // l'écran. Combiné à un changement d'écran dans la même image, Compose
    // remesurait un nœud déjà détaché et plantait. Les écrans qui saisissent
    // du texte gèrent l'encart du clavier eux-mêmes.
    Box(Modifier.fillMaxSize()) {
    CompositionLocalProvider(LocalDiscoveryAnchors provides anchors, LocalDiscoveryTour provides tour) {
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
                onOpenTwoPlayer = { stack.add(Route.TwoPlayer(startFen = it)) },
                onAnalyze = { stack.add(Route.AnalysisBoard(fen = it)) },
                onAnalyzeGame = { stack.add(Route.AnalysisBoard(pgn = it)) },
                onOpenLab = { stack.add(Route.Laboratory(it)) },
            )
            Route.TwoPlayerSetup -> com.chesslab.twoplayer.TwoPlayerSetupScreen(
                initial = com.chesslab.twoplayer.TwoPlayerSettings(),
            ) { settings ->
                // On REMPLACE la configuration dans la pile : revenir depuis la
                // partie doit ramener à l'accueil, pas à l'écran qu'on valide.
                stack[stack.lastIndex] = Route.TwoPlayer(settings = settings)
            }
            is Route.TwoPlayer -> TwoPlayerScreen(
                settings = current.settings,
                resume = current.resume,
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
            is Route.Puzzles -> PuzzleScreen(
                initialTheme = current.theme,
                onPlayVsEngine = { stack.add(Route.PlayVsEngine(startFen = it)) },
                onOpenTwoPlayer = { stack.add(Route.TwoPlayer(startFen = it)) },
                onOpenLab = { stack.add(Route.Laboratory(it)) },
            )
            Route.Openings -> CourseListScreen(
                endgames = false,
                onTrain = { kind -> stack.add(trainRoute(context, kind)) },
                onPlayVsEngine = { stack.add(Route.NewGame) },
                onOpenTwoPlayer = { stack.add(Route.TwoPlayerSetup) },
                onOpenLab = { stack.add(Route.Laboratory()) },
                onImport = { stack.add(Route.OpeningImport) },
                onEdit = { id, name -> stack.add(Route.OpeningEditor(id, name)) },
            ) { stack.add(reader(it)) }
            is Route.OpeningEditor -> com.chesslab.courses.OpeningEditorScreen(
                courseId = current.id,
                onBack = { stack.removeAt(stack.lastIndex) },
            )
            Route.OpeningImport -> com.chesslab.courses.OpeningImportScreen(
                onImported = { stack.removeAt(stack.lastIndex) },
            )
            Route.Endgames -> CourseListScreen(
                endgames = true,
                onTrain = { kind -> stack.add(trainRoute(context, kind)) },
                onPlayVsEngine = { stack.add(Route.NewGame) },
                onOpenTwoPlayer = { stack.add(Route.TwoPlayerSetup) },
                onOpenLab = { stack.add(Route.Laboratory()) },
            ) { stack.add(reader(it)) }
            is Route.CourseReader -> CourseScreen(
                courseId = current.id,
                onPlayVsEngine = { stack.add(Route.PlayVsEngine(startFen = it)) },
                onOpenTwoPlayer = { stack.add(Route.TwoPlayer(startFen = it)) },
                onOpenLab = { stack.add(Route.Laboratory(it)) },
                onFreeTrain = { id, name -> stack.add(Route.EndgameFree(id, name)) },
            ) { id, name ->
                stack.add(Route.Train("line", id, context.getString(R.string.route_train_named, name)))
            }
            is Route.EndgameFree -> com.chesslab.training.EndgameFreeScreen(
                courseId = current.courseId,
                onPlayVsEngine = { stack.add(Route.PlayVsEngine(startFen = it)) },
                onOpenTwoPlayer = { stack.add(Route.TwoPlayer(startFen = it)) },
                onOpenLab = { stack.add(Route.Laboratory(it)) },
            )
            is Route.Train -> TrainScreen(
                mode = when (current.kind) {
                    "line" -> TrainMode.FullLine(current.courseId ?: "")
                    "hardest" -> TrainMode.Hardest
                    else -> TrainMode.Daily
                },
                onPlayVsEngine = { stack.add(Route.PlayVsEngine(startFen = it)) },
                onOpenTwoPlayer = { stack.add(Route.TwoPlayer(startFen = it)) },
                onOpenLab = { stack.add(Route.Laboratory(it)) },
            )
            Route.Settings -> SettingsScreen(onOpenLicences = { stack.add(Route.Licences) })
            Route.Licences -> com.chesslab.settings.LicencesScreen()
            Route.Scanner -> ScannerScreen { fen -> stack.add(Route.AnalysisBoard(fen = fen)) }
            Route.Progression -> ProgressionScreen(onTrainTheme = { stack.add(Route.Puzzles(theme = it)) })
            Route.Help -> HelpScreen(onReplayTour = { tour.start() })
            Route.PositionEditor -> PositionEditorScreen { fen -> stack.add(Route.AnalysisBoard(fen = fen)) }
            is Route.Laboratory -> LabScreen(startFen = current.startFen)
            Route.Variants -> VariantListScreen { id ->
                // Le Chess960 passe par un réglage : on y choisit la position
                // par son NUMÉRO, et l'on peut jouer à deux.
                when (id) {
                    "chess960" -> stack.add(Route.Chess960Setup)
                    "duck" -> stack.add(Route.DuckGame)
                    "stolenmove" -> stack.add(Route.StolenMoveGame)
                    else -> stack.add(
                        Route.VariantGame(id, VariantCatalog.byId(id)?.let { context.getString(it.titleRes) } ?: id)
                    )
                }
            }
            Route.DuckGame -> com.chesslab.variants.DuckChessScreen(
                onAnalyze = { stack.add(Route.AnalysisBoard(fen = it)) },
            )
            Route.StolenMoveGame -> com.chesslab.variants.StolenMoveScreen(
                onAnalyze = { stack.add(Route.AnalysisBoard(fen = it)) },
            )
            Route.Chess960Setup -> com.chesslab.variants.Chess960SetupScreen { number, twoPlayer ->
                stack[stack.lastIndex] = Route.VariantGame(
                    "chess960", context.getString(R.string.variant_chess960),
                    chess960Number = number, twoPlayer = twoPlayer,
                )
            }
            is Route.VariantGame -> VariantPlayScreen(
                variantId = current.id,
                chess960Number = current.chess960Number,
                twoPlayer = current.twoPlayer,
                onAnalyze = { stack.add(Route.AnalysisBoard(fen = it)) },
            )
            else -> Placeholder(current.title(context))
        }
        }
    }
    }
    // Par-dessus les écrans ET leurs barres : à la racine, pas dans un écran.
    DiscoveryTourOverlay(tour, anchors)
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
