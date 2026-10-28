package com.chesslab.puzzles

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Autorenew
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.GpsFixed
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.Numbers
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Replay
import androidx.compose.material.icons.filled.SignalCellularAlt
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.library.LibraryDatabase
import com.chesslab.progression.PuzzleStats
import com.chesslab.ui.CardShape
import com.chesslab.ui.ChipButton
import com.chesslab.ui.IconBadge
import com.chesslab.ui.Palette
import com.chesslab.ui.QuickSwitchMenu
import com.chesslab.ui.SectionHeader
import com.chesslab.ui.TopBarActions
import com.chesslab.ui.accentGradient
import com.chesslab.ui.cardGradient
import com.chesslab.ui.subtleBorder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * L'écran Puzzles : LANCER en un geste, régler à part, Woodpecker à sa place.
 * Pendant de `PuzzleQueueView` (refonte du 28/10/2026).
 *
 * De haut en bas : où j'en suis (cote, réussite, thème à travailler) ; quatre
 * séries prêtes qui démarrent au toucher (à mon niveau, ratés, à revoir, mes
 * parties) ; « Série sur mesure », tous les filtres dans une feuille avec le
 * nombre de puzzles avant de lancer ; et le programme Woodpecker, dont la
 * création (critères compris) vit dans sa propre feuille.
 */
@OptIn(ExperimentalMaterial3Api::class)
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
    val scope = rememberCoroutineScope()
    var puzzleRating by remember { mutableStateOf(PuzzleRating()) }
    var stats by remember { mutableStateOf<PuzzleStats?>(null) }
    var missedCount by remember { mutableStateOf(0) }
    var reviewCount by remember { mutableStateOf(0) }
    var ownCount by remember { mutableStateOf(0) }
    var programme by remember { mutableStateOf<WoodpeckerProgram?>(null) }
    var confirmStop by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var sheet by remember { mutableStateOf<CriteriaMode?>(null) }

    LaunchedEffect(Unit) {
        puzzleRating = com.chesslab.settings.StatsStore.puzzleRating(context)
        val db = LibraryDatabase.get(context)
        withContext(Dispatchers.IO) {
            missedCount = runCatching { db.puzzleProgress().missedIds().size }.getOrDefault(0)
            reviewCount = runCatching { db.puzzleProgress().reviewIds().size }.getOrDefault(0)
            ownCount = runCatching { db.ownPuzzles().count() }.getOrDefault(0)
            stats = runCatching { PuzzleStats.compute(db.puzzleProgress().all()) }.getOrNull()
            programme = runCatching { db.woodpecker().active() }.getOrNull()
        }
    }

    TopBarActions {
        QuickSwitchMenu(
            onPlayVsEngine = { onPlayVsEngine() },
            onOpenTwoPlayer = { onOpenTwoPlayer() },
            onOpenLab = { onOpenLab() },
        )
    }

    com.chesslab.ui.ReadableColumn(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(22.dp),
    ) {
        stats?.takeIf { it.attempts > 0 }?.let { StatusCard(it, puzzleRating, onStart) }

        // Quatre séries qui démarrent AU TOUCHER — pas de puce à cocher puis de bouton à chercher.
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            SectionTitle(stringResource(R.string.puzzle_section_start))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                SeriesTile(
                    stringResource(R.string.puzzle_at_my_level),
                    "${puzzleRating.window.first}–${puzzleRating.window.last}",
                    Icons.Default.GpsFixed, Palette.accent, count = null, tag = "serie-mon-niveau",
                    modifier = Modifier.weight(1f),
                ) { onStart(PuzzleFilter(ratingWindow = puzzleRating.window)) }
                SeriesTile(
                    stringResource(R.string.puzzle_missed), stringResource(R.string.puzzle_tile_missed_sub),
                    Icons.Default.Cancel, Palette.rose, count = missedCount, tag = "historique-rates",
                    modifier = Modifier.weight(1f),
                ) { onStart(PuzzleFilter(missedOnly = true)) }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                SeriesTile(
                    stringResource(R.string.puzzle_review), stringResource(R.string.puzzle_tile_review_sub),
                    Icons.Default.Replay, Palette.warning, count = reviewCount, tag = "historique-a-revoir",
                    modifier = Modifier.weight(1f),
                ) { onStart(PuzzleFilter(reviewOnly = true)) }
                SeriesTile(
                    stringResource(PuzzleSource.ownGames.labelRes), stringResource(R.string.puzzle_tile_own_sub),
                    Icons.Default.Person, Palette.violet, count = ownCount, tag = "serie-mes-parties",
                    modifier = Modifier.weight(1f),
                ) { onStart(PuzzleFilter(source = PuzzleSource.ownGames)) }
            }
        }

        LinkRow(
            Icons.Default.Tune, Palette.info,
            stringResource(R.string.puzzle_custom_title), stringResource(R.string.puzzle_custom_sub),
            tag = "serie-sur-mesure",
        ) { sheet = CriteriaMode.session }

        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            SectionTitle(stringResource(R.string.puzzle_section_programme))
            val running = programme
            val plan = running?.plan
            if (running != null && plan != null) {
                RunningProgramme(running, plan, onResume = { onOpenWoodpecker(running.id) }, onStop = { confirmStop = true })
            } else {
                LinkRow(
                    Icons.Default.Autorenew, Palette.teal,
                    stringResource(R.string.woodpecker_title), stringResource(R.string.woodpecker_row_sub),
                    tag = "woodpecker-carte",
                ) { sheet = CriteriaMode.woodpecker }
            }
        }
    }

    sheet?.let { mode ->
        val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(
            onDismissRequest = { sheet = null },
            sheetState = state,
            containerColor = Palette.background,
        ) {
            CriteriaSheet(mode, puzzleRating) { filter, size ->
                when (mode) {
                    CriteriaMode.session -> {
                        sheet = null
                        onStart(filter)
                    }
                    CriteriaMode.woodpecker -> scope.launch {
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
                                criteria = context.getString(R.string.woodpecker_criteria, plan.items.size) +
                                    " · " + summaryOf(context, filter),
                                planJson = plan.toJson(),
                            )
                            withContext(Dispatchers.IO) { LibraryDatabase.get(app).woodpecker().put(created) }
                            programme = created
                            sheet = null
                            onOpenWoodpecker(created.id)
                        }
                    }
                }
            }
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
                        val running = programme ?: return@TextButton
                        programme = null
                        scope.launch(Dispatchers.IO) {
                            LibraryDatabase.get(context).woodpecker()
                                .put(running.copy(archived = true, updatedAt = System.currentTimeMillis()))
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

/** Cote, réussite, et le thème le plus raté — qu'un toucher met au travail. */
@Composable
private fun StatusCard(stats: PuzzleStats, rating: PuzzleRating, onStart: (PuzzleFilter) -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(cardGradient)
            .subtleBorder()
            .padding(16.dp)
            .testTag("cote-puzzle"),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.Bottom) {
            if (rating.count > 0) {
                Column {
                    Text(stringResource(R.string.puzzle_your_rating), fontSize = 12.sp, color = Palette.textSecondary)
                    Text(
                        (if (rating.isSettled) "" else "≈ ") + rating.displayed,
                        fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Palette.accent,
                    )
                }
            }
            Spacer(Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.End) {
                Text(stringResource(R.string.puzzle_success), fontSize = 12.sp, color = Palette.textSecondary)
                Text(
                    stats.successRate?.let { "${kotlin.math.round(it * 100).toInt()}" + stringResource(R.string.percent_suffix) } ?: "—",
                    fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary,
                )
            }
        }
        stats.weakestThemes.firstOrNull()?.let { weakest ->
            HorizontalDivider(color = Palette.stroke)
            val kind = PuzzleThemeKind.entries.firstOrNull { it.raw == weakest.theme }
            Row(
                Modifier
                    .fillMaxWidth()
                    .clickable(enabled = kind != null) { kind?.let { onStart(PuzzleFilter(theme = it)) } }
                    .testTag("travailler-theme"),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(stringResource(R.string.puzzle_to_work_on) + " ", fontSize = 14.sp, color = Palette.textSecondary)
                Text(
                    stringResource(weakest.labelRes), fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                    color = Palette.textPrimary, modifier = Modifier.weight(1f),
                )
                Text(
                    stringResource(R.string.puzzle_failure_rate, kotlin.math.round(weakest.failureRate * 100).toInt()),
                    fontSize = 12.sp, color = Palette.textTertiary,
                )
                Icon(Icons.Default.ChevronRight, null, tint = Palette.textTertiary, modifier = Modifier.size(18.dp))
            }
        }
    }
}

/** Une série prête : elle démarre au toucher. Son compte s'affiche ; à zéro, elle est grisée. */
@Composable
private fun SeriesTile(
    title: String,
    subtitle: String,
    icon: ImageVector,
    tint: Color,
    count: Int?,
    tag: String,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val empty = count == 0
    val shape = RoundedCornerShape(16.dp)
    Column(
        modifier
            .clip(shape)
            .background(tint.copy(alpha = 0.10f))
            .border(1.dp, tint.copy(alpha = 0.30f), shape)
            .clickable(enabled = !empty, onClick = onClick)
            .alpha(if (empty) 0.4f else 1f)
            .padding(14.dp)
            .testTag(tag),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(22.dp))
            Spacer(Modifier.weight(1f))
            if (count != null) {
                Text(
                    "$count", fontSize = 14.sp, fontWeight = FontWeight.Bold,
                    color = if (count > 0) tint else Palette.textTertiary,
                )
            }
        }
        Column {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary, maxLines = 1)
            Text(subtitle, fontSize = 12.sp, color = Palette.textSecondary, maxLines = 1)
        }
    }
}

@Composable
private fun SectionTitle(title: String) {
    Text(
        title.uppercase(), fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
        color = Palette.textSecondary, letterSpacing = 0.4.sp,
    )
}

@Composable
private fun LinkRow(icon: ImageVector, tint: Color, title: String, subtitle: String, tag: String, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(cardGradient)
            .subtleBorder()
            .clickable(onClick = onClick)
            .padding(14.dp)
            .testTag(tag),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        IconBadge(icon, tint, 40.dp)
        Column(Modifier.weight(1f)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
            Text(subtitle, fontSize = 12.sp, color = Palette.textSecondary)
        }
        Icon(Icons.Default.ChevronRight, null, tint = Palette.textTertiary, modifier = Modifier.size(18.dp))
    }
}

/** Un programme en cours : où il en est, et la reprise d'un toucher. */
@Composable
private fun RunningProgramme(program: WoodpeckerProgram, plan: WoodpeckerPlan, onResume: () -> Unit, onStop: () -> Unit) {
    val cycle = plan.currentCycle
    Column(
        Modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(cardGradient)
            .subtleBorder()
            .padding(16.dp)
            .testTag("woodpecker-programme"),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            IconBadge(Icons.Default.Autorenew, Palette.teal, 40.dp)
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.woodpecker_title), fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
                Text(
                    if (cycle.isComplete) stringResource(R.string.woodpecker_cycle_done, cycle.number)
                    else stringResource(R.string.woodpecker_progress, cycle.number, cycle.attempts.size, cycle.order.size),
                    fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.accent,
                )
                Text(program.criteria, fontSize = 12.sp, color = Palette.textTertiary, maxLines = 1)
            }
        }
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
                    .clickable(onClick = onResume)
                    .padding(vertical = 10.dp)
                    .testTag("woodpecker-reprendre"),
            )
            Spacer(Modifier.width(12.dp))
            Text(
                stringResource(R.string.woodpecker_stop),
                fontSize = 14.sp, color = Palette.danger,
                modifier = Modifier
                    .clip(CircleShape)
                    .clickable(onClick = onStop)
                    .padding(horizontal = 10.dp, vertical = 8.dp)
                    .testTag("woodpecker-arreter"),
            )
        }
    }
}

/** Ce que la feuille de critères prépare. Pendant de `CriteriaSheetMode`. */
private enum class CriteriaMode { session, woodpecker }

/**
 * Tous les filtres, dans une feuille : niveau, phase, type, provenance. Rien de
 * coché = tout. Le nombre de puzzles s'affiche avant de lancer ; en mode
 * Woodpecker, on choisit aussi la taille du lot. Pendant de `PuzzleCriteriaSheet`.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CriteriaSheet(mode: CriteriaMode, rating: PuzzleRating, onConfirm: (PuzzleFilter, Int) -> Unit) {
    val context = LocalContext.current
    var difficulty by remember { mutableStateOf<DifficultyTier?>(null) }
    var atMyLevel by remember { mutableStateOf(false) }
    var phase by remember { mutableStateOf<GamePhase?>(null) }
    var theme by remember { mutableStateOf<PuzzleThemeKind?>(null) }
    var source by remember { mutableStateOf<PuzzleSource?>(null) }
    var size by remember { mutableStateOf(WoodpeckerPlan.DEFAULT_SIZE) }
    var matching by remember { mutableStateOf<Int?>(null) }
    var busy by remember { mutableStateOf(false) }
    val filter = PuzzleFilter(
        difficulty = difficulty, phase = phase, theme = theme, source = source,
        ratingWindow = if (atMyLevel) rating.window else null,
    )

    LaunchedEffect(filter) {
        matching = null
        matching = withContext(Dispatchers.Default) {
            val own = if (filter.source == PuzzleSource.lichess) 0 else runCatching {
                LibraryDatabase.get(context).ownPuzzles().all().map { it.toPuzzle() }
                    .count { PuzzleAnswer.accepts(it, filter, isOwn = true) }
            }.getOrDefault(0)
            val library = if (filter.source == PuzzleSource.ownGames) 0 else runCatching {
                PuzzleRepository.count(context.assets, filter.ratings, filter.theme?.raw, filter.phase?.raw)
            }.getOrDefault(0)
            own + library
        }
    }

    Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                stringResource(if (mode == CriteriaMode.session) R.string.puzzle_custom_title else R.string.woodpecker_title),
                fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary, modifier = Modifier.weight(1f),
            )
            val anySet = difficulty != null || atMyLevel || phase != null || theme != null || source != null
            TextButton(
                onClick = { difficulty = null; atMyLevel = false; phase = null; theme = null; source = null },
                enabled = anySet,
            ) { Text(stringResource(R.string.puzzle_reset), color = if (anySet) Palette.accent else Palette.textTertiary) }
        }
        Column(
            Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            if (mode == CriteriaMode.woodpecker) {
                Text(stringResource(R.string.woodpecker_sheet_intro), fontSize = 13.sp, color = Palette.textSecondary)
            }
            // Vos puzzles n'ont pas de cote : un niveau les exclurait tous.
            if (source != PuzzleSource.ownGames) Group(stringResource(R.string.puzzle_level), Icons.Default.SignalCellularAlt, Palette.accent) {
                ChipButton(stringResource(R.string.puzzle_at_my_level), atMyLevel, Modifier.testTag("niveau-mien"), tint = Palette.accent) {
                    atMyLevel = !atMyLevel
                    if (atMyLevel) difficulty = null
                }
                DifficultyTier.entries.forEach { tier ->
                    ChipButton(stringResource(tier.labelRes), difficulty == tier, Modifier.testTag("niveau-${tier.name}"), tint = tier.tint) {
                        difficulty = if (difficulty == tier) null else tier
                        atMyLevel = false
                    }
                }
            }
            Group(stringResource(R.string.puzzle_phase), Icons.Default.Flag, Palette.info) {
                GamePhase.entries.forEach { value ->
                    ChipButton(stringResource(value.labelRes), phase == value, Modifier.testTag("phase-${value.name}"), icon = value.icon, tint = Palette.info) {
                        phase = if (phase == value) null else value
                    }
                }
            }
            Group(stringResource(R.string.puzzle_type), Icons.Default.Extension, Palette.warning) {
                PuzzleThemeKind.entries.forEach { value ->
                    ChipButton(
                        // « Attaque à la découverte » déborde à côté des autres puces :
                        // raccourci ICI SEULEMENT, comme iOS.
                        stringResource(if (value.labelRes == R.string.theme_discovered) R.string.theme_discovered_short else value.labelRes),
                        theme == value, Modifier.testTag("theme-${value.name}"), icon = value.icon, tint = Palette.warning,
                    ) { theme = if (theme == value) null else value }
                }
            }
            Group(stringResource(R.string.puzzle_provenance), Icons.Default.Layers, Palette.violet) {
                PuzzleSource.entries.forEach { value ->
                    ChipButton(stringResource(value.labelRes), source == value, Modifier.testTag("provenance-${value.name}"), icon = value.icon, tint = Palette.violet) {
                        source = if (source == value) null else value
                        if (source == PuzzleSource.ownGames) { difficulty = null; atMyLevel = false }
                    }
                }
            }
            if (mode == CriteriaMode.woodpecker) {
                Group(stringResource(R.string.puzzle_lot_size), Icons.Default.Numbers, Palette.teal) {
                    WoodpeckerPlan.SIZES.forEach { value ->
                        ChipButton("$value", size == value, Modifier.testTag("woodpecker-taille-$value"), tint = Palette.teal) { size = value }
                    }
                }
            }
            Spacer(Modifier.height(4.dp))
        }

        val count = matching
        val enabled = count != null && count > 0 && !busy
        Spacer(Modifier.height(12.dp))
        Text(
            summaryOf(context, filter), fontSize = 11.sp, color = Palette.textTertiary,
            textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        Text(
            when {
                mode == CriteriaMode.woodpecker -> stringResource(R.string.woodpecker_create)
                count == null -> stringResource(R.string.puzzle_start_session)
                // Groupé selon la langue (« 130 935 »), comme le fait iOS.
                else -> stringResource(R.string.puzzle_start_count, java.text.NumberFormat.getIntegerInstance().format(count))
            },
            fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .alpha(if (enabled) 1f else 0.4f)
                .clip(CircleShape)
                .background(accentGradient)
                .clickable(enabled = enabled) {
                    if (mode == CriteriaMode.woodpecker) busy = true
                    onConfirm(filter, size)
                }
                .padding(vertical = 14.dp)
                .testTag(if (mode == CriteriaMode.session) "commencer-puzzles" else "woodpecker-creer"),
        )
        Spacer(Modifier.height(24.dp))
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Group(title: String, icon: ImageVector, tint: Color, content: @Composable FlowRowScope.() -> Unit) {
    Column {
        SectionHeader(title, icon = icon, tint = tint)
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            content = content,
        )
    }
}

/** La sélection en une ligne — aussi le libellé d'un programme Woodpecker. Pendant de `PuzzleCriteriaSheet.summary`. */
private fun summaryOf(context: android.content.Context, filter: PuzzleFilter): String {
    val parts = listOfNotNull(
        filter.source?.let { context.getString(it.labelRes) },
        if (filter.missedOnly) context.getString(R.string.puzzle_missed) else null,
        if (filter.reviewOnly) context.getString(R.string.puzzle_review) else null,
        filter.difficulty?.let { context.getString(it.labelRes) },
        filter.phase?.let { context.getString(it.labelRes) },
        filter.theme?.let { context.getString(it.labelRes) },
        filter.ratingWindow?.let { context.getString(R.string.puzzle_at_my_level) + " (${it.first}–${it.last})" },
    )
    return if (parts.isEmpty()) context.getString(R.string.puzzle_all_puzzles) else parts.joinToString(" · ")
}
