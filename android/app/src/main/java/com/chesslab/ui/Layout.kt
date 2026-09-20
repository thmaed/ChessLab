package com.chesslab.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.widthIn
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Ce qu'il faut savoir de la largeur de l'écran. Pendant du
 * `horizontalSizeClass` d'iOS et de `Theme.readableWidth`.
 *
 * Android n'avait rien de tel : l'app était mise en page pour un téléphone et
 * s'étirait sur une tablette sans se reconsidérer. Huit tuiles s'alignaient
 * sur une rangée de sept plus une orpheline, et les deux tiers du bas
 * restaient noirs. Rien n'était cassé — rien n'était mis en page.
 *
 * Viser le SDK 36 rend la chose obligatoire : Android 16 IGNORE les
 * restrictions de redimensionnement sur grand écran, donc l'app y sera
 * redimensionnable qu'on le veuille ou non.
 */
object Metrics {

    /**
     * La MESURE DE LECTURE : au-delà, une ligne de texte devient illisible
     * parce que l'œil perd la ligne suivante en revenant à la marge.
     *
     * 720 dp, la valeur d'iOS (`Theme.readableWidth`), qui tient une ligne
     * autour de 70-90 caractères. À employer avec [readable], qui borne ET
     * recentre — bornée sans recentrer, la colonne se collerait à gauche.
     */
    val readableWidth: Dp = 720.dp

    /**
     * La largeur MINIMALE d'une tuile de mode, sur téléphone puis sur grand
     * écran. Ce sont les deux valeurs d'iOS (`ModeGridMetrics`).
     *
     * 132 parce qu'à 320 dp d'écran il faut encore DEUX colonnes ; 178 parce
     * qu'au-delà les tuiles portent leurs libellés LONGS, et qu'à 132 une
     * fenêtre large en ouvrait cinq, trop étroites pour ce texte.
     */
    val minTilePhone: Dp = 132.dp
    val minTileRegular: Dp = 178.dp

    /**
     * Le seuil au-delà duquel on n'est plus sur un téléphone en portrait.
     *
     * 600 dp : c'est la frontière d'Android entre « compact » et le reste,
     * et elle tombe au même endroit que la classe *regular* d'iOS — un iPad
     * en portrait fait 768 pt, un téléphone n'atteint jamais 600.
     */
    val regularBreakpoint: Dp = 600.dp
}

/**
 * Borne le contenu à la mesure de lecture et le CENTRE.
 *
 * Les deux vont ensemble : borner sans recentrer colle la colonne à gauche et
 * laisse un demi-écran vide à droite, ce qui est pire que de tout étirer.
 */
fun Modifier.readable(largeur: Dp = Metrics.readableWidth): Modifier =
    // L'ORDRE compte, et il n'est pas intuitif : `widthIn` D'ABORD, qui abaisse
    // la largeur disponible, `fillMaxWidth` ENSUITE, qui la remplit. Écrit dans
    // l'autre sens, `fillMaxWidth` fixe la largeur du parent et `widthIn` ne
    // peut plus la réduire — la borne est simplement perdue, sans un mot.
    this.widthIn(max = largeur).fillMaxWidth()

/**
 * Une colonne bornée et centrée — le gabarit des écrans qui se lisent.
 *
 * @param maxWidth la borne ; la mesure de lecture par défaut.
 */
@Composable
fun ReadableColumn(
    modifier: Modifier = Modifier,
    maxWidth: Dp = Metrics.readableWidth,
    verticalArrangement: Arrangement.Vertical = Arrangement.Top,
    horizontalAlignment: Alignment.Horizontal = Alignment.Start,
    content: @Composable ColumnScope.() -> Unit,
) {
    Box(modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
        Column(
            // `widthIn` avant `fillMaxWidth` : voir [readable].
            Modifier.widthIn(max = maxWidth).fillMaxWidth(),
            verticalArrangement = verticalArrangement,
            horizontalAlignment = horizontalAlignment,
            content = content,
        )
    }
}

/**
 * Le nombre de COLONNES d'une grille de tuiles, pour une largeur donnée.
 *
 * Reprend le calcul d'iOS : on prend la largeur utile, on la divise par la
 * largeur minimale d'une tuile — plus large sur grand écran, où les libellés
 * sont longs — et on ne descend jamais sous deux.
 */
fun tileColumns(width: Dp, padding: Dp, spacing: Dp): Int {
    val minTile = if (width >= Metrics.regularBreakpoint) Metrics.minTileRegular else Metrics.minTilePhone
    val usable = width - padding * 2
    return ((usable + spacing).value / (minTile + spacing).value).toInt().coerceAtLeast(2)
}
