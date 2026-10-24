package com.chesslab.play

import chesskit.Piece

/**
 * La navigation en consultation contre l'ordinateur : par coup COMPLET, et non
 * par demi-coup. Les flèches s'arrêtent toujours sur une position où c'est AU
 * JOUEUR de jouer, si bien que « Reprendre ici » y reprend sa partie — et non
 * celle du moteur (demande du 23/10/2026, étendue aux variantes le 24/10).
 * Pendant de `ReviewStepper.swift`, mêmes trois façons de dire quelles
 * positions sont celles du joueur :
 *
 * - la PARITÉ, quand les coups alternent toujours (jeu classique) ;
 * - le camp au trait inscrit dans la FEN de chaque position (variantes) ;
 * - la couleur de qui JOUE chaque coup, quand ils n'alternent pas toujours :
 *   au milieu d'un tour double du Coup Volé, la FEN donne le trait à
 *   l'adversaire alors que le même camp rejoue.
 */
class ReviewStepper(
    val totalPlies: Int,
    private val userPly: (Int) -> Boolean,
) {
    /** [userMovesOnEvenPlies] : vrai si c'est au joueur de jouer après un nombre PAIR de demi-coups. */
    constructor(totalPlies: Int, userMovesOnEvenPlies: Boolean) :
        this(totalPlies, { ply: Int -> (ply % 2 == 0) == userMovesOnEvenPlies })

    fun isUserPly(ply: Int): Boolean = userPly(ply)

    /** La position du joueur juste avant [from], `null` s'il n'y en a pas. */
    fun previous(from: Int): Int? =
        if (from <= 0) null else (from - 1 downTo 0).firstOrNull(userPly)

    /**
     * La position du joueur juste après [from] — la position vive
     * ([totalPlies]) s'il n'y en a plus, `null` si l'on y est déjà.
     */
    fun next(from: Int): Int? =
        if (from >= totalPlies) null else (from + 1..totalPlies).firstOrNull(userPly) ?: totalPlies

    companion object {
        /** Par le journal des positions : une position du joueur est une position où il a le trait. */
        fun fromFens(totalPlies: Int, fens: List<String>, user: Piece.Color) =
            ReviewStepper(totalPlies) { ply -> ply < fens.size && sideToMove(fens[ply]) == user }

        /** Par la couleur de qui a joué chaque coup : la position avant le coup `p` est au joueur s'il l'a joué. */
        fun fromMovers(movers: List<Piece.Color>, user: Piece.Color) =
            ReviewStepper(movers.size) { ply -> ply < movers.size && movers[ply] == user }

        /** Chaque demi-coup est une étape — à deux joueurs, il n'y a pas « un » joueur. */
        fun everyPly(totalPlies: Int) = ReviewStepper(totalPlies) { true }

        /** Le camp au trait d'une FEN (2e champ), y compris d'une FEN de variante. */
        fun sideToMove(fen: String): Piece.Color? = when (fen.trim().split(" ").getOrNull(1)) {
            "w" -> Piece.Color.white
            "b" -> Piece.Color.black
            else -> null
        }
    }
}
