package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextClearance
import androidx.compose.ui.test.performTextInput
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.courses.OpeningPgnImporter
import com.chesslab.courses.UserOpeningStore
import com.chesslab.transfer.TransferService
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import java.io.File

/**
 * L'éditeur de répertoire, de bout en bout : jouer un coup l'AJOUTE, la
 * suppression retire la variante, le renommage suit, et le fichier est écrit
 * à chaque geste. Puis le voyage : un répertoire personnel entre dans le
 * fichier `.clab` et en ressort intact.
 */
class RepertoireEditTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    /**
     * Un répertoire à soi, posé avant l'écran : l'éditeur ne s'ouvre que sur
     * un cours PERSONNEL, et un essai précédent ne doit pas en laisser
     * traîner un second qui rendrait l'assertion ambiguë.
     */
    private lateinit var id: String

    @Before fun unRepertoireAMoi() {
        UserOpeningStore.catalog().forEach { UserOpeningStore.delete(it.id) }
        id = UserOpeningStore.newIdentifier()
        val course = OpeningPgnImporter
            .course("1. e4 e5 2. Nf3 *", "Ma ligne", "white", id, "À moi") { "Chapitre $it" }
            .course
        UserOpeningStore.save(course)
    }

    /**
     * Et on repart sans rien laisser.
     *
     * Un répertoire personnel oublié ici n'est pas un détail : il entre dans
     * la séance quotidienne et fait échouer les tests d'entraînement, qui
     * attendent une ligne précise — trois d'entre eux sont tombés en 60 s
     * d'attente avant que ce nettoyage existe. Et deux répertoires du même nom
     * rendent ambigu le `onNodeWithText` de l'import.
     */
    @After fun onNeLaissePasDeTraces() {
        UserOpeningStore.catalog().forEach { UserOpeningStore.delete(it.id) }
    }

    private fun awaitTag(tag: String, timeoutMs: Long = 20_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
        }

    private fun awaitText(text: String, timeoutMs: Long = 20_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text, substring = true, ignoreCase = true)
                .fetchSemanticsNodes().isNotEmpty()
        }

    private fun openEditor() {
        compose.onNodeWithTag("mode-openings").performScrollTo().performClick()
        awaitTag("cours-$id")
        compose.onNodeWithTag("actions-$id").performScrollTo().performClick()
        compose.waitForIdle()
        compose.onNodeWithTag("modifier-$id").performClick()
        awaitTag("consigne")
    }

    @Test fun jouerUnCoupLAjouteAuRepertoire() {
        openEditor()
        // 1.e4 est déjà là : on l'ouvre, puis on greffe une DEUXIÈME réponse.
        compose.onNodeWithTag("entrer-e2e4").performScrollTo().performClick()
        awaitTag("arete-e7e5")

        // c5 n'existe pas encore : le jouer sur l'échiquier l'ajoute.
        compose.onNodeWithTag("case-c7").performClick()
        compose.onNodeWithTag("case-c5").performClick()
        compose.waitForIdle()

        // Le fichier, pas seulement l'écran : l'enregistrement est immédiat.
        val saved = UserOpeningStore.course(id)!!
        val afterE4 = com.chesslab.courses.OpeningCourseValidator
            .resultingKey("e2e4", com.chesslab.courses.CourseRepository.key(chesskit.Position.standard))!!
        assertTrue(
            "c5 devrait être écrit sur le disque",
            saved.moves(afterE4).any { it.uci == "c7c5" },
        )
        // Et l'éditeur y est ENTRÉ : on continue sa ligne sans retaper le coup.
        awaitText("1. e4")
        awaitText("c5")
    }

    @Test fun supprimerUneVarianteLaRetireDuFichier() {
        openEditor()
        compose.onNodeWithTag("entrer-e2e4").performScrollTo().performClick()
        awaitTag("arete-e7e5")
        compose.onNodeWithTag("supprimer-e7e5").performScrollTo().performClick()
        compose.waitForIdle()

        val saved = UserOpeningStore.course(id)!!
        val afterE4 = com.chesslab.courses.OpeningCourseValidator
            .resultingKey("e2e4", com.chesslab.courses.CourseRepository.key(chesskit.Position.standard))!!
        assertEquals(emptyList<String>(), saved.moves(afterE4).map { it.uci })
        // La suite devient inatteignable et disparaît : 2.Cf3 n'est plus là.
        assertEquals(2, saved.positions.size)
    }

    @Test fun renommerSuitJusquAuFichier() {
        openEditor()
        compose.onNodeWithTag("renommer").performClick()
        awaitTag("champ-nom")
        compose.onNodeWithTag("champ-nom").performTextClearance()
        compose.onNodeWithTag("champ-nom").performTextInput("Ma Sicilienne à moi")
        compose.onNodeWithTag("valider-nom").performClick()
        compose.waitForIdle()

        assertEquals("Ma Sicilienne à moi", UserOpeningStore.course(id)!!.name)
    }

    @Test fun unCommentaireSecritEtSeRelit() {
        openEditor()
        compose.onNodeWithTag("commenter-e2e4").performScrollTo().performClick()
        awaitTag("champ-commentaire")
        compose.onNodeWithTag("champ-commentaire").performTextInput("On occupe le centre.")
        compose.onNodeWithTag("valider-commentaire").performClick()
        compose.waitForIdle()

        val saved = UserOpeningStore.course(id)!!
        assertEquals("On occupe le centre.", saved.moves(saved.rootFEN).first().comment)
    }

    /**
     * Le voyage : un répertoire personnel part dans le `.clab` et revient
     * intact sur un appareil qui ne l'a pas. Réimporter le même fichier ne le
     * duplique pas — c'est l'identité du cours qui le dit.
     */
    @Test fun unRepertoirePersonnelVoyageDansLeFichier() = runBlocking {
        val file = File(context.cacheDir, "repertoires.clab").apply { delete() }
        TransferService.export(context, android.net.Uri.fromFile(file)).getOrThrow()

        // L'appareil d'en face ne l'a pas.
        UserOpeningStore.delete(id)
        assertNull(UserOpeningStore.course(id))

        val summary = TransferService.import(context, android.net.Uri.fromFile(file)).getOrThrow()
        assertEquals(1, summary.newRepertoires)
        val back = UserOpeningStore.course(id)
        assertNotNull("le répertoire devrait être revenu", back)
        assertEquals("Ma ligne", back!!.name)

        // Deux fois le même fichier ne fait pas deux répertoires.
        val again = TransferService.import(context, android.net.Uri.fromFile(file)).getOrThrow()
        assertEquals(0, again.newRepertoires)
        assertEquals(1, UserOpeningStore.catalog().count { it.id == id })
    }
}
