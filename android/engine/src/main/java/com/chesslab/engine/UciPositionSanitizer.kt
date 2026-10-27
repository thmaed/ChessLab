package com.chesslab.engine

/**
 * Garde-fou entre l'app et le moteur : une FEN dont le champ de roque annonce un droit que l'échiquier ne
 * permet plus FAIT PLANTER Stockfish. Pendant de `UCIPositionSanitizer.swift`.
 *
 * Retour d'un joueur (27/10/2026, iOS) : l'app plantait à chaque reprise d'une partie. `Position::set` cherche,
 * pour chaque `K`/`Q`/`k`/`q`, la tour du roque en balayant la rangée depuis le coin — sans borne : si la tour a
 * été capturée dans son coin, la boucle sort de l'échiquier. La FEN que produit la bibliothèque d'échecs garde le
 * droit d'un camp quand sa tour est prise dans son coin. On la corrige donc AVANT de l'envoyer : un droit n'est
 * conservé que s'il existe, sur la rangée de fond, un roi du camp et une tour du camp du bon côté de ce roi. Les
 * droits « Shredder » (lettres de colonnes) ne font pas balayer le moteur : ils sont laissés tels quels.
 */
object UciPositionSanitizer {

    /** La commande UCI, avec la FEN assainie si c'est un `position fen …`. Toute autre commande passe telle quelle. */
    fun sanitize(command: String): String {
        val prefix = "position fen "
        if (!command.startsWith(prefix)) return command
        val rest = command.substring(prefix.length)
        val parts = rest.split(" moves ")
        val fixed = castlingFixed(parts[0])
        return if (parts.size == 1) prefix + fixed else prefix + fixed + " moves " + parts.drop(1).joinToString(" moves ")
    }

    /** La FEN, droits de roque ramenés à ce que l'échiquier permet. */
    fun castlingFixed(fen: String): String {
        val fields = fen.split(" ").filter { it.isNotEmpty() }.toMutableList()
        if (fields.size < 3) return fen
        val placement = fields[0].substringBefore('[')
        val ranks = placement.split("/")
        // Seul l'échiquier 8 × 8 a des coins connus ; ailleurs on ne touche à rien.
        if (ranks.size != 8) return fen
        val whiteBack = expand(ranks[7]) ?: return fen
        val blackBack = expand(ranks[0]) ?: return fen

        val kept = StringBuilder()
        for (right in fields[2]) {
            val keep = when (right) {
                'K' -> hasRook(whiteBack, 'K', 'R', true)
                'Q' -> hasRook(whiteBack, 'K', 'R', false)
                'k' -> hasRook(blackBack, 'k', 'r', true)
                'q' -> hasRook(blackBack, 'k', 'r', false)
                else -> true   // « - » ou une lettre de colonne (Shredder-FEN)
            }
            if (keep) kept.append(right)
        }
        val letters = kept.toString().filter { it != '-' }
        fields[2] = if (letters.isEmpty()) "-" else letters
        return fields.joinToString(" ")
    }

    private fun expand(rank: String): List<Char>? {
        val squares = ArrayList<Char>()
        for (c in rank) {
            val digit = c.digitToIntOrNull()
            if (digit != null && digit in 1..8) repeat(digit) { squares += '.' } else squares += c
        }
        return if (squares.size == 8) squares else null
    }

    private fun hasRook(back: List<Char>, king: Char, rook: Char, kingside: Boolean): Boolean {
        val kingFile = back.indexOf(king)
        if (kingFile < 0) return false
        val range = if (kingside) (kingFile + 1) until 8 else 0 until kingFile
        return range.any { back[it] == rook }
    }
}
