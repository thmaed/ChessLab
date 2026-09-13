package com.chesslab.analysis

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

/**
 * Le cache des analyses : la clé désigne la PARTIE (pas son texte), le
 * fichier rend exactement ce qu'on y a mis, un profil étranger ne se lit
 * pas, et le cache ne grossit pas sans fin.
 */
class AnalysisEvalStoreTest {

    private lateinit var directory: File
    private lateinit var store: AnalysisEvalStore

    private val start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    @Before fun setUp() {
        directory = Files.createTempDirectory("analysis-cache").toFile()
        store = AnalysisEvalStore(directory)
    }

    @After fun tearDown() { directory.deleteRecursively() }

    @Test fun `la cle vient de la position et des coups, pas du texte du PGN`() {
        val a = AnalysisEvalStore.key(start, listOf("e2e4", "e7e5"))
        val b = AnalysisEvalStore.key(start, listOf("e2e4", "e7e5"))
        val c = AnalysisEvalStore.key(start, listOf("e2e4", "c7c5"))
        assertEquals(a, b)
        assertNotEquals(a, c)
        assertEquals(64, a!!.length)
        // Une position sans coup n'a rien à mettre en cache.
        assertNull(AnalysisEvalStore.key(start, emptyList()))
        // Deux variantes qui partagent la position standard ne partagent pas leur clé.
        assertNotEquals(a, AnalysisEvalStore.key(start, listOf("e2e4", "e7e5"), variantId = "3check"))
    }

    @Test fun `un aller-retour rend les evaluations a l'identique`() {
        val evals = mapOf(
            0 to PositionEval(cp = 12, mate = null, bestLan = "e2e4", gapToSecondBest = 1.5, secondBestLan = "d2d4", pv = listOf("e2e4", "e7e5")),
            1 to PositionEval(cp = null, mate = 3, bestLan = "d1h5", gapToSecondBest = null, pv = emptyList()),
            2 to PositionEval(cp = null, mate = null, bestLan = null, gapToSecondBest = null, pv = emptyList(), terminalWinWhite = 100.0),
        )
        val key = AnalysisEvalStore.key(start, listOf("e2e4", "e7e5"))!!
        store.save(key, evals)
        assertEquals(evals, store.load(key))
    }

    @Test fun `un profil etranger ou un schema inconnu ne se lit pas`() {
        val key = AnalysisEvalStore.key(start, listOf("e2e4"))!!
        store.save(key, mapOf(0 to PositionEval(0, null, "e2e4", null, pv = emptyList())))
        assertNull(store.load(key, profile = "SF16/autre"))
        assertNull(store.load("cle-inexistante"))
        store.file(key).writeText("{\"schema\": 99, \"profile\": \"${AnalysisEvalStore.engineProfile}\", \"evals\": {}}")
        assertNull(store.load(key))
        store.file(key).writeText("pas du json")
        assertNull(store.load(key))
    }

    @Test fun `rien n'est ecrit pour une carte vide, et le cache s'elague`() {
        val key = AnalysisEvalStore.key(start, listOf("e2e4"))!!
        store.save(key, emptyMap())
        assertEquals(false, store.file(key).exists())

        val eval = mapOf(0 to PositionEval(0, null, "e2e4", null, pv = emptyList()))
        for (i in 0 until AnalysisEvalStore.maxSnapshots + 5) {
            val k = AnalysisEvalStore.key(start, listOf("e2e4", "move$i"))!!
            store.save(k, eval)
            // Des dates distinctes, sinon l'ordre LRU serait un tirage au sort.
            store.file(k).setLastModified(1_000_000L + i * 1000L)
        }
        store.prune()
        assertEquals(AnalysisEvalStore.maxSnapshots, directory.listFiles { f -> f.extension == "json" }!!.size)
        // Les plus anciens sont partis, le plus récent est resté.
        assertEquals(false, store.file(AnalysisEvalStore.key(start, listOf("e2e4", "move0"))!!).exists())
        assertEquals(true, store.file(AnalysisEvalStore.key(start, listOf("e2e4", "move${AnalysisEvalStore.maxSnapshots + 4}"))!!).exists())
    }
}
