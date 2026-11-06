package com.chesslab

import android.graphics.BitmapFactory
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import chesskit.Piece
import chesskit.Square
import com.chesslab.scanner.ScanReading
import com.chesslab.scanner.ScanRotation
import com.chesslab.vision.BoardReader
import com.chesslab.vision.Homography
import com.chesslab.vision.PieceDetector
import org.json.JSONArray
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Pendant de `ScannerFixtureTests` (iOS) pour les captures de l'interface
 * Lichess rendues le 06/11/2026 (`lichess_ui_*`) : points de coups légaux,
 * flèches, surbrillances, coordonnées et miniatures de pièces capturées, sur
 * des jeux de pièces que le modèle n'a JAMAIS vus.
 *
 * C'est la régression qui a motivé le réentraînement : l'ancien modèle lisait
 * les points de coups légaux comme des pions (50/64 et 54/64 sur deux de ces
 * captures, avec des erreurs données pour sûres). Les coins sont ceux du
 * manifeste ; la rotation (0 ou 180°) est donnée, pour ne mesurer que la
 * reconnaissance.
 */
@RunWith(AndroidJUnit4::class)
class ScannerLichessUiTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val assets get() = InstrumentationRegistry.getInstrumentation().context.assets

    @Test fun lichessInterfaceCapturesAreReadExactly() {
        val detector = PieceDetector.shared(context)
        assumeTrue("modèle de reconnaissance absent", detector != null)

        val manifest = JSONArray(assets.open("manifest.json").bufferedReader().use { it.readText() })
        var checked = 0
        for (i in 0 until manifest.length()) {
            val entry = manifest.getJSONObject(i)
            val file = entry.getString("file")
            if (!file.startsWith("lichess_ui_")) continue

            val bitmap = assets.open(file).use { BitmapFactory.decodeStream(it) }
            val c = entry.getJSONArray("corners")
            val corners = (0 until 4).map { Homography.Point(c.getJSONArray(it).getDouble(0), c.getJSONArray(it).getDouble(1)) }

            val reading = ScanReading(BoardReader.grid(detector!!.detect(bitmap, corners)))
            val rotation = if (entry.optInt("rotation", 0) == 2) ScanRotation.half else ScanRotation.none
            val read = reading.fen(rotation, Piece.Color.white).substringBefore(' ')
            val expected = entry.getString("fen")

            val wrong = wrongSquares(expected, read)
            val correct = 64 - wrong.size
            val minCorrect = entry.optInt("minCorrectSquares", 64)
            assertTrue(
                "$file : $correct/64 (attendu ≥ $minCorrect) — cases fausses ${wrong.map { it.notation }}\n" +
                    "  attendu $expected\n  lu      $read",
                correct >= minCorrect
            )

            // Comme iOS : une case fausse doit au moins être SIGNALÉE à l'écran de confirmation.
            val flagged = reading.lowConfidenceSquares(rotation)
            val silentlyWrong = wrong.filter { it !in flagged }
            // `androidMaxSilentlyWrong` : écart connu, voir PARITE.md (pas de recroisement par gabarits côté Android).
            val maxSilent = entry.optInt("androidMaxSilentlyWrong", entry.optInt("maxSilentlyWrong", 2))
            assertTrue(
                "$file : ${silentlyWrong.size} cases fausses ET données pour sûres : ${silentlyWrong.map { it.notation }}",
                silentlyWrong.size <= maxSilent
            )
            checked++
        }
        assertTrue("aucune capture lichess_ui_* dans le manifeste", checked > 0)
    }

    private fun wrongSquares(expected: String, read: String): List<Square> {
        val ea = expand(expected); val eb = expand(read)
        if (ea.length != 64 || eb.length != 64) return (0 until 64).map(::squareAt)
        return ea.indices.filter { ea[it] != eb[it] }.map(::squareAt)
    }

    /** Index 0 = a8 ... 63 = h1, l'ordre d'un placement FEN. */
    private fun squareAt(index: Int) = Square(Square.File(index % 8 + 1), Square.Rank(8 - index / 8))

    private fun expand(placement: String): String = buildString {
        for (c in placement) when {
            c == '/' -> Unit
            c.isDigit() -> repeat(c - '0') { append('.') }
            else -> append(c)
        }
    }
}
