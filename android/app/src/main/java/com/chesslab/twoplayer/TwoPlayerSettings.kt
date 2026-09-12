package com.chesslab.twoplayer

import com.chesslab.play.TimeControl

/**
 * Ce qu'on règle avant une partie à deux. Pendant de
 * `TwoPlayerGameSettings.swift`.
 *
 * Les NOMS sont le point qui surprend le plus : on joue à deux autour d'un
 * téléphone, et « Blancs » / « Noirs » ne dit pas qui perd. Une partie rangée
 * dans la bibliothèque sous « Thierry — Camille » se retrouve, une partie
 * rangée sous « Blancs — Noirs » se confond avec toutes les autres.
 */
data class TwoPlayerSettings(
    val whiteName: String = "",
    val blackName: String = "",
    val rotation: RotationMode = RotationMode.faceToFace,
    val timeControlId: String = "none",
    /** Position de départ imposée, venue d'un autre mode. */
    val startFen: String? = null,
) {
    val timeControl: TimeControl get() = TimeControl.byId(timeControlId)

    /** Comment le plateau se présente aux deux joueurs. */
    enum class RotationMode {
        /** Le plateau pivote à 180° après chaque coup : on est assis face à face. */
        faceToFace,

        /** Orientation fixe : on est côte à côte. */
        fixed,

        /**
         * Plateau fixe, mais la ligne du joueur DU HAUT est retournée à 180° :
         * chacun lit ses propres informations à l'endroit depuis son côté de
         * la table, et personne n'a besoin de faire tourner l'appareil.
         */
        tabletop,
    }
}
