package com.chesslab.courses

import chesskit.Board
import chesskit.Move
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/** A3 — la sortie de répertoire : seule la première déviation DU JOUEUR compte. Pendant de `RepertoireExitDetectorTests.swift`. */
class RepertoireExitDetectorTest {

    /** Rejoue des coups « e2e4 » depuis le départ : les positions (une de plus que de coups) et les coups. */
    private fun line(vararg ucis: String): Pair<List<Position>, List<Move>> {
        val board = Board(Position.standard.copy())
        val positions = arrayListOf(board.position.copy())
        val moves = ArrayList<Move>()
        for (uci in ucis) {
            val made = checkNotNull(board.move(Square(uci.substring(0, 2)), Square(uci.substring(2, 4)))) { "coup illégal $uci" }
            moves += made
            positions += board.position.copy()
        }
        return positions to moves
    }

    private fun key(vararg ucis: String): String = CourseRepository.key(line(*ucis).first.last())

    /** Un répertoire blanc minimal : 1.e4 e5 2.Nf3 (principale), 2.Bc4 (variante), 2.Qh5 (réfutation). */
    private fun whiteCourse(): Course {
        val root = key()
        val afterE4 = key("e2e4")
        val afterE4E5 = key("e2e4", "e7e5")
        fun edge(san: String, uci: String, role: String) = CourseMove(san, uci, "", role, null, null, null)
        return Course(
            id = "test-ouverture-blanche", name = "Ouverture test", summary = "", side = "white", rootFEN = root,
            chapters = emptyList(),
            positions = mapOf(
                root to listOf(edge("e4", "e2e4", "mainLine")),
                afterE4 to listOf(edge("e5", "e7e5", "mainLine")),
                afterE4E5 to listOf(
                    edge("Nf3", "g1f3", "mainLine"),
                    edge("Bc4", "f1c4", "sideline"),
                    edge("Qh5", "d1h5", "refutation"),
                ),
            ),
        )
    }

    private fun exit(
        vararg ucis: String,
        color: Piece.Color = Piece.Color.white,
        courses: List<FollowedCourse> = listOf(FollowedCourse(whiteCourse(), followsAll = true)),
        studied: Set<String> = emptySet(),
    ): RepertoireExit? {
        val (positions, moves) = line(*ucis)
        return RepertoireExitDetector.firstExit(positions, moves, color, courses, studied)
    }

    @Test fun `suivre le repertoire n'est pas une sortie`() {
        assertNull(exit("e2e4", "e7e5", "g1f3", "b8c6"))
        assertNull(exit("e2e4", "e7e5", "f1c4", "g8f6"))
    }

    @Test fun `quitter le repertoire est signale avec le coup attendu`() {
        val found = exit("e2e4", "e7e5", "b1c3", "g8f6")
        assertNotNull(found)
        assertEquals(2, found!!.ply)
        assertEquals(2, found.moveNumber)
        assertEquals("Nc3", found.playedSan)
        assertEquals("Nf3", found.expectedSan)
        assertEquals("g1f3", found.expectedUci)
    }

    @Test fun `le premier coup peut deja etre une sortie`() {
        val found = exit("d2d4", "d7d5")
        assertEquals(0, found!!.ply)
        assertEquals("e4", found.expectedSan)
    }

    @Test fun `quand l'adversaire quitte la theorie le premier ce n'est pas une faute du joueur`() {
        assertNull(exit("e2e4", "c7c5", "g1f3", "d7d6"))
    }

    @Test fun `un coup note refutation compte comme une sortie`() {
        assertEquals("Qh5", exit("e2e4", "e7e5", "d1h5", "b8c6")!!.playedSan)
    }

    @Test fun `un cours de l'autre camp ou aucun cours ne signale rien`() {
        assertNull(exit("d2d4", "d7d5", color = Piece.Color.black))
        assertNull(exit("d2d4", "d7d5", courses = emptyList()))
    }

    @Test fun `un cours simplement etudie ne compte que sur les positions travaillees`() {
        val course = whiteCourse()
        val studiedOnly = listOf(FollowedCourse(course, followsAll = false))
        assertNull(exit("d2d4", "d7d5", courses = studiedOnly))
        val found = exit("d2d4", "d7d5", courses = studiedOnly, studied = setOf(course.positions.keys.first { it == key() }))
        assertEquals("e4", found!!.expectedSan)
        assertNull(exit("e2e4", "e7e5", "b1c3", "g8f6", courses = studiedOnly, studied = setOf(key())))
    }

    @Test fun `seule la premiere sortie est rendue`() {
        assertEquals(0, exit("d2d4", "e7e5", "e2e4", "d7d5")!!.ply)
    }
}
