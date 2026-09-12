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
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
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
    onPlayVsEngine: (String) -> Unit = {},
    onOpenTwoPlayer: (String) -> Unit = {},
    onOpenLab: (String) -> Unit = {},
    model: PuzzleViewModel = viewModel(),
) {
    val ui = model.ui

    TopBarActions {
        QuickSwitchMenu(
            onPlayVsEngine = { onPlayVsEngine(model.ui.position.fen) },
            onOpenTwoPlayer = { onOpenTwoPlayer(model.ui.position.fen) },
            onOpenLab = { onOpenLab(model.ui.position.fen) },
        )
    }

    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        SourcePicker(ui, model::setSource)
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
            )
        }
    }

    if (ui.pendingPromotion != null) PromotionDialog(model::completePromotion)
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
            // Cote 0 : un puzzle maison n'en a pas, et en inventer une serait
            // pire que de n'en montrer aucune.
            if (puzzle.rating > 0) ContextPill("${puzzle.rating}", difficultyTint(puzzle.rating))
            puzzle.phase?.let { ContextPill(stringResource(phaseLabel(it)), Palette.info) }
            Text(
                stringResource(R.string.puzzle_score, ui.solvedCount, ui.attemptedCount),
                fontSize = 12.sp, color = Palette.textSecondary,
                modifier = Modifier.testTag("score"),
            )
        }
    }
}

@Composable
private fun ContextPill(label: String, tint: Color) {
    Text(
        label, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = tint,
        modifier = Modifier
            .clip(CircleShape)
            .background(tint.copy(alpha = 0.16f))
            .padding(horizontal = 8.dp, vertical = 3.dp),
    )
}

/** La difficulté se lit à sa couleur, du vert au rouge. */
private fun difficultyTint(rating: Int): Color = when {
    rating < 1200 -> Palette.accent
    rating < 1600 -> Palette.teal
    rating < 2000 -> Palette.warning
    else -> Palette.danger
}

private fun phaseLabel(phase: String): Int = when (phase) {
    "opening" -> R.string.phase_opening
    "middlegame" -> R.string.phase_middlegame
    else -> R.string.phase_endgame
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
private fun ResultCard(solved: Boolean, modifier: Modifier, onNext: () -> Unit) {
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
    }
}
