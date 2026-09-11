package com.chesslab.play

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import chesskit.Piece
import com.chesslab.maia.OpponentGallery
import com.chesslab.maia.OpponentProfile
import com.chesslab.maia.OpponentTint
import com.chesslab.ui.BoardView
import com.chesslab.ui.MoveStrip
import com.chesslab.ui.Palette
import com.chesslab.ui.StatusRow
import kotlin.math.roundToInt

@Composable
fun PlayScreen(model: PlayViewModel = viewModel()) {
    val ui = model.ui
    val scroll = rememberScrollState()

    Column(Modifier.fillMaxSize().verticalScroll(scroll).padding(horizontal = 16.dp)) {
        OpponentPicker(ui.opponent, ui.maiaAvailable, model::chooseOpponent)
        Spacer(Modifier.height(8.dp))

        ui.opponent?.let { profile ->
            OpponentCard(profile, ui.level, model::setLevel)
            Spacer(Modifier.height(8.dp))
        }

        StatusRow(ui.status, busy = ui.thinking)
        Spacer(Modifier.height(8.dp))

        BoardView(
            position = ui.position,
            selected = ui.selected,
            legalTargets = ui.legalTargets,
            lastMove = ui.lastMove,
            checkedKing = ui.checkedKing,
            enabled = !ui.thinking && !ui.gameOver,
            onSquareTap = model::onSquareTap,
        )

        Spacer(Modifier.height(10.dp))
        MoveStrip(ui.sanMoves)
        TextButton(onClick = model::newGame, modifier = Modifier.testTag("nouvelle")) {
            Text("Nouvelle partie", color = Palette.accent)
        }
        Spacer(Modifier.height(24.dp))
    }

    if (ui.pendingPromotion != null) PromotionDialog(model::completePromotion)
}

@Composable
private fun OpponentPicker(
    selected: OpponentProfile?,
    maiaAvailable: Boolean,
    onPick: (OpponentProfile?) -> Unit,
) {
    Row(
        Modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (maiaAvailable) {
            OpponentGallery.all.forEach { profile ->
                Chip(
                    label = profile.firstName,
                    tint = tintColor(profile.tint),
                    active = profile.id == selected?.id,
                    tag = "adversaire-${profile.id}",
                ) { onPick(profile) }
            }
        }
        Chip("Stockfish", Palette.textSecondary, selected == null, "adversaire-stockfish") { onPick(null) }
    }
}

@Composable
private fun OpponentCard(profile: OpponentProfile, level: Double, onLevel: (Double) -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Palette.surface)
            .padding(12.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(10.dp).clip(CircleShape).background(tintColor(profile.tint))
            )
            Spacer(Modifier.width(8.dp))
            Text(
                profile.displayName,
                fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
            )
            Spacer(Modifier.weight(1f))
            Text(
                "${level.roundToInt()}",
                fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.accent,
                modifier = Modifier.testTag("niveau"),
            )
        }
        Spacer(Modifier.height(4.dp))
        Text(
            profile.tagline,
            fontSize = 11.sp, color = Palette.textSecondary,
            maxLines = 3, overflow = TextOverflow.Ellipsis,
        )
        Spacer(Modifier.height(2.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            profile.tags.forEach { tag ->
                Text(
                    tag, fontSize = 10.sp, color = tintColor(profile.tint),
                    modifier = Modifier
                        .clip(RoundedCornerShape(5.dp))
                        .background(tintColor(profile.tint).copy(alpha = 0.14f))
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                )
            }
        }
        Slider(
            value = level.toFloat(),
            onValueChange = { onLevel(it.toDouble()) },
            valueRange = profile.recommendedLevels.first.toFloat()..profile.recommendedLevels.last.toFloat(),
            colors = SliderDefaults.colors(thumbColor = Palette.accent, activeTrackColor = Palette.accent),
            modifier = Modifier.testTag("curseur-niveau"),
        )
        Text(
            "Niveau sur l'échelle humaine de Maia, proche de celle de Lichess.",
            fontSize = 10.sp, color = Palette.textTertiary,
        )
    }
}

@Composable
private fun Chip(label: String, tint: Color, active: Boolean, tag: String, onClick: () -> Unit) {
    Text(
        label,
        fontSize = 12.sp,
        fontWeight = if (active) FontWeight.SemiBold else FontWeight.Normal,
        color = if (active) Palette.background else tint,
        modifier = Modifier
            .testTag(tag)
            .clip(RoundedCornerShape(14.dp))
            .background(if (active) tint else Palette.surface)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 7.dp),
    )
}

/** Les teintes d'identité des personnages, reprises d'`OpponentTint`. */
private fun tintColor(tint: OpponentTint): Color = when (tint) {
    OpponentTint.maiaBlue -> Color(0.36f, 0.58f, 0.95f)
    OpponentTint.red -> Color(0.92f, 0.38f, 0.38f)
    OpponentTint.deepBlue -> Color(0.29f, 0.42f, 0.78f)
    OpponentTint.green -> Color(0.36f, 0.80f, 0.56f)
    OpponentTint.purple -> Color(0.62f, 0.51f, 0.96f)
    OpponentTint.orange -> Color(0.91f, 0.62f, 0.34f)
    OpponentTint.cyan -> Color(0.24f, 0.72f, 0.72f)
    OpponentTint.slate -> Color(0.55f, 0.60f, 0.68f)
    OpponentTint.yellow -> Color(0.95f, 0.75f, 0.30f)
}

@Composable
fun PromotionDialog(onPick: (Piece.Kind) -> Unit) {
    AlertDialog(
        onDismissRequest = { onPick(Piece.Kind.queen) },
        title = { Text("Promotion") },
        text = { Text("En quelle pièce promouvoir le pion ?") },
        confirmButton = {
            Row {
                listOf(
                    Piece.Kind.queen to "Dame",
                    Piece.Kind.rook to "Tour",
                    Piece.Kind.bishop to "Fou",
                    Piece.Kind.knight to "Cavalier",
                ).forEach { (kind, label) ->
                    TextButton(onClick = { onPick(kind) }) { Text(label) }
                }
            }
        },
        containerColor = Palette.surfaceElevated,
    )
}
