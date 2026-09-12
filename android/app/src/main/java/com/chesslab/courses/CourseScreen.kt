package com.chesslab.courses

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chesskit.FenParser
import chesskit.Position
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
import com.chesslab.ui.Palette
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import androidx.compose.ui.res.stringResource
import com.chesslab.R

/**
 * La lecture d'un cours : un chapitre, une position à la fois, avec le
 * commentaire du coup qui y mène et les suites possibles.
 *
 * Pendant réduit d'`OpeningReaderView` / `EndgameReaderView`.
 */
@Composable
fun CourseScreen(courseId: String, onTrain: (id: String, name: String) -> Unit = { _, _ -> }) {
    val context = LocalContext.current
    var course by remember(courseId) { mutableStateOf<Course?>(null) }
    var chapter by remember(courseId) { mutableStateOf(0) }
    var step by remember(courseId) { mutableStateOf(0) }

    LaunchedEffect(courseId) {
        course = withContext(Dispatchers.IO) {
            runCatching { CourseRepository.course(context.assets, courseId) }.getOrNull()
        }
        chapter = 0
        step = 0
    }

    val loaded = course
    if (loaded == null) {
        Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator(color = Palette.accent) }
        return
    }
    if (loaded.chapters.isEmpty()) {
        Box(Modifier.fillMaxSize(), Alignment.Center) { Text(stringResource(R.string.course_no_chapter), color = Palette.textSecondary) }
        return
    }

    val current = loaded.chapters[chapter.coerceIn(loaded.chapters.indices)]
    val fens = current.positionFENs
    val index = step.coerceIn(fens.indices)
    val fen = fens[index]

    // la FEN des cours n'a que quatre champs : on complète les pendules
    val position = remember(fen) { FenParser.parse("$fen 0 1") ?: Position.standard }

    // le commentaire du coup qui MÈNE ici : il vit sur la position précédente
    val incoming = remember(fen, index) {
        if (index == 0) null
        else loaded.positions[CourseRepository.fenKey(fens[index - 1])]
            ?.firstOrNull { CourseRepository.fenKey(it.toFEN) == CourseRepository.fenKey(fen) }
    }
    val options = loaded.positions[CourseRepository.fenKey(fen)].orEmpty()

    BoardScaffold(
        header = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(loaded.name, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
                    if (loaded.summary.isNotEmpty() && index == 0) {
                        Spacer(Modifier.height(4.dp))
                        Text(loaded.summary, fontSize = 12.sp, color = Palette.textSecondary)
                    }
                }
                Spacer(Modifier.width(8.dp))
                // LIRE puis ENTRAÎNER : le bouton est là où la lecture se termine,
                // pas caché dans un menu.
                FilledTonalButton(
                    onClick = { onTrain(loaded.id, loaded.name) },
                    modifier = Modifier.testTag("entrainer"),
                ) { Text(stringResource(R.string.course_train), fontSize = 13.sp) }
            }

            Spacer(Modifier.height(10.dp))
            ChapterChips(loaded.chapters, chapter) { chapter = it; step = 0 }
            Spacer(Modifier.height(10.dp))
        },
        board = { BoardView(position = position, enabled = false) },
        panel = {
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = { step = (index - 1).coerceAtLeast(0) }, modifier = Modifier.testTag("precedent")) {
                    Icon(Icons.Default.ChevronLeft, stringResource(R.string.course_previous_position), tint = Palette.textPrimary)
                }
                Text(
                    "${index + 1} / ${fens.size}",
                    fontSize = 12.sp, color = Palette.textTertiary,
                    modifier = Modifier.testTag("progression"),
                )
                IconButton(onClick = { step = (index + 1).coerceAtMost(fens.lastIndex) }, modifier = Modifier.testTag("suivant")) {
                    Icon(Icons.Default.ChevronRight, stringResource(R.string.course_next_position), tint = Palette.textPrimary)
                }
                Spacer(Modifier.weight(1f))
                incoming?.let {
                    Text(it.san, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.accent)
                }
            }

            incoming?.comment?.let { comment ->
                Spacer(Modifier.height(6.dp))
                Text(
                    comment,
                    fontSize = 13.sp, color = Palette.textPrimary,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .background(Palette.surface)
                        .padding(12.dp)
                        .testTag("commentaire"),
                )
            }

            if (options.isNotEmpty()) {
                Spacer(Modifier.height(10.dp))
                Text(stringResource(R.string.course_next_moves), fontSize = 12.sp, color = Palette.textTertiary)
                Spacer(Modifier.height(4.dp))
                options.sortedByDescending { it.popularity ?: 0.0 }.take(6).forEach { move ->
                    MoveRow(move) {
                        // suivre une suite revient à avancer si elle est sur la ligne
                        val next = fens.getOrNull(index + 1)
                        if (next != null && CourseRepository.fenKey(next) == CourseRepository.fenKey(move.toFEN)) {
                            step = index + 1
                        }
                    }
                }
            }
        },
    )
}

@Composable
private fun ChapterChips(chapters: List<Chapter>, selected: Int, onSelect: (Int) -> Unit) {
    Row(
        Modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        chapters.forEachIndexed { i, chapter ->
            val active = i == selected
            Text(
                chapter.title,
                fontSize = 12.sp,
                color = if (active) Palette.background else Palette.textSecondary,
                modifier = Modifier
                    .testTag("chapitre-$i")
                    .clip(RoundedCornerShape(14.dp))
                    .background(if (active) Palette.accent else Palette.surface)
                    .clickable { onSelect(i) }
                    .padding(horizontal = 10.dp, vertical = 6.dp),
            )
        }
    }
}

@Composable
private fun MoveRow(move: CourseMove, onFollow: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(if (move.isMainLine) Palette.accent.copy(alpha = 0.10f) else Palette.surface)
            .clickable(onClick = onFollow)
            .padding(horizontal = 10.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            move.san, fontSize = 13.sp, fontWeight = FontWeight.Medium,
            color = if (move.isMainLine) Palette.accent else Palette.textPrimary,
            modifier = Modifier.width(56.dp),
        )
        move.popularity?.let {
            Text("${(it * 100).toInt()} %", fontSize = 11.sp, color = Palette.textSecondary, modifier = Modifier.width(52.dp))
        }
        move.eval?.let {
            Text(
                (if (it >= 0) "+%.2f" else "−%.2f").format(kotlin.math.abs(it)),
                fontSize = 11.sp, color = Palette.textTertiary,
            )
        }
        Spacer(Modifier.weight(1f))
        if (move.comment != null) {
            Text(stringResource(R.string.course_commented), fontSize = 10.sp, color = Palette.violet)
        }
    }
}
