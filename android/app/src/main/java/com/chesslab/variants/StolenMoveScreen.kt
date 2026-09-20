package com.chesslab.variants

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.foundation.border
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import chesskit.Piece
import com.chesslab.R
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
import com.chesslab.ui.ControlButton
import com.chesslab.ui.EvalBar
import com.chesslab.ui.Palette
import com.chesslab.ui.QuickSwitchMenu
import com.chesslab.ui.StatusRow
import com.chesslab.ui.TopBarActions
import com.chesslab.ui.accentGradient

/**
 * Le Coup Volé : un jeton tous les N coups, et deux coups d'affilée quand on
 * le dépense. Pendant réduit de `StolenMovePlayView.swift`.
 *
 * Le jeton se DÉPENSE avant de jouer, pas après : c'est une annonce, et
 * l'écran la reprend dans son statut pour qu'on sache où l'on en est dans un
 * tour qui, ce coup-là, n'a pas la forme habituelle.
 */
@Composable
fun StolenMoveScreen(
    settings: VariantSettings = VariantSettings(),
    onAnalyze: (String) -> Unit = {},
    /** Revoir la partie : les POSITIONS, pas les coups — un tour double n'est pas rejouable. */
    onReviewGame: (List<String>, List<String>, List<String>) -> Unit = { _, _, _ -> },
    model: StolenMoveViewModel = viewModel(),
) {
    LaunchedEffect(settings) { model.apply(settings) }
    val ui = model.ui
    var confirmResign by remember { mutableStateOf(false) }

    DisposableEffect(Unit) {
        model.resumeFromBackground()
        onDispose { model.pauseForBackground() }
    }

    TopBarActions {
        QuickSwitchMenu(onAnalyze = { onAnalyze(ui.position.fen) })
    }

    BoardScaffold(
        header = {
            Text(
                stringResource(R.string.variant_stolen_blurb, ui.tokenInterval),
                fontSize = 11.sp, color = Palette.textTertiary,
            )
            Spacer(Modifier.height(6.dp))
            StatusRow(ui.status, busy = ui.thinking)
            Spacer(Modifier.height(8.dp))
            StolenClockRow(ui, top = true)
        },
        board = {
            BoardView(
                position = ui.position,
                orientation = ui.userColor,
                selected = ui.selected,
                legalTargets = ui.legalTargets,
                lastMove = ui.lastMove,
                checkedKing = ui.checkedKing,
                arrows = ui.hints,
                draggableColor = ui.userColor,
                enabled = !ui.gameOver && !ui.thinking && ui.mover == ui.userColor,
                onSquareTap = model::onSquareTap,
            )
        },
        panel = {
            if (ui.settings.showEvalBar) {
                Spacer(Modifier.height(6.dp))
                EvalBar(cp = ui.evalCp, mate = ui.evalMate)
            }
            Spacer(Modifier.height(6.dp))
            StolenClockRow(ui, top = false)
            Spacer(Modifier.height(4.dp))

            // Le jeton : ce que l'on a, et ce qu'on peut en faire. Rien du tout
            // quand on n'en a pas — une ligne grise qui dit « aucun jeton »
            // occupe autant de place qu'une qui en annonce un.
            if ((ui.tokens[ui.userColor] ?: 0) > 0) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier.testTag("jeton"),
                ) {
                    Icon(Icons.Default.Bolt, null, tint = Palette.gold, modifier = Modifier.size(18.dp))
                    Text(
                        stringResource(R.string.stolen_token), fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold, color = Palette.gold,
                    )
                    if (model.canSpendNow) {
                        Text(
                            stringResource(R.string.stolen_spend),
                            fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
                            modifier = Modifier
                                .clip(CircleShape)
                                .background(accentGradient)
                                .clickable(onClick = model::spendToken)
                                .padding(horizontal = 14.dp, vertical = 7.dp)
                                .testTag("depenser"),
                        )
                    }
                }
                Spacer(Modifier.height(10.dp))
            }

            Text(
                pluralStringResource(R.plurals.variant_halfmoves, ui.sanMoves.size, ui.sanMoves.size),
                fontSize = 11.sp, color = Palette.textTertiary,
                modifier = Modifier.testTag("compteur"),
            )

            // Le rythme des jetons se règle AVANT la partie, sur l'écran de
            // réglage ; ici on le rappelle seulement. Le changer en cours
            // fausserait le compte, à cheval sur deux intervalles.
            Spacer(Modifier.height(10.dp))
            Text(
                stringResource(R.string.stolen_interval, ui.tokenInterval),
                fontSize = 11.sp, color = Palette.textTertiary,
                modifier = Modifier.testTag("intervalle-${ui.tokenInterval}"),
            )

            Spacer(Modifier.height(8.dp))
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                ControlButton(
                    Icons.Default.Lightbulb, stringResource(R.string.train_hint),
                    enabled = ui.settings.hintsEnabled && !ui.gameOver,
                    tint = if (ui.hintWanted) Palette.background else Palette.textPrimary,
                    background = if (ui.hintWanted) Palette.accent else Palette.surfaceElevated,
                    tag = "indice", onClick = model::toggleHint,
                )
                Spacer(Modifier.weight(1f))
                ControlButton(
                    text = "½", label = stringResource(R.string.play_offer_draw),
                    tint = Palette.info, enabled = !ui.gameOver && !ui.thinking,
                    tag = "nulle", onClick = model::offerDraw,
                )
                Spacer(Modifier.width(10.dp))
                ControlButton(
                    Icons.Default.Flag, stringResource(R.string.play_resign),
                    tint = Palette.danger, enabled = !ui.gameOver,
                    tag = "abandonner", onClick = { confirmResign = true },
                )
            }

            Spacer(Modifier.height(8.dp))
            if (ui.gameOver) {
                Row(
                    Modifier.fillMaxWidth().testTag("fin-de-partie"),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    TextButton(onClick = model::newGame, modifier = Modifier.testTag("nouvelle")) {
                        Text(stringResource(R.string.new_game), color = Palette.accent)
                    }
                    Spacer(Modifier.weight(1f))
                    TextButton(
                        onClick = { onReviewGame(model.analysisFens(), model.analysisMoves(), model.analysisSans()) },
                        enabled = model.analysisMoves().isNotEmpty(),
                        modifier = Modifier.testTag("analyser-la-partie"),
                    ) {
                        Text(stringResource(R.string.route_analysis), color = Palette.teal)
                    }
                }
            } else {
                TextButton(onClick = model::newGame, modifier = Modifier.testTag("nouvelle")) {
                    Text(stringResource(R.string.new_game), color = Palette.accent)
                }
            }
        },
    )

    if (confirmResign) {
        AlertDialog(
            onDismissRequest = { confirmResign = false },
            title = { Text(stringResource(R.string.play_resign)) },
            text = { Text(stringResource(R.string.play_resign_confirm)) },
            confirmButton = {
                TextButton(
                    onClick = { confirmResign = false; model.resign() },
                    modifier = Modifier.testTag("abandonner-oui"),
                ) { Text(stringResource(R.string.play_resign), color = Palette.danger) }
            },
            dismissButton = {
                TextButton(onClick = { confirmResign = false }) { Text(stringResource(R.string.cancel)) }
            },
            containerColor = Palette.surface,
        )
    }

    if (ui.drawDeclined) {
        AlertDialog(
            onDismissRequest = model::dismissDrawDeclined,
            title = { Text(stringResource(R.string.play_draw_declined), color = Palette.textPrimary) },
            text = { Text(stringResource(R.string.play_draw_declined_body), color = Palette.textSecondary) },
            confirmButton = {
                TextButton(onClick = model::dismissDrawDeclined) {
                    Text(stringResource(android.R.string.ok), color = Palette.accent)
                }
            },
            containerColor = Palette.surfaceElevated,
        )
    }

    ui.blunderWarning?.let { severity ->
        val message = when (severity) {
            is com.chesslab.play.BlunderSeverity.MissedMate -> stringResource(R.string.blunder_missed_mate)
            is com.chesslab.play.BlunderSeverity.AllowsMate -> stringResource(R.string.blunder_allows_mate)
            is com.chesslab.play.BlunderSeverity.Centipawns ->
                stringResource(R.string.blunder_centipawns, minOf(severity.drop, 1_000) / 100)
        }
        AlertDialog(
            onDismissRequest = model::dismissBlunderWarning,
            title = { Text(stringResource(R.string.blunder_title), color = Palette.textPrimary) },
            text = { Text(message, color = Palette.textSecondary, modifier = Modifier.testTag("alerte-gaffe")) },
            // Pas de « reprendre » : un tour double se défait mal, et le jeton
            // dépensé ne se rend pas.
            confirmButton = {
                TextButton(onClick = model::dismissBlunderWarning) {
                    Text(stringResource(android.R.string.ok), color = Palette.accent)
                }
            },
            containerColor = Palette.surfaceElevated,
        )
    }
}

/** La pendule d'un camp — celle d'en face au-dessus, la nôtre en dessous. */
@Composable
private fun StolenClockRow(ui: StolenMoveUiState, top: Boolean) {
    val white = ui.whiteClockMs ?: return
    val black = ui.blackClockMs ?: return
    val color = if (top) ui.userColor.opposite else ui.userColor
    val ms = if (color == Piece.Color.white) white else black
    val active = ui.mover == color && !ui.gameOver
    Row(
        Modifier
            .fillMaxWidth()
            .clip(androidx.compose.foundation.shape.RoundedCornerShape(10.dp))
            .background(if (active) Palette.surfaceElevated else androidx.compose.ui.graphics.Color.Transparent)
            .padding(horizontal = 12.dp, vertical = 5.dp)
            .testTag(if (top) "pendule-adversaire" else "pendule-moi"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(9.dp)
                .clip(CircleShape)
                .background(
                    if (color == Piece.Color.white) androidx.compose.ui.graphics.Color.White
                    else androidx.compose.ui.graphics.Color.Black
                )
                .border(1.dp, Palette.stroke, CircleShape)
        )
        Spacer(Modifier.weight(1f))
        Text(
            com.chesslab.play.GameClock.format(ms),
            fontSize = 19.sp, fontWeight = FontWeight.SemiBold,
            fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
            color = when {
                ms < 30_000 -> Palette.danger
                active -> Palette.textPrimary
                else -> Palette.textTertiary
            },
        )
    }
}
