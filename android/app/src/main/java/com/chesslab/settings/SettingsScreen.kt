package com.chesslab.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chesskit.Position
import com.chesslab.ui.BoardTheme
import com.chesslab.ui.BoardView
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Category
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Abc
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Vibration
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VolumeUp
import com.chesslab.ui.IconBadge
import com.chesslab.ui.SettingsSection
import com.chesslab.ui.Palette
import androidx.compose.ui.res.stringResource
import com.chesslab.R
import androidx.compose.runtime.*

@Composable
fun SettingsScreen(onOpenLicences: () -> Unit = {}) {
    val context = LocalContext.current
    val settings by SettingsStore.state.collectAsState()

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        // Un aperçu vaut mieux qu'une vignette : c'est le vrai plateau, avec
        // le thème et les pièces choisis juste en dessous.
        SettingsSection(stringResource(R.string.settings_preview), Icons.Default.Visibility) {
            BoardView(position = remembered, enabled = false)
        }

        SettingsSection(stringResource(R.string.settings_board_theme), Icons.Default.Palette) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                BoardTheme.all.forEach { theme ->
                    ThemeSwatch(theme, theme.id == settings.boardThemeId) {
                        SettingsStore.setBoardTheme(context, theme.id)
                    }
                }
            }
        }

        SettingsSection(stringResource(R.string.settings_piece_set), Icons.Default.Category) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf(
                "classic" to R.string.pieces_classic,
                "chessnut" to R.string.pieces_modern,
                "merida" to R.string.pieces_bold,
            ).forEach { (id, label) ->
                Choice(stringResource(label), id == settings.pieceSetId, "piece-$id") {
                    SettingsStore.setPieceSet(context, id)
                }
            }
        }

        }

        SettingsSection(stringResource(R.string.settings_engine_time), Icons.Default.Speed) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf(200 to R.string.speed_fast, 400 to R.string.speed_normal, 1000 to R.string.speed_thoughtful, 3000 to R.string.speed_long)
                .forEach { (ms, label) ->
                    Choice(stringResource(label), ms == settings.engineMoveTimeMs, "temps-$ms") {
                        SettingsStore.setMoveTime(context, ms)
                    }
                }
        }

        }

        SettingsSection(stringResource(R.string.settings_sounds), Icons.Default.VolumeUp) {
        Row(
            Modifier
                .fillMaxWidth()
                .testTag("sons")
                .clip(RoundedCornerShape(8.dp))
                .background(Palette.surface)
                .clickable { SettingsStore.setSounds(context, !settings.soundsEnabled) }
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Switch(
                checked = settings.soundsEnabled,
                onCheckedChange = { SettingsStore.setSounds(context, it) },
            )
            Spacer(Modifier.width(10.dp))
            Column {
                Text(stringResource(R.string.settings_board_sounds), fontSize = 13.sp, color = Palette.textPrimary)
                Text(
                    stringResource(R.string.settings_sounds_note),
                    fontSize = 10.sp, color = Palette.textTertiary,
                )
            }
        }

        }

        SettingsSection(stringResource(R.string.settings_haptics), Icons.Default.Vibration) {
        Row(
            Modifier
                .fillMaxWidth()
                .testTag("haptique")
                .clip(RoundedCornerShape(8.dp))
                .background(Palette.surface)
                .clickable { SettingsStore.setHaptics(context, !settings.hapticsEnabled) }
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Switch(
                checked = settings.hapticsEnabled,
                onCheckedChange = { SettingsStore.setHaptics(context, it) },
            )
            Spacer(Modifier.width(10.dp))
            Column {
                Text(stringResource(R.string.settings_board_haptics), fontSize = 13.sp, color = Palette.textPrimary)
                Text(
                    stringResource(R.string.settings_haptics_note),
                    fontSize = 10.sp, color = Palette.textTertiary,
                )
            }
        }

        }

        SettingsSection(stringResource(R.string.settings_notation), Icons.Default.Abc) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            // Le libellé porte son propre EXEMPLE : « Cf3 » explique mieux que
            // n'importe quelle phrase ce que le réglage change.
            listOf(
                com.chesslab.settings.PieceNotation.french to "Cf3, Dxd5, O-O",
                com.chesslab.settings.PieceNotation.english to "Nf3, Qxd5, O-O",
            ).forEach { (notation, exemple) ->
                val active = settings.pieceNotation == notation
                Column(
                    Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(10.dp))
                        .background(if (active) Palette.accent.copy(alpha = 0.18f) else Palette.surface)
                        .clickable { SettingsStore.setPieceNotation(context, notation) }
                        .padding(horizontal = 12.dp, vertical = 10.dp)
                        .testTag("notation-${notation.name}"),
                ) {
                    Text(
                        stringResource(
                            if (notation == com.chesslab.settings.PieceNotation.french)
                                R.string.settings_notation_french else R.string.settings_notation_english
                        ),
                        fontSize = 13.sp,
                        color = if (active) Palette.accent else Palette.textPrimary,
                    )
                    Text(exemple, fontSize = 11.sp, color = Palette.textTertiary)
                }
            }
        }

        }

        SettingsSection(stringResource(R.string.settings_language), Icons.Default.Language) {
        val activity = LocalContext.current as? android.app.Activity
        var language by remember { mutableStateOf(AppLanguage.current(context)) }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf(
                AppLanguage.system to R.string.settings_language_system,
                AppLanguage.french to R.string.settings_language_fr,
                AppLanguage.english to R.string.settings_language_en,
            ).forEach { (value, label) ->
                Choice(stringResource(label), value == language, "langue-${value.name}") {
                    language = value
                    AppLanguage.apply(context, value) { activity?.recreate() }
                }
            }
        }

        }

        SettingsSection(stringResource(R.string.progress_puzzles), Icons.Default.Extension) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf(1 to R.string.settings_one_try, 3 to R.string.settings_three_tries).forEach { (n, label) ->
                Choice(stringResource(label), n == settings.puzzleAttempts, "essais-$n") {
                    SettingsStore.setPuzzleAttempts(context, n)
                }
            }
        }
        Text(
            stringResource(R.string.settings_tries_note),
            fontSize = 11.sp, color = Palette.textTertiary,
            modifier = Modifier.padding(top = 6.dp),
        )
        }

        com.chesslab.transfer.TransferSection()

        // Ce que l'app doit à d'autres : Stockfish est sous GPLv3, et cela
        // s'affiche sur un écran à part, comme sur iOS — pas en note de bas
        // de page.
        SettingsSection(stringResource(R.string.settings_about), Icons.Default.Info) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .clickable(onClick = onOpenLicences)
                    .padding(vertical = 4.dp)
                    .testTag("licences"),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                IconBadge(Icons.Default.Description, Palette.textSecondary, 34.dp)
                Column(Modifier.weight(1f)) {
                    Text(
                        stringResource(R.string.licences_title),
                        fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Palette.textPrimary,
                    )
                    Text(
                        stringResource(R.string.settings_licences_subtitle),
                        fontSize = 11.sp, color = Palette.textTertiary,
                    )
                }
                Icon(Icons.Default.ChevronRight, contentDescription = null, tint = Palette.textTertiary)
            }
        }

        Spacer(Modifier.height(12.dp))
    }
}

private val remembered: Position get() = Position.standard

@Composable
private fun Section(title: String) {
    Text(
        title,
        fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.textTertiary,
        modifier = Modifier.padding(bottom = 6.dp),
    )
}

@Composable
private fun ThemeSwatch(theme: BoardTheme, selected: Boolean, onPick: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.testTag("theme-${theme.id}").clickable(onClick = onPick),
    ) {
        Row(
            Modifier
                .size(56.dp, 36.dp)
                .clip(RoundedCornerShape(8.dp))
        ) {
            Box(Modifier.weight(1f).fillMaxHeight().background(theme.lightSquare))
            Box(Modifier.weight(1f).fillMaxHeight().background(theme.darkSquare))
        }
        Spacer(Modifier.height(3.dp))
        Text(
            theme.label, fontSize = 10.sp,
            color = if (selected) Palette.accent else Palette.textSecondary,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
        )
    }
}

@Composable
private fun Choice(label: String, selected: Boolean, tag: String, onPick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .testTag(tag)
            .clip(RoundedCornerShape(8.dp))
            .background(if (selected) Palette.accent.copy(alpha = 0.12f) else Palette.surface)
            .clickable(onClick = onPick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RadioButton(selected = selected, onClick = onPick, colors = RadioButtonDefaults.colors(selectedColor = Palette.accent))
        Spacer(Modifier.width(6.dp))
        Text(label, fontSize = 13.sp, color = if (selected) Palette.accent else Palette.textPrimary)
    }
}

private val unusedColor: Color = Color.Transparent
