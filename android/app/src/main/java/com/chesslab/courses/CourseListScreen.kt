package com.chesslab.courses

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.GridOn
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.VerticalAlignBottom
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.ui.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * La liste des cours — ouvertures ou finales selon [endgames].
 *
 * Pendant d'`OpeningListView` et `EndgameListView`. Le grand titre, la carte
 * d'introduction, la barre de filtres et le regroupement par camp viennent de
 * là : ce sont eux qui font qu'une liste de 136 entrées reste parcourable.
 */
@Composable
fun CourseListScreen(
    endgames: Boolean,
    onTrain: (kind: String) -> Unit = {},
    onOpen: (String) -> Unit,
) {
    val context = LocalContext.current
    var entries by remember { mutableStateOf<List<CatalogEntry>?>(null) }
    var query by remember { mutableStateOf("") }
    var sideFilter by remember { mutableStateOf<String?>(null) }
    var levelFilter by remember { mutableStateOf<String?>(null) }
    var due by remember { mutableStateOf(0) }
    var hard by remember { mutableStateOf(0) }

    LaunchedEffect(endgames) {
        val dao = com.chesslab.library.LibraryDatabase.get(context).training()
        val all = withContext(Dispatchers.IO) { dao.allProgress() }
        val now = System.currentTimeMillis()
        due = all.count { it.dueAt != null && it.dueAt <= now }
        hard = all.count { com.chesslab.training.TrainingQueue.isHard(it.snapshot) }
        entries = withContext(Dispatchers.IO) {
            runCatching { CourseRepository.catalog(context.assets) }
                .getOrDefault(emptyList())
                .filter { it.isEndgame == endgames }
                .sortedBy { it.name }
        }
    }

    val list = entries
    if (list == null) {
        Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator(color = Palette.accent) }
        return
    }

    val tint = if (endgames) Palette.gold else Palette.warning
    val filtered = list.filter { entry ->
        (query.isBlank() || entry.name.contains(query, true) || entry.summary.contains(query, true) ||
            entry.eco.any { it.contains(query, true) }) &&
            (sideFilter == null || entry.side == sideFilter) &&
            (levelFilter == null || entry.level == levelFilter)
    }

    Box(Modifier.fillMaxSize()) {
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 90.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item(key = "titre") {
                Text(
                    stringResource(if (endgames) R.string.route_endgames else R.string.route_openings),
                    fontSize = 34.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary,
                )
            }
            item(key = "intro") {
                IntroCard(
                    if (endgames) Icons.Default.EmojiEvents else Icons.Default.MenuBook, tint,
                    stringResource(if (endgames) R.string.courses_intro_endgames_title else R.string.courses_intro_openings_title),
                    stringResource(if (endgames) R.string.courses_intro_endgames_body else R.string.courses_intro_openings_body),
                )
            }
            item(key = "seances") {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    SessionChip(
                        stringResource(R.string.train_daily),
                        if (due > 0) stringResource(R.string.train_daily_due, due) else stringResource(R.string.train_daily_new),
                        Palette.warning, "seance-quotidienne", Modifier.weight(1f),
                    ) { onTrain("daily") }
                    SessionChip(
                        stringResource(R.string.train_hardest),
                        if (hard > 0) stringResource(R.string.train_hard_count, hard) else stringResource(R.string.train_hard_none),
                        Palette.danger, "seance-difficiles", Modifier.weight(1f),
                    ) { onTrain("hardest") }
                }
            }
            item(key = "filtres") {
                FilterBar(
                    tint, sideFilter, levelFilter,
                    onAll = { sideFilter = null; levelFilter = null },
                    onSide = { sideFilter = if (sideFilter == it) null else it },
                    onLevel = { levelFilter = if (levelFilter == it) null else it },
                )
            }

            // Regroupé par CAMP, comme sur iOS : un répertoire blanc et un
            // répertoire noir ne se mélangent pas dans la tête.
            val white = filtered.filter { it.side == "white" }
            val black = filtered.filter { it.side != "white" }
            if (white.isNotEmpty()) {
                item(key = "entete-blancs") { GroupHeader(stringResource(R.string.courses_white_repertoire)) }
                items(white, key = { it.id }) { CourseRow(it, onOpen) }
            }
            if (black.isNotEmpty()) {
                item(key = "entete-noirs") { GroupHeader(stringResource(R.string.courses_black_repertoire)) }
                items(black, key = { it.id }) { CourseRow(it, onOpen) }
            }
            if (filtered.isEmpty()) {
                item(key = "vide") {
                    Text(stringResource(R.string.courses_none), fontSize = 13.sp, color = Palette.textSecondary)
                }
            }
        }

        // La recherche EN BAS, à portée de pouce : c'est le geste qu'on répète
        // dans une liste de 136 entrées.
        SearchField(
            query, endgames, filtered.size,
            Modifier.align(Alignment.BottomCenter).imePadding()
                .padding(horizontal = 20.dp, vertical = 14.dp),
        ) { query = it }
    }
}

@Composable
private fun IntroCard(icon: ImageVector, tint: Color, title: String, body: String) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(cardGradient)
            .subtleBorder()
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        IconBadge(icon, tint, 36.dp)
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary)
            Text(body, fontSize = 12.sp, color = Palette.textSecondary)
        }
    }
}

@Composable
private fun FilterBar(
    tint: Color,
    side: String?,
    level: String?,
    onAll: () -> Unit,
    onSide: (String) -> Unit,
    onLevel: (String) -> Unit,
) {
    Row(
        Modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        FilterChip(stringResource(R.string.filter_all), side == null && level == null, tint, "filtre-tous", onAll)
        GlyphFilterChip("♙", side == "white", tint, "filtre-blancs") { onSide("white") }
        GlyphFilterChip("♟", side == "black", tint, "filtre-noirs") { onSide("black") }
        FilterChip(stringResource(R.string.level_club), level == "club", Palette.accent, "filtre-club") { onLevel("club") }
        FilterChip(stringResource(R.string.level_advanced), level == "advanced", Palette.warning, "filtre-avance") { onLevel("advanced") }
    }
}

@Composable
private fun FilterChip(label: String, selected: Boolean, tint: Color, tag: String, onClick: () -> Unit) {
    Text(
        label, fontSize = 14.sp, fontWeight = FontWeight.Medium,
        color = if (selected) Palette.background else Palette.textPrimary,
        modifier = Modifier
            .clip(CircleShape)
            .background(if (selected) tint else Palette.surfaceElevated)
            .border(1.dp, if (selected) Color.Transparent else Palette.stroke, CircleShape)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 9.dp)
            .testTag(tag),
    )
}

/** La puce d'un camp : la figurine dit le répertoire mieux qu'un mot. */
@Composable
private fun GlyphFilterChip(glyph: String, selected: Boolean, tint: Color, tag: String, onClick: () -> Unit) {
    Text(
        glyph, fontSize = 16.sp,
        color = if (selected) Palette.background else Palette.textPrimary,
        modifier = Modifier
            .clip(CircleShape)
            .background(if (selected) tint else Palette.surfaceElevated)
            .border(1.dp, if (selected) Color.Transparent else Palette.stroke, CircleShape)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 7.dp)
            .testTag(tag),
    )
}

@Composable
private fun GroupHeader(title: String) {
    Text(
        title.uppercase(), fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
        letterSpacing = 0.4.sp, color = Palette.textSecondary,
        modifier = Modifier.padding(top = 6.dp),
    )
}

@Composable
private fun SessionChip(
    title: String, subtitle: String, tint: Color, tag: String,
    modifier: Modifier, onClick: () -> Unit,
) {
    Column(
        modifier
            .clip(ControlShape)
            .background(tint.copy(alpha = 0.12f))
            .border(1.dp, tint.copy(alpha = 0.35f), ControlShape)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp)
            .testTag(tag),
    ) {
        Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = tint)
        Text(subtitle, fontSize = 11.sp, color = Palette.textSecondary)
    }
}

/** Une entrée : nom, code ECO, résumé, puis les trois pastilles de mesure. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CourseRow(entry: CatalogEntry, onOpen: (String) -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(cardGradient)
            .subtleBorder()
            .clickable { onOpen(entry.id) }
            .padding(14.dp)
            .testTag("cours-${entry.id}"),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                entry.name, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                color = Palette.textPrimary, modifier = Modifier.weight(1f),
                maxLines = 2, overflow = TextOverflow.Ellipsis,
            )
            ecoLabel(entry)?.let { eco ->
                Text(
                    eco, fontSize = 11.sp, fontWeight = FontWeight.SemiBold,
                    fontFamily = FontFamily.Monospace, color = Palette.teal,
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(Palette.teal.copy(alpha = 0.14f))
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                )
            }
            Spacer(Modifier.width(6.dp))
            Icon(Icons.Default.ChevronRight, null, tint = Palette.textTertiary, modifier = Modifier.size(16.dp))
        }
        if (entry.summary.isNotEmpty()) {
            Text(
                entry.summary, fontSize = 12.sp, color = Palette.textSecondary,
                maxLines = 3, overflow = TextOverflow.Ellipsis,
            )
        }
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Stat(stringResource(entry.sideLabel), if (entry.side == "white") "○" else "●")
            if (entry.positionCount > 0) {
                Stat(pluralStringResource(R.plurals.course_positions, entry.positionCount, entry.positionCount), null,
                    Icons.Default.GridOn)
            }
            entry.maxDepth?.let {
                Stat(pluralStringResource(R.plurals.course_moves, it / 2, it / 2), null, Icons.Default.VerticalAlignBottom)
            }
        }
    }
}

@Composable
private fun Stat(label: String, glyph: String?, icon: ImageVector? = null) {
    Row(
        Modifier
            .clip(CircleShape)
            .background(Palette.surfaceElevated)
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (glyph != null) Text(glyph, fontSize = 11.sp, color = Palette.textTertiary)
        else if (icon != null) Icon(icon, null, tint = Palette.textTertiary, modifier = Modifier.size(12.dp))
        Spacer(Modifier.width(5.dp))
        Text(label, fontSize = 11.sp, color = Palette.textSecondary)
    }
}

@Composable
private fun SearchField(
    query: String, endgames: Boolean, count: Int,
    modifier: Modifier, onChange: (String) -> Unit,
) {
    Row(
        modifier
            .fillMaxWidth()
            .clip(CircleShape)
            .background(Palette.surfaceElevated.copy(alpha = 0.96f))
            .border(1.dp, Palette.strokeStrong, CircleShape)
            .padding(horizontal = 16.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Default.Search, null, tint = Palette.textTertiary, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(10.dp))
        BasicTextFieldWithPlaceholder(
            query,
            stringResource(if (endgames) R.string.course_search_endgame else R.string.course_search_opening),
            Modifier.weight(1f),
            tag = "recherche",
            onChange = onChange,
        )
        Text("$count", fontSize = 12.sp, color = Palette.textTertiary, modifier = Modifier.testTag("compte"))
    }
}

/**
 * Le code ECO d'un cours : un intervalle quand le catalogue en donne deux
 * (« C60–C99 »), le code seul sinon.
 */
private fun ecoLabel(entry: CatalogEntry): String? {
    val first = entry.eco.firstOrNull() ?: return null
    val last = entry.eco.lastOrNull()
    return if (entry.eco.size > 1 && last != null && last != first) "$first–$last" else first
}
