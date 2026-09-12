package com.chesslab.analysis

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import chesskit.Piece
import chesskit.Square
import com.chesslab.R
import com.chesslab.ui.BoardArrow
import com.chesslab.ui.BoardScaffold
import com.chesslab.ui.BoardView
import com.chesslab.ui.CardShape
import com.chesslab.ui.ControlShape
import com.chesslab.ui.sanText
import com.chesslab.ui.MoveStrip
import com.chesslab.ui.Palette
import com.chesslab.ui.QuickSwitchMenu
import com.chesslab.ui.StatusRow
import com.chesslab.ui.TopBarActions
import com.chesslab.ui.accentGradient
import com.chesslab.ui.subtleBorder

/**
 * L'écran d'analyse. Pendant d'`AnalysisView` (disposition iPhone).
 *
 * L'ordre vient d'iOS et il a ses raisons : l'ouverture nomme ce qu'on
 * regarde, le plateau porte les flèches, la barre d'éval donne le verdict
 * chiffré, la navigation permet d'avancer, les candidats montrent les
 * alternatives, et le bandeau coach dit ce qui vient de se passer. Le panneau
 * — courbe, coups, bilan — vient après.
 */
@Composable
fun AnalysisScreen(
    initialFen: String? = null,
    initialPgn: String? = null,
    onPlayVsEngine: (String) -> Unit = {},
    onOpenLab: (String) -> Unit = {},
    model: AnalysisViewModel = viewModel(),
) {
    LaunchedEffect(initialFen, initialPgn) {
        val incoming = initialFen?.takeIf { it.isNotBlank() } ?: initialPgn?.takeIf { it.isNotBlank() }
        if (incoming != null) { model.onInputChange(incoming); model.load() }
    }
    val ui = model.ui
    val context = LocalContext.current
    val clipboard = LocalClipboardManager.current
    var showSummary by remember { mutableStateOf(false) }
    var toast by remember { mutableStateOf<String?>(null) }

    TopBarActions {
        QuickSwitchMenu(
            onPlayVsEngine = { onPlayVsEngine(model.ui.position.fen) },
            onOpenLab = { onOpenLab(model.ui.position.fen) },
        )
        OverflowMenu(
            onSummary = { showSummary = true },
            onExport = {
                val pgn = model.pgn()
                if (pgn.isNotEmpty()) {
                    // Le presse-papiers EN PLUS du partage : la feuille de
                    // partage dépend des apps installées, et sur un appareil
                    // qui n'en propose aucune il ne resterait rien. Le PGN est
                    // du texte, il tient toujours dans le presse-papiers.
                    clipboard.setText(AnnotatedString(pgn))
                    val send = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(android.content.Intent.EXTRA_TEXT, pgn)
                    }
                    runCatching {
                        context.startActivity(
                            android.content.Intent.createChooser(
                                send, context.getString(R.string.analysis_export_pgn)
                            )
                        )
                    }.onFailure { toast = context.getString(R.string.analysis_copied) }
                }
            },
            onFlip = model::flip,
            onPuzzles = model::generatePuzzles,
            canMakePuzzles = ui.summary != null && !ui.reviewing,
            arrowMode = ui.arrowMode,
            onArrowMode = model::setArrowMode,
        )
    }

    BoardScaffold(
        header = {
            OpeningHeader(ui)
            StatusRow(ui.status, busy = ui.thinking)
            Spacer(Modifier.height(8.dp))
        },
        board = {
            BoardView(
                position = ui.position,
                orientation = ui.orientation,
                lastMove = ui.lastMove,
                checkedKing = ui.checkedKing,
                arrows = arrowsFor(ui),
                enabled = false,
            )
        },
        panel = {
            Spacer(Modifier.height(10.dp))
            EvaluationBar(ui)

            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = model::previous, modifier = Modifier.testTag("precedent")) {
                    Icon(Icons.Default.ChevronLeft, stringResource(R.string.previous_move), tint = Palette.textPrimary)
                }
                IconButton(onClick = model::next, modifier = Modifier.testTag("suivant")) {
                    Icon(Icons.Default.ChevronRight, stringResource(R.string.next_move), tint = Palette.textPrimary)
                }
                Spacer(Modifier.width(8.dp))
                Box(Modifier.weight(1f)) {
                    MoveStrip(
                        ui.sanMoves,
                        selected = ui.cursor.takeIf { it >= 0 },
                        qualities = ui.qualities,
                        onSelect = model::goTo,
                    )
                }
            }

            CandidatesBar(ui, model::playCandidate)
            CoachBar(ui)

            if (ui.sanMoves.isNotEmpty()) {
                Spacer(Modifier.height(12.dp))
                ReviewBar(ui, model::review) { showSummary = true }
            }

            if (ui.curve.size > 1) {
                Spacer(Modifier.height(10.dp))
                EvalCurve(ui.curve, currentPly = ui.cursor + 1, onSelect = model::goTo)
            }

            Spacer(Modifier.height(12.dp))
            SavedGames(model)

            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = ui.input,
                onValueChange = model::onInputChange,
                label = { Text(stringResource(R.string.analysis_input_label)) },
                modifier = Modifier.fillMaxWidth().heightIn(min = 96.dp).testTag("saisie"),
                textStyle = androidx.compose.ui.text.TextStyle(fontSize = 12.sp, fontFamily = FontFamily.Monospace),
            )
            if (ui.error != null) {
                Text(ui.error!!, color = Palette.danger, fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp))
            }
            TextButton(onClick = model::load, modifier = Modifier.testTag("charger")) {
                Text(stringResource(R.string.analysis_load), color = Palette.accent)
            }
        },
    )

    if (showSummary) GameSummarySheet(ui) { showSummary = false }
    ui.puzzlesCreated?.let { count ->
        AlertDialog(
            onDismissRequest = model::clearPuzzleNotice,
            confirmButton = {
                TextButton(onClick = model::clearPuzzleNotice) { Text("OK", color = Palette.accent) }
            },
            text = {
                Text(
                    if (count == 0) stringResource(R.string.analysis_no_puzzles)
                    else pluralStringResource(R.plurals.analysis_puzzles_created, count, count),
                    color = Palette.textPrimary,
                    modifier = Modifier.testTag("puzzles-crees"),
                )
            },
            containerColor = Palette.surfaceElevated,
        )
    }
    toast?.let { message ->
        AlertDialog(
            onDismissRequest = { toast = null },
            confirmButton = { TextButton(onClick = { toast = null }) { Text("OK", color = Palette.accent) } },
            text = { Text(message, color = Palette.textPrimary) },
            containerColor = Palette.surfaceElevated,
        )
    }
}

/**
 * Les flèches du moteur sur la position affichée. « Aucune » sert à revoir une
 * partie sans être soufflé ; « Trois » à comparer des candidats. Le défaut ne
 * montre que le meilleur coup — trois flèches en permanence, c'est la solution
 * affichée en continu, et plus rien n'invite à chercher.
 */
private fun arrowsFor(ui: AnalysisUiState): List<BoardArrow> {
    // « Aucune » coupe TOUT, menace comprise : c'est le réglage de celui qui
    // revoit sa partie sans vouloir être soufflé.
    val kept = when (ui.arrowMode) {
        ArrowMode.none -> return emptyList()
        ArrowMode.best -> ui.candidates.take(1)
        ArrowMode.three -> ui.candidates
    }
    val arrows = kept.mapNotNull { candidate ->
        if (candidate.lan.length < 4) return@mapNotNull null
        BoardArrow(
            from = Square(candidate.lan.substring(0, 2)),
            to = Square(candidate.lan.substring(2, 4)),
            tint = Palette.accent,
            // Le rang fait l'épaisseur : le coup recommandé est le plus marqué.
            strength = when (candidate.rank) { 1 -> 1f; 2 -> 0.6f; else -> 0.35f },
        )
    }.toMutableList()

    // Ce que l'ADVERSAIRE ferait si on lui laissait la main : en rouge, la
    // couleur de ce qui menace.
    ui.threat?.let { arrows += BoardArrow(it.first, it.second, Palette.danger, 0.7f) }

    // « Il fallait jouer ça » : la seule flèche qui porte sur la position
    // PRÉCÉDENTE. Pleinement marquée — c'est l'information la plus utile de
    // l'écran quand elle apparaît.
    ui.betterMove?.let { arrows += BoardArrow(it.first, it.second, Palette.violet, 1f) }
    return arrows
}

@Composable
private fun OverflowMenu(
    onSummary: () -> Unit,
    onExport: () -> Unit,
    onFlip: () -> Unit,
    onPuzzles: () -> Unit,
    /** Il n'y a de puzzles à tirer qu'une fois les fautes connues. */
    canMakePuzzles: Boolean,
    arrowMode: ArrowMode,
    onArrowMode: (ArrowMode) -> Unit,
) {
    var open by remember { mutableStateOf(false) }
    IconButton(onClick = { open = true }, modifier = Modifier.testTag("menu-analyse")) {
        Icon(Icons.Default.MoreVert, stringResource(R.string.analysis_summary), tint = Palette.textPrimary)
    }
    DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
        DropdownMenuItem(
            text = { Text(stringResource(R.string.analysis_summary), color = Palette.textPrimary) },
            onClick = { open = false; onSummary() },
            modifier = Modifier.testTag("bilan"),
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.analysis_export_pgn), color = Palette.textPrimary) },
            onClick = { open = false; onExport() },
            modifier = Modifier.testTag("exporter-pgn"),
        )
        DropdownMenuItem(
            text = {
                Text(
                    stringResource(R.string.analysis_make_puzzles),
                    color = if (canMakePuzzles) Palette.textPrimary else Palette.textTertiary,
                )
            },
            enabled = canMakePuzzles,
            onClick = { open = false; onPuzzles() },
            modifier = Modifier.testTag("creer-puzzles"),
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.analysis_flip), color = Palette.textPrimary) },
            onClick = { open = false; onFlip() },
            modifier = Modifier.testTag("retourner"),
        )
        HorizontalDivider(color = Palette.stroke)
        Text(
            stringResource(R.string.analysis_arrows),
            fontSize = 11.sp, color = Palette.textTertiary,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
        )
        ArrowMode.entries.forEach { mode ->
            DropdownMenuItem(
                text = {
                    Text(
                        stringResource(mode.labelRes),
                        color = if (mode == arrowMode) Palette.accent else Palette.textPrimary,
                    )
                },
                onClick = { open = false; onArrowMode(mode) },
                modifier = Modifier.testTag("fleches-${mode.name}"),
            )
        }
    }
}

/** Le code ECO et le nom de l'ouverture, quand la ligne jouée le confirme. */
@Composable
private fun OpeningHeader(ui: AnalysisUiState) {
    val opening = ui.opening ?: return
    val french = java.util.Locale.getDefault().language == "fr"
    Row(
        Modifier.fillMaxWidth().padding(bottom = 6.dp).testTag("ouverture"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (opening.eco.isNotEmpty()) {
            Text(
                opening.eco,
                fontSize = 10.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace,
                color = Palette.background,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(accentGradient)
                    .padding(horizontal = 7.dp, vertical = 3.dp),
            )
            Spacer(Modifier.width(8.dp))
        }
        Text(
            opening.displayName(french),
            fontSize = 12.sp, color = Palette.textSecondary, maxLines = 1,
        )
    }
}

/** Les trois meilleurs coups du moteur, jouables d'un tap. */
@Composable
private fun CandidatesBar(ui: AnalysisUiState, onPlay: (Candidate) -> Unit) {
    if (ui.candidates.isEmpty()) return
    Spacer(Modifier.height(8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        ui.candidates.forEach { candidate ->
            Row(
                Modifier
                    .clip(CircleShape)
                    .background(
                        if (candidate.rank == 1) Palette.accent.copy(alpha = 0.16f) else Palette.surface
                    )
                    .border(
                        1.dp,
                        if (candidate.rank == 1) Palette.accent.copy(alpha = 0.5f) else Palette.stroke,
                        CircleShape,
                    )
                    .clickable { onPlay(candidate) }
                    .padding(horizontal = 10.dp, vertical = 7.dp)
                    .testTag("candidat-${candidate.rank}"),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    sanText(candidate.san),
                    fontSize = 14.sp,
                    fontWeight = if (candidate.rank == 1) FontWeight.Bold else FontWeight.Medium,
                    color = Palette.textPrimary,
                )
                Text(
                    candidate.eval,
                    fontSize = 11.sp, fontFamily = FontFamily.Monospace, color = Palette.textSecondary,
                )
            }
        }
    }
}

/**
 * « e5 — Erreur, −12 % », et en dessous CE QUI punit le coup. Sans la seconde
 * ligne, on apprend qu'on a eu tort sans apprendre ce qu'on n'a pas vu — et on
 * rejoue le même coup.
 */
@Composable
private fun CoachBar(ui: AnalysisUiState) {
    val quality = ui.displayedQuality ?: return
    val san = ui.sanMoves.getOrNull(ui.cursor) ?: return
    val context = LocalContext.current

    Spacer(Modifier.height(8.dp))
    Column(
        Modifier
            .fillMaxWidth()
            .clip(ControlShape)
            .background(Palette.surface)
            .border(1.dp, quality.tint.copy(alpha = 0.45f), ControlShape)
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .testTag("coach"),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            QualityBadge(quality)
            Text(
                sanText(san),
                fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary,
            )
            Text(
                stringResource(quality.labelRes),
                fontSize = 14.sp, fontWeight = FontWeight.Bold, color = quality.tint, maxLines = 1,
            )
            Spacer(Modifier.weight(1f))
            // Le meilleur coup n'est pas rappelé en toutes lettres : la flèche
            // sur le plateau le montre déjà. À la place, ce que le coup a coûté.
            ui.displayedWinDelta?.let { delta ->
                Text(
                    (if (delta >= 0) "+%.0f %%" else "−%.0f %%").format(kotlin.math.abs(delta)),
                    fontSize = 12.sp, fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.Monospace,
                    color = if (delta >= -1) Palette.accent else quality.tint,
                    modifier = Modifier.testTag("ecart"),
                )
            }
        }
        ui.displayedExplanation?.let { explanation ->
            Text(
                explanation.sentence(context),
                fontSize = 12.sp, color = Palette.textPrimary, maxLines = 2,
                modifier = Modifier.testTag("explication"),
            )
        }
    }
}

/** La pastille ronde qui porte le signe de la catégorie. */
@Composable
private fun QualityBadge(quality: MoveQuality, size: androidx.compose.ui.unit.Dp = 26.dp) {
    Box(
        Modifier.size(size).clip(CircleShape).background(quality.tint),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            quality.symbol ?: "",
            fontSize = (size.value * 0.42f).sp,
            fontWeight = FontWeight.Black,
            color = androidx.compose.ui.graphics.Color.White,
            maxLines = 1,
        )
    }
}

/** Lancer la revue complète, et rouvrir son bilan. */
@Composable
private fun ReviewBar(ui: AnalysisUiState, onReview: () -> Unit, onSummary: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(ControlShape)
            .background(Palette.surfaceElevated)
            .subtleBorder(ControlShape)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (ui.reviewing) {
            // Une jauge DÉTERMINÉE et non un compteur qui tourne : on sait
            // exactement où en est la revue, et le dire vaut mieux que de faire
            // patienter. (Un indicateur indéterminé anime sans fin, ce qui
            // empêche aussi les tests d'interface de se déclarer au repos.)
            Column(Modifier.weight(1f)) {
                Text(
                    stringResource(R.string.analysis_reviewing, ui.reviewDone, ui.reviewTotal),
                    fontSize = 13.sp, color = Palette.textSecondary,
                    modifier = Modifier.testTag("revue-en-cours"),
                )
                Spacer(Modifier.height(6.dp))
                LinearProgressIndicator(
                    progress = {
                        if (ui.reviewTotal == 0) 0f
                        else ui.reviewDone.toFloat() / ui.reviewTotal
                    },
                    color = Palette.accent,
                    trackColor = Palette.surface,
                    drawStopIndicator = {},
                    modifier = Modifier.fillMaxWidth().height(4.dp).clip(CircleShape),
                )
            }
        } else {
            val summary = ui.summary
            if (summary == null) {
                Text(
                    stringResource(R.string.analysis_review_hint),
                    fontSize = 12.sp, color = Palette.textSecondary, modifier = Modifier.weight(1f),
                )
            } else {
                AccuracyPair(summary, Modifier.weight(1f))
            }
            Text(
                stringResource(if (ui.summary == null) R.string.analysis_review else R.string.analysis_summary),
                fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(accentGradient)
                    .clickable { if (ui.summary == null) onReview() else onSummary() }
                    .padding(horizontal = 14.dp, vertical = 7.dp)
                    .testTag("analyser-partie"),
            )
        }
    }
}

/** Les deux précisions côte à côte : c'est le chiffre qu'on cherche d'abord. */
@Composable
private fun AccuracyPair(summary: GameSummary, modifier: Modifier = Modifier) {
    Row(modifier.testTag("precision"), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        listOf(
            R.string.analysis_white to summary.white,
            R.string.analysis_black to summary.black,
        ).forEach { (label, side) ->
            Column {
                Text(stringResource(label), fontSize = 10.sp, color = Palette.textTertiary)
                Text(
                    side.accuracy?.let { "%.1f %%".format(it) } ?: "—",
                    fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                    fontFamily = FontFamily.Monospace, color = Palette.accent,
                )
            }
        }
    }
}

/** Le bilan : précision et décompte par catégorie, pour chaque camp. */
@Composable
private fun GameSummarySheet(ui: AnalysisUiState, onDismiss: () -> Unit) {
    val summary = ui.summary
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text("OK", color = Palette.accent) } },
        title = { Text(stringResource(R.string.analysis_summary), color = Palette.textPrimary) },
        containerColor = Palette.surfaceElevated,
        text = {
            if (summary == null) {
                Text(stringResource(R.string.analysis_no_review), color = Palette.textSecondary)
            } else {
                Column(Modifier.testTag("feuille-bilan")) {
                    AccuracyPair(summary)
                    Spacer(Modifier.height(12.dp))
                    // Les catégories dans l'ordre de l'échelle, du meilleur au
                    // pire : le regard descend, et le bas de la colonne est ce
                    // qu'il y a à travailler.
                    MoveQuality.entries.forEach { quality ->
                        val w = summary.white.count(quality)
                        val b = summary.black.count(quality)
                        if (w == 0 && b == 0) return@forEach
                        Row(
                            Modifier.fillMaxWidth().padding(vertical = 2.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            QualityBadge(quality, 20.dp)
                            Spacer(Modifier.width(8.dp))
                            Text(
                                stringResource(quality.labelRes),
                                fontSize = 12.sp, color = Palette.textPrimary, modifier = Modifier.weight(1f),
                            )
                            Text("$w", fontSize = 13.sp, fontFamily = FontFamily.Monospace, color = Palette.textPrimary)
                            Spacer(Modifier.width(18.dp))
                            Text("$b", fontSize = 13.sp, fontFamily = FontFamily.Monospace, color = Palette.textPrimary)
                        }
                    }
                    Spacer(Modifier.height(10.dp))
                    Text(
                        stringResource(R.string.analysis_moves_counted, summary.white.classifiedCount + summary.black.classifiedCount),
                        fontSize = 11.sp, color = Palette.textTertiary,
                    )
                    val book = summary.white.bookCount + summary.black.bookCount
                    if (book > 0) {
                        Text(
                            stringResource(R.string.analysis_book_moves, book),
                            fontSize = 11.sp, color = Palette.textTertiary,
                        )
                    }
                }
            }
        },
    )
}

/** La bibliothèque : les parties déjà jouées, rechargeables d'un tap. */
@Composable
private fun SavedGames(model: AnalysisViewModel) {
    val games by model.savedGames.collectAsState(initial = emptyList())
    if (games.isEmpty()) return

    Text(stringResource(R.string.analysis_library), fontSize = 12.sp, color = Palette.textTertiary)
    Spacer(Modifier.height(4.dp))
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        games.take(8).forEach { record ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .testTag("partie-${record.id}")
                    .clip(RoundedCornerShape(8.dp))
                    .background(Palette.surface)
                    .clickable { model.open(record) }
                    .padding(horizontal = 10.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "${record.white} — ${record.black}",
                    fontSize = 12.sp, color = Palette.textPrimary, modifier = Modifier.weight(1f),
                )
                Text(record.result, fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = Palette.accent)
                Spacer(Modifier.width(8.dp))
                Text(
                    pluralStringResource(R.plurals.analysis_move_count, record.moveCount, record.moveCount),
                    fontSize = 10.sp, color = Palette.textTertiary,
                )
            }
        }
    }
}

/**
 * La barre d'évaluation : le verdict chiffré, et la part du plateau que chaque
 * camp occupe. Le remplissage dit d'un coup d'œil qui mène, sans lire le
 * chiffre — c'est ce que fait `EvalBarView` sur iOS.
 */
@Composable
private fun EvaluationBar(ui: AnalysisUiState) {
    // Probabilité de gain des Blancs, bornée pour rester lisible aux extrêmes.
    val share = when {
        ui.evalMate != null -> if (ui.evalMate > 0) 1f else 0f
        ui.evalCp != null -> (EvalConversion.fromCentipawns(ui.evalCp) / 100).toFloat()
        else -> 0.5f
    }.coerceIn(0.03f, 0.97f)

    Column(Modifier.fillMaxWidth()) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(8.dp)
                .clip(CircleShape)
                .background(Palette.info.copy(alpha = 0.55f))
                .testTag("barre-eval")
        ) {
            Box(Modifier.fillMaxWidth(share).fillMaxHeight().background(Palette.accent))
        }
        Spacer(Modifier.height(8.dp))
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(Palette.surface)
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                ui.evaluation.ifEmpty { "—" },
                fontSize = 20.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = FontFamily.Monospace,
                color = when {
                    ui.evaluation.startsWith("+") -> Palette.accent
                    ui.evaluation.startsWith("−") -> Palette.danger
                    else -> Palette.textTertiary
                },
                modifier = Modifier.testTag("evaluation"),
            )
            Spacer(Modifier.width(12.dp))
            Column {
                if (ui.depth > 0) {
                    Text(
                        stringResource(R.string.analysis_depth, ui.depth),
                        fontSize = 11.sp, color = Palette.textTertiary,
                    )
                }
                if (ui.bestLine.isNotEmpty()) {
                    Text(
                        ui.bestLine.split(" ").take(6).joinToString(" "),
                        fontSize = 11.sp,
                        fontFamily = FontFamily.Monospace,
                        color = Palette.textSecondary,
                        maxLines = 1,
                    )
                }
            }
        }
    }
}
