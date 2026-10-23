package com.chesslab.puzzles

import chesskit.Board
import chesskit.Piece
import chesskit.Position
import chesskit.Square

/**
 * Un mat forcé que le camp au trait tenait, et que le coup joué a laissé
 * filer — candidat à un puzzle « Mat » de vos parties. Pendant de
 * `MissedMate` (`MissedMateDetector.swift`).
 */
data class MissedMate(
    /** Position d'avant le coup joué : au camp qui y a le trait de mater. */
    val fen: String,
    val playedSan: String,
    /** La ligne COMPLÈTE jusqu'au mat, en LAN — jamais tronquée. */
    val solution: List<String>,
    val mateIn: Int,
    val mover: Piece.Color,
    /** Numéro du coup dans la partie, pour le dire à l'utilisateur. */
    val moveNumber: Int,
)

/**
 * Les règles pures de la recherche des mats manqués. Pendant de
 * `MissedMateDetector.swift`, mêmes seuils.
 *
 * Pourquoi PAS [PuzzleSolutionTrimmer] : il plafonne une solution à six
 * demi-coups et la coupe dès qu'un gain de matériel est acquis. Un mat en trois
 * avec sacrifice aurait été coupé AVANT le mat.
 */
object MissedMateDetector {
    /** Au-delà, la ligne se calcule mal de tête : des mats en 5 au plus. */
    const val MAX_MATE_MOVES = 5

    /**
     * Seuil de présélection, en probabilité de gain du camp au trait (0…100) :
     * environ +9,5. Tout mat court y est ; la recherche dédiée, plus chère,
     * n'est lancée que sur ces positions.
     */
    const val CANDIDATE_WIN_PERCENT = 97.0

    private val LAN = Regex("[a-h][1-8][a-h][1-8][qrbn]?")

    fun mightHoldMate(winPercentForMover: Double): Boolean = winPercentForMover >= CANDIDATE_WIN_PERCENT

    /**
     * La ligne jusqu'au mat, si la variante du moteur y mène : rejouée depuis
     * [startFen] et coupée au premier mat. `null` si elle est illégale,
     * n'aboutit pas, ou dépasse [MAX_MATE_MOVES] coups du résolveur.
     */
    fun solution(pv: List<String>, startFen: String): List<String>? {
        val start = Position.fromFen(startFen) ?: return null
        val board = Board(start)
        val line = ArrayList<String>()
        for (lan in pv.take(2 * MAX_MATE_MOVES - 1)) {
            // `Square("e9")` ne refuse pas : il ramène la rangée dans les
            // bornes. Une notation fautive doit être rejetée AVANT.
            if (!LAN.matches(lan)) return null
            val from = Square(lan.substring(0, 2))
            val to = Square(lan.substring(2, 4))
            // ChessKit ne consulte pas le trait : on le vérifie ici.
            if (board.position.piece(from)?.color != board.position.sideToMove) return null
            if (!board.canMove(pieceAt = from, to = to)) return null
            val move = board.move(pieceAt = from, to = to) ?: return null
            if (board.state is Board.State.Promotion) {
                val kind = when (lan.getOrNull(4)) {
                    'r' -> Piece.Kind.rook
                    'b' -> Piece.Kind.bishop
                    'n' -> Piece.Kind.knight
                    else -> Piece.Kind.queen
                }
                board.completePromotion(of = move, to = kind)
            }
            line += lan
            if (board.state is Board.State.Checkmate) return line
        }
        return null
    }

    /** Numéro de coup lu dans la FEN (6e champ), 1 à défaut. */
    fun moveNumber(fen: String): Int =
        fen.split(" ").getOrNull(5)?.toIntOrNull() ?: 1
}
