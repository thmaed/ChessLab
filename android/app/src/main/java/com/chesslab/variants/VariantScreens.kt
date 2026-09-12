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
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.Looks3
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.SportsScore
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material.icons.filled.Whatshot
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextOverflow
import com.chesslab.ui.CardShape
import com.chesslab.ui.IconBadge
import com.chesslab.ui.cardGradient
import com.chesslab.ui.tintedCardBorder
import androidx.compose.material3.Icon
import androidx.compose.ui.Alignment
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.fillMaxSize
import com.chesslab.ui.Palette
import com.chesslab.ui.StatusRow
import androidx.compose.ui.res.stringResource
import com.chesslab.R
import androidx.compose.ui.res.pluralStringResource

@Composable
fun VariantListScreen(onOpen: (String) -> Unit) {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val columns = ((maxWidth - 40.dp) / 174.dp).toInt().coerceAtLeast(2)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                stringResource(R.string.variants_intro),
                fontSize = 14.sp, color = Palette.textSecondary,
            )
            VariantCatalog.all.chunked(columns).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    row.forEach { variant ->
                        Box(Modifier.weight(1f)) { VariantCard(variant, onOpen) }
                    }
                    repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}

/**
 * Une tuile de variante : le même langage que les tuiles de l'accueil —
 * pastille d'icône, flèche de lancement, icône fantôme, bordure teintée.
 */
@Composable
private fun VariantCard(variant: Variant, onOpen: (String) -> Unit) {
    val tint = variantTint(variant.id)
    val icon = variantIcon(variant.id)
    Box(
        Modifier
            .testTag("variante-${variant.id}")
            .height(132.dp)
            .clip(CardShape)
            .background(cardGradient)
            .tintedCardBorder(tint)
            .clickable { onOpen(variant.id) }
    ) {
        Icon(
            icon, null, tint = tint.copy(alpha = 0.08f),
            modifier = Modifier.align(Alignment.BottomEnd).offset(x = 28.dp, y = 22.dp).size(96.dp),
        )
        Icon(
            Icons.Default.NorthEast, null, tint = tint.copy(alpha = 0.6f),
            modifier = Modifier.align(Alignment.TopEnd).padding(13.dp).size(14.dp),
        )
        Column(Modifier.fillMaxSize().padding(16.dp)) {
            IconBadge(icon, tint)
            Spacer(Modifier.weight(1f))
            Text(
                stringResource(variant.titleRes), fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                color = Palette.textPrimary, maxLines = 2, overflow = TextOverflow.Ellipsis,
            )
            Text(
                stringResource(variant.shortRes), fontSize = 12.sp, color = Palette.textSecondary,
                modifier = Modifier.padding(top = 2.dp), maxLines = 2, overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/** Une couleur par variante, reprise de l'écran iOS. */
private fun variantTint(id: String): Color = when (id) {
    "chess960" -> Palette.violet
    "kingofthehill" -> Palette.gold
    "3check" -> Palette.danger
    "horde" -> Palette.teal
    "racingkings" -> Palette.info
    "atomic" -> Palette.danger
    "crazyhouse" -> Palette.accent
    else -> Palette.rose
}

private fun variantIcon(id: String): ImageVector = when (id) {
    "chess960" -> Icons.Default.Casino
    "kingofthehill" -> Icons.Default.Terrain
    "3check" -> Icons.Default.Looks3
    "horde" -> Icons.Default.Groups
    "racingkings" -> Icons.Default.SportsScore
    "atomic" -> Icons.Default.Whatshot
    "crazyhouse" -> Icons.Default.Inventory2
    else -> Icons.Default.SwapVert
}

@Composable
fun VariantPlayScreen(variantId: String, model: VariantPlayViewModel = viewModel()) {
    LaunchedEffect(variantId) { model.load(variantId) }
    val ui = model.ui

    BoardScaffold(
        header = {
            ui.variant?.let {
                Text(stringResource(it.blurbRes), fontSize = 11.sp, color = Palette.textTertiary)
                Spacer(Modifier.height(6.dp))
            }
            StatusRow(ui.status, busy = ui.thinking)
            Spacer(Modifier.height(8.dp))
        },
        board = {
            BoardView(
                position = ui.position,
                selected = ui.selected,
                legalTargets = ui.legalTargets,
                lastMove = ui.lastMove,
                checkedKing = ui.checkedKing,
                enabled = ui.ready && !ui.thinking && !ui.gameOver,
                onSquareTap = model::onSquareTap,
            )
        },
        panel = {
            Spacer(Modifier.height(10.dp))
            Text(
                pluralStringResource(R.plurals.variant_halfmoves, ui.uciLog.size, ui.uciLog.size),
                fontSize = 11.sp, color = Palette.textTertiary,
                modifier = Modifier.testTag("compteur"),
            )
            TextButton(onClick = model::newGame, modifier = Modifier.testTag("nouvelle")) {
                Text(stringResource(R.string.new_game), color = Palette.accent)
            }
        },
    )
}
