package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.library.LibraryDatabase
import kotlinx.coroutines.runBlocking
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith

/**
 * « S'entraîner » depuis le lecteur travaille la variante AFFICHÉE (demande
 * d'Olivier, 01/11/2026), pas seulement la ligne principale. Pendant de
 * `OpeningTrainVariationUITests` côté iOS.
 *
 * Le parcours est celui de l'utilisateur : ouvrir l'Italienne, choisir un coup
 * dans l'index des lignes, toucher le chapeau, jouer.
 */
@RunWith(AndroidJUnit4::class)
class TrainVariationTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    private val dao by lazy {
        LibraryDatabase.get(InstrumentationRegistry.getInstrumentation().targetContext).training()
    }

    @Before fun cleanSlate() = runBlocking {
        dao.clearProgress()
        dao.clearLogs()
    }

    private fun awaitTag(tag: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) { compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }

    private fun awaitText(text: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text, substring = true, ignoreCase = true).fetchSemanticsNodes().isNotEmpty()
        }

    private fun openItalianGame() {
        compose.onNodeWithTag("mode-openings").performScrollTo().performClick()
        awaitTag("compte")
        compose.onNodeWithTag("recherche").performTextInput("Italian")
        awaitTag("cours-italian-game", 10_000)
        compose.onNodeWithTag("cours-italian-game").performClick()
        awaitTag("racine")
    }

    /** Choisit un coup dans l'index (la position s'affiche), puis touche le chapeau. */
    private fun trainFromIndexMove(tag: String?) {
        if (tag != null) {
            compose.onNodeWithTag("index-des-lignes").performClick()
            awaitTag("index-rangee-0", 20_000)
            compose.onNodeWithTag(tag).performScrollTo().performClick()
            compose.waitUntil(10_000) { compose.onAllNodesWithTag("index-fermer").fetchSemanticsNodes().isEmpty() }
        }
        compose.onNodeWithTag("entrainer").performClick()
        awaitTag("consigne")
    }

    /**
     * Avance dans le lecteur de [steps] coups, puis choisit la variante [uci] dans la
     * liste du répertoire (la ligne de l'index, paresseuse, n'est pas encore là).
     */
    private fun trainFromReaderVariation(steps: Int, uci: String) {
        repeat(steps) { compose.onNodeWithTag("suivant").performClick(); compose.waitForIdle() }
        compose.onNodeWithTag("coup-$uci").performScrollTo().performClick()
        compose.waitForIdle()
        compose.onNodeWithTag("entrainer").performClick()
        awaitTag("consigne")
    }

    private fun play(from: String, to: String) {
        compose.onNodeWithTag("case-$from").performClick()
        compose.onNodeWithTag("case-$to").performClick()
    }

    // Les coups s'affichent avec des figurines : fou ♝, cavalier ♞.

    @Test fun aLaRacineLEntrainementSuitLaLignePrincipale() {
        openItalianGame()
        trainFromIndexMove(null)
        play("e2", "e4"); awaitText("1. e4 e5")
        play("g1", "f3"); awaitText("2. ♞f3 ♞c6")
        play("f1", "c4"); awaitText("3. ♝c4 ♝c5")        // Fc5, la principale
    }

    @Test fun lAdversaireSuitLaVarianteAffichee() {
        openItalianGame()
        trainFromReaderVariation(steps = 5, uci = "g8f6")           // 3…Cf6, la défense des deux cavaliers
        play("e2", "e4"); awaitText("1. e4 e5")
        play("g1", "f3"); awaitText("2. ♞f3 ♞c6")
        play("f1", "c4"); awaitText("3. ♝c4 ♞f6")        // Cf6 et non Fc5
    }

    @Test fun lEntrainementAttendLeCoupDeLaVarianteAffichee() {
        openItalianGame()
        trainFromIndexMove("index-coup-7-b2b4")                     // le gambit Evans
        play("e2", "e4"); awaitText("1. e4 e5")
        play("g1", "f3"); awaitText("2. ♞f3 ♞c6")
        play("f1", "c4"); awaitText("3. ♝c4 ♝c5")
        play("b2", "b4")                                            // le coup de la variante : juste, sans question
        awaitText("4. b4 ♝xb4")
        assert(compose.onAllNodesWithTag("variante").fetchSemanticsNodes().isEmpty())
    }

    @Test fun jouerLaPrincipalePendantUneVarianteProposeDeRester() {
        openItalianGame()
        trainFromIndexMove("index-coup-7-b2b4")
        play("e2", "e4"); awaitText("1. e4 e5")
        play("g1", "f3"); awaitText("2. ♞f3 ♞c6")
        play("f1", "c4"); awaitText("3. ♝c4 ♝c5")
        play("c2", "c3")                                            // la principale, alors qu'on travaille Evans

        awaitTag("variante")
        compose.onNodeWithTag("variante").assertIsDisplayed()
        compose.onNodeWithText("autre variante", substring = true).assertIsDisplayed()
        compose.onNodeWithTag("rester-principale").performClick()   // « Rester sur b4 » : le coup travaillé
        awaitText("4. b4")
    }

    @Test fun uneVarianteQuiN_EstPasLaPrincipaleGardeLeTexteHabituel() {
        // Sans variante demandée, jouer un coup non principal garde l'ancien message.
        openItalianGame()
        trainFromIndexMove(null)
        play("e2", "e4"); awaitText("1. e4 e5")
        play("g1", "f3"); awaitText("2. ♞f3 ♞c6")
        play("f1", "c4"); awaitText("3. ♝c4 ♝c5")
        play("b2", "b4")
        awaitTag("variante")
        compose.onNodeWithText("la ligne principale est", substring = true).assertIsDisplayed()
    }
}
