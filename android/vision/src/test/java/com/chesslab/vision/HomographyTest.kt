package com.chesslab.vision

import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertTrue

/**
 * L'homographie, vérifiée sur des cas dont on connaît la réponse : sans cela,
 * un redressement faux ne se verrait que sur une photo, trop tard.
 */
class HomographyTest {

    private fun assertClose(expected: Double, actual: Double, tolerance: Double = 1e-6) =
        assertTrue(abs(expected - actual) < tolerance, "attendu $expected, obtenu $actual")

    @Test fun identityWhenTheQuadIsAlreadyASquare() {
        val corners = listOf(
            Homography.Point(0.0, 0.0), Homography.Point(100.0, 0.0),
            Homography.Point(100.0, 100.0), Homography.Point(0.0, 100.0),
        )
        val h = Homography.fromSquare(corners, side = 100.0)
        val centre = Homography.map(h, 50.0, 50.0)
        assertClose(50.0, centre.x)
        assertClose(50.0, centre.y)
    }

    @Test fun theFourCornersMapExactly() {
        // un quadrilatère nettement en perspective
        val corners = listOf(
            Homography.Point(120.0, 80.0), Homography.Point(480.0, 140.0),
            Homography.Point(530.0, 460.0), Homography.Point(60.0, 400.0),
        )
        val side = 200.0
        val h = Homography.fromSquare(corners, side)

        val square = listOf(
            0.0 to 0.0, side to 0.0, side to side, 0.0 to side,
        )
        for ((index, point) in square.withIndex()) {
            val mapped = Homography.map(h, point.first, point.second)
            assertClose(corners[index].x, mapped.x, 1e-6)
            assertClose(corners[index].y, mapped.y, 1e-6)
        }
    }

    @Test fun aTranslatedSquareStaysASquare() {
        val corners = listOf(
            Homography.Point(10.0, 20.0), Homography.Point(90.0, 20.0),
            Homography.Point(90.0, 100.0), Homography.Point(10.0, 100.0),
        )
        val h = Homography.fromSquare(corners, side = 80.0)
        val middle = Homography.map(h, 40.0, 40.0)
        assertClose(50.0, middle.x)
        assertClose(60.0, middle.y)
    }
}
