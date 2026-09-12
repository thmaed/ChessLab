package com.chesslab.transfer

import com.chesslab.training.Fsrs
import com.chesslab.training.FsrsRating
import com.chesslab.training.OpeningReviewLog
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * La fusion entre appareils.
 *
 * Ce fichier ne vérifie pas des valeurs : il vérifie les trois PROPRIÉTÉS sur
 * lesquelles tout repose — déterminisme, idempotence, commutativité. Si elles
 * tiennent, deux appareils ne peuvent pas diverger ; si l'une cède, ils le
 * feront un jour, en silence, sur la donnée la plus douloureuse à perdre.
 */
class TransferMergeTest {

    private val t0 = 1_700_000_000_000L
    private val jour = Fsrs.DAY_MS

    private fun local(uid: String, fen: String, rating: Int, at: Long) =
        OpeningReviewLog(uid, fen, rating, at, 0.0, 1.0, 1.0)

    private fun incoming(uid: String, fen: String, rating: Int, at: Long) =
        TransferFile.LogEntry(uid, fen, rating, at, 0.0, 1.0, 1.0)

    private val e4 = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -"
    private val e5 = "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq -"

    // MARK: Union du journal

    @Test fun `les deux journaux se réunissent`() {
        val merged = TransferMerge.mergeLogs(
            listOf(local("a", e4, 3, t0)),
            listOf(incoming("b", e5, 2, t0 + jour)),
        )
        assertEquals(listOf("a", "b"), merged.map { it.uid })
    }

    @Test fun `une entrée déjà connue n'est pas ajoutée deux fois`() {
        val merged = TransferMerge.mergeLogs(
            listOf(local("a", e4, 3, t0)),
            listOf(incoming("a", e4, 3, t0), incoming("b", e5, 3, t0 + jour)),
        )
        assertEquals(2, merged.size)
    }

    @Test fun `le journal fusionné est trié par date, pas par provenance`() {
        val merged = TransferMerge.mergeLogs(
            listOf(local("tard", e4, 3, t0 + 10 * jour)),
            listOf(incoming("tôt", e4, 3, t0)),
        )
        assertEquals(listOf("tôt", "tard"), merged.map { it.uid })
    }

    // MARK: Les trois propriétés

    @Test fun `la fusion est IDEMPOTENTE — réimporter ne change rien`() {
        val mine = listOf(local("a", e4, 3, t0), local("b", e5, 1, t0 + jour))
        val file = mine.map { incoming(it.uid, it.fenKey, it.ratingRaw, it.reviewedAt) }

        val once = TransferMerge.mergeLogs(mine, file)
        val twice = TransferMerge.mergeLogs(once, file)
        assertEquals(once.map { it.uid }, twice.map { it.uid })
        assertEquals(TransferMerge.replay(once).keys, TransferMerge.replay(twice).keys)
    }

    @Test fun `la fusion est COMMUTATIVE — A puis B vaut B puis A`() {
        val a = listOf(local("a1", e4, 3, t0), local("a2", e4, 2, t0 + 3 * jour))
        val b = listOf(local("b1", e4, 1, t0 + jour), local("b2", e5, 4, t0 + 2 * jour))
        fun asFile(l: List<OpeningReviewLog>) =
            l.map { incoming(it.uid, it.fenKey, it.ratingRaw, it.reviewedAt) }

        val ab = TransferMerge.replay(TransferMerge.mergeLogs(a, asFile(b)))
        val ba = TransferMerge.replay(TransferMerge.mergeLogs(b, asFile(a)))

        assertEquals(ab.keys, ba.keys)
        for (key in ab.keys) {
            val x = ab.getValue(key)
            val y = ba.getValue(key)
            assertEquals("stabilité de $key", x.stability, y.stability, 1e-9)
            assertEquals("difficulté de $key", x.difficulty, y.difficulty, 1e-9)
            assertEquals("répétitions de $key", x.reps, y.reps)
            assertEquals("échéance de $key", x.dueAt, y.dueAt)
        }
    }

    @Test fun `le rejeu est DÉTERMINISTE — l'ordre d'arrivée ne compte pas`() {
        val entries = listOf(
            local("1", e4, 3, t0),
            local("2", e4, 1, t0 + 2 * jour),
            local("3", e4, 4, t0 + 9 * jour),
        )
        val straight = TransferMerge.replay(entries).getValue(e4)
        val shuffled = TransferMerge.replay(entries.reversed()).getValue(e4)
        assertEquals(straight.stability, shuffled.stability, 1e-9)
        assertEquals(straight.reps, shuffled.reps)
    }

    // MARK: Ce que le rejeu corrige

    @Test fun `une révision intercalée change l'état, et c'est le but`() {
        // L'appareil A ne connaissait que sa révision ; B en avait une AVANT.
        // Rejouer avec les deux donne un état différent de celui que A avait
        // calculé seul — c'est exactement la raison pour laquelle on ne
        // transporte pas l'état.
        val seul = TransferMerge.replay(listOf(local("a", e4, 3, t0 + 5 * jour))).getValue(e4)
        val ensemble = TransferMerge.replay(
            listOf(local("b", e4, 3, t0), local("a", e4, 3, t0 + 5 * jour))
        ).getValue(e4)
        assertEquals(1, seul.reps)
        assertEquals(2, ensemble.reps)
        assertTrue("la position est mieux ancrée après deux révisions",
            ensemble.stability > seul.stability)
    }

    @Test fun `une position jamais révisée n'apparaît pas`() {
        assertTrue(TransferMerge.replay(emptyList()).isEmpty())
    }

    @Test fun `l'état rejoué porte la première rencontre et la dernière révision`() {
        val state = TransferMerge.replay(
            listOf(local("a", e4, 3, t0), local("b", e4, 3, t0 + 4 * jour))
        ).getValue(e4)
        assertEquals(t0, state.firstSeenAt)
        assertEquals(t0 + 4 * jour, state.lastReviewedAt)
        assertNotNull(state.dueAt)
    }

    // MARK: Parties et compteurs

    @Test fun `seules les parties inconnues sont retenues`() {
        val mine = setOf("g1")
        val file = listOf(
            TransferFile.GameEntry("g1", t0, "Vous", "Lena", "1-0", "engine", null, 40, "…"),
            TransferFile.GameEntry("g2", t0 - jour, "Vous", "Nils", "0-1", "engine", null, 30, "…"),
        )
        val kept = TransferMerge.mergeGames(mine, file)
        assertEquals(listOf("g2"), kept.map { it.uid })
    }

    @Test fun `les compteurs prennent le maximum, jamais la somme`() {
        // Additionner compterait deux fois ce qui a été résolu avant l'échange.
        assertEquals(12, TransferMerge.mergeCounters(12, 9))
        assertEquals(12, TransferMerge.mergeCounters(9, 12))
    }

    // MARK: Le format

    @Test fun `un fichier écrit puis relu rend exactement la même chose`() {
        val file = TransferFile(
            exportedAt = t0, device = "Pixel 7",
            reviewLog = listOf(TransferFile.LogEntry("a", e4, 3, t0, 0.5, 1.0, 3.17)),
            games = listOf(TransferFile.GameEntry("g", t0, "Vous", "Lena", "1-0", "engine", null, 40, "1. e4 e5")),
            puzzlesAttempted = 12, puzzlesSolved = 9,
        )
        val back = TransferFile.decode(TransferFile.encode(file)).getOrThrow()
        assertEquals(file, back)
    }

    @Test fun `un fichier étranger est refusé sans lever`() {
        val failure = TransferFile.decode("{\"hello\":1}").exceptionOrNull()
        assertTrue(failure is TransferFile.DecodeError)
        assertEquals(TransferFile.Companion.Failure.NotOurs,
            (failure as TransferFile.DecodeError).failure)
    }

    @Test fun `du texte qui n'est pas du JSON est refusé sans lever`() {
        assertTrue(TransferFile.decode("ceci n'est pas un fichier").isFailure)
    }

    @Test fun `un fichier d'une version future est refusé, et le dit`() {
        val text = TransferFile.encode(
            TransferFile(t0, "x", emptyList(), emptyList(), 0, 0)
        ).replace("\"version\":1", "\"version\":99")
        val failure = TransferFile.decode(text).exceptionOrNull() as TransferFile.DecodeError
        assertEquals(TransferFile.Companion.Failure.TooNew(99), failure.failure)
    }

    @Test fun `une entrée sans identifiant est ignorée plutôt que de tout perdre`() {
        val text = """{"format":"chesslab-transfer","version":1,"reviewLog":[
            {"fen":"$e4","rating":3,"at":$t0},
            {"uid":"bon","fen":"$e4","rating":3,"at":$t0}]}"""
        val file = TransferFile.decode(text).getOrThrow()
        assertEquals(listOf("bon"), file.reviewLog.map { it.uid })
    }
}
