package com.chesslab.puzzles

import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.library.LibraryDatabase
import com.chesslab.ui.CardShape
import com.chesslab.ui.Palette
import com.chesslab.ui.accentGradient
import com.chesslab.ui.cardGradient
import com.chesslab.ui.subtleBorder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Importer des puzzles depuis un fichier PGN : un ou plusieurs fichiers à la
 * fois, chacun devient une collection ([PuzzleCollectionStore]). On peut aussi
 * coller le texte. Pendant de `PuzzleImportSheet.swift`.
 *
 * Le bilan reste affiché après l'import : combien de puzzles, combien de parties
 * écartées et POURQUOI — un fichier de mille puzzles dont douze sont refusés ne
 * doit pas se contenter de « 988 importés ».
 *
 * Le sélecteur de fichiers est celui du système (`OpenMultipleDocuments`) :
 * aucune permission de stockage, et surtout aucune permission réseau.
 */
@Composable
fun PuzzleImportSheet(onClose: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val db = remember { LibraryDatabase.get(context) }

    var pastedName by remember { mutableStateOf("") }
    var pastedText by remember { mutableStateOf("") }
    var working by remember { mutableStateOf(false) }
    var reports by remember { mutableStateOf<List<PuzzleCollectionStore.ImportReport>>(emptyList()) }
    var unreadable by remember { mutableStateOf<List<String>>(emptyList()) }

    /** La lecture se fait HORS du fil principal ; l'écriture en base aussi. */
    suspend fun importText(text: String, name: String) {
        val parsed = withContext(Dispatchers.Default) { PuzzleCollectionImporter.parse(text) }
        val report = withContext(Dispatchers.IO) { PuzzleCollectionStore.add(db.importedPuzzles(), parsed, name) }
        reports = reports + report
    }

    val fallbackName = stringResource(R.string.puzzle_import_default_name)
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        if (uris.isEmpty()) return@rememberLauncherForActivityResult
        working = true
        scope.launch {
            for (uri in uris) {
                val fileName = displayName(context, uri)
                val text = withContext(Dispatchers.IO) { readText(context, uri) }
                if (text == null) {
                    unreadable = unreadable + fileName
                    continue
                }
                importText(text, PuzzleCollectionStore.suggestedName(fileName, fallbackName))
            }
            working = false
        }
    }

    Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp)) {
        // L'en-tête reste FIXE : « Fermer » ne doit pas défiler hors de l'écran quand on
        // descend vers le bouton d'import ou vers le bilan, sur un téléphone où la feuille
        // est plus courte que son contenu.
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                stringResource(R.string.puzzle_import_row_title),
                fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary, modifier = Modifier.weight(1f),
            )
            TextButton(onClick = onClose, modifier = Modifier.testTag("puzzleImportClose")) {
                Text(stringResource(R.string.puzzle_import_close), color = Palette.accent)
            }
        }
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(top = 18.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
        Text(stringResource(R.string.puzzle_import_intro), fontSize = 13.sp, color = Palette.textSecondary)

        Text(
            stringResource(R.string.puzzle_import_files),
            fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .alpha(if (working) 0.4f else 1f)
                .clip(CircleShape)
                .background(accentGradient)
                .clickable(enabled = !working) { pick.launch(arrayOf("*/*")) }
                .padding(vertical = 14.dp)
                .testTag("puzzleImportFiles"),
        )

        // Coller du texte.
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                stringResource(R.string.puzzle_import_paste_title).uppercase(),
                fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary, letterSpacing = 0.4.sp,
            )
            OutlinedTextField(
                value = pastedName,
                onValueChange = { pastedName = it },
                singleLine = true,
                placeholder = { Text(stringResource(R.string.puzzle_import_name_hint)) },
                modifier = Modifier.fillMaxWidth().testTag("puzzleImportName"),
            )
            OutlinedTextField(
                value = pastedText,
                onValueChange = { pastedText = it },
                modifier = Modifier.fillMaxWidth().heightIn(min = 110.dp).testTag("puzzleImportText"),
                textStyle = TextStyle(fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = Palette.textPrimary),
            )
            val canImport = !working && pastedText.isNotBlank()
            Text(
                stringResource(R.string.puzzle_import_text_btn),
                fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
                modifier = Modifier
                    .alpha(if (canImport) 1f else 0.4f)
                    .clip(CircleShape)
                    .background(Palette.surfaceElevated)
                    .border(1.dp, Palette.stroke, CircleShape)
                    .clickable(enabled = canImport) {
                        val text = pastedText
                        val name = pastedName.ifBlank { fallbackName }
                        working = true
                        scope.launch {
                            importText(text, name)
                            pastedText = ""
                            working = false
                        }
                    }
                    .padding(horizontal = 16.dp, vertical = 9.dp)
                    .testTag("puzzleImportPasted"),
            )
        }

        if (working) Text(stringResource(R.string.puzzle_import_reading), fontSize = 13.sp, color = Palette.textSecondary)
        unreadable.forEach {
            Text(
                stringResource(R.string.puzzle_import_unreadable, it),
                fontSize = 13.sp, color = Palette.danger,
            )
        }
        reports.forEach { ReportCard(it) }
        Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun ReportCard(report: PuzzleCollectionStore.ImportReport) {
    val ok = report.added > 0
    Column(
        Modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(cardGradient)
            .subtleBorder()
            .padding(14.dp)
            .testTag("puzzleImportReport"),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(
                if (ok) Icons.Default.CheckCircle else Icons.Default.ErrorOutline, null,
                tint = if (ok) Palette.accent else Palette.warning, modifier = Modifier.padding(end = 2.dp),
            )
            Text(report.collection, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary, maxLines = 1)
        }
        Text(summaryLine(report), fontSize = 13.sp, color = Palette.textSecondary)
        report.parsed.skipped.take(SKIPPED_SHOWN).forEach {
            Text("• " + describe(it), fontSize = 12.sp, color = Palette.textTertiary)
        }
        val more = report.parsed.skipped.size - SKIPPED_SHOWN
        if (more > 0) Text(pluralStringResource(R.plurals.puzzle_import_more, more, more), fontSize = 12.sp, color = Palette.textTertiary)
    }
}

/** Combien de parties écartées on détaille ; le reste est résumé. */
private const val SKIPPED_SHOWN = 5

/** « 947 puzzles ajoutés · 12 parties écartées », sur une ligne. */
@Composable
private fun summaryLine(report: PuzzleCollectionStore.ImportReport): String {
    if (report.parsed.gameCount == 0 || (report.added == 0 && report.alreadyThere == 0 && report.parsed.skipped.isEmpty())) {
        return stringResource(R.string.puzzle_import_none)
    }
    val parts = ArrayList<String>()
    parts += pluralStringResource(R.plurals.puzzle_import_added, report.added, report.added)
    if (report.alreadyThere > 0) parts += stringResource(R.string.puzzle_import_already, report.alreadyThere)
    if (report.parsed.duplicates > 0) parts += stringResource(R.string.puzzle_import_dupes, report.parsed.duplicates)
    if (report.parsed.skipped.isNotEmpty()) parts += pluralStringResource(R.plurals.puzzle_import_skipped, report.parsed.skipped.size, report.parsed.skipped.size)
    return parts.joinToString(" · ")
}

@Composable
private fun describe(skip: PuzzleCollectionImporter.Skip): String = when (val reason = skip.reason) {
    PuzzleCollectionImporter.SkipReason.MissingFen -> stringResource(R.string.puzzle_skip_missing_fen, skip.gameNumber)
    PuzzleCollectionImporter.SkipReason.InvalidFen -> stringResource(R.string.puzzle_skip_invalid_fen, skip.gameNumber)
    PuzzleCollectionImporter.SkipReason.NoMoves -> stringResource(R.string.puzzle_skip_no_moves, skip.gameNumber)
    PuzzleCollectionImporter.SkipReason.NoSolution -> stringResource(R.string.puzzle_skip_no_solution, skip.gameNumber)
    is PuzzleCollectionImporter.SkipReason.IllegalMove -> stringResource(R.string.puzzle_skip_illegal, skip.gameNumber, reason.san)
}

private fun displayName(context: android.content.Context, uri: Uri): String {
    val fromProvider = runCatching {
        context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0) else null
        }
    }.getOrNull()
    return fromProvider ?: uri.lastPathSegment?.substringAfterLast('/') ?: ""
}

/**
 * UTF-8, à défaut Latin-1 : les fichiers venus de Windows ou d'un vieux logiciel
 * d'échecs ne sont pas toujours en UTF-8. `null` si le fichier ne s'ouvre pas.
 */
internal fun readText(context: android.content.Context, uri: Uri): String? {
    val bytes = runCatching { context.contentResolver.openInputStream(uri)?.use { it.readBytes() } }.getOrNull()
        ?: return null
    val utf8 = Charsets.UTF_8.newDecoder()
        .onMalformedInput(java.nio.charset.CodingErrorAction.REPORT)
        .onUnmappableCharacter(java.nio.charset.CodingErrorAction.REPORT)
    return runCatching { utf8.decode(java.nio.ByteBuffer.wrap(bytes)).toString() }
        .getOrElse { String(bytes, Charsets.ISO_8859_1) }
}
