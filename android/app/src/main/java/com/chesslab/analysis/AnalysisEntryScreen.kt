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

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        EntryCard(
            stringResource(R.string.entry_scan), stringResource(R.string.entry_scan_sub),
            Icons.Default.PhotoCamera, Palette.accent, "entree-scanner", onClick = onScan,
        )
        EntryCard(
            stringResource(R.string.analysis_library),
            pluralStringResource(R.plurals.progress_games_count, games.size, games.size),
            Icons.Default.MenuBook, Palette.warning, "entree-bibliotheque",
            // Toujours ouverte, même vide : c'est de là qu'on IMPORTE un
            // fichier PGN, et une bibliothèque vide est justement le moment
            // où l'on veut le faire.
            enabled = true,
            modifier = Modifier.discoveryAnchor(DiscoverySpot.analysisLibrary), onClick = onLibrary,
        )
        if (lastPgn != null && lastPgn.isNotEmpty()) {
            EntryCard(
                stringResource(R.string.entry_last_game), stringResource(R.string.entry_last_game_sub),
                Icons.Default.History, Palette.info, "entree-derniere",
            ) { onLastGame(lastPgn) }
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
