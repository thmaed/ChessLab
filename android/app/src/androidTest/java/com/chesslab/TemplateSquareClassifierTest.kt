package com.chesslab

import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.core.content.ContextCompat
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import chesskit.Piece
import com.chesslab.scanner.ScanReading
import com.chesslab.scanner.ScanSource
import com.chesslab.scanner.TemplateSquareClassifier
import com.chesslab.vision.BoardRectifier
import com.chesslab.vision.ImagePatch
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Pendant de `TemplateSquareClassifierTests` (iOS) : les 12 pièces se relisent
 * sur des fonds qui ne sont PAS ceux des gabarits (un thème inconnu), un aplat
 * est vide, et un « 8 » incrusté dans le coin d'une case vide ne la fait pas
 * passer pour une pièce.
 */
@RunWith(AndroidJUnit4::class)
class TemplateSquareClassifierTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val side = 128

    private fun drawableId(color: Piece.Color, kind: Piece.Kind): Int {
        val c = if (color == Piece.Color.white) "w" else "b"
        val k = when (kind) {
            Piece.Kind.king -> "k"; Piece.Kind.queen -> "q"; Piece.Kind.rook -> "r"
            Piece.Kind.bishop -> "b"; Piece.Kind.knight -> "n"; Piece.Kind.pawn -> "p"
        }
        return context.resources.getIdentifier("piece_$c$k", "drawable", context.packageName)
    }

    /** Une case rendue : fond [background], glyphe à l'échelle [scale] décalé de [shift] px, ou vide si [piece] est nul. */
    private fun render(piece: Pair<Piece.Color, Piece.Kind>?, background: Int, scale: Double = 0.9, shift: Int = 0): DoubleArray {
        val bitmap = Bitmap.createBitmap(side, side, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(background)
        if (piece != null) {
            val glyph = ContextCompat.getDrawable(context, drawableId(piece.first, piece.second))!!.mutate()
            val glyphSide = (side * scale).toInt()
            val inset = (side - glyphSide) / 2
            glyph.setBounds(inset + shift, inset + shift, inset + shift + glyphSide, inset + shift + glyphSide)
            glyph.draw(canvas)
        }
        val pixels = IntArray(side * side)
        bitmap.getPixels(pixels, 0, side, 0, 0, side, side)
        val lum = DoubleArray(pixels.size) { ImagePatch.luma(pixels[it]) }
        return ImagePatch.patch(lum, side, 0, 0, side, side, BoardRectifier.PATCH_SIDE)
    }

    // Les deux cases du thème « marron » de Lichess : un fond que les quatre thèmes de l'app ne reproduisent pas.
    private val unknownLight = 0xFFF0D9B5.toInt()
    private val unknownDark = 0xFFB58863.toInt()

    @Test fun everyPieceIsReadBackOnAnUnknownTheme() {
        val classifier = TemplateSquareClassifier.shared(context)
        val wrong = ArrayList<String>()
        for (color in Piece.Color.entries) for (kind in Piece.Kind.entries) {
            for ((background, shift) in listOf(unknownLight to 0, unknownDark to 0)) {
                val read = classifier.classify(render(color to kind, background, scale = 0.85, shift = shift))
                if (read.piece != kind || read.color != color || read.confidence < ScanReading.CONFIDENCE_THRESHOLD) {
                    wrong += "${color.raw} ${kind.notation} -> ${read.color?.raw} ${read.piece?.notation} (${"%.2f".format(read.confidence)})"
                }
            }
        }
        assertTrue("pièces mal relues : $wrong", wrong.isEmpty())
    }

    @Test fun aFlatSquareIsEmptyAndSure() {
        val read = TemplateSquareClassifier.shared(context).classify(render(null, unknownLight))
        assertNull(read.piece)
        assertEquals(1.0, read.confidence, 0.0)
    }

    /** Une coordonnée dans le coin ne fait pas d'une case vide une pièce : son centre reste un aplat. */
    @Test fun aCornerCoordinateDoesNotMakeAnEmptySquareAPiece() {
        val patch = render(null, unknownDark)
        val n = BoardRectifier.PATCH_SIDE
        for (y in 1..6) for (x in 1..4) patch[y * n + x] = if ((x + y) % 2 == 0) 0.95 else 0.2   // un « 8 » en haut à gauche
        val read = TemplateSquareClassifier.shared(context).classify(patch)
        assertNull(read.piece)
        assertTrue("sûre, ou au moins non signalée", read.confidence >= ScanReading.CONFIDENCE_THRESHOLD)
    }

    /**
     * La source règle les seuils, comme iOS (`TemplateSquareClassifier(source:)`) : une
     * photo accepte un score plus bas qu'une capture (0,32 contre 0,45). Un gabarit
     * bruité — plus ou moins, selon l'amplitude — finit dans la bande entre les deux :
     * la photo y lit la pièce, la capture la refuse.
     */
    @Test fun aPhotoAcceptsAWeakerMatchThanAScreenshot() {
        val shot = TemplateSquareClassifier.shared(context, ScanSource.screenshot)
        val photo = TemplateSquareClassifier.shared(context, ScanSource.screenPhoto)
        val clean = render(Piece.Color.white to Piece.Kind.rook, unknownLight, scale = 0.85)
        var found = false
        var amplitude = 0.05
        while (amplitude <= 1.5 && !found) {
            val rng = java.util.Random(7)
            val noisy = DoubleArray(clean.size) { (clean[it] + (rng.nextDouble() - 0.5) * amplitude).coerceIn(0.0, 1.0) }
            val a = shot.classify(noisy)
            val b = photo.classify(noisy)
            found = a.piece == null && b.piece == Piece.Kind.rook && b.color == Piece.Color.white
            amplitude += 0.05
        }
        assertTrue("aucune amplitude de bruit où la photo lit la tour et la capture non", found)
    }

    /**
     * Et une photo juge « vide » un aplat un peu plus agité qu'une capture (écart-type
     * 0,05 contre 0,035) : le grain d'un écran photographié n'y fait pas une pièce.
     */
    @Test fun aPhotoTreatsAGrainyFlatSquareAsEmptyAndSure() {
        val n = BoardRectifier.PATCH_SIDE
        val grainy = DoubleArray(n * n) { 0.5 + (if (it % 2 == 0) 0.04 else -0.04) }   // écart-type 0,04
        val shot = TemplateSquareClassifier.shared(context, ScanSource.screenshot).classify(grainy)
        val photo = TemplateSquareClassifier.shared(context, ScanSource.screenPhoto).classify(grainy)
        assertEquals("photo : un aplat, vide et sûr", 1.0, photo.confidence, 0.0)
        assertTrue("capture : pas un aplat, donc moins sûre", shot.confidence < ScanReading.CONFIDENCE_THRESHOLD)
    }
}
