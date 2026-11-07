package com.chesslab.scanner

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.drag
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.chesslab.ui.BoardView
import androidx.compose.foundation.clickable
import com.chesslab.ui.Palette
import com.chesslab.ui.StatusRow
import androidx.compose.foundation.Canvas
import androidx.compose.ui.res.stringResource
import com.chesslab.R

@Composable
fun ScannerScreen(
    model: ScannerViewModel = viewModel(),
    sharedImage: android.net.Uri? = null,
    onPlay: ((String) -> Unit)? = null,
    onUseAsLabStart: ((String) -> Unit)? = null,
    onAnalyse: (String) -> Unit = {},
) {
    val ui = model.ui
    val context = androidx.compose.ui.platform.LocalContext.current
    // L'image reçue par « Partager » : lue une fois, quel que soit le nombre de
    // fois où l'écran se recompose ou se rouvre (voir `loadShared`).
    LaunchedEffect(sharedImage) { sharedImage?.let(model::loadShared) }
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri?.let(model::load)
    }

    // L'APPAREIL PHOTO, pour lire un vrai plateau posé sur une table — ce que
    // la carte d'entrée promet depuis toujours (« photo ou plateau réel ») et
    // que seule la galerie permettait.
    //
    // On passe par l'app photo du système : elle rend une image et garde la
    // caméra pour elle, si bien que l'app ne demande AUCUNE permission. La
    // photo est écrite en pleine résolution dans notre cache — une vignette
    // ne se lit pas, à soixante-quatre cases.
    var captureUri by remember { mutableStateOf<android.net.Uri?>(null) }
    val capture = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { taken ->
        if (taken) captureUri?.let(model::load)
    }
    val hasCamera = remember {
        context.packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_CAMERA_ANY)
    }

    // Étape 3 — la confirmation, OBLIGATOIRE : rien de ce qui sort du scanner
    // n'a échappé au regard de l'utilisateur. C'est l'éditeur, pré-rempli.
    if (ui.stage == ScanStage.confirm && ui.fen != null) {
        ScanConfirmation(ui, model, onAnalyse, onPlay, onUseAsLabStart)
        return
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)
    ) {
        StatusRow(ui.status, busy = ui.busy)
        Spacer(Modifier.height(8.dp))

        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            if (hasCamera) {
                Text(
                    stringResource(R.string.scan_photo),
                    fontSize = 15.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold,
                    color = Palette.background,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .clip(androidx.compose.foundation.shape.CircleShape)
                        .background(com.chesslab.ui.accentGradient)
                        .clickable {
                            captureUri = newCaptureUri(context)
                            captureUri?.let { capture.launch(it) }
                        }
                        .padding(vertical = 13.dp)
                        .testTag("photographier"),
                )
            }
            Text(
                stringResource(R.string.scan_choose),
                fontSize = 15.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold,
                color = if (hasCamera) Palette.textPrimary else Palette.background,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                modifier = Modifier
                    .weight(1f)
                    .clip(androidx.compose.foundation.shape.CircleShape)
                    .then(
                        if (hasCamera) Modifier
                            .background(Palette.surfaceElevated)
                            .border(1.dp, Palette.stroke, androidx.compose.foundation.shape.CircleShape)
                        else Modifier.background(com.chesslab.ui.accentGradient)
                    )
                    .clickable { pick.launch("image/*") }
                    .padding(vertical = 13.dp)
                    .testTag("choisir"),
            )
        }

        ui.image?.let { bitmap ->
            Spacer(Modifier.height(10.dp))
            CornerPicker(
                bitmap = bitmap.asImageBitmap(),
                corners = ui.corners,
                onMove = model::moveCorner,
            )
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Button(onClick = { model.scan() }, enabled = !ui.busy, modifier = Modifier.testTag("scanner")) {
                    Text(stringResource(R.string.scan_read))
                }
                Spacer(Modifier.width(8.dp))
                TextButton(onClick = { model.autoFrame() }, modifier = Modifier.testTag("recadrer")) {
                    Text(stringResource(R.string.scan_reframe), color = Palette.textSecondary)
                }
            }
        }

        Spacer(Modifier.height(24.dp))
    }
}

/**
 * La photo, et quatre poignées à poser sur les coins du plateau.
 *
 * Les coins sont mémorisés en FRACTIONS de l'image, pas en pixels d'écran :
 * la position reste juste quand la vue change de taille (rotation, fenêtre
 * redimensionnée).
 */
@Composable
private fun CornerPicker(
    bitmap: androidx.compose.ui.graphics.ImageBitmap,
    corners: List<Pair<Float, Float>>,
    onMove: (Int, Float, Float) -> Unit,
) {
    var size by remember { mutableStateOf(IntSize.Zero) }
    var dragging by remember { mutableStateOf(-1) }

    Box(
        Modifier
            .fillMaxWidth()
            .aspectRatio(bitmap.width.toFloat() / bitmap.height)
            .onSizeChanged { size = it }
            // Le geste est géré à la main plutôt qu'avec `detectDragGestures` :
            // celui-ci consomme le slop AVANT qu'on puisse décider, si bien que
            // la photo avalait aussi le défilement vertical de l'écran — le
            // bouton « Lire le plateau » devenait inatteignable sans déplacer
            // un coin au passage. Ici, si le doigt ne part pas d'une poignée,
            // on ne consomme rien et le geste redescend au défilement.
            .pointerInput(corners, size) {
                val grab = 48.dp.toPx()
                awaitEachGesture {
                    val down = awaitFirstDown(requireUnconsumed = false)
                    if (size.width <= 0) return@awaitEachGesture
                    val index = corners.indices.minByOrNull { i ->
                        val (fx, fy) = corners[i]
                        val dx = fx * size.width - down.position.x
                        val dy = fy * size.height - down.position.y
                        dx * dx + dy * dy
                    }?.takeIf { i ->
                        val (fx, fy) = corners[i]
                        val dx = fx * size.width - down.position.x
                        val dy = fy * size.height - down.position.y
                        dx * dx + dy * dy <= grab * grab
                    } ?: return@awaitEachGesture

                    dragging = index
                    drag(down.id) { change ->
                        onMove(index, change.position.x / size.width, change.position.y / size.height)
                        change.consume()
                    }
                    dragging = -1
                }
            }
    ) {
        Image(bitmap, contentDescription = stringResource(R.string.scan_photo_to_frame), Modifier.fillMaxSize(), contentScale = ContentScale.Fit)

        Canvas(Modifier.fillMaxSize()) {
            val points = corners.map { (fx, fy) -> Offset(fx * this.size.width, fy * this.size.height) }
            for (i in points.indices) {
                drawLine(Palette.accent, points[i], points[(i + 1) % points.size], strokeWidth = 3f)
            }
            points.forEach { point ->
                drawCircle(Color.White, radius = 14f, center = point)
                drawCircle(Palette.accent, radius = 14f, center = point, style = Stroke(width = 4f))
            }
        }
    }
}


/**
 * L'écran de confirmation du scanner : l'éditeur pré-rempli avec la lecture,
 * augmenté des deux choses qu'une image ne peut pas donner — l'orientation de
 * lecture et le trait. Les cases douteuses sont surlignées ; toute correction
 * se fait à la palette, comme dans l'éditeur. Pendant de `ScanConfirmationView`.
 */
@Composable
private fun ScanConfirmation(
    ui: ScannerUiState, model: ScannerViewModel, onAnalyse: (String) -> Unit,
    onPlay: ((String) -> Unit)?, onUseAsLabStart: ((String) -> Unit)?,
) {
    // Les cases douteuses déjà passées en revue, et celle qu'on regarde. Une
    // nouvelle lecture ou une rotation relit tout : on repart de zéro.
    var reviewed by remember(ui.reading, ui.rotation) { mutableStateOf(emptySet<chesskit.Square>()) }
    var focusedIndex by remember(ui.reading, ui.rotation) { mutableStateOf(0) }
    val pending = ui.reviewSquares.filter { it !in reviewed }
    val index = if (pending.isEmpty()) 0 else focusedIndex.coerceIn(0, pending.size - 1)
    val focus = pending.getOrNull(index)
    val uncertain = pending.size
    val allReviewed = reviewed.isNotEmpty() && pending.isEmpty()

    com.chesslab.editor.PositionEditorScreen(
        initialFen = ui.fen,
        marked = pending.toSet(),
        focused = focus,
        onBack = model::backToCrop,
        backLabel = "‹ " + stringResource(R.string.scan_recrop),
        onAnalyse = onAnalyse,
        onPlay = onPlay,
        onUseAsLabStart = onUseAsLabStart,
        extra = { editor ->
            Text(
                stringResource(R.string.scan_confirm_title),
                fontSize = 15.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold,
                color = Palette.textPrimary,
            )
            Spacer(Modifier.height(8.dp))
            // La revue : une case douteuse à la fois, avec sa vignette d'origine.
            val current = focus?.let { ui.reading?.squares(ui.rotation)?.get(it) }
            if (focus != null && current != null) {
                ScanReviewPanel(
                    square = focus, reading = current,
                    thumbnail = remember(focus, ui.rotation, ui.board) { ui.thumbnail(focus) },
                    remaining = pending.size, position = index + 1,
                    onChoose = { choice ->
                        editor.place(focus, choice?.let { chesskit.Piece(it.kind, it.color, focus) })
                        reviewed = reviewed + focus
                    },
                    onKeep = { reviewed = reviewed + focus },
                    onPrevious = { focusedIndex = (index - 1 + pending.size) % pending.size },
                    onNext = { focusedIndex = (index + 1) % pending.size },
                )
                Spacer(Modifier.height(10.dp))
            }
            // La bannière de confiance : combien de cases méritent encore un regard.
            Text(
                when {
                    uncertain > 0 -> androidx.compose.ui.res.pluralStringResource(R.plurals.scan_uncertain_banner, uncertain, uncertain)
                    allReviewed -> stringResource(R.string.scan_reviewed_banner)
                    else -> stringResource(R.string.scan_confident_banner)
                },
                fontSize = 12.sp,
                color = if (uncertain > 0) Palette.warning else Palette.accent,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(Palette.surface)
                    .padding(12.dp)
                    .testTag(if (uncertain > 0) "banniere-incertaine" else if (allReviewed) "banniere-verifiee" else "banniere-sure"),
            )
            Spacer(Modifier.height(10.dp))
            // Le sens de lecture : deux orientations plausibles, un bouton.
            Text(stringResource(R.string.scan_reading_orientation), fontSize = 11.sp, color = Palette.textTertiary)
            Spacer(Modifier.height(4.dp))
            Text(
                stringResource(R.string.scan_flip), fontSize = 12.sp, color = Palette.textPrimary,
                modifier = Modifier
                    .clip(RoundedCornerShape(10.dp))
                    .background(Palette.surface)
                    .clickable(onClick = model::flipReading)
                    .padding(horizontal = 10.dp, vertical = 6.dp)
                    .testTag("inverser-lecture"),
            )
            Spacer(Modifier.height(4.dp))
            Text(
                stringResource(R.string.scan_rotation_hint, ui.rotation.degrees),
                fontSize = 10.sp, color = Palette.textTertiary,
            )
            Spacer(Modifier.height(10.dp))
        },
    )
}

/**
 * Un fichier neuf dans le cache, et le droit d'y écrire pour l'app photo.
 * `null` si le cache est indisponible — on n'en fait alors pas une erreur :
 * le choix d'une image reste là.
 */
private fun newCaptureUri(context: android.content.Context): android.net.Uri? = runCatching {
    val dir = java.io.File(context.cacheDir, "captures").apply { mkdirs() }
    val file = java.io.File(dir, "plateau-${System.currentTimeMillis()}.jpg")
    androidx.core.content.FileProvider.getUriForFile(
        context, "${context.packageName}.captures", file,
    )
}.getOrNull()
