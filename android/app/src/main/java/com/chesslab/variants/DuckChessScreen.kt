package com.chesslab.variants

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import chesskit.Piece
import com.chesslab.R
import com.chesslab.play.BlunderSeverity
import com.chesslab.play.GameClock
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
import com.chesslab.ui.ControlButton
import com.chesslab.ui.EvalBar
import com.chesslab.ui.Palette
import com.chesslab.ui.QuickSwitchMenu
import com.chesslab.ui.StatusRow
import com.chesslab.ui.TopBarActions

/**
 * Le Duck Chess : un tour en DEUX temps, et un canard qui bloque une case.
 * Pendant réduit de `DuckChessPlayView.swift`.
 *
 * Les cases où le canard peut se poser s'allument comme des cases de
 * destination : c'est le même geste que jouer une pièce, et c'est ce qui rend
 * un tour en deux temps évident sans l'expliquer.
 */
@Composable
fun DuckChessScreen(
    settings: VariantSettings = VariantSettings(),
    onAnalyze: (String) -> Unit = {},
    /** Revoir la partie : les POSITIONS, pas les coups — le canard n'est dans aucun coup. */
    onReviewGame: (List<String>, List<String>, List<String>) -> Unit = { _, _, _ -> },
    model: DuckChessViewModel = viewModel(),
) {
    LaunchedEffect(settings) { model.apply(settings) }
    val ui = model.ui
    var confirmResign by remember { mutableStateOf(false) }

    DisposableEffect(Unit) {
        model.resumeFromBackground()
        onDispose { model.pauseForBackground() }
    }

    TopBarActions {
        QuickSwitchMenu(onAnalyze = { onAnalyze(ui.position.fen) })
    }

    BoardScaffold(
        header = {
            Text(
                stringResource(R.string.variant_duck_blurb),
                fontSize = 11.sp, color = Palette.textTertiary,
            )
            Spacer(Modifier.height(6.dp))
            StatusRow(ui.status, busy = ui.thinking)
            Spacer(Modifier.height(8.dp))
            DuckClockRow(ui, top = true)
        },
        board = {
            BoardView(
                position = ui.position,
                orientation = ui.userColor,
                selected = ui.selected,
                // Les cases du canard s'allument comme des destinations : le
                // geste est le même, et la phase se lit sans un mot.
                legalTargets = if (ui.phase == DuckPhase.placeDuck) ui.duckTargets else ui.legalTargets,
                lastMove = ui.lastMove,
                duck = ui.duck,
                arrows = ui.hints,
                draggableColor = ui.position.sideToMove,
                enabled = !ui.thinking && !ui.gameOver,
                onSquareTap = model::onSquareTap,
            )
        },
        panel = {
            if (ui.settings.showEvalBar) {
                Spacer(Modifier.height(6.dp))
                EvalBar(cp = ui.evalCp, mate = ui.evalMate)
            }
            Spacer(Modifier.height(6.dp))
            DuckClockRow(ui, top = false)
            Spacer(Modifier.height(4.dp))
            Text(
                pluralStringResource(R.plurals.variant_halfmoves, ui.plies, ui.plies),
                fontSize = 11.sp, color = Palette.textTertiary,
                modifier = Modifier.testTag("compteur"),
            )
            Spacer(Modifier.height(6.dp))
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                ControlButton(
                    Icons.Default.Lightbulb, stringResource(R.string.train_hint),
                    enabled = ui.settings.hintsEnabled && !ui.gameOver,
                    tint = if (ui.hintWanted) Palette.background else Palette.textPrimary,
                    background = if (ui.hintWanted) Palette.accent else Palette.surfaceElevated,
                    tag = "indice", onClick = model::toggleHint,
                )
                Spacer(Modifier.weight(1f))
                ControlButton(
                    Icons.Default.Flag, stringResource(R.string.play_resign),
                    tint = Palette.danger, enabled = !ui.gameOver,
                    tag = "abandonner", onClick = { confirmResign = true },
                )
            }
            Spacer(Modifier.height(8.dp))
            if (ui.gameOver) {
                Row(
                    Modifier.fillMaxWidth().testTag("fin-de-partie"),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    TextButton(onClick = model::newGame, modifier = Modifier.testTag("nouvelle")) {
                        Text(stringResource(R.string.new_game), color = Palette.accent)
                    }
                    Spacer(Modifier.weight(1f))
                    TextButton(
                        onClick = { onReviewGame(model.analysisFens(), model.analysisMoves(), model.analysisSans()) },
                        enabled = model.analysisMoves().isNotEmpty(),
                        modifier = Modifier.testTag("analyser-la-partie"),
                    ) {
                        Text(stringResource(R.string.route_analysis), color = Palette.teal)
                    }
                }
            } else {
                TextButton(onClick = model::newGame, modifier = Modifier.testTag("nouvelle")) {
                    Text(stringResource(R.string.new_game), color = Palette.accent)
                }
            }
        },
    )

    if (confirmResign) {
        AlertDialog(
            onDismissRequest = { confirmResign = false },
            title = { Text(stringResource(R.string.play_resign)) },
            text = { Text(stringResource(R.string.play_resign_confirm)) },
            confirmButton = {
                TextButton(
                    onClick = { confirmResign = false; model.resign() },
                    modifier = Modifier.testTag("abandonner-oui"),
                ) { Text(stringResource(R.string.play_resign), color = Palette.danger) }
            },
            dismissButton = {
                TextButton(onClick = { confirmResign = false }) { Text(stringResource(R.string.cancel)) }
            },
            containerColor = Palette.surface,
        )
    }

    ui.blunderWarning?.let { severity ->
        val message = when (severity) {
            is BlunderSeverity.MissedMate -> stringResource(R.string.blunder_missed_mate)
            is BlunderSeverity.AllowsMate -> stringResource(R.string.blunder_allows_mate)
            is BlunderSeverity.Centipawns ->
                stringResource(R.string.blunder_centipawns, minOf(severity.drop, 1_000) / 100)
        }
        AlertDialog(
            onDismissRequest = model::dismissBlunderWarning,
            title = { Text(stringResource(R.string.blunder_title), color = Palette.textPrimary) },
            text = { Text(message, color = Palette.textSecondary, modifier = Modifier.testTag("alerte-gaffe")) },
            // Pas de « reprendre » ici : un tour de Duck Chess se joue en deux
            // temps, et défaire la moitié d'un tour laisserait le canard posé
            // sur une case qui n'existe plus dans la partie.
            confirmButton = {
                TextButton(onClick = model::dismissBlunderWarning) {
                    Text(stringResource(android.R.string.ok), color = Palette.accent)
                }
            },
            containerColor = Palette.surfaceElevated,
        )
    }
}

/** La pendule d'un camp — celle d'en face au-dessus, la nôtre en dessous. */
@Composable
private fun DuckClockRow(ui: DuckUiState, top: Boolean) {
    val white = ui.whiteClockMs ?: return
    val black = ui.blackClockMs ?: return
    val color = if (top) ui.userColor.opposite else ui.userColor
    val ms = if (color == Piece.Color.white) white else black
    val active = ui.position.sideToMove == color && !ui.gameOver
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(if (active) Palette.surfaceElevated else Color.Transparent)
            .padding(horizontal = 12.dp, vertical = 5.dp)
            .testTag(if (top) "pendule-adversaire" else "pendule-moi"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(9.dp)
                .clip(CircleShape)
                .background(if (color == Piece.Color.white) Color.White else Color.Black)
                .border(1.dp, Palette.stroke, CircleShape)
        )
        Spacer(Modifier.weight(1f))
        Text(
            GameClock.format(ms),
            fontSize = 19.sp, fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.Monospace,
            color = when {
                ms < 30_000 -> Palette.danger
                active -> Palette.textPrimary
                else -> Palette.textTertiary
            },
        )
    }
}
