package com.chesslab.scanner

import android.graphics.Bitmap
import androidx.annotation.StringRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chesskit.Piece
import chesskit.Square
import com.chesslab.R
import com.chesslab.ui.Palette
import com.chesslab.vision.PieceChoice
import com.chesslab.vision.SquareReading

/**
 * La revue des cases douteuses du scanner : UNE case à la fois, avec la
 * vignette de l'image d'origine à côté de ce qui a été lu. Pendant de
 * `ScanReviewSection` (iOS).
 *
 * Sans elle, l'utilisateur voit une case surlignée et doit aller chercher
 * l'image source de son côté pour savoir qui a raison. Ici, la bonne réponse se
 * choisit d'un tap : la lecture gardée, la deuxième hypothèse du détecteur, ou
 * « case vide ».
 */
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun ColumnScope.ScanReviewPanel(
    square: Square,
    reading: SquareReading,
    thumbnail: Bitmap?,
    /** Combien de cases restent à vérifier (celle-ci comprise), et quelle place elle y tient. */
    remaining: Int,
    position: Int,
    onChoose: (PieceChoice?) -> Unit,
    onKeep: () -> Unit,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
) {
    val readName = reading.piece?.let { kind -> reading.color?.let { stringResource(pieceNameRes(it, kind)) } }
        ?: stringResource(R.string.scan_read_empty_name)

    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Palette.surface)
            .padding(12.dp)
            .testTag("revue-cases"),
    ) {
        Text(stringResource(R.string.scan_review_title), 11.sp, Palette.textTertiary)
        Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            if (thumbnail != null) {
                Image(
                    thumbnail.asImageBitmap(), contentDescription = null,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier
                        .size(76.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .border(1.dp, Palette.textTertiary, RoundedCornerShape(8.dp)),
                )
            }
            Column(Modifier.weight(1f)) {
                Text(
                    stringResource(R.string.scan_review_square, square.name, position, remaining),
                    14.sp, Palette.textPrimary, FontWeight.SemiBold,
                )
                Spacer(Modifier.height(4.dp))
                Text(stringResource(R.string.scan_review_read, readName), 12.sp, Palette.textSecondary)
            }
            if (remaining > 1) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("‹", 20.sp, Palette.accent, modifier = Modifier.clickable(onClick = onPrevious).padding(6.dp).testTag("revue-precedente"))
                    Text("›", 20.sp, Palette.accent, modifier = Modifier.clickable(onClick = onNext).padding(6.dp).testTag("revue-suivante"))
                }
            }
        }
        Spacer(Modifier.height(10.dp))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            ReviewChip(
                stringResource(if (reading.isEmpty) R.string.scan_review_keep_empty else R.string.scan_review_keep),
                "revue-garder", onKeep,
            )
            reading.alternatives.forEach { choice ->
                ReviewChip(
                    stringResource(pieceNameRes(choice.color, choice.kind)),
                    "revue-choix-${choice.color.raw}-${choice.kind.notation}",
                ) { onChoose(choice) }
            }
            if (!reading.isEmpty) ReviewChip(stringResource(R.string.scan_review_empty), "revue-vide") { onChoose(null) }
        }
    }
}

@Composable
private fun Text(text: String, size: androidx.compose.ui.unit.TextUnit, color: androidx.compose.ui.graphics.Color,
                 weight: FontWeight? = null, modifier: Modifier = Modifier) {
    androidx.compose.material3.Text(text, fontSize = size, color = color, fontWeight = weight, modifier = modifier)
}

@Composable
private fun ReviewChip(label: String, tag: String, onClick: () -> Unit) {
    Text(
        label, 12.sp, Palette.textPrimary,
        modifier = Modifier
            .clip(RoundedCornerShape(10.dp))
            .background(Palette.background)
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 6.dp)
            .testTag(tag),
    )
}

/** Le nom complet d'une pièce, localisé (« Cavalier blanc » / « White knight »). */
@StringRes
fun pieceNameRes(color: Piece.Color, kind: Piece.Kind): Int = when (color) {
    Piece.Color.white -> when (kind) {
        Piece.Kind.pawn -> R.string.scan_piece_white_pawn; Piece.Kind.knight -> R.string.scan_piece_white_knight
        Piece.Kind.bishop -> R.string.scan_piece_white_bishop; Piece.Kind.rook -> R.string.scan_piece_white_rook
        Piece.Kind.queen -> R.string.scan_piece_white_queen; Piece.Kind.king -> R.string.scan_piece_white_king
    }
    Piece.Color.black -> when (kind) {
        Piece.Kind.pawn -> R.string.scan_piece_black_pawn; Piece.Kind.knight -> R.string.scan_piece_black_knight
        Piece.Kind.bishop -> R.string.scan_piece_black_bishop; Piece.Kind.rook -> R.string.scan_piece_black_rook
        Piece.Kind.queen -> R.string.scan_piece_black_queen; Piece.Kind.king -> R.string.scan_piece_black_king
    }
}
