package com.chesslab.maia

import android.content.Context
import chesskit.Board
import chesskit.Position
import kotlin.random.Random

/**
 * Traduction Kotlin de `MaiaOpponent.swift`.
 *
 * L'adversaire humain : Maia-3 interrogé sur la position courante et son
 * historique, puis un tirage à la température du personnage.
 *
 * Ne connaît ni le filet ni le tempérament : il rend un coup et la
 * distribution dont il sort ; l'appelant décide du reste.
 */
class MaiaOpponent private constructor(private val model: MaiaModel) {

    data class Choice(
        /** Le coup tiré, en UCI côté plateau réel. */
        val uci: String,
        /** Toute la distribution sur les coups légaux, triée. */
        val candidates: List<MaiaCandidate>,
        val win: Double,
        val draw: Double,
        val loss: Double,
    )

    /**
     * [history] va de la plus ancienne position à la courante.
     * `null` si aucun coup n'est légal.
     */
    fun chooseMove(
        history: List<Position>,
        board: Board,
        selfElo: Double,
        oppoElo: Double,
        temperature: Double,
        topP: Double,
        style: StyleProfile = StyleProfile.none,
        random: Random = Random.Default,
    ): Choice? {
        val legal = MaiaLegalMoves.moves(board)
        if (legal.isEmpty()) return null

        // Le réseau peut refuser : sa session est rendue au système quand
        // l'app passe en arrière-plan (voir [MaiaModel.release]), et rien ne
        // garantit qu'elle rouvre — mémoire encore trop juste, fichier illisible.
        // Dans ce cas on rend `null` et l'appelant retombe sur Stockfish, ce
        // qu'il sait déjà faire ; une exception, elle, emporterait la partie.
        val prediction = runCatching {
            model.predict(MaiaEncoder.tokens(history), selfElo, oppoElo)
        }.getOrNull() ?: return null

        // Le style repondère la distribution HUMAINE de Maia — borné, donc il
        // la colore sans la remplacer — puis le tirage se fait dans le résultat.
        val candidates = OpponentStyle.apply(
            style,
            MaiaPolicy.candidates(prediction.moveLogits, legal),
            board,
        )
        val pick = MaiaPolicy.sample(candidates, temperature, topP, random) ?: return null
        return Choice(pick.move.uci, candidates, prediction.win, prediction.draw, prediction.loss)
    }

    companion object {
        /** `null` si le modèle est absent — l'app retombe alors sur Stockfish. */
        fun shared(context: Context, threads: Int): MaiaOpponent? =
            MaiaModel.shared(context, threads)?.let { MaiaOpponent(it) }
    }
}
