package com.chesslab.lab

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.chesslab.maia.OpponentGallery
import com.chesslab.maia.OpponentProfile
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
import com.chesslab.ui.MoveStrip
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.text.style.TextAlign
import com.chesslab.ui.accentGradient
import com.chesslab.ui.Palette
import com.chesslab.ui.StatusRow
import androidx.compose.ui.res.stringResource
import com.chesslab.R
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString

@Composable
fun LabScreen(
    /** La position envoyée par un autre mode : la série part de là. */
    startFen: String? = null,
    model: LabViewModel = viewModel(),
) {
    val ui = model.ui

    LaunchedEffect(startFen) { if (startFen != null) model.startFrom(startFen) }

    BoardScaffold(
        header = {
            Scoreboard(ui)
            Spacer(Modifier.height(8.dp))
            SidePicker(stringResource(R.string.lab_side_a), ui.sideA.profile, "a", model::setSideA)
            Spacer(Modifier.height(6.dp))
            SidePicker(stringResource(R.string.lab_side_b), ui.sideB.profile, "b", model::setSideB)

            Spacer(Modifier.height(8.dp))
            StatusRow(ui.status, busy = ui.running)
            Spacer(Modifier.height(8.dp))
        },
        board = {
            BoardView(position = ui.position, lastMove = ui.lastMove, enabled = false)
        },
        panel = {
            Spacer(Modifier.height(10.dp))
            MoveStrip(ui.sanMoves)

            Spacer(Modifier.height(12.dp))
            LabStatsPanel(ui)

            Spacer(Modifier.height(12.dp))
            StartPositionField(ui, model::startFrom, model::clearStartPosition)

            if (ui.completed.isNotEmpty()) {
                Spacer(Modifier.height(12.dp))
                ExportRow(model)
            }

            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    stringResource(if (ui.running) R.string.lab_pause else R.string.lab_start),
                    fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .clip(CircleShape)
                        .background(accentGradient)
                        .clickable { model.toggle() }
                        .padding(vertical = 13.dp)
                        .testTag("lancer"),
                )
                Text(
                    stringResource(R.string.lab_reset),
                    fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .clip(CircleShape)
                        .background(Palette.surfaceElevated)
                        .border(1.dp, Palette.stroke, CircleShape)
                        .clickable { model.reset() }
                        .padding(vertical = 13.dp)
                        .testTag("remise"),
                )
            }
        },
    )
}

/**
 * Le champ qui impose la position de départ. Un FEN ou un PGN — un PGN fait
 * partir la série de sa position FINALE, ce qui permet de tester une ouverture
 * qu'on vient de coller sans en recopier la position.
 */
@Composable
private fun StartPositionField(
    ui: LabUiState,
    onResolve: (String) -> Unit,
    onClear: () -> Unit,
) {
    var text by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var note by remember { mutableStateOf<String?>(null) }
    val unreadable = stringResource(R.string.lab_start_unreadable)
    val fromPgn = stringResource(R.string.lab_start_from_pgn, 0)

    Column(Modifier.fillMaxWidth()) {
        Text(
            stringResource(R.string.lab_start_position),
            fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary,
        )
        Spacer(Modifier.height(2.dp))
        Text(
            stringResource(R.string.lab_start_position_sub),
            fontSize = 10.sp, color = Palette.textTertiary,
        )
        Spacer(Modifier.height(6.dp))
        OutlinedTextField(
            value = text,
            onValueChange = { text = it; error = null },
            modifier = Modifier.fillMaxWidth().heightIn(min = 72.dp).testTag("position-depart"),
            textStyle = androidx.compose.ui.text.TextStyle(
                fontSize = 11.sp,
                fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                color = Palette.textPrimary,
            ),
        )
        error?.let {
            Text(it, fontSize = 11.sp, color = Palette.danger, modifier = Modifier.padding(top = 4.dp))
        }
        note?.let {
            Text(it, fontSize = 11.sp, color = Palette.textTertiary, modifier = Modifier.padding(top = 4.dp))
        }
        Spacer(Modifier.height(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SmallPill(stringResource(R.string.lab_start_position), "poser-position") {
                val resolved = LabStartPosition.resolve(text)
                if (resolved == null) { error = unreadable; note = null; return@SmallPill }
                error = null
                note = if (resolved.fromPgn) fromPgn.replace("0", "${resolved.plies}") else null
                onResolve(resolved.fen)
            }
            if (ui.startFen != null) {
                SmallPill(stringResource(R.string.lab_start_standard), "position-standard") {
                    text = ""; error = null; note = null; onClear()
                }
            }
        }
    }
}

/** Exporter la série : le PGN de toutes les parties, ou le CSV des résultats. */
@Composable
private fun ExportRow(model: LabViewModel) {
    val context = LocalContext.current
    val clipboard = LocalClipboardManager.current
    val chooserTitle = stringResource(R.string.lab_export)

    fun send(text: String) {
        if (text.isEmpty()) return
        // Le presse-papiers EN PLUS du partage, comme pour l'analyse : la
        // feuille de partage dépend des apps installées, le presse-papiers non.
        clipboard.setText(AnnotatedString(text))
        val intent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(android.content.Intent.EXTRA_TEXT, text)
        }
        runCatching { context.startActivity(android.content.Intent.createChooser(intent, chooserTitle)) }
    }

    Column {
        Text(
            stringResource(R.string.lab_export),
            fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary,
        )
        Spacer(Modifier.height(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SmallPill(stringResource(R.string.lab_export_pgn), "export-pgn") { send(model.exportPgn()) }
            SmallPill(stringResource(R.string.lab_export_csv), "export-csv") { send(model.exportCsv()) }
        }
    }
}

@Composable
private fun SmallPill(label: String, tag: String, onClick: () -> Unit) {
    Text(
        label,
        fontSize = 12.sp, fontWeight = FontWeight.Medium, color = Palette.textPrimary,
        modifier = Modifier
            .clip(CircleShape)
            .background(Palette.surfaceElevated)
            .border(1.dp, Palette.stroke, CircleShape)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .testTag(tag),
    )
}

@Composable
private fun Scoreboard(ui: LabUiState) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Palette.surface)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                "${ui.winsA} — ${ui.draws} — ${ui.winsB}",
                fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
                modifier = Modifier.testTag("bilan"),
            )
            // Ces trois libellés étaient écrits EN DUR, donc en français au
            // milieu d'un écran anglais. Les ressources existaient déjà.
            Text(
                stringResource(R.string.lab_game_number, ui.gameNumber + 1) + " · " +
                    stringResource(if (ui.aPlaysWhite) R.string.lab_a_white else R.string.lab_a_black),
                fontSize = 11.sp, color = Palette.textTertiary,
            )
        }
        Text(stringResource(R.string.lab_legend), fontSize = 11.sp, color = Palette.textSecondary)
    }
}

@Composable
private fun SidePicker(label: String, selected: OpponentProfile?, tag: String, onPick: (OpponentProfile?) -> Unit) {
    Column {
        Text(label, fontSize = 11.sp, color = Palette.textTertiary)
        Row(
            Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Chip(stringResource(R.string.stockfish), selected == null, "camp-$tag-stockfish") { onPick(null) }
            OpponentGallery.all.forEach { profile ->
                Chip(profile.firstName, profile.id == selected?.id, "camp-$tag-${profile.id}") { onPick(profile) }
            }
        }
    }
}

@Composable
private fun Chip(label: String, active: Boolean, tag: String, onClick: () -> Unit) {
    Text(
        label,
        fontSize = 11.sp,
        color = if (active) Palette.background else Palette.textSecondary,
        modifier = Modifier
            .testTag(tag)
            .clip(RoundedCornerShape(12.dp))
            .background(if (active) Palette.accent else Palette.surface)
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 5.dp),
    )
}
