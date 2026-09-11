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
import com.chesslab.ui.BoardView
import com.chesslab.ui.Palette

/**
 * L'éditeur de position : poser les pièces à la main.
 *
 * Pendant réduit de `PositionEditorView.swift`. On choisit une pièce dans la
 * palette, on tape les cases ; la gomme vide. Le trait et les roques sont des
 * interrupteurs, parce qu'ils ne se déduisent pas d'un plateau.
 */
@Composable
fun PositionEditorScreen(onAnalyse: (String) -> Unit = {}) {
    val pieces = remember { mutableStateMapOf<Square, Piece>() }
    var brush by remember { mutableStateOf<Piece.Kind?>(Piece.Kind.pawn) }
    var brushColor by remember { mutableStateOf(Piece.Color.white) }
    var whiteToMove by remember { mutableStateOf(true) }
    val castling = remember { mutableStateMapOf<Castling, Boolean>() }

    val position = Position(
        pieces = pieces.values.toList(),
        sideToMove = if (whiteToMove) Piece.Color.white else Piece.Color.black,
        legalCastlings = LegalCastlings(Castling.all.filter { castling[it] == true }),
        clock = Clock(0, 1),
    )

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)
    ) {
        Text(
            if (brush == null) "Gomme : tapez une case pour la vider"
            else "Posez des pièces en tapant les cases",
            fontSize = 12.sp, color = Palette.textSecondary,
        )
        Spacer(Modifier.height(8.dp))

        BoardView(
            position = position,
            enabled = true,
            onSquareTap = { square ->
                val kind = brush
                if (kind == null) pieces.remove(square)
                else pieces[square] = Piece(kind, brushColor, square)
            },
        )

        Spacer(Modifier.height(10.dp))
        Palette(brush, brushColor, onKind = { brush = it }, onColor = { brushColor = it })

        Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Switch(checked = whiteToMove, onCheckedChange = { whiteToMove = it })
            Spacer(Modifier.width(8.dp))
            Text(
                if (whiteToMove) "Aux blancs de jouer" else "Aux noirs de jouer",
                fontSize = 13.sp, color = Palette.textPrimary,
                modifier = Modifier.testTag("trait"),
            )
        }

        Text("Roques encore possibles", fontSize = 11.sp, color = Palette.textTertiary)
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf(
                Castling.wK to "Blancs ⌐", Castling.wQ to "Blancs ⌐⌐",
                Castling.bK to "Noirs ⌐", Castling.bQ to "Noirs ⌐⌐",
            ).forEach { (c, label) ->
                val on = castling[c] == true
                Text(
                    label, fontSize = 11.sp,
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

        Row {
            TextButton(onClick = { pieces.clear() }, modifier = Modifier.testTag("vider")) {
                Text("Vider", color = Palette.textSecondary)
            }
            TextButton(
                onClick = { Position.standard.pieces.forEach { pieces[it.square] = it } },
                modifier = Modifier.testTag("depart"),
            ) { Text("Position de départ", color = Palette.textSecondary) }
            TextButton(onClick = { onAnalyse(position.fen) }, modifier = Modifier.testTag("analyser")) {
                Text("Analyser", color = Palette.accent)
            }
        }
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun Palette(
    brush: Piece.Kind?,
    color: Piece.Color,
    onKind: (Piece.Kind?) -> Unit,
    onColor: (Piece.Color) -> Unit,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
        listOf(Piece.Color.white to "Blanc", Piece.Color.black to "Noir").forEach { (c, label) ->
            Chip(label, c == color) { onColor(c) }
        }
    }
    Spacer(Modifier.height(6.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        listOf(
            Piece.Kind.pawn to "Pion", Piece.Kind.knight to "C", Piece.Kind.bishop to "F",
            Piece.Kind.rook to "T", Piece.Kind.queen to "D", Piece.Kind.king to "R",
        ).forEach { (kind, label) ->
            Chip(label, kind == brush) { onKind(kind) }
        }
        Chip("Gomme", brush == null) { onKind(null) }
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
