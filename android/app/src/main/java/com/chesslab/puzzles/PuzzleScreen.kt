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
    model: PuzzleViewModel = viewModel(),
) {
    val ui = model.ui
    LaunchedEffect(initialTheme, filter) {
        initialTheme?.let(model::trainTheme)
        if (initialTheme == null && filter != null) model.setFilter(filter)
    }

    TopBarActions {
        QuickSwitchMenu(
            onPlayVsEngine = { onPlayVsEngine(model.ui.position.fen) },
            onOpenTwoPlayer = { onOpenTwoPlayer(model.ui.position.fen) },
            onOpenLab = { onOpenLab(model.ui.position.fen) },
        )
    }

    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        // Les filtres et le bilan ont quitté cet écran pour celui du CHOIX de
        // la séance : on décide ce qu'on travaille avant de résoudre, et le
        // puzzle courant ne change plus sous les doigts. Ne restent ici que
        // la source (Lichess ou maison) et le compte des révisions.
        SourcePicker(ui, model::setSource)
        DueBadge(ui)
        Header(ui)
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
            Spacer(Modifier.height(12.dp))
            TextButton(onClick = model::next, modifier = Modifier.testTag("passer")) {
                Text(stringResource(R.string.puzzle_skip), color = Palette.textSecondary)
            }
        } else {
            ResultCard(
                solved = ui.outcome == PuzzleOutcome.solved,
                modifier = Modifier.padding(horizontal = 20.dp),
                onNext = model::next,
                sourcePgn = ui.puzzle?.sourcePgn,
                onViewSourceGame = onViewSourceGame,
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

/**
 * Lichess ou vos propres parties. Le sélecteur ne s'affiche QUE si des puzzles
 * maison existent : sans eux, un onglet vide n'annoncerait qu'une déception.
 */
@Composable
private fun SourcePicker(ui: PuzzleUiState, onPick: (PuzzleSource) -> Unit) {
    if (ui.ownCount == 0 && ui.source == PuzzleSource.lichess) return
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        PuzzleSource.entries.forEach { source ->
            val active = source == ui.source
            Text(
                stringResource(source.labelRes),
                fontSize = 12.sp,
                fontWeight = if (active) FontWeight.Bold else FontWeight.Normal,
                color = if (active) Palette.background else Palette.textSecondary,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(if (active) Palette.accent else Palette.surface)
                    .clickable { onPick(source) }
                    .padding(horizontal = 12.dp, vertical = 6.dp)
                    .testTag("source-${source.name}"),
            )
        }
    }
}

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
        Row(
            horizontalArrangement = Arrangement.spacedBy(7.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                stringResource(puzzle.themeLabel).uppercase(),
                fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Palette.accent,
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
            Text(
                stringResource(R.string.puzzle_score, ui.solvedCount, ui.attemptedCount),
                fontSize = 12.sp, color = Palette.textSecondary,
                modifier = Modifier.testTag("score"),
            )
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
    modifier: Modifier,
    onNext: () -> Unit,
    sourcePgn: String? = null,
    onViewSourceGame: (String) -> Unit = {},
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
            Text(
                stringResource(if (solved) R.string.puzzle_solved_bang else R.string.puzzle_revealed),
                fontSize = 19.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary,
            )
        }
        Text(
            stringResource(R.string.puzzle_next),
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
 * Le bilan de vos puzzles : taux de réussite et thèmes d'erreurs récurrents —
 * « vous ratez souvent des fourchettes ». Pendant de `statsCard` dans
 * `PuzzleQueueView`. Ne s'affiche qu'une fois quelques puzzles tentés : ni
 * « 0 % » ni thème désigné sur trois essais.
 */
@Composable
internal fun PuzzleStatsCard(stats: com.chesslab.progression.PuzzleStats) {
    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 6.dp)
            .clip(com.chesslab.ui.CardShape)
            .background(Palette.surface)
            .padding(12.dp)
            .testTag("bilan-puzzles"),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.puzzle_stats_title), fontSize = 13.sp,
                fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold, color = Palette.textPrimary,
                modifier = Modifier.weight(1f))
            Text(
                stats.successRate?.let { "${kotlin.math.round(it * 100).toInt()}" + stringResource(R.string.percent_suffix) } ?: "—",
                fontSize = 18.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold, color = Palette.accent,
            )
        }
        Text(
            stringResource(R.string.puzzle_stats_solved_of, stats.successes, stats.attempts),
            fontSize = 11.sp, color = Palette.textTertiary,
        )
        if (stats.weakestThemes.isNotEmpty()) {
            Text(stringResource(R.string.progress_to_work_on), fontSize = 11.sp,
                fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold, color = Palette.textSecondary,
                modifier = Modifier.padding(top = 4.dp))
            stats.weakestThemes.take(3).forEach { record ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(stringResource(record.labelRes), fontSize = 11.sp, color = Palette.textPrimary, modifier = Modifier.weight(1f))
                    Text(
                        stringResource(R.string.progress_failed_of, kotlin.math.round(record.failureRate * 100).toInt(), record.attempts),
                        fontSize = 11.sp, color = Palette.textTertiary,
                    )
                }
            }
        }
    }
}
