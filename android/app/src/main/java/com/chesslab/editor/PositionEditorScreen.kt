package com.chesslab.editor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chesskit.Castling
import chesskit.Clock
import chesskit.LegalCastlings
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
import com.chesslab.ui.Palette
import androidx.compose.ui.res.stringResource
import com.chesslab.R

/**
 * L'éditeur de position : poser les pièces à la main.
 *
 * Pendant réduit de `PositionEditorView.swift`. On choisit une pièce dans la
 * palette, on tape les cases ; la gomme vide. Le trait et les roques sont des
 * interrupteurs, parce qu'ils ne se déduisent pas d'un plateau.
 */
@Composable
fun PositionEditorScreen(
    /**
     * La position de départ. Absente : un plateau vide. C'est ce qui fait de
     * l'éditeur l'écran de confirmation du scanner — pré-rempli avec la
     * lecture, et rebâti quand elle change (l'orientation qu'on inverse).
     */
    initialFen: String? = null,
    /** Les cases à surligner : les lectures douteuses du scanner. */
    marked: Set<Square> = emptySet(),
    /** Ce que l'appelant veut ajouter au panneau : bannière de confiance, sens de lecture. */
    extra: @Composable ColumnScope.() -> Unit = {},
    /** Un retour vers l'écran d'avant (« Recadrer »), quand il y en a un. */
    onBack: (() -> Unit)? = null,
    backLabel: String? = null,
    /** Le libellé du bouton de sortie : « Analyser », ou « Utiliser cette position ». */
    @androidx.annotation.StringRes confirmLabel: Int = R.string.route_analysis,
    onAnalyse: (String) -> Unit = {},
) {
    // La position initiale est SEMÉE à la composition, pas versée par un effet
    // différé : un effet arrive une frame plus tard, et l'écran se montrait
    // d'abord vide — assez longtemps pour qu'une capture le surprenne. Elle
    // se ressème à chaque changement : inverser la lecture du scanner
    // remplace tout le plateau.
    val initial = remember(initialFen) { initialFen?.let { chesskit.FenParser.parse(it) } }
    val pieces = remember(initialFen) {
        mutableStateMapOf<Square, Piece>().apply { initial?.pieces?.forEach { put(it.square, it) } }
    }
    var brush by remember { mutableStateOf<Piece.Kind?>(Piece.Kind.pawn) }
    var brushColor by remember { mutableStateOf(Piece.Color.white) }
    var whiteToMove by remember(initialFen) { mutableStateOf(initial?.sideToMove != Piece.Color.black) }
    val castling = remember(initialFen) {
        mutableStateMapOf<Castling, Boolean>().apply {
            initial?.let { p -> Castling.all.forEach { put(it, it in p.legalCastlings) } }
        }
    }

    val position = Position(
        pieces = pieces.values.toList(),
        sideToMove = if (whiteToMove) Piece.Color.white else Piece.Color.black,
        legalCastlings = LegalCastlings(Castling.all.filter { castling[it] == true }),
        clock = Clock(0, 1),
    )

    BoardScaffold(
        header = {
            if (onBack != null && backLabel != null) {
                Text(
                    backLabel, fontSize = 13.sp, color = Palette.accent,
                    modifier = Modifier.clickable(onClick = onBack).padding(vertical = 4.dp).testTag("recadrer"),
                )
                Spacer(Modifier.height(4.dp))
            }
            Text(
                stringResource(if (brush == null) R.string.editor_eraser_hint else R.string.editor_place_hint),
                fontSize = 12.sp, color = Palette.textSecondary,
            )
            Spacer(Modifier.height(8.dp))
        },
        board = {
            BoardView(
                position = position,
                marked = marked,
                enabled = true,
                onSquareTap = { square ->
                    val kind = brush
                    if (kind == null) pieces.remove(square)
                    else pieces[square] = Piece(kind, brushColor, square)
                },
            )
        },
        panel = {
            Spacer(Modifier.height(10.dp))
            extra()
            Palette(brush, brushColor, onKind = { brush = it }, onColor = { brushColor = it })

            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Switch(
                    checked = whiteToMove, onCheckedChange = { whiteToMove = it },
                    colors = com.chesslab.ui.chessLabSwitchColors(),
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    stringResource(if (whiteToMove) R.string.white_to_move else R.string.black_to_move),
                    fontSize = 13.sp, color = Palette.textPrimary,
                    modifier = Modifier.testTag("trait"),
                )
            }

            Text(stringResource(R.string.editor_castling), fontSize = 11.sp, color = Palette.textTertiary)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf(
                    Castling.wK to R.string.editor_white_short, Castling.wQ to R.string.editor_white_long,
                    Castling.bK to R.string.editor_black_short, Castling.bQ to R.string.editor_black_long,
                ).forEach { (c, label) ->
                    val on = castling[c] == true
                    Text(
                        stringResource(label), fontSize = 11.sp,
                        color = if (on) Palette.background else Palette.textSecondary,
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (on) Palette.accent else Palette.surface)
                            .clickable { castling[c] = !on }
                            .padding(horizontal = 8.dp, vertical = 5.dp),
                    )
                }
            }

            Spacer(Modifier.height(10.dp))
            Text(
                position.fen,
                fontSize = 11.sp, fontFamily = FontFamily.Monospace, color = Palette.textSecondary,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(Palette.surface)
                    .padding(10.dp)
                    .testTag("fen"),
            )

            // Ce qui empêche la position d'être jouable, dit avant qu'on
            // l'envoie au moteur — même règle qu'iOS.
            val faults = remember(position.fen) { FenValidator.errors(position.fen) }
            faults.forEach { fault ->
                Text(
                    stringResource(fault), fontSize = 11.sp, color = Palette.warning,
                    modifier = Modifier.padding(top = 4.dp).testTag("defaut-fen"),
                )
            }

            Row {
                TextButton(onClick = { pieces.clear() }, modifier = Modifier.testTag("vider")) {
                    Text(stringResource(R.string.editor_clear), color = Palette.textSecondary)
                }
                TextButton(
                    onClick = { Position.standard.pieces.forEach { pieces[it.square] = it } },
                    modifier = Modifier.testTag("depart"),
                ) { Text(stringResource(R.string.editor_start_position), color = Palette.textSecondary) }
                TextButton(
                    onClick = { onAnalyse(position.fen) }, enabled = faults.isEmpty(),
                    modifier = Modifier.testTag("analyser"),
                ) {
                    Text(
                        stringResource(confirmLabel),
                        color = if (faults.isEmpty()) Palette.accent else Palette.textTertiary,
                    )
                }
            }
        },
    )
}

@Composable
private fun Palette(
    brush: Piece.Kind?,
    color: Piece.Color,
    onKind: (Piece.Kind?) -> Unit,
    onColor: (Piece.Color) -> Unit,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
        listOf(Piece.Color.white to R.string.color_white_one, Piece.Color.black to R.string.color_black_one).forEach { (c, label) ->
            Chip(stringResource(label), c == color) { onColor(c) }
        }
    }
    Spacer(Modifier.height(6.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        listOf(
            Piece.Kind.pawn to R.string.piece_pawn, Piece.Kind.knight to R.string.piece_initial_knight,
            Piece.Kind.bishop to R.string.piece_initial_bishop, Piece.Kind.rook to R.string.piece_initial_rook,
            Piece.Kind.queen to R.string.piece_initial_queen, Piece.Kind.king to R.string.piece_initial_king,
        ).forEach { (kind, label) ->
            Chip(stringResource(label), kind == brush) { onKind(kind) }
        }
        Chip(stringResource(R.string.editor_eraser), brush == null) { onKind(null) }
    }
}

@Composable
private fun Chip(label: String, active: Boolean, onClick: () -> Unit) {
    Text(
        label, fontSize = 11.sp,
        color = if (active) Palette.background else Palette.textSecondary,
        modifier = Modifier
            .testTag("palette-$label")
            .clip(RoundedCornerShape(10.dp))
            .background(if (active) Palette.accent else Palette.surface)
            .clickable(onClick = onClick)
            .padding(horizontal = 9.dp, vertical = 5.dp),
    )
}
