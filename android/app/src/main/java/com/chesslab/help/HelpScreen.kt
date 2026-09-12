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
fun HelpScreen() {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)
    ) {
        sections.forEach { (title, body) ->
            Text(
                stringResource(title), fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                color = Palette.textPrimary, modifier = Modifier.padding(top = 14.dp, bottom = 4.dp),
            )
            Text(
                stringResource(body), fontSize = 12.sp, color = Palette.textSecondary,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(Palette.surface)
                    .padding(12.dp),
            )
        }
        Spacer(Modifier.height(24.dp))
    }
}

/**
 * Les huit sections, par paires (titre, corps). Le texte vit dans les
 * ressources : c'est la seule prose de l'app, et elle existe dans les deux
 * langues.
 */
private val sections = listOf(
    R.string.help_characters_title to R.string.help_characters_body,
    R.string.help_level_title to R.string.help_level_body,
    R.string.help_safety_title to R.string.help_safety_body,
    R.string.help_puzzles_title to R.string.help_puzzles_body,
    R.string.help_courses_title to R.string.help_courses_body,
    R.string.help_training_title to R.string.help_training_body,
    R.string.help_variants_title to R.string.help_variants_body,
    R.string.help_scanner_title to R.string.help_scanner_body,
    R.string.help_offline_title to R.string.help_offline_body,
)
