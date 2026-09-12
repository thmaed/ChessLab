package com.chesslab.analysis

import chesskit.Board
import chesskit.Move
import chesskit.Piece
import com.chesslab.play.CapturedMaterial
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Conversion éval (centipions ou mat) → probabilité de gain, POV Blancs.
 * Pendant de `MoveClassification.swift`.
 *
 * Sigmoïde type Lichess : à +8 perdre 300 cp ne change presque rien, à 0.00
 * c'est décisif — la classification se fait sur cette échelle, pas sur les
 * centipions bruts.
 */
object EvalConversion {
    fun fromCentipawns(cp: Int): Double = 50 + 50 * (2 / (1 + exp(-0.00368 * cp)) - 1)

    /**
     * Un mat forcé compte comme un avantage extrême (100/0), pas une simple
     * grande valeur de cp — sinon un mat en 1 et un mat en 20 auraient un
     * score arbitrairement différent selon la profondeur atteinte.
     */
    fun fromMate(mate: Int): Double = if (mate > 0) 100.0 else 0.0
}

/** La valeur d'une pièce, en points. */
fun pieceValue(kind: Piece.Kind): Int = CapturedMaterial.value(kind)

/**
 * Classe chaque coup joué. Toutes les probabilités sont DU POINT DE VUE DU
 * JOUEUR QUI VIENT DE JOUER. Fonction pure : tout ce qui demande le moteur ou
 * le plateau est calculé par l'appelant et passé dans [Input].
 */
object MoveClassifier {

    /**
     * Seuils de PERTE de probabilité de gain (points de %). Le barème vient
     * d'iOS : Excellent < 2 %, Bon coup 2-5 %, Imprécision 5-10 %, Erreur
     * 10-20 %, Gaffe ≥ 20 %.
     */
    const val INACCURACY_THRESHOLD = 5.0
    const val MISTAKE_THRESHOLD = 10.0
    const val BLUNDER_THRESHOLD = 20.0

    /** En dessous de cette perte, le coup vaut celui du moteur. */
    const val EXCELLENT_THRESHOLD = 2.0

    /**
     * Écart minimal (points de %) avec le 2e choix du moteur pour qu'un coup
     * soit « le seul bon coup » — condition du Grand coup et du Brillant.
     */
    const val ONLY_MOVE_GAP_THRESHOLD = 15.0

    /**
     * Au-delà, la position était déjà gagnée : trouver le seul coup qui garde
     * +9 plutôt que +5 n'est pas un exploit, et une victoire dilapidée mais
     * pas perdue est une occasion MANQUÉE, pas une gaffe.
     */
    const val CLEARLY_WINNING_THRESHOLD = 85.0

    /**
     * EXCEPTION au seuil ci-dessus pour le Grand coup : même dans une position
     * déjà gagnée, le coup le mérite si le 2e choix s'effondre de plus de ça —
     * c'est qu'il y avait un piège, un seul coup gardait vraiment le gain.
     */
    const val SECOND_BEST_COLLAPSE_THRESHOLD = 30.0

    /**
     * Tout ce que la classification d'un coup doit savoir. Les champs nuls sont
     * ceux que le moteur ne fournit pas toujours : [gapToSecondBest] est nul
     * quand il n'existe pas de 2e choix.
     */
    data class Input(
        val winPercentBefore: Double,
        val winPercentAfter: Double,
        /** Le coup joué est-il le premier choix du moteur à la position parente ? */
        val isBestMove: Boolean = false,
        /**
         * Écart (points de %) entre le 1er et le 2e choix du moteur à la
         * position parente, POV du joueur au trait.
         */
        val gapToSecondBest: Double? = null,
        /** La ligne jouée jusqu'ici est-elle encore dans la théorie (ECO) ? */
        val isBook: Boolean = false,
        /** Le coup abandonne-t-il du matériel de façon reprenable ? */
        val isSacrifice: Boolean = false,
        /**
         * La pièce sacrifiée est-elle IMMÉDIATEMENT reprise sur sa case
         * d'arrivée au coup suivant ? Une reprise triviale trahit une simple
         * simplification, pas un exploit.
         */
        val sacrificeImmediatelyRecaptured: Boolean = false,
        /**
         * Le MEILLEUR coup (celui qu'on a raté) était-il une tactique nette —
         * mat direct ou gain de matériel ? Rater un plan positionnel dans une
         * position gagnée n'est pas une occasion manquée ; rater un mat, si.
         */
        val bestMoveWasTactical: Boolean = false,
        /** Seul coup légal : ni mérite, ni faute. */
        val isForced: Boolean = false,
    )

    fun classify(input: Input): MoveQuality {
        // La théorie d'abord : tant qu'on récite, l'éval ne juge personne.
        if (input.isBook) return MoveQuality.book
        // Un coup unique est trivialement le meilleur — et ne sera jamais
        // « brillant » : on ne sacrifie pas ce qu'on est forcé de donner.
        if (input.isForced) return MoveQuality.best

        val loss = input.winPercentBefore - input.winPercentAfter

        if (loss >= INACCURACY_THRESHOLD) {
            // Occasion manquée : position déjà gagnée dilapidée SANS être
            // perdue, ET la perte vient d'avoir raté une TACTIQUE nette.
            if (input.winPercentBefore >= CLEARLY_WINNING_THRESHOLD &&
                input.winPercentAfter >= 50 &&
                input.bestMoveWasTactical
            ) return MoveQuality.miss

            return when {
                loss >= BLUNDER_THRESHOLD -> MoveQuality.blunder
                loss >= MISTAKE_THRESHOLD -> MoveQuality.mistake
                else -> MoveQuality.inaccuracy
            }
        }

        if (input.isBestMove) {
            val gap = input.gapToSecondBest ?: 0.0
            // « Le seul bon coup » : écart ≥ 15 % avec le 2e choix, ET soit la
            // position n'était pas encore gagnée, SOIT — même gagnée — le 2e
            // choix s'effondre, signe qu'un seul coup gardait le gain.
            val isOnlyGoodMove = gap >= ONLY_MOVE_GAP_THRESHOLD &&
                (input.winPercentBefore < CLEARLY_WINNING_THRESHOLD ||
                    gap >= SECOND_BEST_COLLAPSE_THRESHOLD)

            // Brillant : le seul bon coup, ET un sacrifice RÉEL (pas repris
            // trivialement au coup suivant), ET la position reste au moins
            // égale — le sacrifice spéculatif perdant n'est pas salué.
            if (isOnlyGoodMove && input.isSacrifice &&
                !input.sacrificeImmediatelyRecaptured && input.winPercentAfter >= 50
            ) return MoveQuality.brilliant

            if (isOnlyGoodMove) return MoveQuality.great
            return MoveQuality.best
        }

        return if (loss < EXCELLENT_THRESHOLD) MoveQuality.excellent else MoveQuality.good
    }

    /**
     * Vrai si la pièce arrivée en `move.end` est REPRISE sur cette même case
     * par le coup suivant réellement joué. On ne juge pas la valeur du
     * reprenant : la simple reprise immédiate suffit à disqualifier le
     * « brillant ».
     */
    fun isImmediatelyRecaptured(move: Move, next: Move?): Boolean =
        next != null && next.end == move.end && next.result is Move.Result.Capture

    /**
     * Un coup « sacrifie » s'il abandonne une valeur nette significative
     * (≥ 2 points) à une pièce adverse qui peut reprendre sur la case
     * d'arrivée à moindre coût — approximation volontaire, sans recherche.
     */
    fun involvesSacrifice(move: Move, boardAfterMove: Board): Boolean {
        // Une promotion change la pièce arrivée sur la case : `move.piece`
        // reste le PION qui a bougé, donc une dame qui se sacrifie juste après
        // sa promotion ne compterait que pour un pion.
        val moverValue = pieceValue(move.promotedPiece?.kind ?: move.piece.kind)
        val gained = (move.result as? Move.Result.Capture)?.let { pieceValue(it.piece.kind) } ?: 0
        if (moverValue - gained < 2) return false

        val cheapest = boardAfterMove.position.pieces
            .filter { it.color == move.piece.color.opposite }
            .filter { boardAfterMove.canMove(it.square, move.end) }
            .minOfOrNull { pieceValue(it.kind) } ?: return false
        return cheapest <= moverValue
    }
}

/**
 * Précision (%) d'un joueur sur une partie. Pendant de `AccuracyScore`.
 *
 * La courbe est celle popularisée par Lichess, appliquée à une MOYENNE des
 * pertes — pas aux pertes coup par coup (la courbe étant convexe, agréger
 * dans l'autre sens est plus généreux, et c'est justement ce qu'on cherchait
 * à corriger).
 *
 * Ce qui change, côté iOS comme ici, c'est la moyenne : elle est pondérée par
 * la VOLATILITÉ de la position — l'écart-type des probabilités de gain sur une
 * fenêtre glissante. Un coup joué dans une position qui bouge encore compte
 * pleinement ; un coup joué dans une position morte ne compte presque pas.
 * Sans quoi vingt coups de finition dans une partie déjà gagnée gonflaient le
 * score de plusieurs points sans que rien n'ait été mieux joué.
 */
object AccuracyScore {

    /** La courbe, appliquée à une perte moyenne. */
    fun accuracy(averageWinPercentLoss: Double): Double {
        if (averageWinPercentLoss <= 0) return 100.0
        val raw = 103.1668 * exp(-0.04354 * averageWinPercentLoss) - 3.1669
        return min(100.0, max(0.0, raw))
    }

    /**
     * Au-delà de cet écart au nul, la partie est tenue pour JOUÉE : à 90/10,
     * plus aucun coup raisonnable ne peut faire bouger grand-chose.
     */
    const val DECIDED_MARGIN = 40.0

    /**
     * Ce que pèse un coup joué dans une position déjà pliée. Pas zéro : il
     * faut encore ne pas tout gâcher, et un coup qui perdrait vraiment la
     * partie gagnée aurait une perte énorme, donc compterait malgré ce
     * coefficient.
     */
    const val DECIDED_STAKE = 0.05

    /**
     * Poids d'un coup : CE QUI BOUGEAIT × CE QUI ÉTAIT EN JEU.
     *
     * @param whiteWinPercents probabilités de gain POV BLANCS le long de la
     *   partie, position de départ COMPRISE — il en faut une de plus que de
     *   coups.
     */
    fun moveWeights(whiteWinPercents: List<Double>): List<Double> {
        val moveCount = max(whiteWinPercents.size - 1, 0)
        if (moveCount == 0) return emptyList()
        // Fenêtre proportionnelle à la longueur de la partie, bornée : trop
        // courte elle ne mesure rien, trop longue elle lisse justement ce
        // qu'on cherche à voir.
        val window = max(2, min(8, moveCount / 10))
        return (0 until moveCount).map { i ->
            val end = i + 1
            val start = max(0, end - window + 1)
            val deviation = standardDeviation(whiteWinPercents.subList(start, end + 1))
            // Plage resserrée à [1 ; 3] : avec la plage large, les six mauvais
            // coups d'une partie de club captaient les trois quarts du poids.
            val volatility = min(3.0, max(1.0, deviation / 4))
            // Pliée AVANT **et** APRÈS : un coup qui fait basculer la partie
            // d'équilibrée à gagnée engageait tout, et doit compter plein.
            val decidedness = min(
                abs(whiteWinPercents[end - 1] - 50), abs(whiteWinPercents[end] - 50)
            )
            volatility * (if (decidedness >= DECIDED_MARGIN) DECIDED_STAKE else 1.0)
        }
    }

    /**
     * Précision d'un joueur sur une partie.
     *
     * @param winPercentLosses pertes de probabilité de gain des coups DE CE
     *   JOUEUR, dans l'ordre.
     * @param weights leurs poids de volatilité, même ordre.
     */
    fun accuracy(winPercentLosses: List<Double>, weights: List<Double>): Double? {
        if (winPercentLosses.isEmpty() || weights.size != winPercentLosses.size) return null
        val weightSum = weights.sum()
        if (weightSum <= 0) return accuracy(winPercentLosses.average())
        val weighted = winPercentLosses.zip(weights).sumOf { it.first * it.second } / weightSum
        return accuracy(weighted)
    }

    private fun standardDeviation(values: List<Double>): Double {
        if (values.size < 2) return 0.0
        val mean = values.average()
        return sqrt(values.sumOf { (it - mean) * (it - mean) } / values.size)
    }
}
