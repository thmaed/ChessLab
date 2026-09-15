package com.chesslab

import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.engine.FairyEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Test

/**
 * Une recherche ANNULÉE doit laisser le moteur à l'arrêt.
 *
 * L'app s'est arrêtée net « vers la fin » d'une partie de Horde, sur un
 * SIGSEGV dans l'évaluation de Fairy-Stockfish. Le symbole du premier cadre
 * était trompeur — le binaire est optimisé —, mais l'adresse fautive (0x1470,
 * un décalage dans `Thread`) disait l'essentiel : la position a été RÉÉCRITE
 * sous un thread de recherche encore vivant.
 *
 * C'est le geste que font désormais la barre d'évaluation et les flèches
 * d'indice : elles annulent leur coroutine à chaque coup. Sans arrêt explicite,
 * l'annulation rendait le verrou pendant que le moteur cherchait toujours, et
 * l'appelant suivant lui envoyait `position …` en pleine recherche.
 *
 * Le test refait ce geste trente fois de suite. Il ne « vérifie » pas une
 * valeur : il vérifie que le processus est toujours là, et que le moteur
 * répond encore juste après.
 */
class FairyEngineCancellationTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    @Test fun unerechercheAnnuleeNeLaissePasLeMoteurEnCourse() {
        runBlocking {
            repeat(30) { tour ->
                val cherche = launch(Dispatchers.IO) {
                    FairyEngine.use(context) { engine ->
                        engine.bestMove("horde", startFen = null, uciLog = emptyList(), movetimeMs = 5_000)
                    }
                }
                // Assez pour que la recherche démarre pour de bon, pas assez
                // pour qu'elle finisse : c'est la fenêtre dangereuse.
                delay(120)
                cherche.cancelAndJoin()

                // Aussitôt après, ce que fait l'écran : redemander la position.
                val query = withContext(Dispatchers.IO) {
                    FairyEngine.use(context) { it.queryPosition("horde", null, emptyList()) }
                }
                assertNotNull("le moteur ne répond plus au tour $tour", query)
                assertFalse("aucun coup légal au tour $tour", query!!.legalMoves.isEmpty())
            }
        }
    }

    /**
     * L'indice remet `MultiPV` à 1 même annulé : sinon le moteur cherche trois
     * lignes à chaque coup pour le reste de la partie, sans que rien ne le dise.
     */
    @Test fun unIndiceAnnuleRendSonMultiPV() {
        runBlocking {
            repeat(5) {
                val indice = launch(Dispatchers.IO) {
                    FairyEngine.use(context) { it.hintLines("horde", null, emptyList(), 5_000) }
                }
                delay(120)
                indice.cancelAndJoin()
            }
            // Une recherche ordinaire ne doit rendre qu'UNE ligne principale.
            val rangs = withContext(Dispatchers.IO) {
                FairyEngine.use(context) { engine ->
                    engine.send("setoption name UCI_Variant value horde")
                    engine.send("position startpos")
                    val vues = HashSet<Int>()
                    val lues = java.util.concurrent.CopyOnWriteArrayList<String>()
                    val lecteur = launch(Dispatchers.IO) { engine.lines.collect { lues += it } }
                    engine.send("go movetime 400")
                    kotlinx.coroutines.withTimeoutOrNull(20_000) {
                        while (lues.none { it.startsWith("bestmove") }) delay(30)
                    }
                    lecteur.cancel()
                    for (l in lues) {
                        if (!l.contains(" multipv ")) continue
                        l.substringAfter(" multipv ", "").substringBefore(" ").toIntOrNull()?.let { vues += it }
                    }
                    vues
                }
            }
            assertFalse("MultiPV est resté à 3 : $rangs", rangs.orEmpty().any { it > 1 })
        }
    }
}
