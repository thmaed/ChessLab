package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.play.PlaySettingsStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain

/**
 * L'écran de réglage d'une partie, et ce qu'il commande vraiment.
 *
 * Trois choses s'y jouaient dans le vide avant le 14/09 : le curseur de force
 * ne bridait pas le moteur, aucun réglage ne survivait à la fermeture de
 * l'app, et trois sections d'iOS manquaient — le livre, la cadence libre et
 * la position de départ.
 */
class PlaySetupTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    /** Les réglages sont PERSISTÉS : un essai précédent ne doit pas décider de celui-ci. */
    @Before fun pageBlanche() {
        context.getSharedPreferences("play", android.content.Context.MODE_PRIVATE).edit().clear().commit()
    }

    private fun awaitTag(tag: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
        }

    private fun openSetup() {
        compose.onNodeWithTag("mode-play").performScrollTo().performClick()
        awaitTag("commencer", 120_000)
    }

    /**
     * Le chiffre du curseur PORTE le réglage réel — « Elo ~1200 » quand la
     * force est simulée sous la borne de Stockfish — et le palier le nomme.
     */
    @Test fun leCurseurDitLaForceReelleEtSonPalier() {
        openSetup()
        compose.onNodeWithTag("segment-1").performScrollTo().performClick()
        compose.onNodeWithTag("niveau").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("palier").assertIsDisplayed()
        // Le défaut est accueillant, pas la pleine puissance.
        compose.waitUntil(10_000) {
            compose.onAllNodesWithText("~1200", substring = true).fetchSemanticsNodes().isNotEmpty()
        }
        compose.waitUntil(10_000) {
            compose.onAllNodesWithText("Débutant confirmé", substring = true).fetchSemanticsNodes().isNotEmpty()
        }
    }

    /** Les trois sections qui manquaient sont là. */
    @Test fun leLivreLaCadenceLibreEtLaPositionSontProposes() {
        openSetup()
        compose.onNodeWithTag("segment-1").performScrollTo().performClick()
        // Le livre d'ouvertures, et sa largeur.
        compose.onNodeWithTag("livre-actif").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("livre-mainLinesOnly").performScrollTo().assertIsDisplayed()
        // La cadence personnalisée : minutes et incrément.
        compose.onNodeWithTag("cadence-custom").performScrollTo().performClick()
        compose.onNodeWithTag("minutes-perso").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("increment-perso").performScrollTo().assertIsDisplayed()
        // Et la position de départ.
        compose.onNodeWithTag("position-perso").performScrollTo().performClick()
        compose.onNodeWithTag("champ-fen").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("ouvrir-editeur").performScrollTo().assertIsDisplayed()
    }

    /**
     * Ce qu'on règle est MÉMORISÉ : sans cela, couleur, adversaire, niveau,
     * cadence et aides repartaient aux valeurs d'usine à chaque lancement.
     */
    @Test fun lesReglagesSurviventALaPartie() {
        openSetup()
        compose.onNodeWithTag("segment-1").performScrollTo().performClick()
        compose.onNodeWithTag("couleur-black").performScrollTo().performClick()
        compose.onNodeWithTag("cadence-blitz").performScrollTo().performClick()
        compose.onNodeWithTag("commencer").performClick()
        compose.waitForIdle()

        val saved = PlaySettingsStore.load(context)
        assertNotNull("les réglages devraient être sur le disque", saved)
        assertEquals(com.chesslab.play.PlayerColorChoice.black, saved!!.colorChoice)
        assertEquals("blitz", saved.timeControl.category)
        assertEquals(null, saved.opponentId)
        // La position, elle, ne se mémorise jamais : c'est un choix ponctuel.
        assertEquals(null, saved.startFen)
    }

    /**
     * « Reprendre ici » ÉCARTE vraiment la suite — avant le 14/09 elle
     * revenait simplement au direct, sans rien tronquer — et huit secondes
     * permettent de se raviser.
     */
    @Test fun reprendreIciTronqueLaPartieEtSAnnule() {
        openSetup()
        compose.onNodeWithTag("segment-1").performScrollTo().performClick()
        compose.onNodeWithTag("commencer").performClick()
        compose.waitUntil(120_000) {
            compose.onAllNodesWithText("À vous de jouer", substring = true).fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()
        compose.waitUntil(120_000) {
            compose.onAllNodesWithText("À vous de jouer", substring = true).fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithTag("case-d2").performClick()
        compose.onNodeWithTag("case-d4").performClick()
        compose.waitUntil(120_000) {
            compose.onAllNodesWithText("À vous de jouer", substring = true).fetchSemanticsNodes().isNotEmpty()
        }

        // On remonte de deux demi-coups, puis on repart d'ici.
        compose.onNodeWithTag("precedent").performClick()
        compose.onNodeWithTag("precedent").performClick()
        compose.onNodeWithTag("reprendre-ici").performClick()
        compose.waitForIdle()

        // La suite est écartée — et récupérable le temps qu'on s'en avise.
        compose.onNodeWithTag("annuler-reprise").assertIsDisplayed()
        compose.onNodeWithTag("annuler-reprise").performClick()
        compose.waitForIdle()
    }
}
