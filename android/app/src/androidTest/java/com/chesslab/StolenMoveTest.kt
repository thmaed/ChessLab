package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain

/**
 * Le Coup Volé : un jeton tous les N coups, et DEUX coups d'affilée quand on
 * le dépense. C'est la seule chose qui distingue la variante des échecs
 * ordinaires, et aucun moteur ne sait l'exprimer — donc rien d'autre que ce
 * test ne la vérifie sur l'appareil.
 */
class StolenMoveTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    /**
     * Les réglages d'une variante se RETIENNENT d'une partie à l'autre : sans
     * ce nettoyage, un test hérite de ce que le précédent a coché.
     */
    @Before fun oublieLesReglagesPrecedents() {
        androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext
            .getSharedPreferences("play", android.content.Context.MODE_PRIVATE)
            .edit().clear().commit()
    }

    private fun awaitText(text: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text, substring = true, ignoreCase = true)
                .fetchSemanticsNodes().isNotEmpty()
        }

    /** Le compteur de demi-coups, lu tel qu'il s'affiche. */
    private fun demiCoups(): Int =
        compose.onNodeWithTag("compteur").fetchSemanticsNode()
            .config[androidx.compose.ui.semantics.SemanticsProperties.Text]
            .first().text.filter { it.isDigit() }.toIntOrNull() ?: 0

    /**
     * Joue un coup et attend que le compteur ait ATTEINT [attendus].
     *
     * « Atteint » et non « vaut » : l'ordinateur gagne des jetons lui aussi, et
     * quand il en dépense un il joue DEUX coups d'affilée — le compteur saute
     * alors de deux, et une égalité stricte manquerait le moment où il vaut la
     * valeur attendue. C'est le jeu qui veut ça, pas un défaut.
     */
    private fun joue(from: String, to: String, attendus: Int) {
        compose.onNodeWithTag("case-$from").performClick()
        compose.onNodeWithTag("case-$to").performClick()
        compose.waitUntil(90_000) { demiCoups() >= attendus }
    }

    @Test fun leJetonDonneDeuxCoupsDAffilee() {
        compose.onNodeWithTag("mode-variants").performScrollTo().performClick()
        compose.onNodeWithTag("variante-stolenmove").performScrollTo().performClick()

        // Un jeton tous les QUATRE coups : réglé AVANT de commencer, comme
        // tout le reste depuis le 15/09 — et cela abrège d'autant ce test.
        repeat(2) { compose.onNodeWithTag("intervalle-moins").performScrollTo().performClick() }
        compose.onNodeWithTag("intervalle").assertTextEquals("4")
        // L'alerte de coup risqué est COUPÉE : quatre poussées de flanc
        // d'affilée la déclenchent pour de bon, et son dialogue barrerait le
        // plateau au beau milieu du test. C'est aussi la preuve que le
        // réglage sert à quelque chose.
        compose.onNodeWithTag("aide-alerte").performScrollTo().performClick()
        compose.onNodeWithTag("commencer").performClick()
        awaitText("À vous de jouer", 30_000)

        // Quatre coups de part et d'autre — des poussées de flanc, qui
        // restent légales quoi que l'ordinateur réponde au centre.
        joue("a2", "a3", 2)
        joue("h2", "h3", 4)
        joue("b2", "b3", 6)
        joue("g2", "g3", 8)

        // Le quatrième coup a donné le jeton.
        compose.onNodeWithTag("jeton").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("depenser").performScrollTo().performClick()
        awaitText("Jeton dépensé", 10_000)

        // Premier coup du tour double : l'ordinateur ne répond PAS.
        joue("a3", "a4", 9)
        awaitText("second coup", 10_000)

        // Second coup : le tour s'achève, et l'ordinateur reprend la main.
        joue("h3", "h4", 10)
        compose.waitUntil(90_000) { demiCoups() >= 11 }
    }
}
