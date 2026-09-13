package com.chesslab.courses

import chesskit.Piece
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Les VRAIS fichiers de cours, pas une FEN inventée pour le test.
 *
 * Ce qui est prouvé ici : la racine d'un cours s'ouvre bien sur SA position.
 * Le défaut corrigé le 12/09 était silencieux et total — les fichiers portent
 * des FEN à quatre champs, `FenParser` en exige six, et le repli
 * `?: Position.standard` rendait la position de départ. Comme les 59
 * ouvertures partent justement du début, personne ne voyait rien : seules les
 * 78 FINALES s'ouvraient sur un échiquier complet, où il n'y a rien à
 * apprendre. D'où un test sur le corpus entier, et pas sur un cas choisi.
 */
class CourseFenTest {

    /** Les cours vivent chez iOS et sont recopiés dans les assets au build. */
    private val dir = File("../../ChessLab/Resources/openings").also {
        require(it.isDirectory) { "cours introuvables : ${it.absolutePath}" }
    }

    private fun courses(): List<JSONObject> =
        dir.listFiles { f -> f.name.endsWith(".json") && f.name != "opening_catalog.json" }!!
            .sortedBy { it.name }
            .map { JSONObject(it.readText()) }

    @Test fun `la racine de chaque cours s'ouvre sur sa propre position`() {
        var finales = 0
        for (course in courses()) {
            val root = course.getString("rootFEN")
            val position = CourseRepository.position(root)
            assertNotNull("racine illisible dans ${course.getString("id")} : $root", position)
            // La preuve est le placement : c'est le champ que la FEN décrit et
            // que la position doit restituer, champ par champ.
            assertEquals(
                "racine mal relue dans ${course.getString("id")}",
                root.split(" ").first(),
                position!!.fen.split(" ").first(),
            )
            if (course.optString("kind") == "endgame") {
                finales++
                assertTrue(
                    "la finale ${course.getString("id")} s'ouvre sur la position de départ",
                    position.pieces.size < 32,
                )
            }
        }
        assertTrue("le corpus devrait porter des dizaines de finales", finales >= 70)
    }

    @Test fun `toute position de cours est lisible`() {
        // Les clés du graphe sont, elles aussi, des FEN à quatre champs : le
        // lecteur les reparse à chaque descente.
        var positions = 0
        for (course in courses()) {
            val all = course.optJSONObject("positions") ?: continue
            for (key in all.keys()) {
                assertNotNull("position illisible : $key", CourseRepository.position(key))
                positions++
            }
        }
        assertTrue("le corpus devrait porter des milliers de positions", positions > 1_000)
    }

    @Test fun `les compteurs manquants sont completes, pas exiges`() {
        val placement = "8/8/8/8/B6n/7p/6k1/4K3"
        val quatre = CourseRepository.position("$placement w - -")
        val cinq = CourseRepository.position("$placement w - - 0")
        val six = CourseRepository.position("$placement w - - 0 1")
        // La raison d'être du complément : le parseur brut REFUSE les quatre
        // champs. Si cette ligne tombe un jour, c'est que `FenParser` s'est
        // assoupli — et que ce complément peut disparaître.
        assertNull(chesskit.FenParser.parse("$placement w - -"))
        assertNotNull(quatre); assertNotNull(cinq); assertNotNull(six)
        assertEquals(six!!.fen, quatre!!.fen)
        assertEquals(six.fen, cinq!!.fen)
        assertEquals(Piece.Color.white, quatre.sideToMove)
    }

    @Test fun `une chaine qui ne decrit pas une position est refusee`() {
        // Le parseur est très permissif : six jetons quelconques lui font un
        // échiquier vide sans broncher. On exige les deux rois.
        assertNull(CourseRepository.position("nawak nawak nawak nawak"))
        assertNull(CourseRepository.position("8/8/8/8/8/8/8/4K3 w - -"))   // roi noir absent
        assertNull(CourseRepository.position("4k3/8/8/8/8/8/8/8 w - -"))   // roi blanc absent
        assertNotNull(CourseRepository.position("4k3/8/8/8/8/8/8/4K3 w - -"))
    }

    // MARK: La clé canonique

    private fun play(vararg moves: Pair<String, String>): chesskit.Board {
        val board = chesskit.Board(chesskit.Position.standard)
        for ((from, to) in moves) requireNotNull(board.move(chesskit.Square(from), chesskit.Square(to))) { "$from$to illégal" }
        return board
    }

    @Test fun `la position de depart a la cle attendue`() {
        assertEquals("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -", CourseRepository.key(chesskit.Position.standard))
    }

    @Test fun `deux ordres de coups vers la meme position donnent la meme cle`() {
        // 1.Cf3 d5 2.d4 et 1.d4 d5 2.Cf3 : mêmes pièces, compteurs différents
        // — et une case e.p. « d3 » d'un côté seulement. Les FEN diffèrent, les
        // clés doivent coïncider : c'est ce qui fait fusionner les transpositions.
        val a = play("g1" to "f3", "d7" to "d5", "d2" to "d4")
        val b = play("d2" to "d4", "d7" to "d5", "g1" to "f3")
        assertTrue(a.position.fen != b.position.fen)
        assertEquals(CourseRepository.key(a.position), CourseRepository.key(b.position))
    }

    @Test fun `la case en passant est gardee quand la prise est legale`() {
        // 1.e4 c5 2.e5 d5 : le pion e5 peut prendre exd6 e.p.
        val board = play("e2" to "e4", "c7" to "c5", "e4" to "e5", "d7" to "d5")
        assertTrue(CourseRepository.key(board.position).endsWith(" d6"))
    }

    @Test fun `la case en passant est retiree sans preneur`() {
        // Après 1.e4, ChessKit émet « e3 » — aucun pion noir ne peut y prendre.
        val key = CourseRepository.key(play("e2" to "e4").position)
        assertTrue(!key.contains("e3"))
        assertTrue(key.endsWith(" -"))
    }

    @Test fun `un droit de roque tombe avec la tour capturee sur sa case`() {
        // Gambit dame accepté, juste avant Txa8 : les Blancs perdent « Q »
        // (leur tour a1 est partie) et les Noirs « q » (la tour a8 est prise).
        val position = CourseRepository.position("rn1qkbnr/1bp1pppp/8/1p6/2pP4/4PN2/1P3PPP/RNBQKB1R w KQkq -")!!
        val board = chesskit.Board(position)
        requireNotNull(board.move(chesskit.Square("a1"), chesskit.Square("a8")))
        assertEquals("Rn1qkbnr/1bp1pppp/8/1p6/2pP4/4PN2/1P3PPP/1NBQKB1R b Kk -", CourseRepository.key(board.position))
    }
}
