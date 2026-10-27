package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.isEnabled
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
        // La limite de temps est éteinte : aucune cadence tant qu'on ne l'allume pas.
        compose.onNodeWithTag("limite-de-temps").performScrollTo().assertIsDisplayed()
        assertEquals(0, compose.onAllNodesWithTag("cadence-custom").fetchSemanticsNodes().size)
        compose.onNodeWithTag("limite-de-temps").performClick()
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
        compose.onNodeWithTag("limite-de-temps").performScrollTo().performClick()
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

        // Un seul « précédent » recule d'un COUP COMPLET (23/10/2026) : on
        // tombe sur la position d'avant 2. d4, où c'est à nous de jouer — et
        // la reprise nous rend donc la main, pas au moteur.
        compose.onNodeWithTag("precedent").performClick()
        compose.onNodeWithTag("reprendre-ici").performClick()
        compose.waitForIdle()
        compose.waitUntil(10_000) {
            compose.onAllNodesWithText("À vous de jouer", substring = true).fetchSemanticsNodes().isNotEmpty()
        }

        // La suite est écartée — et récupérable le temps qu'on s'en avise.
        compose.onNodeWithTag("annuler-reprise").assertIsDisplayed()
        compose.onNodeWithTag("annuler-reprise").performClick()
        compose.waitForIdle()
    }

    /**
     * Fin de partie : « Accueil » et « Analyser », et la phrase qui dit que l'analyse crée des puzzles. Abandon au premier coup : aucun
     * coup joué, donc rien à trouver — la proposition le dit.
     */
    @Test fun laFinDePartieProposeLesMatsManques() {
        openSetup()
        // « Commencer » est épinglé hors du défilement.
        compose.onNodeWithTag("commencer").performClick()
        awaitTag("abandonner", 60_000)
        compose.waitUntil(60_000) {
            compose.onAllNodes(hasTestTag("abandonner") and isEnabled()).fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithTag("abandonner").performClick()
        awaitTag("abandonner-oui")
        compose.onNodeWithTag("abandonner-oui").performClick()

        awaitTag("fin-de-partie")
        // Abandon AVANT que le modèle Maia ait fini de charger : la fin de ce
        // chargement rouvrait la partie (« À vous de jouer », panneau de fin
        // disparu). On laisse passer ce chargement, et la partie doit rester
        // abandonnée.
        Thread.sleep(6_000)
        compose.waitForIdle()
        compose.onNodeWithTag("fin-de-partie").assertIsDisplayed()
        compose.onNodeWithTag("accueil").assertIsDisplayed()
        compose.onNodeWithTag("analyser-la-partie").assertIsDisplayed()
        // « Mats manqués » n'a plus de bouton : tout passe par « Analyser », dont le récapitulatif propose les puzzles.
        assertEquals(0, compose.onAllNodesWithTag("mats-manques-partie").fetchSemanticsNodes().size)
        compose.onNodeWithTag("indice-analyser-puzzles").assertIsDisplayed()
    }

    /** C8 : après quatre demi-coups et un abandon, la fin de partie montre la courbe du matériel. */
    @Test fun laFinDePartieMontreLaCourbeDuMateriel() {
        openSetup()
        compose.onNodeWithTag("segment-1").performScrollTo().performClick()
        compose.onNodeWithTag("commencer").performClick()
        compose.waitUntil(120_000) {
            compose.onAllNodesWithText("À vous de jouer", substring = true).fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()
        // Le moteur répond : le statut quitte « À vous de jouer » puis y revient.
        runCatching {
            compose.waitUntil(10_000) {
                compose.onAllNodesWithText("À vous de jouer", substring = true).fetchSemanticsNodes().isEmpty()
            }
        }
        compose.waitUntil(120_000) {
            compose.onAllNodesWithText("À vous de jouer", substring = true).fetchSemanticsNodes().isNotEmpty()
        }
        // Laisse le moteur finir de répondre : un clic trop tôt est ignoré.
        Thread.sleep(4_000)
        compose.waitForIdle()
        compose.onNodeWithTag("case-d2").performClick()
        compose.onNodeWithTag("case-d4").performClick()
        // Le moteur répond : le statut quitte « À vous de jouer » puis y revient.
        runCatching {
            compose.waitUntil(10_000) {
                compose.onAllNodesWithText("À vous de jouer", substring = true).fetchSemanticsNodes().isEmpty()
            }
        }
        compose.waitUntil(120_000) {
            compose.onAllNodesWithText("À vous de jouer", substring = true).fetchSemanticsNodes().isNotEmpty()
        }
        compose.waitUntil(60_000) {
            compose.onAllNodes(hasTestTag("abandonner") and isEnabled()).fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithTag("abandonner").performClick()
        awaitTag("abandonner-oui")
        compose.onNodeWithTag("abandonner-oui").performClick()
        awaitTag("courbe-materiel")
        compose.onNodeWithTag("courbe-materiel").assertIsDisplayed()
    }

    /**
     * L'interrupteur « Limite de temps » : éteint, la partie est sans pendule ;
     * la dernière cadence choisie est gardée pour la rallumer.
     */
    @Test fun laLimiteDeTempsSeSouvientDeLaDerniereCadence() {
        openSetup()
        compose.onNodeWithTag("segment-1").performScrollTo().performClick()
        compose.onNodeWithTag("limite-de-temps").performScrollTo().performClick()
        compose.onNodeWithTag("cadence-bullet").performScrollTo().performClick()
        // On l'éteint avant de commencer : la partie est sans limite.
        compose.onNodeWithTag("limite-de-temps").performScrollTo().performClick()
        compose.onNodeWithTag("commencer").performClick()
        compose.waitForIdle()
        val saved = PlaySettingsStore.load(context)
        assertEquals("none", saved!!.timeControlId)
        assertEquals(
            "bullet_1_0",
            context.getSharedPreferences("time_limit", android.content.Context.MODE_PRIVATE).getString("play", null),
        )
    }

    /**
     * Depuis l'écran de réglages : la partie en cours se voit (carte « Reprendre »), et « Commencer »
     * demande avant de l'effacer. Retour d'un joueur (27/10/2026).
     */
    @Test fun lEcranDeReglagesProposeDeReprendreEtDemandeAvantDeRemplacer() {
        openSetup()
        compose.onNodeWithTag("segment-1").performScrollTo().performClick()
        assertEquals(0, compose.onAllNodesWithTag("reprendre-depuis-reglages").fetchSemanticsNodes().size)
        compose.onNodeWithTag("commencer").performClick()
        compose.waitUntil(120_000) {
            compose.onAllNodesWithText("À vous de jouer", substring = true).fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()
        Thread.sleep(2_000)
        compose.waitForIdle()
        // Retour à l'accueil par la flèche, puis de nouveau l'écran de réglages.
        compose.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        compose.waitForIdle()
        awaitTag("mode-play")
        compose.onNodeWithTag("mode-play").performScrollTo().performClick()
        awaitTag("reprendre-depuis-reglages")
        compose.onNodeWithTag("commencer").performClick()
        awaitTag("remplacer-reprendre")
        compose.onNodeWithTag("remplacer-reprendre").performClick()
        awaitTag("case-e4")
    }
}
