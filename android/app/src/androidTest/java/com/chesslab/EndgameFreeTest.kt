package com.chesslab

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import chesskit.Board
import chesskit.Square
import com.chesslab.training.EndgameAssessment
import com.chesslab.training.EndgameFreeViewModel
import com.chesslab.training.EndgameJudge
import com.chesslab.training.EndgameVerdict
import com.chesslab.training.FreePhase
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * La mécanique d'arbitrage de l'entraînement libre, sans le moteur.
 *
 * L'arbitre est postiche et DÉTERMINISTE : ce qui est prouvé ici n'est pas la
 * justesse de Stockfish mais celle du mode — quel coup est repris, ce que le
 * plateau devient quand il l'est, et quel coup la correction montre.
 *
 * Le défaut que ces cas gardent fermé (12/09) : le coup de l'utilisateur était
 * joué sur le VRAI plateau avant d'être arbitré, si bien qu'un coup repris
 * laissait quand même la pièce sur sa nouvelle case et que la flèche de
 * correction montrait le meilleur coup de l'ADVERSAIRE. Ici `Board` est une
 * classe là où l'original Swift est une `struct` — une affectation ne copie
 * rien, il faut le dire.
 */
@RunWith(AndroidJUnit4::class)
class EndgameFreeTest {

    /** La forteresse de Sam Loyd : fou et roi contre cavalier, pion et roi. */
    private val courseId = "eg-bishop-vs-knight-fortress"
    private val rootPlacement = "8/8/8/8/B6n/7p/6k1/4K3"

    /** La même position après Fb3 — le coup qui abandonne la grande diagonale. */
    private val apresFb3 = "8/8/8/8/7n/1B5p/6k1/4K3"

    private val app get() = InstrumentationRegistry.getInstrumentation()
        .targetContext.applicationContext as android.app.Application

    /**
     * Un arbitre qui répond selon une table de PLACEMENTS, « nulle » par
     * défaut.
     *
     * Le nom du champ dit le piège : un verdict est TOUJOURS celui du camp au
     * trait. La position qui suit un coup de l'utilisateur est donc jugée du
     * point de vue de l'ADVERSAIRE — y déclarer « gagnant » veut dire que
     * l'utilisateur vient de tout lâcher. Écrire « perdant » pour dire la
     * même chose est l'erreur naturelle, et elle rend le test muet.
     */
    private class FakeJudge(
        private val verdictForSideToMove: Map<String, EndgameVerdict> = emptyMap(),
        private val best: Map<String, String> = emptyMap(),
        private val defaultBest: String? = null,
    ) : EndgameJudge {

        override suspend fun assess(fen: String): EndgameAssessment {
            val placement = fen.split(" ").first()
            return EndgameAssessment(
                verdictForSideToMove[placement] ?: EndgameVerdict.draw,
                best[placement] ?: defaultBest,
            )
        }

        override suspend fun reply(fen: String): String? = defaultBest
    }

    private fun model(judge: EndgameJudge): EndgameFreeViewModel {
        var vm: EndgameFreeViewModel? = null
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            vm = EndgameFreeViewModel(app).also { it.replaceJudge(judge) }
        }
        return vm!!
    }

    @Test fun laFinaleSOuvreSurSaPropresPosition() {
        val vm = model(FakeJudge(best = mapOf(rootPlacement to "a4d7")))
        runBlocking { vm.start(courseId).join() }

        // Le défaut qui a motivé ce test : la racine est une FEN à QUATRE
        // champs, le parseur en exige six, et le repli rendait la POSITION DE
        // DÉPART — un échiquier complet, où il n'y a aucune finale à conclure.
        assertEquals(rootPlacement, vm.ui.position.fen.split(" ").first())
        assertEquals(FreePhase.awaiting, vm.ui.phase)
        assertEquals(EndgameVerdict.draw, vm.ui.baseline)
        assertTrue("la correction devrait être connue", vm.ui.bestKnown)
    }

    @Test fun unCoupQuiLacheEstRepris_etLePlateauNeBougePas() {
        // Après Fb3 c'est aux Noirs, et l'arbitre les déclare GAGNANTS :
        // autrement dit, l'utilisateur vient de lâcher la nulle.
        val vm = model(
            FakeJudge(
                verdictForSideToMove = mapOf(apresFb3 to EndgameVerdict.win),
                best = mapOf(rootPlacement to "a4d7"),
            )
        )
        runBlocking { vm.start(courseId).join() }

        runBlocking { val (b, m) = played(vm, "a4", "b3"); vm.arbitrate(b, m) }

        assertEquals(FreePhase.slipped, vm.ui.phase)
        assertEquals(EndgameVerdict.draw, vm.ui.slipFrom)
        assertEquals(EndgameVerdict.loss, vm.ui.slipTo)
        assertEquals(1, vm.ui.slipCount)
        // Le plateau n'a pas bougé : le fou est toujours en a4.
        assertEquals(rootPlacement, vm.ui.position.fen.split(" ").first())
        // Et la flèche montre le coup de L'UTILISATEUR, pas celui d'en face.
        val fleche = vm.ui.hints.singleOrNull()
        assertNotNull("une correction devrait être montrée", fleche)
        assertEquals(Square("a4"), fleche!!.from)
        assertEquals(Square("d7"), fleche.to)

        // « Réessayer » n'a rien à défaire.
        InstrumentationRegistry.getInstrumentation().runOnMainSync { vm.retry() }
        assertEquals(FreePhase.awaiting, vm.ui.phase)
        assertEquals(rootPlacement, vm.ui.position.fen.split(" ").first())
        assertTrue(vm.ui.hints.isEmpty())
    }

    @Test fun unCoupQuiTientEstAccepte_etLaDefenseRepond() {
        val vm = model(FakeJudge(best = mapOf(rootPlacement to "a4d7"), defaultBest = "h3h2"))
        runBlocking { vm.start(courseId).join() }
        runBlocking { val (b, m) = played(vm, "a4", "d7"); vm.arbitrate(b, m) }

        // Le fou est en d7, le pion noir a répondu h2, et c'est de nouveau à
        // l'utilisateur : le verdict a été RECALCULÉ.
        assertEquals("8/3B4/8/8/7n/8/6kp/4K3", vm.ui.position.fen.split(" ").first())
        assertEquals(FreePhase.awaiting, vm.ui.phase)
        assertEquals(listOf("Bd7", "h2"), vm.ui.sanMoves)
        assertEquals(0, vm.ui.slipCount)
    }

    @Test fun jouerLeMeilleurCoupApresUnFauxPas() {
        val vm = model(
            FakeJudge(
                verdictForSideToMove = mapOf(apresFb3 to EndgameVerdict.win),
                best = mapOf(rootPlacement to "a4d7"),
                defaultBest = "h3h2",
            )
        )
        runBlocking { vm.start(courseId).join() }
        runBlocking { val (b, m) = played(vm, "a4", "b3"); vm.arbitrate(b, m) }
        assertEquals(FreePhase.slipped, vm.ui.phase)

        runBlocking { vm.playBest().join() }
        assertEquals("8/3B4/8/8/7n/8/6kp/4K3", vm.ui.position.fen.split(" ").first())
        assertEquals(listOf("Bd7", "h2"), vm.ui.sanMoves)
        // Le faux pas reste compté : le bilan de fin doit rester honnête.
        assertEquals(1, vm.ui.slipCount)
    }

    @Test fun rejouerRemetLaFinaleAZero() {
        val vm = model(
            FakeJudge(
                verdictForSideToMove = mapOf(apresFb3 to EndgameVerdict.win),
                best = mapOf(rootPlacement to "a4d7"),
            )
        )
        runBlocking { vm.start(courseId).join() }
        runBlocking { val (b, m) = played(vm, "a4", "b3"); vm.arbitrate(b, m) }
        runBlocking { vm.restart().join() }

        assertEquals(rootPlacement, vm.ui.position.fen.split(" ").first())
        assertEquals(FreePhase.awaiting, vm.ui.phase)
        assertEquals(0, vm.ui.slipCount)
        assertTrue(vm.ui.sanMoves.isEmpty())
    }

    /** Le plateau d'ESSAI que l'écran construit avant d'appeler l'arbitrage. */
    private fun played(vm: EndgameFreeViewModel, from: String, to: String): Pair<Board, chesskit.Move> {
        val scratch = Board(vm.ui.position)
        val move = scratch.move(Square(from), Square(to))!!
        return scratch to move
    }
}
