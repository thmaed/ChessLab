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
    onPaste: () -> Unit,
    onEditor: () -> Unit,
) {
    val context = LocalContext.current
    val games by remember { LibraryDatabase.get(context).games().all() }
        .collectAsState(initial = emptyList())
    val lastPgn = games.firstOrNull()?.pgn

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
            enabled = games.isNotEmpty(),
            modifier = Modifier.discoveryAnchor(DiscoverySpot.analysisLibrary), onClick = onLibrary,
        )
        if (lastPgn != null && lastPgn.isNotEmpty()) {
            EntryCard(
                stringResource(R.string.entry_last_game), stringResource(R.string.entry_last_game_sub),
                Icons.Default.History, Palette.info, "entree-derniere",
            ) { onLastGame(lastPgn) }
        }
        EntryCard(
            stringResource(R.string.entry_paste), stringResource(R.string.entry_paste_sub),
            Icons.Default.ContentPaste, Palette.teal, "entree-coller", onClick = onPaste,
        )
        EntryCard(
            stringResource(R.string.route_editor), stringResource(R.string.entry_editor_sub),
            Icons.Default.Edit, Palette.rose, "entree-editeur", onClick = onEditor,
        )
        Spacer(Modifier.height(12.dp))
    }
}
