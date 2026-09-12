package com.chesslab.analysis

import androidx.annotation.StringRes
import androidx.compose.ui.graphics.Color
import com.chesslab.R

/**
 * L'échelle sur laquelle CHAQUE coup joué est classé. Pendant de
 * `MoveQualityBadge.swift`.
 *
 * Pas de coup « sans catégorie » : un coup sain est dit sain, pas passé sous
 * silence.
 */
enum class MoveQuality(@StringRes val labelRes: Int, val tint: Color) {
    /** `!!` — sacrifice correct et nettement supérieur. */
    brilliant(R.string.quality_brilliant, Color(0.10f, 0.72f, 0.65f)),
    /** `!` — le seul bon coup de la position. */
    great(R.string.quality_great, Color(0.35f, 0.56f, 0.90f)),
    /** Le premier choix du moteur. */
    best(R.string.quality_best, Color(0.42f, 0.72f, 0.30f)),
    /** Quasi sans perte. */
    excellent(R.string.quality_excellent, Color(0.51f, 0.71f, 0.36f)),
    /** Perte modeste, coup sain. */
    good(R.string.quality_good, Color(0.46f, 0.60f, 0.44f)),
    /** Encore dans la théorie connue. */
    book(R.string.quality_book, Color(0.66f, 0.60f, 0.48f)),
    inaccuracy(R.string.quality_inaccuracy, Color(0.94f, 0.78f, 0.31f)),
    mistake(R.string.quality_mistake, Color(0.95f, 0.55f, 0.25f)),
    /** `✕` — occasion manquée : la victoire était là. */
    miss(R.string.quality_miss, Color(0.93f, 0.45f, 0.40f)),
    blunder(R.string.quality_blunder, Color(0.85f, 0.25f, 0.25f));

    /**
     * Le signe porté par la pastille. Les catégories que la notation d'échecs
     * ne sait pas écrire portent un glyphe à la place (voir [icon]).
     */
    val symbol: String?
        get() = when (this) {
            brilliant -> "!!"
            great -> "!"
            inaccuracy -> "?!"
            mistake -> "?"
            blunder -> "??"
            miss -> "✕"
            best -> "★"
            excellent -> "👍"
            good -> "✓"
            book -> "📖"
        }

    /**
     * Les catégories qui MARQUENT la courbe d'évaluation : les moments où la
     * partie a basculé (ou aurait pu). Une courbe criblée de pastilles ne
     * montrerait plus rien, et c'est le décrochage qu'on cherche du regard.
     */
    val marksCriticalPhase: Boolean
        get() = this == brilliant || this == great || this == miss ||
            this == mistake || this == blunder

    /**
     * Les catégories qui appellent une correction : la flèche rétrospective
     * « il fallait jouer ça » et l'explication n'ont de sens que pour elles.
     */
    val isFault: Boolean
        get() = this == inaccuracy || this == mistake || this == miss || this == blunder

    /**
     * Symbole dans le ruban de coups : seulement les catégories REMARQUABLES.
     * Un symbole sur chaque coup (la moitié sont « meilleur » ou « bon »)
     * noierait précisément ce qu'on veut voir en balayant la partie.
     */
    val showsInMoveList: Boolean
        get() = this == brilliant || this == great || this == miss ||
            this == inaccuracy || this == mistake || this == blunder

    /**
     * Notation NAG pour l'export PGN. Les catégories que la notation d'échecs
     * ne connaît pas partent sans annotation — un PGN constellé de signes
     * inventés ne serait lu par aucun autre logiciel.
     */
    val nag: Int?
        get() = when (this) {
            brilliant -> 3       // !!
            great -> 1           // !
            inaccuracy -> 6      // ?!
            mistake, miss -> 2   // ?
            blunder -> 4         // ??
            best, excellent, good, book -> null
        }
}
