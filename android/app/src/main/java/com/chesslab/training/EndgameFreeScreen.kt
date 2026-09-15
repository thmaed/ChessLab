package com.chesslab.training

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.chesslab.R
import com.chesslab.play.PromotionDialog
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
import com.chesslab.ui.ControlShape
import com.chesslab.ui.MoveStrip
import com.chesslab.ui.Palette
import com.chesslab.ui.QuickSwitchMenu
import com.chesslab.ui.StatusRow
import com.chesslab.ui.TopBarActions
import com.chesslab.ui.accentGradient

/**
 * L'entraînement LIBRE d'une finale. Pendant d'`EndgameFreeTrainView`.
 *
 * L'écran dit deux choses en permanence : le verdict qu'on doit PRÉSERVER, et
 * ce qui arrive quand on le lâche. C'est toute la pédagogie du mode — on
 * n'apprend pas une suite de coups, on apprend à ne pas perdre ce qu'on a.
 */
@Composable
fun EndgameFreeScreen(
    courseId: String,
    onPlayVsEngine: (String) -> Unit = {},
    onOpenTwoPlayer: (String) -> Unit = {},
    onOpenLab: (String) -> Unit = {},
    model: EndgameFreeViewModel = viewModel(),
) {
    LaunchedEffect(courseId) { model.start(courseId) }
    val ui = model.ui

    TopBarActions {
        QuickSwitchMenu(
            onPlayVsEngine = { onPlayVsEngine(model.ui.position.fen) },
            onOpenTwoPlayer = { onOpenTwoPlayer(model.ui.position.fen) },
            onOpenLab = { onOpenLab(model.ui.position.fen) },
        )
    }

    BoardScaffold(
        header = {
            // Le contrat du mode, en une ligne : le verdict à tenir, et la
            // source de l'arbitrage — VÉRIFIÉ par le moteur, pas prouvé par
            // une table. La nuance est l'honnêteté maison, elle reste visible.
            Row(
                Modifier.fillMaxWidth().padding(bottom = 2.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.endgame_free_goal),
                    fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
                )
                Spacer(Modifier.width(6.dp))
                ui.baseline?.let { verdict ->
                    Text(
                        stringResource(verdict.labelRes),
                        fontSize = 13.sp, fontWeight = FontWeight.Bold,
                        color = when (verdict) {
                            EndgameVerdict.win -> Palette.accent
                            EndgameVerdict.draw -> Palette.info
                            EndgameVerdict.loss -> Palette.danger
                        },
                        modifier = Modifier.testTag("verdict"),
                    )
                }
            }
            Text(
                stringResource(R.string.endgame_free_note),
                fontSize = 11.sp, color = Palette.textTertiary,
            )
            // Rien pendant que c'est à l'utilisateur : le bandeau dit déjà
            // tout, et l'écran reste calme le temps qu'il cherche.
            when (ui.phase) {
                FreePhase.preparing, FreePhase.arbitrating -> {
                    Spacer(Modifier.height(6.dp))
                    StatusRow(stringResource(R.string.endgame_arbitrating), busy = true)
                }
                FreePhase.opponentMoving -> {
                    Spacer(Modifier.height(6.dp))
                    StatusRow(stringResource(R.string.endgame_defence_thinking), busy = true)
                }
                else -> Unit
            }
            Spacer(Modifier.height(8.dp))
        },
        board = {
            BoardView(
                position = ui.position,
                orientation = ui.orientation,
                selected = ui.selected,
                legalTargets = ui.legalTargets,
                lastMove = ui.lastMove,
                checkedKing = ui.checkedKing,
                arrows = ui.hints,
                draggableColor = ui.position.sideToMove,
                enabled = ui.phase == FreePhase.awaiting,
                onSquareTap = model::onSquareTap,
            )
        },
        panel = {
            Spacer(Modifier.height(10.dp))

            when {
                ui.phase == FreePhase.slipped && ui.slipFrom != null && ui.slipTo != null ->
                    SlipCard(ui, model)

                ui.phase == FreePhase.finished -> FinishedCard(ui, model)

                ui.phase == FreePhase.unavailable -> Column(
                    Modifier.fillMaxWidth().clip(ControlShape)
                        .background(Palette.surfaceElevated)
                        .border(1.dp, Palette.danger.copy(alpha = 0.45f), ControlShape)
                        .padding(14.dp),
                ) {
                    Text(
                        stringResource(R.string.endgame_unavailable),
                        fontSize = 13.sp, color = Palette.textPrimary,
                    )
                }
            }

            if (ui.slipCount > 0 && ui.phase != FreePhase.finished) {
                Spacer(Modifier.height(10.dp))
                Text(
                    stringResource(R.string.endgame_slips, ui.slipCount),
                    fontSize = 11.sp, color = Palette.textTertiary,
                )
            }
            Spacer(Modifier.height(6.dp))
            MoveStrip(ui.sanMoves)
            Spacer(Modifier.height(20.dp))
        },
    )

    if (ui.pendingPromotion != null) {
        PromotionDialog(onPick = model::completePromotion, onCancel = model::cancelPromotion)
    }
}

/**
 * Correction après un coup qui lâche : les deux verdicts en toutes lettres,
 * puis le choix — réessayer soi-même, ou voir le meilleur coup.
 */
@Composable
private fun SlipCard(ui: EndgameFreeUiState, model: EndgameFreeViewModel) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(ControlShape)
            .background(Palette.surfaceElevated)
            .border(1.dp, Palette.warning.copy(alpha = 0.35f), ControlShape)
            .padding(14.dp)
            .testTag("faux-pas"),
    ) {
        Text(
            stringResource(R.string.endgame_slip_title),
            fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.warning,
        )
        Spacer(Modifier.height(4.dp))
        // Le verdict d'avant et d'après, en toutes lettres : c'est
        // l'information, pas le fait d'avoir eu tort.
        Text(
            stringResource(
                R.string.endgame_slip,
                stringResource(ui.slipFrom!!.labelRes),
                stringResource(ui.slipTo!!.labelRes),
            ),
            fontSize = 13.sp, color = Palette.textPrimary,
        )
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            PrimaryPill(stringResource(R.string.endgame_retry), "reessayer", Modifier.weight(1f), model::retry)
            if (ui.bestKnown) {
                SecondaryPill(
                    stringResource(R.string.endgame_play_best), "jouer-meilleur",
                    Modifier.weight(1f),
                ) { model.playBest() }
            }
        }
    }
}

/** Le bilan de fin, honnête : le résultat, et le nombre de coups repris. */
@Composable
private fun FinishedCard(ui: EndgameFreeUiState, model: EndgameFreeViewModel) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(ControlShape)
            .background(Palette.surfaceElevated)
            .border(1.dp, Palette.stroke, ControlShape)
            .padding(14.dp)
            .testTag("bilan"),
    ) {
        Text(
            ui.outcome.orEmpty(),
            fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
            color = if (ui.success) Palette.accent else Palette.textPrimary,
        )
        Spacer(Modifier.height(4.dp))
        // Convertir en trois reprises n'est pas convertir du premier coup :
        // le chiffre le dit sans juger.
        Text(
            if (ui.slipCount > 0) stringResource(R.string.endgame_slips_final, ui.slipCount)
            else stringResource(R.string.endgame_clean),
            fontSize = 12.sp,
            color = if (ui.slipCount > 0) Palette.textSecondary else Palette.accent,
        )
        Spacer(Modifier.height(12.dp))
        PrimaryPill(stringResource(R.string.endgame_replay), "rejouer", Modifier) { model.restart() }
    }
}

@Composable
private fun PrimaryPill(label: String, tag: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier
            .clip(CircleShape)
            .background(accentGradient)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 10.dp)
            .testTag(tag),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.background)
    }
}

@Composable
private fun SecondaryPill(label: String, tag: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier
            .clip(CircleShape)
            .background(Palette.surface)
            .border(1.dp, Palette.stroke, CircleShape)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 10.dp)
            .testTag(tag),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
    }
}
