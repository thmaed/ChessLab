package com.chesslab.twoplayer

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.chesslab.play.PromotionDialog
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
import com.chesslab.ui.MoveStrip
import com.chesslab.ui.Palette
import com.chesslab.ui.StatusRow

@Composable
fun TwoPlayerScreen(model: TwoPlayerViewModel = viewModel()) {
    val ui = model.ui

    BoardScaffold(
        header = {
            StatusRow(ui.status)
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
                enabled = !ui.gameOver,
                onSquareTap = model::onSquareTap,
            )
        },
        panel = {
            Spacer(Modifier.height(12.dp))
            MoveStrip(ui.sanMoves)

            Spacer(Modifier.height(4.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Switch(checked = ui.autoFlip, onCheckedChange = { model.toggleAutoFlip() })
                Spacer(Modifier.width(8.dp))
                Text("Retourner à chaque coup", fontSize = 13.sp, color = Palette.textSecondary)
                Spacer(Modifier.weight(1f))
                TextButton(onClick = model::flip) {
                    Icon(Icons.Default.SwapVert, "Retourner le plateau", tint = Palette.accent)
                }
            }
            TextButton(onClick = model::newGame) { Text("Nouvelle partie", color = Palette.accent) }
        },
    )

    if (ui.pendingPromotion != null) PromotionDialog(model::completePromotion)
}
