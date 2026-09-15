package com.chesslab.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Abc
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.ui.CardShape
import com.chesslab.ui.Palette
import com.chesslab.ui.subtleBorder

/**
 * Ce à quoi les ouvertures doivent leurs données. Pendant de `SourcesView`.
 *
 * Elles sont PRÉ-GÉNÉRÉES hors de l'app, puis embarquées : aucune requête
 * réseau à l'usage — l'app ne déclare d'ailleurs pas la permission. Le dire
 * n'est pas qu'une politesse envers les sources : c'est aussi ce qui explique
 * pourquoi tout marche en avion.
 */
@Composable
fun SourcesScreen() {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            stringResource(R.string.sources_intro),
            fontSize = 13.sp, color = Palette.textSecondary,
            modifier = Modifier.testTag("sources-intro"),
        )
        SourceCard(Icons.Default.Abc, Palette.info, R.string.sources_eco_title, R.string.sources_eco_body)
        SourceCard(Icons.Default.BarChart, Palette.accent, R.string.sources_moves_title, R.string.sources_moves_body)
        SourceCard(Icons.Default.Memory, Palette.violet, R.string.sources_eval_title, R.string.sources_eval_body)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Default.WifiOff, null, tint = Palette.textTertiary, modifier = Modifier.size(18.dp))
            Text(
                stringResource(R.string.sources_offline),
                fontSize = 11.sp, color = Palette.textTertiary,
            )
        }
        Spacer(Modifier.height(12.dp))
    }
}

@Composable
private fun SourceCard(icon: ImageVector, tint: Color, title: Int, body: Int) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(Palette.surface)
            .subtleBorder(CardShape)
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(24.dp).align(Alignment.Top))
        Column {
            Text(
                stringResource(title),
                fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
            )
            Spacer(Modifier.height(4.dp))
            Text(stringResource(body), fontSize = 11.sp, color = Palette.textTertiary)
        }
    }
}
