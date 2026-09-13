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
import androidx.compose.material.icons.filled.Fence
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Pets
import androidx.compose.material.icons.filled.Shuffle
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
import com.chesslab.ui.QuickSwitchMenu
import com.chesslab.ui.TopBarActions
import androidx.compose.foundation.border
import chesskit.Piece
import chesskit.Square
import com.chesslab.ui.PieceIcon
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.text.font.FontFamily

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

/**
 * La réserve d'un camp : les pièces prises qui attendent d'être posées.
 *
 * Rien du tout quand elle est vide — une bande vide sous un plateau ne dit
 * rien et vole de la place à l'échiquier, qui en manque toujours. La sienne se
 * touche pour choisir la pièce à poser ; celle d'en face ne se touche pas.
 */
@Composable
private fun Reserve(ui: VariantUiState, color: Piece.Color, model: VariantPlayViewModel) {
    val hand = ui.pocket[color].orEmpty()
    if (hand.isEmpty()) return
    val mine = color == Piece.Color.white
    Row(
        Modifier.fillMaxWidth().padding(vertical = 2.dp).testTag("reserve-${if (mine) "blancs" else "noirs"}"),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CrazyhouseFen.order.forEach { kind ->
            val count = hand[kind] ?: 0
            if (count == 0) return@forEach
            val selected = mine && ui.selectedDrop == kind
            Row(
                Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (selected) Palette.accent.copy(alpha = 0.28f) else Color.Transparent)
                    .border(
                        1.5.dp,
                        if (selected) Palette.accent else Color.Transparent,
                        RoundedCornerShape(8.dp),
                    )
                    .clickable(enabled = mine) { model.selectPocketPiece(kind) }
                    .padding(horizontal = 6.dp, vertical = 3.dp)
                    .testTag("reserve-${CrazyhouseFen.letter(kind)}-${if (mine) "moi" else "lui"}"),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                PieceIcon(Piece(kind, color, Square("a1")), Modifier.size(26.dp))
                if (count > 1) {
                    Text(
                        "$count", fontSize = 11.sp, fontWeight = FontWeight.Bold,
                        color = Palette.textSecondary,
                    )
                }
            }
        }
    }
}

/** Une couleur par variante, reprise de l'écran iOS. */
private fun variantTint(id: String): Color = when (id) {
    "barricades" -> Palette.textSecondary
    "duck" -> Palette.gold
    "stolenmove" -> Palette.warning
    "randombarricades" -> Palette.violet
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
    "barricades" -> Icons.Default.Fence
    "duck" -> Icons.Default.Pets
    "stolenmove" -> Icons.Default.Bolt
    "randombarricades" -> Icons.Default.Shuffle
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
fun VariantPlayScreen(
    variantId: String,
    /** La position Chess960 choisie au réglage ; `null` = tirage au sort. */
    chess960Number: Int? = null,
    twoPlayer: Boolean = false,
    /**
     * Seule l'analyse est proposée : les autres modes jouent aux règles
     * ORTHODOXES, et y envoyer une position de Horde ou de Roi de la colline
     * donnerait une partie qui n'a plus rien à voir. iOS fait le même
     * choix sur son écran Chess960.
     */
    onAnalyze: (String) -> Unit = {},
    model: VariantPlayViewModel = viewModel(),
) {
    LaunchedEffect(variantId, chess960Number, twoPlayer) {
        model.load(variantId, chess960Number, twoPlayer)
    }
    val ui = model.ui

    TopBarActions {
        QuickSwitchMenu(onAnalyze = { onAnalyze(model.ui.position.fen) })
    }

    val settings by com.chesslab.settings.SettingsStore.state.collectAsState()
    val autoFlip = settings.autoFlipTwoPlayer

    BoardScaffold(
        header = {
            ui.variant?.let {
                Text(stringResource(it.blurbRes), fontSize = 11.sp, color = Palette.textTertiary)
                Spacer(Modifier.height(6.dp))
            }
            StatusRow(ui.status, busy = ui.thinking)
            Spacer(Modifier.height(8.dp))
            // La réserve ADVERSE, au-dessus du plateau comme le camp qu'elle
            // sert : un relevé de ce qui peut nous tomber dessus.
            Reserve(ui, Piece.Color.black, model)
            ui.chess960Number?.let {
                Text(
                    stringResource(R.string.chess960_number) + " $it",
                    fontSize = 11.sp, fontFamily = FontFamily.Monospace, color = Palette.textTertiary,
                    modifier = Modifier.testTag("numero-position"),
                )
            }
        },
        board = {
            BoardView(
                position = ui.position,
                // À deux sur un seul appareil, le plateau se retourne pour
                // celui qui doit jouer — le même réglage que le mode Deux
                // joueurs ordinaire le commande.
                orientation = if (ui.twoPlayer && autoFlip) ui.position.sideToMove
                else Piece.Color.white,
                selected = ui.selected,
                legalTargets = ui.legalTargets,
                lastMove = ui.lastMove,
                checkedKing = ui.checkedKing,
                walls = ui.walls,
                enabled = ui.ready && !ui.thinking && !ui.gameOver,
                onSquareTap = model::onSquareTap,
            )
        },
        panel = {
            Spacer(Modifier.height(6.dp))
            // La NÔTRE, sous le plateau, du côté où l'on joue.
            Reserve(ui, Piece.Color.white, model)
            Spacer(Modifier.height(4.dp))
            Text(
                pluralStringResource(R.plurals.variant_halfmoves, ui.plies, ui.plies),
                fontSize = 11.sp, color = Palette.textTertiary,
                modifier = Modifier.testTag("compteur"),
            )
            TextButton(onClick = model::newGame, modifier = Modifier.testTag("nouvelle")) {
                Text(stringResource(R.string.new_game), color = Palette.accent)
            }
        },
    )
}
