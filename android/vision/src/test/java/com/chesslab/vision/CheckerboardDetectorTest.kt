package com.chesslab.vision

import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * La détection automatique du cadrage, portée de
 * `CheckerboardDetectorTests.swift`.
 *
 * Ici, des damiers de SYNTHÈSE : le détecteur est de l'arithmétique pure, il
 * reçoit un tableau de niveaux de gris et rend un cadre, donc il se juge sur
 * la JVM en quelques millisecondes. Les vraies captures d'écran, elles, sont
 * dans `ScannerPipelineTest` — il faut un appareil pour décoder un PNG, les
 * tests d'un module Android n'ayant pas `javax.imageio`.
 */
class CheckerboardDetectorTest {

    private val side = CheckerboardDetector.ANALYSIS_SIDE

    /** Un damier de synthèse : plateau de [board] px, posé à [margin] du bord. */
    private fun synthetic(
        imageSide: Int = 1000, board: Int = 800, margin: Int = 100,
        background: Double = 0.25, light: Double = 0.92, dark: Double = 0.45,
    ): DoubleArray {
        val full = DoubleArray(imageSide * imageSide) { background }
        val cell = board / 8.0
        for (y in 0 until imageSide) for (x in 0 until imageSide) {
            val bx = x - margin; val by = y - margin
            if (bx < 0 || by < 0 || bx >= board || by >= board) continue
            val column = (bx / cell).toInt(); val row = (by / cell).toInt()
            full[y * imageSide + x] = if ((row + column) % 2 == 0) light else dark
        }
        return resample(full, imageSide, imageSide, side)
    }

    /** Sous-échantillonnage au plus proche, comme le fait le rendu Android. */
    private fun resample(src: DoubleArray, w: Int, h: Int, to: Int): DoubleArray {
        val out = DoubleArray(to * to)
        for (y in 0 until to) for (x in 0 until to) {
            val sx = (x + 0.5) * w / to
            val sy = (y + 0.5) * h / to
            out[y * to + x] = src[sy.toInt().coerceIn(0, h - 1) * w + sx.toInt().coerceIn(0, w - 1)]
        }
        return out
    }

    @Test fun trouveLePlateauDansUneCaptureAvecMarge() {
        val gray = synthetic()
        val result = assertNotNull(
            CheckerboardDetector.detect(gray, 1000, 1000),
            "un plateau devrait être trouvé",
        )
        assertTrue(abs(result.rect.x - 100) < 20, "bord gauche ≈ 100, reçu ${result.rect.x}")
        assertTrue(abs(result.rect.y - 100) < 20, "bord haut ≈ 100, reçu ${result.rect.y}")
        assertTrue(abs(result.rect.width - 800) < 30, "côté ≈ 800, reçu ${result.rect.width}")
        assertTrue(result.score > 0.55)
    }

    @Test fun uneImageUnieNeRendRien() {
        assertNull(CheckerboardDetector.detect(DoubleArray(side * side) { 0.4 }, 400, 400))
    }

    @Test fun unPlateauCollantAuBordEstTrouveQuandMeme() {
        // Le cas de la capture de téléphone : plateau PLEINE LARGEUR, donc les
        // lignes extrêmes sont coupées et n'offrent aucun gradient.
        val gray = synthetic(imageSide = 1000, board = 1000, margin = 0)
        val result = assertNotNull(CheckerboardDetector.detect(gray, 1000, 1000))
        assertTrue(result.rect.width > 900, "le plateau couvre presque tout, reçu ${result.rect.width}")
    }

    @Test fun leCadreTrouveEnglobeLePlateau() {
        // La marge de sécurité doit ÉLARGIR, jamais rogner : un cadrage trop
        // court décale cumulativement les cases.
        val r = assertNotNull(CheckerboardDetector.detect(synthetic(), 1000, 1000)).rect
        assertTrue(r.x <= 100.5 && r.y <= 100.5, "le cadre doit englober le plateau, reçu (${r.x}, ${r.y})")
        assertTrue(r.right >= 899.5 && r.bottom >= 899.5, "reçu (${r.right}, ${r.bottom})")
    }
}
