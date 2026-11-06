package com.chesslab.vision

import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Pendant de `TemplateSquareClassifierTests` (iOS) pour le calcul pur : corrélation, vignettes. */
class ImagePatchTest {

    @Test fun correlationOfAPatchWithItselfIsOne() {
        val patch = DoubleArray(1024) { (it * 7 % 13) / 13.0 }
        val n = assertNotNull(ImagePatch.normalize(patch))
        assertEquals(1.0, ImagePatch.dot(n, n), 1e-9)
    }

    @Test fun correlationOfOppositePatternsIsMinusOne() {
        val patch = DoubleArray(1024) { (it * 7 % 13) / 13.0 }
        val inverse = DoubleArray(1024) { 1 - patch[it] }
        assertEquals(-1.0, ImagePatch.dot(ImagePatch.normalize(patch)!!, ImagePatch.normalize(inverse)!!), 1e-9)
    }

    /** ZNCC est invariante à toute transformation affine de la luminosité — c'est ce qui permet de lire un thème inconnu. */
    @Test fun correlationIgnoresBrightnessAndContrast() {
        val patch = DoubleArray(1024) { (it * 7 % 13) / 13.0 }
        val dimmer = DoubleArray(1024) { patch[it] * 0.4 + 0.2 }
        assertEquals(1.0, ImagePatch.dot(ImagePatch.normalize(patch)!!, ImagePatch.normalize(dimmer)!!), 1e-9)
    }

    @Test fun aFlatPatchHasNoNormalization() {
        assertNull(ImagePatch.normalize(DoubleArray(1024) { 0.5 }))
    }

    @Test fun theCentralRegionKeepsTheMiddleSixtyPercent() {
        val side = 10
        // Un cadre à 1 sur les bords, 0 au centre : la région centrale n'en contient rien.
        val patch = DoubleArray(side * side) { val x = it % side; val y = it / side; if (x == 0 || y == 0 || x == side - 1 || y == side - 1) 1.0 else 0.0 }
        val central = ImagePatch.centralRegion(patch, side, 0.6)
        assertEquals(36, central.size)
        assertTrue(central.all { it == 0.0 })
    }

    @Test fun aBoxAverageReducesWithoutAliasing() {
        // 8 × 8 en damier de 1 pixel, réduit à 2 × 2 : chaque case moyenne 0,5.
        val lum = DoubleArray(64) { if ((it % 8 + it / 8) % 2 == 0) 1.0 else 0.0 }
        val small = ImagePatch.patch(lum, 8, 0, 0, 8, 8, 2)
        assertTrue(small.all { abs(it - 0.5) < 1e-9 })
    }

    @Test fun lumaOfPureChannelsFollowsRec601() {
        assertEquals(1.0, ImagePatch.luma(0xFFFFFFFF.toInt()), 1e-9)
        assertEquals(0.0, ImagePatch.luma(0xFF000000.toInt()), 1e-9)
        assertEquals(0.587, ImagePatch.luma(0xFF00FF00.toInt()), 1e-9)
    }
}
