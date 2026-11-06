package com.chesslab.vision

import chesskit.Piece

/**
 * Contrôles de cohérence d'échecs appliqués à une grille lue, quel que soit le
 * classifieur qui l'a produite (détecteur ou gabarits).
 *
 * Traduction de `BoardConsistency.swift` (ChessLab). Une lecture IMPOSSIBLE aux
 * échecs — un pion sur la rangée de fond, deux rois d'une couleur — trahit une
 * confusion que la confiance brute n'a pas signalée. On ne CORRIGE jamais en
 * silence : on fait chuter la confiance des cases fautives sous le seuil de
 * signalement, pour qu'elles soient surlignées à la confirmation.
 *
 * Pur (grille → grille), sans image ni état.
 */
object BoardConsistency {

    /** Confiance imposée à une case qui viole une règle dure — sous le seuil de signalement (0,55). */
    const val VIOLATION_CONFIDENCE = 0.2

    /** Position dans la grille brute, ligne 0 en haut. */
    data class Cell(val row: Int, val column: Int)

    /** Grille inchangée dans ses OCCUPATIONS, dont la confiance des cases incohérentes est abaissée. */
    fun reconciled(grid: Array<Array<SquareReading>>): Array<Array<SquareReading>> {
        val suspects = suspectCells(grid)
        if (suspects.isEmpty()) return grid
        return Array(grid.size) { row ->
            Array(grid[row].size) { column ->
                val reading = grid[row][column]
                if (Cell(row, column) !in suspects) reading
                else reading.copy(confidence = minOf(reading.confidence, VIOLATION_CONFIDENCE))
            }
        }
    }

    /**
     * Cases dont la lecture contredit une règle dure des échecs. On ne retient
     * que les règles qui se LOCALISENT sur une case précise : les simples
     * improbabilités sont écartées (deux fous de même couleur de case restent
     * légaux après promotion, une dame en trop aussi).
     */
    fun suspectCells(grid: Array<Array<SquareReading>>): Set<Cell> {
        val suspects = HashSet<Cell>()
        val kings = Piece.Color.entries.associateWith { ArrayList<Cell>() }
        val queens = Piece.Color.entries.associateWith { ArrayList<Cell>() }
        val pawns = Piece.Color.entries.associateWith { ArrayList<Pair<Cell, Double>>() }

        val lastRow = grid.size - 1
        for (row in grid.indices) for (column in grid[row].indices) {
            val reading = grid[row][column]
            val kind = reading.piece ?: continue
            val color = reading.color ?: continue
            val cell = Cell(row, column)

            // Pion sur une rangée extrême : impossible, quelle que soit l'orientation 0°/180°.
            if (kind == Piece.Kind.pawn && (row == 0 || row == lastRow)) suspects += cell

            when (kind) {
                Piece.Kind.king -> kings.getValue(color) += cell
                Piece.Kind.queen -> queens.getValue(color) += cell
                Piece.Kind.pawn -> pawns.getValue(color) += cell to reading.confidence
                else -> Unit
            }
        }

        for (color in Piece.Color.entries) {
            val colorKings = kings.getValue(color)
            // Deux rois d'une couleur : l'un est faux, on ne sait pas lequel.
            if (colorKings.size > 1) suspects += colorKings
            // Aucun roi : le plus souvent lu comme une DAME (la confusion nº 1 du modèle).
            if (colorKings.isEmpty()) suspects += queens.getValue(color)
            // Plus de 8 pions : on signale les MOINS sûrs au-delà de 8.
            val colorPawns = pawns.getValue(color).sortedByDescending { it.second }
            if (colorPawns.size > 8) for (extra in colorPawns.drop(8)) suspects += extra.first
        }
        return suspects
    }
}
