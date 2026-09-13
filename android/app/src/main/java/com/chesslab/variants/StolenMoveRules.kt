package com.chesslab.variants

import chesskit.Piece

/**
 * Le Coup Volé — variante MAISON : aucun moteur ne connaît le tour double, et
 * aucune option UCI ne saurait le décrire. Pendant de `StolenMoveVariant.swift`.
 *
 * Les règles de base restent celles du jeu classique — plateau, pièces, mat,
 * pat —, `chesskit` reste l'unique arbitre de légalité de CHAQUE coup, et
 * Stockfish ne sert que d'adversaire. SEUL le déroulement du tour change :
 *
 * 1. un jeton est gagné tous les [defaultTokenInterval] coups joués par un
 *    camp (réglable de 4 à 8) ;
 * 2. un seul jeton en stock : en gagner un nouveau efface l'ancien s'il n'a
 *    pas été dépensé ;
 * 3. un jeton ne peut pas être dépensé par un camp en échec ;
 * 4. dépensé, il fait jouer un coup PUIS un second — sauf si le premier met
 *    l'adversaire en échec, auquel cas le tour s'arrête là ;
 * 5. une prise en passant rendue possible par le dernier coup adverse reste
 *    valable au second coup du tour double, bien qu'un coup se soit
 *    intercalé — c'est le seul cas où cela peut arriver.
 */
object StolenMoveRules {

    val tokenIntervalRange = 4..8
    const val defaultTokenInterval = 7

    /** Le camp gagne-t-il un jeton en jouant son [movesPlayed]-ième coup ? */
    fun earnsToken(movesPlayed: Int, interval: Int): Boolean =
        movesPlayed > 0 && interval > 0 && movesPlayed % interval == 0

    /** Règle 3 : on ne dépense pas un jeton quand on est soi-même en échec. */
    fun canSpend(hasToken: Boolean, inCheck: Boolean): Boolean = hasToken && !inCheck

    /** Règle 4 : le tour double s'arrête si le premier coup donne échec. */
    fun turnContinues(firstMoveGivesCheck: Boolean): Boolean = !firstMoveGivesCheck

    /** La case de prise en passant d'une FEN, ou `null` s'il n'y en a pas. */
    fun enPassantTarget(fen: String): String? =
        fen.split(" ").getOrNull(3)?.takeIf { it != "-" && it.length == 2 }

    /**
     * La position REMISE au trait de [mover] pour son second coup — et, si la
     * FEN n'en porte plus, avec la case de prise en passant d'avant le
     * premier coup (règle 5).
     *
     * `chesskit` a passé le trait en appliquant le premier coup, et effacé la
     * prise en passant que le dernier coup adverse avait ouverte. Sans cette
     * remise en état, le second coup du tour double serait joué par
     * l'adversaire, et une prise en passant pourtant légale disparaîtrait.
     */
    fun fenForSecondMove(fen: String, mover: Piece.Color, enPassantOverride: String?): String? {
        val fields = fen.split(" ")
        if (fields.size != 6) return null
        val rebuilt = fields.toMutableList()
        rebuilt[1] = if (mover == Piece.Color.white) "w" else "b"
        if (rebuilt[3] == "-" && enPassantOverride != null) rebuilt[3] = enPassantOverride
        return rebuilt.joinToString(" ")
    }
}
