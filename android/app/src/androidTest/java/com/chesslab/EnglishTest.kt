package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.rules.RuleChain
import org.junit.Test
import org.junit.runner.RunWith

/**
 * L'app en ANGLAIS — la langue par défaut, celle que verra tout téléphone
 * qu'on ne traduit pas.
 *
 * Le reste de la suite tourne en français ; ce test-ci existe pour qu'une
 * clé oubliée dans `values/` se voie, plutôt que de n'apparaître qu'aux
 * utilisateurs anglophones.
 */
@RunWith(AndroidJUnit4::class)
class EnglishTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule("en")).around(compose)

    /** L'accueil défile : on fait venir la tuile avant de la toucher. */
    private fun openMode(tag: String) {
        compose.onNodeWithTag("mode-$tag").performScrollTo().performClick()
    }

    private fun awaitText(text: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text, substring = true, ignoreCase = true)
                .fetchSemanticsNodes().isNotEmpty()
        }

    @Test fun theHomeSpeaksEnglish() {
        compose.onNodeWithText("Play, analyze, improve.").assertIsDisplayed()
        compose.onNodeWithText("Computer").assertIsDisplayed()
        compose.onNodeWithText("2 players").assertIsDisplayed()
        // La grille est paresseuse : les tuiles du bas se font venir.
        compose.onNodeWithText("Winning endings").performScrollTo().assertIsDisplayed()
    }

    @Test fun theCharactersSpeakEnglish() {
        openMode("play")
        awaitText("Start", 120_000)
        // Le surnom, l'accroche et les étiquettes viennent tous du module
        // maia : s'ils sont en français ici, c'est que ses ressources manquent.
        compose.onNodeWithText("Tornado", substring = true).assertIsDisplayed()
        compose.onNodeWithTag("adversaire-lea").performClick()
        awaitText("Attack")
        awaitText("Castles on the opposite wing")
        awaitText("Human scale")
    }

    @Test fun theCoursesSpeakEnglish() {
        openMode("openings")
        awaitText("Today's review")
        compose.onNodeWithText("Hard positions").assertIsDisplayed()
        // La carte d'introduction de la liste, en anglais.
        awaitText("Every position, dissected")
        // Et le CONTENU des cours suit la langue, pas seulement le décor :
        // les fichiers portent les deux, et n'en lire qu'un serait pire que
        // de ne rien traduire. Une ouverture BLANCHE : la liste groupe par
        // camp, et le groupe noir est sous la ligne de flottaison.
        awaitText("a Dutch with White")
    }

    @Test fun theHelpSpeaksEnglish() {
        compose.onNodeWithTag("aide").performClick()
        awaitText("The nine characters")
        // Les sections du bas ne sont pas à l'écran : on les fait venir.
        compose.onNodeWithText("Spaced repetition").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("What stays offline").performScrollTo().assertIsDisplayed()
    }

    @Test fun theVariantsSpeakEnglish() {
        openMode("variants")
        awaitText("King of the Hill")
        compose.onNodeWithText("Racing Kings").assertIsDisplayed()
        compose.onNodeWithText("Antichess").assertIsDisplayed()
    }
}
