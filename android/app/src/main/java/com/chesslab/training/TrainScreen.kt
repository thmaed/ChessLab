package com.chesslab.training

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.chesslab.play.PromotionDialog
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
import com.chesslab.ui.FigurineSan
import com.chesslab.ui.Palette
import androidx.compose.ui.res.stringResource
import com.chesslab.R
import androidx.compose.ui.res.pluralStringResource
import com.chesslab.ui.QuickSwitchMenu
import com.chesslab.ui.TopBarActions

/**
 * L'entraînement : un échiquier continu, l'utilisateur joue SON camp, le
 * partenaire répond sur la ligne principale.
 *
 * Pendant réduit d'`OpeningTrainView`. La répétition espacée n'apparaît nulle
 * part : elle note en coulisse. Ce que l'écran montre, c'est ce qu'il reste à
 * réviser et si le coup était juste — le reste est de la plomberie.
 */
@Composable
fun TrainScreen(
    mode: TrainMode,
    onPlayVsEngine: (String) -> Unit = {},
    onOpenTwoPlayer: (String) -> Unit = {},
    onOpenLab: (String) -> Unit = {},
    model: TrainViewModel = viewModel(),
) {
    val ui = model.ui
    LaunchedEffect(mode) { model.start(mode) }

    TopBarActions {
        QuickSwitchMenu(
            onPlayVsEngine = { onPlayVsEngine(model.ui.position.fen) },
            onOpenTwoPlayer = { onOpenTwoPlayer(model.ui.position.fen) },
            onOpenLab = { onOpenLab(model.ui.position.fen) },
        )
    }

    if (ui.loading) {
        Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator(color = Palette.accent) }
        return
    }

    if (ui.phase == TrainPhase.empty) {
        Box(Modifier.fillMaxSize().padding(32.dp), Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    when (mode) {
                        TrainMode.Hardest -> stringResource(R.string.train_no_hard)
                        else -> stringResource(R.string.train_nothing_today)
                    },
                    color = Palette.textPrimary, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.testTag("rien-a-reviser"),
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    when (mode) {
                        TrainMode.Hardest -> stringResource(R.string.train_no_hard_body)
                        else -> stringResource(R.string.train_nothing_today_body)
                    },
                    fontSize = 13.sp, color = Palette.textSecondary,
                )
            }
        }
        return
    }

    BoardScaffold(
        header = {
            Header(ui)
            Spacer(Modifier.height(10.dp))
        },
        board = {
            BoardView(
                position = ui.position,
                orientation = ui.orientation,
                selected = ui.selected,
                legalTargets = ui.legalTargets,
                lastMove = ui.lastMove,
                checkedKing = ui.checkedKing,
                hint = ui.hint,
                enabled = ui.phase == TrainPhase.awaiting,
                onSquareTap = model::tap,
            )
        },
        panel = {
            Spacer(Modifier.height(12.dp))
            when (ui.phase) {
                TrainPhase.wrong -> Panel(Palette.danger) {
                    Text(stringResource(R.string.train_not_repertoire), color = Palette.textPrimary, fontSize = 13.sp)
                    Text(
                        stringResource(R.string.train_continuation_is, ui.wrongCorrect ?: "—"),
                        color = Palette.danger, fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.testTag("bon-coup"),
                    )
                    ui.comment?.let { Spacer(Modifier.height(4.dp)); Comment(it) }
                    Spacer(Modifier.height(8.dp))
                    Button(onClick = model::continueAfterWrong, modifier = Modifier.testTag("continuer")) {
                        Text(stringResource(R.string.train_play_and_continue, ui.wrongCorrect ?: ""))
                    }
                }

                TrainPhase.variation -> Panel(Palette.info) {
                    Text(
                        stringResource(R.string.train_variation, ui.variationPlayed ?: "", ui.variationMain ?: ""),
                        color = Palette.textPrimary, fontSize = 13.sp,
                        modifier = Modifier.testTag("variante"),
                    )
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = model::playVariation, modifier = Modifier.testTag("jouer-variante")) {
                            Text(stringResource(R.string.train_play_variation, ui.variationPlayed ?: ""))
                        }
                        OutlinedButton(onClick = model::keepMainLine, modifier = Modifier.testTag("rester-principale")) {
                            Text(stringResource(R.string.train_keep_main, ui.variationMain ?: ""))
                        }
                    }
                }

                TrainPhase.complete -> Panel(Palette.accent) {
                    Text(stringResource(R.string.train_session_done), color = Palette.accent, fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.testTag("seance-terminee"))
                    Text(
                        stringResource(
                            R.string.train_session_score,
                            pluralStringResource(R.plurals.train_correct, ui.correct, ui.correct),
                            pluralStringResource(R.plurals.train_reviewed, ui.reviewed, ui.reviewed),
                        ),
                        fontSize = 13.sp, color = Palette.textSecondary,
                    )
                    Spacer(Modifier.height(8.dp))
                    Button(onClick = model::restart, modifier = Modifier.testTag("recommencer")) { Text(stringResource(R.string.train_restart)) }
                }

                else -> {
                    ui.note?.let {
                        Text(
                            it, fontSize = 13.sp, color = Palette.info,
                            modifier = Modifier.testTag("note"),
                        )
                        Spacer(Modifier.height(6.dp))
                    }
                    ui.comment?.let { Comment(it); Spacer(Modifier.height(8.dp)) }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            stringResource(if (ui.phase == TrainPhase.awaiting) R.string.your_turn else R.string.partner_thinking),
                            fontSize = 13.sp, color = Palette.textSecondary,
                            modifier = Modifier.testTag("consigne"),
                        )
                        Spacer(Modifier.weight(1f))
                        TextButton(
                            onClick = model::showHint,
                            enabled = ui.phase == TrainPhase.awaiting,
                            modifier = Modifier.testTag("indice"),
                        ) {
                            Icon(Icons.Default.Lightbulb, null, Modifier.size(16.dp), tint = Palette.textSecondary)
                            Spacer(Modifier.width(4.dp))
                            Text(stringResource(R.string.train_hint), color = Palette.textSecondary)
                        }
                    }
                }
            }

            if (ui.playedSans.isNotEmpty()) {
                Spacer(Modifier.height(10.dp))
                Text(
                    ui.playedSans.map(FigurineSan::format).chunked(2)
                    .mapIndexed { i, pair -> "${i + 1}. ${pair.joinToString(" ")}" }
                        .joinToString("  "),
                    fontSize = 12.sp, color = Palette.textSecondary,
                    modifier = Modifier.testTag("coups-joues"),
                )
            }
        },
    )

    if (ui.pendingPromotion != null) PromotionDialog(model::completePromotion)
}

@Composable
private fun Header(ui: TrainUiState) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(Palette.surface)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            ui.courseName, color = Palette.textPrimary, fontSize = 13.sp,
            fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f).testTag("cours-en-cours"),
        )
        Text(
            if (ui.remaining > 0) stringResource(R.string.train_remaining, ui.remaining)
            else pluralStringResource(R.plurals.train_reviewed, ui.reviewed, ui.reviewed),
            fontSize = 12.sp, color = Palette.textSecondary, modifier = Modifier.testTag("restant"),
        )
    }
}

@Composable
private fun Panel(tint: Color, content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp))
            .background(tint.copy(alpha = 0.10f)).padding(12.dp),
        content = content,
    )
}

@Composable
private fun Comment(text: String) {
    Text(text, fontSize = 13.sp, color = Palette.textSecondary, modifier = Modifier.testTag("commentaire"))
}
