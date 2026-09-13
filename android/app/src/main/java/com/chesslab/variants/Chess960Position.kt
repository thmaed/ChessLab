package com.chesslab.variants

/**
 * Les 960 positions de départ du Chess960, par leur numéro de Scharnagl.
 * Pendant de `Chess960Position.swift`.
 *
 * L'algorithme est le port fidèle de `chess.BaseBoard._set_chess960_pos` de
 * python-chess, et le test compare les 960 FEN produites à celles que
 * python-chess a écrites (`ChessLabTests/Fixtures_chess960_starts.json`, le
 * MÊME fichier que la suite iOS). La numérotation est donc INTERCHANGEABLE
 * avec Lichess et les moteurs : la position 518 est la partie classique.
 */
object Chess960Position {

    /** La position classique : sa numérotation est celle de tout le monde. */
    const val classic = 518

    val range = 0..959

    /** Rangée de base (blanche, a→h) du numéro [number], ou `null` hors bornes. */
    fun backRank(number: Int): CharArray? {
        if (number !in range) return null

        var n = number
        val bw = n % 4; n /= 4          // fou de cases claires : b, d, f, h
        val bb = n % 4; n /= 4          // fou de cases sombres : a, c, e, g
        val q = n % 6; n /= 6           // dame : q-ième case libre

        // Décomposition N5N : n ∈ 0…9 désigne la paire de cases des cavaliers
        // parmi les 5 restantes — même boucle que python-chess.
        var n1 = 0
        var n2 = 0
        for (candidate in 0 until 4) {
            n1 = candidate
            n2 = n + (3 - candidate) * (4 - candidate) / 2 - 5
            if (n1 < n2 && n2 in 1..4) break
        }

        val rank = arrayOfNulls<Char>(8)
        val bwFile = bw * 2 + 1
        val bbFile = bb * 2
        rank[bwFile] = 'B'
        rank[bbFile] = 'B'

        var qFile = q
        if (minOf(bwFile, bbFile) <= qFile) qFile++
        if (maxOf(bwFile, bbFile) <= qFile) qFile++
        rank[qFile] = 'Q'

        var counterN1 = n1
        var counterN2 = n2
        for (file in 0 until 8) {
            if (rank[file] != null) continue
            if (counterN1 == 0 || counterN2 == 0) rank[file] = 'N'
            counterN1--
            counterN2--
        }

        // Les trois cases restantes, de gauche à droite : tour, roi, tour.
        for (piece in "RKR") {
            val file = rank.indexOfFirst { it == null }
            if (file < 0) return null
            rank[file] = piece
        }
        return CharArray(8) { rank[it]!! }
    }

    /**
     * La rangée respecte-t-elle les règles du Chess960 ? Trois conditions, que
     * l'algorithme de Scharnagl impose par construction — nécessaires ici
     * parce qu'un agencement composé À LA MAIN peut les violer :
     * - le ROI est strictement ENTRE les deux tours (sans quoi le roque tel que
     *   cette app le joue perd son sens : on ne saurait plus quelle tour est
     *   « petit côté ») ;
     * - les deux FOUS sont sur des cases de couleurs DIFFÉRENTES (règle FIDE) ;
     * - le jeu de pièces exact.
     */
    fun isLegalBackRank(rank: CharArray): Boolean {
        if (rank.size != 8) return false
        if (String(rank.clone().also { it.sort() }) != "BBKNNQRR") return false
        val king = rank.indexOf('K')
        if (king < 0) return false
        val rooks = rank.indices.filter { rank[it] == 'R' }
        if (rooks.size != 2 || rooks[0] >= king || king >= rooks[1]) return false
        val bishops = rank.indices.filter { rank[it] == 'B' }
        if (bishops.size != 2) return false
        return (bishops[0] % 2 == 0) != (bishops[1] % 2 == 0)
    }

    /**
     * Le numéro dont la rangée de base est EXACTEMENT [rank], ou `null`.
     * Balayage linéaire : 960 positions, coût négligeable, et ça évite
     * d'inverser l'algorithme pour un besoin qui ne se produit qu'au réglage
     * d'une partie, jamais en boucle chaude.
     */
    fun number(rank: CharArray): Int? {
        if (!isLegalBackRank(rank)) return null
        return range.firstOrNull { backRank(it)?.concatToString() == rank.concatToString() }
    }

    /**
     * FEN Shredder complète de la position : droits de roque en LETTRES DE
     * COLONNES (« HFhf »), le dialecte que parle le moteur sous
     * `UCI_Chess960` — la seule forme non ambiguë quand les tours ne sont pas
     * en a1 et h1.
     */
    fun startingFen(number: Int): String? {
        val rank = backRank(number) ?: return null
        val white = rank.concatToString()
        val black = white.lowercase()
        val rights = rank.indices.filter { rank[it] == 'R' }
            .map { ('A' + it) }
            .sortedDescending()
            .joinToString("")
        return "$black/pppppppp/8/8/8/8/PPPPPPPP/$white w $rights${rights.lowercase()} - 0 1"
    }
}
