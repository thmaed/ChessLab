package com.chesslab.ui

import chesskit.Piece

/**
 * Notation FIGURINE : le dessin de la pièce à la place de sa lettre
 * (« ♘f3 » plutôt que « Nf3 » ou « Cf3 »).
 *
 * C'est la notation des livres d'échecs, et elle a un mérite concret ici :
 * elle est INDÉPENDANTE DE LA LANGUE. L'app existe en français et en anglais,
 * où un « F » et un « B » désignent la même pièce ; le glyphe supprime la
 * question.
 *
 * Transformation d'AFFICHAGE, et rien d'autre : jamais sur un SAN stocké,
 * comparé ou exporté — le standard PGN est en lettres anglaises.
 */
object FigurineSan {

    /**
     * Lettres de pièce du standard PGN, majuscules seulement : un « b »
     * minuscule est la colonne b, jamais le fou.
     */
    private val kinds = mapOf(
        'K' to Piece.Kind.king, 'Q' to Piece.Kind.queen, 'R' to Piece.Kind.rook,
        'B' to Piece.Kind.bishop, 'N' to Piece.Kind.knight,
    )

    /** Les figurines pleines : elles se lisent sur fond clair comme sombre. */
    private val glyphs = mapOf(
        Piece.Kind.king to "♚", Piece.Kind.queen to "♛", Piece.Kind.rook to "♜",
        Piece.Kind.bishop to "♝", Piece.Kind.knight to "♞", Piece.Kind.pawn to "♟",
    )

    /**
     * Deux endroits seulement portent une lettre de pièce, et ce sont les deux
     * que l'on remplace : le PREMIER caractère (« Nf3 », « Qxd5+ ») et la
     * promotion, après le « = » (« e8=Q+ »). Le reste traverse tel quel — le
     * roque « O-O » n'a pas de lettre de pièce.
     */
    fun format(san: String): String {
        if (san.isEmpty()) return san
        val out = StringBuilder()
        var index = 0
        while (index < san.length) {
            val c = san[index]
            val isPieceLetter = (index == 0 && kinds.containsKey(c)) ||
                (index > 0 && san[index - 1] == '=' && kinds.containsKey(c))
            if (isPieceLetter) out.append(glyphs[kinds[c]])
            else out.append(c)
            index++
        }
        return out.toString()
    }
}
