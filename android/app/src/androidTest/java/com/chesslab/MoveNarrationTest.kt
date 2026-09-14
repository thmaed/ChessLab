package com.chesslab

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.ui.MoveNarration
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

/**
 * La verbalisation d'un coup, telle qu'un lecteur d'écran l'entendra. Elle
 * vit ici et non sur la JVM parce qu'elle lit de vraies ressources : c'est
 * précisément ce qu'on veut vérifier — que rien n'est écrit en dur.
 */
@RunWith(AndroidJUnit4::class)
class MoveNarrationTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
        .createConfigurationContext(
            android.content.res.Configuration(
                InstrumentationRegistry.getInstrumentation().targetContext.resources.configuration
            ).apply { setLocale(java.util.Locale.FRENCH) }
        )

    private fun say(san: String) = MoveNarration.describe(context, san)

    @Test fun unPionSeDitPion() {
        assertEquals("pion en e 4", say("e4"))
    }

    @Test fun unePieceSeNommeEtLaCaseSEpelle() {
        assertEquals("cavalier en f 3", say("Nf3"))
    }

    @Test fun unePriseSeDit() {
        assertEquals("fou prend en f 7, échec", say("Bxf7+"))
    }

    @Test fun lesRoquesOntLeurNom() {
        assertEquals("petit roque", say("O-O"))
        assertEquals("grand roque", say("O-O-O"))
    }

    @Test fun laPromotionSAnnonce() {
        assertEquals("pion en e 8, promotion en dame", say("e8=Q"))
    }

    @Test fun leMatSeDitEnDernier() {
        assertEquals("dame prend en f 7, échec et mat", say("Qxf7#"))
    }

    @Test fun lAnnonceDitQuiJoue() {
        assertEquals(
            "Blancs : pion en e 4",
            MoveNarration.announcement(context, "Blancs", "e4"),
        )
    }
}
