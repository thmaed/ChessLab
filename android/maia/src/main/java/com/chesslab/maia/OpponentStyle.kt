package com.chesslab.maia

import chesskit.Board
import chesskit.Move
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min

/**
 * Traduction Kotlin de `OpponentStyle.swift`.
 *
 * Un trait de coup, lu en REJOUANT le coup sur un plateau : ce qu'un
 * personnage aime ou évite. Chaque trait vaut entre −1 et 1.
 */
@Suppress("EnumEntryName")
enum class StyleTrait {
    check, capture, materialGain, sacrifice, towardKing, pawnStorm,
    castle, development, weakPawn, equalTrade, queenTrade, tension, mobility,
}

/**
 * Le style d'un personnage : un poids par trait, et une borne.
 *
 * Le score d'un coup est la somme pondérée de ses traits, BORNÉE à
 * ±[strength] (en nats) : la probabilité de Maia est multipliée par e^score.
 * Avec `strength` = 1, un coup adoré pèse au plus 2,7 fois plus — le style
 * COLORE la distribution humaine, il ne la remplace pas, et il n'achète
 * jamais une gaffe que Maia jugeait improbable.
 */
data class StyleProfile(val weights: Map<StyleTrait, Double>, val strength: Double) {
    val isNeutral: Boolean get() = strength <= 0 || weights.isEmpty()

    /** Le même style, avec des poids ajoutés — le style dynamique selon le score. */
    fun adding(extra: Map<StyleTrait, Double>): StyleProfile {
        if (extra.isEmpty()) return this
        val merged = weights.toMutableMap()
        for ((trait, weight) in extra) merged[trait] = (merged[trait] ?: 0.0) + weight
        return StyleProfile(merged, max(strength, 0.6))
    }

    companion object { val none = StyleProfile(emptyMap(), 0.0) }
}

/** Les traits d'UN coup, mesurés. */
data class MoveTraits(
    var check: Boolean = false,
    var capture: Boolean = false,
    var capturedValue: Int = 0,
    var movedValue: Int = 0,
    var sacrifice: Boolean = false,
    var towardKing: Boolean = false,
    var pawnStorm: Boolean = false,
    var castle: Boolean = false,
    var development: Boolean = false,
    var weakPawnDelta: Int = 0,
    var equalTrade: Boolean = false,
    var queenTrade: Boolean = false,
    var tensionDelta: Int = 0,
    var mobilityDelta: Int = 0,
) {
    fun value(trait: StyleTrait): Double = when (trait) {
        StyleTrait.check -> if (check) 1.0 else 0.0
        StyleTrait.capture -> if (capture) 1.0 else 0.0
        StyleTrait.materialGain -> clamp((capturedValue - (if (sacrifice) movedValue else 0)) / 5.0)
        StyleTrait.sacrifice -> if (sacrifice) 1.0 else 0.0
        StyleTrait.towardKing -> if (towardKing) 1.0 else 0.0
        StyleTrait.pawnStorm -> if (pawnStorm) 1.0 else 0.0
        StyleTrait.castle -> if (castle) 1.0 else 0.0
        StyleTrait.development -> if (development) 1.0 else 0.0
        StyleTrait.weakPawn -> clamp(weakPawnDelta / 2.0)
        StyleTrait.equalTrade -> if (equalTrade) 1.0 else 0.0
        StyleTrait.queenTrade -> if (queenTrade) 1.0 else 0.0
        StyleTrait.tension -> clamp(tensionDelta / 3.0)
        StyleTrait.mobility -> clamp(mobilityDelta / 6.0)
    }

    private fun clamp(x: Double) = min(1.0, max(-1.0, x))
}

/** Extraction des traits et repondération de la distribution de Maia. */
object OpponentStyle {

    fun value(kind: Piece.Kind): Int = when (kind) {
        Piece.Kind.pawn -> 1
        Piece.Kind.knight, Piece.Kind.bishop -> 3
        Piece.Kind.rook -> 5
        Piece.Kind.queen -> 9
        Piece.Kind.king -> 0
    }

    /**
     * Les traits du coup [lan] pour le camp au trait, ou `null` si le coup
     * n'est pas applicable.
     *
     * L'original profite de la sémantique de valeur de Swift (`var scratch =
     * board`) ; ici le plateau d'essai est construit sur une COPIE explicite
     * de la position.
     */
    fun traits(lan: String, board: Board): MoveTraits? {
        if (lan.length < 4) return null
        val mover = board.position.sideToMove
        val from = Square(lan.substring(0, 2))
        val to = Square(lan.substring(2, 4))
        val piece = board.position.piece(from) ?: return null
        if (piece.color != mover) return null

        val scratch = Board(board.position.copy())
        var made: Move = scratch.move(pieceAt = from, to = to) ?: return null
        var promotedKind: Piece.Kind? = null
        if (scratch.state is Board.State.Promotion) {
            val kind = if (lan.length == 5) kindOf(lan[4]) else Piece.Kind.queen
            made = scratch.completePromotion(of = made, to = kind)
            promotedKind = kind
        }

        val traits = MoveTraits()
        traits.movedValue = value(promotedKind ?: piece.kind)
        (made.result as? Move.Result.Capture)?.let { captured ->
            traits.capture = true
            traits.capturedValue = value(captured.piece.kind)
            traits.queenTrade = captured.piece.kind == Piece.Kind.queen && piece.kind == Piece.Kind.queen
        }
        traits.check = scratch.state is Board.State.Check || scratch.state is Board.State.Checkmate
        traits.castle = piece.kind == Piece.Kind.king && abs(from.file.number - to.file.number) == 2

        val homeRank = if (mover == Piece.Color.white) 1 else 8
        traits.development = (piece.kind == Piece.Kind.knight || piece.kind == Piece.Kind.bishop) &&
            from.rank.value == homeRank && to.rank.value != homeRank

        val enemy = mover.opposite
        board.position.pieces.firstOrNull { it.kind == Piece.Kind.king && it.color == enemy }?.let { king ->
            if (piece.kind != Piece.Kind.pawn && piece.kind != Piece.Kind.king) {
                val before = distance(from, king.square)
                val after = distance(to, king.square)
                traits.towardKing = after < before && after <= 3
            }
            if (piece.kind == Piece.Kind.pawn) {
                val kingFile = king.square.file.number
                val kingWing = if (kingFile <= 3) 0 else if (kingFile >= 6) 1 else null
                val pawnWing = if (to.file.number <= 3) 0 else if (to.file.number >= 6) 1 else null
                val relativeRank = if (mover == Piece.Color.white) to.rank.value else 9 - to.rank.value
                traits.pawnStorm = kingWing != null && kingWing == pawnWing && relativeRank >= 4
            }
        }

        // les attaquants adverses de la case d'arrivée, APRÈS le coup :
        // `legalMoves` ignore le trait, on peut donc interroger l'adversaire
        var lowestAttacker: Int? = null
        for (enemyPiece in scratch.position.pieces) {
            if (enemyPiece.color != enemy) continue
            if (to in scratch.legalMoves(forPieceAt = enemyPiece.square)) {
                val attackerValue = value(enemyPiece.kind)
                lowestAttacker = min(lowestAttacker ?: Int.MAX_VALUE, attackerValue)
            }
        }
        lowestAttacker?.let { lowest ->
            val netCapture = traits.capture && traits.capturedValue >= traits.movedValue
            traits.sacrifice = lowest + 1 < traits.movedValue && !netCapture
            traits.equalTrade = traits.capture && traits.capturedValue == traits.movedValue && traits.movedValue >= 3
        }

        traits.weakPawnDelta = weakPawns(scratch.position, mover) - weakPawns(board.position, mover)
        traits.tensionDelta = captures(enemy, scratch) - captures(enemy, board)
        traits.mobilityDelta = scratch.legalMoves(forPieceAt = to).size - board.legalMoves(forPieceAt = from).size
        return traits
    }

    /** Le score de style d'un coup, borné à ±`strength`. */
    fun score(traits: MoveTraits, style: StyleProfile): Double {
        if (style.isNeutral) return 0.0
        val raw = style.weights.entries.sumOf { it.value * traits.value(it.key) }
        return min(style.strength, max(-style.strength, raw))
    }

    /**
     * Repondère les [topK] premiers candidats de Maia par leur score de style,
     * puis renormalise.
     *
     * Seulement les premiers : calculer les traits coûte un plateau d'essai
     * par coup, et la queue de la distribution ne pèse rien.
     */
    fun apply(style: StyleProfile, candidates: List<MaiaCandidate>, board: Board, topK: Int = 8): List<MaiaCandidate> {
        if (style.isNeutral || candidates.isEmpty()) return candidates
        val weighted = candidates.toMutableList()
        for (index in 0 until min(topK, candidates.size)) {
            val traits = traits(candidates[index].move.uci, board) ?: continue
            val factor = exp(score(traits, style))
            weighted[index] = candidates[index].copy(probability = candidates[index].probability * factor)
        }
        val total = weighted.sumOf { it.probability }
        if (total <= 0) return candidates
        return weighted.map { it.copy(probability = it.probability / total) }
            .sortedByDescending { it.probability }
    }

    fun distance(a: Square, b: Square): Int =
        max(abs(a.file.number - b.file.number), abs(a.rank.value - b.rank.value))

    /** Pions isolés + pions doublés d'un camp. */
    fun weakPawns(position: Position, color: Piece.Color): Int {
        val perFile = IntArray(10)      // 1..8 utilisés, marges à 0 et 9
        for (pawn in position.pieces) {
            if (pawn.color == color && pawn.kind == Piece.Kind.pawn) perFile[pawn.square.file.number]++
        }
        var weak = 0
        for (file in 1..8) {
            if (perFile[file] == 0) continue
            if (perFile[file - 1] == 0 && perFile[file + 1] == 0) weak += perFile[file]
            if (perFile[file] > 1) weak += perFile[file] - 1
        }
        return weak
    }

    /** Les captures disponibles pour `color` — le trait est ignoré. */
    fun captures(color: Piece.Color, board: Board): Int {
        var count = 0
        for (piece in board.position.pieces) {
            if (piece.color != color) continue
            for (target in board.legalMoves(forPieceAt = piece.square)) {
                val victim = board.position.piece(target)
                if (victim != null && victim.color != color) count++
            }
        }
        return count
    }

    private fun kindOf(c: Char): Piece.Kind = when (c.lowercaseChar()) {
        'r' -> Piece.Kind.rook
        'b' -> Piece.Kind.bishop
        'n' -> Piece.Kind.knight
        else -> Piece.Kind.queen
    }
}
