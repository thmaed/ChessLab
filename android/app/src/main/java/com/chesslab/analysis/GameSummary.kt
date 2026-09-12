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
        )

        /**
         * Agrège les classifications. [entries] est donné dans l'ordre de la
         * partie, ce qui suffit : le bilan ne dépend pas des index.
         */
        fun compute(
            entries: List<Entry>,
            totalMoves: Int,
            accuracyByColor: Map<Piece.Color, Double>,
        ): GameSummary {
            fun side(color: Piece.Color): Side {
                val mine = entries.filter { it.mover == color }
                val scored = mine.filter { it.quality != MoveQuality.book }
                return Side(
                    accuracy = accuracyByColor[color],
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
            )
        }
    }
}
