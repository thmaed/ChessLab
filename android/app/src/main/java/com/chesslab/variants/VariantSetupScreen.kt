package com.chesslab.variants

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AllInclusive
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.Contrast
import androidx.compose.material.icons.filled.FlagCircle
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import com.chesslab.R
import com.chesslab.play.EngineStrength
import com.chesslab.play.PlayerColorChoice
import com.chesslab.play.TimeControl
import com.chesslab.ui.ChipButton
import com.chesslab.ui.ControlShape
import com.chesslab.ui.LevelSlider
import com.chesslab.ui.Palette
import com.chesslab.ui.SettingsSection
import com.chesslab.ui.ToggleRow
import com.chesslab.ui.accentGradient
import kotlin.math.roundToInt

/**
 * Les réglages d'une partie de variante. Pendant de `FairyVariantSetupView`
 * et `Chess960SetupView`, réunis.
 *
 * On décidait de tout AVANT de voir un plateau en partie classique, et de
 * rien du tout dans les variantes : on tombait sur un adversaire à pleine
 * puissance, avec les Blancs, sans pendule et sans aide. Le même écran sert
 * les huit variantes ; ce qui ne concerne qu'un jeu — le numéro Chess960, les
 * jetons du Coup Volé, le mode à deux du Duck Chess — n'apparaît que chez lui.
 */
@OptIn(ExperimentalLayoutApi::class, ExperimentalFoundationApi::class)
@Composable
fun VariantSetupScreen(
    variantId: String,
    onStart: (VariantSettings) -> Unit,
) {
    val context = LocalContext.current
    val variant = VariantCatalog.byId(variantId) ?: return
    val saved = remember(variantId) {
        VariantSettingsStore.load(context, variantId) ?: VariantSettings()
    }

    var color by remember { mutableStateOf(saved.colorChoice) }
    var level by remember { mutableStateOf(saved.level) }
    var timeId by remember { mutableStateOf(saved.timeControlId) }
    var customMinutes by remember { mutableStateOf(saved.customMinutes) }
    var customIncrement by remember { mutableStateOf(saved.customIncrementSeconds) }
    var evalBar by remember { mutableStateOf(saved.showEvalBar) }
    var hints by remember { mutableStateOf(saved.hintsEnabled) }
    var blunderAlert by remember { mutableStateOf(saved.blunderAlertEnabled) }
    var tokenInterval by remember { mutableStateOf(saved.tokenInterval) }
    var twoPlayers by remember { mutableStateOf(variant.supportsTwoPlayers && saved.twoPlayers) }
    var number by remember {
        mutableStateOf(saved.chess960Number ?: kotlin.random.Random.nextInt(Chess960Position.range.last + 1))
    }
    var typedNumber by remember { mutableStateOf(number.toString()) }
    var category by remember {
        mutableStateOf(if (timeId == "custom") "custom" else TimeControl.byId(timeId).category)
    }

    // À deux sur le même appareil, le moteur n'est plus un adversaire : sa
    // force, la couleur et les aides n'ont plus d'objet.
    val hidesEngineSettings = twoPlayers

    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(22.dp),
        ) {
            Text(
                stringResource(variant.blurbRes),
                fontSize = 12.sp, color = Palette.textSecondary,
                modifier = Modifier.testTag("regle"),
            )

            if (variant.supportsTwoPlayers) {
                SettingsSection(stringResource(R.string.setup_opponent), Icons.Default.People) {
                    ToggleRow(stringResource(R.string.variant_two_players), twoPlayers, "deux-joueurs") {
                        twoPlayers = it
                    }
                    Text(
                        stringResource(R.string.variant_two_players_note),
                        fontSize = 11.sp, color = Palette.textTertiary,
                    )
                }
            }

            if (!hidesEngineSettings) {
                SettingsSection(stringResource(R.string.setup_colour), Icons.Default.Contrast) {
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        listOf(
                            Triple(PlayerColorChoice.white, R.string.color_white_side, Icons.Default.Person),
                            Triple(PlayerColorChoice.black, R.string.color_black_side, Icons.Default.Person),
                            Triple(PlayerColorChoice.random, R.string.setup_random, Icons.Default.Casino),
                        ).forEach { (value, label, icon) ->
                            ChipButton(
                                stringResource(label), color == value,
                                Modifier.testTag("couleur-${value.name}"), icon = icon,
                            ) { color = value }
                        }
                    }
                }

                SettingsSection(stringResource(R.string.setup_strength), Icons.Default.Speed) {
                    val strength = EngineStrength.of(level)
                    LevelSlider(
                        title = stringResource(R.string.setup_level),
                        valueLabel = if (strength is EngineStrength.Maximum)
                            stringResource(R.string.strength_maximum) else level.roundToInt().toString(),
                        tierLabel = null,
                        value = level,
                        range = EngineStrength.playSliderRange.start.toFloat()..
                            EngineStrength.playSliderRange.endInclusive.toFloat(),
                        lowLabel = stringResource(R.string.setup_level_low),
                        highLabel = stringResource(R.string.setup_level_high),
                        tint = Palette.accent,
                        // Le fait qui rend l'étiquette honnête : le réseau de
                        // Stockfish est entraîné sur la partie ORTHODOXE.
                        note = if (variantId == "stolenmove") null
                        else stringResource(R.string.variant_elo_note),
                        onChange = { level = it },
                    )
                }
            }

            SettingsSection(stringResource(R.string.setup_time), Icons.Default.Timer) {
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    TimeControl.categories.forEach { c ->
                        ChipButton(
                            stringResource(timeCategoryLabel(c)), category == c,
                            Modifier.testTag("cadence-$c"), icon = timeCategoryIcon(c),
                        ) {
                            if (category != c) {
                                category = c
                                timeId = if (c == "custom") "custom"
                                else TimeControl.presets.first { it.category == c }.id
                            }
                        }
                    }
                }
                Spacer(Modifier.height(10.dp))
                when (category) {
                    "none" -> Text(
                        stringResource(R.string.setup_no_clock),
                        fontSize = 12.sp, color = Palette.textSecondary,
                    )
                    "custom" -> {
                        Stepper(stringResource(R.string.setup_custom_minutes), customMinutes, 1..180, 1, "minutes-perso") {
                            customMinutes = it
                        }
                        Spacer(Modifier.height(8.dp))
                        Stepper(stringResource(R.string.setup_custom_increment), customIncrement, 0..60, 1, "increment-perso") {
                            customIncrement = it
                        }
                    }
                    else -> FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        TimeControl.presets.filter { it.category == category }.forEach { tc ->
                            val label = if (tc.id == "none") stringResource(R.string.time_no_limit) else tc.label
                            ChipButton(label, timeId == tc.id, Modifier.testTag("preset-${tc.id}")) { timeId = tc.id }
                        }
                    }
                }
            }

            // Le numéro de Scharnagl — celui de Lichess et des moteurs :
            // pouvoir le saisir, c'est pouvoir rejouer la position d'hier, ou
            // celle dont un ami parle. Et la position SE VOIT avant de
            // commencer : un numéro seul ne dit rien.
            if (variant.chess960) {
                SettingsSection(stringResource(R.string.chess960_position), Icons.Default.Casino) {
                    val shown = number ?: Chess960Position.classic
                    val preview = remember(shown) {
                        Chess960Position.startingFen(shown)?.let { chesskit.FenParser.parse(it) }
                    }
                    preview?.let {
                        com.chesslab.ui.BoardView(position = it, enabled = false)
                        Spacer(Modifier.height(10.dp))
                    }
                    androidx.compose.material3.OutlinedTextField(
                        value = typedNumber,
                        onValueChange = { text ->
                            typedNumber = text.filter { c -> c.isDigit() }.take(3)
                            typedNumber.toIntOrNull()?.let { if (it in Chess960Position.range) number = it }
                        },
                        singleLine = true,
                        keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(
                            keyboardType = androidx.compose.ui.text.input.KeyboardType.Number,
                        ),
                        label = { Text(stringResource(R.string.chess960_number)) },
                        modifier = Modifier.fillMaxWidth().testTag("numero-960"),
                    )
                    // Le curseur pour explorer, le champ pour viser : les deux
                    // gestes n'ont pas le même but, et l'un sans l'autre agace.
                    androidx.compose.material3.Slider(
                        value = shown.toFloat(),
                        onValueChange = {
                            number = it.toInt().coerceIn(Chess960Position.range)
                            typedNumber = number.toString()
                        },
                        valueRange = 0f..959f,
                        colors = com.chesslab.ui.chessLabSliderColors(),
                        modifier = Modifier.testTag("curseur-960"),
                    )
                    Text(
                        stringResource(R.string.chess960_number_hint),
                        fontSize = 11.sp, color = Palette.textTertiary,
                    )
                    Spacer(Modifier.height(8.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        ChipButton(
                            stringResource(R.string.chess960_random), false,
                            Modifier.testTag("hasard-960"),
                        ) {
                            number = kotlin.random.Random.nextInt(Chess960Position.range.last + 1)
                            typedNumber = number.toString()
                        }
                        Spacer(Modifier.width(8.dp))
                        ChipButton(
                            stringResource(R.string.chess960_classic), number == Chess960Position.classic,
                            Modifier.testTag("classique-960"),
                        ) {
                            number = Chess960Position.classic
                            typedNumber = number.toString()
                        }
                    }
                }
            }

            // Le Coup Volé : un jeton tous les N coups, et c'est tout ce qui
            // le distingue des échecs ordinaires.
            if (variantId == "stolenmove") {
                SettingsSection(stringResource(R.string.stolen_tokens), Icons.Default.Tune) {
                    Stepper(stringResource(R.string.stolen_interval_label), tokenInterval, 2..12, 1, "intervalle") {
                        tokenInterval = it
                    }
                    Text(
                        stringResource(R.string.stolen_interval_note),
                        fontSize = 11.sp, color = Palette.textTertiary,
                    )
                }
            }

            if (!hidesEngineSettings) {
                SettingsSection(stringResource(R.string.setup_aids), Icons.Default.Lightbulb) {
                    ToggleRow(stringResource(R.string.setup_eval_bar), evalBar, "aide-eval") { evalBar = it }
                    ToggleRow(stringResource(R.string.setup_hints), hints, "aide-indice") { hints = it }
                    ToggleRow(stringResource(R.string.setup_blunder_alert), blunderAlert, "aide-alerte") {
                        blunderAlert = it
                    }
                }
            }

            Spacer(Modifier.height(4.dp))
        }

        // Le bouton reste EN BAS et toujours visible : c'est la seule action
        // de l'écran, et elle ne doit pas se mériter en défilant.
        Box(
            Modifier
                .fillMaxWidth()
                .background(Palette.background.copy(alpha = 0.94f))
                .padding(horizontal = 20.dp, vertical = 14.dp)
        ) {
            Text(
                stringResource(R.string.setup_start),
                fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(ControlShape)
                    .background(accentGradient)
                    .clickable {
                        val settings = VariantSettings(
                            colorChoice = color,
                            level = level,
                            timeControlId = timeId,
                            customMinutes = customMinutes,
                            customIncrementSeconds = customIncrement,
                            showEvalBar = evalBar,
                            hintsEnabled = hints,
                            blunderAlertEnabled = blunderAlert,
                            tokenInterval = tokenInterval,
                            twoPlayers = twoPlayers,
                            chess960Number = if (variant.chess960) number else null,
                        )
                        VariantSettingsStore.save(context, variantId, settings)
                        onStart(settings)
                    }
                    .padding(vertical = 14.dp)
                    .testTag("commencer"),
            )
        }
    }
}

private fun timeCategoryLabel(category: String): Int = when (category) {
    "bullet" -> R.string.time_bullet
    "blitz" -> R.string.time_blitz
    "rapid" -> R.string.time_rapid
    "classical" -> R.string.time_classical
    "custom" -> R.string.time_custom
    else -> R.string.time_none
}

private fun timeCategoryIcon(category: String) = when (category) {
    "bullet" -> Icons.Default.Speed
    "blitz" -> Icons.Default.Bolt
    "rapid" -> Icons.Default.Timer
    "classical" -> Icons.Default.FlagCircle
    "custom" -> Icons.Default.Tune
    else -> Icons.Default.AllInclusive
}

/** Un nombre qu'on règle à la main, entre deux bornes. */
@Composable
private fun Stepper(title: String, value: Int, range: IntRange, step: Int, tag: String, onChange: (Int) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(title, fontSize = 13.sp, color = Palette.textPrimary, modifier = Modifier.weight(1f))
        listOf("−" to -step, "+" to step).forEach { (glyph, delta) ->
            Text(
                glyph, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Palette.accent,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(Palette.surfaceElevated)
                    .clickable { onChange((value + delta).coerceIn(range)) }
                    .padding(horizontal = 14.dp, vertical = 4.dp)
                    .testTag("$tag-${if (delta < 0) "moins" else "plus"}"),
            )
            if (delta < 0) {
                Text(
                    "$value", fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                    color = Palette.textPrimary,
                    modifier = Modifier.padding(horizontal = 12.dp).testTag(tag),
                )
            }
        }
    }
}
