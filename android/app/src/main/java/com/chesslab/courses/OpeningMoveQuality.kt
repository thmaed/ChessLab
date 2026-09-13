package com.chesslab.courses

import chesskit.Board
import chesskit.Move
import chesskit.Piece
import chesskit.Square
import com.chesslab.analysis.EvalConversion
import com.chesslab.analysis.MoveClassifier
import com.chesslab.analysis.MoveQuality

/**
 * Juge un coup de l'index sur l'échelle de [MoveQuality], à partir des
 * évaluations PRÉ-CALCULÉES du sidecar. Pendant d'`OpeningMoveQuality.swift`.
 *
 * **Pourquoi rejuger des coups de théorie.** Un cours montre la ligne
 * principale ET ce qu'il ne faut pas jouer : pièges, imprécisions,
 * réfutations. Le rôle dit ce que l'auteur a voulu montrer ; il manquait le
 * verdict OBJECTIF — combien coûte réellement ce coup. Les deux blocs
 * `engine` du sidecar (position avant, position après) le donnent sans qu'un
 * moteur ait à tourner sur l'appareil.
 *
 * **Ce qui est affiché, et rien d'autre.** Cinq catégories : gaffe, erreur,
 * imprécision, occasion manquée, coup brillant. Un index où chaque coup
 * porterait une pastille ne montrerait plus rien : c'est le DÉCROCHAGE qu'on
 * cherche du regard, et l'exploit.
 *
 * **Le piège du « c'est de la théorie ».** Le classifieur rend `book` dès que
 * `isBook` est vrai — et dans un cours d'ouverture, TOUT est de la théorie. On
 * ne le lui dit donc pas : on veut précisément le jugement du moteur sur des
 * coups que le livre mentionne, y compris pour les condamner.
 */
object OpeningMoveQuality {

    /** Les seules catégories que l'index dessine. */
    val displayed: Set<MoveQuality> = setOf(
        MoveQuality.brilliant, MoveQuality.miss, MoveQuality.inaccuracy, MoveQuality.mistake, MoveQuality.blunder,
    )

    /** Tout ce dont le jugement a besoin, résolu par l'appelant. */
    data class Context(
        val fromFEN: String,
        val toFEN: String,
        val uci: String,
        /** Le coup RÉELLEMENT joué ensuite dans cette ligne — pour savoir si un sacrifice est trivialement repris. */
        val nextUCI: String?,
    )

    /** Le verdict affichable, ou `null` : donnée manquante, ou catégorie sans place dans l'index. */
    fun classify(context: Context, sidecar: OpeningStatsSidecar): MoveQuality? {
        val before = sidecar.data(context.fromFEN)?.engine?.takeIf { it.isNotEmpty() } ?: return null
        val after = sidecar.data(context.toFEN)?.engine?.firstOrNull() ?: return null
        val position = CourseRepository.position(context.fromFEN) ?: return null

        val mover = position.sideToMove
        val winBefore = winPercent(before[0], mover)
        val winAfter = winPercent(after, mover)

        var isSacrifice = false
        var recaptured = false
        val board = Board(position)
        val applied = apply(context.uci, board)
        if (applied != null) {
            isSacrifice = MoveClassifier.involvesSacrifice(applied, board)
            val nextUci = context.nextUCI
            if (isSacrifice && nextUci != null) {
                val next = apply(nextUci, Board(board.position))
                recaptured = MoveClassifier.isImmediatelyRecaptured(applied, next)
            }
        }

        val input = MoveClassifier.Input(
            winPercentBefore = winBefore,
            winPercentAfter = winAfter,
            isBestMove = before[0].uci == context.uci,
            gapToSecondBest = before.getOrNull(1)?.let { winBefore - winPercent(it, mover) },
            isSacrifice = isSacrifice,
            sacrificeImmediatelyRecaptured = recaptured,
            // Le meilleur coup était-il une TACTIQUE nette (mat ou prise) ?
            // Rater un plan positionnel n'est pas une occasion manquée, rater
            // un mat ou une pièce en est une. Approximation sur la notation,
            // faute d'une recherche ici.
            bestMoveWasTactical = before[0].mate != null || before[0].san.contains("x"),
        )
        val quality = MoveClassifier.classify(input)
        return quality.takeIf { it in displayed }
    }

    /**
     * La probabilité de gain d'une ligne, DU POINT DE VUE du camp donné. Le
     * sidecar est toujours au point de vue des Blancs ; le classifieur attend
     * celui du joueur qui vient de jouer. C'est ici, et nulle part ailleurs,
     * que le signe s'inverse.
     */
    private fun winPercent(line: OpeningEngineLine, color: Piece.Color): Double {
        val white = line.mate?.let { EvalConversion.fromMate(it) }
            ?: EvalConversion.fromCentipawns(line.cp ?: 0)
        return if (color == Piece.Color.white) white else 100 - white
    }

    /** Joue un coup UCI sur le plateau donné (qui bouge), promotion comprise. */
    internal fun apply(uci: String, board: Board): Move? {
        if (uci.length < 4) return null
        val move = board.move(Square(uci.substring(0, 2)), Square(uci.substring(2, 4))) ?: return null
        if (board.state !is Board.State.Promotion) return move
        val kind = when (uci.getOrNull(4)) {
            'r' -> Piece.Kind.rook
            'b' -> Piece.Kind.bishop
            'n' -> Piece.Kind.knight
            else -> Piece.Kind.queen
        }
        return board.completePromotion(move, kind)
    }
}
