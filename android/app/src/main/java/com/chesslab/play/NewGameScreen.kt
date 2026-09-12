package com.chesslab.play

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Contrast
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.maia.OpponentGallery
import com.chesslab.ui.*
import kotlin.math.roundToInt

/**
 * L'écran de configuration d'une partie. Pendant de `NewGameSetupView`.
 *
 * Il existe parce qu'une partie se PRÉPARE : la couleur, l'adversaire, son
 * niveau, la cadence, les aides. Aller droit au plateau avec une rangée de
 * puces au-dessus, comme le faisait ce portage, escamotait tous ces choix.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun NewGameScreen(
    maiaAvailable: Boolean,
    initial: PlayGameSettings,
    onStart: (PlayGameSettings) -> Unit,
) {
    var color by remember { mutableStateOf(initial.colorChoice) }
    var useCharacter by remember { mutableStateOf(maiaAvailable && initial.opponentId != null) }
    var opponentId by remember { mutableStateOf(initial.opponentId ?: "maia") }
    var level by remember { mutableStateOf(initial.level) }
    var timeId by remember { mutableStateOf(initial.timeControlId) }
    var category by remember { mutableStateOf(TimeControl.byId(initial.timeControlId).category) }
    var hints by remember { mutableStateOf(initial.hintsEnabled) }
    var blunderAlert by remember { mutableStateOf(initial.blunderAlertEnabled) }
    var evalBar by remember { mutableStateOf(initial.showEvalBar) }
    var engineResigns by remember { mutableStateOf(initial.engineResigns) }

    val profile = OpponentGallery.byId(opponentId)

    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(22.dp),
        ) {
            SettingsSection(stringResource(R.string.setup_colour), Icons.Default.Contrast) {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(
                        PlayerColorChoice.white to R.string.color_white_one,
                        PlayerColorChoice.black to R.string.color_black_one,
                        PlayerColorChoice.random to R.string.setup_random,
                    ).forEach { (value, label) ->
                        ChipButton(stringResource(label), color == value, Modifier.testTag("couleur-${value.name}")) { color = value }
                    }
                }
            }

            SettingsSection(stringResource(R.string.setup_opponent), Icons.Default.Person) {
                if (maiaAvailable) {
                    Segmented(
                        listOf(stringResource(R.string.setup_character), stringResource(R.string.stockfish)),
                        if (useCharacter) 0 else 1,
                    ) { index ->
                        useCharacter = index == 0
                        if (useCharacter) level = OpponentGallery.byId(opponentId)?.defaultLevel ?: 1500.0
                    }
                    Spacer(Modifier.height(16.dp))
                }
                if (useCharacter && profile != null) {
                    OpponentGalleryGrid(opponentId) { picked ->
                        opponentId = picked.id
                        level = picked.defaultLevel
                    }
                    Spacer(Modifier.height(14.dp))
                    LevelSlider(
                        title = stringResource(R.string.setup_level),
                        value = level,
                        range = profile.recommendedLevels.first.toFloat()..profile.recommendedLevels.last.toFloat(),
                        tint = tintColor(profile.tint),
                        note = stringResource(R.string.setup_level_note),
                    ) { level = it }
                } else {
                    LevelSlider(
                        title = stringResource(R.string.setup_strength),
                        value = level,
                        range = 800f..3000f,
                        tint = Palette.accent,
                        note = stringResource(R.string.setup_strength_note),
                    ) { level = it }
                }
            }

            SettingsSection(stringResource(R.string.setup_time), Icons.Default.Timer) {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    TimeControl.categories.forEach { c ->
                        ChipButton(stringResource(timeCategoryLabel(c)), category == c, Modifier.testTag("cadence-$c")) {
                            category = c
                            timeId = TimeControl.presets.first { it.category == c }.id
                        }
                    }
                }
                if (category == "none") {
                    Spacer(Modifier.height(10.dp))
                    Text(stringResource(R.string.setup_no_clock), fontSize = 12.sp, color = Palette.textSecondary)
                } else {
                    Spacer(Modifier.height(10.dp))
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        TimeControl.presets.filter { it.category == category }.forEach { tc ->
                            ChipButton(tc.label, timeId == tc.id) { timeId = tc.id }
                        }
                    }
                }
            }

            SettingsSection(stringResource(R.string.setup_aids), Icons.Default.Lightbulb) {
                ToggleRow(stringResource(R.string.setup_hints), hints, "aide-indice") { hints = it }
                ToggleRow(stringResource(R.string.setup_blunder_alert), blunderAlert, "aide-alerte") {
                    blunderAlert = it
                }
                ToggleRow(stringResource(R.string.setup_eval_bar), evalBar, "aide-eval") { evalBar = it }
                ToggleRow(stringResource(R.string.setup_engine_resigns), engineResigns, "aide-abandon") { engineResigns = it }
            }

            Spacer(Modifier.height(8.dp))
        }

        // Le bouton reste EN BAS et toujours visible : c'est la seule action
        // de l'écran, et elle ne doit pas se mériter en défilant.
        Box(
            Modifier
                .fillMaxWidth()
                .background(Palette.background.copy(alpha = 0.94f))
                .padding(horizontal = 20.dp, vertical = 14.dp)
        ) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .clip(ControlShape)
                    .background(accentGradient)
                    .clickable {
                        onStart(
                            PlayGameSettings(
                                colorChoice = color,
                                opponentId = if (useCharacter && maiaAvailable) opponentId else null,
                                level = level,
                                timeControlId = timeId,
                                hintsEnabled = hints,
                                blunderAlertEnabled = blunderAlert,
                                showEvalBar = evalBar,
                                engineResigns = engineResigns,
                            )
                        )
                    }
                    .padding(vertical = 14.dp)
                    .testTag("commencer"),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    stringResource(R.string.setup_start), fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold, color = Palette.background,
                )
            }
        }
    }
}

private fun timeCategoryLabel(category: String): Int = when (category) {
    "bullet" -> R.string.time_bullet
    "blitz" -> R.string.time_blitz
    "rapid" -> R.string.time_rapid
    "classical" -> R.string.time_classical
    else -> R.string.time_none
}

/** Le contrôle segmenté à deux choix : Personnage ou Stockfish. */
@Composable
private fun Segmented(labels: List<String>, selected: Int, onSelect: (Int) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Palette.background.copy(alpha = 0.6f))
            .padding(3.dp)
    ) {
        labels.forEachIndexed { index, label ->
            val active = index == selected
            Box(
                Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (active) Palette.surfaceElevated else androidx.compose.ui.graphics.Color.Transparent)
                    .clickable { onSelect(index) }
                    .padding(vertical = 8.dp)
                    .testTag("segment-$index"),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    label, fontSize = 14.sp,
                    fontWeight = if (active) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (active) Palette.textPrimary else Palette.textSecondary,
                )
            }
        }
    }
}

/**
 * Le niveau : le chiffre, le curseur teinté, les deux bornes, et une ligne qui
 * dit de quelle échelle il s'agit.
 */
@Composable
private fun LevelSlider(
    title: String,
    value: Double,
    range: ClosedFloatingPointRange<Float>,
    tint: androidx.compose.ui.graphics.Color,
    note: String,
    onChange: (Double) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary)
            Spacer(Modifier.weight(1f))
            Text(
                "${value.roundToInt()}", fontSize = 20.sp, fontWeight = FontWeight.Bold,
                color = Palette.textPrimary, modifier = Modifier.testTag("niveau"),
            )
        }
        Slider(
            value = value.toFloat().coerceIn(range.start, range.endInclusive),
            onValueChange = { onChange((it / 50).roundToInt() * 50.0) },
            valueRange = range,
            colors = SliderDefaults.colors(thumbColor = tint, activeTrackColor = tint),
            modifier = Modifier.testTag("curseur-niveau"),
        )
        Row {
            Text("${range.start.roundToInt()}", fontSize = 12.sp, color = tint)
            Spacer(Modifier.weight(1f))
            Text("${range.endInclusive.roundToInt()}", fontSize = 12.sp, color = tint)
        }
        Text(note, fontSize = 11.sp, color = Palette.textTertiary)
    }
}

/**
 * L'écran de configuration branché sur le modèle de vue, pour savoir si les
 * personnages sont disponibles — sans Maia, seul Stockfish reste.
 */
@Composable
fun NewGameSetupRoute(
    model: PlayViewModel = androidx.lifecycle.viewmodel.compose.viewModel(),
    onStart: (PlayGameSettings) -> Unit,
) {
    val ui = model.ui
    NewGameScreen(ui.maiaAvailable, ui.settings.copy(level = ui.level), onStart)
}
