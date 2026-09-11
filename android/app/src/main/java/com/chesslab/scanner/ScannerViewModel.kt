package com.chesslab.scanner

import android.app.Application
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import chesskit.FenParser
import chesskit.Position
import com.chesslab.vision.BoardAutoFrame
import com.chesslab.vision.BoardReader
import com.chesslab.vision.Homography
import com.chesslab.vision.PieceDetector
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class ScannerUiState(
    val image: Bitmap? = null,
    /** Les quatre coins du plateau, en fractions de l'image (0…1). */
    val corners: List<Pair<Float, Float>> = defaultCorners,
    val position: Position? = null,
    val placement: String = "",
    val uncertain: Int = 0,
    val busy: Boolean = false,
    val status: String = "Choisissez une photo d'échiquier",
) {
    companion object {
        /** Un cadre confortable au départ : l'utilisateur l'ajuste. */
        val defaultCorners = listOf(
            0.12f to 0.12f, 0.88f to 0.12f, 0.88f to 0.88f, 0.12f to 0.88f,
        )
    }
}

/**
 * Le scanner : une photo, quatre coins, une position.
 *
 * **Le cadrage est MANUEL**, là où l'app iOS détecte d'abord le plateau avec
 * `VNDetectRectanglesRequest`. C'est délibéré pour ce premier jet : la
 * détection automatique demande un pipeline de vision complet (contours,
 * quadrilatères, choix du meilleur), et rien n'oblige à l'avoir avant que le
 * reste fonctionne. Quatre poignées que l'on pose soi-même donnent un résultat
 * juste tout de suite — c'est d'ailleurs le repli que l'app iOS propose déjà
 * quand sa détection échoue.
 */
class ScannerViewModel(app: Application) : AndroidViewModel(app) {

    var ui by mutableStateOf(ScannerUiState())
        private set

    fun load(uri: Uri) = viewModelScope.launch {
        val bitmap = withContext(Dispatchers.IO) {
            runCatching {
                getApplication<Application>().contentResolver.openInputStream(uri).use { stream ->
                    // une photo de 12 Mpx n'apporte rien à un modèle en 640 :
                    // on sous-échantillonne à la lecture
                    val options = BitmapFactory.Options().apply { inSampleSize = 2 }
                    BitmapFactory.decodeStream(stream, null, options)
                }
            }.getOrNull()
        }
        if (bitmap == null) {
            ui = ui.copy(status = "Image illisible")
            return@launch
        }

        // On CHERCHE le plateau avant de demander quoi que ce soit. Ce n'est
        // jamais une vérité : cela pose les quatre poignées à peu près au bon
        // endroit, et l'utilisateur garde la main.
        val found = withContext(Dispatchers.IO) { runCatching { BoardAutoFrame.corners(bitmap) }.getOrNull() }
        ui = ui.copy(
            image = bitmap,
            corners = found ?: ScannerUiState.defaultCorners,
            position = null, placement = "", uncertain = 0,
            status = if (found != null) "Plateau trouvé — ajustez si besoin"
            else "Placez les quatre coins sur le plateau",
        )
    }

    /** Refaire la détection à la demande, après un cadrage manuel raté. */
    fun autoFrame() = viewModelScope.launch {
        val bitmap = ui.image ?: return@launch
        val found = withContext(Dispatchers.IO) { runCatching { BoardAutoFrame.corners(bitmap) }.getOrNull() }
        ui = if (found == null) ui.copy(status = "Plateau introuvable — placez les coins à la main")
        else ui.copy(corners = found, status = "Plateau trouvé — ajustez si besoin")
    }

    fun moveCorner(index: Int, x: Float, y: Float) {
        val corners = ui.corners.toMutableList()
        corners[index] = x.coerceIn(0f, 1f) to y.coerceIn(0f, 1f)
        ui = ui.copy(corners = corners)
    }

    fun scan() = viewModelScope.launch {
        val bitmap = ui.image ?: return@launch
        ui = ui.copy(busy = true, status = "Lecture du plateau…")

        val result = withContext(Dispatchers.IO) {
            val detector = PieceDetector.shared(getApplication()) ?: return@withContext null
            val points = ui.corners.map { (fx, fy) ->
                Homography.Point((fx * bitmap.width).toDouble(), (fy * bitmap.height).toDouble())
            }
            val detections = detector.detect(bitmap, points)
            val grid = BoardReader.grid(detections)
            Triple(BoardReader.placement(grid), BoardReader.uncertain(grid), detections.size)
        }
        ui = ui.copy(busy = false)

        if (result == null) {
            ui = ui.copy(status = "Modèle de reconnaissance indisponible")
            return@launch
        }
        val (placement, uncertain, count) = result
        // La FEN complète demande le trait, les roques et la prise en passant,
        // qu'une photo ne montre pas : on part des blancs au trait et
        // l'utilisateur corrige.
        val position = FenParser.parse("$placement w KQkq - 0 1")
        ui = ui.copy(
            position = position,
            placement = placement,
            uncertain = uncertain,
            status = "$count pièce" + (if (count > 1) "s" else "") + " reconnue" +
                (if (count > 1) "s" else "") +
                (if (uncertain > 0) " · $uncertain douteuse" + (if (uncertain > 1) "s" else "") else ""),
        )
    }

    /** La FEN à recopier ou à analyser. */
    val fen: String get() = if (ui.placement.isEmpty()) "" else "${ui.placement} w KQkq - 0 1"
}
