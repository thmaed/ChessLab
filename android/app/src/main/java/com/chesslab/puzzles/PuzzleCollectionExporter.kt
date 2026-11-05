package com.chesslab.puzzles

import chesskit.Board
import chesskit.Piece
import chesskit.Position
import chesskit.Square

/**
 * Écrit une collection de puzzles en PGN — la sauvegarde que la base locale ne
 * fait pas, et le moyen de la passer à un autre appareil ou à un autre logiciel.
 * Pendant de `PuzzleCollectionExporter.swift`, qui fait foi.
 *
 * ## Le format
 *
 * Une PARTIE par puzzle, que [PuzzleCollectionImporter] relit à l'identique :
 * - `[FEN]` : la position où le puzzle COMMENCE (celle d'après sa préparation) ;
 * - `[PuzzleSetup]` : le coup de préparation en LAN (`e7e5`), ou `-` s'il n'y en
 *   a pas. C'est ce qui dit à l'importeur de ChessLab que le `[FEN]` est déjà le
 *   départ du puzzle — sinon il prendrait le premier coup pour une préparation,
 *   selon la convention de Lichess ;
 * - la ligne principale : la solution seule, en SAN.
 *
 * Pourquoi ne pas écrire la position d'AVANT la préparation, comme Lichess ?
 * Parce qu'elle n'est pas gardée, et qu'elle ne se retrouve pas en défaisant le
 * coup (une prise, un droit de roque perdu). Un autre logiciel lit donc le puzzle
 * tel qu'il se pose — position et solution —, sans la préparation.
 */
object PuzzleCollectionExporter {

    data class Entry(val fen: String, val setup: String?, val solution: List<String>)

    /**
     * Le fichier d'une collection. Un puzzle dont la solution ne se rejoue pas
     * (position illisible, coup illégal) est sauté : mieux vaut un fichier sans lui
     * qu'un fichier que l'import refuserait en bloc.
     */
    fun pgn(collection: String, entries: List<Entry>): String {
        val event = collection.replace("\"", "'").lines().joinToString(" ")
        val games = entries.mapNotNull { entry ->
            val movetext = movetext(entry) ?: return@mapNotNull null
            "[Event \"$event\"]\n[SetUp \"1\"]\n[FEN \"${entry.fen}\"]\n" +
                "[PuzzleSetup \"${entry.setup ?: "-"}\"]\n\n$movetext"
        }
        return if (games.isEmpty()) "" else games.joinToString("\n\n") + "\n"
    }

    /** Le nom du fichier proposé : celui de la collection, sans ce qu'un système de fichiers refuse. */
    fun fileName(collection: String): String {
        val cleaned = collection.map { if (it in "/\\:*?\"<>|" || it.isISOControl()) '-' else it }
            .joinToString("").trim()
        return (cleaned.ifEmpty { "ChessLab" }) + ".pgn"
    }

    // MARK: Une solution en SAN

    private fun movetext(entry: Entry): String? {
        if (entry.solution.isEmpty()) return null
        val start = Position.fromFen(entry.fen) ?: return null
        val fields = entry.fen.split(" ").filter { it.isNotEmpty() }
        var fullmove = fields.getOrNull(5)?.toIntOrNull() ?: 1
        var whiteToMove = fields.getOrNull(1)?.let { it == "w" } ?: true

        val board = Board(start)
        val parts = ArrayList<String>()
        for ((index, lan) in entry.solution.withIndex()) {
            if (lan.length < 4) return null
            var move = board.move(Square(lan.substring(0, 2)), Square(lan.substring(2, 4))) ?: return null
            if (board.state is Board.State.Promotion) {
                move = board.completePromotion(move, promotionKind(lan))
            }
            if (whiteToMove) {
                parts += "$fullmove. ${move.san}"
            } else {
                parts += if (index == 0) "$fullmove... ${move.san}" else move.san
                fullmove++
            }
            whiteToMove = !whiteToMove
        }
        return parts.joinToString(" ") + " *"
    }

    private fun promotionKind(lan: String): Piece.Kind = when (lan.getOrNull(4)?.lowercaseChar()) {
        'n' -> Piece.Kind.knight
        'b' -> Piece.Kind.bishop
        'r' -> Piece.Kind.rook
        else -> Piece.Kind.queen
    }
}
