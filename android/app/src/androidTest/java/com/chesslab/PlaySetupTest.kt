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
     * Le chiffre du curseur PORTE le réglage réel — « Elo ~1200 » quand la force est simulée sous la borne de
     * Stockfish. Et l'écran s'ouvre sur Maia (17/11/2026), Stockfish tout à gauche de la bande.
     */
    @Test fun leCurseurDitLaForceReelle() {
        openSetup()
        compose.onNodeWithTag("fiche-maia").assertIsDisplayed()
        compose.onNodeWithTag("jauges").assertIsDisplayed()
        compose.chooseOpponent("stockfish")
        compose.onNodeWithTag("fiche-stockfish").assertIsDisplayed()
        compose.onNodeWithTag("niveau").performScrollTo().assertIsDisplayed()
        // Le défaut est accueillant, pas la pleine puissance.
        compose.waitUntil(10_000) {
            compose.onAllNodesWithText("~1200", substring = true).fetchSemanticsNodes().isNotEmpty()
        }
    }

    /** Le livre, la cadence libre et la position de départ : chacun dans son menu (refonte du 18/11/2026). */
    @Test fun leLivreLaCadenceLibreEtLaPositionSontProposes() {
        openSetup()
        // Le livre n'existe que pour Stockfish.
        assertEquals(0, compose.onAllNodesWithTag("menu-livre").fetchSemanticsNodes().size)
        compose.chooseOpponent("stockfish")
        compose.pickFromMenu("menu-livre", "livre-mainLinesOnly")
        // La cadence : « Sans limite » par défaut ; « Personnalisé… » ouvre la feuille des minutes et de l'incrément.
        compose.onNodeWithTag("menu-cadence").performScrollTo().assertIsDisplayed()
        compose.pickFromMenu("menu-cadence", "cadence-perso")
        awaitTag("feuille-cadence", 5_000)
        compose.onNodeWithTag("minutes-perso").assertIsDisplayed()
        compose.onNodeWithTag("increment-perso").assertIsDisplayed()
        compose.onNodeWithTag("cadence-ok").performClick()
        compose.waitUntil(5_000) { compose.onAllNodesWithTag("feuille-cadence").fetchSemanticsNodes().isEmpty() }
        // Et la position de départ : le champ FEN, et l'éditeur dans le même menu.
        compose.pickFromMenu("menu-depart", "depart-fen")
        compose.onNodeWithTag("champ-fen").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("menu-depart").performScrollTo().performClick()
        awaitTag("ouvrir-editeur", 5_000)
        compose.onNodeWithTag("depart-initiale").performClick()
        compose.waitUntil(5_000) { compose.onAllNodesWithTag("champ-fen").fetchSemanticsNodes().isEmpty() }
    }

    /**
     * Ce qu'on règle est MÉMORISÉ : sans cela, couleur, adversaire, niveau,
     * cadence et aides repartaient aux valeurs d'usine à chaque lancement.
     */
    @Test fun lesReglagesSurviventALaPartie() {
        openSetup()
        compose.chooseOpponent("stockfish")
        compose.onNodeWithTag("couleur-black").performScrollTo().performClick()
        compose.pickFromMenu("menu-cadence", "preset-blitz_3_2")
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
        compose.chooseOpponent("stockfish")
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
        compose.chooseOpponent("stockfish")
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
     * « Sans limite » : la partie est sans pendule ; la dernière cadence choisie est gardée pour la prochaine fois.
     */
    @Test fun laLimiteDeTempsSeSouvientDeLaDerniereCadence() {
        openSetup()
        compose.chooseOpponent("stockfish")
        compose.pickFromMenu("menu-cadence", "preset-bullet_1_0")
        // On revient à « Sans limite » avant de commencer : la partie est sans pendule.
        compose.pickFromMenu("menu-cadence", "cadence-none")
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
        compose.chooseOpponent("stockfish")
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

    /**
     * Deux joueurs : « Commencer » effaçait la partie en cours SANS rien demander (relevé le
     * 16/11/2026, iOS et Android). Il demande désormais, comme le mode Jouer, et « Reprendre » rouvre
     * la partie. Pendant d'iOS : `ReplaceGameAlert` sur `TwoPlayerSetupView`.
     */
    @Test fun deuxJoueursDemandeAvantDeRemplacerLaPartieEnCours() {
        compose.onNodeWithTag("mode-two").performScrollTo().performClick()
        awaitTag("commencer")
        compose.onNodeWithTag("commencer").performClick()
        awaitTag("case-e2")
        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()
        awaitTag("transport")
        compose.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        compose.waitForIdle()
        awaitTag("mode-two")
        compose.onNodeWithTag("mode-two").performScrollTo().performClick()
        awaitTag("commencer")
        compose.onNodeWithTag("commencer").performClick()
        awaitTag("remplacer-reprendre")
        compose.onNodeWithTag("remplacer-reprendre").performClick()
        // La partie reprise : son premier coup est là (barre de consultation).
        awaitTag("transport")
    }
}
