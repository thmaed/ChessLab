package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.isEnabled
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.chesslab.library.LibraryDatabase
import kotlinx.coroutines.runBlocking
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith

/**
 * La revue complète d'une partie : classer chaque coup, en tirer un bilan, puis
 * fabriquer des puzzles avec les fautes.
 *
 * Le test demande le MOTEUR, donc un appareil ; les fonctions pures du barème,
 * elles, se vérifient sur la JVM en deux secondes (voir `ClassificationTest`).
 */
@RunWith(AndroidJUnit4::class)
class AnalysisReviewTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    /**
     * Les Blancs laissent passer un mat en un (4.Cf3 au lieu de Dxf7#) : la
     * position d'avant n'a qu'UN bon coup, ce qui en fait un puzzle net. Une
     * gaffe d'ouverture ordinaire n'en ferait pas — plusieurs défenses s'y
     * valent, et deux coups qui se valent ne font pas un puzzle.
     */
    private val missedMate = "1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Nf3 Nxh5"

    /**
     * La table part VIDE. La même position ne donne qu'un puzzle — c'est voulu,
     * pour que revoir deux fois une partie ne la double pas —, si bien qu'un
     * puzzle laissé par un essai précédent ferait échouer celui-ci pour une
     * raison qui n'a rien à voir avec le code testé.
     */
    @Before fun videLesPuzzlesMaison() = runBlocking {
        LibraryDatabase.get(ApplicationProvider.getApplicationContext()).ownPuzzles().clear()
    }



    private fun awaitTag(tag: String, timeoutMs: Long = 120_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
        }

    private fun awaitNoTag(tag: String, timeoutMs: Long = 300_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isEmpty()
        }

    private fun awaitText(text: String, timeoutMs: Long = 120_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text, substring = true, ignoreCase = true)
                .fetchSemanticsNodes().isNotEmpty()
        }

    /** Tout le texte porté par un nœud, y compris celui de ses enfants fusionnés. */
    private fun textOf(tag: String): String =
        compose.onNodeWithTag(tag)
            .fetchSemanticsNode()
            .let { node ->
                (listOf(node) + node.children).flatMap {
                    it.config.getOrElse(androidx.compose.ui.semantics.SemanticsProperties.Text) { emptyList() }
                }
            }
            .joinToString(" ")

    private fun loadGame() {
        compose.onNodeWithTag("mode-analysis").performScrollTo().performClick()
        // « Coller » vit désormais sous « Autres sources », et ouvre une
        // FEUILLE : on colle avant d'analyser, et l'écran d'analyse ne porte
        // plus de formulaire.
        awaitTag("entree-autres")
        compose.onNodeWithTag("entree-autres").performScrollTo().performClick()
        awaitTag("entree-coller")
        compose.onNodeWithTag("entree-coller").performScrollTo().performClick()
        awaitTag("saisie")
        compose.onNodeWithTag("saisie").performTextInput(missedMate)
        compose.onNodeWithTag("charger").performClick()
        awaitTag("coup-0")
    }

    /**
     * Le plateau d'analyse SE JOUE : on y pose un coup pour voir ce qu'il
     * donne, et la ligne affichée s'allonge. Il était inerte — la seule façon
     * d'explorer était de toucher une pastille de candidat, donc on ne pouvait
     * essayer que ce que le moteur proposait déjà.
     */
    @Test fun lePlateauDAnalyseSeJoue() {
        loadGame()
        // La partie fait huit demi-coups : on se place au dernier, où c'est
        // aux Blancs, et on joue un coup À LA MAIN.
        awaitTag("coup-7", 60_000)
        compose.onNodeWithTag("coup-7").performClick()
        compose.waitForIdle()

        compose.onNodeWithTag("case-d2").performClick()
        compose.onNodeWithTag("case-d4").performClick()
        // Le coup s'ajoute à la ligne : un neuvième demi-coup apparaît.
        awaitTag("coup-8", 30_000)
    }

    /** La lecture automatique déroule la partie sans qu'on touche à rien. */
    @Test fun laLectureAutomatiqueDerouleLaPartie() {
        loadGame()
        compose.onNodeWithTag("debut").performClick()
        compose.waitForIdle()
        compose.onNodeWithTag("lecture").performClick()

        // Le bouton devient « pause » : la lecture est partie.
        compose.waitUntil(10_000) {
            compose.onAllNodesWithContentDescription("Mettre en pause")
                .fetchSemanticsNodes().isNotEmpty()
        }
        // Et elle avance : un coup par seconde, donc le premier est passé.
        compose.waitUntil(20_000) {
            compose.onAllNodesWithTag("coup-0").fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithTag("lecture").performClick()
        compose.waitUntil(10_000) {
            compose.onAllNodesWithContentDescription("Lire la partie")
                .fetchSemanticsNodes().isNotEmpty()
        }
    }

    @Test fun laRevueClasseLesCoupsEtDonneUnePrecision() {
        loadGame()

        // La revue part TOUTE SEULE au chargement : sa progression s'affiche,
        // puis les deux précisions remplacent la phrase d'invite.
        awaitTag("precision", 300_000)

        // Le bandeau ne suffit pas : il s'affiche aussi avec un bilan VIDE.
        // Ce qu'on veut, c'est un chiffre — la preuve que le moteur a répondu
        // sur les neuf positions et que la classification a tourné.
        val chiffres = textOf("precision")
        require(chiffres.contains("%") && chiffres.any { it.isDigit() }) {
            "précision attendue, obtenu « $chiffres »"
        }

        compose.onNodeWithTag("menu-analyse").performClick()
        compose.waitForIdle()
        compose.onNodeWithTag("bilan").performClick()
        awaitTag("feuille-bilan", 20_000)
        compose.onNodeWithTag("feuille-bilan").assertIsDisplayed()
    }

    /**
     * Le cache disque : la même partie rouverte s'affiche classifiée SANS
     * repasser par le moteur — la précision est là avant qu'une revue ait eu
     * le temps d'évaluer une seule position.
     */
    @Test fun laRevueEstEnCacheEntreDeuxOuvertures() {
        loadGame()
        awaitTag("precision", 300_000)
        val premiere = textOf("precision")

        compose.onNodeWithTag("retour").performClick()
        compose.onNodeWithTag("retour").performClick()
        loadGame()
        awaitTag("precision", 3_000)
        require(textOf("precision") == premiere) { "le cache devrait rendre le même bilan : « ${textOf("precision")} » vs « $premiere »" }
    }

    @Test fun lesFautesDeviennentDesPuzzles() {
        loadGame()
        awaitTag("precision", 300_000)
        // La précision peut s'afficher AVANT la fin de la revue : la première
        // position évaluée suffit à en calculer une, et la revue repart
        // ensuite pour les autres. Or « Créer des puzzles » est désactivé
        // pendant une revue — le tap partait alors dans le vide, et le test
        // attendait une boîte que personne n'allait ouvrir.
        awaitNoTag("revue-en-cours", 300_000)

        // « Créer des puzzles » est DÉSACTIVÉ tant que l'app travaille — une
        // revue peut repartir pour une position manquante juste après que la
        // précision s'est affichée. On rouvre donc le menu jusqu'à ce que
        // l'entrée réponde, comme le ferait quelqu'un devant l'écran.
        compose.waitUntil(300_000) {
            compose.onNodeWithTag("menu-analyse").performClick()
            compose.waitForIdle()
            val ready = compose.onAllNodes(
                hasTestTag("creer-puzzles") and isEnabled()
            ).fetchSemanticsNodes().isNotEmpty()
            if (ready) compose.onNodeWithTag("creer-puzzles").performClick()
            else compose.onNodeWithTag("retourner").performClick()   // referme le menu
            ready
        }
        awaitTag("puzzles-crees", 300_000)
        // Le mat manqué donne son puzzle : la boîte annonce un nombre, pas un
        // « aucune position ».
        val message = textOf("puzzles-crees")
        require(message.contains("1 puzzle")) { "la boîte annonce : « $message »" }
    }
}
