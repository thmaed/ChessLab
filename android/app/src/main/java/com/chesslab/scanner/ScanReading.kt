package com.chesslab.scanner

import chesskit.Piece
import chesskit.Square
import com.chesslab.editor.FenValidator
import com.chesslab.vision.SquareReading

/**
 * L'orientation de lecture d'un plateau scanné. Pendant de
 * `BoardReadingRotation`.
 *
 * Une image ne dit jamais de quel côté on la regarde — mais un diagramme
 * numérique n'a que DEUX orientations plausibles, Blancs en bas ou en haut.
 * Le quart de tour n'existait que pour la photo zénithale d'un plateau réel,
 * retirée côté iOS le 20/07/2026.
 */
enum class ScanRotation(val degrees: Int) {
    none(0), half(180);

    val flipped: ScanRotation get() = if (this == none) half else none
}

/**
 * Le résultat d'un scan : ce qu'on a lu sur chaque case, et de quoi en faire
 * une position. Pendant de `BoardScanReading`. PUR : testable sans image.
 *
 * @param grid `[ligne][colonne]`, ligne 0 en haut de l'IMAGE, avant rotation.
 */
class ScanReading(val grid: Array<Array<SquareReading>>) {

    /** Les lectures replacées sur l'échiquier pour une orientation donnée. */
    fun squares(rotation: ScanRotation): Map<Square, SquareReading> {
        val rotated = if (rotation == ScanRotation.none) grid else rotated180(grid)
        val out = HashMap<Square, SquareReading>(64)
        for (row in 0 until 8) for (column in 0 until 8) {
            // Après rotation, la ligne 0 est la 8e rangée et la colonne 0 la
            // colonne a — la vue « Blancs en bas ».
            out[Square(Square.File(column + 1), Square.Rank(8 - row))] = rotated[row][column]
        }
        return out
    }

    fun pieces(rotation: ScanRotation): Map<Square, Piece> {
        val out = HashMap<Square, Piece>()
        for ((square, reading) in squares(rotation)) {
            val kind = reading.piece ?: continue
            val color = reading.color ?: continue
            out[square] = Piece(kind, color, square)
        }
        return out
    }

    /** Les cases dont la lecture est douteuse — surlignées à la confirmation. */
    fun lowConfidenceSquares(rotation: ScanRotation): Set<Square> =
        squares(rotation).filterValues { !it.isConfident }.keys

    val pieceCount: Int get() = grid.sumOf { row -> row.count { !it.isEmpty } }

    /**
     * L'orientation à proposer. Une seule orientation qui donne une position
     * LÉGALE tranche la question ; sinon on retient celle dont les pions sont
     * le mieux placés, et l'utilisateur garde la main.
     */
    fun suggestedRotation(sideToMove: Piece.Color = Piece.Color.white): ScanRotation {
        val candidates = ScanRotation.entries
        val legal = candidates.filter { FenValidator.isLegal(fen(it, sideToMove)) }
        if (legal.size == 1) return legal[0]
        return (legal.ifEmpty { candidates }).maxByOrNull { pawnPlausibility(it) } ?: ScanRotation.none
    }

    /**
     * Des pions sur la 1re ou la 8e rangée sont impossibles : c'est le signe le
     * plus net d'une lecture à l'envers. Un pion sur sa rangée de départ est
     * un bon signe.
     */
    private fun pawnPlausibility(rotation: ScanRotation): Int {
        var score = 0
        for ((square, reading) in squares(rotation)) {
            if (reading.piece != Piece.Kind.pawn) continue
            val rank = square.rank.value
            if (rank == 1 || rank == 8) score -= 4
            if ((reading.color == Piece.Color.white && rank == 2) || (reading.color == Piece.Color.black && rank == 7)) score += 1
        }
        return score
    }

    /**
     * La FEN de la lecture. Les droits de roque sont DÉDUITS de la position —
     * roi et tour sur leur case — jamais inventés : une image ne dit pas si le
     * roi a déjà bougé. L'utilisateur les corrige à la confirmation.
     */
    fun fen(rotation: ScanRotation, sideToMove: Piece.Color): String {
        val pieces = pieces(rotation)
        val rows = (8 downTo 1).joinToString("/") { rank ->
            val sb = StringBuilder(); var empty = 0
            for (file in 1..8) {
                val piece = pieces[Square(Square.File(file), Square.Rank(rank))]
                if (piece == null) { empty++; continue }
                if (empty > 0) { sb.append(empty); empty = 0 }
                sb.append(letter(piece))
            }
            if (empty > 0) sb.append(empty)
            sb.toString()
        }
        val castling = buildString {
            if (canCastle(pieces, Piece.Color.white, "e1", "h1")) append('K')
            if (canCastle(pieces, Piece.Color.white, "e1", "a1")) append('Q')
            if (canCastle(pieces, Piece.Color.black, "e8", "h8")) append('k')
            if (canCastle(pieces, Piece.Color.black, "e8", "a8")) append('q')
        }.ifEmpty { "-" }
        return "$rows ${if (sideToMove == Piece.Color.white) "w" else "b"} $castling - 0 1"
    }

    private fun canCastle(pieces: Map<Square, Piece>, color: Piece.Color, king: String, rook: String): Boolean {
        val k = pieces[Square(king)]; val r = pieces[Square(rook)]
        return k?.kind == Piece.Kind.king && k.color == color && r?.kind == Piece.Kind.rook && r.color == color
    }

    private fun letter(piece: Piece): String {
        val l = when (piece.kind) {
            Piece.Kind.pawn -> "P"; Piece.Kind.knight -> "N"; Piece.Kind.bishop -> "B"
            Piece.Kind.rook -> "R"; Piece.Kind.queen -> "Q"; Piece.Kind.king -> "K"
        }
        return if (piece.color == Piece.Color.white) l else l.lowercase()
    }

    companion object {
        /** Sous ce seuil, la case est signalée à l'utilisateur. Même valeur qu'iOS. */
        const val CONFIDENCE_THRESHOLD = 0.55

        /** Un demi-tour : la case (r, c) va en (7 − r, 7 − c). */
        fun rotated180(grid: Array<Array<SquareReading>>): Array<Array<SquareReading>> =
            Array(8) { row -> Array(8) { column -> grid[7 - row][7 - column] } }
    }
}

/** Confiant = au-dessus du seuil ; une case vide est réputée sûre. */
val SquareReading.isConfident: Boolean
    get() = isEmpty || confidence >= ScanReading.CONFIDENCE_THRESHOLD
