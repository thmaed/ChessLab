package com.chesslab.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chesskit.Piece
import chesskit.Square
import com.chesslab.courses.CourseRepository

/**
 * Une vignette de plateau : la position d'un cours d'un coup d'œil (C5).
 * Pendant de `MiniBoardView.swift` — mêmes cases, mêmes glyphes.
 */
@Composable
fun MiniBoard(fen: String, flipped: Boolean = false, modifier: Modifier = Modifier) {
    val measurer = rememberTextMeasurer()
    val position = CourseRepository.position(fen)
    val light = Color(0.93f, 0.90f, 0.82f)
    val dark = Color(0.46f, 0.59f, 0.34f)
    Canvas(modifier.aspectRatio(1f).clip(RoundedCornerShape(6.dp))) {
        val cell = size.width / 8f
        for (row in 0 until 8) for (column in 0 until 8) {
            val topLeft = Offset(column * cell, row * cell)
            drawRect(if ((row + column) % 2 == 1) dark else light, topLeft, Size(cell, cell))
            val file = if (flipped) 7 - column else column
            val rank = if (flipped) row + 1 else 8 - row
            val piece = position?.piece(Square("${"abcdefgh"[file]}$rank")) ?: continue
            val glyph = when (piece.kind) {
                Piece.Kind.king -> "♚"
                Piece.Kind.queen -> "♛"
                Piece.Kind.rook -> "♜"
                Piece.Kind.bishop -> "♝"
                Piece.Kind.knight -> "♞"
                Piece.Kind.pawn -> "♟\uFE0E"
            }
            val white = piece.color == Piece.Color.white
            val style = TextStyle(fontSize = (cell * 1.3f / density).sp)
            val layout = measurer.measure(glyph, style)
            val origin = Offset(topLeft.x + (cell - layout.size.width) / 2f, topLeft.y + (cell - layout.size.height) / 2f)
            if (white) {
                for ((dx, dy) in listOf(-1f to 0f, 1f to 0f, 0f to -1f, 0f to 1f)) {
                    drawText(layout.let { measurer.measure(glyph, style.copy(color = Color.Black)) }, topLeft = origin + Offset(dx, dy))
                }
            }
            drawText(measurer.measure(glyph, style.copy(color = if (white) Color.White else Color.Black)), topLeft = origin)
        }
    }
}

