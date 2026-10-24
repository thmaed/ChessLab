package com.chesslab.analysis

import chesskit.Piece

/**
 * Le bilan chiffré d'une partie analysée : par joueur, la précision et le
 * décompte de chaque catégorie de coup. Pendant de `GameSummary.swift`.
 *
 * Calcul PUR à partir des classifications déjà faites — aucune requête moteur,
 * donc affichable à tout moment, y compris pendant que la classification se
 * complète.
 */
data class GameSummary(
    val white: Side = Side(),
    val black: Side = Side(),
    /**
     * Vrai tant que tous les coups de la partie n'ont pas leur catégorie — le
     * bilan l'affiche pour ne pas faire passer un décompte partiel pour un
     * décompte définitif.
     */
    val isComplete: Boolean = false,
    /** A4 : l'ouverture reconnue à la fin de la théorie, pour dire lesquelles coûtent des points. */
    val openingName: String? = null,
) {
    data class Side(
        val accuracy: Double? = null,
        val counts: Map<MoveQuality, Int> = emptyMap(),
        /** Nombre de coups déjà classifiés pour ce joueur. */
        val classifiedCount: Int = 0,
        /**
         * Perte moyenne de probabilité de gain, en points de pourcentage, NON
         * pondérée et HORS THÉORIE.
         *
         * Réciter dix coups de Najdorf ne dit rien du niveau de personne : la
         * perte y est nulle par construction, et l'inclure ferait passer pour
         * fort quiconque connaît une longue ligne.
         */
        val averageLoss: Double? = null,
        /** Coups de théorie reconnus, écartés de la moyenne ci-dessus. */
        val bookCount: Int = 0,
        /** A4 : perte de probabilité de gain par phase, hors théorie. */
        val phases: Map<com.chesslab.puzzles.GamePhase, PhaseLoss> = emptyMap(),
        /** A4 : fautes par motif tactique (`other` quand la réfutation ne se résume à aucun motif nommé). */
        val themes: Map<String, Int> = emptyMap(),
    ) {
        fun count(quality: MoveQuality): Int = counts[quality] ?: 0
    }

    fun side(color: Piece.Color): Side = if (color == Piece.Color.white) white else black

    companion object {
        /** Un coup classé, réduit à ce que le bilan regarde. */
        data class Entry(
            val mover: Piece.Color,
            val quality: MoveQuality,
            /** Perte de probabilité de gain pour le joueur qui vient de jouer. */
            val loss: Double,
            /** A4 : phase du coup, et — si c'est une faute — son motif. */
            val phase: com.chesslab.puzzles.GamePhase = com.chesslab.puzzles.GamePhase.middlegame,
            val faultTheme: String? = null,
        )

        /**
         * Agrège les classifications. [entries] est donné dans l'ordre de la
         * partie, ce qui suffit : le bilan ne dépend pas des index.
         */
        fun compute(
            entries: List<Entry>,
            totalMoves: Int,
            accuracyByColor: Map<Piece.Color, Double>,
            openingName: String? = null,
        ): GameSummary {
            fun side(color: Piece.Color): Side {
                val mine = entries.filter { it.mover == color }
                val scored = mine.filter { it.quality != MoveQuality.book }
                val phases = HashMap<com.chesslab.puzzles.GamePhase, PhaseLoss>()
                for (entry in scored) {
                    val current = phases[entry.phase] ?: PhaseLoss()
                    phases[entry.phase] = PhaseLoss(current.total + maxOf(0.0, entry.loss), current.count + 1)
                }
                val themes = HashMap<String, Int>()
                for (entry in mine) entry.faultTheme?.let { themes[it] = (themes[it] ?: 0) + 1 }
                return Side(
                    accuracy = accuracyByColor[color],
                    phases = phases, themes = themes,
                    counts = mine.groupingBy { it.quality }.eachCount(),
                    classifiedCount = mine.size,
                    averageLoss = if (scored.isEmpty()) null
                    else scored.sumOf { maxOf(0.0, it.loss) } / scored.size,
                    bookCount = mine.size - scored.size,
                )
            }
            return GameSummary(
                white = side(Piece.Color.white),
                black = side(Piece.Color.black),
                isComplete = entries.size >= totalMoves && totalMoves > 0,
                openingName = openingName,
            )
        }
    }
}
