package com.chesslab.play

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.ui.draw.drawBehind
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Contrast
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.material.icons.filled.TextFields
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material.icons.outlined.MenuBook
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.discovery.DiscoverySpot
import com.chesslab.discovery.discoveryAnchor
import com.chesslab.editor.FenValidator
import com.chesslab.maia.OpponentGallery
import com.chesslab.maia.OpponentProfile
import com.chesslab.maia.OpponentTraits
import com.chesslab.ui.*
import kotlin.math.roundToInt

/**
 * L'écran de configuration d'une partie. Pendant de `NewGameSetupView` — REFONDU comme iOS (17-18/11/2026 :
 * « plus joli, plus compact, moins old style »).
 *
 * Trois blocs au lieu de sept sections : l'ADVERSAIRE en vedette (une bande de portraits, Stockfish tout à gauche
 * et Maia choisie à l'ouverture ; le nom, le surnom, quatre jauges, le niveau), une carte PARTIE aux lignes toutes
 * du même style (chacune montre son choix et s'ouvre en menu), les AIDES en quatre pastilles. Une seule couleur
 * d'accent ; la couleur du personnage ne vit que sur son portrait, son halo, son surnom et ses jauges.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NewGameScreen(
    maiaAvailable: Boolean,
    initial: PlayGameSettings,
    onOpenEditor: () -> Unit = {},
    onOpenScanner: () -> Unit = {},
    /** Reprendre la partie contre l'ordinateur laissée en cours. */
    onResume: () -> Unit = {},
    onStart: (PlayGameSettings) -> Unit,
) {
    val context = LocalContext.current
    // La partie en cours (mode « engine ») : lancer une nouvelle partie l'EFFACE, et l'écran le dit
    // au lieu de le laisser découvrir (retour d'un joueur, 27/10/2026). Pendant d'iOS.
    val autosaves by remember { com.chesslab.library.LibraryDatabase.get(context).autosaves().all() }
        .collectAsState(initial = emptyList())
    val resumable = autosaves.firstOrNull { it.mode == "engine" }
    var confirmReplace by remember { mutableStateOf(false) }

    var color by remember { mutableStateOf(initial.colorChoice) }
    // Maia, TOUJOURS, à l'ouverture (demande du 17/11/2026) : Stockfish est à un toucher, tout à gauche. Sans
    // Maia (modèle absent), seul Stockfish reste.
    var useCharacter by remember { mutableStateOf(maiaAvailable) }
    var opponentId by remember { mutableStateOf("maia") }
    /**
     * La force de Stockfish, gardée à part : toucher Stockfish la retrouve, au lieu de garder le niveau du
     * personnage (échelle humaine) affiché juste avant. Si la dernière partie était contre un personnage, le
     * niveau enregistré est le SIEN : on repart alors de la force par défaut. Comme iOS.
     */
    var stockfishLevel by remember {
        mutableStateOf(
            (if (initial.opponentId == null) initial.level else PlayGameSettings().level)
                .coerceIn(EngineStrength.playSliderRange)
        )
    }
    var level by remember { mutableStateOf(if (maiaAvailable) levelFor(context, "maia") else stockfishLevel) }
    val timeLimit = rememberTimeLimit(initial.timeControlId, initial.customMinutes, initial.customIncrementSeconds, "play")
    var showCustomClock by remember { mutableStateOf(false) }
    var hints by remember { mutableStateOf(initial.hintsEnabled) }
    var blunderAlert by remember { mutableStateOf(initial.blunderAlertEnabled) }
    var evalBar by remember { mutableStateOf(initial.showEvalBar) }
    var engineResigns by remember { mutableStateOf(initial.engineResigns) }
    var bookEnabled by remember { mutableStateOf(initial.bookEnabled) }
    var bookWidth by remember { mutableStateOf(initial.bookWidth) }
    var useCustomFen by remember { mutableStateOf(initial.startFen != null) }
    var fenText by remember { mutableStateOf(initial.startFen.orEmpty()) }
    // L'aveugle ne se RETIENT pas d'une partie à l'autre : « Nouvelle partie » ne doit jamais ouvrir sur un plateau
    // vide sans qu'on l'ait demandé. Comme iOS.
    var blindfold by remember { mutableStateOf(BlindfoldLevel.off) }
    var blindfoldVoice by remember { mutableStateOf(initial.blindfoldVoice) }

    val profile: OpponentProfile? = if (useCharacter) OpponentGallery.byId(opponentId) else null
    val fenIsLegal = remember(fenText) { FenValidator.errors(fenText.trim()).isEmpty() }
    val blind = blindfold != BlindfoldLevel.off

    val launchNew: () -> Unit = {
        val settings = PlayGameSettings(
            colorChoice = color,
            opponentId = if (useCharacter && maiaAvailable) opponentId else null,
            level = level,
            timeControlId = timeLimit.effectiveId,
            customMinutes = timeLimit.customMinutes,
            customIncrementSeconds = timeLimit.customIncrement,
            hintsEnabled = hints,
            blunderAlertEnabled = blunderAlert,
            showEvalBar = evalBar,
            engineResigns = engineResigns,
            bookEnabled = bookEnabled,
            bookWidth = bookWidth,
            startFen = if (useCustomFen) fenText.trim() else null,
            blindfold = blindfold,
            blindfoldVoice = blindfoldVoice,
        )
        // Les réglages survivent à la fermeture de l'app ; le niveau, lui, se mémorise PAR personnage.
        timeLimit.remember()
        PlaySettingsStore.save(context, settings)
        if (useCharacter && maiaAvailable) OpponentLevelStore.save(context, level, opponentId)
        onStart(settings)
    }

    if (confirmReplace) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { confirmReplace = false },
            title = { Text(stringResource(R.string.setup_replace_title)) },
            text = { Text(stringResource(R.string.setup_replace_message, resumable?.moveList?.size ?: 0)) },
            confirmButton = {
                TextButton(
                    onClick = { confirmReplace = false; onResume() },
                    modifier = Modifier.testTag("remplacer-reprendre"),
                ) { Text(stringResource(R.string.home_resume_title)) }
            },
            dismissButton = {
                Row {
                    TextButton(onClick = { confirmReplace = false }) { Text(stringResource(R.string.setup_replace_cancel)) }
                    TextButton(
                        onClick = { confirmReplace = false; launchNew() },
                        modifier = Modifier.testTag("remplacer-confirmer"),
                    ) { Text(stringResource(R.string.setup_replace_confirm)) }
                }
            },
        )
    }

    // La cadence « Personnalisé… » s'ouvre en feuille (minutes, incrément), comme iOS.
    if (showCustomClock) {
        ModalBottomSheet(
            onDismissRequest = { showCustomClock = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = Palette.surface,
        ) {
            Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 24.dp).testTag("feuille-cadence")) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        stringResource(R.string.ng_cadence), fontSize = 17.sp, fontWeight = FontWeight.SemiBold,
                        color = Palette.textPrimary, modifier = Modifier.weight(1f),
                    )
                    TextButton(onClick = { showCustomClock = false }, modifier = Modifier.testTag("cadence-ok")) {
                        Text(stringResource(R.string.ng_ok), color = Palette.accent, fontWeight = FontWeight.SemiBold)
                    }
                }
                Spacer(Modifier.height(8.dp))
                TimeLimitSection(timeLimit, Palette.accent)
            }
        }
    }

    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .padding(top = 4.dp, bottom = 20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            resumable?.let { save -> ResumeCard(save.moveList.size, onResume) }

            OpponentHero(
                maiaAvailable = maiaAvailable,
                profile = profile,
                level = level,
                onLevel = { level = it },
                onChooseProfile = { picked ->
                    if (!useCharacter) stockfishLevel = level
                    // Retaper le personnage DÉJÀ choisi ne fait rien : le niveau qu'on venait d'ajuster resterait.
                    if (!useCharacter || picked.id != opponentId) {
                        useCharacter = true
                        opponentId = picked.id
                        level = levelFor(context, picked.id)
                    }
                },
                onChooseStockfish = {
                    if (useCharacter) {
                        useCharacter = false
                        level = stockfishLevel
                    }
                },
                modifier = Modifier.discoveryAnchor(DiscoverySpot.strengthSlider),
            )

            GameCard {
                SettingRow(Icons.Default.Contrast, stringResource(R.string.ng_colour)) {
                    ColourPicker(color) { color = it }
                }
                RowDivider()
                SettingRow(
                    Icons.Default.Timer, stringResource(R.string.ng_cadence),
                    Modifier.discoveryAnchor(DiscoverySpot.timeLimit),
                ) {
                    ClockMenu(timeLimit) { showCustomClock = true }
                }
                RowDivider()
                SettingRow(Icons.Outlined.VisibilityOff, stringResource(R.string.ng_blind)) {
                    MenuButton(stringResource(blindfold.titleRes), highlighted = blind, tag = "menu-aveugle") { close ->
                        (listOf(BlindfoldLevel.off) + BlindfoldLevel.levels).forEach { lvl ->
                            CheckItem(stringResource(lvl.titleRes), blindfold == lvl, "aveugle-${lvl.name}") {
                                blindfold = lvl; close()
                            }
                        }
                    }
                }
                if (blind) {
                    RowDivider()
                    SettingRow(Icons.Default.VolumeUp, stringResource(R.string.ng_voice)) {
                        Switch(
                            checked = blindfoldVoice, onCheckedChange = { blindfoldVoice = it },
                            colors = SwitchDefaults.colors(checkedTrackColor = Palette.accent),
                            modifier = Modifier.testTag("aveugle-voix"),
                        )
                    }
                }
                RowDivider()
                SettingRow(Icons.Outlined.Flag, stringResource(R.string.ng_start)) {
                    MenuButton(
                        stringResource(if (useCustomFen) R.string.ng_start_custom else R.string.ng_start_initial),
                        highlighted = useCustomFen, tag = "menu-depart",
                    ) { close ->
                        CheckItem(stringResource(R.string.ng_start_position), !useCustomFen, "depart-initiale") {
                            useCustomFen = false; close()
                        }
                        IconItem(stringResource(R.string.ng_start_enter_fen), Icons.Default.TextFields, "depart-fen") {
                            useCustomFen = true; close()
                        }
                        IconItem(stringResource(R.string.setup_open_editor), Icons.Default.Edit, "ouvrir-editeur") {
                            useCustomFen = true; close(); onOpenEditor()
                        }
                        IconItem(stringResource(R.string.setup_scan), Icons.Default.PhotoCamera, "ouvrir-scanner") {
                            useCustomFen = true; close(); onOpenScanner()
                        }
                    }
                }
                if (useCustomFen) {
                    Column(Modifier.padding(horizontal = 14.dp).padding(bottom = 12.dp)) {
                        OutlinedTextField(
                            value = fenText,
                            onValueChange = { fenText = it },
                            singleLine = true,
                            placeholder = { Text("rnbqkbnr/pppppppp/…", fontSize = 12.sp, color = Palette.textTertiary) },
                            textStyle = androidx.compose.ui.text.TextStyle(
                                fontFamily = FontFamily.Monospace, fontSize = 12.sp, color = Palette.textPrimary,
                            ),
                            isError = fenText.isNotBlank() && !fenIsLegal,
                            modifier = Modifier.fillMaxWidth().testTag("champ-fen"),
                        )
                        if (fenText.isNotBlank() && !fenIsLegal) {
                            Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.Warning, null, tint = Palette.danger, modifier = Modifier.size(14.dp))
                                Spacer(Modifier.width(6.dp))
                                Text(
                                    stringResource(R.string.setup_invalid_fen), fontSize = 12.sp,
                                    color = Palette.danger, modifier = Modifier.testTag("fen-invalide"),
                                )
                            }
                        }
                    }
                }
                // Le livre n'a de sens que pour Stockfish : le répertoire d'un personnage ne se coupe pas.
                if (!useCharacter) {
                    RowDivider()
                    SettingRow(Icons.Outlined.MenuBook, stringResource(R.string.ng_book)) {
                        val label = when {
                            !bookEnabled -> R.string.ng_book_none
                            bookWidth == BookWidth.mainLinesOnly -> R.string.setup_book_main
                            else -> R.string.setup_book_sidelines
                        }
                        MenuButton(stringResource(label), highlighted = false, tag = "menu-livre") { close ->
                            CheckItem(stringResource(R.string.ng_book_none), !bookEnabled, "livre-aucun") {
                                bookEnabled = false; close()
                            }
                            listOf(
                                BookWidth.mainLinesOnly to R.string.setup_book_main,
                                BookWidth.includeSidelines to R.string.setup_book_sidelines,
                            ).forEach { (width, res) ->
                                CheckItem(stringResource(res), bookEnabled && bookWidth == width, "livre-${width.name}") {
                                    bookEnabled = true; bookWidth = width; close()
                                }
                            }
                        }
                    }
                }
            }

            // Les aides : quatre pastilles d'une seule couleur ; à l'aveugle, les trois qui montreraient la position
            // s'éteignent.
            Column(
                Modifier.discoveryAnchor(DiscoverySpot.aidToggles),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text(
                    stringResource(R.string.ng_aids_header).uppercase(), fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                    color = Palette.textSecondary, letterSpacing = 0.5.sp, modifier = Modifier.padding(start = 4.dp),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    AidChip(Icons.Default.Lightbulb, Icons.Outlined.Lightbulb, stringResource(R.string.ng_aid_hint),
                        stringResource(R.string.setup_hints), hints, blind, "aide-indice", Modifier.weight(1f)) { hints = !hints }
                    AidChip(Icons.Default.Warning, Icons.Outlined.WarningAmber, stringResource(R.string.ng_aid_blunder),
                        stringResource(R.string.setup_blunder_alert), blunderAlert, blind, "aide-alerte", Modifier.weight(1f)) {
                        blunderAlert = !blunderAlert
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    AidChip(Icons.Default.BarChart, Icons.Outlined.BarChart, stringResource(R.string.setup_eval_bar),
                        stringResource(R.string.setup_eval_bar), evalBar, blind, "aide-eval", Modifier.weight(1f)) { evalBar = !evalBar }
                    AidChip(Icons.Default.Flag, Icons.Outlined.Flag, stringResource(R.string.ng_aid_resign),
                        stringResource(R.string.setup_engine_resigns), engineResigns, false, "aide-abandon", Modifier.weight(1f)) {
                        engineResigns = !engineResigns
                    }
                }
            }
        }

        // Le bouton reste EN BAS et toujours visible : c'est la seule action de l'écran, et elle ne doit pas se
        // mériter en défilant.
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
                        // Une partie en cours serait effacée par la nouvelle : on demande d'abord.
                        if (resumable != null) confirmReplace = true else launchNew()
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

/** La carte « Reprendre » : c'est ici qu'on atterrit en quittant une partie par la flèche. */
@Composable
private fun ResumeCard(moveCount: Int, onResume: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(ControlShape)
            .background(Palette.accent.copy(alpha = 0.14f))
            .border(1.dp, Palette.accent.copy(alpha = 0.4f), ControlShape)
            .clickable(onClick = onResume)
            .padding(16.dp)
            .testTag("reprendre-depuis-reglages"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Default.PlayCircle, null, tint = Palette.accent, modifier = Modifier.size(30.dp))
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(stringResource(R.string.home_resume_title), fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
            Text(stringResource(R.string.setup_resume_waiting, moveCount), fontSize = 12.sp, color = Palette.textSecondary)
        }
    }
}

// MARK: L'adversaire en vedette

private val HeroShape = RoundedCornerShape(22.dp)

@Composable
private fun OpponentHero(
    maiaAvailable: Boolean,
    profile: OpponentProfile?,
    level: Double,
    onLevel: (Double) -> Unit,
    onChooseProfile: (OpponentProfile) -> Unit,
    onChooseStockfish: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val heroTint = profile?.let { tintColor(it.tint) } ?: Palette.accent
    val heroVivid = profile?.let { vividTintColor(it.tint) } ?: Palette.accent
    val haloRadius = with(LocalDensity.current) { 220.dp.toPx() }
    var showTagline by remember { mutableStateOf(false) }
    Column(
        modifier
            .fillMaxWidth()
            .clip(HeroShape)
            .background(Palette.surfaceElevated)
            .drawBehind {
                // Un halo discret de la couleur du personnage, en haut seulement.
                drawRect(
                    Brush.radialGradient(
                        listOf(heroTint.copy(alpha = 0.28f), Color.Transparent),
                        center = Offset(size.width / 2, 0f), radius = haloRadius,
                    )
                )
            }
            .border(1.dp, Palette.stroke, HeroShape)
            .padding(vertical = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        // Stockfish à GAUCHE, puis les personnages, Maia en tête (demande du 17/11/2026).
        val gallery = if (maiaAvailable) OpponentGallery.all else emptyList()
        val selectedIndex = profile?.let { p -> gallery.indexOfFirst { it.id == p.id } + 1 } ?: 0
        val listState = rememberLazyListState(initialFirstVisibleItemIndex = (selectedIndex - 1).coerceAtLeast(0))
        LazyRow(
            state = listState,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 6.dp),
            modifier = Modifier.fillMaxWidth().testTag("bande-adversaires"),
        ) {
            item(key = "stockfish") { StockfishPortrait(profile == null, onChooseStockfish) }
            items(gallery, key = { it.id }) { p ->
                Portrait(p, profile?.id == p.id) { onChooseProfile(p) }
            }
        }

        Column(
            Modifier.padding(horizontal = 12.dp).testTag("fiche-${profile?.id ?: "stockfish"}"),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            if (profile != null) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(profile.firstName, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary)
                    Text(
                        stringResource(R.string.opponent_nickname_quoted, stringResource(profile.nicknameRes)),
                        fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = heroVivid,
                    )
                    // La phrase du personnage — son charme — reste à un toucher.
                    Box {
                        val about = stringResource(R.string.ng_about, profile.firstName)
                        Icon(
                            Icons.Outlined.Info, about, tint = Palette.textTertiary,
                            modifier = Modifier
                                .size(28.dp)
                                .clip(CircleShape)
                                .clickable { showTagline = true }
                                .padding(4.dp)
                                .testTag("info-adversaire"),
                        )
                        DropdownMenu(
                            expanded = showTagline, onDismissRequest = { showTagline = false },
                            modifier = Modifier.background(Palette.surfaceElevated),
                        ) {
                            Text(
                                stringResource(profile.taglineRes), fontSize = 14.sp, color = Palette.textPrimary,
                                modifier = Modifier.widthIn(max = 280.dp).padding(16.dp).testTag("phrase-adversaire"),
                            )
                        }
                    }
                }
                Spacer(Modifier.height(6.dp))
                TraitGauges(OpponentTraits.of(profile), heroVivid)
            } else {
                Text(stringResource(R.string.stockfish), fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary)
                Text(
                    stringResource(R.string.ng_stockfish_blurb), fontSize = 13.sp, color = Palette.textSecondary,
                    textAlign = TextAlign.Center,
                )
            }
        }

        LevelRow(profile, level, onLevel, Modifier.padding(horizontal = 12.dp))
    }
}

@Composable
private fun Portrait(profile: OpponentProfile, selected: Boolean, onClick: () -> Unit) {
    val tint = tintColor(profile.tint)
    val label = "${profile.firstName} " + stringResource(R.string.opponent_nickname_quoted, stringResource(profile.nicknameRes))
    PortraitFrame(selected, tint, label, "adversaire-${profile.id}", onClick) { size ->
        OpponentAvatar(profile, size)
    }
}

@Composable
private fun StockfishPortrait(selected: Boolean, onClick: () -> Unit) {
    PortraitFrame(selected, Palette.accent, stringResource(R.string.stockfish), "adversaire-stockfish", onClick) { size ->
        Box(
            Modifier
                .size(size)
                .clip(CircleShape)
                .background(if (selected) Palette.accent else Palette.accent.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Default.Memory, null,
                tint = if (selected) Palette.background else Palette.accent,
                modifier = Modifier.size(if (selected) 30.dp else 22.dp),
            )
        }
    }
}

/** Le cadre commun : 72 dp, le choisi en grand (64) et cerclé de sa couleur, les autres plus petits et voilés. */
@Composable
private fun PortraitFrame(
    selected: Boolean, tint: Color, label: String, tag: String, onClick: () -> Unit,
    content: @Composable (Dp) -> Unit,
) {
    Box(
        Modifier
            .size(72.dp)
            .clip(CircleShape)
            .clickable(onClick = onClick)
            .semantics(mergeDescendants = true) {
                contentDescription = label
                this.selected = selected
                role = Role.RadioButton
            }
            .testTag(tag),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier
                .alpha(if (selected) 1f else 0.75f)
                .border(2.5.dp, if (selected) tint else Color.Transparent, CircleShape)
                .padding(3.dp)
                .clearAndSetSemantics {},
        ) { content(if (selected) 64.dp else 48.dp) }
    }
}

/**
 * Quatre jauges de cinq points : Attaque, Solidité, Échanges, Imprévisible — calculées des réglages du personnage
 * ([OpponentTraits]), donc comparables d'un personnage à l'autre.
 */
@Composable
private fun TraitGauges(traits: OpponentTraits, tint: Color) {
    // Deux colonnes qui se partagent la largeur : à largeur fixe, la colonne de droite débordait et perdait son
    // cinquième point sur le Galaxy (police système agrandie).
    Column(Modifier.fillMaxWidth().testTag("jauges"), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
            TraitGauge(stringResource(R.string.ng_attack), traits.attack, tint, Modifier.weight(1f))
            TraitGauge(stringResource(R.string.ng_solidity), traits.solidity, tint, Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
            TraitGauge(stringResource(R.string.ng_trades), traits.trades, tint, Modifier.weight(1f))
            TraitGauge(stringResource(R.string.ng_unpredictable), traits.unpredictability, tint, Modifier.weight(1f))
        }
    }
}

@Composable
private fun TraitGauge(title: String, value: Int, tint: Color, modifier: Modifier = Modifier) {
    val spoken = stringResource(R.string.ng_gauge_value, value)
    Row(
        modifier.clearAndSetSemantics { contentDescription = "$title, $spoken" },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            title, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary,
            maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            (1..5).forEach { step ->
                Box(
                    Modifier
                        .size(width = 12.dp, height = 6.dp)
                        .clip(CircleShape)
                        .background(if (step <= value) tint else Color.White.copy(alpha = 0.12f))
                )
            }
        }
    }
}

/** Le niveau, sur une ligne : le mot, le curseur, le chiffre. Par pas de 50, comme iOS. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LevelRow(profile: OpponentProfile?, level: Double, onLevel: (Double) -> Unit, modifier: Modifier = Modifier) {
    val range = profile?.let { it.recommendedLevels.first.toDouble()..it.recommendedLevels.last.toDouble() }
        ?: EngineStrength.playSliderRange
    val valueLabel = if (profile != null) "${level.roundToInt()}" else {
        val strength = EngineStrength.of(level)
        if (strength is EngineStrength.Maximum) stringResource(R.string.strength_maximum)
        else stringResource(strength.labelRes, level.roundToInt())
    }
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(stringResource(R.string.ng_level), fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary)
        // Une poignée blanche en pastille sur une piste fine, comme le curseur d'iOS — pas la barre verticale et le
        // point d'arrêt du curseur Material.
        val colors = SliderDefaults.colors(
            activeTrackColor = Palette.accent, inactiveTrackColor = Color.White.copy(alpha = 0.12f),
            thumbColor = Color.White,
        )
        Slider(
            value = level.toFloat().coerceIn(range.start.toFloat(), range.endInclusive.toFloat()),
            onValueChange = {
                onLevel(((it / 50).roundToInt() * 50).toDouble().coerceIn(range.start, range.endInclusive))
            },
            valueRange = range.start.toFloat()..range.endInclusive.toFloat(),
            colors = colors,
            thumb = {
                Box(
                    Modifier
                        .size(width = 34.dp, height = 22.dp)
                        .shadow(3.dp, RoundedCornerShape(11.dp))
                        .background(Color.White, RoundedCornerShape(11.dp))
                )
            },
            track = { state ->
                SliderDefaults.Track(
                    sliderState = state, colors = colors, drawStopIndicator = null,
                    thumbTrackGapSize = 0.dp, modifier = Modifier.height(6.dp),
                )
            },
            modifier = Modifier.weight(1f).testTag("curseur-niveau"),
        )
        Text(
            valueLabel, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
            textAlign = TextAlign.End, maxLines = 1,
            style = androidx.compose.ui.text.TextStyle(fontFeatureSettings = "tnum"),
            modifier = Modifier.widthIn(min = 52.dp).testTag("niveau"),
        )
    }
}

// MARK: La carte « Partie »

private val CardShape = RoundedCornerShape(18.dp)

@Composable
private fun GameCard(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(Palette.surfaceElevated)
            .border(1.dp, Palette.stroke, CardShape),
        content = content,
    )
}

@Composable
private fun RowDivider() {
    HorizontalDivider(Modifier.padding(start = 52.dp), thickness = 0.5.dp, color = Palette.strokeStrong)
}

@Composable
private fun SettingRow(icon: ImageVector, title: String, modifier: Modifier = Modifier, trailing: @Composable () -> Unit) {
    Row(
        modifier.fillMaxWidth().heightIn(min = 50.dp).padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(icon, null, tint = Palette.accent, modifier = Modifier.width(26.dp).size(20.dp))
        Text(title, fontSize = 16.sp, color = Palette.textPrimary, modifier = Modifier.weight(1f), maxLines = 1)
        trailing()
    }
}

/** La valeur à droite d'une ligne : le choix, puis la petite flèche des menus. Le menu s'ouvre dessous. */
@Composable
private fun MenuButton(
    value: String, highlighted: Boolean, tag: String,
    items: @Composable ColumnScope.(close: () -> Unit) -> Unit,
) {
    var open by remember { mutableStateOf(false) }
    Box {
        Row(
            Modifier
                .clip(RoundedCornerShape(8.dp))
                .clickable { open = true }
                .padding(horizontal = 4.dp, vertical = 8.dp)
                .testTag(tag),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            val tint = if (highlighted) Palette.accent else Palette.textSecondary
            Text(value, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = tint, maxLines = 1)
            Icon(Icons.Default.UnfoldMore, null, tint = tint, modifier = Modifier.size(14.dp))
        }
        DropdownMenu(
            expanded = open, onDismissRequest = { open = false },
            modifier = Modifier.background(Palette.surfaceElevated),
        ) { items { open = false } }
    }
}

@Composable
private fun CheckItem(label: String, checked: Boolean, tag: String, onClick: () -> Unit) {
    DropdownMenuItem(
        text = { Text(label, color = Palette.textPrimary) },
        onClick = onClick,
        leadingIcon = {
            Box(Modifier.size(20.dp)) { if (checked) Icon(Icons.Default.Check, null, tint = Palette.accent) }
        },
        modifier = Modifier.testTag(tag).semantics { selected = checked },
    )
}

@Composable
private fun IconItem(label: String, icon: ImageVector, tag: String, onClick: () -> Unit) {
    DropdownMenuItem(
        text = { Text(label, color = Palette.textPrimary) },
        onClick = onClick,
        leadingIcon = { Icon(icon, null, tint = Palette.textSecondary, modifier = Modifier.size(20.dp)) },
        modifier = Modifier.testTag(tag),
    )
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text.uppercase(), fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Palette.textTertiary,
        modifier = Modifier.padding(start = 16.dp, top = 8.dp, bottom = 2.dp),
    )
}

/** La cadence : « Sans limite », puis les cadences par famille, puis « Personnalisé… » qui ouvre la feuille. */
@Composable
private fun ClockMenu(timeLimit: TimeLimitState, onCustom: () -> Unit) {
    val value = when {
        !timeLimit.enabled -> stringResource(R.string.time_none)
        timeLimit.isCustom -> "${timeLimit.customMinutes}+${timeLimit.customIncrement}"
        else -> TimeControl.byId(timeLimit.presetId).label
    }
    MenuButton(value, highlighted = timeLimit.enabled, tag = "menu-cadence") { close ->
        CheckItem(stringResource(R.string.time_none), !timeLimit.enabled, "cadence-none") {
            timeLimit.enabled = false; close()
        }
        listOf(
            "bullet" to R.string.time_bullet, "blitz" to R.string.time_blitz,
            "rapid" to R.string.time_rapid, "classical" to R.string.time_classical,
        ).forEach { (category, res) ->
            SectionLabel(stringResource(res))
            TimeControl.presets.filter { it.category == category }.forEach { tc ->
                val chosen = timeLimit.enabled && !timeLimit.isCustom && timeLimit.presetId == tc.id
                CheckItem(tc.label, chosen, "preset-${tc.id}") {
                    timeLimit.enabled = true
                    timeLimit.select(category)
                    timeLimit.presetId = tc.id
                    close()
                }
            }
        }
        IconItem(stringResource(R.string.ng_custom_clock), Icons.Default.Tune, "cadence-perso") {
            timeLimit.enabled = true
            timeLimit.select("custom")
            close()
            onCustom()
        }
    }
}

/** Trois disques : Blancs, Noirs, au hasard. */
@Composable
private fun ColourPicker(selected: PlayerColorChoice, onSelect: (PlayerColorChoice) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        listOf(
            PlayerColorChoice.white to R.string.color_white_side,
            PlayerColorChoice.black to R.string.color_black_side,
            PlayerColorChoice.random to R.string.setup_random,
        ).forEach { (choice, res) ->
            val isOn = selected == choice
            val label = stringResource(res)
            Box(
                Modifier
                    .clip(CircleShape)
                    .border(2.dp, if (isOn) Palette.accent else Color.Transparent, CircleShape)
                    .clickable { onSelect(choice) }
                    .padding(3.dp)
                    .semantics {
                        contentDescription = label
                        this.selected = isOn
                        role = Role.RadioButton
                    }
                    .testTag("couleur-${choice.name}"),
            ) {
                Box(
                    Modifier
                        .size(26.dp)
                        .clip(CircleShape)
                        .background(
                            when (choice) {
                                PlayerColorChoice.white -> Color.White
                                PlayerColorChoice.black -> Color.Black
                                else -> Palette.background
                            }
                        )
                        .border(1.dp, Color.White.copy(alpha = 0.35f), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    if (choice == PlayerColorChoice.random) {
                        Icon(Icons.Default.Shuffle, null, tint = Palette.textSecondary, modifier = Modifier.size(14.dp))
                    }
                }
            }
        }
    }
}

// MARK: Les aides

private val AidShape = RoundedCornerShape(14.dp)

@Composable
private fun AidChip(
    litIcon: ImageVector, restIcon: ImageVector, title: String, fullLabel: String,
    isOn: Boolean, blinded: Boolean, tag: String, modifier: Modifier = Modifier, onToggle: () -> Unit,
) {
    val lit = isOn && !blinded
    val tint = if (lit) Palette.accent else Palette.textSecondary
    Row(
        modifier
            .heightIn(min = 46.dp)
            .alpha(if (blinded) 0.4f else 1f)
            .clip(AidShape)
            .background(if (lit) Palette.accent.copy(alpha = 0.14f) else Palette.surfaceElevated)
            .border(1.dp, if (lit) Palette.accent.copy(alpha = 0.55f) else Palette.stroke, AidShape)
            // `toggleable` : le lecteur d'écran dit « activé / désactivé » dans la langue du téléphone.
            .toggleable(value = lit, enabled = !blinded, role = Role.Switch) { onToggle() }
            .semantics(mergeDescendants = true) { contentDescription = fullLabel }
            .padding(horizontal = 12.dp)
            .testTag(tag),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(if (lit) litIcon else restIcon, null, tint = tint, modifier = Modifier.size(20.dp))
        Text(
            title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = tint,
            maxLines = 1, overflow = TextOverflow.Ellipsis,
        )
    }
}

/** Le niveau mémorisé d'un personnage, borné à sa plage, ou celui d'usine. */
private fun levelFor(context: android.content.Context, profileId: String): Double {
    val profile = OpponentGallery.byId(profileId) ?: return 1200.0
    val saved = OpponentLevelStore.level(context, profileId) ?: profile.defaultLevel
    return saved.coerceIn(profile.recommendedLevels.first.toDouble(), profile.recommendedLevels.last.toDouble())
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
    onResume: () -> Unit = {},
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
        onResume = onResume,
        onStart = onStart,
    )
}
