package com.chesslab

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.core.app.ApplicationProvider
import com.chesslab.library.LibraryDatabase
import com.chesslab.puzzles.WoodpeckerPlan
import com.chesslab.puzzles.WoodpeckerProgram
import kotlinx.coroutines.runBlocking
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith

/** A5 / C7 : la carte « Séance du jour » de l'accueil ouvre l'écran des étapes. Pendant de `DailySessionUITests`. */
@RunWith(AndroidJUnit4::class)
class DailySessionTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    @Test fun laCarteOuvreLaSeance() {
        compose.waitUntil(20_000) { compose.onAllNodesWithTag("seance-du-jour").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("seance-du-jour").performScrollTo().performClick()
        compose.waitUntil(10_000) { compose.onAllNodesWithTag("ecran-seance").fetchSemanticsNodes().isNotEmpty() }
        // La finale du jour est toujours proposée.
        compose.waitUntil(10_000) { compose.onAllNodesWithTag("etape-endgame").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("etape-openings").assertExists()
    }

    /** Le plafond d'ouvertures se règle sur l'écran même de la séance, et se retient. */
    @Test fun lePlafondDOuverturesSeRegleSurLEcranDeLaSeance() {
        compose.waitUntil(20_000) { compose.onAllNodesWithTag("seance-du-jour").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("seance-du-jour").performScrollTo().performClick()
        compose.waitUntil(10_000) { compose.onAllNodesWithTag("ecran-seance").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("seance-ouvertures-2").performScrollTo().performClick()
        compose.waitUntil(10_000) { com.chesslab.settings.SettingsStore.state.value.dailyOpeningsCap == 2 }
        compose.onNodeWithTag("seance-ouvertures-5").performScrollTo().performClick()
        compose.waitUntil(10_000) { com.chesslab.settings.SettingsStore.state.value.dailyOpeningsCap == 5 }
    }

    /** Un cycle Woodpecker en cours (suggestion d'Olivier) est une étape de la séance, et la rouvre au bon programme. */
    @Test fun unCycleWoodpeckerEnCoursEstUneEtapeDeLaSeance() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        context.getSharedPreferences("training_days", android.content.Context.MODE_PRIVATE).edit().remove("woodpecker_day").commit()
        val dao = LibraryDatabase.get(context).woodpecker()
        val items = (1..5).map { WoodpeckerPlan.Item("8/8/8/8/8/8/8/K6k w - - 0 $it", listOf("a1a2"), "tactic", null, 0) }
        val plan = WoodpeckerPlan.start(items, now = 0)!!
        runBlocking {
            dao.clear()
            dao.put(WoodpeckerProgram("essai-seance", 0L, 1L, "essai", plan.toJson()))
        }
        try {
            compose.waitUntil(20_000) { compose.onAllNodesWithTag("seance-du-jour").fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithTag("seance-du-jour").performScrollTo().performClick()
            compose.waitUntil(10_000) { compose.onAllNodesWithTag("etape-woodpecker").fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithTag("etape-woodpecker").performScrollTo().performClick()
            // Le programme s'ouvre sur son premier puzzle : le chrono du Woodpecker est là.
            compose.waitUntil(20_000) { compose.onAllNodesWithTag("woodpecker-chrono").fetchSemanticsNodes().isNotEmpty() }
        } finally {
            runBlocking { dao.clear() }
        }
    }
}
