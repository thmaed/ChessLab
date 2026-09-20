package com.chesslab.variants

import chesskit.Piece
import chesskit.Position
import chesskit.Square
import kotlin.math.abs

/**
 * La notation algébrique d'un coup de variante, construite à la main. Pendant
 * d'`EngineLegalitySAN.swift`.
 *
 * Il faut la construire parce que personne ne la donne : `chesskit` ne sert
 * ici qu'à LIRE une position que le moteur a rendue — il ne joue aucun de ces
 * coups, et ne peut donc pas en fournir le SAN —, et Fairy-Stockfish ne parle
 * qu'UCI (`d` et `go perft` rendent des `e2e4`, jamais des `Nf3`).
 *
 * Sans elle, la revue d'une partie de variante affichait « b5b6 a7b6 f5f6 » :
 * une suite exacte, et illisible. iOS écrit « b6 axb6 f6 » depuis l'origine.
 */
object VariantSan {

    /**
     * @param uci le coup joué, en UCI/LAN (`e2e4`, `e7e8q`, `P@e4`).
     * @param beforeFen la position AVANT le coup, telle que le moteur l'écrit.
     * @param legalMovesBefore les coups légaux de cette position, même format —
     *   ils servent à DÉSAMBIGUÏSER quand deux pièces identiques peuvent
     *   atteindre la même case.
     * @param isCheck le coup met-il l'adversaire en échec.
     * @param isMate le coup est-il mat.
     */
    fun build(
        uci: String,
        beforeFen: String,
        legalMovesBefore: List<String>,
        isCheck: Boolean,
        isMate: Boolean,
    ): String {
        // Une POSE (Crazyhouse) s'écrit DÉJÀ en SAN : `P@e4` est la notation
        // standard. Traitée en premier, car tout ce qui suit suppose une case
        // de départ, qu'une pose n'a pas.
        val at = uci.indexOf('@')
        if (at > 0) {
            return uci.take(at).uppercase() + "@" + uci.substring(at + 1) + suffix(isCheck, isMate)
        }
        if (uci.length < 4) return uci
        val position = Position.fromFen(VariantFen.forChessKit(beforeFen)) ?: return uci
        val from = Square(uci.take(2))
        val to = Square(uci.drop(2).take(2))
        val piece = position.piece(from) ?: return uci
        val promotion = if (uci.length == 5) uci.takeLast(1).uppercase() else null

        // Le roque se reconnaît au ROI qui saute deux colonnes. Chess960 mis à
        // part : là le roi peut bouger d'une seule case, et le moteur écrit
        // alors le roque « roi prend sa tour ». Ce cas-là tombe dans la règle
        // générale et s'écrit comme un coup de roi, ce qu'iOS fait aussi.
        if (piece.kind == Piece.Kind.king && abs(to.file.number - from.file.number) == 2) {
            val base = if (to.file.number > from.file.number) "O-O" else "O-O-O"
            return base + suffix(isCheck, isMate)
        }

        val occupied = position.piece(to) != null
        val enPassant = piece.kind == Piece.Kind.pawn && from.file != to.file && !occupied
        val capture = occupied || enPassant

        val body = StringBuilder()
        if (piece.kind == Piece.Kind.pawn) {
            if (capture) body.append(from.file.letter).append("x")
            body.append(to.notation)
            if (promotion != null) body.append("=").append(promotion)
        } else {
            body.append(piece.kind.notation)
            body.append(disambiguation(piece, from, to, legalMovesBefore, position))
            if (capture) body.append("x")
            body.append(to.notation)
        }
        return body.toString() + suffix(isCheck, isMate)
    }

    private fun suffix(isCheck: Boolean, isMate: Boolean) =
        if (isMate) "#" else if (isCheck) "+" else ""

    /**
     * Les cases d'ORIGINE des autres coups légaux de la MÊME pièce vers la
     * MÊME case : colonne d'abord, rangée si la colonne ne suffit pas, les
     * deux en dernier recours — la règle SAN habituelle.
     */
    private fun disambiguation(
        piece: Piece,
        from: Square,
        to: Square,
        legalMoves: List<String>,
        position: Position,
    ): String {
        val others = legalMoves.mapNotNull { move ->
            if (move.length < 4 || move.contains('@')) return@mapNotNull null
            val candidate = Square(move.take(2))
            if (candidate == from) return@mapNotNull null
            if (Square(move.drop(2).take(2)) != to) return@mapNotNull null
            val other = position.piece(candidate) ?: return@mapNotNull null
            if (other.kind != piece.kind || other.color != piece.color) return@mapNotNull null
            candidate
        }
        if (others.isEmpty()) return ""
        if (others.none { it.file == from.file }) return from.file.letter
        if (others.none { it.rank == from.rank }) return from.rank.value.toString()
        return from.notation
    }
}
