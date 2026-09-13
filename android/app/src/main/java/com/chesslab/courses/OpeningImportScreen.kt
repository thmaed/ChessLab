package com.chesslab.courses

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.ui.BasicTextFieldWithPlaceholder
import com.chesslab.ui.CardShape
import com.chesslab.ui.Palette
import com.chesslab.ui.accentGradient
import com.chesslab.ui.subtleBorder

/**
 * L'ajout d'un répertoire personnel : coller un PGN, ouvrir un `.pgn`, ou
 * recevoir le fichier d'un cours partagé par quelqu'un d'autre. Pendant
 * d'`OpeningImportSheet`.
 *
 * Le PGN est le format d'échange de fait des répertoires — une étude Lichess,
 * un chapitre de livre saisi, un export SCID. Comme le lecteur sait lire les
 * variantes entre parenthèses, on récupère l'arbre complet et pas seulement
 * une ligne.
 */
@Composable
fun OpeningImportScreen(onImported: (CatalogEntry) -> Unit) {
    val context = LocalContext.current
    val clipboard = LocalClipboardManager.current
    var name by remember { mutableStateOf("") }
    /**
     * Vrai tant que l'utilisateur n'a pas touché au champ : on peut alors
     * continuer à le remplir tout seul depuis le PGN. Dès qu'il écrit, on n'y
     * touche plus — rien de plus agaçant qu'un champ qui se réécrit sous les
     * doigts.
     */
    var nameEditedByUser by remember { mutableStateOf(false) }
    var side by remember { mutableStateOf("white") }
    var pgn by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var notice by remember { mutableStateOf<String?>(null) }

    val fallbackName = stringResource(R.string.import_fallback_name)
    val chapterLabel = stringResource(R.string.course_chapter_n)
    val errEmpty = stringResource(R.string.import_error_empty)
    val errUnreadable = stringResource(R.string.import_error_unreadable)
    val errNoMoves = stringResource(R.string.import_error_no_moves)
    val errMixed = stringResource(R.string.import_error_mixed)
    val errInvalid = stringResource(R.string.import_error_invalid)
    val errFile = stringResource(R.string.import_error_file)
    val noticeSkipped = stringResource(R.string.import_notice_skipped)

    fun suggest(text: String) {
        if (nameEditedByUser) return
        OpeningPgnImporter.suggestedName(text)?.let { name = it }
    }

    fun importPgn() {
        error = null; notice = null
        try {
            val result = OpeningPgnImporter.course(
                pgn, name = name, side = side, id = UserOpeningStore.newIdentifier(),
                fallbackName = fallbackName, chapterLabel = { chapterLabel.replace("%1\$d", "$it") },
            )
            val entry = UserOpeningStore.save(result.course)
            // On ne tait pas ce qui a été écarté : un répertoire amputé en
            // silence est pire qu'un import refusé.
            if (result.skippedGames > 0 || result.skippedMoves > 0) {
                notice = noticeSkipped.replace("%1\$d", "${result.skippedGames}").replace("%2\$d", "${result.skippedMoves}")
            }
            onImported(entry)
        } catch (e: OpeningPgnImporter.ImportException) {
            error = when (e) {
                is OpeningPgnImporter.ImportException.Empty -> errEmpty
                is OpeningPgnImporter.ImportException.Unreadable -> errUnreadable.replace("%1\$s", e.detail)
                is OpeningPgnImporter.ImportException.NoMoves -> errNoMoves
                is OpeningPgnImporter.ImportException.MixedStartingPositions -> errMixed
            }
        } catch (e: UserOpeningStore.StoreException) {
            error = errInvalid.replace("%1\$s", e.issues.take(3).joinToString(" · ").ifEmpty { e.message.orEmpty() })
        }
    }

    // Un fichier : un `.json` est un cours DÉJÀ construit (partagé par
    // quelqu'un), il entre tel quel ; tout le reste est lu comme un PGN.
    val open = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        val text = runCatching {
            context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
        }.getOrNull()
        if (text == null) { error = errFile; return@rememberLauncherForActivityResult }
        val trimmed = text.trimStart()
        if (trimmed.startsWith("{")) {
            runCatching { UserOpeningStore.importCourseFile(text) }
                .onSuccess { onImported(it) }
                .onFailure { error = errFile }
            return@rememberLauncherForActivityResult
        }
        pgn = text
        // Le nom vient du PGN quand il en porte un ; le nom de fichier n'est
        // qu'un dernier recours, souvent un identifiant illisible.
        if (!nameEditedByUser || name.isBlank()) {
            name = OpeningPgnImporter.suggestedName(text)
                ?: (uri.lastPathSegment?.substringAfterLast('/')?.substringBeforeLast('.') ?: "")
            nameEditedByUser = false
        }
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(stringResource(R.string.import_intro), fontSize = 13.sp, color = Palette.textSecondary)

        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Pill(stringResource(R.string.import_paste), "coller") {
                clipboard.getText()?.text?.let { pgn = it; suggest(it) }
            }
            Pill(stringResource(R.string.import_open_file), "ouvrir-fichier") { open.launch("*/*") }
        }

        FieldLabel(stringResource(R.string.import_name))
        Box(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(Palette.surface)
                .border(1.dp, Palette.stroke, RoundedCornerShape(10.dp)).padding(12.dp),
        ) {
            BasicTextFieldWithPlaceholder(
                name, stringResource(R.string.import_name_placeholder), Modifier.fillMaxWidth(),
                tag = "import-nom",
            ) { name = it; nameEditedByUser = true }
        }

        // Le camp décide de quel côté l'entraînement interroge : le seul choix
        // qu'un PGN ne porte pas et qu'on ne peut pas deviner sans risque.
        FieldLabel(stringResource(R.string.import_side))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Chip(stringResource(R.string.color_white), side == "white", "import-blancs") { side = "white" }
            Chip(stringResource(R.string.color_black), side == "black", "import-noirs") { side = "black" }
        }

        FieldLabel("PGN")
        OutlinedTextField(
            value = pgn,
            // Un PGN COLLÉ doit remplir le nom comme un fichier importé.
            onValueChange = { pgn = it; suggest(it) },
            modifier = Modifier.fillMaxWidth().heightIn(min = 200.dp).testTag("import-pgn"),
            textStyle = androidx.compose.ui.text.TextStyle(
                fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = Palette.textPrimary,
            ),
        )

        error?.let { Message(it, Palette.danger, "import-erreur") }
        notice?.let { Message(it, Palette.warning, "import-avis") }

        Text(
            stringResource(R.string.import_confirm),
            fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .clip(CircleShape)
                .background(accentGradient)
                .clickable(enabled = pgn.isNotBlank()) { importPgn() }
                .padding(vertical = 13.dp)
                .testTag("importer"),
        )
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun FieldLabel(text: String) {
    Text(text.uppercase(), fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Palette.textTertiary)
}

@Composable
private fun Pill(label: String, tag: String, onClick: () -> Unit) {
    Text(
        label, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
        modifier = Modifier
            .clip(CircleShape)
            .background(Palette.surfaceElevated)
            .border(1.dp, Palette.stroke, CircleShape)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp)
            .testTag(tag),
    )
}

@Composable
private fun Chip(label: String, selected: Boolean, tag: String, onClick: () -> Unit) {
    Text(
        label, fontSize = 13.sp, fontWeight = FontWeight.Medium,
        color = if (selected) Palette.background else Palette.textPrimary,
        modifier = Modifier
            .clip(CircleShape)
            .background(if (selected) Palette.accent else Palette.surfaceElevated)
            .border(1.dp, if (selected) androidx.compose.ui.graphics.Color.Transparent else Palette.stroke, CircleShape)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp)
            .testTag(tag),
    )
}

@Composable
private fun Message(text: String, tint: androidx.compose.ui.graphics.Color, tag: String) {
    Text(
        text, fontSize = 12.sp, color = Palette.textSecondary,
        modifier = Modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(Palette.surface)
            .border(1.dp, tint.copy(alpha = 0.45f), CardShape)
            .padding(12.dp)
            .testTag(tag),
    )
}
