package com.chesslab.courses

import com.chesslab.analysis.MoveQuality
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Le sidecar Labs, lu sur les VRAIS fichiers, et le juge des coups qui s'en
 * sert. Ce qui est vérifié : que la donnée se lit, qu'elle s'aligne sur les
 * clés du cours (sinon l'écran dirait « aucune donnée » partout, en silence),
 * et que les verdicts de l'index sont bien ceux qu'on veut voir — et pas les
 * autres.
 */
class OpeningStatsTest {

    private val root = File("../../ChessLab/Resources").also {
        require(it.isDirectory) { "ressources introuvables : ${it.absolutePath}" }
    }

    private fun sidecar(id: String) =
        OpeningStatsSidecar.decode(File(root, "openings_stats/$id.stats.json").readText())

    private fun course(id: String) =
        CourseRepository.parse(File(root, "openings/$id.json").readText())

    @Test fun `un sidecar se lit, avec sa profondeur et ses trois lignes au plus`() {
        val s = sidecar("italian-game")
        assertEquals("italian-game", s.id)
        assertNotNull("la profondeur du moteur fait partie de la donnée", s.engineDepth)
        assertTrue(s.positions.size > 30)
        assertTrue("au plus trois lignes par position", s.positions.values.all { it.engine.size <= 3 })
        assertTrue("le moteur couvre toutes les positions", s.positions.values.all { it.engine.isNotEmpty() })
    }

    @Test fun `les cles du sidecar sont celles du cours`() {
        // Sans cet alignement, chaque position dirait « analyse indisponible ».
        for (id in listOf("italian-game", "scandinavian-defense", "sicilian-najdorf")) {
            val c = runCatching { course(id) }.getOrNull() ?: continue
            val s = sidecar(id)
            val hits = c.positions.keys.count { s.data(it) != null }
            assertTrue("$id : $hits positions sur ${c.positions.size} trouvées dans le sidecar",
                hits >= c.positions.size * 0.9)
        }
    }

    @Test fun `la part d'un coup de maitre se rapporte au total de la position`() {
        val stats = OpeningMasterStats(
            whiteWins = 50, draws = 30, blackWins = 20,
            moves = listOf(OpeningMasterMove("e4", "e2e4", 60, 30, 20, 10, null, null, null)),
        )
        assertEquals(100, stats.totalGames)
        assertEquals(0.6, stats.share(stats.moves[0]), 1e-9)
        assertEquals((30 + 10.0) / 60, stats.moves[0].whiteScore!!, 1e-9)
    }

    @Test fun `un sidecar absent donne une donnee vide, pas une panne`() {
        val empty = OpeningStatsSidecar.empty("nulle-part")
        assertTrue(empty.positions.isEmpty())
        assertEquals(null, empty.data("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -"))
    }

    @Test fun `l'index ne montre que les verdicts qui meritent de l'etre`() {
        val c = course("italian-game")
        val root = OpeningLineTree.build(c, sidecar("italian-game"))!!
        val qualities = root.flattened.flatMap { it.moves }.mapNotNull { it.quality }
        assertTrue("un cours qui montre des pièges doit porter des verdicts", qualities.isNotEmpty())
        assertTrue("seules les cinq catégories affichables ont leur place",
            qualities.all { it in OpeningMoveQuality.displayed })
        assertTrue("jamais « théorie » : dans un cours d'ouverture, tout en est",
            qualities.none { it == MoveQuality.book })
    }

    @Test fun `un coup sans donnee moteur n'a pas de verdict`() {
        val context = OpeningMoveQuality.Context(
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -",
            "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq -", "e2e4", null,
        )
        assertEquals(null, OpeningMoveQuality.classify(context, OpeningStatsSidecar.empty("x")))
    }
}
