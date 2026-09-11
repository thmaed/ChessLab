package com.chesslab.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.composed
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chesskit.Piece

/** La ligne d'état sous le titre : ce que l'app a à dire, et si elle réfléchit. */
@Composable
fun StatusRow(status: String, busy: Boolean = false) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        if (busy) {
            CircularProgressIndicator(Modifier.size(12.dp), strokeWidth = 2.dp, color = Palette.accent)
            Spacer(Modifier.width(8.dp))
        }
        Text(
            status,
            style = MaterialTheme.typography.bodySmall,
            color = Palette.textSecondary,
            modifier = Modifier.testTag("statut"),
        )
    }
}

/**
 * La bande des coups, en notation abrégée. Pendant de `MoveStripView.swift`.
 *
 * [selected] surligne le coup courant : c'est ce qui permet de naviguer dans
 * une partie analysée.
 */
@Composable
fun MoveStrip(
    moves: List<String>,
    selected: Int? = null,
    onSelect: ((Int) -> Unit)? = null,
) {
    val scroll = rememberScrollState()
    LaunchedEffect(moves.size, selected) { scroll.animateScrollTo(scroll.maxValue) }

    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Palette.surface)
            .horizontalScroll(scroll)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (moves.isEmpty()) {
            Text("Aucun coup joué", fontSize = 12.sp, color = Palette.textTertiary)
        }
        moves.forEachIndexed { index, san ->
            if (index % 2 == 0) {
                Text(
                    "${index / 2 + 1}.",
                    fontSize = 12.sp,
                    color = Palette.textTertiary,
                    modifier = Modifier.padding(start = if (index == 0) 0.dp else 8.dp, end = 3.dp),
                )
            }
            val isSelected = index == selected
            Text(
                san,
                modifier = Modifier
                    .testTag("coup-$index")
                    .then(if (onSelect != null) Modifier.clickableNoRipple { onSelect(index) } else Modifier)
                    .then(
                        if (isSelected) Modifier
                            .clip(RoundedCornerShape(4.dp))
                            .background(Palette.accent.copy(alpha = 0.22f))
                            .padding(horizontal = 3.dp)
                        else Modifier
                    )
                    .padding(end = 4.dp),
                fontSize = 12.sp,
                fontFamily = FontFamily.Monospace,
                color = if (isSelected) Palette.accent else Palette.textPrimary,
            )
        }
    }
}

/** Le camp au trait, en toutes lettres. */
fun sideLabel(color: Piece.Color): String =
    if (color == Piece.Color.white) "les blancs" else "les noirs"

/** Un clic sans l'ondulation : dans une bande de coups, elle fait du bruit. */
private fun Modifier.clickableNoRipple(onClick: () -> Unit): Modifier = composed {
    clickable(
        indication = null,
        interactionSource = remember { MutableInteractionSource() },
        onClick = onClick,
    )
}
