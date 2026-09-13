package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith

/**
 * Un répertoire personnel, de bout en bout : collé, importé, listé en tête,
 * ouvert dans le lecteur, puis supprimé.
 */
@RunWith(AndroidJUnit4::class)
class RepertoireImportTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    private fun awaitTag(tag: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) { compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }

    private fun awaitText(text: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            // Les en-têtes de section s'affichent en CAPITALES.
            compose.onAllNodesWithText(text, substring = true, ignoreCase = true).fetchSemanticsNodes().isNotEmpty()
        }

    @Test fun unRepertoireColleSeRetrouveEnTeteDeListe() {
        compose.onNodeWithTag("mode-openings").performScrollTo().performClick()
        awaitTag("compte")
        compose.onNodeWithTag("ajouter-repertoire").performClick()
        awaitTag("importer")

        // Un PGN avec une VARIANTE et un nom d'étude : le nom se devine, la
        // variante devient une branche.
        compose.onNodeWithTag("import-pgn").performScrollTo()
            .performTextInput("[Event \"Ma Scandinave: Chapitre 1\"]\n\n1. e4 d5 2. exd5 Qxd5 (2... Nf6 3. d4) 3. Nc3 *")
        compose.onNodeWithTag("importer").performScrollTo().performClick()

        // De retour sur la liste, le répertoire est en tête, sous son nom.
        awaitText("Mes répertoires")
        awaitText("Ma Scandinave")
        compose.onNodeWithText("Ma Scandinave").performScrollTo().performClick()

        // Le lecteur l'ouvre comme un cours embarqué : racine, puis les suites.
        awaitTag("racine")
        compose.onNodeWithTag("coup-e2e4").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("retour").performClick()

        // Et il se supprime depuis la liste — la confirmation dit ce qui reste.
        awaitText("Ma Scandinave")
        compose.onNodeWithContentDescription("Actions du répertoire").performScrollTo().performClick()
        compose.onNodeWithText("Supprimer").performClick()
        awaitTag("supprimer-confirmer", 10_000)
        compose.onNodeWithTag("supprimer-confirmer").performClick()
        compose.waitUntil(10_000) {
            compose.onAllNodesWithText("Ma Scandinave", substring = true, ignoreCase = true).fetchSemanticsNodes().isEmpty()
        }
    }
}
