package com.chesslab

import android.app.LocaleManager
import android.os.Build
import android.os.LocaleList
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.rules.TestRule
import org.junit.runner.Description
import org.junit.runners.model.Statement

/**
 * Fixe la langue de l'app AVANT que l'activité démarre.
 *
 * Sans cela, les tests dépendraient de la langue de l'émulateur : les mêmes
 * assertions passeraient sur une machine réglée en français et échoueraient
 * sur une autre en anglais. Ce qu'on teste ici, ce n'est pas la traduction —
 * c'est le comportement ; la langue doit donc être une constante du décor.
 *
 * À CHAÎNER AVANT la règle Compose (`RuleChain.outerRule`), sinon l'activité
 * est déjà là quand on change d'avis, et le système la recrée au milieu du
 * test.
 */
class LanguageRule(private val tag: String = "fr") : TestRule {

    override fun apply(base: Statement, description: Description): Statement =
        object : Statement() {
            override fun evaluate() {
                // La visite guidée se proposerait à CHAQUE installation de
                // test et recouvrirait l'écran d'un voile qui avale les
                // taps : on la marque vue avant que l'activité démarre. Le
                // test qui la vérifie la rejoue depuis l'Aide.
                val target = InstrumentationRegistry.getInstrumentation().targetContext
                com.chesslab.discovery.DiscoveryTourMemory.markSeen(target)
                // Idem pour le court parcours des nouveautés 2.0 (mise à jour depuis la 1.x).
                com.chesslab.discovery.DiscoveryTourMemory.markWhatsNewSeen(target)
                // Une partie laissée en cours par le test précédent ferait demander « remplacer ? »
                // à chaque « Commencer » : chaque test repart sans partie en cours.
                kotlinx.coroutines.runBlocking {
                    com.chesslab.library.LibraryDatabase.get(target).autosaves().clear("engine")
                }
                val before = set(tag)
                try {
                    base.evaluate()
                } finally {
                    set(before)
                }
            }
        }

    /** Applique la langue et rend celle qui régnait avant. */
    private fun set(tag: String): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return ""
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val manager = context.getSystemService(LocaleManager::class.java) ?: return ""
        val previous = manager.applicationLocales.toLanguageTags()
        manager.applicationLocales =
            if (tag.isEmpty()) LocaleList.getEmptyLocaleList() else LocaleList.forLanguageTags(tag)
        return previous
    }
}
