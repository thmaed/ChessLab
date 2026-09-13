package com.chesslab.lab

import chesskit.MoveTree
import chesskit.PgnParser
import chesskit.Position
import com.chesslab.analysis.PgnSanitizer
import com.chesslab.courses.CourseRepository

/**
 * Résout la position de départ d'une série à partir d'un texte qui peut être
 * un **FEN** ou un **PGN**. Pendant de `LabStartPosition.swift`.
 *
 * Un PGN est ramené à la FEN de sa position FINALE (ligne principale) : c'est
 * ce qui permet de lancer une série depuis la fin d'une ouverture qu'on vient
 * de coller, sans avoir à en recopier la position à la main.
 */
object LabStartPosition {

    /**
     * @return la FEN de départ, le nombre de demi-coups joués pour l'atteindre
     * (`0` pour un FEN direct), et si la source était un PGN. `null` si le
     * texte n'est ni un FEN légal ni un PGN lisible.
     */
    fun resolve(text: String): Resolved? {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return null

        // Un FEN légal l'emporte : on le prend tel quel. `CourseRepository`
        // plutôt que le parseur brut, pour accepter les quatre champs — et
        // pour refuser une chaîne qui n'a pas ses deux rois.
        CourseRepository.position(trimmed)?.let {
            return Resolved(it.fen, plies = 0, fromPgn = false)
        }

        val candidate = PgnSanitizer.splitIntoGames(PgnSanitizer.sanitize(trimmed))
            .firstOrNull() ?: trimmed
        if (candidate.isEmpty()) return null
        val game = runCatching { PgnParser.parse(candidate) }.getOrNull() ?: return null

        val mainline = game.moves.indices
            .filter { it.variation == MoveTree.Index.MAIN_VARIATION }
            .sorted()
        val last = mainline.lastOrNull() ?: return null
        val position = game.position(last) ?: return null
        return Resolved(position.fen, plies = mainline.size, fromPgn = true)
    }

    data class Resolved(val fen: String, val plies: Int, val fromPgn: Boolean) {
        val isStandard: Boolean get() = fen == Position.standard.fen
    }
}
