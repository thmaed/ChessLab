package com.chesslab.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.R
import com.chesslab.settings.SettingsStore
import androidx.compose.ui.res.stringResource

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
    /** `null` = celui des réglages. */
    theme: BoardTheme? = null,
    /** `null` = celui des réglages. */
    pieceSet: String? = null,
    orientation: Piece.Color = Piece.Color.white,
    selected: Square? = null,
    legalTargets: Set<Square> = emptySet(),
    lastMove: Pair<Square, Square>? = null,
    checkedKing: Square? = null,
    /**
     * Le coup soufflé, montré comme une FLÈCHE et non comme deux cases
     * teintées. Teinter les cases disait « regarde ici » deux fois sans jamais
     * dire dans quel sens — on ne savait pas laquelle était le départ. C'est
     * aussi ce que fait iOS depuis toujours (`HintMove` de nature `.best`),
     * et les deux apps montrent désormais la même chose.
     */
    hint: Pair<Square, Square>? = null,
    /**
     * Les flèches posées sur le plateau : un coup candidat chacune, teintée
     * comme sa pastille dans la liste. C'est ce qui rend un lecteur
     * d'ouvertures lisible d'un coup d'œil — on VOIT les suites au lieu de les
     * lire.
     */
    arrows: List<BoardArrow> = emptyList(),
    enabled: Boolean = true,
    onSquareTap: (Square) -> Unit = {},
) {
    // Le thème et le jeu de pièces viennent des réglages : aucun écran n'a à
    // les transmettre, et changer de thème se voit partout d'un coup.
    val settings by SettingsStore.state.collectAsState()
    val boardTheme = theme
        ?: BoardTheme.all.firstOrNull { it.id == settings.boardThemeId }
        ?: BoardTheme.classic
    val pieces = pieceSet ?: settings.pieceSetId

    // rangée 8 en haut quand on joue les blancs, 1 en haut sinon
    val ranks = if (orientation == Piece.Color.white) (8 downTo 1) else (1..8)
    val files = if (orientation == Piece.Color.white) (1..8) else (8 downTo 1)

    // Le plateau prend le CARRÉ le plus grand qui tienne à la fois dans la
    // largeur offerte ET dans la hauteur de l'écran.
    //
    // `fillMaxWidth().aspectRatio(1f)` ne regardait que la largeur : en
    // paysage, le plateau faisait plus du double de la hauteur de l'écran et
    // on n'en voyait qu'une rangée. La contrainte de hauteur ne peut pas
    // venir du parent — tous ces écrans défilent, donc leur hauteur est
    // infinie — elle vient donc de l'écran lui-même, dont on garde un cinquième
    // pour l'entête et le panneau. Quand le parent BORNE bien la hauteur (le
    // côte-à-côte de [BoardScaffold] en paysage), c'est sa borne qui prime.
    val screenHeight = LocalConfiguration.current.screenHeightDp.dp
    BoxWithConstraints(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        val side = minOf(maxWidth, maxHeight, screenHeight * 0.80f)
        // Les cases, puis les flèches PAR-DESSUS. L'overlay doit être un frère
        // de la colonne, pas son enfant : posé dedans, il devenait une rangée
        // de plus et écrasait les huit autres, dont la hauteur est pondérée.
        Box(Modifier.size(side)) {
            Column(Modifier.fillMaxSize()) {
                for (rank in ranks) {
                    Row(Modifier.fillMaxWidth().weight(1f)) {
                        for (file in files) {
                            val square = Square(Square.File(file), Square.Rank(rank))
                            SquareCell(
                                square = square,
                                piece = position.piece(square),
                                theme = boardTheme,
                                pieceSet = pieces,
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
            val drawn = if (hint == null) arrows
                else arrows + BoardArrow(hint.first, hint.second, HINT_TINT)
            if (drawn.isNotEmpty()) ArrowOverlay(drawn, orientation, Modifier.fillMaxSize())
        }
    }
}

/**
 * La teinte de la flèche d'indice : le gris très sombre d'iOS
 * (`Color(white: 0.12)`), lisible sur les cases claires comme sur les sombres
 * de tous les thèmes, et qui ne se confond avec aucune des couleurs de sens
 * déjà prises — l'ambre du dernier coup, le rouge de l'échec, le vert de
 * l'accent.
 */
private val HINT_TINT = Color(0xFF1F1F1F)

/** Une flèche : d'où, vers où, de quelle couleur, et à quel point marquée. */
data class BoardArrow(
    val from: Square,
    val to: Square,
    val tint: Color,
    /** 1 = le coup recommandé, plus épais ; en dessous, les variantes. */
    val strength: Float = 1f,
)

/**
 * Les flèches, dessinées PAR-DESSUS les cases.
 *
 * Elles partent du bord de la case de départ et non de son centre : une
 * flèche qui sort de sous la pièce la cache, et c'est la pièce qu'on regarde.
 */
@Composable
private fun ArrowOverlay(arrows: List<BoardArrow>, orientation: Piece.Color, modifier: Modifier) {
    androidx.compose.foundation.Canvas(modifier) {
        val cell = size.width / 8f
        fun center(square: Square): Offset {
            val file = square.file.number - 1
            val rank = square.rank.value - 1
            val x = if (orientation == Piece.Color.white) file else 7 - file
            val y = if (orientation == Piece.Color.white) 7 - rank else rank
            return Offset((x + 0.5f) * cell, (y + 0.5f) * cell)
        }
        // Les moins marquées d'abord : la recommandée se pose au-dessus.
        arrows.sortedBy { it.strength }.forEach { arrow ->
            val a = center(arrow.from)
            val b = center(arrow.to)
            val dx = b.x - a.x
            val dy = b.y - a.y
            val length = kotlin.math.hypot(dx, dy)
            if (length < 1f) return@forEach
            val ux = dx / length
            val uy = dy / length
            // Proportions d'iOS : `shaftWidthRatio` 0,18 de case, multiplié
            // par un facteur de 0,7 à 1,35 selon la force — soit 0,126 à 0,243
            // de case. Une flèche faible se voit sans peser autant qu'une
            // forte, et les deux apps dessinent la même chose.
            val width = cell * (0.126f + 0.117f * arrow.strength)
            val head = cell * 0.42f
            // On démarre au bord de la case de départ, on s'arrête au bord de
            // la pointe : la flèche relie deux cases sans les masquer.
            val start = Offset(a.x + ux * cell * 0.34f, a.y + uy * cell * 0.34f)
            val tip = Offset(b.x - ux * cell * 0.10f, b.y - uy * cell * 0.10f)
            val neck = Offset(tip.x - ux * head, tip.y - uy * head)
            val colour = arrow.tint.copy(alpha = 0.55f + 0.35f * arrow.strength)
            drawLine(colour, start, neck, strokeWidth = width, cap = androidx.compose.ui.graphics.StrokeCap.Round)
            val path = androidx.compose.ui.graphics.Path().apply {
                moveTo(tip.x, tip.y)
                lineTo(neck.x - uy * head * 0.52f, neck.y + ux * head * 0.52f)
                lineTo(neck.x + uy * head * 0.52f, neck.y - ux * head * 0.52f)
                close()
            }
            drawPath(path, colour)
        }
    }
}

@Composable
private fun SquareCell(
    square: Square,
    piece: Piece?,
    theme: BoardTheme,
    pieceSet: String,
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
                painter = painterResource(drawableFor(piece, pieceSet)),
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
 * Les trois jeux de l'app iOS — mêmes SVG, convertis en `VectorDrawable` par
 * `tools/svg-to-vector/convert_pieces.py`.
 */
private fun drawableFor(piece: Piece, set: String): Int {
    val white = piece.color == Piece.Color.white
    return when (set) {
        "chessnut" -> if (white) when (piece.kind) {
            Piece.Kind.king -> R.drawable.chessnut_wk
            Piece.Kind.queen -> R.drawable.chessnut_wq
            Piece.Kind.rook -> R.drawable.chessnut_wr
            Piece.Kind.bishop -> R.drawable.chessnut_wb
            Piece.Kind.knight -> R.drawable.chessnut_wn
            Piece.Kind.pawn -> R.drawable.chessnut_wp
        } else when (piece.kind) {
            Piece.Kind.king -> R.drawable.chessnut_bk
            Piece.Kind.queen -> R.drawable.chessnut_bq
            Piece.Kind.rook -> R.drawable.chessnut_br
            Piece.Kind.bishop -> R.drawable.chessnut_bb
            Piece.Kind.knight -> R.drawable.chessnut_bn
            Piece.Kind.pawn -> R.drawable.chessnut_bp
        }
        "merida" -> if (white) when (piece.kind) {
            Piece.Kind.king -> R.drawable.merida_wk
            Piece.Kind.queen -> R.drawable.merida_wq
            Piece.Kind.rook -> R.drawable.merida_wr
            Piece.Kind.bishop -> R.drawable.merida_wb
            Piece.Kind.knight -> R.drawable.merida_wn
            Piece.Kind.pawn -> R.drawable.merida_wp
        } else when (piece.kind) {
            Piece.Kind.king -> R.drawable.merida_bk
            Piece.Kind.queen -> R.drawable.merida_bq
            Piece.Kind.rook -> R.drawable.merida_br
            Piece.Kind.bishop -> R.drawable.merida_bb
            Piece.Kind.knight -> R.drawable.merida_bn
            Piece.Kind.pawn -> R.drawable.merida_bp
        }
        else -> if (white) when (piece.kind) {
            Piece.Kind.king -> R.drawable.piece_wk
            Piece.Kind.queen -> R.drawable.piece_wq
            Piece.Kind.rook -> R.drawable.piece_wr
            Piece.Kind.bishop -> R.drawable.piece_wb
            Piece.Kind.knight -> R.drawable.piece_wn
            Piece.Kind.pawn -> R.drawable.piece_wp
        } else when (piece.kind) {
            Piece.Kind.king -> R.drawable.piece_bk
            Piece.Kind.queen -> R.drawable.piece_bq
            Piece.Kind.rook -> R.drawable.piece_br
            Piece.Kind.bishop -> R.drawable.piece_bb
            Piece.Kind.knight -> R.drawable.piece_bn
            Piece.Kind.pawn -> R.drawable.piece_bp
        }
    }
}

/** Lu par les lecteurs d'écran, comme le `accessibilityLabel` iOS. */
@Composable
private fun describe(piece: Piece): String = stringResource(
    R.string.square_piece,
    stringResource(
        when (piece.kind) {
            Piece.Kind.king -> R.string.piece_king
            Piece.Kind.queen -> R.string.piece_queen
            Piece.Kind.rook -> R.string.piece_rook
            Piece.Kind.bishop -> R.string.piece_bishop
            Piece.Kind.knight -> R.string.piece_knight
            Piece.Kind.pawn -> R.string.piece_pawn
        }
    ),
    stringResource(if (piece.color == Piece.Color.white) R.string.colour_white_adj else R.string.colour_black_adj),
    piece.square.notation,
)

private fun Color.compositeOver(background: Color): Color {
    val a = alpha
    return Color(
        red = red * a + background.red * (1 - a),
        green = green * a + background.green * (1 - a),
        blue = blue * a + background.blue * (1 - a),
        alpha = 1f,
    )
}
