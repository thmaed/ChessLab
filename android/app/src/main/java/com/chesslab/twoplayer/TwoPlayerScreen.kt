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
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import chesskit.Piece
import com.chesslab.ui.Palette
import com.chesslab.ui.StatusRow
import androidx.compose.ui.res.stringResource
import com.chesslab.R

@Composable
fun TwoPlayerScreen(model: TwoPlayerViewModel = viewModel()) {
    val ui = model.ui

    // Les deux camps encadrent le plateau, comme en mode Jouer : celui qui a
    // le trait s'allume, et chacun montre ce qu'il a pris.
    val top = if (ui.orientation == Piece.Color.white) Piece.Color.black else Piece.Color.white
    BoardScaffold(
        header = {
            SidePlayerRow(top, ui, "joueur-haut")
            Spacer(Modifier.height(6.dp))
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
            Spacer(Modifier.height(6.dp))
            SidePlayerRow(ui.orientation, ui, "joueur-bas")

            Spacer(Modifier.height(10.dp))
            StatusRow(ui.status)
            Spacer(Modifier.height(8.dp))
            MoveStrip(ui.sanMoves)

            Spacer(Modifier.height(4.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Switch(checked = ui.autoFlip, onCheckedChange = { model.toggleAutoFlip() })
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.flip_each_move), fontSize = 13.sp, color = Palette.textSecondary)
                Spacer(Modifier.weight(1f))
                TextButton(onClick = model::flip) {
                    Icon(Icons.Default.SwapVert, stringResource(R.string.flip_board), tint = Palette.accent)
                }
            }
            TextButton(onClick = model::newGame) { Text(stringResource(R.string.new_game), color = Palette.accent) }
        },
    )

    if (ui.pendingPromotion != null) PromotionDialog(model::completePromotion)
}

/** Une ligne joueur : la pastille du camp, son nom, ses prises. */
@Composable
private fun SidePlayerRow(color: Piece.Color, ui: TwoPlayerUiState, tag: String) {
    val active = !ui.gameOver && ui.position.sideToMove == color
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(if (active) Palette.surfaceElevated else Color.Transparent)
            .border(
                1.dp,
                if (active) Palette.accent.copy(alpha = 0.40f) else Color.Transparent,
                RoundedCornerShape(10.dp),
            )
            .padding(horizontal = 12.dp, vertical = 6.dp)
            .testTag(tag),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(9.dp)
                .clip(CircleShape)
                .background(if (color == Piece.Color.white) Color.White else Color.Black)
                .border(1.dp, Palette.stroke, CircleShape)
        )
        Spacer(Modifier.width(7.dp))
        Text(
            stringResource(if (color == Piece.Color.white) R.string.color_white else R.string.color_black),
            fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
            color = if (active) Palette.textPrimary else Palette.textSecondary,
        )
        Spacer(Modifier.width(8.dp))
        val kinds = ui.captured.captures(color)
        if (kinds.isNotEmpty()) {
            Text(
                kinds.joinToString("") { glyph(it) },
                fontSize = 13.sp, color = Palette.textSecondary,
            )
        }
        val advantage = ui.captured.advantage(color)
        if (advantage > 0) {
            Spacer(Modifier.width(4.dp))
            Text("+$advantage", fontSize = 12.sp, color = Palette.textSecondary)
        }
    }
}

private fun glyph(kind: Piece.Kind): String = when (kind) {
    Piece.Kind.king -> "\u265a"
    Piece.Kind.queen -> "\u265b"
    Piece.Kind.rook -> "\u265c"
    Piece.Kind.bishop -> "\u265d"
    Piece.Kind.knight -> "\u265e"
    Piece.Kind.pawn -> "\u265f"
}
