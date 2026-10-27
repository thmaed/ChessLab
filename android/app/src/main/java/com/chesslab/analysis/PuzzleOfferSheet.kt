package com.chesslab.analysis

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.ui.MiniBoard
import com.chesslab.ui.Palette
import com.chesslab.ui.accentGradient

/**
 * Le récapitulatif de fin d'analyse : ce que l'app PEUT créer comme puzzles depuis cette partie — les
 * mats manqués et les erreurs —, que l'utilisateur accepte ou refuse. Rien n'est écrit avant son accord.
 * Pendant de `PuzzleOfferSheet` (iOS).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PuzzleOfferSheet(offer: PuzzleOffer, onAccept: () -> Unit, onDecline: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDecline, containerColor = Palette.surface) {
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 8.dp).testTag("offre-puzzles"),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Extension, null, tint = Palette.violet, modifier = Modifier.size(26.dp))
                Spacer(Modifier.width(10.dp))
                Column {
                    Text(stringResource(R.string.offer_title), fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary)
                    Text(stringResource(R.string.offer_subtitle), fontSize = 12.sp, color = Palette.textSecondary)
                }
            }
            if (offer.mates.isNotEmpty()) {
                Section(
                    pluralStringResource(R.plurals.offer_mates, offer.mates.size, offer.mates.size),
                    offer.mates, Palette.danger,
                )
            }
            if (offer.mistakes.isNotEmpty()) {
                Section(
                    pluralStringResource(R.plurals.offer_mistakes, offer.mistakes.size, offer.mistakes.size),
                    offer.mistakes, Palette.warning,
                )
            }
            Text(
                pluralStringResource(R.plurals.offer_create, offer.candidates.size, offer.candidates.size),
                fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(CircleShape)
                    .background(accentGradient)
                    .clickable(onClick = onAccept)
                    .padding(vertical = 14.dp)
                    .testTag("offre-puzzles-creer"),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )
            Text(
                stringResource(R.string.offer_decline), fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary,
                modifier = Modifier.fillMaxWidth().clickable(onClick = onDecline).padding(vertical = 6.dp).testTag("offre-puzzles-non"),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )
            Spacer(Modifier.height(16.dp))
        }
    }
}

@Composable
private fun Section(title: String, items: List<PuzzleCandidate>, tint: androidx.compose.ui.graphics.Color) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title.uppercase(), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.4.sp, color = tint)
        items.forEach { c ->
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(tint.copy(alpha = 0.10f)).padding(10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                MiniBoard(c.fen, flipped = c.blackToMove, modifier = Modifier.size(64.dp))
                Spacer(Modifier.width(12.dp))
                Text(
                    stringResource(if (c.isMate) R.string.offer_row_mate else R.string.offer_row_mistake, c.moveNumber, c.playedSan),
                    fontSize = 13.sp, color = Palette.textPrimary,
                )
            }
        }
    }
}
