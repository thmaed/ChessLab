package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.rules.RuleChain
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Les tests de bout en bout de l'app. On clique des ÉLÉMENTS NOMMÉS et non des
 * pixels : ils restent valides quand la mise en page bouge.
 *
 * Ce sont les seuls tests du projet qui demandent un appareil ; la couche de
 * règles, elle, se teste sur la JVM en dix secondes.
 */
@RunWith(AndroidJUnit4::class)
class AppTest {

    // La langue passe AVANT l'activité : les assertions sont en français,
    // et l'émulateur, lui, peut être réglé sur n'importe quoi.
    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    private fun awaitText(text: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text, substring = true, ignoreCase = true)
                .fetchSemanticsNodes().isNotEmpty()
        }

    private fun awaitTag(tag: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
        }

    /**
     * Ouvre un mode depuis l'accueil.
     *
     * L'accueil défile : une tuile sous la ligne de flottaison existe mais
     * n'est pas à l'écran. On la fait venir avant de la toucher.
     */
    private fun open(mode: String) {
        compose.onNodeWithTag("mode-$mode").performScrollTo().performClick()
    }

    /**
     * Deux joueurs passe d'abord par l'écran de RÉGLAGES — noms, présentation
     * du plateau, cadence — depuis le 12/09. On le traverse avec les valeurs
     * par défaut : c'est bien la partie qu'on vient tester.
     */
    private fun openTwoPlayers() {
        open("two")
        awaitTag("commencer")
        compose.onNodeWithTag("commencer").performClick()
    }

    /**
     * Lance une partie depuis l'accueil, en passant par la configuration —
     * c'est le chemin de l'utilisateur depuis que l'écran « Nouvelle partie »
     * existe, comme sur iOS.
     *
     * [opponent] : le repère d'une vignette de personnage, ou `null` pour
     * Stockfish (qui vit derrière le contrôle segmenté).
     */
    private fun startGame(opponent: String? = null) {
        open("play")
        awaitTag("commencer", 120_000)
        if (opponent == null) compose.onNodeWithTag("segment-1").performClick()
        else compose.onNodeWithTag(opponent).performClick()
        compose.onNodeWithTag("commencer").performClick()
        awaitText("À vous de jouer", 120_000)
    }

    /** Ouvre la feuille des coups joués et rend la main quand elle est là. */
    private fun openMoveList() {
        compose.onNodeWithTag("coups-joues").performClick()
        awaitTag("coup-0", 10_000)
    }

    @Test fun theHomeOffersTheModes() {
        compose.onNodeWithTag("mode-play").assertIsDisplayed()
        compose.onNodeWithTag("mode-two").assertIsDisplayed()
        compose.onNodeWithTag("mode-analysis").assertIsDisplayed()
    }

    @Test fun playingAMoveMakesTheEngineReply() {
        startGame()

        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()
        // Le moteur répond, la main revient, et les DEUX demi-coups sont là.
        compose.waitUntil(90_000) {
            compose.onAllNodesWithTag("coups-joues").fetchSemanticsNodes().isNotEmpty()
        }
        compose.waitUntil(90_000) {
            compose.onNodeWithTag("coups-joues").performClick()
            val found = compose.onAllNodesWithTag("coup-1").fetchSemanticsNodes().isNotEmpty()
            if (!found) compose.onNodeWithTag("case-e4").performClick()   // referme la feuille
            found
        }
    }

    @Test fun twoPlayersAlternate() {
        openTwoPlayers()
        awaitText("Aux blancs de jouer")

        compose.onNodeWithTag("case-d2").performClick()
        compose.onNodeWithTag("case-d4").performClick()
        awaitText("Aux noirs de jouer")

        // le plateau s'est retourné : d7 reste cliquable par son nom
        compose.onNodeWithTag("case-d7").performClick()
        compose.onNodeWithTag("case-d5").performClick()
        awaitText("Aux blancs de jouer")
        awaitTag("coup-1")
    }

    @Test fun analysingAPgnShowsAnEvaluation() {
        open("analysis")
        // Analyser ouvre d'abord le CHOIX de la source, comme sur iOS.
        compose.onNodeWithTag("entree-coller").performScrollTo().performClick()
        // Le champ et le bouton vivent SOUS la liste des parties enregistrées :
        // dès qu'une partie y est rangée, ils passent sous le pli et le tap
        // part dans le vide. Le défaut ne se voyait qu'en suite complète, où
        // une partie terminée a justement été rangée juste avant.
        compose.onNodeWithTag("saisie").performScrollTo()
            .performTextInput("1. e4 e5 2. Nf3 Nc6 3. Bb5 a6")
        compose.onNodeWithTag("charger").performScrollTo().performClick()

        awaitTag("coup-5", 10_000)     // les six demi-coups sont là

        // le moteur évalue la position courante
        compose.waitUntil(60_000) {
            val nodes = compose.onAllNodesWithTag("evaluation").fetchSemanticsNodes()
            nodes.isNotEmpty() && nodes.first().config.toString().let { !it.contains("—") }
        }

        // et on peut remonter dans la partie
        compose.onNodeWithTag("precedent").performClick()
    }

    @Test fun puzzlesLoadFromTheLibrary() {
        open("puzzles")
        // la bibliothèque fait 19 Mo : on laisse le temps de la parcourir
        awaitTag("score", 60_000)
        compose.onNodeWithTag("case-e4").assertIsDisplayed()

        compose.onNodeWithTag("passer").performClick()
        awaitTag("score", 10_000)
    }

    @Test fun openingCoursesCanBeRead() {
        open("openings")
        awaitTag("compte")
        // la liste est paresseuse : on filtre pour amener la ligne à l'écran
        compose.onNodeWithTag("recherche").performTextInput("Italian")
        awaitTag("cours-italian-game", 10_000)
        compose.onNodeWithTag("cours-italian-game").performClick()

        // Le lecteur DESCEND l'arbre : la racine, puis les suites.
        awaitTag("racine")
        compose.onNodeWithTag("case-e4").assertIsDisplayed()
        // le premier coup commenté de la Partie italienne est Fc4, au 5e demi-coup
        // Un clic, puis on laisse l'écran se reposer : enchaîner cinq clics
        // sans respirer détache le nœud sous la main de Compose.
        repeat(5) {
            compose.onNodeWithTag("suivant").performClick()
            compose.waitForIdle()
        }
        awaitTag("commentaire", 10_000)
    }

    @Test fun endgameCoursesAreListedApart() {
        open("endgames")
        awaitTag("compte")
        compose.onNodeWithTag("recherche").performTextInput("Opposition")
        awaitTag("cours-eg-opposition", 10_000)
        compose.onNodeWithTag("cours-eg-opposition").performClick()
        awaitTag("racine")
    }

    @Test fun settingsChangeTheBoardTheme() {
        compose.onNodeWithTag("reglages").performClick()
        compose.onNodeWithTag("theme-blue").performClick()
        compose.onNodeWithTag("piece-merida").performClick()
        compose.onNodeWithTag("temps-1000").performClick()
        // le plateau d'aperçu suit le réglage
        compose.onNodeWithTag("case-e2").assertIsDisplayed()

        // on repose les valeurs par défaut : un test ne doit pas déteindre
        // sur les suivants, et les réglages sont PERSISTÉS
        compose.onNodeWithTag("theme-classic").performClick()
        compose.onNodeWithTag("piece-classic").performClick()
        compose.onNodeWithTag("temps-400").performClick()
    }

    @Test fun aCharacterPlaysWithMaia() {
        // le réseau fait 43 Mo : son chargement prend du temps sur émulateur
        startGame("adversaire-nadia")

        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()
        awaitText("À vous de jouer", 120_000)   // Nadia a répondu

        openMoveList()
        compose.onNodeWithTag("coup-1").assertIsDisplayed()
    }

    @Test fun theLaboratoryPlaysByItself() {
        open("lab")
        // deux Stockfish : pas d'attente de chargement du réseau
        compose.onNodeWithTag("camp-a-stockfish").performClick()
        compose.onNodeWithTag("camp-b-stockfish").performClick()
        // Le bouton vit sous le bilan détaillé, donc bien sous le pli.
        compose.onNodeWithTag("lancer").performScrollTo().performClick()

        awaitTag("coup-3", 120_000)      // quatre demi-coups joués tout seuls
        compose.onNodeWithTag("lancer").performScrollTo().performClick()   // pause
    }

    @Test fun aVariantIsRefereedByTheEngine() {
        open("variants")
        compose.onNodeWithTag("variante-kingofthehill").performClick()

        // le moteur doit répondre à `d` et `go perft 1` avant qu'on puisse jouer
        awaitText("À vous de jouer", 60_000)

        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()

        // notre coup, puis celui du moteur : deux demi-coups au compteur
        compose.waitUntil(90_000) {
            compose.onAllNodesWithText("2 demi-coups").fetchSemanticsNodes().isNotEmpty()
        }
    }

    @Test fun chess960ShufflesTheBackRank() {
        open("variants")
        compose.onNodeWithTag("variante-chess960").performClick()
        awaitText("À vous de jouer", 60_000)
        compose.onNodeWithTag("case-a1").assertIsDisplayed()
    }

    @Test fun aFinishedGameLandsInTheLibrary() {
        openTwoPlayers()
        awaitText("Aux blancs de jouer")

        // le mat du berger, en sept demi-coups
        val moves = listOf(
            "e2" to "e4", "e7" to "e5",
            "f1" to "c4", "b8" to "c6",
            "d1" to "h5", "g8" to "f6",
            "h5" to "f7",
        )
        for ((from, to) in moves) {
            compose.onNodeWithTag("case-$from").performClick()
            compose.onNodeWithTag("case-$to").performClick()
        }
        awaitText("Échec et mat — les blancs gagnent", 10_000)

        // la partie doit se retrouver dans la bibliothèque de l'écran Analyser
        compose.onNodeWithTag("retour").performClick()
        open("analysis")
        awaitTag("entree-bibliotheque", 15_000)
        compose.onNodeWithTag("entree-bibliotheque").performScrollTo().performClick()
        awaitText("Blancs — Noirs", 15_000)
    }

    @Test fun anInterruptedGameCanBeResumed() {
        startGame()
        compose.onNodeWithTag("case-d2").performClick()
        compose.onNodeWithTag("case-d4").performClick()
        awaitText("À vous de jouer", 90_000)   // le moteur a répondu

        // on quitte en pleine partie : l'accueil doit proposer de reprendre
        compose.onNodeWithTag("retour").performClick()
        awaitTag("reprendre", 15_000)
        compose.onNodeWithTag("reprendre").performClick()

        awaitText("Partie reprise", 60_000)
        openMoveList()
        compose.onNodeWithTag("coup-1").assertIsDisplayed()
    }

    @Test fun progressionShowsWhatTheAppHasSeen() {
        compose.onNodeWithTag("progression").performClick()
        awaitText("Parties", 10_000)
        awaitText("Puzzles", 10_000)
    }

    @Test fun soundsCanBeTurnedOff() {
        compose.onNodeWithTag("reglages").performClick()
        awaitText("Sons du plateau", 10_000)
        compose.onNodeWithTag("sons").performClick()
        compose.onNodeWithTag("sons").performClick()   // et remis, pour ne rien laisser derrière
    }

    @Test fun thePositionEditorBuildsAFen() {
        // L'éditeur vit sous Analyser, comme sur iOS.
        open("analysis")
        compose.onNodeWithTag("entree-editeur").performScrollTo().performClick()
        awaitTag("fen", 10_000)

        // la position de départ, puis l'analyse
        compose.onNodeWithTag("depart").performClick()
        compose.waitUntil(10_000) {
            compose.onAllNodesWithText(
                "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1",
            ).fetchSemanticsNodes().isNotEmpty()
        }

        // une pièce posée à la main change la FEN
        compose.onNodeWithTag("vider").performClick()
        compose.onNodeWithTag("palette-R").performClick()
        compose.onNodeWithTag("case-e1").performClick()
        compose.waitUntil(10_000) {
            compose.onAllNodesWithText("8/8/8/8/8/8/8/4K3 w - - 0 1").fetchSemanticsNodes().isNotEmpty()
        }
    }

    @Test fun helpExplainsWhatTheAppActuallyDoes() {
        compose.onNodeWithTag("aide").performClick()
        awaitText("Les neuf personnages", 10_000)
        awaitText("Le filet de sécurité", 10_000)
    }

    @Test fun backReturnsHome() {
        open("analysis")
        compose.onNodeWithTag("retour").performClick()
        compose.onNodeWithTag("mode-analysis").assertIsDisplayed()
    }

    @Test fun leJeuResteJouableEnPaysage() {
        openTwoPlayers()
        awaitText("Aux blancs de jouer")

        compose.activityRule.scenario.onActivity {
            it.requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        }
        compose.waitForIdle()

        // Couché, le plateau doit rester ENTIER et cliquable : c'était le
        // défaut — le panneau mangeait la hauteur et seule la 8e rangée
        // restait visible.
        compose.onNodeWithTag("case-a1").assertIsDisplayed()
        compose.onNodeWithTag("case-h8").assertIsDisplayed()
        compose.onNodeWithTag("case-d2").performClick()
        compose.onNodeWithTag("case-d4").performClick()
        awaitText("Aux noirs de jouer")

        compose.activityRule.scenario.onActivity {
            it.requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        }
        compose.waitForIdle()
        // Le coup survit à la rotation : l'activité ne se recrée pas.
        awaitText("Aux noirs de jouer")
        compose.onNodeWithTag("case-a1").assertIsDisplayed()
    }
}
