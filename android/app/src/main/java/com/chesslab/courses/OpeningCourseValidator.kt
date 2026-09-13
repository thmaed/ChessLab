package com.chesslab.courses

import chesskit.Board
import chesskit.Piece
import chesskit.Square

/**
 * Vérifie l'INTÉGRITÉ d'un cours en graphe. Pendant d'`OpeningCourseValidator`.
 *
 * PUR (cours → liste de problèmes). La validation des arêtes REJOUE chaque coup
 * et compare la clé canonique obtenue à `toFEN` : c'est le test le plus fort,
 * il valide à la fois la légalité du coup, la cohérence du graphe et la
 * normalisation des clés de bout en bout. Un graphe incohérent ne doit pas
 * pouvoir entrer par la porte utilisateur alors qu'il est interdit par la
 * porte des assets.
 */
object OpeningCourseValidator {

    enum class Kind {
        /** `rootFEN` absent du graphe. */
        rootMissing,
        /** Une clé illisible. */
        invalidFEN,
        /** Une clé qui n'est pas sa propre forme canonique. */
        nonNormalizedFEN,
        /** Une arête vers un nœud inexistant. */
        orphanEdge,
        /** Un coup injouable depuis sa position. */
        illegalMove,
        /** Un coup qui ne mène pas où l'arête le dit. */
        edgeTargetMismatch,
        /** Un chapitre qui cite une position absente. */
        chapterPositionMissing,
    }

    data class Issue(val kind: Kind, val detail: String) {
        override fun toString() = "[$kind] $detail"
    }

    /** Tous les problèmes détectés — vide = graphe sain. */
    fun validate(course: Course): List<Issue> {
        val issues = ArrayList<Issue>()
        val root = CourseRepository.fenKey(course.rootFEN)
        if (root !in course.positions) issues += Issue(Kind.rootMissing, "rootFEN absent : $root")

        for ((key, moves) in course.positions) {
            val position = CourseRepository.position(key)
            if (position == null) { issues += Issue(Kind.invalidFEN, key); continue }
            if (CourseRepository.key(position) != key) issues += Issue(Kind.nonNormalizedFEN, key)
            for (edge in moves) {
                val to = CourseRepository.fenKey(edge.toFEN)
                if (to !in course.positions) issues += Issue(Kind.orphanEdge, "$key --${edge.san}--> $to (cible absente)")
                val landed = resultingKey(edge.uci, key)
                if (landed == null) { issues += Issue(Kind.illegalMove, "${edge.san}/${edge.uci} illégal depuis $key"); continue }
                if (landed != to) issues += Issue(Kind.edgeTargetMismatch, "$key --${edge.uci}--> obtenu $landed, attendu $to")
            }
        }

        for (chapter in course.chapters) {
            for (fen in chapter.positionFENs) {
                if (CourseRepository.fenKey(fen) !in course.positions) {
                    issues += Issue(Kind.chapterPositionMissing, "chapitre « ${chapter.title} » → position absente : $fen")
                }
            }
        }
        return issues
    }

    /**
     * Rejoue un coup UCI depuis une clé FEN et rend la clé CANONIQUE de la
     * position obtenue — `null` si le coup est illégal ou illisible. La
     * promotion suit le 5ᵉ caractère UCI, dame par défaut.
     */
    fun resultingKey(uci: String, fen: String): String? {
        if (uci.length < 4) return null
        val position = CourseRepository.position(fen) ?: return null
        val board = Board(position)
        val move = board.move(Square(uci.substring(0, 2)), Square(uci.substring(2, 4))) ?: return null
        if (board.state is Board.State.Promotion) {
            val kind = when (uci.getOrNull(4)) {
                'r' -> Piece.Kind.rook; 'b' -> Piece.Kind.bishop; 'n' -> Piece.Kind.knight; else -> Piece.Kind.queen
            }
            board.completePromotion(move, kind)
        }
        return CourseRepository.key(board.position)
    }
}
