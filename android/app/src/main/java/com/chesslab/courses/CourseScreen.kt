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
import androidx.compose.material.icons.filled.AccountTree
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.SubdirectoryArrowRight
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.text.font.FontFamily
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
    /** Le sidecar Labs du cours — vide pour une finale, jamais absent. */
    var sidecar by remember(courseId) { mutableStateOf<OpeningStatsSidecar?>(null) }
    /** Le chemin parcouru : une clé FEN et le coup qui y a mené. */
    var path by remember(courseId) { mutableStateOf<List<Pair<String, CourseMove>>>(emptyList()) }
    var indexOpen by remember(courseId) { mutableStateOf(false) }

    LaunchedEffect(courseId) {
        val (c, sc) = withContext(Dispatchers.IO) {
            val c = runCatching { CourseRepository.course(context.assets, courseId) }.getOrNull()
            c to OpeningStatsLoader.sidecar(context.assets, courseId)
        }
        course = c; sidecar = sc
        path = emptyList()
    }

    val loaded = course
    val stats = sidecar
    if (loaded == null || stats == null) {
        Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator(color = Palette.accent) }
        return
    }

    val rootKey = CourseRepository.fenKey(loaded.rootFEN)
    val currentKey = path.lastOrNull()?.second?.let { CourseRepository.fenKey(it.toFEN) } ?: rootKey
    val position = remember(currentKey) { CourseRepository.position(currentKey) ?: Position.standard }
    val currentPath = path.map { it.second.uci }
    val estFinale = remember(loaded) {
        CourseRepository.catalog(context.assets).firstOrNull { it.id == loaded.id }?.isEndgame == true
    }

    // L'arbre des lignes, construit une fois par cours — avec ses verdicts.
    val rows = remember(loaded, stats) { OpeningLineTree.build(loaded, stats)?.flattened.orEmpty() }
    /** Où chaque position est DÉPLIÉE : le renvoi des repères « transposition ». */
    val expansionRows = remember(rows) {
        val out = HashMap<String, String>()
        for (row in rows) {
            // Le dernier coup d'une rangée qui transpose atterrit sur une
            // position dépliée AILLEURS : il ne l'expanse pas.
            val expanding = if (row.isTransposition) row.moves.dropLast(1) else row.moves
            for (move in expanding) out.putIfAbsent(move.toFEN, row.id)
        }
        out
    }
    /**
     * Le nom d'une branche : le nom ECO de la donnée, ou le titre écrit à la
     * main, qui prime. Affiché sur la ligne du répertoire pour qu'on sache ce
     * qu'on s'apprête à explorer avant de taper dessus.
     */
    val branchNames = remember(loaded, rows) {
        val names = HashMap<String, String>(loaded.ecoNames)
        for (row in rows) {
            if (row.depth == 0) continue
            val head = row.moves.firstOrNull() ?: continue
            row.chapterTitle?.let { names[head.toFEN] = it }
        }
        names
    }

    /**
     * Saute à une position en REJOUANT un chemin depuis la racine — le point
     * d'entrée de l'index. Le rejeu s'arrête au premier coup injouable
     * (donnée incohérente) plutôt que d'échouer en bloc : on atterrit aussi
     * loin que la donnée le permet.
     */
    fun jump(uciPath: List<String>) {
        var key = rootKey
        val replayed = ArrayList<Pair<String, CourseMove>>()
        for (uci in uciPath) {
            val edge = loaded.moves(key).firstOrNull { it.uci == uci } ?: break
            replayed += key to edge
            key = CourseRepository.fenKey(edge.toFEN)
        }
        path = replayed
    }

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
            // L'index des lignes est celui des OUVERTURES : une finale se lit
            // d'un trait, ses quelques variantes n'ont pas besoin d'un arbre.
            if (!estFinale && rows.isNotEmpty()) {
                CircleIconButton(Icons.Default.AccountTree, stringResource(R.string.index_open),
                    Palette.info, "index-des-lignes") { indexOpen = true }
                Spacer(Modifier.width(8.dp))
            }
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

            // L'évaluation : la ligne de tête du moteur pré-calculé d'abord —
            // c'est celle de la position, à profondeur connue — sinon celle
            // portée par le coup qui a mené ici. Même règle qu'iOS.
            val labs = stats.data(currentKey)
            val lead = labs?.engine?.firstOrNull()
            when {
                lead?.mate != null -> EvalBar(if (lead.mate > 0) 10.0 else -10.0, mateIn = lead.mate, depth = stats.engineDepth)
                lead?.cp != null -> EvalBar(lead.cp / 100.0, depth = stats.engineDepth)
                incoming?.eval != null -> EvalBar(incoming.eval)
            }

            Spacer(Modifier.height(10.dp))
            Breadcrumb(path, Modifier.padding(horizontal = 20.dp)) { index -> path = path.take(index) }

            // Le nom de la variante atteinte — le sous-titre de la position.
            loaded.ecoNames[currentKey]?.let { name ->
                Spacer(Modifier.height(8.dp))
                Text(
                    name, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.info,
                    modifier = Modifier.padding(horizontal = 20.dp).testTag("nom-position"),
                )
            }

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
                        MoveRow(move, tint, branchNames[CourseRepository.fenKey(move.toFEN)]) {
                            path = path + (currentKey to move)
                        }
                    }
                }
            }

            // Ce que les maîtres jouent ici, et ce que le moteur préfère —
            // seulement pour une ouverture : une finale n'a pas de sidecar.
            if (!estFinale) {
                Spacer(Modifier.height(16.dp))
                StatsColumns(
                    labs, stats.engineDepth, position.sideToMove,
                    inRepertoire = { uci -> options.firstOrNull { it.uci == uci } },
                    onPlay = { edge -> path = path + (currentKey to edge) },
                    modifier = Modifier.padding(horizontal = 20.dp),
                )
            }
            Spacer(Modifier.height(20.dp))
        }

        if (indexOpen) {
            Dialog(
                onDismissRequest = { indexOpen = false },
                properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
            ) {
                Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                    OpeningIndexScreen(
                        course = loaded, rows = rows, currentPath = currentPath,
                        destinationRow = { row ->
                            if (!row.isTransposition) null
                            else row.moves.lastOrNull()?.let { expansionRows[it.toFEN] }
                        },
                        onSelect = { uciPath -> jump(uciPath); indexOpen = false },
                        onClose = { indexOpen = false },
                    )
                }
            }
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

/**
 * L'évaluation de la position, avec sa barre. Un mat s'écrit « M3 », pas
 * « +10,00 » ; et la profondeur n'est annoncée que si l'évaluation vient bien
 * du moteur pré-calculé — un repli sur le cours n'en a pas.
 */
@Composable
private fun EvalBar(eval: Double, mateIn: Int? = null, depth: Int? = null) {
    val clamped = eval.coerceIn(-4.0, 4.0)
    val fraction = ((clamped + 4.0) / 8.0).toFloat()
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            when {
                mateIn != null -> if (mateIn > 0) "M$mateIn" else "-M${-mateIn}"
                else -> (if (eval >= 0) "+" else "") + String.format(java.util.Locale.getDefault(), "%.2f", eval)
            },
            fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
            fontFamily = FontFamily.Monospace, color = Palette.textPrimary,
            modifier = Modifier.testTag("evaluation"),
        )
        depth?.let {
            Spacer(Modifier.width(8.dp))
            Text(
                stringResource(R.string.labs_depth, it), fontSize = 10.sp,
                fontFamily = FontFamily.Monospace, color = Palette.textSecondary,
            )
        }
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

/** Une suite possible : sa pastille de couleur, le coup, son rôle, sa part — et le nom de la ligne qu'elle ouvre. */
@Composable
private fun MoveRow(move: CourseMove, tint: Color, branchName: String? = null, onClick: () -> Unit) {
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
        Column {
            Text(FigurineSan.format(move.san), fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
            branchName?.let {
                Text(it, fontSize = 10.sp, color = Palette.textTertiary, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
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
        // La part, avec le séparateur de la langue : « 62 % » en français,
        // « 62% » en anglais — c'était écrit en dur à la française.
        move.popularity?.let {
            Text(percent(it), fontSize = 12.sp, color = Palette.textSecondary)
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


// MARK: Labs — maîtres et moteur

/**
 * Deux colonnes côte à côte : ce que les humains forts ont joué, et ce que le
 * moteur préfère. Côte à côte et non l'une sous l'autre, parce que la question
 * qu'on se pose est une COMPARAISON — « le coup le plus joué est-il le
 * meilleur ? » — et qu'elle ne se lit pas en faisant défiler.
 *
 * Les coups hors répertoire restent visibles (c'est une information : les
 * maîtres jouent aussi ça) mais ne sont pas des boutons — hors répertoire il
 * n'y a ni sidecar, ni commentaire, ni suite.
 */
@Composable
private fun StatsColumns(
    labs: OpeningPositionStats?,
    depth: Int?,
    sideToMove: chesskit.Piece.Color,
    inRepertoire: (String) -> CourseMove?,
    onPlay: (CourseMove) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            val masters = labs?.masters
            LabsHeader(
                stringResource(R.string.labs_masters), Icons.Default.Groups, Palette.gold,
                trailing = masters?.takeIf { it.totalGames > 0 }?.let { formatted(it.totalGames) },
            )
            if (masters == null || masters.totalGames == 0) {
                Text(stringResource(R.string.labs_masters_none), fontSize = 10.sp, color = Palette.textTertiary)
            } else {
                masters.moves.forEach { move -> MasterRow(move, masters, inRepertoire(move.uci), onPlay) }
            }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            val lines = labs?.engine.orEmpty()
            LabsHeader(
                stringResource(R.string.labs_engine), Icons.Default.Memory, Palette.violet,
                trailing = depth?.let { stringResource(R.string.labs_depth, it) },
            )
            if (lines.isEmpty()) {
                Text(stringResource(R.string.labs_engine_none), fontSize = 10.sp, color = Palette.textTertiary)
            } else {
                lines.forEachIndexed { rank, line -> EngineRow(line, rank, inRepertoire(line.uci), onPlay) }
            }
        }
    }
}

@Composable
private fun LabsHeader(title: String, icon: androidx.compose.ui.graphics.vector.ImageVector, tint: Color, trailing: String?) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(13.dp))
        Text(title.uppercase(), fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = Palette.textTertiary, modifier = Modifier.weight(1f))
        trailing?.let { Text(it, fontSize = 10.sp, fontFamily = FontFamily.Monospace, color = Palette.textTertiary) }
    }
}

/** Un coup de maître : le coup, sa part, ses parties, et son bilan en barre fine. */
@Composable
private fun MasterRow(move: OpeningMasterMove, stats: OpeningMasterStats, edge: CourseMove?, onPlay: (CourseMove) -> Unit) {
    val share = stats.share(move)
    val shape = RoundedCornerShape(10.dp)
    Column(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Palette.gold.copy(alpha = 0.12f))
            .border(1.dp, Palette.gold.copy(alpha = 0.32f), shape)
            .clickable(enabled = edge != null) { edge?.let(onPlay) }
            .padding(horizontal = 9.dp, vertical = 7.dp)
            .testTag("maitre-${move.uci}"),
        verticalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                FigurineSan.format(move.san), fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                fontFamily = FontFamily.Monospace,
                color = if (edge == null) Palette.textSecondary else Palette.textPrimary,
                modifier = Modifier.weight(1f),
            )
            Text(percent(share), fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Palette.gold)
            Text(formatted(move.games), fontSize = 9.sp, fontFamily = FontFamily.Monospace, color = Palette.textSecondary)
        }
        // Le bilan blanc / nulle / noir seulement, en 2 dp : une indication de
        // tendance, pas une mesure qu'on lit au dixième.
        val total = maxOf(1, move.games).toFloat()
        Row(Modifier.fillMaxWidth().height(2.dp).clip(CircleShape)) {
            if (move.whiteWins > 0) Box(Modifier.weight(move.whiteWins / total).fillMaxHeight().background(Color.White.copy(alpha = 0.88f)))
            if (move.draws > 0) Box(Modifier.weight(move.draws / total).fillMaxHeight().background(Color.Gray.copy(alpha = 0.55f)))
            if (move.blackWins > 0) Box(Modifier.weight(move.blackWins / total).fillMaxHeight().background(Color(0.13f, 0.13f, 0.13f)))
        }
    }
}

/** Une ligne du moteur : son rang, le coup, son score, et si le répertoire continue par là. */
@Composable
private fun EngineRow(line: OpeningEngineLine, rank: Int, edge: CourseMove?, onPlay: (CourseMove) -> Unit) {
    val shape = RoundedCornerShape(10.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Palette.violet.copy(alpha = if (rank == 0) 0.14f else 0.07f))
            .border(1.dp, Palette.violet.copy(alpha = if (rank == 0) 0.45f else 0.22f), shape)
            .clickable(enabled = edge != null) { edge?.let(onPlay) }
            .padding(horizontal = 9.dp, vertical = 8.dp)
            .testTag("moteur-${line.uci}"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(
            Modifier.size(15.dp).clip(CircleShape)
                .background(if (rank == 0) Palette.violet else Palette.violet.copy(alpha = 0.18f)),
            contentAlignment = Alignment.Center,
        ) {
            Text("${rank + 1}", fontSize = 9.sp, fontWeight = FontWeight.Bold,
                color = if (rank == 0) Palette.background else Palette.violet)
        }
        Text(
            FigurineSan.format(line.san), fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
            fontFamily = FontFamily.Monospace,
            color = if (edge == null) Palette.textSecondary else Palette.textPrimary,
            modifier = Modifier.weight(1f),
        )
        Text(engineScore(line), fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
            fontFamily = FontFamily.Monospace, color = engineTint(line))
        // La flèche dit « on peut y aller » ; le cercle pointillé, « le
        // répertoire s'arrête ici ». Le sens reste dit à l'accessibilité.
        Icon(
            if (edge != null) Icons.Default.SubdirectoryArrowRight else Icons.Outlined.Circle,
            stringResource(if (edge != null) R.string.labs_in_repertoire else R.string.labs_off_repertoire),
            tint = if (edge != null) Palette.textSecondary else Palette.textTertiary,
            modifier = Modifier.size(11.dp),
        )
    }
}

/** Le score, TOUJOURS du point de vue des Blancs, comme la barre. */
private fun engineScore(line: OpeningEngineLine): String {
    line.mate?.let { return if (it > 0) "M$it" else "-M${-it}" }
    val cp = line.cp ?: return "—"
    return String.format(java.util.Locale.getDefault(), "%+.2f", cp / 100.0)
}

private fun engineTint(line: OpeningEngineLine): Color {
    line.mate?.let { return if (it > 0) Palette.accent else Palette.danger }
    val cp = line.cp ?: return Palette.textTertiary
    return when {
        cp > 50 -> Palette.accent
        cp < -50 -> Palette.danger
        else -> Palette.textSecondary
    }
}

/** Sous 1 %, « 0 % » serait faux et « 0,4 % » plus juste que rien. */
@Composable
private fun percent(share: Double): String {
    val value = if (share < 0.01) String.format(java.util.Locale.getDefault(), "%.1f", share * 100)
        else "${Math.round(share * 100)}"
    return value + stringResource(R.string.percent_suffix)
}

private fun formatted(count: Int): String = when {
    count >= 1_000_000 -> String.format(java.util.Locale.getDefault(), "%.1f M", count / 1_000_000.0)
    count >= 1_000 -> String.format(java.util.Locale.getDefault(), "%.0f k", count / 1_000.0)
    else -> "$count"
}
