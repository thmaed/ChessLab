package com.chesslab.variants

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.chesslab.ui.BoardView
import com.chesslab.ui.Palette
import com.chesslab.ui.StatusRow

@Composable
fun VariantListScreen(onOpen: (String) -> Unit) {
    LazyColumn(
        Modifier.fillMaxSize().padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(VariantCatalog.all) { variant ->
            Column(
                Modifier
                    .fillMaxWidth()
                    .testTag("variante-${variant.id}")
                    .clip(RoundedCornerShape(12.dp))
                    .background(Palette.surface)
                    .clickable { onOpen(variant.id) }
                    .padding(12.dp)
            ) {
                Text(variant.title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
                Spacer(Modifier.height(4.dp))
                Text(variant.blurb, fontSize = 12.sp, color = Palette.textSecondary)
            }
        }
    }
}

@Composable
fun VariantPlayScreen(variantId: String, model: VariantPlayViewModel = viewModel()) {
    LaunchedEffect(variantId) { model.load(variantId) }
    val ui = model.ui

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)
    ) {
        ui.variant?.let {
            Text(it.blurb, fontSize = 11.sp, color = Palette.textTertiary)
            Spacer(Modifier.height(6.dp))
        }
        StatusRow(ui.status, busy = ui.thinking)
        Spacer(Modifier.height(8.dp))

        BoardView(
            position = ui.position,
            selected = ui.selected,
            legalTargets = ui.legalTargets,
            lastMove = ui.lastMove,
            checkedKing = ui.checkedKing,
            enabled = ui.ready && !ui.thinking && !ui.gameOver,
            onSquareTap = model::onSquareTap,
        )

        Spacer(Modifier.height(10.dp))
        Text(
            "${ui.uciLog.size} demi-coup" + (if (ui.uciLog.size > 1) "s" else ""),
            fontSize = 11.sp, color = Palette.textTertiary,
            modifier = Modifier.testTag("compteur"),
        )
        TextButton(onClick = model::newGame, modifier = Modifier.testTag("nouvelle")) {
            Text("Nouvelle partie", color = Palette.accent)
        }
        Spacer(Modifier.height(24.dp))
    }
}
