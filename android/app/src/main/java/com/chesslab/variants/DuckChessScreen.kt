package com.chesslab.variants

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.chesslab.R
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
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
    onAnalyze: (String) -> Unit = {},
    model: DuckChessViewModel = viewModel(),
) {
    val ui = model.ui

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
        },
        board = {
            BoardView(
                position = ui.position,
                selected = ui.selected,
                // Les cases du canard s'allument comme des destinations : le
                // geste est le même, et la phase se lit sans un mot.
                legalTargets = if (ui.phase == DuckPhase.placeDuck) ui.duckTargets else ui.legalTargets,
                lastMove = ui.lastMove,
                duck = ui.duck,
                draggableColor = ui.position.sideToMove,
                enabled = !ui.thinking && ui.winner == null,
                onSquareTap = model::onSquareTap,
            )
        },
        panel = {
            Spacer(Modifier.height(10.dp))
            Text(
                pluralStringResource(R.plurals.variant_halfmoves, ui.plies, ui.plies),
                fontSize = 11.sp, color = Palette.textTertiary,
                modifier = Modifier.testTag("compteur"),
            )
            TextButton(onClick = model::newGame, modifier = Modifier.testTag("nouvelle")) {
                Text(stringResource(R.string.new_game), color = Palette.accent)
            }
        },
    )
}
