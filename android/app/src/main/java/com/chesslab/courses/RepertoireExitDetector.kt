package com.chesslab.courses

import android.content.Context
import chesskit.Move
import chesskit.Piece
import chesskit.Position
import com.chesslab.library.LibraryDatabase

/** Le premier coup où le joueur QUITTE son répertoire dans une partie (A3). */
data class RepertoireExit(
    val courseId: String,
    val courseName: String,
    /** Clé FEN de la position AVANT le coup — celle qui rejoint les révisions. */
    val fenKey: String,
    /** Rang du demi-coup (0 = premier coup des Blancs). */
    val ply: Int,
    val playedSan: String,
    val playedUci: String,
    /** Le coup du répertoire (ligne principale du cours, comme l'entraînement). */
    val expectedSan: String,
    val expectedUci: String,
) {
    val moveNumber: Int get() = ply / 2 + 1
}

/**
 * Un cours que le joueur suit, et jusqu'où. [followsAll] : un répertoire
 * personnel, toute sa théorie compte. Faux pour un cours livré simplement
 * ÉTUDIÉ : seules comptent les positions réellement travaillées, sinon jouer
 * 1.d4 une fois « quitterait » l'Italienne révisée trois fois.
 */
data class FollowedCourse(val course: Course, val followsAll: Boolean)

/**
 * Compare une partie aux répertoires que le joueur suit. Pendant de
 * `RepertoireExitDetector.swift`.
 *
 * Trois cas, tranchés :
 * - le joueur joue un coup du répertoire → on continue ;
 * - il en joue un autre alors que la position est dans un cours de son camp →
 *   SORTIE, la seule chose que le module signale (la première de la partie) ;
 * - la position n'est dans AUCUN cours (l'adversaire a quitté la théorie le
 *   premier, ou la ligne s'arrête) → on s'arrête SANS rien signaler : ce n'est
 *   pas une faute du joueur.
 *
 * Un coup que le cours note `inaccuracy` ou `refutation` ne compte pas comme
 * « dans le répertoire » : le jouer, c'est tomber dans un piège connu.
 *
 * Android n'a pas de marquage « mon répertoire » (l'étoile d'iOS n'est plus
 * offerte nulle part) : les répertoires suivis sont les personnels et les
 * cours livrés étudiés.
 */
object RepertoireExitDetector {

    /** [positions] a une entrée de plus que [moves] : `positions[i]` précède `moves[i]`. */
    fun firstExit(
        positions: List<Position>,
        moves: List<Move>,
        userColor: Piece.Color,
        courses: List<FollowedCourse>,
        studied: Set<String>,
    ): RepertoireExit? {
        val side = if (userColor == Piece.Color.white) "white" else "black"
        val own = courses.filter { it.course.side == side }
        if (own.isEmpty()) return null

        for ((ply, move) in moves.withIndex()) {
            val position = positions.getOrNull(ply) ?: return null
            if (position.sideToMove != userColor) continue
            val key = CourseRepository.key(position)
            val known = own.mapNotNull { followed ->
                val edges = followed.course.moves(key)
                if (edges.isEmpty() || !(followed.followsAll || key in studied)) null
                else followed.course to edges
            }
            // Hors théorie : l'adversaire a dévié le premier (ou fin de ligne).
            if (known.isEmpty()) return null
            val played = move.lan
            val inRepertoire = known.any { (_, edges) ->
                edges.any { it.uci == played && it.role != "inaccuracy" && it.role != "refutation" }
            }
            if (!inRepertoire) {
                val (course, edges) = known[0]
                val expected = edges.firstOrNull { it.isMainLine } ?: edges[0]
                return RepertoireExit(
                    courseId = course.id, courseName = course.name, fenKey = key, ply = ply,
                    playedSan = move.san, playedUci = played,
                    expectedSan = expected.san, expectedUci = expected.uci,
                )
            }
        }
        return null
    }

    /**
     * Les cours suivis par le joueur de couleur [color], et les positions qu'il
     * a travaillées :
     * - répertoires personnels : tout compte ;
     * - cours livrés dont il a révisé au moins une position : seules comptent
     *   les positions révisées.
     */
    suspend fun followedCourses(context: Context, color: Piece.Color): Pair<List<FollowedCourse>, Set<String>> {
        val assets = context.assets
        val studied = LibraryDatabase.get(context).training().allProgress()
            .filter { it.reps > 0 }.map { it.fenKey }.toSet()
        val side = if (color == Piece.Color.white) "white" else "black"
        val result = ArrayList<FollowedCourse>()
        val personal = UserOpeningStore.catalog().map { it.id }.toSet()
        for (id in personal) {
            CourseRepository.course(assets, id)?.let { result += FollowedCourse(it, followsAll = true) }
        }
        if (studied.isEmpty()) return result to studied
        for (entry in CourseRepository.catalog(assets)) {
            if (entry.isEndgame || entry.side != side || entry.id in personal) continue
            val course = CourseRepository.course(assets, entry.id) ?: continue
            if (course.positions.keys.any { it in studied }) result += FollowedCourse(course, followsAll = false)
        }
        return result to studied
    }
}
