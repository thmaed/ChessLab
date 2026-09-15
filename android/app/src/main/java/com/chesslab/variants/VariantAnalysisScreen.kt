package com.chesslab.variants

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.FirstPage
import androidx.compose.material.icons.filled.LastPage
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.chesslab.R
import com.chesslab.analysis.EvalConversion
import com.chesslab.analysis.MoveQuality
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
import com.chesslab.ui.Palette
import com.chesslab.ui.StatusRow

/**
 * Revoir une partie de VARIANTE. Pendant de `VariantAnalysisView`.
 *
 * Volontairement plus simple que l'analyse orthodoxe — ni ouvertures, ni
 * puzzles, ni coups candidats : aucune théorie ne porte sur ces jeux. On
 * navigue, on lit l'évaluation que Fairy-Stockfish rend POUR CETTE VARIANTE,
 * et les pastilles disent où la partie a basculé.
 */
@Composable
fun VariantAnalysisScreen(
    variantId: String,
    startFen: String?,
    uciLog: List<String>,
    /** Les positions, quand les coups ne les reproduisent pas (canard, tour double). */
    fenLog: List<String> = emptyList(),
    model: VariantAnalysisViewModel = viewModel(),
) {
    LaunchedEffect(variantId, startFen, uciLog, fenLog) { model.load(variantId, startFen, uciLog, fenLog) }
    val ui = model.ui

    BoardScaffold(
        header = {
            com.chesslab.ui.ThermalBadge()
            Text(ui.variantName, fontSize = 12.sp, color = Palette.textTertiary)
            Spacer(Modifier.height(4.dp))
            if (ui.engineUnavailable) {
                Text(
                    stringResource(R.string.play_engine_down),
                    fontSize = 12.sp, color = Palette.danger,
                    modifier = Modifier.testTag("moteur-absent"),
                )
            } else {
                StatusRow(ui.evaluation.ifEmpty { "—" }, busy = ui.thinking)
            }
            Spacer(Modifier.height(8.dp))
        },
        board = {
            BoardView(
                position = ui.position,
                lastMove = ui.lastMove,
                walls = ui.walls,
                enabled = false,
            )
        },
        panel = {
            Spacer(Modifier.height(10.dp))
            EvalBar(ui)

            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(
                    onClick = model::toStart, enabled = ui.canGoPrevious,
                    modifier = Modifier.testTag("debut"),
                ) { Icon(Icons.Default.FirstPage, stringResource(R.string.two_first_move), tint = Palette.textPrimary) }
                IconButton(
                    onClick = model::previous, enabled = ui.canGoPrevious,
                    modifier = Modifier.testTag("precedent"),
                ) { Icon(Icons.Default.ChevronLeft, stringResource(R.string.previous_move), tint = Palette.textPrimary) }
                IconButton(
                    onClick = model::next, enabled = ui.canGoNext,
                    modifier = Modifier.testTag("suivant"),
                ) { Icon(Icons.Default.ChevronRight, stringResource(R.string.next_move), tint = Palette.textPrimary) }
                IconButton(
                    onClick = model::toEnd, enabled = ui.canGoNext,
                    modifier = Modifier.testTag("fin"),
                ) { Icon(Icons.Default.LastPage, stringResource(R.string.two_last_move), tint = Palette.textPrimary) }
                Spacer(Modifier.weight(1f))
                ui.displayedQuality?.let { quality ->
                    Text(
                        stringResource(quality.labelRes),
                        fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = quality.tint,
                        modifier = Modifier.testTag("verdict-coup"),
                    )
                }
            }

            if (ui.classifying) {
                Spacer(Modifier.height(8.dp))
                Text(
                    stringResource(R.string.analysis_reviewing, ui.done, ui.total),
                    fontSize = 12.sp, color = Palette.textSecondary,
                    modifier = Modifier.testTag("revue-en-cours"),
                )
                Spacer(Modifier.height(4.dp))
                LinearProgressIndicator(
                    progress = { if (ui.total == 0) 0f else ui.done.toFloat() / ui.total },
                    color = Palette.accent, trackColor = Palette.surface,
                    drawStopIndicator = {},
                    modifier = Modifier.fillMaxWidth().height(4.dp).clip(CircleShape),
                )
            }

            Spacer(Modifier.height(10.dp))
            MoveTrail(ui, model::goTo)
            Spacer(Modifier.height(12.dp))
        },
    )
}

/**
 * Les coups en LAN, chacun teinté par sa qualité. Pas de notation algébrique :
 * celle de `chesskit` ne connaît ni le parachutage du Crazyhouse ni le canard,
 * et un coup mal noté vaut moins qu'un coup noté brut.
 */
@Composable
private fun MoveTrail(ui: VariantAnalysisUiState, onPick: (Int) -> Unit) {
    if (ui.sanMoves.isEmpty()) return
    Row(
        Modifier
            .fillMaxWidth()
            .clip(com.chesslab.ui.CardShape)
            .background(Palette.surface)
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        ui.sanMoves.forEachIndexed { index, lan ->
            if (index % 2 == 0) {
                Text(
                    "${index / 2 + 1}.",
                    fontSize = 11.sp, color = Palette.textTertiary,
                    modifier = Modifier.padding(start = if (index == 0) 0.dp else 8.dp, end = 3.dp),
                )
            }
            val quality = ui.qualities[index]
            val current = ui.displayedPly == index + 1
            Text(
                lan,
                fontSize = 12.sp, fontFamily = FontFamily.Monospace,
                fontWeight = if (current) FontWeight.Bold else FontWeight.Normal,
                color = quality?.tint ?: if (current) Palette.accent else Palette.textPrimary,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(if (current) Palette.surfaceElevated else Color.Transparent)
                    .clickable { onPick(index + 1) }
                    .padding(horizontal = 5.dp, vertical = 2.dp)
                    .testTag("coup-$index"),
            )
        }
    }
}

/** Qui mène, et de combien — la même barre que l'analyse ordinaire. */
@Composable
private fun EvalBar(ui: VariantAnalysisUiState) {
    val share = when {
        ui.evalMate != null -> if (ui.evalMate > 0) 1f else 0f
        ui.evalCp != null -> (EvalConversion.fromCentipawns(ui.evalCp) / 100).toFloat()
        else -> 0.5f
    }.coerceIn(0.03f, 0.97f)
    Box(
        Modifier
            .fillMaxWidth()
            .height(8.dp)
            .clip(CircleShape)
            .background(Palette.surfaceElevated)
            .testTag("barre-eval")
    ) {
        Box(Modifier.fillMaxWidth(share).fillMaxHeight().background(Color.White.copy(alpha = 0.92f)))
    }
}
