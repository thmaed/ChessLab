package com.chesslab.play

import chesskit.Board
import chesskit.Position
import com.chesslab.play.VoiceMoves.Decision
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * COUPS À LA VOIX dans une partie (19/11/2026) : ce que la partie fait de ce que le micro a entendu. Pendant de
 * `VoiceMovesGameTests` (iOS) pour la DÉCISION ; le modèle de partie, lui, se vérifie sur l'appareil.
 */
class VoiceMovesTest {
    private val french = VoiceMoveParser.french

    private fun decide(
        text: String,
        fen: String? = null,
        vocabulary: VoiceMoveParser.Vocabulary = french,
        listening: Boolean = true,
        canTakeback: Boolean = true,
        canAct: Boolean = true,
    ): Decision {
        val board = Board(fen?.let { Position.fromFen(it) } ?: Position.standard)
        return VoiceMoves.decide(listOf(text), vocabulary, listening, canTakeback, canAct) {
            VoiceMoveParser.candidates(board)
        }
    }

    private fun played(decision: Decision): String? = (decision as? Decision.Play)?.move?.san

    @Test fun `le coup compris est joué tout de suite`() {
        assertEquals("Nf3", played(decide("Cavalier F3")))
    }

    @Test fun `un coup impossible se dit et ne se joue pas`() {
        assertEquals(Decision.Illegal, decide("fou c4"))
    }

    @Test fun `une phrase incomprise se dit`() {
        // Un mot d'échecs, mais pas de coup : « cavalier » seul.
        assertEquals(Decision.NotUnderstood, decide("cavalier"))
    }

    @Test fun `deux pièces pour une case demandent laquelle, sans dire où elles sont`() {
        assertEquals(Decision.Ambiguous, decide("cavalier d2", fen = "4k3/8/8/8/8/5N2/8/1N2K3 w - - 0 1"))
    }

    @Test fun `une conversation est ignorée`() {
        assertEquals(Decision.Ignored, decide("tu veux un café ?"))
    }

    @Test fun `annule reprend, sauf quand on ne peut pas`() {
        assertEquals(Decision.Undo, decide("annule"))
        assertEquals("avec une pendule, on ne reprend pas", Decision.CannotUndo, decide("annule", canTakeback = false))
    }

    @Test fun `la promotion se complète avec la pièce dite`() {
        val fen = "8/P7/8/8/8/8/8/k6K w - - 0 1"
        assertEquals("a7a8n", (decide("a8 cavalier", fen = fen) as Decision.Play).move.uci)
        assertEquals("a7a8q", (decide("a8", fen = fen) as Decision.Play).move.uci)
    }

    private fun decisive(text: String, fen: String? = null, listening: Boolean = true): Boolean {
        val board = Board(fen?.let { Position.fromFen(it) } ?: Position.standard)
        return VoiceMoves.isDecisive(listOf(text), french, listening, canAct = true) { VoiceMoveParser.candidates(board) }
    }

    /** L'essai anticipé (20/11/2026) ne joue que ce qui est déjà un coup sûr ; le reste attend la fin de la phrase. */
    @Test fun `seul un coup sûr se joue avant la fin de la phrase`() {
        assertTrue(decisive("cavalier f3"))
        assertEquals("une moitié de phrase attend la suite", false, decisive("cavalier"))
        assertEquals(false, decisive("fou c4"))
        assertEquals(false, decisive("tu veux un café ?"))
        assertEquals(false, decisive("annule"))
        assertEquals(false, decisive("cavalier d2", fen = "4k3/8/8/8/8/5N2/8/1N2K3 w - - 0 1"))
        assertEquals("a8 coupé avant cavalier deviendrait une dame", false,
            decisive("a8", fen = "8/P7/8/8/8/8/8/k6K w - - 0 1"))
        assertEquals(false, decisive("a8 cavalier", fen = "8/P7/8/8/8/8/8/k6K w - - 0 1"))
        assertEquals(false, decisive("cavalier f3", listening = false))
    }

    @Test fun `les autres langues jouent aussi`() {
        assertEquals("Nf3", played(decide("knight f3", vocabulary = VoiceMoveParser.english)))
        assertEquals("Nf3", played(decide("Springer f3", vocabulary = VoiceMoveParser.german)))
    }

    @Test fun `quand ce n'est pas à moi, une phrase en retard ne joue rien`() {
        assertEquals(Decision.Ignored, decide("cavalier f6", canAct = false))
    }

    @Test fun `micro coupé ou réglage éteint, rien ne se joue, pas même annule`() {
        assertEquals(Decision.Ignored, decide("e4", listening = false))
        assertEquals(Decision.Ignored, decide("annule", listening = false))
    }

    @Test fun `le réglage et l'interrupteur se retrouvent dans les réglages enregistrés`() {
        assertTrue(PlayGameSettings(voiceMoves = true).voiceMoves)
        assertEquals(false, PlayGameSettings().voiceMoves)
    }

    /** iPhone 11 / pendant Android (21/11/2026) : « e3 » entendu `["A3", "E3"]` ne joue plus a3, on demande. */
    @Test fun `quand la reconnaissance hesite on demande et la reponse joue`() {
        val board = Board(Position.standard)
        val legal = { VoiceMoveParser.candidates(board) }
        val asked = VoiceMoves.decide(listOf("A3", "E3"), french, true, true, true, candidates = legal)
        assertTrue(asked is Decision.Conflicting)
        val pair = (asked as Decision.Conflicting).moves
        assertEquals(listOf("a3", "e3"), pair.map { it.san })
        val answer = VoiceMoves.decide(
            listOf("le deuxième"), french, true, true, true, pendingChoice = pair, language = "fr", candidates = legal,
        )
        assertEquals("e3", played(answer))
        assertTrue(
            "la réponse se joue sans attendre",
            VoiceMoves.isDecisive(
                listOf("le deuxième"), french, true, true, pendingChoice = pair, language = "fr", candidates = legal,
            ),
        )
        // Sans question posée, « premier » n'est qu'une phrase sans coup : ignorée.
        assertEquals(Decision.Ignored, decide("premier"))
    }
}
