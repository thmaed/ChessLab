package com.chesslab.play

import androidx.compose.foundation.layout.*
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import chesskit.Piece
import com.chesslab.ui.BoardView
import com.chesslab.ui.MoveStrip
import com.chesslab.ui.Palette
import com.chesslab.ui.StatusRow

@Composable
fun PlayScreen(model: PlayViewModel = viewModel()) {
    val ui = model.ui

    Column(Modifier.fillMaxSize().padding(horizontal = 16.dp)) {
        StatusRow(ui.status, busy = ui.thinking)
        Spacer(Modifier.height(10.dp))

        BoardView(
            position = ui.position,
            selected = ui.selected,
            legalTargets = ui.legalTargets,
            lastMove = ui.lastMove,
            checkedKing = ui.checkedKing,
            enabled = !ui.thinking && !ui.gameOver,
            onSquareTap = model::onSquareTap,
        )

        Spacer(Modifier.height(12.dp))
        MoveStrip(ui.sanMoves)

        Spacer(Modifier.height(8.dp))
        TextButton(onClick = model::newGame) { Text("Nouvelle partie", color = Palette.accent) }
    }

    if (ui.pendingPromotion != null) PromotionDialog(model::completePromotion)
}

@Composable
fun PromotionDialog(onPick: (Piece.Kind) -> Unit) {
    AlertDialog(
        onDismissRequest = { onPick(Piece.Kind.queen) },
        title = { Text("Promotion") },
        text = { Text("En quelle pièce promouvoir le pion ?") },
        confirmButton = {
            Row {
                listOf(
                    Piece.Kind.queen to "Dame",
                    Piece.Kind.rook to "Tour",
                    Piece.Kind.bishop to "Fou",
                    Piece.Kind.knight to "Cavalier",
                ).forEach { (kind, label) ->
                    TextButton(onClick = { onPick(kind) }) { Text(label) }
                }
            }
        },
        containerColor = Palette.surfaceElevated,
    )
}
