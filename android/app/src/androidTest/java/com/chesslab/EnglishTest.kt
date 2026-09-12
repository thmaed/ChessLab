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

    private fun awaitText(text: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text, substring = true).fetchSemanticsNodes().isNotEmpty()
        }

    @Test fun theHomeSpeaksEnglish() {
        compose.onNodeWithText("Play · Analyse · Train · Experiment").assertIsDisplayed()
        compose.onNodeWithText("Against the computer").assertIsDisplayed()
        compose.onNodeWithText("Two players").assertIsDisplayed()
        compose.onNodeWithText("Winning endings").assertIsDisplayed()
    }

    @Test fun theCharactersSpeakEnglish() {
        compose.onNodeWithTag("mode-play").performClick()
        awaitText("Your turn", 120_000)
        // Le surnom, l'accroche et les étiquettes viennent tous du module maia :
        // s'ils sont en français ici, c'est que ses ressources manquent.
        compose.onNodeWithText("Tornado", substring = true).assertIsDisplayed()
        compose.onNodeWithText("Attack", substring = true).assertIsDisplayed()
        compose.onNodeWithText("Level on Maia's human scale", substring = true).assertIsDisplayed()
    }

    @Test fun theCoursesSpeakEnglish() {
        compose.onNodeWithTag("mode-openings").performClick()
        awaitText("Today's review")
        compose.onNodeWithText("Hard positions").assertIsDisplayed()
        // Le décompte n'arrive qu'une fois le catalogue lu.
        awaitText("openings")
        // Et le CONTENU des cours suit la langue, pas seulement le décor :
        // les fichiers portent les deux, et n'en lire qu'un serait pire que
        // de ne rien traduire.
        awaitText("A pesky countergambit")
    }

    @Test fun theHelpSpeaksEnglish() {
        compose.onNodeWithTag("aide").performClick()
        awaitText("The nine characters")
        // Les sections du bas ne sont pas à l'écran : on les fait venir.
        compose.onNodeWithText("Spaced repetition").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("What stays offline").performScrollTo().assertIsDisplayed()
    }

    @Test fun theVariantsSpeakEnglish() {
        compose.onNodeWithTag("mode-variants").performClick()
        awaitText("King of the Hill")
        compose.onNodeWithText("Racing Kings").assertIsDisplayed()
        compose.onNodeWithText("Antichess").assertIsDisplayed()
    }
}
