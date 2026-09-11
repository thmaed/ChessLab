package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.library.LibraryDatabase
import kotlinx.coroutines.runBlocking
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * L'entraînement par répétition espacée, de bout en bout : la séance se
 * construit, les trois verdicts (juste, variante, hors répertoire) tombent
 * comme il faut, et la progression FSRS ARRIVE VRAIMENT en base.
 *
 * Chaque test repart d'une base vide : la file dépend de ce qui a déjà été
 * révisé, donc un test qui hériterait de l'état d'un autre mentirait.
 */
@RunWith(AndroidJUnit4::class)
class TrainingTest {

    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    private val dao by lazy {
        LibraryDatabase.get(InstrumentationRegistry.getInstrumentation().targetContext).training()
    }

    @Before fun cleanSlate() = runBlocking {
        dao.clearProgress()
        dao.clearLogs()
    }

    private fun awaitText(text: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text, substring = true).fetchSemanticsNodes().isNotEmpty()
        }

    private fun awaitTag(tag: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
        }

    /** Ouvre la séance quotidienne sur le cours italien, via les ouvertures. */
    private fun openDailyOnItalian() {
        compose.onNodeWithTag("mode-Ouvertures").performClick()
        awaitTag("seance-quotidienne")
        compose.onNodeWithTag("seance-quotidienne").performClick()
        awaitTag("consigne")
    }

    private fun play(from: String, to: String) {
        compose.onNodeWithTag("case-$from").performClick()
        compose.onNodeWithTag("case-$to").performClick()
    }

    @Test fun laSeanceDuJourSeConstruitEtSePresente() {
        openDailyOnItalian()
        compose.onNodeWithTag("cours-en-cours").assertIsDisplayed()
        compose.onNodeWithTag("restant").assertIsDisplayed()
        awaitText("À vous de jouer")
    }

    @Test fun unCoupHorsRepertoireMontreLeBonCoup() {
        openDailyOnItalian()
        play("a2", "a3")
        awaitTag("bon-coup")
        compose.onNodeWithText("La suite est e4.", substring = true).assertIsDisplayed()

        // …et « continuer » joue le bon coup pour poursuivre la ligne.
        compose.onNodeWithTag("continuer").performClick()
        awaitTag("coups-joues")
        compose.waitUntil(20_000) {
            compose.onAllNodesWithText("1. e4 e5", substring = true).fetchSemanticsNodes().isNotEmpty()
        }
    }

    @Test fun unCoupJusteEnchaineSansClic() {
        openDailyOnItalian()
        play("e2", "e4")
        // Le partenaire répond tout seul : la ligne avance de deux demi-coups.
        compose.waitUntil(20_000) {
            compose.onAllNodesWithText("1. e4 e5", substring = true).fetchSemanticsNodes().isNotEmpty()
        }
        awaitText("À vous de jouer")
    }

    @Test fun uneVarianteDuRepertoireLaisseChoisir() {
        openDailyOnItalian()
        play("e2", "e4"); awaitText("1. e4 e5")
        play("g1", "f3"); awaitText("2. Nf3 Nc6")
        play("f1", "c4"); awaitText("3. Bc4 Bc5")
        play("b2", "b4")                       // le gambit Evans : au répertoire, pas principal

        awaitTag("variante")
        compose.onNodeWithTag("rester-principale").performClick()
        awaitTag("note")
        compose.onNodeWithText("Aussi jouable : b4.", substring = true).assertIsDisplayed()
    }

    @Test fun laVarianteSeJoueSiOnLaChoisit() {
        openDailyOnItalian()
        play("e2", "e4"); awaitText("1. e4 e5")
        play("g1", "f3"); awaitText("2. Nf3 Nc6")
        play("f1", "c4"); awaitText("3. Bc4 Bc5")
        play("b2", "b4")
        awaitTag("variante")
        compose.onNodeWithTag("jouer-variante").performClick()
        awaitText("4. b4")
    }

    @Test fun lIndiceAllumeLeBonCoup() {
        openDailyOnItalian()
        awaitText("À vous de jouer")
        compose.onNodeWithTag("indice").performClick()
        // L'indice ne dit rien : il ALLUME les cases. On vérifie donc l'effet
        // qu'il a sur la note — un coup soufflé ne vaut jamais mieux que
        // « Difficile ».
        play("e2", "e4")
        compose.waitUntil(20_000) {
            runBlocking { dao.recentLogs(1).firstOrNull()?.ratingRaw == 2 }
        }
    }

    @Test fun uneErreurEstNoteeEncoreEtReplanifieeADemain() {
        openDailyOnItalian()
        play("a2", "a3")
        awaitTag("bon-coup")
        compose.waitUntil(20_000) { runBlocking { dao.recentLogs(1).isNotEmpty() } }

        val log = runBlocking { dao.recentLogs(1).first() }
        assert(log.ratingRaw == FsrsAgain) { "attendu « encore », reçu ${log.ratingRaw}" }
        assert(log.scheduledDays >= 1.0) { "une position ratée revient au plus tôt demain" }

        val progress = runBlocking { dao.allProgress() }
        assert(progress.size == 1) { "une seule position notée, reçu ${progress.size}" }
        // Rater une position JAMAIS VUE n'est pas un oubli au sens de FSRS :
        // `lapses` reste à zéro, et c'est l'ÉTAT qui dit « pas acquise ».
        assert(progress.first().lapses == 0) { "reçu ${progress.first().lapses} rechutes" }
        assert(progress.first().stateRaw == 1) { "attendu « apprentissage », reçu ${progress.first().stateRaw}" }
        assert(progress.first().dueAt != null && progress.first().dueAt!! > System.currentTimeMillis())
    }

    @Test fun unCoupJusteEstNoteBienEtCompte() {
        openDailyOnItalian()
        play("e2", "e4")
        compose.waitUntil(20_000) { runBlocking { dao.recentLogs(1).isNotEmpty() } }
        val log = runBlocking { dao.recentLogs(1).first() }
        assert(log.ratingRaw == FsrsGood) { "attendu « bien », reçu ${log.ratingRaw}" }
        assert(runBlocking { dao.studiedCount() } == 1)
    }

    @Test fun lesPositionsDifficilesSontVidesAuDepart() {
        compose.onNodeWithTag("mode-Ouvertures").performClick()
        awaitTag("seance-difficiles")
        compose.onNodeWithTag("seance-difficiles").performClick()
        awaitTag("rien-a-reviser")
    }

    @Test fun uneErreurPeuplelesPositionsDifficiles() {
        openDailyOnItalian()
        play("a2", "a3")
        compose.waitUntil(20_000) {
            runBlocking { dao.allProgress().any { com.chesslab.training.TrainingQueue.isHard(it.snapshot) } }
        }

        // Retour à la liste, puis la séance des difficiles : la position ratée
        // doit s'y trouver.
        compose.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        awaitTag("seance-difficiles")
        compose.onNodeWithTag("seance-difficiles").performClick()
        awaitTag("consigne")
        compose.onNodeWithTag("cours-en-cours").assertIsDisplayed()
    }

    @Test fun entrainerUneLigneDepuisLeCours() {
        compose.onNodeWithTag("mode-Ouvertures").performClick()
        awaitTag("recherche")
        compose.onNodeWithTag("recherche").performTextInput("Italian")
        awaitText("Italian Game")
        compose.onNodeWithText("Italian Game", substring = true).performClick()
        awaitTag("entrainer")
        compose.onNodeWithTag("entrainer").performClick()
        awaitTag("consigne")
        awaitText("À vous de jouer")
    }

    @Test fun laProgressionRendCompteDeLaMemorisation() {
        openDailyOnItalian()
        play("a2", "a3"); awaitTag("bon-coup")
        compose.onNodeWithTag("continuer").performClick()
        awaitText("1. e4 e5")
        play("g1", "f3"); awaitText("2. Nf3 Nc6")
        compose.waitUntil(20_000) { runBlocking { dao.studiedCount() == 2 } }

        compose.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        compose.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        awaitTag("progression")
        compose.onNodeWithTag("progression").performClick()

        awaitText("Mémorisation")
        // Deux positions vues, une ratée : c'est ce que l'écran doit dire, et
        // aucune n'est encore due, donc il annonce la prochaine échéance.
        awaitText("à consolider")
        compose.onNodeWithTag("prochaine-revision").assertIsDisplayed()
    }

    private companion object {
        const val FsrsAgain = 1
        const val FsrsGood = 3
    }
}