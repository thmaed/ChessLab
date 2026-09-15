package com.chesslab.analysis

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.FileDownload
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Sell
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.library.GameRecord
import com.chesslab.library.LibraryDatabase
import com.chesslab.ui.BasicTextFieldWithPlaceholder
import com.chesslab.ui.CardShape
import com.chesslab.ui.ChipButton
import com.chesslab.ui.GameResultPill
import com.chesslab.ui.Palette
import com.chesslab.ui.subtleBorder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.DateFormat
import java.util.Date

/**
 * La bibliothèque des parties. Pendant d'`AnalysisLibraryView`.
 *
 * Elle n'était qu'une liste de huit lignes coincée sous l'écran d'analyse :
 * on ne pouvait ni chercher, ni filtrer, ni étiqueter, ni supprimer, ni
 * importer. Une bibliothèque de parties, c'est un CLASSEUR — sans quoi elle
 * ne sert qu'à retrouver la dernière partie jouée, ce que l'accueil fait déjà.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun AnalysisLibraryScreen(onOpen: (String) -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val dao = remember { LibraryDatabase.get(context).games() }
    val records by dao.all().collectAsState(initial = emptyList())

    var query by remember { mutableStateOf("") }
    var mode by remember { mutableStateOf<String?>(null) }
    var result by remember { mutableStateOf(ResultFilter.all) }
    var tag by remember { mutableStateOf<String?>(null) }
    var selecting by remember { mutableStateOf(false) }
    var selection by remember { mutableStateOf(setOf<Long>()) }
    var editing by remember { mutableStateOf<GameRecord?>(null) }
    var deleting by remember { mutableStateOf<GameRecord?>(null) }
    var confirmBatch by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }

    val importedOne = stringResource(R.string.library_imported_none)
    val importFailed = stringResource(R.string.library_import_failed)
    val importer = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            val count = withContext(Dispatchers.IO) { importPgn(context, uri, dao) }
            message = when {
                count == null -> importFailed
                count == 0 -> importedOne
                else -> context.resources.getQuantityString(R.plurals.library_imported, count, count)
            }
        }
    }

    val tags = remember(records) {
        records.flatMap { it.tagList }.distinctBy { it.lowercase() }.sortedBy { it.lowercase() }
    }
    val filtered = remember(records, query, mode, result, tag) {
        filter(records, query, mode, result, tag)
    }

    Column(Modifier.fillMaxSize()) {
        if (records.isEmpty()) {
            EmptyLibrary(onImport = { importer.launch(arrayOf("*/*")) })
            return@Column
        }

        Column(Modifier.padding(horizontal = 16.dp, vertical = 10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    pluralStringResource(R.plurals.library_games, records.size, records.size),
                    fontSize = 12.sp, color = Palette.textTertiary, modifier = Modifier.weight(1f),
                )
                TextButton(
                    onClick = { importer.launch(arrayOf("*/*")) },
                    modifier = Modifier.testTag("importer-pgn"),
                ) {
                    Icon(Icons.Default.FileDownload, null, tint = Palette.accent, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text(stringResource(R.string.library_import), color = Palette.accent, fontSize = 12.sp)
                }
            }
            Spacer(Modifier.height(4.dp))
            BasicTextFieldWithPlaceholder(
                value = query,
                placeholder = stringResource(R.string.library_search),
                tag = "recherche",
            ) { query = it }
            Spacer(Modifier.height(10.dp))

            // Trois rangées de filtres : le MODE, le RÉSULTAT, l'ÉTIQUETTE.
            // Chacune défile seule : il y a plus de choix que de largeur.
            Row(
                Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                ChipButton(stringResource(R.string.library_all_modes), mode == null,
                    Modifier.testTag("mode-tous")) { mode = null }
                ChipButton(stringResource(R.string.route_play), mode == "engine",
                    Modifier.testTag("mode-engine"), icon = Icons.Default.Memory) {
                    mode = if (mode == "engine") null else "engine"
                }
                ChipButton(stringResource(R.string.route_two_players), mode == "twoPlayer",
                    Modifier.testTag("mode-twoPlayer"), icon = Icons.Default.People) {
                    mode = if (mode == "twoPlayer") null else "twoPlayer"
                }
                if (records.any { it.source == "imported" }) {
                    ChipButton(stringResource(R.string.library_imported_filter), mode == "imported",
                        Modifier.testTag("mode-imported"), icon = Icons.Default.FileDownload) {
                        mode = if (mode == "imported") null else "imported"
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
            Row(
                Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                ResultFilter.entries.forEach { value ->
                    ChipButton(
                        stringResource(value.label), result == value,
                        Modifier.testTag("resultat-${value.name}"),
                    ) { result = if (result == value) ResultFilter.all else value }
                }
            }
            if (tags.isNotEmpty()) {
                Spacer(Modifier.height(8.dp))
                Row(
                    Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    ChipButton(stringResource(R.string.library_all_tags), tag == null,
                        Modifier.testTag("etiquette-toutes"), icon = Icons.Default.Sell) { tag = null }
                    tags.forEach { value ->
                        ChipButton(value, tag.equals(value, ignoreCase = true),
                            Modifier.testTag("etiquette-$value")) {
                            tag = if (tag.equals(value, ignoreCase = true)) null else value
                        }
                    }
                }
            }
        }

        if (filtered.isEmpty()) {
            Box(Modifier.fillMaxWidth().padding(40.dp), Alignment.Center) {
                Text(
                    stringResource(R.string.library_no_match),
                    fontSize = 13.sp, color = Palette.textSecondary,
                    modifier = Modifier.testTag("aucun-resultat"),
                )
            }
            return@Column
        }

        LazyColumn(
            Modifier.weight(1f),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(filtered, key = { it.id }) { record ->
                RecordRow(
                    record = record,
                    selecting = selecting,
                    checked = record.id in selection,
                    onTap = {
                        if (selecting) {
                            selection = if (record.id in selection) selection - record.id
                            else selection + record.id
                        } else if (record.pgn.isNotBlank()) onOpen(record.pgn)
                    },
                    // L'appui LONG ouvre le menu de la ligne : c'est le geste
                    // Android pour « et sinon, quoi d'autre ? », là où iOS
                    // pose un menu contextuel au même endroit.
                    onEditTags = { editing = record },
                    onDelete = { deleting = record },
                    onStartSelection = { selecting = true; selection = setOf(record.id) },
                )
            }
        }

        // La barre de sélection est ANCRÉE EN BAS, toujours visible : sans
        // elle, il fallait remonter toute la liste après avoir coché la
        // dernière partie.
        if (selecting) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .background(Palette.surfaceElevated)
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                TextButton(onClick = {
                    selection = if (selection.size == filtered.size) emptySet()
                    else filtered.map { it.id }.toSet()
                }) {
                    Text(
                        stringResource(
                            if (selection.size == filtered.size) R.string.library_select_none
                            else R.string.library_select_all
                        ),
                        color = Palette.accent, fontSize = 13.sp,
                    )
                }
                Spacer(Modifier.weight(1f))
                TextButton(
                    onClick = { confirmBatch = true },
                    enabled = selection.isNotEmpty(),
                    modifier = Modifier.testTag("supprimer-selection"),
                ) {
                    Text(
                        stringResource(R.string.library_delete_selected, selection.size),
                        color = if (selection.isEmpty()) Palette.textTertiary else Palette.danger,
                        fontSize = 13.sp,
                    )
                }
                TextButton(onClick = { selecting = false; selection = emptySet() }) {
                    Text(stringResource(R.string.cancel), color = Palette.textSecondary, fontSize = 13.sp)
                }
            }
        }
    }

    editing?.let { record ->
        TagsEditor(record, onDismiss = { editing = null }) { newTags ->
            scope.launch { withContext(Dispatchers.IO) { dao.setTags(record.id, newTags) } }
            editing = null
        }
    }

    deleting?.let { record ->
        AlertDialog(
            onDismissRequest = { deleting = null },
            title = { Text(stringResource(R.string.library_delete_title), color = Palette.textPrimary) },
            text = {
                Text(
                    "${record.white} — ${record.black}",
                    color = Palette.textSecondary,
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        scope.launch { withContext(Dispatchers.IO) { dao.delete(record.id) } }
                        deleting = null
                    },
                    modifier = Modifier.testTag("supprimer-oui"),
                ) { Text(stringResource(R.string.library_delete), color = Palette.danger) }
            },
            dismissButton = {
                TextButton(onClick = { deleting = null }) {
                    Text(stringResource(R.string.cancel), color = Palette.textSecondary)
                }
            },
            containerColor = Palette.surface,
        )
    }

    if (confirmBatch) {
        AlertDialog(
            onDismissRequest = { confirmBatch = false },
            title = {
                Text(
                    pluralStringResource(R.plurals.library_delete_many, selection.size, selection.size),
                    color = Palette.textPrimary,
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val ids = selection.toList()
                        scope.launch { withContext(Dispatchers.IO) { dao.deleteAll(ids) } }
                        confirmBatch = false
                        selecting = false
                        selection = emptySet()
                    },
                    modifier = Modifier.testTag("supprimer-lot-oui"),
                ) { Text(stringResource(R.string.library_delete), color = Palette.danger) }
            },
            dismissButton = {
                TextButton(onClick = { confirmBatch = false }) {
                    Text(stringResource(R.string.cancel), color = Palette.textSecondary)
                }
            },
            containerColor = Palette.surface,
        )
    }

    message?.let { text ->
        AlertDialog(
            onDismissRequest = { message = null },
            text = { Text(text, color = Palette.textPrimary, modifier = Modifier.testTag("import-resume")) },
            confirmButton = {
                TextButton(onClick = { message = null }) {
                    Text(stringResource(android.R.string.ok), color = Palette.accent)
                }
            },
            containerColor = Palette.surface,
        )
    }
}

/** Les filtres de résultat, DU POINT DE VUE de l'utilisateur. */
enum class ResultFilter(val label: Int) {
    all(R.string.library_all_results),
    wins(R.string.library_wins),
    draws(R.string.library_draws),
    losses(R.string.library_losses),
}

/**
 * Le tri, en fonction PURE pour être vérifiable sans écran.
 *
 * « Vous » est écrit littéralement par l'enregistreur du mode Jouer, ce qui le
 * rend reconnaissable quelle que soit la langue d'affichage — c'est ce qui
 * permet de dire « gagnée » ou « perdue » plutôt que « 1-0 ».
 */
fun filter(
    records: List<GameRecord>,
    query: String,
    mode: String?,
    result: ResultFilter,
    tag: String?,
): List<GameRecord> {
    val needle = query.trim().lowercase()
    return records.filter { record ->
        if (mode != null && record.source != mode) return@filter false
        if (result != ResultFilter.all && userResult(record) != result) return@filter false
        if (tag != null && record.tagList.none { it.equals(tag, ignoreCase = true) }) return@filter false
        if (needle.isEmpty()) return@filter true
        val haystack = (listOf(record.white, record.black, record.result) + record.tagList)
            .joinToString(" ") { it.lowercase() }
        haystack.contains(needle)
    }
}

/** Le résultat vu par l'utilisateur ; neutre quand il n'a pas joué la partie. */
fun userResult(record: GameRecord): ResultFilter {
    if (record.result == "1/2-1/2") return ResultFilter.draws
    val userIsWhite = record.engineColor == "black"
    val userIsBlack = record.engineColor == "white"
    return when {
        userIsWhite && record.result == "1-0" -> ResultFilter.wins
        userIsBlack && record.result == "0-1" -> ResultFilter.wins
        userIsWhite && record.result == "0-1" -> ResultFilter.losses
        userIsBlack && record.result == "1-0" -> ResultFilter.losses
        else -> ResultFilter.all
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun RecordRow(
    record: GameRecord,
    selecting: Boolean,
    checked: Boolean,
    onTap: () -> Unit,
    onEditTags: () -> Unit,
    onDelete: () -> Unit,
    onStartSelection: () -> Unit,
) {
    var menu by remember { mutableStateOf(false) }
    Row(
        Modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(Palette.surface)
            .subtleBorder(CardShape)
            .combinedClickable(
                onClick = onTap,
                onLongClick = { menu = true },
            )
            .padding(horizontal = 12.dp, vertical = 10.dp)
            .testTag("partie-${record.id}"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (selecting) {
            Icon(
                if (checked) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                null,
                tint = if (checked) Palette.accent else Palette.textTertiary,
                modifier = Modifier.size(22.dp),
            )
            Spacer(Modifier.width(10.dp))
        }
        Column(Modifier.weight(1f)) {
            Text(
                "${record.white} — ${record.black}",
                fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
            )
            Spacer(Modifier.height(4.dp))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                GameResultPill(record.result)
                Text(
                    DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT)
                        .format(Date(record.playedAt)),
                    fontSize = 11.sp, color = Palette.textSecondary,
                )
                Text(
                    pluralStringResource(R.plurals.analysis_move_count, record.moveCount, record.moveCount),
                    fontSize = 11.sp, color = Palette.textTertiary,
                )
            }
            // La précision, quand la partie a été analysée : c'est le chiffre
            // qu'on cherche en rouvrant une partie, et il était recalculé de
            // zéro à chaque fois.
            val white = record.whiteAccuracy
            val black = record.blackAccuracy
            if (white != null && black != null) {
                Spacer(Modifier.height(3.dp))
                Text(
                    stringResource(R.string.library_accuracy, white.toInt(), black.toInt()),
                    fontSize = 11.sp, color = Palette.teal,
                    modifier = Modifier.testTag("precision-${record.id}"),
                )
            }
            if (record.tagList.isNotEmpty()) {
                Spacer(Modifier.height(4.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    record.tagList.take(4).forEach { value ->
                        Text(
                            value,
                            fontSize = 10.sp, fontWeight = FontWeight.Medium, color = Palette.violet,
                            modifier = Modifier
                                .clip(CircleShape)
                                .background(Palette.violet.copy(alpha = 0.14f))
                                .padding(horizontal = 8.dp, vertical = 2.dp),
                        )
                    }
                }
            }
        }
        Icon(Icons.Default.ChevronRight, null, tint = Palette.textTertiary, modifier = Modifier.size(18.dp))
    }

    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
        DropdownMenuItem(
            text = { Text(stringResource(R.string.library_edit_tags), color = Palette.textPrimary) },
            leadingIcon = { Icon(Icons.Default.Sell, null, tint = Palette.violet) },
            onClick = { menu = false; onEditTags() },
            modifier = Modifier.testTag("etiqueter-${record.id}"),
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.library_select), color = Palette.textPrimary) },
            leadingIcon = { Icon(Icons.Default.CheckCircle, null, tint = Palette.accent) },
            onClick = { menu = false; onStartSelection() },
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.library_delete), color = Palette.danger) },
            leadingIcon = { Icon(Icons.Default.Delete, null, tint = Palette.danger) },
            onClick = { menu = false; onDelete() },
            modifier = Modifier.testTag("supprimer-${record.id}"),
        )
    }
}

/** Les étiquettes d'une partie, séparées par des virgules. */
@Composable
private fun TagsEditor(record: GameRecord, onDismiss: () -> Unit, onSave: (String?) -> Unit) {
    var text by remember { mutableStateOf(record.tagList.joinToString(", ")) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.library_edit_tags), color = Palette.textPrimary) },
        text = {
            Column {
                Text(
                    stringResource(R.string.library_tags_hint),
                    fontSize = 12.sp, color = Palette.textSecondary,
                )
                Spacer(Modifier.height(8.dp))
                BasicTextFieldWithPlaceholder(
                    value = text,
                    placeholder = stringResource(R.string.library_tags_placeholder),
                    tag = "etiquettes",
                ) { text = it }
            }
        },
        confirmButton = {
            TextButton(
                onClick = { onSave(text.trim().ifEmpty { null }) },
                modifier = Modifier.testTag("etiquettes-ok"),
            ) { Text(stringResource(R.string.save), color = Palette.accent) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel), color = Palette.textSecondary)
            }
        },
        containerColor = Palette.surface,
    )
}

@Composable
private fun EmptyLibrary(onImport: () -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            stringResource(R.string.library_empty_title),
            fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            stringResource(R.string.library_empty_body),
            fontSize = 13.sp, color = Palette.textSecondary,
        )
        Spacer(Modifier.height(16.dp))
        // Une bibliothèque vide est justement le moment où l'on veut importer :
        // ne pas obliger à trouver l'icône.
        Text(
            stringResource(R.string.library_import),
            fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
            modifier = Modifier
                .clip(CircleShape)
                .background(Palette.accent)
                .clickable(onClick = onImport)
                .padding(horizontal = 18.dp, vertical = 10.dp)
                .testTag("importer-pgn"),
        )
    }
}

/**
 * Importe un fichier PGN — une partie, ou cent. Rend le nombre de parties
 * ajoutées, ou `null` si le fichier est illisible.
 */
private suspend fun importPgn(
    context: android.content.Context,
    uri: Uri,
    dao: com.chesslab.library.GameDao,
): Int? = runCatching {
    val text = context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
        ?: return null
    val games = PgnSanitizer.splitIntoGames(PgnSanitizer.sanitize(text))
    var added = 0
    for (pgn in games) {
        val parsed = runCatching { chesskit.PgnParser.parse(pgn) }.getOrNull() ?: continue
        val plies = parsed.moves.indices
            .count { it.variation == chesskit.MoveTree.Index.MAIN_VARIATION }
        if (plies == 0) continue
        val inserted = dao.insert(
            GameRecord(
                playedAt = System.currentTimeMillis(),
                white = parsed.tags.white.ifEmpty { "?" },
                black = parsed.tags.black.ifEmpty { "?" },
                result = parsed.tags.result.ifEmpty { "*" },
                source = "imported",
                moveCount = plies,
                pgn = pgn,
            )
        )
        if (inserted > 0) added++
    }
    added
}.getOrNull()
