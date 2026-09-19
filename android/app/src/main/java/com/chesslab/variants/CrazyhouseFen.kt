package com.chesslab.variants

import chesskit.Piece
import chesskit.Square

/**
 * La RÉSERVE du Crazyhouse, lue dans la FEN du moteur.
 *
 * Fairy-Stockfish écrit les pièces en main entre crochets, juste après le
 * plateau : `rnb1kbnr/…/RNBQKBNR[Pp] w KQkq - 0 3` — majuscules pour les
 * Blancs, minuscules pour les Noirs, `[]` quand les deux mains sont vides.
 * `chesskit` ignore cette section, c'est donc à nous de la relever. Pendant
 * de `FairyEngineController.parsePocket(fromFEN:)`.
 */
object CrazyhouseFen {

    /** L'ordre d'affichage : la plus forte d'abord, comme sur iOS. */
    val order = listOf(
        Piece.Kind.queen, Piece.Kind.rook, Piece.Kind.bishop, Piece.Kind.knight, Piece.Kind.pawn,
    )

    /** Les pièces en main, par camp et par type. */
    fun pocket(fen: String): Map<Piece.Color, Map<Piece.Kind, Int>> {
        val open = fen.indexOf('[')
        val close = fen.indexOf(']')
        if (open < 0 || close < 0 || open >= close) return emptyMap()
        val result = HashMap<Piece.Color, MutableMap<Piece.Kind, Int>>()
        for (c in fen.substring(open + 1, close)) {
            val kind = kind(c) ?: continue
            val color = if (c.isUpperCase()) Piece.Color.white else Piece.Color.black
            val hand = result.getOrPut(color) { HashMap() }
            hand[kind] = (hand[kind] ?: 0) + 1
        }
        return result
    }

    /**
     * La FEN débarrassée de ce qui n'appartient qu'aux variantes : la réserve
     * entre crochets, et le `~` qui marque une pièce PROMUE (elle redevient un
     * pion si on la capture, mais elle se dessine comme ce qu'elle est).
     * `chesskit` ne connaît ni l'un ni l'autre et refuserait la position.
     */
    fun boardFen(fen: String): String {
        val fields = fen.trim().split(" ").filter { it.isNotEmpty() }
        if (fields.isEmpty()) return fen
        val placement = fields[0].substringBefore('[').replace("~", "")
        return (listOf(placement) + fields.drop(1)).joinToString(" ")
    }

    /**
     * La lettre FEN d'un type — « P », « N », « B », « R », « Q », « K ».
     *
     * À ne PAS confondre avec la lettre SAN, qui est VIDE pour le pion : s'en
     * servir pour bâtir une pose donnerait le préfixe « @ » au lieu de « P@ »,
     * et aucune case de pose ne serait trouvée. Le défaut est passé par là
     * côté iOS.
     */
    fun letter(kind: Piece.Kind): String = when (kind) {
        Piece.Kind.pawn -> "P"
        Piece.Kind.knight -> "N"
        Piece.Kind.bishop -> "B"
        Piece.Kind.rook -> "R"
        Piece.Kind.queen -> "Q"
        Piece.Kind.king -> "K"
    }

    private fun kind(c: Char): Piece.Kind? = when (c.lowercaseChar()) {
        'p' -> Piece.Kind.pawn
        'n' -> Piece.Kind.knight
        'b' -> Piece.Kind.bishop
        'r' -> Piece.Kind.rook
        'q' -> Piece.Kind.queen
        'k' -> Piece.Kind.king
        else -> null
    }
}

/**
 * Les deux cases à SURLIGNER pour un coup rendu par le moteur.
 *
 * Un coup de variante n'est pas toujours « départ + arrivée » : au Crazyhouse,
 * le moteur répond `P@e4` pour poser une pièce de sa réserve. Découpé comme un
 * coup ordinaire, cela donne `P@` et `e4` — et `Square("P@")` ne proteste pas,
 * il retombe silencieusement sur `a1`. L'app surlignait donc `a1` → `e4` à
 * chaque parachutage de l'adversaire, alors que le parachutage de l'utilisateur,
 * lui, était marqué correctement.
 *
 * Une pose n'a pas d'origine : ses deux cases sont la même.
 */
object VariantMoveMarks {

    fun of(lan: String): Pair<Square, Square>? {
        if (lan.length < 4) return null
        // `P@e4` : la lettre de la pièce, puis l'arobase, puis la case.
        if (lan[1] == '@') {
            val cible = Square(lan.substring(2, 4))
            return cible to cible
        }
        return Square(lan.substring(0, 2)) to Square(lan.substring(2, 4))
    }
}
