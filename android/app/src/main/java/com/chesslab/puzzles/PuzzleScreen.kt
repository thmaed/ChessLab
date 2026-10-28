package com.chesslab.puzzles

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material.icons.filled.Extension
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.material3.*
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import chesskit.Piece
import com.chesslab.R
import com.chesslab.play.PromotionDialog
import com.chesslab.ui.*
import com.chesslab.ui.QuickSwitchMenu
import com.chesslab.ui.TopBarActions

/**
 * Résoudre un puzzle. Pendant de `PuzzleSolveView`.
 *
 * Deux lignes d'en-tête, et pas quatre : la CONSIGNE seule en gros, puis tout
 * le contexte — thème, difficulté, phase, avancement — sur une ligne discrète.
 * Empilées, aucune ne ressortait et le regard devait toutes les lire pour
 * trouver celle qui dit quoi faire.
 */
@Composable
fun PuzzleScreen(
    /** Un thème imposé à l'ouverture — depuis « à travailler » de la progression. */
    initialTheme: String? = null,
    /** La séance choisie sur l'écran précédent. */
    filter: PuzzleFilter? = null,
    onPlayVsEngine: (String) -> Unit = {},
    onOpenTwoPlayer: (String) -> Unit = {},
    onOpenLab: (String) -> Unit = {},
    /** Revoir la faute DANS sa partie : le PGN d'origine part vers l'analyse. */
    onViewSourceGame: (String) -> Unit = {},
    /** Un programme Woodpecker à jouer, à la place d'une série. */
    woodpeckerId: String? = null,
    model: PuzzleViewModel = viewModel(),
) {
    val ui = model.ui
    LaunchedEffect(initialTheme, filter, woodpeckerId) {
        when {
            woodpeckerId != null -> model.openWoodpecker(woodpeckerId)
            initialTheme != null -> model.trainTheme(initialTheme)
            filter != null -> model.setFilter(filter)
        }
    }
    // Le chrono d'un programme ne compte que le temps ACTIF.
    val owner = androidx.lifecycle.compose.LocalLifecycleOwner.current
    DisposableEffect(owner) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            when (event) {
                androidx.lifecycle.Lifecycle.Event.ON_PAUSE -> model.pauseClock()
                androidx.lifecycle.Lifecycle.Event.ON_RESUME -> model.resumeClock()
                else -> Unit
            }
        }
        owner.lifecycle.addObserver(observer)
        onDispose {
            owner.lifecycle.removeObserver(observer)
            model.pauseClock()
        }
    }

    TopBarActions {
        QuickSwitchMenu(
            onPlayVsEngine = { onPlayVsEngine(model.ui.position.fen) },
            onOpenTwoPlayer = { onOpenTwoPlayer(model.ui.position.fen) },
            onOpenLab = { onOpenLab(model.ui.position.fen) },
        )
    }

    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        // Les filtres, la provenance et le bilan ont quitté cet écran pour
        // celui du CHOIX de la séance : on décide ce qu'on travaille avant de
        // résoudre, et le puzzle courant ne change plus sous les doigts. Ne
        // reste ici que le compte des révisions.
        DueBadge(ui)
        // Série VIDE (aucun raté, aucun puzzle maison, rien pour ces critères) :
        // on le DIT, comme l'écran vide d'iOS. Le plateau de l'ancien puzzle
        // restait affiché sous « Trouvez le meilleur coup », et le message
        // d'état — préparé par le view model — n'était montré nulle part.
        if (!ui.loading && ui.puzzle == null) {
            EmptySeries(ui.status)
            return@Column
        }
        Header(ui)
        ui.woodpeckerPlan?.let { WoodpeckerLine(it, ui.outcome == PuzzleOutcome.solving, model) }
        Spacer(Modifier.height(12.dp))

        BoardView(
            position = ui.position,
            orientation = ui.orientation,
            selected = ui.selected,
            legalTargets = ui.legalTargets,
            lastMove = ui.lastMove,
            checkedKing = ui.checkedKing,
            hint = ui.hint,
            // On ne traîne que les pièces du camp à qui l'on demande de
            // trouver : glisser une pièce adverse n'est pas une réponse.
            draggableColor = ui.position.sideToMove,
            enabled = ui.outcome == PuzzleOutcome.solving && !ui.busy,
            onSquareTap = model::onSquareTap,
        )

        Spacer(Modifier.height(14.dp))
        if (ui.outcome == PuzzleOutcome.solving) {
            AttemptsIndicator(ui.attemptsLeft, ui.allowedAttempts)
            if (ui.hint == null) {
                Spacer(Modifier.height(12.dp))
                HintButton { model.showHint() }
            }
            // Pas de « Passer » dans un programme : chaque puzzle du lot
            // reçoit une réponse, comme sur iOS.
            if (ui.woodpeckerPlan == null) {
                Spacer(Modifier.height(12.dp))
                TextButton(onClick = model::next, modifier = Modifier.testTag("passer")) {
                    Text(stringResource(R.string.puzzle_skip), color = Palette.textSecondary)
                }
            }
        } else {
            val plan = ui.woodpeckerPlan
            ResultCard(
                solved = ui.outcome == PuzzleOutcome.solved,
                // Un puzzle partiel revient vite : le dire, plutôt que de laisser
                // « Résolu ! » promettre un puzzle acquis (pas dans un programme).
                partial = ui.result == PuzzleResult.partial && plan == null,
                modifier = Modifier.padding(horizontal = 20.dp),
                onNext = if (plan?.currentCycle?.isComplete == true) model::startNextCycle else model::next,
                sourcePgn = ui.puzzle?.sourcePgn,
                onViewSourceGame = onViewSourceGame,
                nextLabel = when {
                    plan == null -> stringResource(R.string.puzzle_next)
                    plan.currentCycle.isComplete ->
                        stringResource(R.string.woodpecker_start_cycle, plan.currentCycle.number + 1)
                    else -> stringResource(R.string.woodpecker_next_puzzle)
                },
                cycleSummary = plan?.takeIf { it.currentCycle.isComplete },
            )
        }
    }

    if (ui.pendingPromotion != null) {
        PromotionDialog(onPick = model::completePromotion, onCancel = model::cancelPromotion)
    }
}

/**
 * Les filtres : difficulté, phase, thème. Sans eux, on tire dans 106 094
 * positions au hasard ; avec, on travaille une faiblesse précise — les
 * fourchettes, les finales — et c'est tout l'intérêt d'une base de cette
 * taille.
 *
 * Une seule ligne qui défile, pas trois : trois rangées de puces mangeraient
 * le plateau, et c'est le plateau qu'on vient voir.
 */
@Composable
private fun DueBadge(ui: PuzzleUiState) {
    if (ui.dueCount <= 0) return
    Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp), horizontalArrangement = Arrangement.End) {
        Text(
            pluralStringResource(R.plurals.puzzle_due, ui.dueCount, ui.dueCount),
            fontSize = 11.sp, color = Palette.warning,
            modifier = Modifier.testTag("a-revoir"),
        )
    }
}

@Composable
private fun FilterBar(ui: PuzzleUiState, onFilter: (PuzzleFilter) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            stringResource(R.string.puzzle_filters) +
                if (ui.filter.isEmpty) "" else " ·",
            fontSize = 12.sp,
            color = if (ui.filter.isEmpty) Palette.textTertiary else Palette.accent,
            modifier = Modifier
                .clip(CircleShape)
                .clickable { open = !open }
                .padding(horizontal = 8.dp, vertical = 4.dp)
                .testTag("filtres"),
        )
        // Ce qui est actif se lit sans ouvrir le tiroir.
        listOfNotNull(
            ui.filter.difficulty?.labelRes,
            ui.filter.phase?.labelRes,
            ui.filter.theme?.labelRes,
        ).forEach {
            Text(
                stringResource(it), fontSize = 11.sp, color = Palette.accent,
                modifier = Modifier.padding(start = 6.dp),
            )
        }
        Spacer(Modifier.weight(1f))
        if (ui.dueCount > 0) {
            Text(
                pluralStringResource(R.plurals.puzzle_due, ui.dueCount, ui.dueCount),
                fontSize = 11.sp, color = Palette.warning,
                modifier = Modifier.testTag("a-revoir"),
            )
        }
    }
    if (!open) return

    Column(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        ChipRow(
            actif = ui.filter.difficulty?.labelRes,
            libelles = DifficultyTier.entries.map { it.labelRes },
            tag = "niveau",
        ) { index ->
            onFilter(ui.filter.copy(difficulty = index?.let { DifficultyTier.entries[it] }))
        }
        ChipRow(
            actif = ui.filter.phase?.labelRes,
            libelles = GamePhase.entries.map { it.labelRes },
            tag = "phase",
        ) { index ->
            onFilter(ui.filter.copy(phase = index?.let { GamePhase.entries[it] }))
        }
        ChipRow(
            actif = ui.filter.theme?.labelRes,
            libelles = PuzzleThemeKind.entries.map { it.labelRes },
            tag = "theme",
        ) { index ->
            onFilter(ui.filter.copy(theme = index?.let { PuzzleThemeKind.entries[it] }))
        }
    }
}

/**
 * Une ligne de puces avec « Tous » en tête. Toucher la puce ACTIVE la
 * désactive : c'est le geste qu'on cherche quand on veut revenir à tout, et il
 * évite d'aller chercher « Tous » à l'autre bout de la ligne.
 */
@Composable
private fun ChipRow(
    actif: Int?,
    libelles: List<Int>,
    tag: String,
    onPick: (Int?) -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Puce(stringResource(R.string.puzzle_filter_all), actif == null, "$tag-tous") { onPick(null) }
        libelles.forEachIndexed { index, res ->
            val selected = actif == res
            Puce(stringResource(res), selected, "$tag-$index") { onPick(if (selected) null else index) }
        }
    }
}

@Composable
private fun Puce(label: String, selected: Boolean, tag: String, onClick: () -> Unit) {
    Text(
        label,
        fontSize = 11.sp,
        fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
        color = if (selected) Palette.background else Palette.textSecondary,
        modifier = Modifier
            .clip(CircleShape)
            .background(if (selected) Palette.accent else Palette.surface)
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 5.dp)
            .testTag(tag),
    )
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Header(ui: PuzzleUiState) {
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .size(13.dp)
                    .clip(CircleShape)
                    .background(if (ui.orientation == Piece.Color.white) Color.White else Color.Black)
                    .border(1.dp, Palette.stroke, CircleShape)
            )
            Spacer(Modifier.width(8.dp))
            Text(
                stringResource(R.string.puzzle_instruction),
                fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
                modifier = Modifier.testTag("statut"),
            )
        }
        val puzzle = ui.puzzle ?: return@Column
        // Une ligne qui PASSE À LA LIGNE, pas une `Row` : avec un thème long
        // (« ATTAQUE À LA DÉCOUVERTE ») et deux pastilles, la `Row` débordait,
        // écrasait le score à quelques pixels — il s'écrivait alors une lettre
        // par ligne et l'en-tête prenait la moitié de l'écran, poussant le
        // plateau en bas et les essais hors champ (Galaxy A16, 24/10/2026).
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(7.dp, Alignment.CenterHorizontally),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                stringResource(puzzle.themeLabel).uppercase(),
                fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Palette.accent,
                maxLines = 1,
            )
            // Le PALIER, pas la cote brute : « Confirmé » se lit, « 1 742 » se
            // décode. Quatre paliers, quatre couleurs, du vert au rose — c'est
            // le choix d'iOS, et Android montrait encore le nombre.
            // Cote 0 : un puzzle maison n'en a pas, et en inventer une serait
            // pire que de n'en montrer aucune.
            if (puzzle.rating > 0) {
                val tier = DifficultyTier.forRating(puzzle.rating)
                ContextPill(stringResource(tier.labelRes), tier.tint)
            }
            GamePhase.of(puzzle.phase)?.let { phase ->
                ContextPill(stringResource(phase.labelRes), phase.tint, phase.icon)
            }
            // Programme : le rang dans le lot le remplace, sur la ligne d'en
            // dessous (iOS n'affiche pas de score de séance dans ce mode).
            if (ui.woodpeckerPlan == null) {
                Text(
                    stringResource(R.string.puzzle_score, ui.solvedCount, ui.attemptedCount),
                    fontSize = 12.sp, color = Palette.textSecondary, maxLines = 1,
                    modifier = Modifier.testTag("score"),
                )
            }
        }
    }
}

/**
 * Une pastille de contexte : teintée, cerclée, et lisible d'un coup d'œil.
 *
 * Le CERCLE compte : sur un fond sombre, un aplat à 15 % d'une couleur claire
 * se confond avec la surface, et la pastille redevient du texte gris. C'est
 * pour cela qu'iOS en pose un.
 */
@Composable
private fun ContextPill(label: String, tint: Color, icon: ImageVector? = null) {
    Row(
        Modifier
            .clip(CircleShape)
            .background(tint.copy(alpha = 0.15f))
            .border(1.dp, tint.copy(alpha = 0.30f), CircleShape)
            .padding(horizontal = 8.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        icon?.let { Icon(it, null, tint = tint, modifier = Modifier.size(11.dp)) }
        Text(label, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = tint, maxLines = 1)
    }
}

/** Les essais restants, en pastilles : on voit ce qu'il reste sans compter. */
@Composable
private fun AttemptsIndicator(left: Int, allowed: Int) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            stringResource(if (allowed == 1) R.string.puzzle_one_try else R.string.puzzle_tries).uppercase(),
            fontSize = 11.sp, fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.4.sp, color = Palette.textTertiary,
        )
        repeat(allowed) { index ->
            Box(
                Modifier
                    .size(9.dp)
                    .clip(CircleShape)
                    .background(if (index < left) Palette.accent else Color.White.copy(alpha = 0.12f))
            )
        }
    }
}

@Composable
private fun HintButton(onClick: () -> Unit) {
    Row(
        Modifier
            .clip(CircleShape)
            .background(Palette.surfaceElevated)
            .border(1.dp, Palette.stroke, CircleShape)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 7.dp)
            .testTag("indice"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Default.Lightbulb, null, tint = Palette.textSecondary, modifier = Modifier.size(15.dp))
        Spacer(Modifier.width(6.dp))
        Text(stringResource(R.string.train_hint), fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold, color = Palette.textSecondary)
    }
}

/**
 * Le verdict, SOUS le plateau et jamais par-dessus : la position reste
 * visible, y compris la flèche de la solution.
 */
@Composable
private fun ResultCard(
    solved: Boolean,
    partial: Boolean = false,
    modifier: Modifier,
    onNext: () -> Unit,
    sourcePgn: String? = null,
    onViewSourceGame: (String) -> Unit = {},
    nextLabel: String = stringResource(R.string.puzzle_next),
    /** Programme Woodpecker au cycle bouclé : son bilan, au-dessus du bouton. */
    cycleSummary: WoodpeckerPlan? = null,
) {
    val tint = if (solved) Palette.accent else Palette.textSecondary
    Column(
        modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(cardGradient)
            .subtleBorder()
            .padding(16.dp)
            .testTag("verdict"),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(46.dp).clip(CircleShape).background(tint.copy(alpha = 0.16f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    if (solved) Icons.Default.CheckCircle else Icons.Default.Flag, null,
                    tint = tint, modifier = Modifier.size(24.dp),
                )
            }
            Spacer(Modifier.width(12.dp))
            Column {
                Text(
                    stringResource(if (solved) R.string.puzzle_solved_bang else R.string.puzzle_revealed),
                    fontSize = 19.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary,
                )
                if (partial) {
                    Text(
                        stringResource(R.string.puzzle_partial_note),
                        fontSize = 13.sp, fontWeight = FontWeight.Medium, color = Palette.warning,
                        modifier = Modifier.testTag("puzzlePartialNote"),
                    )
                }
            }
        }
        cycleSummary?.let { WoodpeckerCycleSummary(it) }
        Text(
            nextLabel,
            fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
            modifier = Modifier
                .fillMaxWidth()
                .clip(CircleShape)
                .background(accentGradient)
                .clickable(onClick = onNext)
                .padding(vertical = 12.dp)
                .testTag("suivant"),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        // Un puzzle MAISON vient d'une partie qu'on a jouée : la revoir dans
        // son contexte vaut mieux que la revoir seule, et c'est là que le
        // « pourquoi » se trouve.
        if (sourcePgn != null) {
            Text(
                stringResource(R.string.puzzle_view_source),
                fontSize = 13.sp, fontWeight = FontWeight.Medium, color = Palette.textSecondary,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onViewSourceGame(sourcePgn) }
                    .padding(vertical = 4.dp)
                    .testTag("voir-la-partie"),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )
        }
    }
}



/**
 * Programme Woodpecker : le rang dans le lot et le chrono du CYCLE, sur leur
 * propre ligne — pendant de la seconde ligne d'en-tête d'iOS.
 */
@Composable
private fun WoodpeckerLine(plan: WoodpeckerPlan, solving: Boolean, model: PuzzleViewModel) {
    var now by remember { mutableStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            now = System.currentTimeMillis()
            kotlinx.coroutines.delay(1000)
        }
    }
    val cycle = plan.currentCycle
    val rank = minOf(cycle.order.size, cycle.attempts.size + if (solving) 1 else 0)
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            stringResource(R.string.woodpecker_progress, cycle.number, rank, cycle.order.size),
            fontSize = 12.sp, color = Palette.textSecondary,
            modifier = Modifier.testTag("woodpecker-rang"),
        )
        Icon(Icons.Default.Timer, null, tint = Palette.warning, modifier = Modifier.size(14.dp))
        Text(
            WoodpeckerPlan.formatDuration(model.cycleElapsedSeconds(now)),
            fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.warning,
            modifier = Modifier.testTag("woodpecker-chrono"),
        )
    }
}

/** Le bilan d'un cycle bouclé, comparé au précédent, et l'objectif du suivant. */
@Composable
private fun WoodpeckerCycleSummary(plan: WoodpeckerPlan) {
    val cycle = plan.currentCycle
    Column(Modifier.testTag("woodpecker-bilan"), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            stringResource(R.string.woodpecker_cycle_done, cycle.number),
            fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
        )
        Text(
            stringResource(
                R.string.woodpecker_cycle_line, cycle.solvedCount, cycle.order.size,
                WoodpeckerPlan.formatDuration(cycle.activeSeconds),
            ),
            fontSize = 14.sp, color = Palette.accent,
        )
        plan.previousCycle?.let { previous ->
            Text(
                stringResource(
                    R.string.woodpecker_previous_line, previous.number, previous.solvedCount,
                    previous.order.size, WoodpeckerPlan.formatDuration(previous.activeSeconds),
                ),
                fontSize = 12.sp, color = Palette.textSecondary,
            )
            plan.cycleComparison?.let { CycleBars(it) }
        }
        plan.nextCycleTargetSeconds?.let { target ->
            Text(
                stringResource(R.string.woodpecker_target, WoodpeckerPlan.formatDuration(target)),
                fontSize = 12.sp, color = Palette.textTertiary,
            )
        }
    }
}

/** C8 : l'ancien cycle (pâle) contre le nouveau, en barres — trouvés, puis temps. */
@Composable
private fun CycleBars(c: CycleComparison) {
    Column(Modifier.testTag("woodpecker-barres"), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        CycleBar(stringResource(R.string.woodpecker_bar_solved), c.previousScore, c.currentScore, Palette.accent)
        CycleBar(stringResource(R.string.woodpecker_bar_time), c.previousTime, c.currentTime, Palette.info)
        if (c.isProgress) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.testTag("woodpecker-progres")) {
                Icon(Icons.Default.WorkspacePremium, null, tint = Palette.warning, modifier = Modifier.size(14.dp))
                Text(
                    stringResource(R.string.woodpecker_faster, WoodpeckerPlan.formatDuration(c.secondsSaved)),
                    fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.warning,
                    modifier = Modifier.padding(start = 4.dp),
                )
            }
        }
    }
}

@Composable
private fun CycleBar(title: String, before: Double, after: Double, tint: Color) {
    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
        Text(title, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Palette.textTertiary)
        Box(Modifier.fillMaxWidth(before.toFloat().coerceIn(0.02f, 1f)).height(6.dp).clip(CircleShape).background(tint.copy(alpha = 0.35f)))
        Box(Modifier.fillMaxWidth(after.toFloat().coerceIn(0.02f, 1f)).height(6.dp).clip(CircleShape).background(tint))
    }
}

/** Plus rien à résoudre : la raison, en clair — pendant du `ContentUnavailableView` d'iOS. */
@Composable
private fun EmptySeries(message: String) {
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 32.dp, vertical = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Icon(Icons.Default.Extension, null, tint = Palette.textTertiary, modifier = Modifier.size(44.dp))
        Text(
            message,
            fontSize = 15.sp, color = Palette.textSecondary,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            modifier = Modifier.testTag("serie-vide"),
        )
    }
}
