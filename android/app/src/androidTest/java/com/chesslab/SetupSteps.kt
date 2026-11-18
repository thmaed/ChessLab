package com.chesslab

import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToNode

/**
 * Les gestes de l'écran « Nouvelle partie » refondu (18/11/2026), pendant de `NewGameSetupSteps` (iOS) :
 * l'adversaire se choisit dans une bande de portraits qui défile de côté, et chaque ligne de la carte
 * « Partie » (cadence, aveugle, départ, livre) s'ouvre en menu.
 */
fun ComposeTestRule.chooseOpponent(id: String) {
    onNodeWithTag("bande-adversaires").performScrollTo().performScrollToNode(hasTestTag("adversaire-$id"))
    onNodeWithTag("adversaire-$id").performClick()
    waitForIdle()
}

/** Ouvre le menu [menu] et y touche l'entrée [item]. */
fun ComposeTestRule.pickFromMenu(menu: String, item: String) {
    onNodeWithTag(menu).performScrollTo().performClick()
    waitUntil(5_000) { onAllNodesWithTag(item).fetchSemanticsNodes().isNotEmpty() }
    onNodeWithTag(item).performScrollTo().performClick()
    waitForIdle()
}
