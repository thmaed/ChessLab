package com.chesslab.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.R

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

    // La case porte son nom : les tests d'interface cliquent « case-e2 »
    // plutôt que des pixels, et restent valides quand la mise en page bouge.
    Box(
        modifier
            .testTag("case-${square.notation}")
            .background(background)
            .clickable(onClick = onTap),
        Alignment.Center,
    ) {
        if (piece != null) {
            Image(
                painter = painterResource(drawableFor(piece)),
                contentDescription = describe(piece),
                modifier = Modifier.fillMaxSize(0.92f),
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
 * Le jeu cburnett, celui de l'app iOS — mêmes SVG, convertis en
 * `VectorDrawable` par `tools/svg-to-vector/convert_pieces.py`.
 */
private fun drawableFor(piece: Piece): Int = when (piece.color) {
    Piece.Color.white -> when (piece.kind) {
        Piece.Kind.king -> R.drawable.piece_wk
        Piece.Kind.queen -> R.drawable.piece_wq
        Piece.Kind.rook -> R.drawable.piece_wr
        Piece.Kind.bishop -> R.drawable.piece_wb
        Piece.Kind.knight -> R.drawable.piece_wn
        Piece.Kind.pawn -> R.drawable.piece_wp
    }
    Piece.Color.black -> when (piece.kind) {
        Piece.Kind.king -> R.drawable.piece_bk
        Piece.Kind.queen -> R.drawable.piece_bq
        Piece.Kind.rook -> R.drawable.piece_br
        Piece.Kind.bishop -> R.drawable.piece_bb
        Piece.Kind.knight -> R.drawable.piece_bn
        Piece.Kind.pawn -> R.drawable.piece_bp
    }
}

/** Lu par les lecteurs d'écran, comme le `accessibilityLabel` iOS. */
private fun describe(piece: Piece): String {
    val kind = when (piece.kind) {
        Piece.Kind.king -> "Roi"
        Piece.Kind.queen -> "Dame"
        Piece.Kind.rook -> "Tour"
        Piece.Kind.bishop -> "Fou"
        Piece.Kind.knight -> "Cavalier"
        Piece.Kind.pawn -> "Pion"
    }
    val color = if (piece.color == Piece.Color.white) "blanc" else "noir"
    return "$kind $color en ${piece.square.notation}"
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
