package com.chesslab

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith

/**
 * Le Laboratoire en Chess960, sur l'appareil : une vraie partie, jouée par le
 * vrai moteur, de bout en bout. Pendant de `LabChess960SeriesTests` (iOS).
 *
 * Les règles du tirage sont prouvées sur la JVM (`LabChess960Test`) ; ce qui ne
 * l'est qu'ici, c'est que Fairy-Stockfish arbitre et joue la série, que la partie
 * se termine, et qu'elle s'ouvre dans l'analyse de variante.
 */
@RunWith(AndroidJUnit4::class)
class LabChess960SeriesTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    private fun present(tag: String) = compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()

    @Test fun uneSerieDeChess960SeJoueEtSeRevoitDansSonAnalyse() {
        compose.onNodeWithTag("mode-lab").performScrollTo().performClick()
        compose.waitUntil(60_000) { present("bilan-detaille") }

        // Une seule partie, sans animation : on veut le résultat, pas le spectacle.
        repeat(4) { compose.onNodeWithTag("nombre-parties-moins").performScrollTo().performClick() }
        compose.onNodeWithTag("animer").performScrollTo().performClick()
        compose.onNodeWithTag("chess960").performScrollTo().performClick()

        // La position de la partie est annoncée AVANT le premier coup.
        compose.onNodeWithTag("chess960-position").assertExists()

        compose.onNodeWithTag("lancer").performScrollTo().performClick()
        // La partie se termine d'elle-même (abandon, mat ou nulle) : « Analyser la dernière partie » apparaît.
        compose.waitUntil(300_000) { present("analyser-derniere") }

        compose.onNodeWithTag("analyser-derniere").performScrollTo().performClick()
        // L'analyse de VARIANTE s'ouvre sur la partie, avec sa barre de navigation.
        compose.waitUntil(60_000) { present("compteur-demi-coups") }
        compose.onNodeWithTag("compteur-demi-coups").assertExists()
    }
}
