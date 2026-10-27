package com.chesslab.analysis

import com.chesslab.discovery.DiscoverySpot
import com.chesslab.discovery.discoveryAnchor

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ContentPaste
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.NoteAdd
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.chesslab.R
import com.chesslab.library.LibraryDatabase
import com.chesslab.ui.EntryCard
import com.chesslab.ui.tintedCardBorder
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import com.chesslab.ui.Palette

/**
 * Le choix de la source, avant d'analyser. Pendant d'`AnalysisEntryView`.
 *
 * Les trois chemins courts d'abord — scanner une position sous les yeux,
 * rouvrir une partie rangée, reprendre la dernière — puis ceux qui demandent
 * de fournir un texte ou de composer une position, qui sont un travail et non
 * un raccourci.
 */
@Composable
fun AnalysisEntryScreen(
    onScan: () -> Unit,
    onLibrary: () -> Unit,
    onLastGame: (String) -> Unit,
    /** Un PGN ou une FEN saisis à la main, ou lus dans un fichier. */
    onPaste: (String) -> Unit,
    onEditor: () -> Unit,
    /** C6 : « Mats manqués » depuis la carte de la dernière partie. */
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val games by remember { LibraryDatabase.get(context).games().all() }
        .collectAsState(initial = emptyList())
    val lastPgn = games.firstOrNull()?.pgn

    var showOthers by remember { mutableStateOf(false) }
    var showPasteSheet by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }

    val unreadable = stringResource(R.string.library_import_failed)
    // Un fichier à ANALYSER : on lit son texte et on l'envoie tel quel.
    val openForAnalysis = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            val text = withContext(Dispatchers.IO) {
                runCatching {
                    context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
                }.getOrNull()
            }
            if (text.isNullOrBlank()) message = unreadable else onPaste(text)
        }
    }

    // BORNÉE et centrée : trois cartes étirées sur une tablette laissaient
    // 70 % de noir sous elles. iOS borne pareil (`Theme.readableWidth`).
    com.chesslab.ui.ReadableColumn(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        // C6 : la dernière partie d'abord, avec ses deux gestes — ce qu'on vient
        // faire ici, le plus souvent.
        val last = games.firstOrNull()
        if (last != null && last.pgn.isNotEmpty()) {
            LastGameCard(last, onAnalyze = { onLastGame(last.pgn) })
        }
        Row(Modifier.fillMaxWidth().height(IntrinsicSize.Max), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            TileCard(
                stringResource(R.string.entry_scan), stringResource(R.string.entry_scan_sub),
                Icons.Default.PhotoCamera, Palette.accent, "entree-scanner", Modifier.weight(1f).fillMaxHeight(), onScan,
            )
            TileCard(
                stringResource(R.string.analysis_library),
                pluralStringResource(R.plurals.progress_games_count, games.size, games.size),
                Icons.Default.MenuBook, Palette.warning, "entree-bibliotheque",
                // Toujours ouverte, même vide : c'est de là qu'on IMPORTE un
                // fichier PGN, et une bibliothèque vide est justement le moment
                // où l'on veut le faire.
                Modifier.weight(1f).fillMaxHeight().discoveryAnchor(DiscoverySpot.analysisLibrary), onLibrary,
            )
        }
        // Les chemins qui demandent un TRAVAIL — fournir un texte, ouvrir un
        // fichier, composer une position — sont repliés : ce sont des
        // exceptions, pas la façon ordinaire d'arriver sur l'analyse.
        EntryCard(
            stringResource(R.string.entry_other_sources),
            stringResource(R.string.entry_other_sources_sub),
            if (showOthers) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
            Palette.textSecondary, "entree-autres",
        ) { showOthers = !showOthers }

        if (showOthers) {
            EntryCard(
                stringResource(R.string.entry_paste), stringResource(R.string.entry_paste_sub),
                Icons.Default.ContentPaste, Palette.teal, "entree-coller",
            ) { showPasteSheet = true }
            EntryCard(
                stringResource(R.string.entry_open_file), stringResource(R.string.entry_open_file_sub),
                Icons.Default.NoteAdd, Palette.teal, "entree-fichier",
            ) { openForAnalysis.launch(arrayOf("*/*")) }
            EntryCard(
                stringResource(R.string.route_editor), stringResource(R.string.entry_editor_sub),
                Icons.Default.Edit, Palette.rose, "entree-editeur", onClick = onEditor,
            )
        }
        Spacer(Modifier.height(12.dp))
    }

    if (showPasteSheet) {
        PasteSheet(
            onDismiss = { showPasteSheet = false },
            onConfirm = { text, alsoLibrary ->
                showPasteSheet = false
                if (alsoLibrary) {
                    scope.launch {
                        withContext(Dispatchers.IO) {
                            addToLibrary(LibraryDatabase.get(context).games(), text)
                        }
                    }
                }
                onPaste(text)
            },
        )
    }

    message?.let { text ->
        AlertDialog(
            onDismissRequest = { message = null },
            text = { Text(text, color = Palette.textPrimary) },
            confirmButton = {
                TextButton(onClick = { message = null }) {
                    Text(stringResource(android.R.string.ok), color = Palette.accent)
                }
            },
            containerColor = Palette.surface,
        )
    }
}

/** C6 : une tuile haute, pour les deux entrées que l'on choisit à l'œil. */
@Composable
private fun TileCard(
    title: String, subtitle: String, icon: androidx.compose.ui.graphics.vector.ImageVector,
    tint: androidx.compose.ui.graphics.Color, tag: String, modifier: Modifier, onClick: () -> Unit,
) {
    Column(
        modifier
            .clip(com.chesslab.ui.CardShape)
            .background(tint.copy(alpha = 0.10f))
            .tintedCardBorder(tint)
            .clickable(onClick = onClick)
            .padding(16.dp)
            .testTag(tag),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        com.chesslab.ui.IconBadge(icon, tint, 52.dp, true)
        Text(title, fontSize = 15.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold, color = Palette.textPrimary)
        Text(subtitle, fontSize = 12.sp, color = Palette.textSecondary, maxLines = 3)
    }
}

/**
 * C6 : la dernière partie, ses chiffres, et le geste qu'on vient y faire — l'analyser (le récapitulatif
 * de fin d'analyse propose alors les puzzles, mats manqués compris).
 */
@Composable
private fun LastGameCard(record: com.chesslab.library.GameRecord, onAnalyze: () -> Unit) {
    val chips = ArrayList<String>()
    chips += java.text.DateFormat.getDateInstance(java.text.DateFormat.MEDIUM).format(java.util.Date(record.playedAt))
    record.openingName?.let { chips += it }
    if (record.analysisVersion == AnalysisViewModel.ANALYSIS_VERSION && record.engineColor != null) {
        val accuracy = if (record.engineColor == "black") record.whiteAccuracy else record.blackAccuracy
        accuracy?.let { chips += stringResource(R.string.entry_last_accuracy, Math.round(it).toInt()) }
    }
    val tint = Palette.info
    Column(
        Modifier
            .fillMaxWidth()
            .clip(com.chesslab.ui.CardShape)
            .background(com.chesslab.ui.cardGradient)
            .tintedCardBorder(tint)
            .padding(16.dp)
            .testTag("entree-derniere"),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
            com.chesslab.ui.IconBadge(Icons.Default.History, tint, 44.dp, true)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.entry_last_game), fontSize = 15.sp,
                    fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold, color = Palette.textPrimary)
                Text("${record.white} – ${record.black}", fontSize = 13.sp, color = Palette.textSecondary, maxLines = 1)
            }
            Text(
                record.result, fontSize = 12.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace, color = Palette.textPrimary,
                modifier = Modifier
                    .clip(androidx.compose.foundation.shape.CircleShape)
                    .background(Palette.surfaceElevated)
                    .padding(horizontal = 8.dp, vertical = 3.dp),
            )
        }
        @OptIn(ExperimentalLayoutApi::class)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            chips.forEach { chip ->
                Text(
                    chip, fontSize = 12.sp, color = Palette.textSecondary,
                    modifier = Modifier
                        .clip(androidx.compose.foundation.shape.CircleShape)
                        .background(Palette.surfaceElevated.copy(alpha = 0.7f))
                        .padding(horizontal = 9.dp, vertical = 4.dp),
                )
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            androidx.compose.material3.Button(
                onClick = onAnalyze,
                modifier = Modifier.weight(1f).height(44.dp).testTag("derniere-analyser"),
                colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                    containerColor = Palette.accent, contentColor = Palette.background),
            ) { Text(stringResource(R.string.entry_last_analyze), fontWeight = androidx.compose.ui.text.font.FontWeight.Bold) }
        }
    }
}

/**
 * La feuille où l'on colle un PGN ou une FEN. Une feuille et non un champ
 * posé sous le plateau : on colle AVANT d'analyser, et l'écran d'analyse n'a
 * pas à porter un formulaire qui ne sert qu'une fois.
 */
@Composable
private fun PasteSheet(onDismiss: () -> Unit, onConfirm: (String, Boolean) -> Unit) {
    var text by remember { mutableStateOf("") }
    var alsoLibrary by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.entry_paste), color = Palette.textPrimary) },
        text = {
            Column {
                OutlinedTextField(
                    value = text,
                    onValueChange = { text = it },
                    label = { Text(stringResource(R.string.analysis_input_label)) },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 110.dp).testTag("saisie"),
                    textStyle = androidx.compose.ui.text.TextStyle(
                        fontSize = 12.sp,
                        fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                    ),
                )
                Spacer(Modifier.height(8.dp))
                // Sans effet sur une FEN : la bibliothèque range des PARTIES.
                com.chesslab.ui.ToggleRow(
                    stringResource(R.string.entry_also_library), alsoLibrary, "aussi-bibliotheque",
                ) { alsoLibrary = it }
                Text(
                    stringResource(R.string.entry_also_library_note),
                    fontSize = 10.sp, color = Palette.textTertiary,
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = { if (text.isNotBlank()) onConfirm(text.trim(), alsoLibrary) },
                modifier = Modifier.testTag("charger"),
            ) { Text(stringResource(R.string.analysis_load), color = Palette.accent) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel), color = Palette.textSecondary)
            }
        },
        containerColor = Palette.surface,
    )
}

/** Range aussi la partie collée dans la bibliothèque, quand c'en est une. */
private suspend fun addToLibrary(dao: com.chesslab.library.GameDao, text: String) {
    runCatching {
        val pgn = PgnSanitizer.splitIntoGames(PgnSanitizer.sanitize(text)).firstOrNull() ?: return
        val parsed = chesskit.PgnParser.parse(pgn)
        val plies = parsed.moves.indices
            .count { it.variation == chesskit.MoveTree.Index.MAIN_VARIATION }
        if (plies == 0) return
        // Analyser cinq fois la même partie collée ne doit pas la ranger cinq
        // fois : iOS passe ici par le même dédoublonnage que l'import.
        val signature = com.chesslab.library.GameSignature.of(pgn)
        if (signature != null &&
            dao.allOnce().any { com.chesslab.library.GameSignature.of(it.pgn) == signature }
        ) return
        dao.insert(
            com.chesslab.library.GameRecord(
                playedAt = System.currentTimeMillis(),
                white = parsed.tags.white.ifEmpty { "?" },
                black = parsed.tags.black.ifEmpty { "?" },
                result = parsed.tags.result.ifEmpty { "*" },
                source = "imported", moveCount = plies, pgn = pgn,
            )
        )
    }
}
