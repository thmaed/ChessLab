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
import com.chesslab.ui.Palette

@Composable
fun SettingsScreen() {
    val context = LocalContext.current
    val settings by SettingsStore.state.collectAsState()

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)
    ) {
        Section("Aperçu")
        // un aperçu vaut mieux qu'une vignette : c'est le vrai plateau
        BoardView(position = remembered, enabled = false)

        Spacer(Modifier.height(16.dp))
        Section("Thème du plateau")
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            BoardTheme.all.forEach { theme ->
                ThemeSwatch(theme, theme.id == settings.boardThemeId) {
                    SettingsStore.setBoardTheme(context, theme.id)
                }
            }
        }

        Spacer(Modifier.height(16.dp))
        Section("Jeu de pièces")
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf(
                "classic" to "Classique",
                "chessnut" to "Moderne",
                "merida" to "Contrasté",
            ).forEach { (id, label) ->
                Choice(label, id == settings.pieceSetId, "piece-$id") {
                    SettingsStore.setPieceSet(context, id)
                }
            }
        }

        Spacer(Modifier.height(16.dp))
        Section("Temps de réflexion du moteur")
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf(200 to "Rapide (0,2 s)", 400 to "Normal (0,4 s)", 1000 to "Réfléchi (1 s)", 3000 to "Long (3 s)")
                .forEach { (ms, label) ->
                    Choice(label, ms == settings.engineMoveTimeMs, "temps-$ms") {
                        SettingsStore.setMoveTime(context, ms)
                    }
                }
        }

        Spacer(Modifier.height(16.dp))
        Section("Sons")
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
                Text("Sons du plateau", fontSize = 13.sp, color = Palette.textPrimary)
                Text(
                    "Synthétisés, aucun fichier audio embarqué.",
                    fontSize = 10.sp, color = Palette.textTertiary,
                )
            }
        }

        Spacer(Modifier.height(16.dp))
        Section("Puzzles")
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf(1 to "Un essai", 3 to "Trois essais").forEach { (n, label) ->
                Choice(label, n == settings.puzzleAttempts, "essais-$n") {
                    SettingsStore.setPuzzleAttempts(context, n)
                }
            }
        }
        Text(
            "Un seul essai par défaut : trois invitent à tenter un coup « pour voir », "
                + "l'inverse de ce qu'un puzzle entraîne.",
            fontSize = 11.sp, color = Palette.textTertiary,
            modifier = Modifier.padding(top = 6.dp),
        )

        Spacer(Modifier.height(32.dp))
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
