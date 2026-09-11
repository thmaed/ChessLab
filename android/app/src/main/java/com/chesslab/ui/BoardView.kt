package com.chesslab.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chesskit.Piece
import chesskit.Position
import chesskit.Square

/**
 * L'échiquier. Pendant de `BoardView.swift`.
 *
 * Huit rangées de huit cases : à 64 cellules, la simplicité d'un `Column` de
 * `Row` vaut mieux qu'un `Canvas` à calculer soi-même, et l'adaptation à la
 * taille de l'écran vient gratuitement.
 */
@Composable
fun BoardView(
    position: Position,
    theme: BoardTheme = BoardTheme.classic,
    orientation: Piece.Color = Piece.Color.white,
    selected: Square? = null,
    legalTargets: Set<Square> = emptySet(),
    lastMove: Pair<Square, Square>? = null,
    checkedKing: Square? = null,
    enabled: Boolean = true,
    onSquareTap: (Square) -> Unit = {},
) {
    // rangée 8 en haut quand on joue les blancs, 1 en haut sinon
    val ranks = if (orientation == Piece.Color.white) (8 downTo 1) else (1..8)
    val files = if (orientation == Piece.Color.white) (1..8) else (8 downTo 1)

    Column(
        Modifier
            .fillMaxWidth()
            .aspectRatio(1f)
    ) {
        for (rank in ranks) {
            Row(Modifier.fillMaxWidth().weight(1f)) {
                for (file in files) {
                    val square = Square(Square.File(file), Square.Rank(rank))
                    SquareCell(
                        square = square,
                        piece = position.piece(square),
                        theme = theme,
                        isSelected = square == selected,
                        isLegalTarget = square in legalTargets,
                        isLastMove = lastMove?.let { square == it.first || square == it.second } == true,
                        isChecked = square == checkedKing,
                        showFile = rank == ranks.last,
                        showRank = file == files.first,
                        modifier = Modifier.weight(1f).fillMaxHeight(),
                        onTap = { if (enabled) onSquareTap(square) },
                    )
                }
            }
        }
    }
}

@Composable
private fun SquareCell(
    square: Square,
    piece: Piece?,
    theme: BoardTheme,
    isSelected: Boolean,
    isLegalTarget: Boolean,
    isLastMove: Boolean,
    isChecked: Boolean,
    showFile: Boolean,
    showRank: Boolean,
    modifier: Modifier,
    onTap: () -> Unit,
) {
    val isLight = square.color == Square.Color.light
    val base = if (isLight) theme.lightSquare else theme.darkSquare
    val background = when {
        isChecked -> theme.checkColor
        isSelected -> theme.selectedColor.compositeOver(base)
        isLastMove -> (if (isLight) theme.lastMoveLight else theme.lastMoveDark).compositeOver(base)
        else -> base
    }

    Box(modifier.background(background).clickable(onClick = onTap), Alignment.Center) {
        if (piece != null) {
            Text(
                text = glyph(piece),
                style = TextStyle(
                    fontSize = 34.sp,
                    color = if (piece.color == Piece.Color.white) Color.White else Color(0xFF16181C),
                ),
            )
        }

        // pastille des coups possibles : un point sur case vide, un anneau sur
        // une pièce à prendre — la convention de l'app iOS
        if (isLegalTarget) {
            if (piece == null) {
                Box(
                    Modifier
                        .fillMaxSize(0.30f)
                        .clip(CircleShape)
                        .background(theme.legalDotColor)
                )
            } else {
                Box(
                    Modifier
                        .fillMaxSize(0.94f)
                        .clip(CircleShape)
                        .background(theme.legalDotColor.copy(alpha = 0.28f))
                )
            }
        }

        if (showRank) {
            Text(
                "${square.rank.value}",
                style = TextStyle(fontSize = 9.sp, color = theme.coordinateColor, fontWeight = FontWeight.Medium),
                modifier = Modifier.align(Alignment.TopStart).padding(start = 2.dp, top = 1.dp),
            )
        }
        if (showFile) {
            Text(
                square.file.letter,
                style = TextStyle(fontSize = 9.sp, color = theme.coordinateColor, fontWeight = FontWeight.Medium),
                modifier = Modifier.align(Alignment.BottomEnd).padding(end = 2.dp, bottom = 1.dp),
            )
        }
    }
}

/**
 * Les glyphes Unicode. Le jeu vectoriel cburnett de l'app iOS n'est pas encore
 * porté (12 SVG à convertir en `VectorDrawable`) ; en attendant, les glyphes
 * pleins d'Unicode rendent correctement sur case claire comme sur case sombre.
 */
private fun glyph(piece: Piece): String = when (piece.kind) {
    Piece.Kind.king -> "♚"
    Piece.Kind.queen -> "♛"
    Piece.Kind.rook -> "♜"
    Piece.Kind.bishop -> "♝"
    Piece.Kind.knight -> "♞"
    Piece.Kind.pawn -> "♟"
}

private fun Color.compositeOver(background: Color): Color {
    val a = alpha
    return Color(
        red = red * a + background.red * (1 - a),
        green = green * a + background.green * (1 - a),
        blue = blue * a + background.blue * (1 - a),
        alpha = 1f,
    )
}
