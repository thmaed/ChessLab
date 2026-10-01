package com.chesslab.ui

/**
 * Le partage de la largeur entre l'échiquier et le panneau, en paysage.
 * Pendant de `PlayView.panelWidth(in:)` côté iOS.
 *
 * **Le principe d'iOS : l'échiquier prend son carré, le panneau prend ce qui
 * reste**, borné entre un plancher (la largeur utile de la barre de commandes)
 * et un plafond (au-delà, une grande fenêtre éparpille les commandes). Android
 * partageait à parts ÉGALES : sur une tablette de 10 pouces en paysage,
 * l'échiquier tombait à 618 dp quand 736 lui revenaient — le défaut exact
 * qu'un essai sur iPad a montré côté iOS le 29/09/2026.
 *
 * **Un garde-fou propre à Android.** iOS n'atteint jamais une petite fenêtre
 * en largeur : l'iPhone est verrouillé en portrait, et sous 744 pt l'iPad
 * passe à la disposition iPhone. Android, lui, met le plateau et le panneau
 * côte à côte sur un TÉLÉPHONE tenu en paysage et dans une fenêtre partagée.
 * Le plancher de 340 y volerait la place de l'échiquier ; il ne dépasse donc
 * jamais la moitié de la largeur — c'est-à-dire qu'il ne fait jamais pire que
 * l'ancien partage égal.
 */
object BoardLayout {

    /** La largeur utile de la barre de commandes — en dessous, elle déborde. */
    const val PANEL_MIN = 340f

    /** Au-delà, une grande fenêtre éparpille les commandes d'un bord à l'autre. */
    const val PANEL_MAX = 420f

    /**
     * Largeur du panneau, en dp, pour une zone de [width] × [height] dp
     * (marges déjà retirées) dont [gap] dp séparent les deux colonnes.
     */
    fun panelWidth(width: Float, height: Float, gap: Float = 12f): Float {
        val usable = (width - gap).coerceAtLeast(0f)
        val floor = minOf(PANEL_MIN, usable / 2f)
        // L'échiquier prend son carré, borné par la hauteur ; le panneau, le reste.
        val rest = usable - height
        return rest.coerceIn(floor, PANEL_MAX).coerceAtMost(usable)
    }

    /** Le côté de l'échiquier qui en résulte — pour les tests et les relevés. */
    fun boardSide(width: Float, height: Float, gap: Float = 12f): Float =
        minOf(height, (width - gap - panelWidth(width, height, gap)).coerceAtLeast(0f))
}
