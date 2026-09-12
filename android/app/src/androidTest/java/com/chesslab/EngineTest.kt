package com.chesslab

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.engine.EngineService
import com.chesslab.engine.FairyEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Les deux moteurs natifs. Le module `engine` n'avait aucun test : ce qu'il
 * fait passe par JNI, du C++ statique et des threads, c'est-à-dire tout ce qui
 * ne se voit pas à la lecture.
 *
 * Le cas qui motive ce fichier : `libchesslab_engine.so` et
 * `libchesslab_fairy.so` embarquent CHACUNE sa libc++ en statique, et toutes
 * deux exportent `std::cout` sous le même nom mangé. Si le lien dynamique les
 * confondait, le shim de l'une détournerait la sortie de l'autre et leurs
 * réponses se mélangeraient. Ce test le règle par l'expérience.
 */
@RunWith(AndroidJUnit4::class)
class EngineTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    @Test fun stockfishRepondAUneQuestionSimple() = runBlocking {
        val best = withContext(Dispatchers.IO) {
            EngineService.use(context) { e ->
                e.send("position startpos")
                e.search("go depth 8", timeoutMs = 30_000)
            }
        }
        assertNotNull("Stockfish n'a pas répondu", best)
        assertTrue("réponse inattendue : $best", best!!.startsWith("bestmove"))
        assertNotNull("le moteur devrait s'être présenté", EngineService.identity)
    }

    @Test fun fairyArbitreUneVariante() = runBlocking {
        val query = withContext(Dispatchers.IO) {
            FairyEngine.use(context) { it.queryPosition("atomic", null, emptyList()) }
        }
        assertNotNull("Fairy n'a pas répondu", query)
        // Vingt coups légaux au départ, aux échecs comme à l'Atomique.
        assertEquals(20, query!!.legalMoves.size)
        assertTrue("e2e4 devrait être légal : ${query.legalMoves}", "e2e4" in query.legalMoves)
    }

    /**
     * Les deux moteurs, EN MÊME TEMPS. Chacun doit rendre SA réponse : c'est
     * la seule façon de savoir si leurs sorties natives se croisent.
     */
    @Test fun lesDeuxMoteursNeSeMelangentPas() = runBlocking {
        repeat(3) {
            val results = withContext(Dispatchers.IO) {
                listOf(
                    async {
                        EngineService.use(context) { e ->
                            e.send("position startpos moves e2e4 e7e5")
                            e.search("go depth 6", timeoutMs = 30_000)
                        }
                    },
                    async {
                        FairyEngine.use(context) { it.queryPosition("horde", null, emptyList()) }
                    },
                ).awaitAll()
            }
            val best = results[0] as String?
            val query = results[1] as com.chesslab.engine.PositionQuery?

            assertNotNull("Stockfish muet au tour $it", best)
            assertTrue("Stockfish a rendu « $best » — sortie croisée ?", best!!.startsWith("bestmove"))
            assertNotNull("Fairy muet au tour $it", query)
            // La Horde est le témoin : sa position de départ n'a RIEN à voir
            // avec celle des échecs. Une FEN d'échecs classiques ici voudrait
            // dire que la réponse vient de l'autre moteur.
            assertTrue(
                "position d'échecs classiques rendue pour la Horde : ${query!!.fen}",
                query.fen.startsWith("rnbqkbnr/pppppppp/8/1PP2PP1/"),
            )
            // Huit coups, et pas un de plus : tous les pions de la horde sont
            // bloqués par celui qui les précède, sauf ceux des quatre colonnes
            // sans pion en cinquième et les quatre de la cinquième elle-même.
            assertEquals(8, query.legalMoves.size)
        }
    }

    /**
     * Une recherche abandonnée ne doit pas polluer la suivante : c'est la
     * raison d'être du `stop` + attente de `bestmove` dans `search`.
     */
    @Test fun uneRechercheAbandonneeNePolluePasLaSuivante() = runBlocking {
        withContext(Dispatchers.IO) {
            EngineService.use(context) { e ->
                e.send("position startpos")
                // une recherche longue, coupée net par le délai
                e.search("go movetime 20000", timeoutMs = 300)
            }
        }
        val best = withContext(Dispatchers.IO) {
            EngineService.use(context) { e ->
                e.send("position startpos moves e2e4 e7e5 g1f3")
                e.search("go depth 6", timeoutMs = 30_000)
            }
        }
        assertNotNull(best)
        val move = best!!.split(" ").getOrNull(1)
        assertNotNull(move)
        // La réponse doit être un coup NOIR de cette position-ci.
        assertTrue("« $move » ne vient pas de la position demandée", move!!.length in 4..5)
        assertTrue("un coup noir part de la 6e, 7e ou 8e rangée, reçu $move", move[1] in '6'..'8')
    }
}
