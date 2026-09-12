package com.chesslab.analysis

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.*
import androidx.compose.foundation.clickable
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
import com.chesslab.ui.MoveStrip
import com.chesslab.ui.Palette
import com.chesslab.ui.StatusRow
import androidx.compose.ui.res.stringResource
import com.chesslab.R
import androidx.compose.ui.res.pluralStringResource

@Composable
fun AnalysisScreen(
    initialFen: String? = null,
    initialPgn: String? = null,
    model: AnalysisViewModel = viewModel(),
) {
    LaunchedEffect(initialFen, initialPgn) {
        val incoming = initialFen?.takeIf { it.isNotBlank() } ?: initialPgn?.takeIf { it.isNotBlank() }
        if (incoming != null) { model.onInputChange(incoming); model.load() }
    }
    val ui = model.ui

    BoardScaffold(
        header = {
            StatusRow(ui.status, busy = ui.thinking)
            Spacer(Modifier.height(8.dp))

            EvaluationBar(ui)
            Spacer(Modifier.height(10.dp))
        },
        board = {
            BoardView(
                position = ui.position,
                lastMove = ui.lastMove,
                checkedKing = ui.checkedKing,
                enabled = false,
            )
        },
        panel = {
            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = model::previous, modifier = Modifier.testTag("precedent")) {
                    Icon(Icons.Default.ChevronLeft, stringResource(R.string.previous_move), tint = Palette.textPrimary)
                }
                IconButton(onClick = model::next, modifier = Modifier.testTag("suivant")) {
                    Icon(Icons.Default.ChevronRight, stringResource(R.string.next_move), tint = Palette.textPrimary)
                }
                Spacer(Modifier.width(8.dp))
                Box(Modifier.weight(1f)) {
                    MoveStrip(ui.sanMoves, selected = ui.cursor.takeIf { it >= 0 }, onSelect = model::goTo)
                }
            }

            Spacer(Modifier.height(12.dp))
            SavedGames(model)

            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = ui.input,
                onValueChange = model::onInputChange,
                label = { Text(stringResource(R.string.analysis_input_label)) },
                modifier = Modifier.fillMaxWidth().heightIn(min = 96.dp).testTag("saisie"),
                textStyle = androidx.compose.ui.text.TextStyle(fontSize = 12.sp, fontFamily = FontFamily.Monospace),
            )
            if (ui.error != null) {
                Text(ui.error!!, color = Palette.danger, fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp))
            }
            TextButton(onClick = model::load, modifier = Modifier.testTag("charger")) {
                Text(stringResource(R.string.analysis_load), color = Palette.accent)
            }
        },
    )
}

/** La bibliothèque : les parties déjà jouées, rechargeables d'un tap. */
@Composable
private fun SavedGames(model: AnalysisViewModel) {
    val games by model.savedGames.collectAsState(initial = emptyList())
    if (games.isEmpty()) return

    Text(stringResource(R.string.analysis_library), fontSize = 12.sp, color = Palette.textTertiary)
    Spacer(Modifier.height(4.dp))
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        games.take(8).forEach { record ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .testTag("partie-${record.id}")
                    .clip(RoundedCornerShape(8.dp))
                    .background(Palette.surface)
                    .clickable { model.open(record) }
                    .padding(horizontal = 10.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "${record.white} — ${record.black}",
                    fontSize = 12.sp, color = Palette.textPrimary, modifier = Modifier.weight(1f),
                )
                Text(record.result, fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = Palette.accent)
                Spacer(Modifier.width(8.dp))
                Text(pluralStringResource(R.plurals.analysis_move_count, record.moveCount, record.moveCount), fontSize = 10.sp, color = Palette.textTertiary)
            }
        }
    }
}

@Composable
private fun EvaluationBar(ui: AnalysisUiState) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Palette.surface)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            ui.evaluation.ifEmpty { "—" },
            fontSize = 20.sp,
            fontWeight = FontWeight.SemiBold,
            fontFamily = FontFamily.Monospace,
            color = when {
                ui.evaluation.startsWith("+") -> Palette.accent
                ui.evaluation.startsWith("−") -> Palette.danger
                else -> Palette.textTertiary
            },
            modifier = Modifier.testTag("evaluation"),
        )
        Spacer(Modifier.width(12.dp))
        Column {
            if (ui.depth > 0) {
                Text("profondeur ${ui.depth}", fontSize = 11.sp, color = Palette.textTertiary)
            }
            if (ui.bestLine.isNotEmpty()) {
                Text(
                    ui.bestLine.split(" ").take(6).joinToString(" "),
                    fontSize = 11.sp,
                    fontFamily = FontFamily.Monospace,
                    color = Palette.textSecondary,
                    maxLines = 1,
                )
            }
        }
    }
}
