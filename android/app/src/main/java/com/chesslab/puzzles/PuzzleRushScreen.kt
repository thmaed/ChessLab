package com.chesslab.puzzles

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.PauseCircle
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import chesskit.Piece
import com.chesslab.R
import com.chesslab.play.PromotionDialog
import com.chesslab.settings.SettingsStore
import com.chesslab.ui.BoardView
import com.chesslab.ui.CardShape
import com.chesslab.ui.CelebrationOverlay
import com.chesslab.ui.IconBadge
import com.chesslab.ui.MiniBoard
import com.chesslab.ui.Palette
import com.chesslab.ui.ReadableColumn
import com.chesslab.ui.SanFormatter
import com.chesslab.ui.accentGradient
import com.chesslab.ui.cardGradient
import com.chesslab.ui.isLandscape
import com.chesslab.ui.subtleBorder
import kotlinx.coroutines.delay

/**
 * « Contre la montre » (17/11/2026). Pendant de `PuzzleRushView.swift`. Lisibilité d'abord : la règle en
 * une phrase avant de commencer, un seul élément en gros pendant la série (le chrono), un seul chiffre au
 * bilan.
 */
@Composable
fun PuzzleRushScreen(
    /** Le numéro de cette entrée dans l'écran : une nouvelle entrée repart de la règle. */
    session: Long,
    onExit: () -> Unit,
    /** Un raté du bilan, ouvert dans l'Analyse. */
    onAnalyze: (String) -> Unit = {},
    model: PuzzleRushViewModel = viewModel(),
) {
    LaunchedEffect(session) { model.open(session) }
    // L'app quitte le premier plan : le temps s'arrête, le plateau se voile.
    val owner = androidx.lifecycle.compose.LocalLifecycleOwner.current
    DisposableEffect(owner) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            if (event == androidx.lifecycle.Lifecycle.Event.ON_PAUSE) model.pause()
        }
        owner.lifecycle.addObserver(observer)
        onDispose {
            owner.lifecycle.removeObserver(observer)
            model.pause()
        }
    }
    val ui = model.ui
    when (ui.phase) {
        RushPhase.intro -> Intro(ui, model::begin)
        RushPhase.finished -> Summary(ui, onExit = onExit, onAgain = model::begin, onAnalyze = onAnalyze)
        else -> Running(ui, model)
    }
    if (ui.pendingPromotion != null) {
        PromotionDialog(onPick = model::completePromotion, onCancel = model::cancelPromotion)
    }
}

@Composable
private fun Intro(ui: PuzzleRushUi, onStart: () -> Unit) {
    ReadableColumn(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(22.dp),
    ) {
        Spacer(Modifier.height(8.dp))
        IconBadge(Icons.Default.Timer, Palette.rose, 64.dp)
        Text(stringResource(R.string.rush_title), fontSize = 28.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary)
        Text(
            stringResource(R.string.rush_rule), fontSize = 20.sp, color = Palette.textPrimary,
            textAlign = TextAlign.Center, modifier = Modifier.testTag("rushRule"),
        )
        Text(
            stringResource(R.string.rush_rule_detail), fontSize = 15.sp, color = Palette.textSecondary,
            textAlign = TextAlign.Center,
        )
        if (ui.previousBest > 0) {
            Text(stringResource(R.string.rush_best, ui.previousBest), fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Palette.accent)
        }
        if (ui.unavailable) {
            Text(stringResource(R.string.rush_unavailable), fontSize = 15.sp, color = Palette.warning, textAlign = TextAlign.Center)
        } else {
            PrimaryButton(stringResource(R.string.rush_start), "rushStart", loading = ui.preparing, onClick = onStart)
        }
    }
}

@Composable
private fun Running(ui: PuzzleRushUi, model: PuzzleRushViewModel) {
    val board: @Composable () -> Unit = { BoardArea(ui, model) }
    if (isLandscape()) {
        Row(Modifier.fillMaxSize().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.weight(1f).fillMaxHeight(), Alignment.Center) { board() }
            Spacer(Modifier.width(16.dp))
            Column(Modifier.width(300.dp), verticalArrangement = Arrangement.spacedBy(22.dp)) {
                Hud(ui, model)
                SideToMove(ui)
            }
        }
    } else {
        Column(Modifier.fillMaxSize().padding(vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Hud(ui, model, Modifier.padding(horizontal = 20.dp))
            Spacer(Modifier.height(14.dp))
            Box(Modifier.padding(horizontal = 16.dp)) { board() }
            Spacer(Modifier.height(14.dp))
            SideToMove(ui)
        }
    }
}

/** Le chrono en gros, le score, les trois erreurs possibles. */
@Composable
private fun Hud(ui: PuzzleRushUi, model: PuzzleRushViewModel, modifier: Modifier = Modifier) {
    var remaining by remember { mutableLongStateOf(ui.run.durationMs) }
    LaunchedEffect(ui.phase) {
        while (true) {
            remaining = if (ui.phase == RushPhase.countdown) ui.run.durationMs else model.remainingMs()
            delay(250)
        }
    }
    val timeLeft = stringResource(R.string.rush_time_left)
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            // Chiffres de largeur fixe SANS police à chasse fixe : celle-ci écartait le deux-points (« 0 : 14 »,
            // vu sur le Galaxy A16) ; iOS affiche « 0:14 ».
            clock(remaining), fontSize = 40.sp, fontWeight = FontWeight.Bold,
            style = androidx.compose.ui.text.TextStyle(fontFeatureSettings = "tnum"),
            color = if (remaining <= 10_000) Palette.rose else Palette.textPrimary,
            modifier = Modifier.testTag("rushClock").semantics {
                contentDescription = timeLeft
                stateDescription = clock(remaining)
            },
        )
        Spacer(Modifier.weight(1f))
        Box(contentAlignment = Alignment.TopCenter) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.testTag("rushScore")) {
                Text("${ui.run.solved}", fontSize = 34.sp, fontWeight = FontWeight.Bold, color = Palette.accent)
                Text(
                    stringResource(R.string.rush_found).uppercase(), fontSize = 11.sp, fontWeight = FontWeight.SemiBold,
                    color = Palette.textTertiary,
                )
            }
            FlashUp(ui.flashId)
        }
        Spacer(Modifier.weight(1f))
        val errorsLabel = stringResource(R.string.rush_errors, ui.run.errors, PuzzleRushRun.MAX_ERRORS)
        Row(
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier.testTag("rushErrors").semantics { contentDescription = errorsLabel },
        ) {
            repeat(PuzzleRushRun.MAX_ERRORS) { index ->
                val made = index < ui.run.errors
                Icon(
                    if (made) Icons.Default.Cancel else Icons.Outlined.Circle, null,
                    tint = if (made) Palette.rose else Palette.textTertiary, modifier = Modifier.size(24.dp),
                )
            }
        }
    }
}

/** « +1 » qui monte et s'efface à chaque réussite. */
@Composable
private fun FlashUp(id: Int) {
    if (id == 0) return
    val progress = remember(id) { Animatable(0f) }
    LaunchedEffect(id) { progress.animateTo(1f, tween(700)) }
    Text(
        "+1", fontSize = 17.sp, fontWeight = FontWeight.Black, color = Palette.accent,
        modifier = Modifier
            .graphicsLayer { translationY = -10f - 70f * progress.value }
            .alpha(1f - progress.value),
    )
}

@Composable
private fun BoardArea(ui: PuzzleRushUi, model: PuzzleRushViewModel) {
    BoxWithConstraints(Modifier.aspectRatio(1f), contentAlignment = Alignment.Center) {
        when (ui.phase) {
            RushPhase.countdown -> {
                Box(Modifier.fillMaxSize().clip(RoundedCornerShape(12.dp)).background(Palette.surfaceElevated))
                AnimatedContent(
                    targetState = ui.countdown,
                    transitionSpec = { (scaleIn() + fadeIn()) togetherWith fadeOut() },
                    label = "décompte",
                ) { value ->
                    Text(
                        "$value", fontSize = 120.sp, fontWeight = FontWeight.Black, color = Palette.accent,
                        modifier = Modifier.testTag("rushCountdown"),
                    )
                }
            }
            RushPhase.paused -> {
                Box(Modifier.fillMaxSize().clip(RoundedCornerShape(12.dp)).background(Palette.surfaceElevated))
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                    modifier = Modifier.padding(24.dp),
                ) {
                    Icon(Icons.Default.PauseCircle, null, tint = Palette.textSecondary, modifier = Modifier.size(54.dp))
                    Text(stringResource(R.string.rush_paused), fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary)
                    Text(
                        stringResource(R.string.rush_paused_body), fontSize = 15.sp, color = Palette.textSecondary,
                        textAlign = TextAlign.Center,
                    )
                    Box(Modifier.widthIn(max = 240.dp)) {
                        PrimaryButton(stringResource(R.string.rush_resume), "rushResume", onClick = model::resume)
                    }
                }
            }
            else -> if (ui.hasPuzzle) {
                Box(Modifier.testTag("rushBoard")) {
                    BoardView(
                        position = ui.position,
                        orientation = ui.orientation,
                        selected = ui.selected,
                        legalTargets = ui.legalTargets,
                        lastMove = ui.lastMove,
                        checkedKing = ui.checkedKing,
                        hint = ui.hint,
                        draggableColor = ui.position.sideToMove,
                        enabled = ui.phase == RushPhase.playing && !ui.busy,
                        onSquareTap = model::onSquareTap,
                    )
                }
            }
        }
    }
}

@Composable
private fun SideToMove(ui: PuzzleRushUi) {
    if (ui.phase != RushPhase.playing) return
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(
            Modifier.size(14.dp).clip(CircleShape)
                .background(if (ui.orientation == Piece.Color.white) Color.White else Color.Black)
                .subtleBorder(RoundedCornerShape(7.dp)),
        )
        Text(
            stringResource(if (ui.orientation == Piece.Color.white) R.string.rush_white_to_move else R.string.rush_black_to_move),
            fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
        )
    }
}

@Composable
private fun Summary(ui: PuzzleRushUi, onExit: () -> Unit, onAgain: () -> Unit, onAnalyze: (String) -> Unit) {
    val settings by SettingsStore.state.collectAsState()
    Box(Modifier.fillMaxSize()) {
        ReadableColumn(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                "${ui.run.solved}", fontSize = 96.sp, fontWeight = FontWeight.Black, color = Palette.accent,
                modifier = Modifier.testTag("rushFinalScore"),
            )
            Text(
                pluralStringResource(R.plurals.rush_solved_count, ui.run.solved), fontSize = 20.sp,
                color = Palette.textSecondary, modifier = Modifier.offset(y = (-14).dp),
            )
            if (ui.isNewRecord) {
                Row(
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.testTag("rushNewRecord"),
                ) {
                    Icon(Icons.Default.EmojiEvents, null, tint = Palette.gold)
                    Text(
                        if (ui.previousBest > 0) stringResource(R.string.rush_new_record, ui.previousBest)
                        else stringResource(R.string.rush_first_record),
                        fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Palette.gold,
                    )
                }
            } else if (ui.previousBest > 0) {
                Text(stringResource(R.string.rush_best, ui.previousBest), fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary)
            }
            ui.run.highestSolvedRating?.let {
                Text(stringResource(R.string.rush_hardest, it), fontSize = 15.sp, color = Palette.textTertiary)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.padding(top = 6.dp)) {
                Box(Modifier.weight(1f)) { SecondaryButton(stringResource(R.string.rush_done), "rushDone", onExit) }
                Box(Modifier.weight(1f)) { PrimaryButton(stringResource(R.string.rush_again), "rushAgain", onClick = onAgain) }
            }
            if (ui.missed.isNotEmpty()) {
                Spacer(Modifier.height(10.dp))
                Text(
                    pluralStringResource(R.plurals.rush_missed_title, ui.missed.size).uppercase(),
                    fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary,
                    letterSpacing = 0.6.sp, modifier = Modifier.fillMaxWidth(),
                )
                ui.missed.forEach { item ->
                    MissedRow(item, SanFormatter.display(item.sans, settings.pieceNotation)) { onAnalyze(item.fen) }
                }
            }
        }
        if (ui.isNewRecord) CelebrationOverlay()
    }
}

/** Un raté, avec sa solution : on apprend ici, pas pendant la course. */
@Composable
private fun MissedRow(item: RushMissed, sans: List<String>, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(CardShape).background(cardGradient).subtleBorder()
            .clickable(onClick = onClick).padding(12.dp).testTag("rushMissed"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        MiniBoard(item.fen, flipped = !item.whiteToMove, modifier = Modifier.size(76.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                stringResource(if (item.whiteToMove) R.string.rush_white_to_move else R.string.rush_black_to_move),
                fontSize = 12.sp, color = Palette.textTertiary,
            )
            Text(PuzzleRushSolution.numbered(item.fen, sans), fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
            Text(stringResource(R.string.rush_analyze), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.accent)
        }
        Icon(Icons.Default.ChevronRight, null, tint = Palette.textTertiary, modifier = Modifier.size(18.dp))
    }
}

@Composable
private fun PrimaryButton(title: String, tag: String, loading: Boolean = false, onClick: () -> Unit) {
    Box(
        Modifier.fillMaxWidth().clip(CardShape).background(accentGradient)
            .clickable(enabled = !loading, onClick = onClick).padding(vertical = 14.dp).testTag(tag),
        contentAlignment = Alignment.Center,
    ) {
        if (loading) CircularProgressIndicator(Modifier.size(20.dp), color = Palette.background, strokeWidth = 2.dp)
        else Text(title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Palette.background)
    }
}

@Composable
private fun SecondaryButton(title: String, tag: String, onClick: () -> Unit) {
    Box(
        Modifier.fillMaxWidth().clip(CardShape).background(Palette.surfaceElevated).subtleBorder()
            .clickable(onClick = onClick).padding(vertical = 14.dp).testTag(tag),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
    }
}

/** « 2:41 ». */
internal fun clock(ms: Long): String {
    val total = ((ms + 999) / 1000).toInt()
    return "%d:%02d".format(total / 60, total % 60)
}
