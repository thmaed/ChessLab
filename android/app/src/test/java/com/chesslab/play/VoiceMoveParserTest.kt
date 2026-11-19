package com.chesslab.play

import chesskit.Board
import chesskit.Position
import chesskit.Square
import com.chesslab.play.VoiceMoveParser.Candidate
import com.chesslab.play.VoiceMoveParser.Outcome
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Coups à la voix (19/11/2026). Pendant de `VoiceMoveParserTests` + `VoiceMoveRealTrialsTests` (iOS). */
class VoiceMoveParserTest {

    private fun candidates(fen: String? = null, after: List<String> = emptyList()): List<Candidate> {
        val board = Board(fen?.let { Position.fromFen(it) } ?: Position.standard)
        for (lan in after) board.move(pieceAt = Square(lan.take(2)), to = Square(lan.takeLast(2)))
        return VoiceMoveParser.candidates(board)
    }

    private fun uci(text: String, legal: List<Candidate>): String? =
        (VoiceMoveParser.resolve(listOf(text), legal) as? Outcome.Move)?.move?.uci

    @Test fun `la position initiale a vingt coups`() {
        assertEquals(20, candidates().size)
    }

    @Test fun `coups depuis la position initiale`() {
        val cases = listOf(
            "e4" to "e2e4", "E4" to "e2e4", "pion e4" to "e2e4", "Pion en e 4" to "e2e4", "euh 4" to "e2e4",
            "Cavalier f3" to "g1f3", "cavalier en F3." to "g1f3", "Cavalier effe trois" to "g1f3", "Cf3" to "g1f3",
            "c'est 4" to "c2c4", "dé 4" to "d2d4", "Cavalier c3" to "b1c3", "f3" to "f2f3",
        )
        val legal = candidates()
        for ((text, expected) in cases) assertEquals("« $text »", expected, uci(text, legal))
    }

    @Test fun `un coup qu'aucune pièce ne peut faire est impossible`() {
        assertEquals(Outcome.Illegal, VoiceMoveParser.resolve(listOf("fou c4"), candidates()))
        assertEquals(Outcome.NotUnderstood, VoiceMoveParser.resolve(listOf("bonjour"), candidates()))
    }

    @Test fun `les roques`() {
        val italian = candidates(after = listOf("e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5"))
        assertEquals("e1g1", uci("petit roque", italian))
        assertEquals(Outcome.Illegal, VoiceMoveParser.resolve(listOf("grand roque"), italian))
        assertEquals("e1g1", uci("roque", italian))
    }

    @Test fun `deux cavaliers pour une case demandent lequel`() {
        val legal = candidates("4k3/8/8/8/8/5N2/8/1N2K3 w - - 0 1")
        val outcome = VoiceMoveParser.resolve(listOf("cavalier d2"), legal)
        assertTrue(outcome is Outcome.Ambiguous)
        assertEquals(setOf("b1d2", "f3d2"), (outcome as Outcome.Ambiguous).moves.map { it.uci }.toSet())
        assertEquals("b1d2", uci("cavalier b d2", legal))
        assertEquals("f3d2", uci("cavalier f3 d2", legal))
    }

    @Test fun `promotion en dame sauf si une autre pièce est nommée`() {
        val legal = candidates("8/P7/8/8/8/8/8/k6K w - - 0 1")
        assertEquals("a7a8q", uci("a8", legal))
        assertEquals("a7a8q", uci("a8 dame", legal))
        assertEquals("a7a8n", uci("a8 cavalier", legal))
        assertEquals("a7a8r", uci("pion a8 promotion tour", legal))
    }

    @Test fun `une lettre qui rime est rattrapée quand un seul coup convient`() {
        val legal = candidates("4k3/8/8/8/8/8/3P4/4K3 w - - 0 1")
        assertEquals("d2d4", uci("bé 4", legal))
        assertEquals(Outcome.Illegal, VoiceMoveParser.resolve(listOf("bé 4"), legal, confusions = false))
    }

    @Test fun `les formes dites couvrent l'usage`() {
        val forms = VoiceMoveParser.spokenForms(candidates())
        assertTrue("cavalier f3" in forms)
        assertTrue("pion en e4" in forms)
        assertTrue("e4" in forms)
    }

    /**
     * Les 51 essais RÉELS du 19/11/2026 sur iPhone3, rejoués : Android doit donner EXACTEMENT les mêmes chiffres
     * qu'iOS (48/48/47/48/47 justes, 49 avec au moins une) — la preuve que le portage est fidèle.
     */
    @Test fun `rejeu des essais réels de l'iPhone`() {
        val text = javaClass.classLoader!!.getResource("voice/trials-2026-11-19-iphone3.jsonl")!!.readText()
        val trials = text.lines().filter { it.isNotBlank() }.map { JSONObject(it) }
        assertEquals(51, trials.size)
        val right = HashMap<String, Int>()
        var anyRight = 0
        for (trial in trials) {
            fun candidate(o: JSONObject) = Candidate(o.getString("uci"), o.getString("san"))
            val target = candidate(trial.getJSONObject("target"))
            val legal = trial.getJSONArray("candidates").let { a -> (0 until a.length()).map { candidate(a.getJSONObject(it)) } }
            var found = false
            val results = trial.getJSONArray("results")
            for (i in 0 until results.length()) {
                val result = results.getJSONObject(i)
                val transcripts = result.getJSONArray("transcripts").let { a -> (0 until a.length()).map { a.getString(it) } }
                val outcome = VoiceMoveParser.resolve(transcripts, legal)
                if (outcome is Outcome.Move && outcome.move == target) {
                    right.merge(result.getString("engine"), 1, Int::plus)
                    found = true
                }
            }
            if (found) anyRight++
        }
        assertEquals(
            mapOf("A classique" to 48, "B indices" to 48, "C vocabulaire" to 47, "D iOS 26" to 48, "E iOS 26 + vocab." to 47),
            right.toMap(),
        )
        assertEquals(49, anyRight)
    }
}
