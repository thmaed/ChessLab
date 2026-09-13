package com.chesslab.courses

import androidx.annotation.StringRes
import chesskit.Board
import chesskit.Piece
import chesskit.Square
import com.chesslab.R

/**
 * Édition d'un répertoire PERSONNEL : ajouter une variante, en retirer une,
 * commenter un coup. Pendant d'`OpeningCourseEditor.swift`.
 *
 * Couche PURE, sans état ni interface : chaque opération prend un cours et en
 * rend un autre. C'est ce qui la rend testable sans appareil, et c'est
 * délibéré — un éditeur d'arbre est exactement le genre de code où une erreur
 * de graphe (arête orpheline, nœud inatteignable, chapitre pendant) ne se voit
 * pas à l'écran mais casse la validation à l'enregistrement.
 *
 * Deux invariants tenus par construction, et vérifiés par les tests :
 * 1. **aucune arête que le validateur rejetterait** — le coup est rejoué par
 *    la même mécanique que l'import PGN avant de fabriquer quoi que ce soit ;
 * 2. **aucun nœud inatteignable** — après un retrait, le graphe est reparcouru
 *    depuis `rootFEN` et ce qui n'est plus joignable disparaît, chapitres
 *    compris. Sans ça, [UserOpeningStore.save] refuserait le cours.
 *
 * Le graphe est indexé par FEN : retirer une arête ne retire donc PAS toujours
 * les positions qui suivent, puisqu'une transposition peut encore y mener.
 * C'est pourquoi la purge se calcule par accessibilité, jamais en descendant
 * naïvement le sous-arbre.
 */
object OpeningCourseEditor {

    /**
     * Ce qui peut refuser une modification. Le message est une RESSOURCE que
     * l'écran résout : la couche pure ne connaît pas de contexte, et c'est ce
     * qui permet de la tester sur la JVM.
     */
    sealed class EditError(@StringRes val messageRes: Int, val detail: String? = null) {
        data class UnknownPosition(val fen: String) :
            EditError(R.string.repedit_err_unknown_position)

        data class IllegalMove(val move: String) :
            EditError(R.string.repedit_err_illegal, move)

        data class DuplicateMove(val san: String) :
            EditError(R.string.repedit_err_duplicate, san)

        /** Le validateur ou le disque a refusé l'écriture. */
        data class SaveRefused(val reason: String) :
            EditError(R.string.repedit_err_save, reason)
    }

    class EditException(val error: EditError) : Exception(error.toString())

    /** Le résultat d'un coup rejoué : son SAN, et la clé canonique d'arrivée. */
    data class Played(val san: String, val key: String)

    // MARK: Ajout

    /**
     * Ajoute un coup depuis [fen], en créant au besoin la position d'arrivée.
     *
     * Si la position d'arrivée existe déjà (transposition), elle est RÉUTILISÉE
     * telle quelle : c'est tout l'intérêt du graphe, et l'utilisateur retrouve
     * d'un coup ce qu'il a déjà écrit ailleurs.
     */
    fun addMove(uci: String, fen: String, role: String = "sideline", course: Course): Course {
        val key = CourseRepository.fenKey(fen)
        val node = course.positions[key] ?: throw EditException(EditError.UnknownPosition(key))
        val played = play(uci, key) ?: throw EditException(EditError.IllegalMove(uci))
        if (node.any { it.uci == uci }) throw EditException(EditError.DuplicateMove(played.san))

        val positions = HashMap(course.positions)
        positions[key] = node + CourseMove(
            san = played.san, uci = uci, toFEN = played.key, role = role,
            comment = null, eval = null, popularity = null,
        )
        if (played.key !in positions) positions[played.key] = emptyList()
        return course.copy(positions = positions)
    }

    // MARK: Retrait

    /**
     * Retire un coup, puis purge ce qui n'est plus atteignable depuis la
     * racine. Sans effet si le coup n'existe pas — un retrait deux fois
     * demandé n'est pas une erreur.
     */
    fun removeMove(uci: String, fen: String, course: Course): Course {
        val key = CourseRepository.fenKey(fen)
        val node = course.positions[key] ?: return course
        val remaining = node.filterNot { it.uci == uci }
        if (remaining.size == node.size) return course

        var positions = HashMap(course.positions)
        positions[key] = remaining
        positions = reachable(CourseRepository.fenKey(course.rootFEN), positions)
        val kept = positions.keys
        return course.copy(
            positions = positions,
            chapters = cleaned(course.chapters, kept),
            // Les noms de variante d'une position disparue n'ont plus de
            // position à nommer.
            ecoNames = course.ecoNames.filterKeys { it in kept },
        )
    }

    // MARK: Commentaire

    /**
     * Écrit (ou efface, avec un texte vide) le commentaire d'un coup.
     *
     * Le statut passe à `validated` — c'est [CourseJson] qui l'écrit : le
     * texte vient de l'utilisateur lui-même. La règle « jamais de brouillon
     * affiché comme théorie sûre » vise le contenu GÉNÉRÉ, pas ce que
     * l'auteur écrit de sa main.
     *
     * Écart ASSUMÉ avec iOS, qui préserve l'autre langue : le modèle Android
     * ne garde qu'un commentaire par arête (la lecture choisit déjà la langue
     * à l'ouverture du fichier), et le réenregistrement l'écrit dans les deux.
     * Rien n'est perdu — le texte reste lisible dans les deux langues — mais
     * une traduction distincte ne survivrait pas à une modification.
     */
    fun setComment(text: String?, uci: String, fen: String, course: Course): Course {
        val key = CourseRepository.fenKey(fen)
        val node = course.positions[key] ?: return course
        val index = node.indexOfFirst { it.uci == uci }
        if (index < 0) return course

        val trimmed = text?.trim()
        val positions = HashMap(course.positions)
        positions[key] = node.toMutableList().also {
            it[index] = it[index].copy(comment = if (trimmed.isNullOrEmpty()) null else trimmed)
        }
        return course.copy(positions = positions)
    }

    // MARK: Renommage

    fun rename(course: Course, to: String): Course {
        val trimmed = to.trim()
        if (trimmed.isEmpty()) return course
        return course.copy(name = trimmed)
    }

    // MARK: Interne

    /**
     * Rejoue un coup et rend son SAN avec la clé canonique d'arrivée. `null`
     * si le coup est illégal — c'est le seul juge, on ne fait jamais confiance
     * à l'appelant.
     */
    fun play(uci: String, fen: String): Played? {
        if (uci.length < 4) return null
        val position = CourseRepository.position(fen) ?: return null
        val start = Square(uci.substring(0, 2))
        val end = Square(uci.substring(2, 4))

        // Le TRAIT d'abord : `canMove`/`legalMoves` ne le consultent pas (le
        // port garde le comportement de ChessKit). Sans ce garde, déplacer une
        // pièce noire quand les Blancs ont le trait fabriquerait une arête vers
        // une position que personne ne peut atteindre — et le validateur ne
        // verrait rien, puisqu'il rejoue le coup avec la même mécanique
        // permissive.
        val piece = position.piece(start) ?: return null
        if (piece.color != position.sideToMove) return null

        val board = Board(position)
        var move = board.move(start, end) ?: return null
        if (board.state is Board.State.Promotion) {
            // UCI promeut en minuscule (« e7e8q ») ; dame par défaut.
            val kind = when (uci.getOrNull(4)) {
                'r' -> Piece.Kind.rook
                'b' -> Piece.Kind.bishop
                'n' -> Piece.Kind.knight
                else -> Piece.Kind.queen
            }
            move = board.completePromotion(move, kind)
        }
        return Played(move.san, CourseRepository.key(board.position))
    }

    /**
     * Sous-graphe réellement atteignable depuis la racine. La racine est
     * toujours conservée, même devenue une feuille : un répertoire vidé de ses
     * variantes reste un répertoire, et son fichier doit rester valide.
     */
    private fun reachable(
        root: String,
        positions: Map<String, List<CourseMove>>,
    ): HashMap<String, List<CourseMove>> {
        if (root !in positions) return HashMap(positions)
        val keep = hashSetOf(root)
        val queue = ArrayDeque(listOf(root))
        while (queue.isNotEmpty()) {
            val key = queue.removeLast()
            for (edge in positions[key].orEmpty()) {
                val to = CourseRepository.fenKey(edge.toFEN)
                if (keep.add(to)) queue.addLast(to)
            }
        }
        val result = HashMap<String, List<CourseMove>>()
        for ((key, moves) in positions) if (key in keep) result[key] = moves
        return result
    }

    /**
     * Retire des chapitres les positions disparues, puis les chapitres devenus
     * vides — un chapitre pendant fait échouer la validation.
     */
    private fun cleaned(chapters: List<Chapter>, keys: Set<String>): List<Chapter> =
        chapters.mapNotNull { chapter ->
            val fens = chapter.positionFENs.filter { CourseRepository.fenKey(it) in keys }
            if (fens.isEmpty()) null else chapter.copy(positionFENs = fens)
        }
}
