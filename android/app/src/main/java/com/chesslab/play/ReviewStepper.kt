package com.chesslab.play

/**
 * La navigation en consultation contre l'ordinateur : par coup COMPLET, et non
 * par demi-coup. Les flèches s'arrêtent toujours sur une position où c'est AU
 * JOUEUR de jouer, si bien que « Reprendre ici » y reprend sa partie — et non
 * celle du moteur (demande du 23/10/2026). Pendant de `ReviewStepper.swift`.
 *
 * Pur : seuls comptent le nombre de demi-coups et la parité des positions du
 * joueur (une partie commencée depuis une position où les Noirs ont le trait
 * inverse cette parité).
 */
data class ReviewStepper(
    val totalPlies: Int,
    /** Vrai si c'est au joueur de jouer après un nombre PAIR de demi-coups. */
    val userMovesOnEvenPlies: Boolean,
) {
    fun isUserPly(ply: Int): Boolean = (ply % 2 == 0) == userMovesOnEvenPlies

    /** La position du joueur juste avant [ply], `null` s'il n'y en a pas. */
    fun previous(from: Int): Int? =
        if (from <= 0) null else (from - 1 downTo 0).firstOrNull(::isUserPly)

    /**
     * La position du joueur juste après [from] — la position vive
     * ([totalPlies]) s'il n'y en a plus, `null` si l'on y est déjà.
     */
    fun next(from: Int): Int? =
        if (from >= totalPlies) null else (from + 1..totalPlies).firstOrNull(::isUserPly) ?: totalPlies
}
