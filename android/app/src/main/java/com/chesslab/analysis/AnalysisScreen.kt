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
import androidx.compose.ui.semantics.semantics
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
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.FirstPage
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import com.chesslab.ui.BoardView
import com.chesslab.ui.CardShape
import com.chesslab.ui.ControlShape
import com.chesslab.ui.sanText
import com.chesslab.ui.MoveStrip
import kotlin.math.max
import com.chesslab.ui.HintArrowBuilder
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

    // L'écran qui s'en va arrête ce qui tourne pour lui : la lecture
    // automatique et l'analyse en continu. Sans cela le moteur restait à
    // plein régime derrière un autre écran.
    val owner = androidx.lifecycle.compose.LocalLifecycleOwner.current
    DisposableEffect(owner) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            when (event) {
                androidx.lifecycle.Lifecycle.Event.ON_PAUSE -> model.handleViewDisappear()
                androidx.lifecycle.Lifecycle.Event.ON_RESUME -> model.handleViewAppear()
                else -> Unit
            }
        }
        owner.lifecycle.addObserver(observer)
        onDispose {
            owner.lifecycle.removeObserver(observer)
            model.handleViewDisappear()
        }
    }

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
            com.chesslab.ui.ThermalBadge()
            if (ui.engineUnavailable) {
                EngineBanner(ui.retryingEngine, onRetry = { model.retryEngine() })
                Spacer(Modifier.height(6.dp))
            }
            OpeningHeader(ui)
            StatusRow(ui.status, busy = ui.thinking)
            Spacer(Modifier.height(6.dp))
            EngineStatusBadge(ui)
            Spacer(Modifier.height(8.dp))
        },
        board = {
            BoardView(
                position = ui.position,
                orientation = ui.orientation,
                selected = ui.selected,
                legalTargets = ui.legalTargets,
                lastMove = ui.lastMove,
                checkedKing = ui.checkedKing,
                arrows = arrowsFor(ui),
                qualityBadge = ui.qualityBadge,
                // Le plateau d'analyse SE JOUE : on y pose un coup pour voir
                // ce qu'il donne. Il était inerte, et la seule façon
                // d'explorer était de toucher une pastille de candidat — on
                // ne pouvait donc essayer que ce que le moteur proposait.
                draggableColor = ui.position.sideToMove,
                enabled = true,
                onSquareTap = model::selectSquare,
            )
        },
        panel = {
            Spacer(Modifier.height(10.dp))
            // La barre PARTAGÉE, celle d'iOS : le score s'écrit dedans. Cet
            // écran avait la sienne — un ruban vert et bleu de 8 dp, doublé
            // d'une carte qui répétait le chiffre, la profondeur et le début
            // de la variante. iOS n'a ni la carte ni la variante : les coups
            // du moteur sont dans la barre des candidats, juste dessous.
            com.chesslab.ui.EvalBar(cp = ui.evalCp, mate = ui.evalMate)

            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(
                    onClick = model::goToStart, enabled = ui.canGoPrevious,
                    modifier = Modifier.testTag("debut"),
                ) {
                    Icon(Icons.Default.FirstPage, stringResource(R.string.two_first_move), tint = Palette.textPrimary)
                }
                IconButton(onClick = model::previous, modifier = Modifier.testTag("precedent")) {
                    Icon(Icons.Default.ChevronLeft, stringResource(R.string.previous_move), tint = Palette.textPrimary)
                }
                IconButton(onClick = model::next, modifier = Modifier.testTag("suivant")) {
                    Icon(Icons.Default.ChevronRight, stringResource(R.string.next_move), tint = Palette.textPrimary)
                }
                // Lire la partie toute seule, un coup par seconde : c'est la
                // façon la plus simple de la REVOIR — on regarde le plateau,
                // pas les boutons.
                IconButton(
                    onClick = model::toggleAutoplay,
                    enabled = ui.canGoNext || ui.autoplaying,
                    modifier = Modifier.testTag("lecture"),
                ) {
                    Icon(
                        if (ui.autoplaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                        stringResource(if (ui.autoplaying) R.string.analysis_pause else R.string.analysis_play),
                        tint = if (ui.autoplaying) Palette.accent else Palette.textPrimary,
                    )
                }
                // Dérouler la meilleure ligne coup par coup depuis une
                // position (scan, FEN, éditeur) : l'action « intelligente »
                // de l'écran, donc teintée accent.
                IconButton(
                    onClick = model::playBestMove, enabled = ui.canPlayBestMove,
                    modifier = Modifier.testTag("meilleur-coup"),
                ) {
                    Icon(
                        Icons.Default.AutoAwesome,
                        stringResource(R.string.analysis_play_best),
                        tint = if (ui.canPlayBestMove) Palette.accent else Palette.textTertiary,
                    )
                }
                Spacer(Modifier.weight(1f))
                if (ui.reviewing) {
                    CircularProgressIndicator(
                        Modifier.size(12.dp), strokeWidth = 2.dp, color = Palette.textTertiary,
                    )
                    Spacer(Modifier.width(6.dp))
                    Text(
                        "${ui.reviewDone}/${ui.reviewTotal}",
                        fontSize = 11.sp, color = Palette.textTertiary,
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
                // La courbe rend un DEMI-COUP ; cet écran-ci compte les COUPS,
                // où −1 est la position de départ.
                EvalCurve(ui.curve, currentPly = ui.cursor + 1) { model.goTo(it - 1) }
            }

            if (ui.sanMoves.isNotEmpty()) {
                Spacer(Modifier.height(16.dp))
                Text(
                    stringResource(R.string.analysis_moves_played),
                    fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
                )
                Spacer(Modifier.height(8.dp))
            }
            // La bande PLEINE LARGEUR, en fin de panneau comme iOS. Elle était
            // coincée dans la rangée de navigation, à côté de cinq boutons :
            // deux capsules y tenaient.
            MoveStrip(
                ui.sanMoves,
                selected = ui.cursor.takeIf { it >= 0 },
                qualities = ui.qualities,
                onSelect = model::goTo,
            )

            // Ni liste de parties ni formulaire sur cet écran : la
            // BIBLIOTHÈQUE sait chercher, filtrer, étiqueter et supprimer, et
            // l'on COLLE avant d'analyser, pas après. Ne reste ici que
            // l'erreur, quand le texte reçu s'avère illisible.
            if (ui.error != null) {
                Spacer(Modifier.height(12.dp))
                Text(ui.error!!, color = Palette.danger, fontSize = 12.sp)
            }
        },
    )

    if (showSummary) GameSummarySheet(ui) { showSummary = false }

    // Le plateau se joue : une poussée de pion en 8e demande donc en quoi
    // promouvoir, ici comme ailleurs.
    if (ui.pendingPromotion != null) {
        com.chesslab.play.PromotionDialog(
            onPick = model::completePromotion,
            onCancel = model::cancelPromotion,
        )
    }
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
 *
 * **Deux régimes, et c'est la couleur qui les distingue.** En REVUE d'une
 * partie, les flèches sont VERTES et lues dans la classification déjà faite :
 * rien n'est recalculé en naviguant, et après une faute la rétrospective prime
 * — c'est le point d'apprentissage. En analyse d'une POSITION, elles sont
 * GRISES et viennent du moteur en continu. Une flèche verte dit « ce que le
 * camp au trait peut jouer ici », une rouge « ce que l'adversaire menace ».
 */
private fun arrowsFor(ui: AnalysisUiState): List<BoardArrow> {
    // « Aucune » coupe TOUT, menace comprise : c'est le réglage de celui qui
    // revoit sa partie sans vouloir être soufflé.
    if (ui.arrowMode == ArrowMode.none) return emptyList()

    val threat = ui.threat?.let {
        BoardArrow(it.first, it.second, HintArrowBuilder.threatTint, 1f)
    }
    // « Il fallait jouer ça » : la seule flèche qui porte sur la position
    // PRÉCÉDENTE. Vive et pleinement opaque.
    val better = ui.betterMove?.let {
        BoardArrow(it.first, it.second, HintArrowBuilder.betterTint, 1f)
    }

    ui.reviewEval?.let { cached ->
        // Après une faute, la rétrospective prime et reste SEULE : la flèche
        // verte porterait sur le coup de l'adversaire, ce qui se lit de
        // travers juste après s'être trompé.
        val green = if (better != null) listOf(better) else reviewArrows(cached, ui.arrowMode)
        return green + listOfNotNull(threat)
    }

    val live = when (ui.arrowMode) {
        ArrowMode.none -> emptyList()
        ArrowMode.best -> ui.candidates.take(1)
        ArrowMode.three -> ui.candidates
    }.mapNotNull { candidate ->
        if (candidate.lan.length < 4) return@mapNotNull null
        // Pas de force : le coup est trop loin du meilleur pour être suggéré.
        // Une position sans vraie alternative n'affiche donc qu'une ou deux
        // flèches, même en mode « Trois ».
        val strength = candidate.strength ?: return@mapNotNull null
        BoardArrow(
            from = Square(candidate.lan.substring(0, 2)),
            to = Square(candidate.lan.substring(2, 4)),
            tint = HintArrowBuilder.tint(strength),
            strength = strength.toFloat(),
        )
    }
    return live + listOfNotNull(threat, better)
}

/**
 * Les flèches VERTES d'une revue : le meilleur coup de la position affichée,
 * plus un second de taille voisine quand un autre coup est presque aussi bon
 * — « deux coups qui se valent ». Tout est lu dans l'évaluation en cache.
 */
private fun reviewArrows(cached: PositionEval, mode: ArrowMode): List<BoardArrow> {
    val best = cached.bestLan?.takeIf { it.length >= 4 } ?: return emptyList()
    val arrows = mutableListOf(reviewArrow(best, 1.0))
    val second = cached.secondBestLan?.takeIf { it.length >= 4 }
    val gap = cached.gapToSecondBest
    // En mode « Trois », dès qu'un 2e coup existe ; en mode « Meilleur »,
    // seulement s'il est PROCHE (≤ 4 points de %).
    if (second != null && gap != null && (mode == ArrowMode.three || gap <= 4.0)) {
        arrows += reviewArrow(second, max(0.6, 1 - gap / 12))
    }
    return arrows
}

private fun reviewArrow(lan: String, strength: Double) = BoardArrow(
    from = Square(lan.substring(0, 2)),
    to = Square(lan.substring(2, 4)),
    tint = HintArrowBuilder.reviewBestTint(strength),
    strength = strength.toFloat(),
)

/**
 * « L'ordinateur n'a pas démarré » — et de quoi retenter. Dans le flux : posée
 * par-dessus, elle recouvrirait la 8e rangée.
 */
@Composable
private fun EngineBanner(retrying: Boolean, onRetry: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(com.chesslab.ui.ControlShape)
            .background(Palette.danger.copy(alpha = 0.14f))
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .testTag("moteur-absent"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            stringResource(R.string.play_engine_down),
            fontSize = 12.sp, color = Palette.danger, modifier = Modifier.weight(1f),
        )
        if (retrying) {
            CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp, color = Palette.danger)
        } else {
            TextButton(onClick = onRetry, modifier = Modifier.testTag("moteur-reessayer")) {
                Text(stringResource(R.string.play_engine_retry), fontSize = 12.sp, color = Palette.danger)
            }
        }
    }
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
                // Sous un demi-point, le coup n'a RIEN coûté : « ≈ 0 % » le
                // dit, là où « −0 % » laissait croire à une perte. Mêmes
                // seuils et mêmes couleurs qu'iOS (`winDeltaLabel`).
                val négligeable = kotlin.math.abs(delta) < 0.5
                Text(
                    if (négligeable) "≈ 0 %"
                    else (if (delta > 0) "+" else "−") + "${kotlin.math.round(kotlin.math.abs(delta)).toInt()} %",
                    fontSize = 12.sp, fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.Monospace,
                    color = when {
                        négligeable -> Palette.textSecondary
                        delta > 0 -> Palette.accent
                        else -> quality.tint
                    },
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

/**
 * Les deux précisions côte à côte : c'est le chiffre qu'on cherche d'abord.
 *
 * Une précision calculée sur une PARTIE de la partie — revue interrompue,
 * reprise en cours — se dit telle quelle : chiffre en gris, suivi de « … ».
 * Affichée comme une précision définitive, elle mentait : une seule position
 * évaluée suffit à en produire une, et elle vaut alors 100 %.
 */
@Composable
private fun AccuracyPair(summary: GameSummary, modifier: Modifier = Modifier) {
    val tint = if (summary.isComplete) Palette.accent else Palette.textTertiary
    Row(
        modifier.testTag(if (summary.isComplete) "precision" else "precision-partielle"),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        listOf(
            R.string.analysis_white to summary.white,
            R.string.analysis_black to summary.black,
        ).forEach { (label, side) ->
            Column {
                Text(stringResource(label), fontSize = 10.sp, color = Palette.textTertiary)
                Text(
                    // ENTIÈRE et collée au signe, comme iOS : « 97% ». La
                    // décimale donnait une précision que le calcul n'a pas.
                    side.accuracy?.let {
                        "${kotlin.math.round(it).toInt()}%" + if (summary.isComplete) "" else " …"
                    } ?: "—",
                    fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                    fontFamily = FontFamily.Monospace, color = tint,
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
                    // L'ouverture jouée, en tête : c'est le premier repère
                    // qu'on cherche en rouvrant le bilan d'une partie.
                    ui.opening?.let { opening ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            if (opening.eco.isNotEmpty()) {
                                Text(
                                    opening.eco,
                                    fontSize = 10.sp, fontWeight = FontWeight.Bold,
                                    fontFamily = FontFamily.Monospace, color = Palette.background,
                                    modifier = Modifier
                                        .clip(CircleShape)
                                        .background(Palette.warning)
                                        .padding(horizontal = 6.dp, vertical = 2.dp),
                                )
                                Spacer(Modifier.width(6.dp))
                            }
                            Text(
                                opening.displayName(
                                    java.util.Locale.getDefault().language == "fr"
                                ),
                                fontSize = 12.sp, color = Palette.textSecondary,
                            )
                        }
                        Spacer(Modifier.height(10.dp))
                    }
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
                    // Un bilan PARTIEL le dit : sans cette ligne, un décompte
                    // en cours passe pour un décompte définitif.
                    if (!summary.isComplete) {
                        Spacer(Modifier.height(8.dp))
                        Text(
                            stringResource(R.string.analysis_summary_partial),
                            fontSize = 11.sp, color = Palette.warning,
                            modifier = Modifier.testTag("bilan-partiel"),
                        )
                    }
                }
            }
        },
    )
}

/**
 * La barre d'évaluation : le verdict chiffré, et la part du plateau que chaque
 * camp occupe. Le remplissage dit d'un coup d'œil qui mène, sans lire le
 * chiffre — c'est ce que fait `EvalBarView` sur iOS.
 */
@Composable
private fun EngineStatusBadge(ui: AnalysisUiState) {
    // Une ligne d'état NEUTRE, qui nomme ce qui travaille et jusqu'où il a
    // calculé. Elle disait « profondeur 18 » : le mot ne veut rien dire pour
    // qui ne connaît pas les moteurs, alors qu'un nombre de coups d'avance se
    // comprend. iOS l'a changé pour cette raison, commentaire à l'appui.
    val texte = when {
        ui.engineUnavailable -> stringResource(R.string.analysis_engine_off)
        ui.depth > 0 -> stringResource(R.string.analysis_engine_working, ui.depth)
        else -> stringResource(R.string.analysis_engine_idle)
    }
    val vivant = !ui.engineUnavailable && ui.depth > 0
    Row(
        Modifier
            .clip(CircleShape)
            .background(Palette.surface)
            .subtleBorder(CircleShape)
            .padding(horizontal = 10.dp, vertical = 4.dp)
            // FUSIONNÉE : sans cela, la rangée ne porte que son étiquette et
            // le texte reste dans l'enfant — invisible au lecteur d'écran
            // comme aux tests d'interface, qui lisaient une capsule vide.
            .semantics(mergeDescendants = true) {}
            .testTag("moteur-etat"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(
                    (if (vivant) Palette.accent else Palette.textTertiary)
                        .copy(alpha = if (vivant) 1f else 0.5f)
                )
        )
        Spacer(Modifier.width(7.dp))
        Text(texte, fontSize = 11.sp, fontWeight = FontWeight.Medium, color = Palette.textSecondary, maxLines = 1)
    }
}
