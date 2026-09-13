package com.chesslab.help

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.foundation.clickable
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.testTag
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Speed
import com.chesslab.ui.CardShape
import com.chesslab.ui.IconBadge
import com.chesslab.ui.cardGradient
import com.chesslab.ui.subtleBorder
import com.chesslab.ui.Palette
import androidx.compose.ui.res.stringResource
import com.chesslab.R

/**
 * L'aide. Pendant réduit de `HelpView.swift`.
 *
 * On y dit ce que l'app FAIT VRAIMENT, y compris quand c'est moins flatteur :
 * ce que le filet corrige, ce que le scanner ne devine pas, ce que les niveaux
 * signifient. Une aide qui ne dit que le bon côté ne sert à personne.
 */
@Composable
fun HelpScreen(onReplayTour: () -> Unit = {}) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        // EN TÊTE, pas au fond : celui qui ouvre l'Aide pour retrouver la
        // visite ne doit pas la chercher sous neuf modules.
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(Palette.surface)
                .clickable(onClick = onReplayTour)
                .padding(14.dp)
                .testTag("revoir-visite"),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconBadge(Icons.Default.AutoAwesome, Palette.accent, 42.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    stringResource(R.string.discovery_replay_title), fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
                )
                Text(stringResource(R.string.discovery_replay_sub), fontSize = 12.sp, color = Palette.textSecondary)
            }
            Icon(Icons.Default.ChevronRight, null, tint = Palette.textTertiary, modifier = Modifier.size(16.dp))
        }
        sections.forEach { (title, body, look) ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(CardShape)
                    .background(cardGradient)
                    .subtleBorder()
                    .padding(14.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                IconBadge(look.first, look.second, 36.dp)
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        stringResource(title), fontSize = 14.sp,
                        fontWeight = FontWeight.Bold, color = Palette.textPrimary,
                    )
                    Text(stringResource(body), fontSize = 12.sp, color = Palette.textSecondary)
                }
            }
        }
        Spacer(Modifier.height(12.dp))
    }
}

/**
 * Les huit sections, par paires (titre, corps). Le texte vit dans les
 * ressources : c'est la seule prose de l'app, et elle existe dans les deux
 * langues.
 */
private val sections = listOf(
    Triple(R.string.help_characters_title, R.string.help_characters_body, Icons.Default.Groups to Palette.accent),
    Triple(R.string.help_level_title, R.string.help_level_body, Icons.Default.Speed to Palette.info),
    Triple(R.string.help_safety_title, R.string.help_safety_body, Icons.Default.Shield to Palette.teal),
    Triple(R.string.help_puzzles_title, R.string.help_puzzles_body, Icons.Default.Extension to Palette.violet),
    Triple(R.string.help_courses_title, R.string.help_courses_body, Icons.Default.MenuBook to Palette.warning),
    Triple(R.string.help_training_title, R.string.help_training_body, Icons.Default.Psychology to Palette.gold),
    Triple(R.string.help_variants_title, R.string.help_variants_body, Icons.Default.Casino to Palette.rose),
    Triple(R.string.help_scanner_title, R.string.help_scanner_body, Icons.Default.PhotoCamera to Palette.accentSecondary),
    Triple(R.string.help_offline_title, R.string.help_offline_body, Icons.Default.CloudOff to Palette.textSecondary),
)
