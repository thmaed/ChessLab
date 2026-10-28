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
import androidx.compose.material.icons.filled.ShowChart
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
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
fun HelpScreen(
    onReplayTour: () -> Unit = {},
    onReplayWhatsNew: () -> Unit = {},
    onOpen: (HelpDestination) -> Unit = {},
) {
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
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(Palette.surface)
                .clickable(onClick = onReplayWhatsNew)
                .padding(14.dp)
                .testTag("revoir-nouveautes"),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconBadge(Icons.Default.Star, Palette.violet, 42.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    stringResource(R.string.discovery_replay_news_title), fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
                )
                Text(stringResource(R.string.discovery_replay_news_sub), fontSize = 12.sp, color = Palette.textSecondary)
            }
            Icon(Icons.Default.ChevronRight, null, tint = Palette.textTertiary, modifier = Modifier.size(16.dp))
        }
        FaqSection(onOpen)
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

/** Les écrans qu'une réponse de la FAQ sait ouvrir. Pendant de `HelpView.Destination`. */
enum class HelpDestination { analysis, positionEditor, puzzles, settings }

/**
 * Une question PRATIQUE et sa réponse. Pendant de `HelpView.Question` (iOS) : nées des
 * retours d'utilisateurs (28/10/2026) — les fonctions existaient, l'Aide les décrivait
 * par module, et personne ne les trouvait par la tâche.
 */
private data class Faq(
    val id: String,
    val question: Int,
    val answer: Int,
    val action: Pair<Int, HelpDestination>? = null,
)

private val faqs = listOf(
    Faq("takeback", R.string.faq_takeback_q, R.string.faq_takeback_a),
    Faq("variation", R.string.faq_variation_q, R.string.faq_variation_a, R.string.faq_open_analysis to HelpDestination.analysis),
    Faq("position", R.string.faq_position_q, R.string.faq_position_a, R.string.faq_open_editor to HelpDestination.positionEditor),
    Faq("missed", R.string.faq_missed_q, R.string.faq_missed_a, R.string.faq_open_puzzles to HelpDestination.puzzles),
    Faq("version", R.string.faq_version_q, R.string.faq_version_a, R.string.faq_open_settings to HelpDestination.settings),
)

/** Questions fréquentes : une ligne par question, la réponse se déplie au toucher. */
@Composable
private fun FaqSection(onOpen: (HelpDestination) -> Unit) {
    var openId by androidx.compose.runtime.saveable.rememberSaveable { androidx.compose.runtime.mutableStateOf<String?>(null) }
    Column(
        Modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(cardGradient)
            .subtleBorder()
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Text(
            stringResource(R.string.faq_title), fontSize = 15.sp,
            fontWeight = FontWeight.Bold, color = Palette.textPrimary,
            modifier = Modifier.padding(bottom = 6.dp),
        )
        faqs.forEachIndexed { index, faq ->
            if (index > 0) androidx.compose.material3.HorizontalDivider(color = Palette.stroke)
            val isOpen = openId == faq.id
            Row(
                Modifier
                    .fillMaxWidth()
                    .clickable { openId = if (isOpen) null else faq.id }
                    .padding(vertical = 10.dp)
                    .testTag("faq-${faq.id}"),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(faq.question), fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                    color = Palette.textPrimary, modifier = Modifier.weight(1f),
                )
                Icon(
                    if (isOpen) Icons.Default.ExpandLess else Icons.Default.ExpandMore, null,
                    tint = Palette.textTertiary, modifier = Modifier.size(18.dp),
                )
            }
            if (isOpen) {
                Text(stringResource(faq.answer), fontSize = 13.sp, color = Palette.textSecondary)
                faq.action?.let { (label, destination) ->
                    Text(
                        stringResource(label) + " →", fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                        color = Palette.accent,
                        modifier = Modifier
                            .padding(top = 8.dp, bottom = 10.dp)
                            .clickable { onOpen(destination) }
                            .testTag("faq-${faq.id}-ouvrir"),
                    )
                } ?: Spacer(Modifier.height(10.dp))
            }
        }
    }
}

/**
 * Les huit sections, par paires (titre, corps). Le texte vit dans les
 * ressources : c'est la seule prose de l'app, et elle existe dans les deux
 * langues.
 */
private val sections = listOf(
    Triple(R.string.help_news_title, R.string.help_news_body, Icons.Default.AutoAwesome to Palette.accent),
    Triple(R.string.help_daily_title, R.string.help_daily_body, Icons.Default.LocalFireDepartment to Palette.warning),
    Triple(R.string.help_characters_title, R.string.help_characters_body, Icons.Default.Groups to Palette.accent),
    Triple(R.string.help_level_title, R.string.help_level_body, Icons.Default.Speed to Palette.info),
    Triple(R.string.help_safety_title, R.string.help_safety_body, Icons.Default.Shield to Palette.teal),
    Triple(R.string.help_puzzles_title, R.string.help_puzzles_body, Icons.Default.Extension to Palette.violet),
    Triple(R.string.help_rating_title, R.string.help_rating_body, Icons.Default.TrendingUp to Palette.violet),
    Triple(R.string.help_analysis_title, R.string.help_analysis_body, Icons.Default.ShowChart to Palette.teal),
    Triple(R.string.help_courses_title, R.string.help_courses_body, Icons.Default.MenuBook to Palette.warning),
    Triple(R.string.help_training_title, R.string.help_training_body, Icons.Default.Psychology to Palette.gold),
    Triple(R.string.help_variants_title, R.string.help_variants_body, Icons.Default.Casino to Palette.rose),
    Triple(R.string.help_scanner_title, R.string.help_scanner_body, Icons.Default.PhotoCamera to Palette.accentSecondary),
    Triple(R.string.help_offline_title, R.string.help_offline_body, Icons.Default.CloudOff to Palette.textSecondary),
)
