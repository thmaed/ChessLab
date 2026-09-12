package com.chesslab.puzzles

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.chesslab.play.PromotionDialog
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
import com.chesslab.ui.Palette
import com.chesslab.ui.StatusRow
import androidx.compose.ui.res.stringResource
import com.chesslab.R

@Composable
fun PuzzleScreen(model: PuzzleViewModel = viewModel()) {
    val ui = model.ui

    BoardScaffold(
        header = {
            StatusRow(ui.status, busy = ui.loading || ui.busy)
            Spacer(Modifier.height(8.dp))

            ui.puzzle?.let { puzzle ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .background(Palette.surface)
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Badge(stringResource(puzzle.themeLabel), Palette.violet)
                    Spacer(Modifier.width(8.dp))
                    Badge("${puzzle.rating}", Palette.info)
                    Spacer(Modifier.weight(1f))
                    Text(
                        stringResource(R.string.puzzle_score, ui.solvedCount, ui.attemptedCount),
                        fontSize = 12.sp, color = Palette.textSecondary,
                        modifier = Modifier.testTag("score"),
                    )
                }
            }
            Spacer(Modifier.height(10.dp))
        },
        board = {
            BoardView(
                position = ui.position,
                orientation = ui.orientation,
                selected = ui.selected,
                legalTargets = ui.legalTargets,
                lastMove = ui.lastMove,
                checkedKing = ui.checkedKing,
                enabled = ui.outcome == PuzzleOutcome.solving && !ui.busy,
                onSquareTap = model::onSquareTap,
            )
        },
        panel = {
            Spacer(Modifier.height(12.dp))
            when (ui.outcome) {
                PuzzleOutcome.solved -> Verdict(stringResource(R.string.puzzle_solved), Palette.accent, model::next)
                PuzzleOutcome.failed -> Verdict(stringResource(R.string.puzzle_failed), Palette.danger, model::next)
                PuzzleOutcome.solving -> TextButton(onClick = model::next, modifier = Modifier.testTag("passer")) {
                    Text(stringResource(R.string.puzzle_skip), color = Palette.textSecondary)
                }
            }
        },
    )

    if (ui.pendingPromotion != null) PromotionDialog(model::completePromotion)
}

@Composable
private fun Verdict(text: String, tint: androidx.compose.ui.graphics.Color, onNext: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(text, color = tint, fontWeight = FontWeight.SemiBold, modifier = Modifier.testTag("verdict"))
        Spacer(Modifier.weight(1f))
        Button(onClick = onNext, modifier = Modifier.testTag("suivant")) { Text(stringResource(R.string.puzzle_next)) }
    }
}

@Composable
private fun Badge(text: String, tint: androidx.compose.ui.graphics.Color) {
    Text(
        text,
        fontSize = 11.sp,
        color = tint,
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(tint.copy(alpha = 0.14f))
            .padding(horizontal = 7.dp, vertical = 3.dp),
    )
}
