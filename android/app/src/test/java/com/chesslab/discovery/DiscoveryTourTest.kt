package com.chesslab.discovery

import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * La géométrie de la visite guidée — chaque règle ici est le contre-exemple
 * d'un bug déjà payé côté iOS, et ces tests sont la seule mémoire qui
 * survive aux relectures « simplificatrices ». Pendant de
 * `DiscoveryTourTests.swift`, mêmes chiffres.
 */
class DiscoveryGeometryTest {

    private val screen = Size(390f, 844f)

    @Test fun `le cote choisi est celui qui a le plus de place, pas la moitie du trou`() {
        // Cible HAUTE et GRANDE : son bord bas (560) dépasse le milieu de
        // l'écran (422). La mesure des deux côtés envoie la carte EN DESSOUS
        // (284 dp nets contre 41).
        val tallHigh = Rect(20f, 100f, 370f, 560f)
        assertEquals(DiscoveryGeometry.CardSide.below, DiscoveryGeometry.side(tallHigh, screen, 59f, 34f))
        // Symétrique : cible basse et grande → au-dessus.
        val tallLow = Rect(20f, 380f, 370f, 760f)
        assertEquals(DiscoveryGeometry.CardSide.above, DiscoveryGeometry.side(tallLow, screen, 59f, 34f))
    }

    @Test fun `une cible plus grande que l'ecran moins la reserve centre la carte`() {
        val oversized = Rect(20f, 240f, 370f, 940f)
        assertEquals(DiscoveryGeometry.CardSide.centered, DiscoveryGeometry.side(oversized, screen, 59f, 34f))
    }

    @Test fun `les insets comptent - une cible haute ne pousse plus la carte sous la barre d'etat`() {
        // 260 dp bruts au-dessus, mais 201 nets : sous la réserve de 250.
        val high = Rect(20f, 260f, 370f, 680f)
        assertNotEquals(DiscoveryGeometry.CardSide.above, DiscoveryGeometry.side(high, screen, 59f, 34f))
    }

    @Test fun `la fleche cede sa longueur avant que la carte cede sa hauteur`() {
        assertEquals(72f, DiscoveryGeometry.effectiveGap(600f))
        assertEquals(22f, DiscoveryGeometry.effectiveGap(260f))
        assertEquals(22f, DiscoveryGeometry.effectiveGap(0f))
        assertEquals(50f, DiscoveryGeometry.effectiveGap(300f))
    }

    @Test fun `le bow s'incline a l'oppose du bord le plus proche`() {
        assertEquals(-1f, DiscoveryGeometry.bowSign(350f, 390f))
        assertEquals(1f, DiscoveryGeometry.bowSign(60f, 390f))
        // Pile au centre : penche à droite (seuil volontairement à 0,55).
        assertEquals(1f, DiscoveryGeometry.bowSign(195f, 390f))
    }

    @Test fun `la fleche part du bord de la carte et arrive au bord du trou`() {
        val hole = Rect(20f, 100f, 370f, 200f)
        val arrow = DiscoveryGeometry.arrow(hole, screen, 59f, 34f)!!
        // Carte en dessous : la flèche descend du trou vers la carte.
        assertEquals(hole.bottom + 7f, arrow.endY)
        assertTrue(arrow.startY > arrow.endY)
        // Une carte centrée ne relie rien.
        assertEquals(null, DiscoveryGeometry.arrow(Rect(20f, 240f, 370f, 940f), screen, 59f, 34f))
    }
}

class DiscoveryTourStepsTest {

    @Test fun `les etapes forment trois sections ordonnees, ids croissants`() {
        val tour = DiscoveryTourController()
        assertEquals(11, tour.steps.size)
        assertEquals((0 until 11).toList(), tour.steps.map { it.id })
        // L'ordre du contrat : ce qu'on s'apprête à toucher, puis les
        // affichages, puis les autres écrans, et le « ? » qui ramène tout.
        assertEquals(DiscoverySpot.playTile, tour.steps.first().spot)
        assertEquals(DiscoverySpot.helpButton, tour.steps.last().spot)
        // Les étapes sans cible sont VOULUES — pas plus de trois.
        assertEquals(3, tour.steps.count { it.spot == null })
        // Les chips des variantes suivent le catalogue, et le titre les compte.
        val variants = tour.steps[8]
        assertTrue(variants.chips.size >= 7)
        assertEquals(variants.chips.size, variants.titleArg)
    }

    @Test fun `avancer au bout termine, passer compte comme vue`() {
        var seen = 0
        val tour = DiscoveryTourController(onSeen = { seen++ })
        tour.start()
        assertTrue(tour.isActive)
        repeat(tour.steps.size) { tour.advance() }
        assertFalse(tour.isActive)
        assertEquals(1, seen)

        tour.start(at = 5)
        assertEquals(5, tour.currentStepIndex)
        tour.goBack()
        assertEquals(4, tour.currentStepIndex)
        tour.skip()
        assertFalse(tour.isActive)
        assertEquals(2, seen)
        // Hors bornes : ramené dans la liste, jamais planté.
        tour.start(at = 99)
        assertEquals(10, tour.currentStepIndex)
        tour.start(at = -3)
        assertEquals(0, tour.currentStepIndex)
    }
}
