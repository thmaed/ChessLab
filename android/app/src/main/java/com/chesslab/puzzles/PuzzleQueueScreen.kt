package com.chesslab.puzzles

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.SignalCellularAlt
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.material.icons.filled.Autorenew
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.foundation.border
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import com.chesslab.R
import com.chesslab.library.LibraryDatabase
import com.chesslab.progression.PuzzleStats
import com.chesslab.ui.ChipButton
import com.chesslab.ui.Palette
import com.chesslab.ui.QuickSwitchMenu
import com.chesslab.ui.SectionHeader
import com.chesslab.ui.TopBarActions
import com.chesslab.ui.accentGradient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Le choix de la SÉANCE, avant de résoudre. Pendant de `PuzzleQueueView`.
 *
 * Les filtres vivaient en tiroir au-dessus du plateau : on les ouvrait, on
 * choisissait, et le puzzle courant changeait sous les doigts. iOS demande
 * d'abord ce qu'on veut travailler — niveau, phase, type — puis lance la
 * séance ; c'est un écran de DÉCISION, et il a la place de montrer les trois
 * familles en entier plutôt qu'une ligne qui défile.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PuzzleQueueScreen(
    onStart: (PuzzleFilter) -> Unit,
    onPlayVsEngine: () -> Unit = {},
    onOpenTwoPlayer: () -> Unit = {},
    onOpenLab: () -> Unit = {},
    /** Ouvre un programme Woodpecker (créé ici, ou repris). */
    onOpenWoodpecker: (String) -> Unit = {},
) {
    val context = LocalContext.current
    var difficulty by remember { mutableStateOf<DifficultyTier?>(null) }
    var phase by remember { mutableStateOf<GamePhase?>(null) }
    var theme by remember { mutableStateOf<PuzzleThemeKind?>(null) }
    var source by remember { mutableStateOf<PuzzleSource?>(null) }
    var missedOnly by remember { mutableStateOf(false) }
    // Ratés à la dernière tentative : à zéro, la puce « Ratés » est grisée.
    var missedCount by remember { mutableStateOf(0) }
    // « À mon niveau » : la cote personnelle fixe la fenêtre de puzzles.
    var atMyLevel by remember { mutableStateOf(false) }
    var puzzleRating by remember { mutableStateOf(PuzzleRating()) }
    var stats by remember { mutableStateOf<PuzzleStats?>(null) }

    LaunchedEffect(Unit) {
        puzzleRating = com.chesslab.settings.StatsStore.puzzleRating(context)
        missedCount = withContext(Dispatchers.IO) {
            runCatching { LibraryDatabase.get(context).puzzleProgress().missedIds().size }.getOrDefault(0)
        }
        if (missedCount == 0) missedOnly = false
        stats = withContext(Dispatchers.IO) {
            runCatching {
                PuzzleStats.compute(LibraryDatabase.get(context).puzzleProgress().all())
            }.getOrNull()
        }
    }

    TopBarActions {
        QuickSwitchMenu(
            onPlayVsEngine = { onPlayVsEngine() },
            onOpenTwoPlayer = { onOpenTwoPlayer() },
            onOpenLab = { onOpenLab() },
        )
    }

    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            // Chaque groupe a SA couleur — la provenance en violet, l'historique
            // en rose, le niveau en vert, la phase en bleu, le thème en ambre —
            // et chaque puce son icône. Des rangées de puces toutes vertes se
            // ressemblent trop pour qu'on retrouve la sienne d'un coup d'œil ;
            // c'est le parti pris d'iOS.
            Group(stringResource(R.string.puzzle_provenance), Icons.Default.Layers, Palette.violet) {
                ChipButton(stringResource(R.string.filter_all_f), source == null,
                    Modifier.testTag("provenance-toutes"), tint = Palette.violet) { source = null }
                PuzzleSource.entries.forEach { value ->
                    ChipButton(
                        stringResource(value.labelRes), source == value,
                        Modifier.testTag("provenance-${value.name}"),
                        icon = value.icon, tint = Palette.violet,
                    ) {
                        source = if (source == value) null else value
                        // Vos puzzles n'ont pas de cote : un niveau choisi
                        // les exclurait TOUS.
                        if (source == PuzzleSource.ownGames) difficulty = null
                    }
                }
            }
            Group(stringResource(R.string.puzzle_history), Icons.Default.History, Palette.rose) {
                ChipButton(stringResource(R.string.filter_all), !missedOnly,
                    Modifier.testTag("historique-tous"), tint = Palette.rose) { missedOnly = false }
                ChipButton(
                    stringResource(R.string.puzzle_missed), missedOnly,
                    Modifier.testTag("historique-rates"),
                    icon = Icons.Default.Cancel, tint = Palette.rose,
                    enabled = missedCount > 0,
                ) { missedOnly = !missedOnly }
            }
            // Masqué pour « Mes parties » : sans cote, aucun niveau ne
            // retiendrait un seul puzzle.
            if (source != PuzzleSource.ownGames) Group(stringResource(R.string.puzzle_level), Icons.Default.SignalCellularAlt, Palette.accent) {
                ChipButton(stringResource(R.string.filter_all), difficulty == null && !atMyLevel,
                    Modifier.testTag("niveau-tous"), tint = Palette.accent) { difficulty = null; atMyLevel = false }
                // Ma cote, plutôt qu'un palier : les puzzles se resserrent
                // autour de ce que je réussis. Pendant de `niveau-mien` (iOS).
                ChipButton(stringResource(R.string.puzzle_at_my_level), atMyLevel,
                    Modifier.testTag("niveau-mien"), tint = Palette.accent) {
                    atMyLevel = !atMyLevel
                    if (atMyLevel) difficulty = null
                }
                DifficultyTier.entries.forEach { tier ->
                    ChipButton(
                        stringResource(tier.labelRes), difficulty == tier,
                        Modifier.testTag("niveau-${tier.name}"), tint = tier.tint,
                    ) { difficulty = if (difficulty == tier) null else tier; atMyLevel = false }
                }
            }
            Group(stringResource(R.string.puzzle_phase), Icons.Default.Flag, Palette.info) {
                ChipButton(stringResource(R.string.filter_all_f), phase == null,
                    Modifier.testTag("phase-toutes"), tint = Palette.info) { phase = null }
                GamePhase.entries.forEach { value ->
                    ChipButton(
                        stringResource(value.labelRes), phase == value,
                        Modifier.testTag("phase-${value.name}"),
                        icon = value.icon, tint = Palette.info,
                    ) { phase = if (phase == value) null else value }
                }
            }
            Group(stringResource(R.string.puzzle_type), Icons.Default.Extension, Palette.warning) {
                ChipButton(stringResource(R.string.filter_all), theme == null,
                    Modifier.testTag("theme-tous"), tint = Palette.warning) { theme = null }
                PuzzleThemeKind.entries.forEach { value ->
                    ChipButton(
                        // « Attaque à la découverte » déborde à côté des
                        // autres puces : raccourci ICI SEULEMENT, comme iOS.
                        // Le libellé entier reste sur l'écran de résolution.
                        stringResource(
                            if (value.labelRes == R.string.theme_discovered) R.string.theme_discovered_short
                            else value.labelRes
                        ),
                        theme == value,
                        Modifier.testTag("theme-${value.name}"),
                        icon = value.icon, tint = Palette.warning,
                    ) { theme = if (theme == value) null else value }
                }
            }
            WoodpeckerCard(
                filter = PuzzleFilter(difficulty, phase, theme, source, missedOnly),
                criteria = summary(source, missedOnly, difficulty, phase, theme, if (atMyLevel) puzzleRating.window else null),
                onOpen = onOpenWoodpecker,
            )
            stats?.takeIf { it.attempts > 0 }?.let { PuzzleStatsCard(it) }
            if (puzzleRating.count > 0) {
                Row(Modifier.fillMaxWidth().testTag("cote-puzzle"), verticalAlignment = Alignment.CenterVertically) {
                    Text(stringResource(R.string.puzzle_rating), fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                        color = Palette.textSecondary, modifier = Modifier.weight(1f))
                    Text((if (puzzleRating.isSettled) "" else "≈ ") + puzzleRating.displayed,
                        fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Palette.accent)
                }
            }
        }

        // Le pied est ÉPINGLÉ : « Commencer » reste accessible quel que soit
        // le défilement, sur un petit écran comme sur un grand.
        Column(
            Modifier
                .fillMaxWidth()
                .background(Palette.background)
                .padding(horizontal = 20.dp)
                .padding(top = 12.dp, bottom = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                summary(source, missedOnly, difficulty, phase, theme, if (atMyLevel) puzzleRating.window else null),
                fontSize = 11.sp, color = Palette.textTertiary,
                modifier = Modifier.testTag("resume-selection"),
            )
            Spacer(Modifier.height(10.dp))
            Text(
                stringResource(R.string.puzzle_start_session),
                fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(CircleShape)
                    .background(accentGradient)
                    .clickable { onStart(PuzzleFilter(difficulty, phase, theme, source, missedOnly, if (atMyLevel) puzzleRating.window else null)) }
                    .padding(vertical = 14.dp)
                    .testTag("commencer-puzzles"),
                textAlign = TextAlign.Center,
            )
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Group(
    title: String,
    icon: ImageVector,
    tint: Color,
    content: @Composable FlowRowScope.() -> Unit,
) {
    Column {
        SectionHeader(title, icon = icon, tint = tint)
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            content = content,
        )
    }
}

/** « Tous les puzzles », ou ce qu'on a choisi, en une ligne. */
@Composable
private fun summary(
    source: PuzzleSource?,
    missedOnly: Boolean,
    difficulty: DifficultyTier?,
    phase: GamePhase?,
    theme: PuzzleThemeKind?,
    ratingWindow: IntRange? = null,
): String {
    val parts = listOfNotNull(
        source?.let { stringResource(it.labelRes) },
        if (missedOnly) stringResource(R.string.puzzle_missed) else null,
        difficulty?.let { stringResource(it.labelRes) },
        ratingWindow?.let { stringResource(R.string.puzzle_at_my_level) + " (${it.first}–${it.last})" },
        phase?.let { stringResource(it.labelRes) },
        theme?.let { stringResource(it.labelRes) },
    )
    return if (parts.isEmpty()) stringResource(R.string.puzzle_all_puzzles)
    else parts.joinToString(" · ")
}

/**
 * La méthode Woodpecker : un lot FIXE, repris en cycles de plus en plus
 * rapides (voir [WoodpeckerPlan]). Un seul programme en cours à la fois — la
 * carte propose de le reprendre, sinon d'en créer un avec les critères choisis
 * au-dessus. Pendant de `woodpeckerCard` dans `PuzzleQueueView`.
 */
@Composable
private fun WoodpeckerCard(filter: PuzzleFilter, criteria: String, onOpen: (String) -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var active by remember { mutableStateOf<WoodpeckerProgram?>(null) }
    var size by remember { mutableStateOf(WoodpeckerPlan.DEFAULT_SIZE) }
    var confirmStop by remember { mutableStateOf(false) }
    var creating by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) {
        active = withContext(Dispatchers.IO) {
            runCatching { LibraryDatabase.get(context).woodpecker().active() }.getOrNull()
        }
    }

    Column(
        Modifier
            .fillMaxWidth()
            .clip(androidx.compose.foundation.shape.RoundedCornerShape(18.dp))
            .background(Palette.surface)
            .padding(16.dp)
            .testTag("woodpecker-carte"),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            // Le symbole de cycle d'iOS (`arrow.triangle.2.circlepath`).
            androidx.compose.material3.Icon(
                Icons.Default.Autorenew, null, tint = Palette.textPrimary, modifier = Modifier.size(18.dp),
            )
            Spacer(Modifier.width(8.dp))
            Text(
                stringResource(R.string.woodpecker_title),
                fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
            )
        }
        val program = active
        val plan = program?.plan
        if (program != null && plan != null) {
            val cycle = plan.currentCycle
            Text(program.criteria, fontSize = 12.sp, color = Palette.textSecondary)
            Text(
                if (cycle.isComplete) stringResource(R.string.woodpecker_cycle_done, cycle.number)
                else stringResource(R.string.woodpecker_progress, cycle.number, cycle.attempts.size, cycle.order.size),
                fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.accent,
            )
            plan.cycles.lastOrNull { it.isComplete }?.let { finished ->
                Text(
                    stringResource(
                        R.string.woodpecker_previous_line, finished.number, finished.solvedCount,
                        finished.order.size, WoodpeckerPlan.formatDuration(finished.activeSeconds),
                    ),
                    fontSize = 12.sp, color = Palette.textTertiary,
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    if (cycle.isComplete) stringResource(R.string.woodpecker_start_cycle, cycle.number + 1)
                    else stringResource(R.string.woodpecker_resume),
                    fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .clip(CircleShape)
                        .background(accentGradient)
                        .clickable { onOpen(program.id) }
                        .padding(vertical = 10.dp)
                        .testTag("woodpecker-reprendre"),
                )
                Spacer(Modifier.width(12.dp))
                Text(
                    stringResource(R.string.woodpecker_stop),
                    fontSize = 14.sp, color = Palette.danger,
                    modifier = Modifier
                        .clip(CircleShape)
                        .clickable { confirmStop = true }
                        .padding(horizontal = 10.dp, vertical = 8.dp)
                        .testTag("woodpecker-arreter"),
                )
            }
        } else {
            Text(stringResource(R.string.woodpecker_intro), fontSize = 12.sp, color = Palette.textSecondary)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                WoodpeckerPlan.SIZES.forEach { value ->
                    ChipButton(
                        "$value", size == value,
                        Modifier.testTag("woodpecker-taille-$value"), tint = Palette.accent,
                    ) { size = value }
                }
            }
            Text(
                stringResource(R.string.woodpecker_create),
                fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(CircleShape)
                    .border(1.dp, Palette.stroke, CircleShape)
                    .clickable(enabled = !creating) {
                        creating = true
                        scope.launch {
                            val app = context.applicationContext as android.app.Application
                            val own = withContext(Dispatchers.IO) {
                                runCatching { LibraryDatabase.get(app).ownPuzzles().all() }.getOrDefault(emptyList())
                            }
                            val puzzles = PuzzleDraw.draw(app, filter, own, count = size)
                            val plan = WoodpeckerPlan.start(puzzles.map { WoodpeckerPlan.Item.of(it) })
                            if (plan == null) {
                                message = context.getString(R.string.woodpecker_none_match)
                            } else {
                                val now = System.currentTimeMillis()
                                val created = WoodpeckerProgram(
                                    id = java.util.UUID.randomUUID().toString(),
                                    createdAt = now, updatedAt = now,
                                    criteria = context.getString(R.string.woodpecker_criteria, plan.items.size) + " · " + criteria,
                                    planJson = plan.toJson(),
                                )
                                withContext(Dispatchers.IO) { LibraryDatabase.get(app).woodpecker().put(created) }
                                active = created
                                onOpen(created.id)
                            }
                            creating = false
                        }
                    }
                    .padding(vertical = 10.dp)
                    .testTag("woodpecker-creer"),
            )
        }
    }

    if (confirmStop) {
        AlertDialog(
            onDismissRequest = { confirmStop = false },
            title = { Text(stringResource(R.string.woodpecker_stop_title)) },
            text = { Text(stringResource(R.string.woodpecker_stop_body)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        confirmStop = false
                        val program = active ?: return@TextButton
                        active = null
                        scope.launch(Dispatchers.IO) {
                            LibraryDatabase.get(context).woodpecker()
                                .put(program.copy(archived = true, updatedAt = System.currentTimeMillis()))
                        }
                    },
                    modifier = Modifier.testTag("woodpecker-arreter-oui"),
                ) { Text(stringResource(R.string.woodpecker_stop_confirm), color = Palette.danger) }
            },
            dismissButton = {
                TextButton(onClick = { confirmStop = false }) { Text(stringResource(R.string.cancel)) }
            },
            containerColor = Palette.surfaceElevated,
        )
    }
    message?.let {
        AlertDialog(
            onDismissRequest = { message = null },
            confirmButton = { TextButton(onClick = { message = null }) { Text("OK", color = Palette.accent) } },
            text = { Text(it) },
            containerColor = Palette.surfaceElevated,
        )
    }
}
