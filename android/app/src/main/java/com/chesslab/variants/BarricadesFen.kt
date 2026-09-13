package com.chesslab.variants

import chesskit.Square

/**
 * La FEN des Barricades, et la protection de `chesskit` contre elle.
 *
 * Le mur est une PIÈCE aux yeux du moteur — la lettre « W », un type
 * `immobile` qui ne peut jouer aucun coup. `chesskit` ne la connaît pas et
 * refuserait la position entière à cause d'elle : on la lui retire avant de
 * lui donner quoi que ce soit, et l'on garde les cases de côté pour les
 * dessiner. Pendant de `BarricadesFEN.swift`.
 */
object BarricadesFen {

    /** La lettre du mur dans la FEN du moteur — MAJUSCULE, donc blanche. */
    const val wallLetter = 'W'

    private val files = "abcdefgh"

    /** La même FEN, sans les murs : celle que `chesskit` sait lire. */
    fun forChessKit(fen: String): String {
        val fields = fen.split(" ")
        val placement = fields.firstOrNull() ?: return fen
        // Le test porte sur le PLACEMENT seul, jamais sur la FEN entière : le
        // champ du trait vaut « w » une fois sur deux, et le chercher partout
        // ferait retraiter chaque position de toutes les variantes pour rien.
        if (placement.none { isWall(it) }) return fen
        val cleaned = placement.split("/").joinToString("/") { compress(expand(it).map { s -> if (isWall(s)) '.' else s }) }
        return (listOf(cleaned) + fields.drop(1)).joinToString(" ")
    }

    /**
     * Les cases murées d'une FEN. LUES plutôt que supposées : c'est le moteur
     * qui fait autorité sur le plateau, ici comme ailleurs.
     */
    fun wallSquares(fen: String): List<Square> {
        val placement = fen.split(" ").firstOrNull() ?: return emptyList()
        val squares = ArrayList<Square>()
        placement.split("/").forEachIndexed { index, rankText ->
            val rank = 8 - index
            if (rank !in 1..8) return@forEachIndexed
            expand(rankText).forEachIndexed { file, slot ->
                if (isWall(slot) && file < files.length) squares += Square("${files[file]}$rank")
            }
        }
        return squares
    }

    /** Réécrit une FEN SANS mur en y posant ceux qu'on lui donne. */
    fun inserting(walls: Set<Square>, fen: String): String? {
        val fields = fen.split(" ")
        val placement = fields.firstOrNull() ?: return null
        val ranks = ArrayList<String>()
        placement.split("/").forEachIndexed { index, rankText ->
            val rank = 8 - index
            val slots = expand(rankText).toMutableList()
            for (file in slots.indices) {
                if (slots[file] != '.' || file >= files.length) continue
                if (Square("${files[file]}$rank") in walls) slots[file] = wallLetter
            }
            ranks += compress(slots)
        }
        return (listOf(ranks.joinToString("/")) + fields.drop(1)).joinToString(" ")
    }

    private fun isWall(c: Char): Boolean = c.uppercaseChar() == wallLetter

    /** Une rangée de FEN en 8 cases, les vides en « . ». */
    private fun expand(rank: String): List<Char> {
        val slots = ArrayList<Char>(8)
        for (c in rank) {
            val empty = c.digitToIntOrNull()
            if (empty != null && empty in 1..8) repeat(empty) { slots += '.' } else slots += c
        }
        return slots
    }

    private fun compress(slots: List<Char>): String {
        val out = StringBuilder()
        var empty = 0
        for (slot in slots) {
            if (slot == '.') {
                empty++
            } else {
                if (empty > 0) { out.append(empty); empty = 0 }
                out.append(slot)
            }
        }
        if (empty > 0) out.append(empty)
        return out.toString()
    }
}
