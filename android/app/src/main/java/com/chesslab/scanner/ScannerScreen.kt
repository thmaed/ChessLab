package com.chesslab.scanner

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
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
import com.chesslab.ui.Palette
import com.chesslab.ui.StatusRow
import androidx.compose.foundation.Canvas

@Composable
fun ScannerScreen(model: ScannerViewModel = viewModel(), onAnalyse: (String) -> Unit = {}) {
    val ui = model.ui
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri?.let(model::load)
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)
    ) {
        StatusRow(ui.status, busy = ui.busy)
        Spacer(Modifier.height(8.dp))

        Button(onClick = { pick.launch("image/*") }, modifier = Modifier.testTag("choisir")) {
            Text("Choisir une photo")
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
                    Text("Lire le plateau")
                }
                Spacer(Modifier.width(8.dp))
                TextButton(onClick = { model.autoFrame() }, modifier = Modifier.testTag("recadrer")) {
                    Text("Retrouver le plateau", color = Palette.textSecondary)
                }
            }
        }

        ui.position?.let { position ->
            Spacer(Modifier.height(12.dp))
            Text("Position lue", fontSize = 12.sp, color = Palette.textTertiary)
            Spacer(Modifier.height(4.dp))
            BoardView(position = position, enabled = false)

            Spacer(Modifier.height(8.dp))
            Text(
                model.fen,
                fontSize = 11.sp, fontFamily = FontFamily.Monospace, color = Palette.textSecondary,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(Palette.surface)
                    .padding(10.dp)
                    .testTag("fen"),
            )
            Text(
                "Le trait, les roques et la prise en passant ne se lisent pas sur une "
                    + "photo : à vous de les corriger.",
                fontSize = 10.sp, color = Palette.textTertiary,
            )
            TextButton(onClick = { onAnalyse(model.fen) }, modifier = Modifier.testTag("analyser")) {
                Text("Analyser cette position", color = Palette.accent)
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
        Image(bitmap, contentDescription = "Photo à cadrer", Modifier.fillMaxSize(), contentScale = ContentScale.Fit)

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
