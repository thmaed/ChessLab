package com.chesslab.vision

import chesskit.Piece

/** Une pièce détectée sur le plateau redressé. */
data class Detection(
    val color: Piece.Color,
    val kind: Piece.Kind,
    val confidence: Double,
    /** Boîte normalisée 0…1, origine en HAUT à gauche. */
    val left: Double,
    val top: Double,
    val right: Double,
    val bottom: Double,
) {
    val midX: Double get() = (left + right) / 2
}

/** Ce qu'on lit sur une case. */
data class SquareReading(val piece: Piece.Kind?, val color: Piece.Color?, val confidence: Double) {
    val isEmpty: Boolean get() = piece == null
}

/**
 * Traduit une liste de détections en grille 8×8, puis en FEN.
 *
 * Traduction Kotlin de `YOLODetectionMapper` (ChessLab). PUR — aucun modèle,
 * aucune image : c'est ce qui rend la seule partie subtile, celle qui peut
 * casser en silence, testable au carré près.
 */
object BoardReader {

    /**
     * Confiance d'une case laissée VIDE. L'absence n'est pas une preuve — une
     * pièce ratée ressemble à une case vide — mais rester sous le seuil de
     * signalement inonderait l'écran de confirmation.
     */
    const val EMPTY_CONFIDENCE = 0.9

    private const val HALF_CELL = 1.0 / 16

    /** La grille `[ligne][colonne]`, ligne 0 en HAUT de l'image. */
    fun grid(detections: List<Detection>): Array<Array<SquareReading>> {
        val grid = Array(8) { Array(8) { SquareReading(null, null, 0.0) } }
        val best = Array(8) { DoubleArray(8) }

        for (detection in detections) {
            // La pièce « pose » près du BAS de sa boîte : on l'ancre sur le bas
            // — robuste aux glyphes hauts comme le roi, dont le sommet déborde
            // de la case — puis on remonte d'une demi-case. Sans cette
            // remontée, le bas de boîte tomberait pile sur la ligne de grille
            // et basculerait dans la case du dessous.
            val column = clamp((detection.midX * 8).toInt())
            val row = clamp(((detection.bottom - HALF_CELL) * 8).toInt())

            if (detection.confidence <= best[row][column]) continue
            best[row][column] = detection.confidence
            grid[row][column] = SquareReading(detection.kind, detection.color, detection.confidence)
        }

        for (row in 0 until 8) {
            for (column in 0 until 8) {
                if (grid[row][column].isEmpty) {
                    grid[row][column] = SquareReading(null, null, EMPTY_CONFIDENCE)
                }
            }
        }
        return grid
    }

    /**
     * Le placement FEN d'une grille, ligne 0 en haut = 8e rangée.
     *
     * Rend seulement le PLACEMENT : le trait, les roques et la prise en
     * passant ne se lisent pas sur une photo — c'est à l'utilisateur de les
     * confirmer.
     */
    fun placement(grid: Array<Array<SquareReading>>): String {
        val sb = StringBuilder()
        for (row in 0 until 8) {
            var empty = 0
            for (column in 0 until 8) {
                val square = grid[row][column]
                val kind = square.piece
                if (kind == null) { empty++; continue }
                if (empty > 0) { sb.append(empty); empty = 0 }
                val letter = when (kind) {
                    Piece.Kind.pawn -> "p"; Piece.Kind.knight -> "n"; Piece.Kind.bishop -> "b"
                    Piece.Kind.rook -> "r"; Piece.Kind.queen -> "q"; Piece.Kind.king -> "k"
                }
                sb.append(if (square.color == Piece.Color.white) letter.uppercase() else letter)
            }
            if (empty > 0) sb.append(empty)
            if (row < 7) sb.append("/")
        }
        return sb.toString()
    }

    /** Les cases dont la lecture est douteuse — celles à confirmer en premier. */
    fun uncertain(grid: Array<Array<SquareReading>>, threshold: Double = 0.6): Int =
        grid.sumOf { row -> row.count { !it.isEmpty && it.confidence < threshold } }

    private fun clamp(value: Int) = value.coerceIn(0, 7)
}
