package com.chesslab.lab

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.chesslab.maia.OpponentGallery
import com.chesslab.maia.OpponentProfile
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
import com.chesslab.ui.MoveStrip
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.text.style.TextAlign
import com.chesslab.ui.accentGradient
import com.chesslab.ui.Palette
import com.chesslab.ui.StatusRow
import androidx.compose.ui.res.stringResource
import com.chesslab.R
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString

@Composable
fun LabScreen(
    /** La position envoyée par un autre mode : la série part de là. */
    startFen: String? = null,
    model: LabViewModel = viewModel(),
) {
    val ui = model.ui

    LaunchedEffect(startFen) { if (startFen != null) model.startFrom(startFen) }

    // Une série interrompue attend peut-être sur le disque : on le demande à
    // l'ouverture, une fois.
    LaunchedEffect(Unit) { model.lookForInterruptedSeries() }

    // Une longue série tourne plusieurs minutes sans qu'on touche l'écran :
    // sans ce verrou, l'appareil s'endort et la série s'arrête avec lui. On
    // ne le prend QUE pendant la série, et on le rend en partant.
    val view = androidx.compose.ui.platform.LocalView.current
    DisposableEffect(ui.keepAwake && ui.running) {
        view.keepScreenOn = ui.keepAwake && ui.running
        onDispose { view.keepScreenOn = false }
    }

    BoardScaffold(
        header = {
            com.chesslab.ui.ThermalBadge()
            Scoreboard(ui)
            Spacer(Modifier.height(8.dp))
            SidePicker(stringResource(R.string.lab_side_a), ui.sideA.profile, "a", model::setSideA)
            Spacer(Modifier.height(6.dp))
            SidePicker(stringResource(R.string.lab_side_b), ui.sideB.profile, "b", model::setSideB)

            Spacer(Modifier.height(8.dp))
            StatusRow(ui.status, busy = ui.running)
            Spacer(Modifier.height(8.dp))
        },
        board = {
            BoardView(position = ui.position, lastMove = ui.lastMove, enabled = false)
        },
        panel = {
            Spacer(Modifier.height(10.dp))
            MoveStrip(ui.sanMoves)

            ui.resumable?.let { snapshot ->
                Spacer(Modifier.height(12.dp))
                ResumeBanner(
                    played = snapshot.completed.size,
                    total = snapshot.settings.gameCount,
                    onResume = model::resumeInterruptedSeries,
                    onDiscard = model::discardInterruptedSeries,
                )
            }

            Spacer(Modifier.height(12.dp))
            LabStatsPanel(ui)

            Spacer(Modifier.height(12.dp))
            SeriesSettings(ui, model)

            Spacer(Modifier.height(12.dp))
            StartPositionField(ui, model::startFrom, model::clearStartPosition)

            if (ui.completed.isNotEmpty()) {
                Spacer(Modifier.height(12.dp))
                ExportRow(model)
            }

            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    stringResource(if (ui.running) R.string.lab_pause else R.string.lab_start),
                    fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .clip(CircleShape)
                        .background(accentGradient)
                        .clickable { model.toggle() }
                        .padding(vertical = 13.dp)
                        .testTag("lancer"),
                )
                Text(
                    stringResource(R.string.lab_reset),
                    fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .clip(CircleShape)
                        .background(Palette.surfaceElevated)
                        .border(1.dp, Palette.stroke, CircleShape)
                        .clickable { model.reset() }
                        .padding(vertical = 13.dp)
                        .testTag("remise"),
                )
            }
        },
    )
}

/**
 * La bannière de reprise. Pendant de `resumeBanner` (`LabSetupView`).
 *
 * Elle ne reprend RIEN toute seule : une série qu'on retrouve peut aussi être
 * une série qu'on avait abandonnée exprès, et la relancer d'office ferait
 * repartir le moteur pour un quart d'heure sans qu'on l'ait demandé.
 */
@Composable
private fun ResumeBanner(played: Int, total: Int, onResume: () -> Unit, onDiscard: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(com.chesslab.ui.ControlShape)
            .background(Palette.surfaceElevated)
            .border(1.dp, Palette.accent.copy(alpha = 0.45f), com.chesslab.ui.ControlShape)
            .padding(14.dp)
            .testTag("reprendre-serie"),
    ) {
        Text(
            stringResource(R.string.lab_resume_title), fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
        )
        Spacer(Modifier.height(2.dp))
        Text(
            stringResource(R.string.lab_resume_body, played, total),
            fontSize = 12.sp, color = Palette.textSecondary,
        )
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            SmallPill(stringResource(R.string.lab_resume), "reprendre", onResume)
            SmallPill(stringResource(R.string.lab_resume_discard), "recommencer", onDiscard)
        }
    }
}

/**
 * Les réglages de la SÉRIE : sa longueur, l'alternance des couleurs, ce qu'on
 * autorise pour l'abréger, le rythme d'affichage.
 *
 * Ils sont grisés pendant qu'elle tourne : changer la longueur ou le niveau au
 * milieu d'un bilan le fausserait, et un bilan faux ne se voit pas.
 */
@Composable
private fun SeriesSettings(ui: LabUiState, model: LabViewModel) {
    val enabled = !ui.running
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        com.chesslab.ui.SectionHeader(stringResource(R.string.lab_series_section))
        Spacer(Modifier.height(4.dp))
        Stepper(stringResource(R.string.lab_games), ui.gameCount, 1..500, 5, "nombre-parties", enabled) {
            model.setGameCount(it)
        }
        Stepper(stringResource(R.string.lab_level_a), ui.sideA.level.toInt(), 800..3190, 100, "niveau-a", enabled) {
            model.setLevelA(it.toDouble())
        }
        Stepper(stringResource(R.string.lab_level_b), ui.sideB.level.toInt(), 800..3190, 100, "niveau-b", enabled) {
            model.setLevelB(it.toDouble())
        }
        Toggle(stringResource(R.string.lab_alternate), ui.alternateColors, "alterner", enabled, model::setAlternateColors)
        Toggle(stringResource(R.string.lab_resign_allowed), ui.resignationEnabled, "abandon", enabled, model::setResignation)
        Toggle(stringResource(R.string.lab_draw_allowed), ui.drawAgreementEnabled, "nulle", enabled, model::setDrawAgreement)
        // Les nulles selon les RÈGLES restent déclarées quoi qu'on coche : le
        // réglage ne porte que sur la nulle par accord.
        Text(
            stringResource(R.string.lab_draw_rules_note),
            fontSize = 11.sp, color = Palette.textTertiary,
        )
        Toggle(stringResource(R.string.lab_animate), ui.liveVisualization, "animer", enabled, model::setLiveVisualization)

        Spacer(Modifier.height(10.dp))
        AdvancedSettings(ui, model, enabled)
    }
}

/**
 * Les réglages AVANCÉS : le temps de réflexion, le livre d'ouvertures, la mise
 * en veille. Pendant de la section du même nom de `LabSetupView`.
 *
 * Le temps est un curseur et non un incrémenteur : de 50 ms à 5 s, on ne
 * parcourt pas cette plage en tapant cinquante fois sur « + ». Et il porte sa
 * NOTE : les Elo de Stockfish sont calibrés à deux ou trois secondes par coup,
 * un chiffre qu'on ne devine pas et qui rend les étiquettes honnêtes.
 */
@Composable
private fun AdvancedSettings(ui: LabUiState, model: LabViewModel, enabled: Boolean) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        com.chesslab.ui.SectionHeader(stringResource(R.string.lab_advanced_section))
        Spacer(Modifier.height(4.dp))

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                stringResource(R.string.lab_movetime), fontSize = 13.sp,
                color = if (enabled) Palette.textPrimary else Palette.textTertiary,
                modifier = Modifier.weight(1f),
            )
            Text(
                if (ui.movetimeMs >= 1_000) "%.1f s".format(ui.movetimeMs / 1000.0)
                else "${ui.movetimeMs} ms",
                fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                color = Palette.textSecondary,
                modifier = Modifier.testTag("temps-coup"),
            )
        }
        androidx.compose.material3.Slider(
            value = ui.movetimeMs.toFloat(),
            onValueChange = { model.setMovetime((it / 50).toInt() * 50) },
            valueRange = 50f..5_000f,
            steps = 98,
            enabled = enabled,
            modifier = Modifier.testTag("curseur-temps"),
        )
        Text(
            stringResource(R.string.lab_movetime_note),
            fontSize = 11.sp, color = Palette.textTertiary,
        )
        if (ui.shortTimeWarning) {
            Text(
                stringResource(R.string.lab_short_time_warning),
                fontSize = 11.sp, color = Palette.warning,
                modifier = Modifier.testTag("avertissement-temps"),
            )
        }

        Spacer(Modifier.height(6.dp))
        Text(
            stringResource(R.string.lab_book_section), fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold, color = Palette.textSecondary,
        )
        Toggle(stringResource(R.string.lab_book_a), ui.bookA, "livre-a", enabled, model::setBookA)
        Toggle(stringResource(R.string.lab_book_b), ui.bookB, "livre-b", enabled, model::setBookB)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(
                com.chesslab.play.BookWidth.mainLinesOnly to R.string.setup_book_main,
                com.chesslab.play.BookWidth.includeSidelines to R.string.setup_book_sidelines,
            ).forEach { (width, label) ->
                com.chesslab.ui.ChipButton(
                    stringResource(label), ui.bookWidth == width,
                    Modifier.testTag("livre-${width.name}"),
                ) { if (enabled) model.setBookWidth(width) }
            }
        }
        Text(
            stringResource(R.string.lab_book_note),
            fontSize = 11.sp, color = Palette.textTertiary,
        )

        Spacer(Modifier.height(6.dp))
        Toggle(stringResource(R.string.lab_keep_awake), ui.keepAwake, "eveil", enabled, model::setKeepAwake)
        Text(
            stringResource(R.string.lab_keep_awake_note),
            fontSize = 11.sp, color = Palette.textTertiary,
        )
    }
}

/** Un nombre qu'on règle à la main, entre deux bornes. */
@Composable
private fun Stepper(
    title: String,
    value: Int,
    range: IntRange,
    step: Int,
    tag: String,
    enabled: Boolean,
    onChange: (Int) -> Unit,
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            title, fontSize = 13.sp,
            color = if (enabled) Palette.textPrimary else Palette.textTertiary,
            modifier = Modifier.weight(1f),
        )
        listOf("−" to -step, "+" to step).forEach { (glyph, delta) ->
            Text(
                glyph, fontSize = 18.sp, fontWeight = FontWeight.Bold,
                color = if (enabled) Palette.accent else Palette.textTertiary,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(Palette.surfaceElevated)
                    .clickable(enabled = enabled) { onChange((value + delta).coerceIn(range)) }
                    .padding(horizontal = 14.dp, vertical = 4.dp)
                    .testTag("$tag-${if (delta < 0) "moins" else "plus"}"),
            )
            if (delta < 0) {
                Text(
                    "$value", fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                    color = if (enabled) Palette.textPrimary else Palette.textTertiary,
                    modifier = Modifier.padding(horizontal = 10.dp).testTag(tag),
                )
            }
        }
    }
}

@Composable
private fun Toggle(
    label: String,
    checked: Boolean,
    tag: String,
    enabled: Boolean,
    onChange: (Boolean) -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(CircleShape)
            .clickable(enabled = enabled) { onChange(!checked) }
            .padding(vertical = 2.dp)
            .testTag(tag),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        androidx.compose.material3.Switch(
            checked = checked, onCheckedChange = { onChange(it) }, enabled = enabled,
        )
        Spacer(Modifier.width(10.dp))
        Text(
            label, fontSize = 13.sp,
            color = if (enabled) Palette.textPrimary else Palette.textTertiary,
        )
    }
}

/**
 * Le champ qui impose la position de départ. Un FEN ou un PGN — un PGN fait
 * partir la série de sa position FINALE, ce qui permet de tester une ouverture
 * qu'on vient de coller sans en recopier la position.
 */
@Composable
private fun StartPositionField(
    ui: LabUiState,
    onResolve: (String) -> Unit,
    onClear: () -> Unit,
) {
    var text by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var note by remember { mutableStateOf<String?>(null) }
    val unreadable = stringResource(R.string.lab_start_unreadable)
    val fromPgn = stringResource(R.string.lab_start_from_pgn, 0)

    Column(Modifier.fillMaxWidth()) {
        Text(
            stringResource(R.string.lab_start_position),
            fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary,
        )
        Spacer(Modifier.height(2.dp))
        Text(
            stringResource(R.string.lab_start_position_sub),
            fontSize = 10.sp, color = Palette.textTertiary,
        )
        Spacer(Modifier.height(6.dp))
        OutlinedTextField(
            value = text,
            onValueChange = { text = it; error = null },
            modifier = Modifier.fillMaxWidth().heightIn(min = 72.dp).testTag("position-depart"),
            textStyle = androidx.compose.ui.text.TextStyle(
                fontSize = 11.sp,
                fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                color = Palette.textPrimary,
            ),
        )
        error?.let {
            Text(it, fontSize = 11.sp, color = Palette.danger, modifier = Modifier.padding(top = 4.dp))
        }
        note?.let {
            Text(it, fontSize = 11.sp, color = Palette.textTertiary, modifier = Modifier.padding(top = 4.dp))
        }
        Spacer(Modifier.height(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SmallPill(stringResource(R.string.lab_start_position), "poser-position") {
                val resolved = LabStartPosition.resolve(text)
                if (resolved == null) { error = unreadable; note = null; return@SmallPill }
                error = null
                note = if (resolved.fromPgn) fromPgn.replace("0", "${resolved.plies}") else null
                onResolve(resolved.fen)
            }
            if (ui.startFen != null) {
                SmallPill(stringResource(R.string.lab_start_standard), "position-standard") {
                    text = ""; error = null; note = null; onClear()
                }
            }
        }
    }
}

/** Exporter la série : le PGN de toutes les parties, ou le CSV des résultats. */
@Composable
private fun ExportRow(model: LabViewModel) {
    val context = LocalContext.current
    val clipboard = LocalClipboardManager.current
    val chooserTitle = stringResource(R.string.lab_export)

    fun send(text: String) {
        if (text.isEmpty()) return
        // Le presse-papiers EN PLUS du partage, comme pour l'analyse : la
        // feuille de partage dépend des apps installées, le presse-papiers non.
        clipboard.setText(AnnotatedString(text))
        val intent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(android.content.Intent.EXTRA_TEXT, text)
        }
        runCatching { context.startActivity(android.content.Intent.createChooser(intent, chooserTitle)) }
    }

    Column {
        Text(
            stringResource(R.string.lab_export),
            fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary,
        )
        Spacer(Modifier.height(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SmallPill(stringResource(R.string.lab_export_pgn), "export-pgn") { send(model.exportPgn()) }
            SmallPill(stringResource(R.string.lab_export_csv), "export-csv") { send(model.exportCsv()) }
        }
    }
}

@Composable
private fun SmallPill(label: String, tag: String, onClick: () -> Unit) {
    Text(
        label,
        fontSize = 12.sp, fontWeight = FontWeight.Medium, color = Palette.textPrimary,
        modifier = Modifier
            .clip(CircleShape)
            .background(Palette.surfaceElevated)
            .border(1.dp, Palette.stroke, CircleShape)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .testTag(tag),
    )
}

@Composable
private fun Scoreboard(ui: LabUiState) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Palette.surface)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                "${ui.winsA} — ${ui.draws} — ${ui.winsB}",
                fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
                modifier = Modifier.testTag("bilan"),
            )
            // Ces trois libellés étaient écrits EN DUR, donc en français au
            // milieu d'un écran anglais. Les ressources existaient déjà.
            Text(
                stringResource(R.string.lab_game_number, ui.gameNumber + 1) + " · " +
                    stringResource(if (ui.aPlaysWhite) R.string.lab_a_white else R.string.lab_a_black),
                fontSize = 11.sp, color = Palette.textTertiary,
            )
        }
        Text(stringResource(R.string.lab_legend), fontSize = 11.sp, color = Palette.textSecondary)
    }
}

@Composable
private fun SidePicker(label: String, selected: OpponentProfile?, tag: String, onPick: (OpponentProfile?) -> Unit) {
    Column {
        Text(label, fontSize = 11.sp, color = Palette.textTertiary)
        Row(
            Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Chip(stringResource(R.string.stockfish), selected == null, "camp-$tag-stockfish") { onPick(null) }
            OpponentGallery.all.forEach { profile ->
                Chip(profile.firstName, profile.id == selected?.id, "camp-$tag-${profile.id}") { onPick(profile) }
            }
        }
    }
}

@Composable
private fun Chip(label: String, active: Boolean, tag: String, onClick: () -> Unit) {
    Text(
        label,
        fontSize = 11.sp,
        color = if (active) Palette.background else Palette.textSecondary,
        modifier = Modifier
            .testTag(tag)
            .clip(RoundedCornerShape(12.dp))
            .background(if (active) Palette.accent else Palette.surface)
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 5.dp),
    )
}
