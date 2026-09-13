package com.chesslab.courses

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import chesskit.Board
import chesskit.Piece
import chesskit.Position
import chesskit.Square

/**
 * L'état de l'éditeur d'arbre : où l'on se trouve dans le répertoire, et ce
 * que l'on y modifie. Pendant d'`OpeningEditorViewModel.swift`.
 *
 * Toute la logique de graphe vit dans [OpeningCourseEditor] (pure, testée) ;
 * cet état ne fait que trois choses : tenir la position courante, traduire les
 * gestes du plateau en coups, et enregistrer.
 *
 * **L'enregistrement est immédiat.** Pas de bouton « Enregistrer », pas d'état
 * « modifié non sauvé » : chaque geste part sur le disque, et si l'écriture
 * échoue l'utilisateur le voit tout de suite plutôt qu'en quittant l'écran.
 * Le fichier EST le répertoire — c'est déjà ce que fait l'import.
 */
class OpeningEditorState(initial: Course) {

    /** Un pas du fil : le coup joué, et la position où il mène. */
    data class Step(val san: String, val key: String)

    var course by mutableStateOf(initial)
        private set
    var position by mutableStateOf(CourseRepository.position(initial.rootFEN) ?: Position.standard)
        private set
    var currentKey by mutableStateOf(CourseRepository.fenKey(initial.rootFEN))
        private set

    /** Coups joués depuis la racine, pour le fil et le retour arrière. */
    var trail by mutableStateOf<List<Step>>(emptyList())
        private set
    var lastMove by mutableStateOf<Pair<Square, Square>?>(null)
        private set

    /** Case sélectionnée au premier tap (le second tap joue le coup). */
    var selected by mutableStateOf<Square?>(null)
        private set
    var legalTargets by mutableStateOf<Set<Square>>(emptySet())
        private set

    /** Ce qui a refusé la dernière modification — coup illégal, doublon, écriture. */
    var error by mutableStateOf<OpeningCourseEditor.EditError?>(null)

    // MARK: Lecture

    val moves: List<CourseMove> get() = course.moves(currentKey)
    val isAtRoot: Boolean get() = trail.isEmpty()

    /** Nombre de positions — l'indicateur de taille que voit l'utilisateur. */
    val positionCount: Int get() = course.positions.size

    /** Le camp que l'on joue : c'est lui qui donne le sens du plateau. */
    val orientation: Piece.Color
        get() = if (course.side == "black") Piece.Color.black else Piece.Color.white

    /**
     * Coup que « Suivant » jouerait : la LIGNE PRINCIPALE si elle est marquée,
     * sinon le premier coup écrit. Dans un arbre, « suivant » est ambigu dès
     * qu'il y a une bifurcation ; on suit la ligne principale et la liste
     * reste là pour choisir une autre branche.
     */
    val nextEdge: CourseMove? get() = moves.firstOrNull { it.isMainLine } ?: moves.firstOrNull()

    fun dismissError() { error = null }

    // MARK: Navigation

    fun enter(edge: CourseMove) {
        val played = playOnBoard(edge.uci, position) ?: return
        position = played.first
        lastMove = played.second
        val key = CourseRepository.fenKey(edge.toFEN)
        trail = trail + Step(edge.san, key)
        currentKey = key
        clearSelection()
    }

    fun forward() { nextEdge?.let { enter(it) } }

    fun back() {
        if (trail.isEmpty()) return
        trail = trail.dropLast(1)
        rebuild()
    }

    fun jump(ply: Int) {
        if (ply < 0 || ply > trail.size) return
        trail = trail.take(ply)
        rebuild()
    }

    // MARK: Gestes du plateau

    fun tap(square: Square) {
        val current = selected
        if (current != null) {
            when {
                current == square -> clearSelection()
                square in legalTargets -> addMove(current, square)
                else -> select(square)
            }
            return
        }
        select(square)
    }

    private fun select(square: Square) {
        val piece = position.piece(square)
        if (piece == null || piece.color != position.sideToMove) {
            clearSelection()
            return
        }
        selected = square
        legalTargets = Board(position.copy()).legalMoves(square).toSet()
    }

    private fun clearSelection() {
        selected = null
        legalTargets = emptySet()
    }

    // MARK: Modifications

    /**
     * Ajoute le coup au répertoire PUIS y entre — l'utilisateur continue sa
     * ligne sans avoir à retaper le coup qu'il vient de créer.
     *
     * La promotion est toujours une DAME : proposer les quatre pièces dans un
     * éditeur de répertoire compliquerait l'écran pour un cas qui, en
     * ouverture, n'arrive quasiment jamais. La sous-promotion reste possible
     * en important un PGN.
     */
    fun addMove(from: Square, to: Square) {
        // Le trait est vérifié ici ET dans `OpeningCourseEditor.play` : le port
        // de ChessKit ne le consulte pas, et un glissement échappe au filtre de
        // `select`.
        val piece = position.piece(from)
        if (piece == null || piece.color != position.sideToMove || !Board(position.copy()).canMove(from, to)) {
            clearSelection()
            return
        }
        clearSelection()
        val uci = uciString(from, to)

        // Le coup existe déjà : on y entre au lieu de refuser. C'est ce qu'un
        // utilisateur attend en rejouant une ligne qu'il a déjà écrite.
        moves.firstOrNull { it.uci == uci }?.let { enter(it); return }

        val key = currentKey
        if (apply { OpeningCourseEditor.addMove(uci, key, course = it) }) {
            course.moves(key).firstOrNull { it.uci == uci }?.let { enter(it) }
        }
    }

    fun delete(edge: CourseMove) {
        val key = currentKey
        if (apply { OpeningCourseEditor.removeMove(edge.uci, key, it) }) rebuild()
    }

    fun setComment(text: String?, edge: CourseMove) {
        val key = currentKey
        apply { OpeningCourseEditor.setComment(text, edge.uci, key, it) }
    }

    fun rename(name: String) {
        apply { OpeningCourseEditor.rename(it, name) }
    }

    // MARK: Interne

    /**
     * Applique une transformation, enregistre, et ne garde le résultat QUE si
     * l'écriture a réussi. En cas d'échec le cours en mémoire reste celui du
     * disque : jamais d'écran qui montre des modifications que le fichier
     * ignore.
     */
    private fun apply(transform: (Course) -> Course): Boolean = try {
        val updated = transform(course)
        UserOpeningStore.save(updated)
        course = updated
        error = null
        true
    } catch (e: OpeningCourseEditor.EditException) {
        error = e.error
        false
    } catch (e: UserOpeningStore.StoreException) {
        error = OpeningCourseEditor.EditError.SaveRefused(
            e.issues.firstOrNull() ?: e.message ?: ""
        )
        false
    }

    /** Rejoue un coup sur une position et rend la suivante, avec ses deux cases. */
    private fun playOnBoard(uci: String, from: Position): Pair<Position, Pair<Square, Square>>? {
        if (uci.length < 4) return null
        val start = Square(uci.substring(0, 2))
        val end = Square(uci.substring(2, 4))
        val board = Board(from.copy())
        val move = board.move(start, end) ?: return null
        if (board.state is Board.State.Promotion) {
            val kind = when (uci.getOrNull(4)) {
                'r' -> Piece.Kind.rook
                'b' -> Piece.Kind.bishop
                'n' -> Piece.Kind.knight
                else -> Piece.Kind.queen
            }
            board.completePromotion(move, kind)
        }
        return board.position.copy() to (start to end)
    }

    /**
     * Rejoue le fil depuis la racine. Plus simple et plus sûr qu'un « défaire »
     * sur le plateau, et le fil est court par nature.
     *
     * Le fil est TRONQUÉ à ce qui a pu être rejoué : une variante supprimée
     * sous nos pieds laisserait sinon un fil qui ne mène plus où il prétend.
     */
    private fun rebuild() {
        var pos = CourseRepository.position(course.rootFEN) ?: Position.standard
        var key = CourseRepository.fenKey(course.rootFEN)
        var last: Pair<Square, Square>? = null
        var walked = 0
        for (step in trail) {
            val edge = course.moves(key).firstOrNull { CourseRepository.fenKey(it.toFEN) == step.key } ?: break
            val played = playOnBoard(edge.uci, pos) ?: break
            pos = played.first
            last = played.second
            key = step.key
            walked++
        }
        if (walked < trail.size) trail = trail.take(walked)
        position = pos
        currentKey = key
        lastMove = last
        clearSelection()
    }

    /**
     * La promotion est forcée en dame (voir [addMove]) : le 5e caractère n'est
     * requis que pour le couple pion + dernière rangée, seul cas où le coup en
     * est une.
     */
    private fun uciString(from: Square, to: Square): String {
        val piece = position.piece(from)
        val isPromotion = piece?.kind == Piece.Kind.pawn && (to.rank.value == 1 || to.rank.value == 8)
        return from.notation + to.notation + if (isPromotion) "q" else ""
    }
}
