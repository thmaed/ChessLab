package com.chesslab.play

import com.chesslab.discovery.DiscoverySpot
import com.chesslab.discovery.discoveryAnchor

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AllInclusive
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.Contrast
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.FlagCircle
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.editor.FenValidator
import com.chesslab.maia.OpponentGallery
import com.chesslab.ui.*
import kotlin.math.roundToInt

/**
 * L'écran de configuration d'une partie. Pendant de `NewGameSetupView`.
 *
 * Il existe parce qu'une partie se PRÉPARE : la couleur, l'adversaire, son
 * niveau, la cadence, les aides, et jusqu'à la position de départ. Aller droit
 * au plateau escamoterait tous ces choix — y compris quand on arrive avec une
 * position venue d'un autre écran : on repasse ici, l'écran titré « Continuer
 * la partie », plutôt que de repartir en silence aux derniers réglages.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun NewGameScreen(
    maiaAvailable: Boolean,
    initial: PlayGameSettings,
    onOpenEditor: () -> Unit = {},
    onOpenScanner: () -> Unit = {},
    onStart: (PlayGameSettings) -> Unit,
) {
    val context = LocalContext.current

    var color by remember { mutableStateOf(initial.colorChoice) }
    var useCharacter by remember { mutableStateOf(maiaAvailable && initial.opponentId != null) }
    /**
     * MAIA est toujours la sélection de départ en mode Personnage : on ouvre
     * sur l'étalon, pas sur le dernier personnage affronté. Le NIVEAU, lui,
     * reste mémorisé par personnage.
     */
    var opponentId by remember { mutableStateOf(if (initial.opponentId != null) "maia" else "maia") }
    /**
     * Le niveau est BORNÉ à la plage du personnage dès l'ouverture : un
     * curseur dont la valeur sort de ses bornes se colle à la butée sans le
     * dire, et l'on lancerait une partie à une force qu'on ne voit nulle part.
     */
    var level by remember {
        mutableStateOf(
            if (initial.opponentId != null) {
                val profile = OpponentGallery.byId("maia")
                val saved = OpponentLevelStore.level(context, "maia") ?: profile?.defaultLevel ?: initial.level
                profile?.let { saved.coerceIn(it.recommendedLevels.first.toDouble(), it.recommendedLevels.last.toDouble()) }
                    ?: saved
            } else {
                initial.level.coerceIn(EngineStrength.playSliderRange)
            }
        )
    }
    var timeId by remember { mutableStateOf(initial.timeControlId) }
    var category by remember { mutableStateOf(initial.timeControl.category) }
    var customMinutes by remember { mutableStateOf(initial.customMinutes) }
    var customIncrement by remember { mutableStateOf(initial.customIncrementSeconds) }
    var hints by remember { mutableStateOf(initial.hintsEnabled) }
    var blunderAlert by remember { mutableStateOf(initial.blunderAlertEnabled) }
    var evalBar by remember { mutableStateOf(initial.showEvalBar) }
    var engineResigns by remember { mutableStateOf(initial.engineResigns) }
    var bookEnabled by remember { mutableStateOf(initial.bookEnabled) }
    var bookWidth by remember { mutableStateOf(initial.bookWidth) }
    var useCustomFen by remember { mutableStateOf(initial.startFen != null) }
    var fenText by remember { mutableStateOf(initial.startFen.orEmpty()) }

    val profile = OpponentGallery.byId(opponentId)
    val fenIsLegal = remember(fenText) { FenValidator.errors(fenText.trim()).isEmpty() }
    val hasClock = remember(timeId, customMinutes) {
        if (timeId == "custom") customMinutes > 0 else TimeControl.byId(timeId).hasClock
    }

    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(22.dp),
        ) {
            SettingsSection(stringResource(R.string.setup_colour), Icons.Default.Contrast) {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(
                        Triple(PlayerColorChoice.white, R.string.color_white_side, Icons.Filled.Circle),
                        Triple(PlayerColorChoice.black, R.string.color_black_side, Icons.Outlined.Circle),
                        Triple(PlayerColorChoice.random, R.string.setup_random, Icons.Filled.Casino),
                    ).forEach { (value, label, icon) ->
                        ChipButton(
                            stringResource(label), color == value,
                            Modifier.testTag("couleur-${value.name}"), icon = icon,
                        ) { color = value }
                    }
                }
            }

            SettingsSection(
                stringResource(R.string.setup_opponent), Icons.Default.Person,
                modifier = Modifier.discoveryAnchor(DiscoverySpot.strengthSlider),
            ) {
                if (maiaAvailable) {
                    Segmented(
                        listOf(stringResource(R.string.setup_character), stringResource(R.string.stockfish)),
                        if (useCharacter) 0 else 1,
                    ) { index ->
                        val wanted = index == 0
                        if (wanted != useCharacter) {
                            useCharacter = wanted
                            level = if (wanted) levelFor(context, opponentId) else initial.level.coerceIn(EngineStrength.playSliderRange)
                        }
                    }
                    Spacer(Modifier.height(16.dp))
                }
                if (useCharacter && profile != null) {
                    OpponentGalleryGrid(opponentId) { picked ->
                        // Retaper le personnage DÉJÀ choisi ne fait rien : sans
                        // ce garde, le niveau qu'on venait d'ajuster retombait
                        // à celui d'usine.
                        if (picked.id != opponentId) {
                            opponentId = picked.id
                            level = levelFor(context, picked.id)
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                    LevelSlider(
                        title = stringResource(R.string.setup_level),
                        valueLabel = "${level.roundToInt()}",
                        tierLabel = null,
                        value = level,
                        range = profile.recommendedLevels.first.toFloat()..profile.recommendedLevels.last.toFloat(),
                        lowLabel = "${profile.recommendedLevels.first}",
                        highLabel = "${profile.recommendedLevels.last}",
                        tint = tintColor(profile.tint),
                        note = stringResource(R.string.setup_level_note),
                    ) { level = it }
                } else {
                    // Le chiffre PORTE le réglage réel : « Elo 1400 » quand le
                    // moteur est bridé à cet Elo, « Elo ~1000 » quand il est
                    // simulé plus bas, « Maximum » à la butée.
                    val strength = EngineStrength.of(level)
                    val numberLabel = if (strength is EngineStrength.Maximum) stringResource(R.string.strength_maximum)
                    else stringResource(strength.labelRes, level.roundToInt())
                    LevelSlider(
                        title = stringResource(R.string.setup_strength),
                        valueLabel = numberLabel,
                        tierLabel = EnginePreset.nearest(level)?.let { stringResource(it.label) },
                        value = level,
                        range = EngineStrength.playSliderRange.start.toFloat()..EngineStrength.playSliderRange.endInclusive.toFloat(),
                        lowLabel = "${EngineStrength.playSliderRange.start.roundToInt()}",
                        highLabel = stringResource(R.string.strength_maximum),
                        tint = Palette.accent,
                        note = null,
                    ) { level = it }
                }
            }

            // Le livre n'a de sens que pour Stockfish : le répertoire d'un
            // personnage ne se coupe pas, c'est son caractère.
            if (!useCharacter || !maiaAvailable) {
                SettingsSection(stringResource(R.string.setup_book), Icons.Default.MenuBook) {
                    ToggleRow(stringResource(R.string.setup_book_enabled), bookEnabled, "livre-actif") { bookEnabled = it }
                    if (bookEnabled) {
                        Spacer(Modifier.height(8.dp))
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            listOf(
                                BookWidth.mainLinesOnly to R.string.setup_book_main,
                                BookWidth.includeSidelines to R.string.setup_book_sidelines,
                            ).forEach { (width, label) ->
                                ChipButton(stringResource(label), bookWidth == width, Modifier.testTag("livre-${width.name}")) {
                                    bookWidth = width
                                }
                            }
                        }
                    }
                }
            }

            SettingsSection(stringResource(R.string.setup_time), Icons.Default.Timer) {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    TimeControl.categories.forEach { c ->
                        ChipButton(
                            stringResource(timeCategoryLabel(c)), category == c,
                            Modifier.testTag("cadence-$c"), icon = timeCategoryIcon(c),
                        ) {
                            // Retaper la famille DÉJÀ choisie ne fait rien :
                            // sans ce garde, on retombait sur sa première
                            // cadence en effaçant celle qu'on venait de régler.
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
                    "none" -> Text(stringResource(R.string.setup_no_clock), fontSize = 12.sp, color = Palette.textSecondary)
                    "custom" -> {
                        Stepper(stringResource(R.string.setup_custom_minutes), customMinutes, 1..180, "minutes-perso") {
                            customMinutes = it
                        }
                        Spacer(Modifier.height(8.dp))
                        Stepper(stringResource(R.string.setup_custom_increment), customIncrement, 0..60, "increment-perso") {
                            customIncrement = it
                        }
                    }
                    else -> FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        TimeControl.presets.filter { it.category == category }.forEach { tc ->
                            val label = if (tc.id == "none") stringResource(R.string.time_no_limit) else tc.label
                            ChipButton(label, timeId == tc.id, Modifier.testTag("preset-${tc.id}")) { timeId = tc.id }
                        }
                    }
                }
            }

            SettingsSection(
                stringResource(R.string.setup_aids), Icons.Default.Lightbulb,
                modifier = Modifier.discoveryAnchor(DiscoverySpot.aidToggles),
            ) {
                ToggleRow(stringResource(R.string.setup_hints), hints, "aide-indice") { hints = it }
                ToggleRow(stringResource(R.string.setup_blunder_alert), blunderAlert, "aide-alerte") {
                    blunderAlert = it
                }
                ToggleRow(stringResource(R.string.setup_eval_bar), evalBar, "aide-eval") { evalBar = it }
                ToggleRow(stringResource(R.string.setup_engine_resigns), engineResigns, "aide-abandon") { engineResigns = it }
                Spacer(Modifier.height(8.dp))
                Text(
                    stringResource(if (hasClock) R.string.setup_aids_note_clock else R.string.setup_aids_note),
                    fontSize = 11.sp, color = Palette.textTertiary,
                    modifier = Modifier.testTag("note-aides"),
                )
            }

            SettingsSection(stringResource(R.string.setup_start_section), Icons.Default.Tune) {
                ToggleRow(stringResource(R.string.setup_custom_position), useCustomFen, "position-perso") {
                    useCustomFen = it
                }
                if (useCustomFen) {
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value = fenText,
                        onValueChange = { fenText = it },
                        singleLine = true,
                        textStyle = androidx.compose.ui.text.TextStyle(
                            fontFamily = FontFamily.Monospace, fontSize = 12.sp, color = Palette.textPrimary,
                        ),
                        modifier = Modifier.fillMaxWidth().testTag("champ-fen"),
                    )
                    if (fenText.isNotBlank() && !fenIsLegal) {
                        Text(
                            stringResource(R.string.setup_invalid_fen), fontSize = 11.sp,
                            color = Palette.danger, modifier = Modifier.padding(top = 4.dp).testTag("fen-invalide"),
                        )
                    }
                    Spacer(Modifier.height(10.dp))
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        ChipButton(stringResource(R.string.setup_open_editor), false, Modifier.testTag("ouvrir-editeur"), icon = Icons.Default.Edit) {
                            onOpenEditor()
                        }
                        ChipButton(stringResource(R.string.setup_scan), false, Modifier.testTag("ouvrir-scanner"), icon = Icons.Default.PhotoCamera) {
                            onOpenScanner()
                        }
                    }
                }
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
            val ready = !useCustomFen || (fenText.isNotBlank() && fenIsLegal)
            Box(
                Modifier
                    .fillMaxWidth()
                    .clip(ControlShape)
                    .then(if (ready) Modifier.background(accentGradient) else Modifier.background(Palette.surfaceElevated))
                    .clickable(enabled = ready) {
                        val settings = PlayGameSettings(
                            colorChoice = color,
                            opponentId = if (useCharacter && maiaAvailable) opponentId else null,
                            level = level,
                            timeControlId = timeId,
                            customMinutes = customMinutes,
                            customIncrementSeconds = customIncrement,
                            hintsEnabled = hints,
                            blunderAlertEnabled = blunderAlert,
                            showEvalBar = evalBar,
                            engineResigns = engineResigns,
                            bookEnabled = bookEnabled,
                            bookWidth = bookWidth,
                            startFen = if (useCustomFen) fenText.trim() else null,
                        )
                        // Les réglages survivent à la fermeture de l'app ; le
                        // niveau, lui, se mémorise PAR personnage.
                        PlaySettingsStore.save(context, settings)
                        if (useCharacter && maiaAvailable) OpponentLevelStore.save(context, level, opponentId)
                        onStart(settings)
                    }
                    .padding(vertical = 14.dp)
                    .testTag("commencer"),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    stringResource(R.string.setup_start), fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = if (ready) Palette.background else Palette.textTertiary,
                )
            }
        }
    }
}

/** Le niveau mémorisé d'un personnage, borné à sa plage, ou celui d'usine. */
private fun levelFor(context: android.content.Context, profileId: String): Double {
    val profile = OpponentGallery.byId(profileId) ?: return 1200.0
    val saved = OpponentLevelStore.level(context, profileId) ?: profile.defaultLevel
    return saved.coerceIn(profile.recommendedLevels.first.toDouble(), profile.recommendedLevels.last.toDouble())
}

private fun timeCategoryLabel(category: String): Int = when (category) {
    "bullet" -> R.string.time_bullet
    "blitz" -> R.string.time_blitz
    "rapid" -> R.string.time_rapid
    "classical" -> R.string.time_classical
    "custom" -> R.string.time_custom
    else -> R.string.time_none
}

/** Un repère visuel qui se lit plus vite que le mot, du plus rapide au plus lent. */
private fun timeCategoryIcon(category: String) = when (category) {
    "bullet" -> Icons.Default.Speed
    "blitz" -> Icons.Default.Bolt
    "rapid" -> Icons.Default.Timer
    "classical" -> Icons.Default.FlagCircle
    "custom" -> Icons.Default.Tune
    else -> Icons.Default.AllInclusive
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

/** Un nombre qu'on règle à la main, entre deux bornes. */
@Composable
private fun Stepper(title: String, value: Int, range: IntRange, tag: String, onChange: (Int) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(title, fontSize = 13.sp, color = Palette.textPrimary, modifier = Modifier.weight(1f))
        listOf("−" to -1, "+" to 1).forEach { (glyph, delta) ->
            Text(
                glyph, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Palette.accent,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(Palette.surfaceElevated)
                    .clickable { onChange((value + delta).coerceIn(range)) }
                    .padding(horizontal = 14.dp, vertical = 4.dp)
                    .testTag("$tag-$delta"),
            )
            if (delta == -1) {
                Text(
                    "$value", fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                    color = Palette.textPrimary,
                    modifier = Modifier.padding(horizontal = 12.dp).testTag(tag),
                )
            }
        }
    }
}

/**
 * L'écran de configuration branché sur le modèle de vue, pour savoir si les
 * personnages sont disponibles — sans Maia, seul Stockfish reste.
 *
 * [startFen] : la position venue d'un autre écran (« Jouer à partir d'ici »),
 * ou celle que l'éditeur et le scanner rapportent.
 */
@Composable
fun NewGameSetupRoute(
    model: PlayViewModel = androidx.lifecycle.viewmodel.compose.viewModel(),
    startFen: String? = null,
    onOpenEditor: () -> Unit = {},
    onOpenScanner: () -> Unit = {},
    onStart: (PlayGameSettings) -> Unit,
) {
    val context = LocalContext.current
    val ui = model.ui
    // Les derniers réglages, relus du disque : ils survivent à la fermeture
    // de l'app. La position, elle, ne se mémorise jamais — c'est un choix
    // ponctuel, pas une préférence.
    val remembered = remember { PlaySettingsStore.load(context) ?: PlayGameSettings() }
    NewGameScreen(
        maiaAvailable = ui.maiaAvailable,
        initial = remembered.copy(startFen = startFen),
        onOpenEditor = onOpenEditor,
        onOpenScanner = onOpenScanner,
        onStart = onStart,
    )
}
