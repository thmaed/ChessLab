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

@Composable
fun LabScreen(model: LabViewModel = viewModel()) {
    val ui = model.ui

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

            Spacer(Modifier.height(8.dp))
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
            Text(
                "partie ${ui.gameNumber + 1} · " +
                    (if (ui.aPlaysWhite) "A a les blancs" else "A a les noirs"),
                fontSize = 11.sp, color = Palette.textTertiary,
            )
        }
        Text("A / nulles / B", fontSize = 11.sp, color = Palette.textSecondary)
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
            Chip("Stockfish", selected == null, "camp-$tag-stockfish") { onPick(null) }
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
