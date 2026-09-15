package com.chesslab.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Un bouton rond de la barre de contrôle. Pendant de `PlayControlBar.swift`.
 *
 * Il vivait en copie `private` dans l'écran « Contre l'ordinateur », et les
 * écrans de variantes n'avaient donc ni indice, ni nulle, ni abandon : une
 * déclaration partagée coûte moins qu'une sixième copie, et surtout elle
 * garantit que le même bouton a partout la même taille de cible.
 */
@Composable
fun ControlButton(
    icon: ImageVector? = null,
    label: String,
    text: String? = null,
    tint: Color = Palette.textPrimary,
    /** Le fond : c'est lui qui dit qu'un bouton à BASCULE est allumé. */
    background: Color = Palette.surfaceElevated,
    enabled: Boolean = true,
    tag: String,
    onClick: () -> Unit,
) {
    Box(
        Modifier
            .size(46.dp)
            .clip(CircleShape)
            .background(background)
            .border(1.dp, Palette.stroke, CircleShape)
            .clickable(enabled = enabled, onClick = onClick)
            .testTag(tag),
        contentAlignment = Alignment.Center,
    ) {
        val colour = if (enabled) tint else Palette.textTertiary
        if (text != null) Text(text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = colour)
        else if (icon != null) Icon(icon, label, tint = colour, modifier = Modifier.size(21.dp))
    }
}

/**
 * La barre d'évaluation : qui mène, et de combien. Pendant d'`EvalBarView`.
 */
@Composable
fun EvalBar(modifier: Modifier = Modifier, cp: Int?, mate: Int?) {
    val share = when {
        mate != null -> if (mate > 0) 1f else 0f
        cp != null -> (com.chesslab.analysis.EvalConversion.fromCentipawns(cp) / 100).toFloat()
        else -> 0.5f
    }.coerceIn(0.03f, 0.97f)
    Box(
        modifier
            .fillMaxWidth()
            .height(8.dp)
            .clip(CircleShape)
            .background(Palette.surfaceElevated)
            .testTag("barre-eval")
    ) {
        Box(Modifier.fillMaxWidth(share).fillMaxHeight().background(Color.White.copy(alpha = 0.92f)))
    }
}
