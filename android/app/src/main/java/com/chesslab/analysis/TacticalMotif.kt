package com.chesslab.analysis

import chesskit.Board
import chesskit.Move
import chesskit.Piece
import chesskit.Square

/**
 * Le motif tactique qui PUNIT un coup — ce que l'adversaire va en faire.
 * Pendant de `TacticalMotif.swift`.
 *
 * Chaque cas est établi en REJOUANT la réfutation du moteur sur un plateau,
 * jamais inféré d'un score : c'est toute la différence entre « votre coup perd
 * 12 % » et « votre coup perd une pièce, et voici comment ». Un motif faux
 * serait pire que pas de motif du tout — dans une app d'apprentissage, une
 * explication inventée s'apprend aussi bien qu'une vraie.
 */
sealed class TacticalMotif {
    /** La réfutation mate. [inMoves] compte les coups du camp qui mate. */
    data class Checkmate(val inMoves: Int, val isBackRank: Boolean) : TacticalMotif()

    /** Une pièce de valeur est simplement prise, et rien ne peut reprendre. */
    data class HangingPiece(val kind: Piece.Kind, val on: Square) : TacticalMotif()

    /** Une pièce attaque au moins deux cibles de valeur : on ne peut pas toutes les sauver. */
    data class Fork(val by: Piece.Kind, val on: Square, val targets: List<Piece.Kind>) : TacticalMotif()

    /** L'échec ne vient pas de la pièce qui a bougé mais de celle qu'elle démasque. */
    data class DiscoveredCheck(val by: Piece.Kind) : TacticalMotif()

    /** Une pièce est clouée : la bouger exposerait une pièce plus chère derrière elle. */
    data class Pin(val victim: Piece.Kind, val behind: Piece.Kind) : TacticalMotif()
}

/**
 * Reconnaît le motif d'UN coup — celui que l'adversaire joue pour punir.
 *
 * Fonction pure sur `(coup, plateau après ce coup)` : aucune requête moteur,
 * aucune dépendance à l'interface, donc entièrement testable.
 */
object TacticalMotifDetector {

    /**
     * Une cible « de valeur » : cavalier ou plus. Le roi ne vaut rien au
     * matériel mais reste évidemment la cible qui compte le plus.
     */
    fun isValuableTarget(kind: Piece.Kind): Boolean =
        kind == Piece.Kind.king || pieceValue(kind) >= 3

    /**
     * Ordre de mention dans une phrase : le roi d'abord, puis par valeur
     * décroissante. « Fourchette sur le roi et la tour » se lit mieux que
     * l'inverse, et c'est aussi l'ordre de la menace.
     */
    private fun threatRank(kind: Piece.Kind): Int =
        if (kind == Piece.Kind.king) 100 else pieceValue(kind)

    /**
     * Le motif du coup [move], joué sur la position que [board] représente
     * MAINTENANT (donc après le coup).
     *
     * L'ordre des tests est l'ordre de ce qui apprend le plus : un mat prime
     * tout, une fourchette explique mieux qu'une simple perte matérielle, et
     * « la pièce était en prise » ne sert que quand rien de plus fin ne
     * s'applique. `null` est fréquent et parfaitement normal.
     */
    fun detect(move: Move, boardAfter: Board): TacticalMotif? {
        val victim = move.piece.color.opposite
        val state = boardAfter.state
        if (state is Board.State.Checkmate && state.color == victim) {
            return TacticalMotif.Checkmate(1, isBackRankMate(victim, boardAfter))
        }
        detectFork(move, boardAfter)?.let { return it }
        detectDiscoveredCheck(move, boardAfter)?.let { return it }
        detectPin(move, boardAfter)?.let { return it }
        return detectHangingCapture(move, boardAfter)
    }

    /**
     * Mat du couloir : le roi maté est sur SA rangée de fond et les trois cases
     * devant lui (diagonales comprises) sont bouchées par ses propres pièces.
     * C'est la définition littérale du motif — un roi qui étouffe derrière ses
     * propres pions —, pas « le roi est sur la 1re rangée », qui étiquetterait
     * n'importe quel mat de finale.
     */
    fun isBackRankMate(color: Piece.Color, board: Board): Boolean {
        val king = board.position.pieces
            .firstOrNull { it.color == color && it.kind == Piece.Kind.king } ?: return false
        val homeRank = if (color == Piece.Color.white) 1 else 8
        if (king.square.rank.value != homeRank) return false

        val escapeRank = if (color == Piece.Color.white) 2 else 7
        val files = (king.square.file.number - 1)..(king.square.file.number + 1)
        return files.filter { it in 1..8 }.all { file ->
            board.position.piece(square(file, escapeRank))?.color == color
        }
    }

    /**
     * La pièce qui vient d'arriver attaque au moins deux cibles de valeur.
     *
     * `legalMoves(forPieceAt:)` ignore le trait et inclut les cases occupées
     * par l'adversaire, roi compris — c'est exactement ce qu'il faut, et c'est
     * ce qui donne la fourchette royale sans traitement à part.
     */
    private fun detectFork(move: Move, board: Board): TacticalMotif? {
        val victim = move.piece.color.opposite
        val targets = board.legalMoves(move.end)
            .mapNotNull { board.position.piece(it) }
            .filter { it.color == victim && isValuableTarget(it.kind) }
        if (targets.size < 2) return null
        return TacticalMotif.Fork(
            by = arrivingKind(move, board),
            on = move.end,
            targets = targets.map { it.kind }.sortedByDescending { threatRank(it) },
        )
    }

    /** Échec donné par une pièce AUTRE que celle qui vient de bouger. */
    private fun detectDiscoveredCheck(move: Move, board: Board): TacticalMotif? {
        val victim = move.piece.color.opposite
        val state = board.state
        if (state !is Board.State.Check || state.color != victim) return null
        val kingSquare = board.position.pieces
            .firstOrNull { it.color == victim && it.kind == Piece.Kind.king }?.square ?: return null

        // Si la pièce arrivée attaque elle-même le roi, l'échec est direct :
        // rien de « découvert » à raconter.
        if (kingSquare in board.legalMoves(move.end)) return null

        // Nommer la pièce qui donne RÉELLEMENT l'échec — c'est elle, le sujet
        // de la phrase, pas celle qui s'est écartée.
        val checker = board.position.pieces.firstOrNull {
            it.color == move.piece.color && it.square != move.end &&
                kingSquare in board.legalMoves(it.square)
        }
        return TacticalMotif.DiscoveredCheck(checker?.kind ?: arrivingKind(move, board))
    }

    /**
     * Clouage créé par la pièce qui vient d'arriver : en partant d'elle, la
     * première pièce rencontrée sur un rayon est adverse, et derrière elle se
     * trouve une pièce du même camp plus chère (ou le roi).
     */
    private fun detectPin(move: Move, board: Board): TacticalMotif? {
        val directions = when (arrivingKind(move, board)) {
            Piece.Kind.rook -> ORTHOGONAL
            Piece.Kind.bishop -> DIAGONAL
            Piece.Kind.queen -> ORTHOGONAL + DIAGONAL
            // Seule une pièce à longue portée peut clouer.
            else -> return null
        }
        val victim = move.piece.color.opposite
        for ((df, dr) in directions) {
            var file = move.end.file.number + df
            var rank = move.end.rank.value + dr
            var pinned: Piece? = null
            while (file in 1..8 && rank in 1..8) {
                val piece = board.position.piece(square(file, rank))
                if (piece != null) {
                    val front = pinned
                    if (front == null) {
                        // Première pièce du rayon. Un roi n'est pas cloué, il
                        // est en échec — et une pièce à nous bloque le rayon.
                        if (piece.color != victim || piece.kind == Piece.Kind.king) break
                        pinned = piece
                    } else {
                        // Deuxième pièce : le clouage n'existe que si elle est
                        // du même camp que la première et vaut plus cher.
                        if (piece.color != victim) break
                        if (piece.kind != Piece.Kind.king &&
                            pieceValue(piece.kind) <= pieceValue(front.kind)
                        ) break
                        return TacticalMotif.Pin(front.kind, piece.kind)
                    }
                }
                file += df
                rank += dr
            }
        }
        return null
    }

    /**
     * Le coup prend une pièce de valeur que rien ne peut reprendre : elle était
     * vraiment en prise, ce n'était pas un échange.
     */
    private fun detectHangingCapture(move: Move, board: Board): TacticalMotif? {
        val captured = (move.result as? Move.Result.Capture)?.piece ?: return null
        if (!isValuableTarget(captured.kind)) return null
        val victim = move.piece.color.opposite
        val canRecapture = board.position.pieces
            .filter { it.color == victim }
            .any { board.canMove(it.square, move.end) }
        return if (canRecapture) null else TacticalMotif.HangingPiece(captured.kind, move.end)
    }

    /**
     * Le type de la pièce qui se trouve à l'arrivée — et non `move.piece`, qui
     * vaut « pion » après une promotion. Une dame fraîchement promue qui cloue
     * doit être nommée dame.
     */
    private fun arrivingKind(move: Move, board: Board): Piece.Kind =
        board.position.piece(move.end)?.kind ?: move.piece.kind

    private val ORTHOGONAL = listOf(1 to 0, -1 to 0, 0 to 1, 0 to -1)
    private val DIAGONAL = listOf(1 to 1, 1 to -1, -1 to 1, -1 to -1)

    private fun square(file: Int, rank: Int): Square =
        Square(Square.File(file), Square.Rank(rank))
}
