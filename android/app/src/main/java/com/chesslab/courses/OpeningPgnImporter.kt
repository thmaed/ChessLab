package com.chesslab.courses

import chesskit.Game
import chesskit.Move
import chesskit.MoveTree
import chesskit.PgnParser
import com.chesslab.analysis.PgnSanitizer

/**
 * Convertit un PGN de RÉPERTOIRE (une étude Lichess, un livre saisi, un export
 * SCID) en [Course] — le même graphe indexé par FEN que les cours embarqués.
 * Pendant d'`OpeningPGNImporter.swift`.
 *
 * Pourquoi c'est court : le lecteur de PGN sait déjà lire les variantes entre
 * parenthèses et rend un arbre branchu, et tout l'aval de l'app (FSRS,
 * transpositions, lecteur, entraîneur) est indexé par FEN CANONIQUE et non par
 * identifiant de cours. Un cours importé y entre donc sans qu'une ligne de
 * l'aval change — c'est le pari du graphe qui paie ici.
 *
 * PUR : texte → cours (ou erreur). Ni disque, ni base, ni écran.
 */
object OpeningPgnImporter {

    sealed class ImportException(message: String) : Exception(message) {
        class Empty : ImportException("empty")
        class Unreadable(val detail: String) : ImportException("unreadable: $detail")
        class NoMoves : ImportException("no moves")
        /** Toutes les parties ne partent pas de la même position : un cours n'a qu'une racine. */
        class MixedStartingPositions : ImportException("mixed starting positions")
    }

    /** Le cours, plus ce qu'on a dû écarter — pour le dire plutôt que le taire. */
    data class Result(val course: Course, val skippedGames: Int, val skippedMoves: Int)

    /**
     * Le nom du répertoire DÉDUIT du PGN, quand le fichier en porte un. Une
     * étude Lichess arrive avec `[Event "Nom de l'étude: Nom du chapitre"]` :
     * c'est le nom que l'utilisateur a donné, le lui faire ressaisir serait
     * absurde. Par ordre : `[Opening]`, puis `[Event]` tronqué avant le « : »,
     * puis `[White]`. `null` plutôt qu'un nom vide ou générique.
     */
    fun suggestedName(pgn: String): String? {
        fun tag(key: String): String? {
            val m = Regex("\\[$key\\s+\"([^\"]*)\"").find(pgn) ?: return null
            val value = m.groupValues[1].trim()
            return value.takeUnless { it in rejectedNames }
        }
        tag("Opening")?.let { return it }
        tag("Event")?.let { event ->
            val colon = event.indexOf(':')
            if (colon > 0) event.substring(0, colon).trim().takeIf { it.isNotEmpty() }?.let { return it }
            return event
        }
        return tag("White")
    }

    private val rejectedNames = setOf("", "?", "Event", "event", "Study", "Chapter")

    /**
     * @param side le camp étudié — « white » ou « black » ; décide de quel côté
     *   l'entraînement interroge, seul choix qu'un PGN ne porte pas.
     */
    fun course(pgn: String, name: String, side: String, id: String, fallbackName: String, chapterLabel: (Int) -> String): Result {
        val trimmed = pgn.trim()
        if (trimmed.isEmpty()) throw ImportException.Empty()

        // Même prétraitement que tous les autres points d'import : fins de
        // ligne Windows, BOM, commentaire de tête — ce qu'un copier-coller
        // réel produit constamment. DÉCOUPER d'abord, nettoyer ENSUITE, partie
        // par partie : le nettoyage ne garde qu'une ligne vide, et appliqué au
        // fichier entier il mangeait celle qui sépare les en-têtes de la
        // seconde partie — qui devenait illisible.
        val games = PgnSanitizer.splitIntoGames(trimmed).map { PgnSanitizer.sanitize(it) }
        if (games.isEmpty()) throw ImportException.NoMoves()

        val positions = LinkedHashMap<String, MutableList<CourseMove>>()
        val chapters = ArrayList<Chapter>()
        var rootKey: String? = null
        var skippedGames = 0
        var skippedMoves = 0
        var firstError: String? = null

        games.forEachIndexed { offset, text ->
            val game = runCatching { PgnParser.parse(text) }.getOrNull()
            if (game == null) {
                skippedGames++
                if (firstError == null) firstError = text.trim().take(60)
                return@forEachIndexed
            }
            val start = game.startingPosition ?: run { skippedGames++; return@forEachIndexed }
            val startKey = CourseRepository.key(start)
            if (rootKey != null && rootKey != startKey) throw ImportException.MixedStartingPositions()
            rootKey = startKey

            val absorbed = absorb(game, startKey, positions)
            skippedMoves += absorbed.skippedMoves
            if (absorbed.spine.size <= 1) { skippedGames++; return@forEachIndexed }
            chapters += Chapter("chapter-${offset + 1}", chapterTitle(game, offset, chapterLabel), absorbed.spine)
        }

        val root = rootKey
        if (root == null || root !in positions) throw ImportException.NoMoves()
        // Un cours sans la moindre arête n'apprend rien : on refuse plutôt que
        // d'ajouter une entrée vide à la liste.
        if (positions.values.none { it.isNotEmpty() }) {
            firstError?.let { throw ImportException.Unreadable(it) }
            throw ImportException.NoMoves()
        }

        val course = Course(
            id = id,
            name = name.trim().ifEmpty { fallbackName },
            summary = "",
            side = side,
            rootFEN = root,
            chapters = chapters,
            positions = positions.mapValues { it.value.toList() },
        )
        return Result(course, skippedGames, skippedMoves)
    }

    private class Absorbed(val spine: List<String>, val skippedMoves: Int)

    /**
     * Verse une partie dans le graphe partagé : un nœud par position atteinte,
     * une arête par coup. Les positions communes à plusieurs parties (ou à
     * plusieurs variantes) FUSIONNENT d'elles-mêmes, puisque la clé est la FEN
     * canonique — c'est ce qui transforme un empilement d'arbres PGN en un vrai
     * graphe de répertoire.
     *
     * L'ordre de parcours n'a AUCUNE importance : chaque arête se calcule
     * depuis les positions de la partie, qui connaît déjà celle de chaque
     * index, et les nœuds se créent à la demande.
     */
    private fun absorb(game: Game, startKey: String, positions: MutableMap<String, MutableList<CourseMove>>): Absorbed {
        positions.getOrPut(startKey) { ArrayList() }
        var skipped = 0

        for (index in game.moves.indices) {
            val move = game.moves[index]
            val childPosition = game.position(index)
            if (move == null || childPosition == null) { skipped++; continue }
            val history = game.moves.history(index)
            val parentIndex = history.dropLast(1).lastOrNull()
            val parentKey = parentIndex?.let { game.position(it) }?.let { CourseRepository.key(it) } ?: startKey
            val childKey = CourseRepository.key(childPosition)

            // Garde-fou AVANT de créer quoi que ce soit : jamais une arête que
            // le validateur rejetterait, ni le nœud orphelin qui irait avec.
            if (OpeningCourseValidator.resultingKey(move.lan, parentKey) != childKey) { skipped++; continue }

            val parent = positions.getOrPut(parentKey) { ArrayList() }
            positions.getOrPut(childKey) { ArrayList() }
            // Le même coup n'est ajouté qu'une fois : la fusion des
            // transpositions fait qu'on repasse forcément sur des arêtes connues.
            if (parent.none { it.uci == move.lan }) {
                parent += CourseMove(
                    san = move.san, uci = move.lan, toFEN = childKey,
                    role = role(move, index.variation == MoveTree.Index.MAIN_VARIATION),
                    // Le commentaire vient de l'utilisateur lui-même : validé
                    // par construction. La règle « jamais de brouillon » vise
                    // le contenu GÉNÉRÉ, pas ce que l'auteur a écrit de sa main.
                    comment = move.comment.trim().ifEmpty { null },
                    eval = null, popularity = null,
                )
            }
        }

        // Le sommaire du chapitre = la LIGNE PRINCIPALE, lue dans l'arbre.
        val mainLine = game.moves.history(game.moves.lastMainVariationIndex)
        val spine = (listOf(startKey) + mainLine.mapNotNull { game.position(it)?.let { p -> CourseRepository.key(p) } })
            .filter { it in positions }
        return Absorbed(spine, skipped)
    }

    /**
     * Le PGN porte déjà le jugement de l'auteur (`?`, `?!`, `!`) : on le
     * traduit en rôle, pour que le lecteur affiche « Piège » ou « Imprécision »
     * sans rien faire ressaisir.
     */
    private fun role(move: Move, isMainLine: Boolean): String = when (move.assessment) {
        Move.Assessment.blunder, Move.Assessment.mistake -> "trap"
        Move.Assessment.dubious -> "inaccuracy"
        else -> if (isMainLine) "mainLine" else "sideline"
    }

    private fun chapterTitle(game: Game, index: Int, label: (Int) -> String): String {
        // Une étude Lichess met le nom du chapitre dans `Event` ; un fichier de
        // parties y met le tournoi. Les deux valent mieux qu'un numéro, sauf
        // quand c'est le « ? » des PGN sans métadonnées.
        val event = game.tags.event.trim()
        return if (event.isNotEmpty() && event != "?") event else label(index + 1)
    }
}
