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
import com.chesslab.ui.BoardView
import com.chesslab.ui.Palette

/**
 * L'entraînement : un échiquier continu, l'utilisateur joue SON camp, le
 * partenaire répond sur la ligne principale.
 *
 * Pendant réduit d'`OpeningTrainView`. La répétition espacée n'apparaît nulle
 * part : elle note en coulisse. Ce que l'écran montre, c'est ce qu'il reste à
 * réviser et si le coup était juste — le reste est de la plomberie.
 */
@Composable
fun TrainScreen(mode: TrainMode, model: TrainViewModel = viewModel()) {
    val ui = model.ui
    LaunchedEffect(mode) { model.start(mode) }

    if (ui.loading) {
        Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator(color = Palette.accent) }
        return
    }

    if (ui.phase == TrainPhase.empty) {
        Box(Modifier.fillMaxSize().padding(32.dp), Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    when (mode) {
                        TrainMode.Hardest -> "Aucune position ratée"
                        else -> "Rien à réviser aujourd'hui"
                    },
                    color = Palette.textPrimary, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.testTag("rien-a-reviser"),
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    when (mode) {
                        TrainMode.Hardest -> "Les positions difficiles apparaissent ici dès qu'un coup est manqué."
                        else -> "Revenez demain, ou ouvrez un cours pour travailler une ligne."
                    },
                    fontSize = 13.sp, color = Palette.textSecondary,
                )
            }
        }
        return
    }

    Column(Modifier.fillMaxSize().padding(horizontal = 16.dp).verticalScroll(rememberScrollState())) {
        Header(ui)
        Spacer(Modifier.height(10.dp))

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

        Spacer(Modifier.height(12.dp))
        when (ui.phase) {
            TrainPhase.wrong -> Panel(Palette.danger) {
                Text("Ce n'était pas le coup du répertoire.", color = Palette.textPrimary, fontSize = 13.sp)
                Text(
                    "La suite est ${ui.wrongCorrect ?: "—"}.",
                    color = Palette.danger, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.testTag("bon-coup"),
                )
                ui.comment?.let { Spacer(Modifier.height(4.dp)); Comment(it) }
                Spacer(Modifier.height(8.dp))
                Button(onClick = model::continueAfterWrong, modifier = Modifier.testTag("continuer")) {
                    Text("Jouer ${ui.wrongCorrect ?: ""} et continuer")
                }
            }

            TrainPhase.variation -> Panel(Palette.info) {
                Text(
                    "${ui.variationPlayed} est au répertoire, mais la ligne principale est ${ui.variationMain}.",
                    color = Palette.textPrimary, fontSize = 13.sp,
                    modifier = Modifier.testTag("variante"),
                )
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = model::playVariation, modifier = Modifier.testTag("jouer-variante")) {
                        Text("Jouer ${ui.variationPlayed}")
                    }
                    OutlinedButton(onClick = model::keepMainLine, modifier = Modifier.testTag("rester-principale")) {
                        Text("Rester sur ${ui.variationMain}")
                    }
                }
            }

            TrainPhase.complete -> Panel(Palette.accent) {
                Text("Séance terminée", color = Palette.accent, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.testTag("seance-terminee"))
                Text(
                    "${ui.correct} coup${if (ui.correct > 1) "s" else ""} juste${if (ui.correct > 1) "s" else ""} " +
                        "sur ${ui.reviewed} révisé${if (ui.reviewed > 1) "s" else ""}.",
                    fontSize = 13.sp, color = Palette.textSecondary,
                )
                Spacer(Modifier.height(8.dp))
                Button(onClick = model::restart, modifier = Modifier.testTag("recommencer")) { Text("Recommencer") }
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
                        if (ui.phase == TrainPhase.awaiting) "À vous de jouer" else "Le partenaire réfléchit…",
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
                        Text("Indice", color = Palette.textSecondary)
                    }
                }
            }
        }

        if (ui.playedSans.isNotEmpty()) {
            Spacer(Modifier.height(10.dp))
            Text(
                ui.playedSans.chunked(2).mapIndexed { i, pair -> "${i + 1}. ${pair.joinToString(" ")}" }
                    .joinToString("  "),
                fontSize = 12.sp, color = Palette.textSecondary,
                modifier = Modifier.testTag("coups-joues"),
            )
        }
        Spacer(Modifier.height(24.dp))
    }

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
            if (ui.remaining > 0) "${ui.remaining} à revoir" else "${ui.reviewed} révisé${if (ui.reviewed > 1) "s" else ""}",
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
