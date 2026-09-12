package com.chesslab.analysis

/**
 * Prétraitement des PGN collés. Pendant de `PGNSanitizer.swift`.
 *
 * **Pourquoi c'est nécessaire.** Le premier geste d'un utilisateur du mode
 * Analyser est de coller un PGN venu de Lichess ou de chess.com. Or un
 * copier-coller depuis un site web apporte des choses que le lecteur de PGN
 * refuse — et qui n'ont rien à voir avec les échecs : un BOM de tête, des fins
 * de ligne Windows, un commentaire de présentation avant le premier coup. Le
 * PGN est valide à l'œil, et l'app répondait « PGN illisible ».
 *
 * Vérifié sur le port Kotlin (`PgnRealWorldTest`) : les pendules `[%clk …]`,
 * les annotations NAG, les variantes et les lignes vides surnuméraires passent
 * déjà ; le BOM, les `\r\n` et le commentaire d'introduction, non. C'est ce que
 * cette classe répare, et rien d'autre — on ne nettoie pas ce qui n'est pas
 * cassé.
 *
 * Tout est PUR et testable : ni moteur, ni contexte.
 */
object PgnSanitizer {

    /** Le nettoyage complet, tel que l'appelle le point d'import. */
    fun sanitize(pgn: String): String =
        stripCastlingCheckMarkers(stripLeadingComment(collapseExtraBlankLines(normalizeWhitespace(pgn))))

    /**
     * Ce qu'un copier-coller (web, Windows) glisse et qui fait échouer la
     * lecture : BOM de tête, `\r\n` / `\r`, espaces insécables.
     */
    fun normalizeWhitespace(pgn: String): String =
        pgn.removePrefix("﻿")
            .replace("\r\n", "\n")
            .replace('\r', '\n')
            .replace(' ', ' ')   // insécable
            .replace(' ', ' ')   // fine insécable
            .replace(' ', ' ')   // fine

    /**
     * N'autorise qu'UNE ligne vide, le séparateur entre les tags et les coups.
     *
     * Les lignes vides de TÊTE sont retirées d'abord : sans ça, la première
     * d'entre elles consommait l'unique séparateur conservé, la vraie ligne
     * vide disparaissait, et un PGN correct était rejeté.
     */
    fun collapseExtraBlankLines(pgn: String): String {
        var seenSeparator = false
        val out = ArrayList<String>()
        for (line in pgn.split("\n").dropWhile { it.isBlank() }) {
            if (line.isBlank()) {
                if (seenSeparator) continue
                seenSeparator = true
            }
            out += line
        }
        return out.joinToString("\n")
    }

    /**
     * Retire un commentaire `{ … }` placé AVANT le premier coup. C'est
     * courant — « Partie commentée par… » — et ça fait échouer la lecture.
     *
     * **Va plus loin qu'iOS**, à dessein : là-bas, le nettoyage n'opère que
     * s'il existe un bloc de tags (il cherche la ligne vide qui le sépare des
     * coups). Or dans un champ « coller », on colle souvent les COUPS SEULS,
     * sans en-tête — et le commentaire de tête cassait alors la lecture malgré
     * l'assainisseur. Mesuré sur l'appareil.
     */
    fun stripLeadingComment(pgn: String): String {
        val separator = pgn.indexOf("\n\n")
        val tags = if (separator < 0) "" else pgn.substring(0, separator)
        var movetext = (if (separator < 0) pgn else pgn.substring(separator + 2)).trim()
        while (movetext.startsWith("{")) {
            val closing = movetext.indexOf('}')
            if (closing < 0) break
            movetext = movetext.substring(closing + 1).trim()
        }
        return if (tags.isEmpty()) movetext else "$tags\n\n$movetext"
    }

    /**
     * Retire le marqueur d'échec ou de mat APRÈS un roque — `O-O+`, `O-O-O#`.
     *
     * ChessKit refuse ces coups en amont (Swift comme Kotlin) alors qu'un échec
     * ordinaire passe. Le marqueur est purement décoratif : il décrit une
     * conséquence du coup, pas le coup — le retirer ne change rien à la partie
     * rejouée. Trouvé côté iOS sur un vrai fichier de tournoi, une partie sur
     * neuf refusée pour ce seul caractère.
     */
    fun stripCastlingCheckMarkers(text: String): String =
        Regex("(O-O(-O)?)[+#]").replace(text) { it.groupValues[1] }

    /**
     * Découpe un texte multi-parties : chaque nouvelle partie recommence par
     * `[Event …]`. Un fichier `.pgn` en contient souvent plusieurs, et l'écran
     * d'analyse n'en montre qu'une — la première.
     */
    fun splitIntoGames(pgnText: String): List<String> {
        val games = ArrayList<String>()
        val current = ArrayList<String>()
        for (line in normalizeWhitespace(pgnText).split("\n")) {
            if (line.startsWith("[Event ") && current.isNotEmpty()) {
                games += current.joinToString("\n").trim()
                current.clear()
            }
            current += line
        }
        current.joinToString("\n").trim().takeIf { it.isNotEmpty() }?.let { games += it }
        return games
    }
}
