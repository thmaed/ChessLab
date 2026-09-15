package com.chesslab

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.rules.RuleChain
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Ce qui arrive quand on change d'avis PENDANT que quelque chose calcule.
 *
 * Une réponse mise en route pour une position n'a plus de sens une fois la
 * partie remise à zéro — et si elle se trouve légale sur le nouveau plateau,
 * elle se joue toute seule.
 */
@RunWith(AndroidJUnit4::class)
class StaleAnswerTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    /** L'accueil défile : on fait venir la tuile avant de la toucher. */
    private fun openMode(tag: String) {
        compose.onNodeWithTag("mode-$tag").performScrollTo().performClick()
    }

    private fun awaitText(text: String, timeoutMs: Long = 120_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text, substring = true, ignoreCase = true)
                .fetchSemanticsNodes().isNotEmpty()
        }

    private fun awaitTag(tag: String, timeoutMs: Long = 120_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
        }

    @Test fun uneNouvellePartieEnPleineReflexionNeJoueRienToutSeul() {
        openMode("play")
        awaitTag("commencer")
        // Un personnage plutôt que Stockfish : son inférence prend plus de
        // temps, donc la fenêtre « pendant qu'il calcule » est assez large
        // pour être visée sans course. Les réglages étant mémorisés, l'écran
        // peut s'ouvrir sur Stockfish : on redemande les personnages.
        compose.onNodeWithTag("segment-0").performScrollTo().performClick()
        compose.onNodeWithTag("adversaire-lea").performScrollTo().performClick()
        compose.onNodeWithTag("commencer").performClick()
        awaitText("À vous de jouer")

        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()

        // On abandonne SANS attendre sa réponse, puis on relance : elle ne
        // doit pas atterrir sur le plateau neuf.
        compose.onNodeWithTag("abandonner").performClick()
        compose.onNodeWithTag("abandonner-oui").performClick()
        // Le panneau de fin n'offre que l'accueil et l'analyse, comme iOS :
        // on repasse donc par l'écran de réglages, qui est à un tap.
        awaitTag("accueil")
        compose.onNodeWithTag("accueil").performClick()
        openMode("play")
        awaitTag("commencer")
        compose.onNodeWithTag("commencer").performClick()
        awaitText("À vous de jouer", 60_000)

        Thread.sleep(6_000)
        compose.waitForIdle()
        compose.onNodeWithTag("coups-joues").performClick()
        compose.waitForIdle()
        assert(compose.onAllNodesWithTag("coup-0").fetchSemanticsNodes().isEmpty()) {
            "un coup est apparu tout seul dans la partie neuve"
        }
    }

    @Test fun passerUnPuzzlePendantLaRiposteNeLaJouePasSurLeSuivant() {
        openMode("puzzles")
        awaitTag("commencer-puzzles", 15_000)
        compose.onNodeWithTag("commencer-puzzles").performClick()
        awaitText("Trouvez le meilleur coup")

        // On passe plusieurs fois de suite, plus vite que la riposte de 450 ms.
        repeat(6) { compose.onNodeWithTag("passer").performClick() }
        compose.waitForIdle()
        Thread.sleep(2_000)
        compose.waitForIdle()
        awaitText("Trouvez le meilleur coup", 20_000)
    }
}
