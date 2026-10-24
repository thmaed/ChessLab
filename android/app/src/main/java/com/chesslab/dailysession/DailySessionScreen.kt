package com.chesslab.dailysession

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Replay
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.courses.CourseRepository
import com.chesslab.puzzles.PuzzleFilter
import com.chesslab.puzzles.PuzzleSource
import com.chesslab.ui.ControlShape
import com.chesslab.ui.Palette
import com.chesslab.ui.tintedCardBorder

/** « 3 jours de suite », ou l'invitation à commencer. */
@Composable
private fun streakText(days: Int): String =
    if (days == 0) stringResource(R.string.daily_streak_none)
    else pluralStringResource(R.plurals.daily_streak_days, days, days)

private data class StepStyle(val icon: ImageVector, val tint: Color)

private fun style(kind: DailySessionStep.Kind): StepStyle = when (kind) {
    DailySessionStep.Kind.openings -> StepStyle(Icons.Default.MenuBook, Palette.warning)
    DailySessionStep.Kind.missedPuzzles -> StepStyle(Icons.Default.Replay, Palette.violet)
    DailySessionStep.Kind.ownPuzzles -> StepStyle(Icons.Default.Extension, Palette.accent)
    DailySessionStep.Kind.endgame -> StepStyle(Icons.Default.EmojiEvents, Palette.rose)
}

/** C7 / A5 : la carte « Séance du jour » en tête de l'accueil. Pendant de `DailySessionCard` (iOS). */
@Composable
fun DailySessionCard(onOpen: () -> Unit) {
    val context = LocalContext.current
    var plan by remember { mutableStateOf<DailySessionPlan?>(null) }
    LaunchedEffect(Unit) { plan = DailySessionBuilder.load(context) }
    val tint = Palette.warning
    Row(
        Modifier
            .fillMaxWidth()
            .testTag("seance-du-jour")
            .clip(ControlShape)
            .background(tint.copy(alpha = 0.14f))
            .tintedCardBorder(tint, shape = ControlShape)
            .clickable(onClick = onOpen)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            if (plan?.isComplete == true) Icons.Default.Verified else Icons.Default.LocalFireDepartment, null,
            tint = if (plan?.isComplete == true) Palette.accent else tint, modifier = Modifier.size(30.dp),
        )
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(stringResource(R.string.daily_title), fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
            Text(
                plan?.let { summary(it) } ?: " ", fontSize = 13.sp, color = Palette.textSecondary, maxLines = 2,
                modifier = Modifier.testTag("seance-resume"),
            )
        }
        plan?.streak?.takeIf { it > 0 }?.let { streak ->
            Icon(Icons.Default.LocalFireDepartment, null, tint = tint, modifier = Modifier.size(18.dp))
            Text("$streak", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = tint, modifier = Modifier.padding(start = 2.dp, end = 8.dp))
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Palette.textTertiary)
    }
}

/** « Ouvertures : 12 · Puzzles ratés : 3 · Une finale », ou le constat que tout est fait. */
@Composable
private fun summary(plan: DailySessionPlan): String {
    val parts = plan.pending.map { step ->
        when (step.kind) {
            DailySessionStep.Kind.openings -> stringResource(R.string.daily_sum_openings, step.remaining)
            DailySessionStep.Kind.missedPuzzles -> stringResource(R.string.daily_sum_missed, step.remaining)
            DailySessionStep.Kind.ownPuzzles -> stringResource(R.string.daily_sum_own, step.remaining)
            DailySessionStep.Kind.endgame -> stringResource(R.string.daily_sum_endgame)
        }
    }
    if (parts.isEmpty()) return stringResource(R.string.daily_all_done)
    return parts.joinToString(" · ").replaceFirstChar { it.uppercase() }
}

/** La séance du jour : les étapes dans l'ordre, et la série. Pendant de `DailySessionView` (iOS). */
@Composable
fun DailySessionScreen(
    onOpenOpenings: () -> Unit,
    onOpenPuzzles: (PuzzleFilter) -> Unit,
    onOpenEndgame: (String, String) -> Unit,
) {
    val context = LocalContext.current
    var plan by remember { mutableStateOf<DailySessionPlan?>(null) }
    // Relu à chaque retour sur l'écran : une étape est faite quand il n'y a plus rien à y revoir.
    var resumes by remember { mutableStateOf(0) }
    androidx.lifecycle.compose.LifecycleResumeEffect(Unit) {
        resumes++
        onPauseOrDispose { }
    }
    LaunchedEffect(resumes) { plan = DailySessionBuilder.load(context) }
    val current = plan
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp).testTag("ecran-seance"),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        if (current != null) {
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Palette.surface).padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    if (current.isComplete) Icons.Default.Verified else Icons.Default.LocalFireDepartment, null,
                    tint = if (current.isComplete) Palette.accent else Palette.warning, modifier = Modifier.size(34.dp),
                )
                Spacer(Modifier.width(14.dp))
                Column {
                    Text(
                        stringResource(if (current.isComplete) R.string.daily_complete else R.string.daily_todo),
                        fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary,
                    )
                    Text(streakText(current.streak), fontSize = 13.sp, color = Palette.textSecondary, modifier = Modifier.testTag("seance-serie"))
                }
            }
            current.steps.forEach { step ->
                StepRow(step) {
                    when (step.kind) {
                        DailySessionStep.Kind.openings -> onOpenOpenings()
                        DailySessionStep.Kind.missedPuzzles -> onOpenPuzzles(PuzzleFilter(missedOnly = true, limit = DailySessionBuilder.PUZZLES_CAP))
                        DailySessionStep.Kind.ownPuzzles -> onOpenPuzzles(PuzzleFilter(source = PuzzleSource.ownGames, limit = DailySessionBuilder.PUZZLES_CAP))
                        DailySessionStep.Kind.endgame -> step.courseId?.let { id ->
                            TrainingDays.markEndgameOpened(context)
                            onOpenEndgame(id, CourseRepository.cachedName(id) ?: id)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun StepRow(step: DailySessionStep, onStart: () -> Unit) {
    val look = style(step.kind)
    val title = stringResource(
        when (step.kind) {
            DailySessionStep.Kind.openings -> R.string.daily_step_openings
            DailySessionStep.Kind.missedPuzzles -> R.string.daily_step_missed
            DailySessionStep.Kind.ownPuzzles -> R.string.daily_step_own
            DailySessionStep.Kind.endgame -> R.string.daily_step_endgame
        }
    )
    val detail = if (step.isDone) stringResource(
        when (step.kind) {
            DailySessionStep.Kind.openings -> R.string.daily_done_openings
            DailySessionStep.Kind.missedPuzzles -> R.string.daily_done_missed
            DailySessionStep.Kind.ownPuzzles -> R.string.daily_done_own
            DailySessionStep.Kind.endgame -> R.string.daily_done_endgame
        }
    ) else when (step.kind) {
        DailySessionStep.Kind.openings -> stringResource(R.string.daily_todo_openings, step.remaining)
        DailySessionStep.Kind.missedPuzzles -> stringResource(R.string.daily_todo_missed, step.remaining)
        DailySessionStep.Kind.ownPuzzles -> stringResource(R.string.daily_todo_own, step.remaining)
        DailySessionStep.Kind.endgame -> stringResource(R.string.daily_todo_endgame)
    }
    val tint = look.tint
    Row(
        Modifier
            .fillMaxWidth()
            .testTag("etape-${step.kind.name}")
            .clip(ControlShape)
            .background(tint.copy(alpha = if (step.isDone) 0.06f else 0.14f))
            .tintedCardBorder(tint, shape = ControlShape)
            .then(if (step.isDone) Modifier else Modifier.clickable(onClick = onStart))
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            if (step.isDone) Icons.Default.CheckCircle else look.icon, null,
            tint = if (step.isDone) Palette.accent else tint, modifier = Modifier.size(26.dp),
        )
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(title, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
            Text(detail, fontSize = 13.sp, color = Palette.textSecondary)
        }
        if (!step.isDone) Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Palette.textTertiary)
    }
}
