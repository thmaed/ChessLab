package com.chesslab.library

import chesskit.PgnParser

/**
 * Reconnaître une partie déjà rangée. Pendant de `GameLibraryService.signature`
 * et `movetext` côté iOS.
 *
 * L'import Android n'écartait AUCUN doublon : réimporter le même fichier
 * doublait la bibliothèque, quand iOS dit « 3 déjà présentes, non
 * réimportées ». La signature tient aux COUPS et aux deux joueurs, jamais au
 * texte brut : le même PGN exporté par deux sites diffère par ses balises,
 * ses commentaires et ses espaces.
 *
 * Les joueurs entrent dans la signature à dessein : deux parties DIFFÉRENTES
 * peuvent partager leurs coups (une nulle courte, une miniature connue), et en
 * écarter une à tort ferait perdre une partie à l'utilisateur — bien pire que
 * de laisser passer un doublon.
 */
object GameSignature {

    /** `null` pour un PGN illisible ou sans coup. */
    fun of(pgn: String): String? {
        val game = runCatching { PgnParser.parse(pgn) }.getOrNull() ?: return null
        val moves = movetext(pgn)
        if (moves.isEmpty()) return null
        return "${name(game.tags.white)}|${name(game.tags.black)}|$moves"
    }

    /**
     * Nom réduit à ce qui compte. « ? » vaut ABSENT : c'est ce que le standard
     * écrit pour un joueur inconnu, et ce que les exports de l'app posent
     * depuis qu'ils émettent les sept balises (29/09/2026). Sans cette
     * équivalence, une partie rangée avant — sans balises — puis réimportée
     * après aurait deux signatures, et reviendrait en double.
     */
    fun name(raw: String): String = raw.trim().lowercase().let { if (it == "?") "" else it }

    /**
     * La suite de coups NORMALISÉE : balises, commentaires, variantes, numéros
     * de coup, annotations et résultat retirés, espaces réduits.
     */
    fun movetext(pgn: String): String {
        var text = pgn
        text = text.replace(Regex("\\[[^\\]]*\\]"), " ")
        text = text.replace(Regex("\\{[^}]*\\}"), " ")
        text = text.replace(Regex("\\([^)]*\\)"), " ")
        text = text.replace(Regex("\\d+\\.(\\.\\.)?"), " ")
        text = text.replace(Regex("\\$\\d+"), " ")
        text = text.replace(Regex("[!?]+"), "")
        for (token in listOf("1-0", "0-1", "1/2-1/2", "*")) text = text.replace(token, " ")
        return text.split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")
    }
}
