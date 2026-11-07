package com.chesslab.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * L'état d'un GRAND titre qui se réduit quand on fait défiler — l'équivalent du
 * grand titre de navigation d'iOS.
 *
 * Le titre est un en-tête de hauteur [maxHeightPx] : faire défiler l'écran vers
 * le haut l'avale d'abord (le contenu ne bouge qu'ensuite), et le ramener en
 * haut le restitue. [connection] se pose sur un parent des défilements : il
 * reçoit leurs gestes sans que l'écran ait rien à savoir de lui.
 */
class TitleCollapse(val maxHeightPx: Float) {
    /** De 0 (grand titre entier) à `-maxHeightPx` (réduit dans la barre). */
    var offset by mutableFloatStateOf(0f)
        private set

    /** 0 : titre entier ; 1 : titre réduit. */
    val fraction: Float get() = if (maxHeightPx <= 0f) 1f else (-offset / maxHeightPx).coerceIn(0f, 1f)

    val connection = object : NestedScrollConnection {
        /** Un geste vers le haut : le titre se réduit AVANT que le contenu ne défile. */
        override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
            if (available.y >= 0f || offset <= -maxHeightPx) return Offset.Zero
            val next = (offset + available.y).coerceAtLeast(-maxHeightPx)
            val consumed = next - offset
            offset = next
            return Offset(0f, consumed)
        }

        /** Un geste vers le bas que le contenu n'a pas pris (il est arrivé en haut) : le titre se rouvre. */
        override fun onPostScroll(consumed: Offset, available: Offset, source: NestedScrollSource): Offset {
            if (available.y <= 0f || offset >= 0f) return Offset.Zero
            val next = (offset + available.y).coerceAtMost(0f)
            val taken = next - offset
            offset = next
            return Offset(0f, taken)
        }
    }
}

/** Hauteur de la zone du grand titre, développée. */
val LargeTitleHeight = 52.dp

/**
 * La barre d'un écran de menu : flèche de retour et actions en haut, puis le
 * titre en GRAND (34 sp, gras, à gauche) — comme les écrans de menu d'iOS. Quand
 * [collapse] avance, le grand titre s'efface et le même mot apparaît, petit, dans
 * la rangée du haut.
 */
@Composable
fun LargeTitleBar(
    title: String,
    collapse: TitleCollapse,
    actions: (@Composable RowScope.() -> Unit)?,
    onBack: () -> Unit,
) {
    val density = LocalDensity.current
    androidx.compose.foundation.layout.Column(Modifier.fillMaxWidth()) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onBack, modifier = Modifier.testTag("retour")) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, "Retour", tint = Palette.textPrimary)
            }
            // Un seul des deux titres existe à la fois (hors transition) : deux fois le
            // même mot dans l'arbre embrouillait les tests et les lecteurs d'écran.
            if (collapse.fraction > 0f) {
                Text(
                    title, style = MaterialTheme.typography.titleMedium, color = Palette.textPrimary,
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false).graphicsLayer { alpha = collapse.fraction },
                )
            }
            Spacer(Modifier.weight(1f))
            actions?.invoke(this)
        }
        // Le grand titre : la zone rétrécit avec le défilement, le texte reste ancré en bas.
        if (collapse.fraction < 1f) Box(
            Modifier
                .fillMaxWidth()
                .height(with(density) { (collapse.maxHeightPx + collapse.offset).coerceAtLeast(0f).toDp() })
                .clipToBounds()
                .testTag("grand-titre"),
            contentAlignment = Alignment.BottomStart,
        ) {
            Text(
                title,
                fontSize = 34.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary,
                maxLines = 1, overflow = TextOverflow.Ellipsis,
                modifier = Modifier
                    .padding(start = 16.dp, end = 16.dp, bottom = 6.dp)
                    .graphicsLayer { alpha = 1f - collapse.fraction },
            )
        }
    }
}
