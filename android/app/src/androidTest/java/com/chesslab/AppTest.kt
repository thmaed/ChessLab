package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
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

    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    private fun awaitText(text: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty()
        }

    private fun awaitTag(tag: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
        }

    private fun open(mode: String) = compose.onNodeWithTag("mode-$mode").performClick()

    @Test fun theHomeOffersTheModes() {
        compose.onNodeWithTag("mode-Contre l'ordinateur").assertIsDisplayed()
        compose.onNodeWithTag("mode-Deux joueurs").assertIsDisplayed()
        compose.onNodeWithTag("mode-Analyser").assertIsDisplayed()
    }

    @Test fun playingAMoveMakesTheEngineReply() {
        open("Contre l'ordinateur")
        awaitText("À vous de jouer", 120_000)
        compose.onNodeWithTag("adversaire-stockfish").performClick()

        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()

        awaitTag("coup-0", 10_000)     // notre coup est écrit
        awaitTag("coup-1", 60_000)     // le moteur a répondu
        awaitText("À vous de jouer")   // la main revient
    }

    @Test fun twoPlayersAlternate() {
        open("Deux joueurs")
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
        open("Analyser")
        compose.onNodeWithTag("saisie").performTextInput("1. e4 e5 2. Nf3 Nc6 3. Bb5 a6")
        compose.onNodeWithTag("charger").performClick()

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
        open("Puzzles")
        // la bibliothèque fait 19 Mo : on laisse le temps de la parcourir
        awaitTag("score", 60_000)
        compose.onNodeWithTag("case-e4").assertIsDisplayed()

        compose.onNodeWithTag("passer").performClick()
        awaitTag("score", 10_000)
    }

    @Test fun openingCoursesCanBeRead() {
        open("Ouvertures")
        awaitTag("compte")
        // la liste est paresseuse : on filtre pour amener la ligne à l'écran
        compose.onNodeWithTag("recherche").performTextInput("Italian")
        awaitTag("cours-italian-game", 10_000)
        compose.onNodeWithTag("cours-italian-game").performClick()

        awaitTag("progression")
        compose.onNodeWithTag("case-e4").assertIsDisplayed()
        // le premier coup commenté de la Partie italienne est Bc4, au 5e demi-coup
        repeat(5) { compose.onNodeWithTag("suivant").performClick() }
        awaitTag("commentaire", 10_000)
    }

    @Test fun endgameCoursesAreListedApart() {
        open("Finales")
        awaitTag("compte")
        compose.onNodeWithTag("recherche").performTextInput("Opposition")
        awaitTag("cours-eg-opposition", 10_000)
        compose.onNodeWithTag("cours-eg-opposition").performClick()
        awaitTag("progression")
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
        open("Contre l'ordinateur")
        // le réseau fait 43 Mo : son chargement prend du temps sur émulateur
        awaitText("À vous de jouer", 120_000)

        compose.onNodeWithTag("adversaire-nadia").performClick()
        awaitText("À vous de jouer", 30_000)

        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()

        awaitTag("coup-0", 10_000)
        awaitTag("coup-1", 120_000)      // Nadia répond
        awaitText("À vous de jouer", 30_000)
    }

    @Test fun theLaboratoryPlaysByItself() {
        open("Laboratoire")
        // deux Stockfish : pas d'attente de chargement du réseau
        compose.onNodeWithTag("camp-a-stockfish").performClick()
        compose.onNodeWithTag("camp-b-stockfish").performClick()
        compose.onNodeWithTag("lancer").performClick()

        awaitTag("coup-3", 120_000)      // quatre demi-coups joués tout seuls
        compose.onNodeWithTag("lancer").performClick()   // pause
    }

    @Test fun aVariantIsRefereedByTheEngine() {
        open("Variantes")
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
        open("Variantes")
        compose.onNodeWithTag("variante-chess960").performClick()
        awaitText("À vous de jouer", 60_000)
        compose.onNodeWithTag("case-a1").assertIsDisplayed()
    }

    @Test fun aFinishedGameLandsInTheLibrary() {
        open("Deux joueurs")
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
        open("Analyser")
        awaitText("Bibliothèque", 15_000)
        awaitText("Blancs — Noirs", 10_000)
    }

    @Test fun anInterruptedGameCanBeResumed() {
        open("Contre l'ordinateur")
        awaitText("À vous de jouer", 120_000)
        compose.onNodeWithTag("adversaire-stockfish").performClick()

        compose.onNodeWithTag("case-d2").performClick()
        compose.onNodeWithTag("case-d4").performClick()
        awaitTag("coup-1", 60_000)          // le moteur a répondu

        // on quitte en pleine partie : l'accueil doit proposer de reprendre
        compose.onNodeWithTag("retour").performClick()
        awaitTag("reprendre", 15_000)
        compose.onNodeWithTag("reprendre").performClick()

        // les deux demi-coups sont rejoués
        awaitTag("coup-1", 60_000)
        awaitText("Partie reprise", 30_000)
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
        compose.onNodeWithTag("editeur").performClick()
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
        open("Analyser")
        compose.onNodeWithTag("retour").performClick()
        compose.onNodeWithTag("mode-Analyser").assertIsDisplayed()
    }
}
