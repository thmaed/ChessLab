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
import chesskit.Piece
import chesskit.Square
import com.chesslab.vision.BoardAutoFrame
import com.chesslab.vision.BoardGridFinder
import com.chesslab.vision.BoardRectifier
import com.chesslab.vision.BoardReader
import com.chesslab.vision.Homography
import com.chesslab.vision.PieceDetector
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.chesslab.R
import com.chesslab.ui.q
import com.chesslab.ui.s

/** Où en est le scan : la photo, le cadrage, puis la confirmation — OBLIGATOIRE. */
enum class ScanStage { chooseSource, adjustCrop, confirm }

data class ScannerUiState(
    val stage: ScanStage = ScanStage.chooseSource,
    val image: Bitmap? = null,
    /** Les quatre coins du plateau, en fractions de l'image (0…1). */
    val corners: List<Pair<Float, Float>> = defaultCorners,
    /** La lecture des 64 cases, et l'orientation retenue pour la lire. */
    val reading: ScanReading? = null,
    val rotation: ScanRotation = ScanRotation.none,
    /** L'image redressée et sa grille : de quoi montrer la vignette d'origine d'une case douteuse. */
    val board: Bitmap? = null,
    val boardGrid: BoardGridFinder.Grid? = null,
    /** Capture ou photo d'écran — déduite de l'image à son ouverture, jamais demandée. */
    val source: ScanSource = ScanSource.screenshot,
    val busy: Boolean = false,
    val status: String = "",
) {
    /**
     * La FEN à confirmer. Le trait ne se lit JAMAIS sur une image, mais un roi
     * en échec le trahit (`ScanReading.suggestedSideToMove`) ; sans indice, les
     * Blancs. C'est l'éditeur qui fait ensuite autorité.
     */
    val fen: String? get() = reading?.let { it.fen(rotation, it.suggestedSideToMove(rotation)) }

    /** Les cases à passer en revue, les moins sûres d'abord. */
    val reviewSquares: List<Square> get() = reading?.reviewSquares(rotation).orEmpty()

    /**
     * La vignette d'origine d'une case de l'échiquier, une fois la rotation de
     * lecture appliquée. `null` si l'image redressée n'est plus là.
     */
    fun thumbnail(square: Square): Bitmap? {
        val board = board ?: return null
        val grid = boardGrid ?: return null
        val row = 8 - square.rank.value
        val column = square.file.number - 1
        // Un demi-tour : la case (r, c) de l'échiquier vient de (7 − r, 7 − c) dans l'image.
        val (r, c) = if (rotation == ScanRotation.half) (7 - row) to (7 - column) else row to column
        return BoardRectifier.squareBitmap(board, grid, r, c)
    }

    /** Les cases à surligner : celles dont la lecture est douteuse. */
    val lowConfidence: Set<Square> get() = reading?.lowConfidenceSquares(rotation).orEmpty()

    companion object {
        /** Un cadre confortable au départ : l'utilisateur l'ajuste. */
        val defaultCorners = listOf(
            0.12f to 0.12f, 0.88f to 0.12f, 0.88f to 0.88f, 0.12f to 0.88f,
        )
    }
}

/**
 * Le scanner : une photo, quatre coins, une position — pendant de
 * `ScannerViewModel.swift`.
 *
 * Le plateau est CHERCHÉ d'abord (motif de damier). Trouvé avec certitude,
 * l'image est une capture : la lecture s'enchaîne sans demander de recadrer.
 * Sinon c'est une photo d'écran, et l'utilisateur ajuste les quatre poignées
 * avant de lire. La source se déduit donc de l'image, comme sur iOS, et règle
 * les seuils du second avis ([TemplateSquareClassifier]).
 */
class ScannerViewModel(app: Application) : AndroidViewModel(app) {

    var ui by mutableStateOf(ScannerUiState(status = s(R.string.scan_pick_photo)))
        private set

    init {
        // Le modèle et les gabarits se chargent pendant que l'utilisateur choisit
        // son image et cadre le plateau : la première lecture n'attend plus après
        // eux (≈ 300 gabarits à rendre). Pendant d'`ScannerView.task` côté iOS.
        viewModelScope.launch(Dispatchers.Default) {
            runCatching {
                PieceDetector.shared(getApplication())
                TemplateSquareClassifier.shared(getApplication())
            }
        }
    }

    /**
     * Source imposée — porte dérobée des tests, qui doivent pouvoir viser un
     * chemin précis sans dépendre de la déduction (comme `forcedSource` iOS).
     */
    var forcedSource: ScanSource? = null

    /** La dernière image reçue par « Partager » : la même ne se relit pas en revenant sur l'écran. */
    private var sharedLoaded: Uri? = null

    /** Charge l'image envoyée par une autre app, une seule fois par image. */
    fun loadShared(uri: Uri) {
        if (sharedLoaded == uri) return
        sharedLoaded = uri
        load(uri)
    }

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
            ui = ui.copy(status = s(R.string.scan_unreadable))
            return@launch
        }
        loadBitmap(bitmap).join()
    }

    /**
     * Charge une image déjà décodée. Séparé de [load] pour les tests, qui
     * n'ont pas de sélecteur de photos à piloter — mais ont la capture.
     *
     * Déduit la source de l'image : un damier reconnu avec certitude est une
     * capture, et la lecture s'enchaîne aussitôt ([autoRead]) ; sinon c'est une
     * photo d'écran, et l'on s'arrête au cadrage. Ce n'est jamais une vérité :
     * un échec de la lecture automatique laisse le cadrage manuel, pas un cul-de-sac.
     */
    fun loadBitmap(bitmap: Bitmap, autoRead: Boolean = true) = viewModelScope.launch {
        ui = ui.copy(busy = true, status = s(R.string.scan_reading))
        val detection = withContext(Dispatchers.IO) { runCatching { BoardAutoFrame.detect(bitmap) }.getOrNull() }
        val source = forcedSource ?: if (detection != null) ScanSource.screenshot else ScanSource.screenPhoto
        val found = detection?.let { BoardAutoFrame.corners(bitmap, it.rect) }

        if (autoRead && found != null) {
            val result = readBoard(bitmap, found, source)
            if (result != null) {
                showReading(bitmap, found, source, result)
                return@launch
            }
        }
        ui = ui.copy(
            busy = false,
            stage = ScanStage.adjustCrop,
            image = bitmap,
            source = source,
            corners = found ?: ScannerUiState.defaultCorners,
            reading = null, rotation = ScanRotation.none,
            status = s(if (found != null) R.string.scan_found else R.string.scan_place_corners),
        )
    }

    /** Refaire la détection à la demande, après un cadrage manuel raté. */
    fun autoFrame() = viewModelScope.launch {
        val bitmap = ui.image ?: return@launch
        val found = withContext(Dispatchers.IO) { runCatching { BoardAutoFrame.corners(bitmap) }.getOrNull() }
        ui = if (found == null) ui.copy(status = s(R.string.scan_not_found))
        else ui.copy(corners = found, status = s(R.string.scan_found))
    }

    fun moveCorner(index: Int, x: Float, y: Float) {
        val corners = ui.corners.toMutableList()
        corners[index] = x.coerceIn(0f, 1f) to y.coerceIn(0f, 1f)
        ui = ui.copy(corners = corners)
    }

    fun scan() = viewModelScope.launch {
        val bitmap = ui.image ?: return@launch
        ui = ui.copy(busy = true, status = s(R.string.scan_reading))
        val result = readBoard(bitmap, ui.corners, ui.source)
        if (result == null) {
            ui = ui.copy(status = s(R.string.scan_model_unavailable))
            return@launch
        }
        showReading(bitmap, ui.corners, ui.source, result)
    }

    /** La lecture, hors fil principal. `null` si le modèle de reconnaissance est absent. */
    private suspend fun readBoard(
        bitmap: Bitmap, corners: List<Pair<Float, Float>>, source: ScanSource,
    ): ScanPipeline.Result? = withContext(Dispatchers.IO) {
        val points = corners.map { (fx, fy) ->
            Homography.Point((fx * bitmap.width).toDouble(), (fy * bitmap.height).toDouble())
        }
        ScanPipeline.read(getApplication(), bitmap, points, source)
    }

    /**
     * Ouvre la confirmation. Rien ne part vers le moteur sans passer sous les
     * yeux de l'utilisateur : la lecture s'ouvre dans l'éditeur, pré-rempli, avec
     * l'orientation la plus plausible et les cases douteuses surlignées.
     */
    private fun showReading(
        bitmap: Bitmap, corners: List<Pair<Float, Float>>, source: ScanSource, result: ScanPipeline.Result,
    ) {
        val reading = result.reading
        val count = result.detections
        val rotation = reading.suggestedRotation()
        val uncertain = reading.lowConfidenceSquares(rotation).size
        ui = ui.copy(
            busy = false,
            stage = ScanStage.confirm,
            image = bitmap,
            corners = corners,
            source = source,
            reading = reading,
            rotation = rotation,
            board = result.board,
            boardGrid = result.grid,
            status = q(R.plurals.scan_pieces, count, count) +
                (if (uncertain > 0) " · " + q(R.plurals.scan_uncertain, uncertain, uncertain) else ""),
        )
    }

    /** Bascule 0°/180° — les seules orientations plausibles d'un diagramme. */
    fun flipReading() { ui = ui.copy(rotation = ui.rotation.flipped) }

    /** Retour au cadrage : la lecture est jetée, l'image et les coins restent. */
    fun backToCrop() { ui = ui.copy(stage = ScanStage.adjustCrop, reading = null, board = null, boardGrid = null) }
}
