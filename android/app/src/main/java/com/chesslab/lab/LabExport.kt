package com.chesslab.lab

/**
 * L'export d'une série : un PGN (toutes les parties bout à bout) et un CSV
 * (une ligne par partie). Pendant de `LabExport.swift`, pur et testable.
 *
 * Chaque partie reçoit des en-têtes SYNTHÉTIQUES et son movetext est clos par
 * le résultat : sans cela, une partie sortait sans joueurs ni score, donc
 * inexploitable ailleurs. Les tags de position de départ (`SetUp`/`FEN`) émis
 * pour une série à FEN personnalisé sont conservés — sans eux, l'autre outil
 * rejouerait les coups depuis la position standard.
 */
object LabExport {

    fun pgn(games: List<LabCompletedGame>, nameA: String, nameB: String): String =
        games.joinToString("\n\n") { game ->
            val white = if (game.aWasWhite) nameA else nameB
            val black = if (game.aWasWhite) nameB else nameA

            val lines = game.pgn.trim().split("\n")
            val setupTags = lines.filter { it.startsWith("[SetUp") || it.startsWith("[FEN") }
            var movetext = lines.filterNot { it.startsWith("[") }.joinToString("\n").trim()
            if (!movetext.endsWith(game.pgnResult)) {
                movetext += (if (movetext.isEmpty()) "" else " ") + game.pgnResult
            }

            val header = buildString {
                append("[Event \"ChessLab Lab\"]\n")
                append("[Round \"${game.index + 1}\"]\n")
                append("[White \"$white\"]\n")
                append("[Black \"$black\"]\n")
                append("[Result \"${game.pgnResult}\"]\n")
                append("[Termination \"${game.reasonLabel}\"]")
                if (setupTags.isNotEmpty()) append("\n" + setupTags.joinToString("\n"))
            }
            "$header\n\n$movetext"
        }

    fun csv(games: List<LabCompletedGame>): String {
        val rows = ArrayList<String>(games.size + 1)
        rows += "partie,camp_A,resultat,score_A,demi_coups,fin"
        for (game in games) {
            val aColor = if (game.aWasWhite) "Blanc" else "Noir"
            val scoreA = when (game.labResult) {
                LabGameResult.winA -> "1"
                LabGameResult.draw -> "0.5"
                LabGameResult.winB -> "0"
            }
            rows += "${game.index + 1},$aColor,${game.pgnResult},$scoreA,${game.plyCount},${game.reasonLabel}"
        }
        return rows.joinToString("\n")
    }
}
