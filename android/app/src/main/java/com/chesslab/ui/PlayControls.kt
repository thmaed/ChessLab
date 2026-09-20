package com.chesslab.ui

import com.chesslab.R

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
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
 *
 * Blanc à gauche, noir à droite, et le SCORE ÉCRIT DEDANS — c'est lui qui fait
 * la différence entre une barre qu'on lit et un ruban qu'on devine. Un trait
 * central marque l'égalité : sans repère, une barre remplie aux deux tiers ne
 * dit pas si c'est beaucoup.
 *
 * Rien n'est affiché quand la position est ÉGALE : un « +0,0 » n'apprend rien
 * et fait clignoter la barre à chaque demi-coup.
 */
@Composable
fun EvalBar(
    modifier: Modifier = Modifier,
    cp: Int?,
    mate: Int?,
    /**
     * L'épaisseur. 20 dp partout où la barre est un élément à part entière ;
     * le lecteur d'ouvertures la veut FINE, elle y accompagne l'échiquier au
     * lieu de lui disputer la place.
     */
    height: Dp = EvalBarDefaults.height,
    /** Sous ~14 dp le chiffre ne tient plus : l'écran hôte l'affiche à côté. */
    showsLabel: Boolean = true,
) {
    val white = when {
        mate != null -> if (mate > 0) 1f else 0f
        cp != null -> (com.chesslab.analysis.EvalConversion.fromCentipawns(cp) / 100).toFloat().coerceIn(0f, 1f)
        else -> 0.5f
    }
    // Animée sur la FRACTION, pas sur l'évaluation : un passage cp → mat change
    // la largeur sans changer `cp`, et sautait alors d'un coup.
    val share by animateFloatAsState(white, tween(300), label = "barre-eval")

    val advantage = when {
        mate != null -> if (mate > 0) 1 else if (mate < 0) -1 else 0
        cp == null -> 0
        cp > 5 -> 1
        cp < -5 -> -1
        else -> 0
    }
    val label = when {
        advantage == 0 -> null
        mate != null -> "M${kotlin.math.abs(mate)}"
        // Le POINT, pas la virgule : iOS écrit « +1.5 » dans les deux
        // langues (`String(format:)` y travaille en locale POSIX), et deux
        // apps qui écrivent le même score autrement se remarquent.
        cp != null -> "%+.1f".format(java.util.Locale.ROOT, cp / 100.0)
        else -> null
    }

    val titre = stringResource(R.string.eval_a11y_title)
    val camp = stringResource(
        if (advantage > 0) R.string.eval_a11y_white else R.string.eval_a11y_black
    )
    val lecture = when {
        mate != null -> stringResource(R.string.eval_a11y_mate, kotlin.math.abs(mate), camp)
        advantage == 0 || cp == null -> stringResource(R.string.eval_a11y_equal)
        else -> stringResource(
            R.string.eval_a11y_score,
            "%.1f".format(java.util.Locale.ROOT, kotlin.math.abs(cp) / 100.0),
            camp,
        )
    }

    BoxWithConstraints(
        modifier
            .fillMaxWidth()
            .height(height)
            .clip(CircleShape)
            // Côté noir : léger dégradé pour un peu de matière plutôt qu'un
            // aplat pur.
            .background(Brush.verticalGradient(listOf(Color(0xFF292929), Color(0xFF0A0A0A))))
            .border(if (height >= 14.dp) 1.5.dp else 1.dp, Color.Gray.copy(alpha = 0.55f), CircleShape)
            .testTag("barre-eval")
            .semantics {
                contentDescription = titre
                // La VALEUR lue à voix haute : « +0,8 pour les blancs »,
                // « mat en 3 pour les noirs », « position égale ». Sans elle,
                // le lecteur d'écran annonçait une barre sans rien en dire.
                stateDescription = lecture
            }
    ) {
        Box(
            Modifier
                .fillMaxWidth(share)
                .fillMaxHeight()
                .clip(CircleShape)
                .background(Brush.verticalGradient(listOf(Color.White, Color(0xFFDBDBDB))))
        )
        // Repère central (égalité) : fin trait à mi-largeur.
        Box(
            Modifier
                .align(Alignment.Center)
                .width(1.dp)
                .fillMaxHeight()
                .background(Color.Gray.copy(alpha = 0.4f))
        )
        if (showsLabel && label != null) {
            Text(
                label,
                fontSize = (height.value * 0.55f).coerceIn(9f, 12f).sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                color = if (advantage > 0) Color.Black else Color.White,
                modifier = Modifier
                    .align(if (advantage > 0) Alignment.CenterStart else Alignment.CenterEnd)
                    .padding(horizontal = 9.dp),
            )
        }
    }
}

object EvalBarDefaults {
    /**
     * L'épaisseur de référence — celle des modes Jouer et Analyser, où la
     * barre est un élément à part entière. Exposée pour que les écrans qui
     * réservent sa place dans leur budget de hauteur lisent la même valeur.
     */
    val height: Dp = 20.dp
}
