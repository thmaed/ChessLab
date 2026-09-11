package com.chesslab

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import chesskit.Piece
import com.chesslab.play.PlayViewModel
import com.chesslab.ui.BoardView
import com.chesslab.ui.Palette

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(colorScheme = darkColorScheme(background = Palette.background, surface = Palette.surface)) {
                Surface(Modifier.fillMaxSize(), color = Palette.background) {
                    PlayScreen()
                }
            }
        }
    }
}

@Composable
private fun PlayScreen(model: PlayViewModel = viewModel()) {
    val ui = model.ui

    Column(
        Modifier
            .fillMaxSize()
            .safeDrawingPadding()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.Top,
    ) {
        Text(
            "Jouer contre le moteur",
            style = MaterialTheme.typography.titleMedium,
            color = Palette.textPrimary,
        )
        Spacer(Modifier.height(2.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (ui.thinking) {
                CircularProgressIndicator(Modifier.size(12.dp), strokeWidth = 2.dp, color = Palette.accent)
                Spacer(Modifier.width(8.dp))
            }
            Text(ui.status, style = MaterialTheme.typography.bodySmall, color = Palette.textSecondary)
        }

        Spacer(Modifier.height(12.dp))

        BoardView(
            position = ui.position,
            selected = ui.selected,
            legalTargets = ui.legalTargets,
            lastMove = ui.lastMove,
            checkedKing = ui.checkedKing,
            enabled = !ui.thinking && !ui.gameOver,
            onSquareTap = model::onSquareTap,
        )

        Spacer(Modifier.height(12.dp))
        MoveStrip(ui.sanMoves)

        Spacer(Modifier.height(12.dp))
        TextButton(onClick = model::newGame) {
            Text("Nouvelle partie", color = Palette.accent)
        }
    }

    if (ui.pendingPromotion != null) {
        PromotionDialog(onPick = model::completePromotion)
    }
}

@Composable
private fun MoveStrip(moves: List<String>) {
    val scroll = rememberScrollState()
    LaunchedEffect(moves.size) { scroll.animateScrollTo(scroll.maxValue) }

    Row(
        Modifier
            .fillMaxWidth()
            .background(Palette.surface)
            .horizontalScroll(scroll)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (moves.isEmpty()) {
            Text("Aucun coup joué", fontSize = 12.sp, color = Palette.textTertiary)
        }
        moves.forEachIndexed { index, san ->
            if (index % 2 == 0) {
                Text(
                    "${index / 2 + 1}.",
                    fontSize = 12.sp,
                    color = Palette.textTertiary,
                    modifier = Modifier.padding(start = if (index == 0) 0.dp else 8.dp, end = 3.dp),
                )
            }
            Text(
                san,
                fontSize = 12.sp,
                fontFamily = FontFamily.Monospace,
                color = Palette.textPrimary,
                modifier = Modifier.padding(end = 4.dp),
            )
        }
    }
}

@Composable
private fun PromotionDialog(onPick: (Piece.Kind) -> Unit) {
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
