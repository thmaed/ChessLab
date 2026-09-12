package com.chesslab.courses

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.School
import androidx.compose.material.icons.filled.SportsMartialArts
import androidx.compose.material.icons.automirrored.filled.Subject
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chesskit.Position
import chesskit.Square
import com.chesslab.R
import com.chesslab.ui.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import com.chesslab.ui.QuickSwitchMenu
import com.chesslab.ui.TopBarActions

/**
 * La lecture d'un cours. Pendant d'`OpeningReaderView`.
 *
 * On DESCEND l'arbre coup par coup plutôt que de feuilleter des positions :
 * le fil des coups joués reste en haut, les suites possibles sont en bas avec
 * leur rôle, et les flèches sur le plateau disent d'un coup d'œil où elles
 * mènent.
 */
@Composable
fun CourseScreen(
    courseId: String,
    onPlayVsEngine: (String) -> Unit = {},
    onOpenTwoPlayer: (String) -> Unit = {},
    onOpenLab: (String) -> Unit = {},
    /**
     * L'entraînement LIBRE, proposé pour les seules FINALES : une ouverture
     * n'a pas de verdict théorique à préserver, la question n'a pas de sens.
     */
    onFreeTrain: (id: String, name: String) -> Unit = { _, _ -> },
    onTrain: (id: String, name: String) -> Unit = { _, _ -> },
) {
    val context = LocalContext.current
    var course by remember(courseId) { mutableStateOf<Course?>(null) }
    /** Le chemin parcouru : une clé FEN et le coup qui y a mené. */
    var path by remember(courseId) { mutableStateOf<List<Pair<String, CourseMove>>>(emptyList()) }

    LaunchedEffect(courseId) {
        course = withContext(Dispatchers.IO) {
            runCatching { CourseRepository.course(context.assets, courseId) }.getOrNull()
        }
        path = emptyList()
    }

    val loaded = course
    if (loaded == null) {
        Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator(color = Palette.accent) }
        return
    }

    val rootKey = CourseRepository.fenKey(loaded.rootFEN)
    val currentKey = path.lastOrNull()?.second?.let { CourseRepository.fenKey(it.toFEN) } ?: rootKey
    val position = remember(currentKey) { CourseRepository.position(currentKey) ?: Position.standard }

    TopBarActions {
        QuickSwitchMenu(
            onPlayVsEngine = { onPlayVsEngine(position.fen) },
            onOpenTwoPlayer = { onOpenTwoPlayer(position.fen) },
            onOpenLab = { onOpenLab(position.fen) },
        )
    }
    val incoming = path.lastOrNull()?.second
    val options = loaded.positions[currentKey].orEmpty()
        .sortedWith(compareByDescending<CourseMove> { it.isMainLine }.thenByDescending { it.popularity ?: 0.0 })
    val coloured = colorize(options)

    Column(Modifier.fillMaxSize()) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                loaded.name, fontSize = 17.sp, fontWeight = FontWeight.Bold,
                color = Palette.textPrimary, modifier = Modifier.weight(1f),
                maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
            // L'entraînement LIBRE n'a de sens que pour une finale : une
            // ouverture n'a pas de verdict théorique à préserver.
            val estFinale = CourseRepository.catalog(context.assets)
                .firstOrNull { it.id == loaded.id }?.isEndgame == true
            if (estFinale) {
                CircleIconButton(Icons.Default.SportsMartialArts, stringResource(R.string.endgame_free),
                    Palette.warning, "entrainer-libre") { onFreeTrain(loaded.id, loaded.name) }
                Spacer(Modifier.width(8.dp))
            }
            CircleIconButton(Icons.Default.School, stringResource(R.string.course_train),
                Palette.accent, "entrainer") { onTrain(loaded.id, loaded.name) }
        }

        Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {
            BoardView(
                position = position,
                enabled = false,
                lastMove = incoming?.let {
                    Square(it.uci.substring(0, 2)) to Square(it.uci.substring(2, 4))
                },
                arrows = coloured.map { (move, tint, rank) ->
                    BoardArrow(
                        Square(move.uci.substring(0, 2)), Square(move.uci.substring(2, 4)),
                        tint, if (rank == 0) 1f else 0.45f,
                    )
                },
            )

            incoming?.eval?.let { EvalBar(it) }

            Spacer(Modifier.height(10.dp))
            Breadcrumb(path, Modifier.padding(horizontal = 20.dp)) { index -> path = path.take(index) }

            incoming?.comment?.let { comment ->
                Spacer(Modifier.height(12.dp))
                CommentCard(comment, Modifier.padding(horizontal = 20.dp))
            }

            if (coloured.isNotEmpty()) {
                Spacer(Modifier.height(16.dp))
                SectionHeader(stringResource(R.string.course_repertoire), Modifier.padding(horizontal = 20.dp))
                Spacer(Modifier.height(8.dp))
                Column(
                    Modifier.padding(horizontal = 20.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    coloured.forEach { (move, tint, _) ->
                        MoveRow(move, tint) { path = path + (currentKey to move) }
                    }
                }
            }
            Spacer(Modifier.height(20.dp))
        }

        // Reculer et avancer sur la ligne principale : les deux gestes qu'on
        // répète en lisant un cours.
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            NavButton(
                Icons.Default.ChevronLeft, stringResource(R.string.course_previous),
                enabled = path.isNotEmpty(), filled = false,
                modifier = Modifier.weight(1f).testTag("precedent"),
            ) { path = path.dropLast(1) }
            val next = coloured.firstOrNull()
            NavButton(
                Icons.Default.ChevronRight, stringResource(R.string.course_next),
                enabled = next != null, filled = true,
                modifier = Modifier.weight(1f).testTag("suivant"),
            ) { next?.let { path = path + (currentKey to it.first) } }
        }
    }
}

/** Les coups parcourus, en fil : un tap ramène à n'importe lequel. */
@Composable
private fun Breadcrumb(
    path: List<Pair<String, CourseMove>>,
    modifier: Modifier,
    onGoTo: (Int) -> Unit,
) {
    Row(
        modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .clip(CircleShape)
                .background(Palette.surfaceElevated)
                .clickable { onGoTo(0) }
                .padding(horizontal = 12.dp, vertical = 8.dp)
                .testTag("racine"),
        ) {
            Icon(Icons.Default.Home, null, tint = Palette.textSecondary, modifier = Modifier.size(15.dp))
        }
        path.forEachIndexed { index, (_, move) ->
            val last = index == path.lastIndex
            val number = if (index % 2 == 0) "${index / 2 + 1}. " else ""
            Text(
                number + FigurineSan.format(move.san), fontSize = 13.sp, fontWeight = FontWeight.Medium,
                color = if (last) Palette.background else Palette.textPrimary,
                modifier = Modifier
                    .clip(CircleShape)
                    .then(if (last) Modifier.background(accentGradient) else Modifier.background(Palette.surfaceElevated))
                    .clickable { onGoTo(index + 1) }
                    .padding(horizontal = 12.dp, vertical = 8.dp)
                    .testTag("fil-$index"),
            )
        }
    }
}

/** L'évaluation du coup qui mène ici, avec sa barre. */
@Composable
private fun EvalBar(eval: Double) {
    val clamped = eval.coerceIn(-4.0, 4.0)
    val fraction = ((clamped + 4.0) / 8.0).toFloat()
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            (if (eval >= 0) "+" else "") + String.format(java.util.Locale.getDefault(), "%.2f", eval),
            fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
            fontFamily = FontFamily.Monospace, color = Palette.textPrimary,
            modifier = Modifier.testTag("evaluation"),
        )
        Spacer(Modifier.width(10.dp))
        Box(
            Modifier
                .weight(1f)
                .height(6.dp)
                .clip(CircleShape)
                .background(Palette.surfaceElevated)
        ) {
            Box(
                Modifier
                    .fillMaxWidth(fraction)
                    .fillMaxHeight()
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.86f))
            )
        }
    }
}

@Composable
private fun CommentCard(comment: String, modifier: Modifier) {
    Row(
        modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(cardGradient)
            .subtleBorder()
            .padding(14.dp)
            .testTag("commentaire"),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            Icons.AutoMirrored.Filled.Subject, null,
            tint = Palette.accent, modifier = Modifier.size(18.dp).padding(top = 2.dp),
        )
        Text(comment, fontSize = 13.sp, color = Palette.textPrimary)
    }
}

/** Une suite possible : sa pastille de couleur, le coup, son rôle, sa part. */
@Composable
private fun MoveRow(move: CourseMove, tint: Color, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(ControlShape)
            .background(tint.copy(alpha = 0.10f))
            .border(1.dp, tint.copy(alpha = 0.45f), ControlShape)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 11.dp)
            .testTag("coup-${move.uci}"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(10.dp).clip(CircleShape).background(tint))
        Spacer(Modifier.width(10.dp))
        Text(FigurineSan.format(move.san), fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
        roleLabel(move.role)?.let { label ->
            Spacer(Modifier.width(8.dp))
            Text(
                stringResource(label), fontSize = 11.sp, fontWeight = FontWeight.SemiBold,
                color = roleTint(move.role) ?: tint,
                modifier = Modifier
                    .clip(CircleShape)
                    .background((roleTint(move.role) ?: tint).copy(alpha = 0.16f))
                    .padding(horizontal = 7.dp, vertical = 2.dp),
            )
        }
        Spacer(Modifier.weight(1f))
        move.popularity?.let {
            Text("${(it * 100).toInt()} %", fontSize = 12.sp, color = Palette.textSecondary)
        }
        Spacer(Modifier.width(6.dp))
        Icon(Icons.Default.ChevronRight, null, tint = Palette.textTertiary, modifier = Modifier.size(16.dp))
    }
}

@Composable
private fun NavButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    enabled: Boolean,
    filled: Boolean,
    modifier: Modifier,
    onClick: () -> Unit,
) {
    Row(
        modifier
            .clip(CircleShape)
            .then(
                if (filled && enabled) Modifier.background(accentGradient)
                else Modifier.background(Palette.surfaceElevated).border(1.dp, Palette.stroke, CircleShape)
            )
            .clickable(enabled = enabled, onClick = onClick)
            .padding(vertical = 13.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val colour = when {
            !enabled -> Palette.textTertiary
            filled -> Palette.background
            else -> Palette.textPrimary
        }
        Icon(icon, null, tint = colour, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(6.dp))
        Text(label, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = colour)
    }
}

/**
 * Colore les suites : le coup recommandé en accent, les pièges en rouge, les
 * imprécisions en ambre, le reste dans une ronde de teintes neutres — c'est ce
 * qui permet de relier une flèche du plateau à sa ligne dans la liste.
 */
private val variations = listOf(Palette.info, Palette.violet, Palette.teal, Palette.rose, Palette.gold)

private fun colorize(moves: List<CourseMove>): List<Triple<CourseMove, Color, Int>> {
    var neutral = 0
    return moves.mapIndexed { index, move ->
        val colour = when {
            index == 0 -> Palette.accent
            move.role == "trap" -> Palette.danger
            move.role == "inaccuracy" -> Palette.warning
            else -> variations[neutral++ % variations.size]
        }
        Triple(move, colour, index)
    }
}

private fun roleLabel(role: String): Int? = when (role) {
    "trap" -> R.string.role_trap
    "inaccuracy" -> R.string.role_inaccuracy
    "refutation" -> R.string.role_refutation
    "mainLine" -> R.string.role_main_line
    else -> null
}

private fun roleTint(role: String): Color? = when (role) {
    "trap" -> Palette.danger
    "inaccuracy" -> Palette.warning
    "refutation" -> Palette.violet
    "mainLine" -> Palette.accent
    else -> null
}
