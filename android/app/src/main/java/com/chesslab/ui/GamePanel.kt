package com.chesslab.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.composed
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.res.stringResource
import com.chesslab.R
import androidx.compose.ui.text.font.FontWeight

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
 * La bande des coups, en notation abrégée. Pendant de `MoveStripView.swift`
 * et de `VariantMoveStripView.swift`, qui ont le même langage visuel.
 *
 * Une CAPSULE par demi-coup, et non un mot posé sur le fond : c'est la bordure
 * de la capsule qui porte la couleur de la catégorie, et un coup remarquable
 * se repère alors en balayant la bande, sans lire. Le coup affiché prend le
 * dégradé d'accent — la même marque que partout ailleurs dans l'app pour dire
 * « vous êtes ici ».
 *
 * [selected] surligne le coup courant : c'est ce qui permet de naviguer dans
 * une partie analysée.
 */
@Composable
fun MoveStrip(
    moves: List<String>,
    selected: Int? = null,
    /**
     * La catégorie de chaque coup, par index — le ruban n'en montre que les
     * REMARQUABLES (voir `MoveQuality.showsInMoveList`). Un symbole sur chaque
     * coup, alors que la moitié sont « meilleur » ou « bon », noierait
     * précisément ce qu'on cherche en balayant la partie : les moments où elle
     * a basculé.
     */
    qualities: Map<Int, com.chesslab.analysis.MoveQuality> = emptyMap(),
    onSelect: ((Int) -> Unit)? = null,
) {
    val scroll = rememberScrollState()
    // Les abscisses des capsules, mesurées. Il en faut pour CENTRER le coup
    // affiché : une bande qui reste collée à la fin ne montre plus celui qu'on
    // regarde dès qu'on revient en arrière, et c'est à ce moment-là qu'on la
    // regarde. iOS centre aussi (`proxy.scrollTo(anchor: .center)`).
    //
    // Toutes les capsules sont COMPOSÉES, y compris hors écran — une `LazyRow`
    // aurait été plus économe, mais un coup non composé n'existe ni pour le
    // lecteur d'écran ni pour les tests d'interface, qui touchent le huitième
    // coup d'une partie sans l'avoir fait défiler.
    val centres = remember { mutableStateMapOf<Int, Int>() }
    var viewport by remember { mutableIntStateOf(0) }
    LaunchedEffect(selected, moves.size, centres.size, viewport) {
        val cible = selected ?: moves.lastIndex
        val centre = centres[cible] ?: return@LaunchedEffect
        scroll.animateScrollTo((centre - viewport / 2).coerceIn(0, scroll.maxValue))
    }

    if (moves.isEmpty()) {
        Box(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Palette.surface)
                .padding(10.dp)
        ) {
            Text(stringResource(R.string.no_moves_played), fontSize = 13.sp, color = Palette.textSecondary)
        }
        return
    }

    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Palette.surface)
            .onSizeChanged { viewport = it.width }
            .horizontalScroll(scroll)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        moves.forEachIndexed { index, san ->
            MoveChip(
                number = if (index % 2 == 0) "${index / 2 + 1}." else null,
                san = san,
                quality = qualities[index]?.takeIf { it.showsInMoveList },
                current = index == selected,
                index = index,
                onSelect = onSelect,
                onPlaced = { centre -> centres[index] = centre },
            )
        }
    }
}

@Composable
private fun MoveChip(
    number: String?,
    san: String,
    quality: com.chesslab.analysis.MoveQuality?,
    current: Boolean,
    index: Int,
    onSelect: ((Int) -> Unit)?,
    onPlaced: (Int) -> Unit,
) {
    val forme = CircleShape
    Row(
        Modifier
            .onGloballyPositioned { onPlaced((it.positionInParent().x + it.size.width / 2).toInt()) }
            .clip(forme)
            .then(
                if (current) Modifier.background(
                    Brush.linearGradient(listOf(Palette.accent, Palette.accentSecondary))
                ) else Modifier.background(Palette.surfaceElevated)
            )
            .border(
                if (quality == null) 1.dp else 1.5.dp,
                // La bordure de qualité s'efface sous le dégradé d'accent :
                // deux couleurs fortes sur la même capsule se disputeraient.
                quality?.tint?.copy(alpha = if (current) 0f else 0.7f) ?: Palette.stroke,
                forme,
            )
            .then(if (onSelect != null) Modifier.clickableNoRipple { onSelect(index) } else Modifier)
            .padding(horizontal = 9.dp, vertical = 6.dp)
            .testTag("coup-$index"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        if (number != null) {
            Text(
                number,
                fontSize = 11.sp,
                color = if (current) Palette.background.copy(alpha = 0.7f) else Palette.textTertiary,
            )
        }
        Text(
            sanText(san),
            fontSize = 14.sp,
            fontWeight = if (current) FontWeight.Bold else FontWeight.Medium,
            color = if (current) Palette.background else Palette.textPrimary,
        )
        if (quality != null) {
            Text(
                quality.symbol ?: "",
                fontSize = 11.sp,
                fontWeight = FontWeight.Black,
                color = if (current) Palette.background else quality.tint,
                modifier = Modifier.testTag("qualite-$index"),
            )
        }
    }
}

/** Un clic sans l'ondulation : dans une bande de coups, elle fait du bruit. */
private fun Modifier.clickableNoRipple(onClick: () -> Unit): Modifier = composed {
    clickable(
        indication = null,
        interactionSource = remember { MutableInteractionSource() },
        onClick = onClick,
    )
}
