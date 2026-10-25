package com.chesslab.dailysession

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
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
import com.chesslab.ui.CelebrationOverlay
import com.chesslab.ui.ControlShape
import com.chesslab.ui.Palette
import com.chesslab.ui.tintedCardBorder

/** « 3 jours de suite », ou l'invitation à commencer. */
@Composable
private fun streakText(days: Int): String =
    if (days == 0) stringResource(R.string.daily_streak_none)
    else pluralStringResource(R.plurals.daily_streak_days, days, days)

/** « Médaille d'argent · prochaine à 30 jours », ou la première à gagner. */
@Composable
private fun medalCaption(streak: Int): String? {
    val medal = StreakMedal.earned(streak)
    val next = StreakMedal.next(streak)
    return when {
        medal == null -> next?.let { stringResource(R.string.medal_first, it.days) }
        next == null -> stringResource(medal.nameRes)
        else -> stringResource(R.string.medal_caption, stringResource(medal.nameRes), next.days)
    }
}

private data class StepStyle(val icon: ImageVector, val tint: Color)

private fun style(kind: DailySessionStep.Kind): StepStyle = when (kind) {
    DailySessionStep.Kind.openings -> StepStyle(Icons.Default.MenuBook, Palette.warning)
    DailySessionStep.Kind.missedPuzzles -> StepStyle(Icons.Default.Replay, Palette.violet)
    DailySessionStep.Kind.ownPuzzles -> StepStyle(Icons.Default.Extension, Palette.accent)
    DailySessionStep.Kind.endgame -> StepStyle(Icons.Default.EmojiEvents, Palette.rose)
}

/** C7 / A5 : la carte « Séance du jour » en tête de l'accueil. Pendant de `DailySessionCard` (iOS). */
@Composable
fun DailySessionCard(modifier: Modifier = Modifier, onOpen: () -> Unit) {
    val context = LocalContext.current
    var plan by remember { mutableStateOf<DailySessionPlan?>(null) }
    LaunchedEffect(Unit) { plan = DailySessionBuilder.load(context) }
    val tint = Palette.warning
    Row(
        modifier
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
            val medal = StreakMedal.earned(streak)
            val badgeTint = medal?.color ?: tint
            Icon(if (medal == null) Icons.Default.LocalFireDepartment else Icons.Default.WorkspacePremium, null, tint = badgeTint, modifier = Modifier.size(18.dp))
            Text("$streak", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = badgeTint, modifier = Modifier.padding(start = 2.dp, end = 8.dp))
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
    val cap = com.chesslab.settings.SettingsStore.state.collectAsState().value.dailyOpeningsCap
    LaunchedEffect(resumes, cap) { plan = DailySessionBuilder.load(context) }
    val current = plan
    Box(Modifier.fillMaxSize()) {
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
                    medalCaption(current.streak)?.let { caption ->
                        val medal = StreakMedal.earned(current.streak)
                        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.testTag("seance-medaille")) {
                            Icon(Icons.Default.WorkspacePremium, null, tint = medal?.color ?: Palette.textTertiary, modifier = Modifier.size(14.dp))
                            Text(caption, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = medal?.color ?: Palette.textTertiary, modifier = Modifier.padding(start = 4.dp))
                        }
                    }
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
            // Combien de positions d'ouverture la séance propose au plus par jour :
            // une seule ligne discrète, sans carte ni phrase d'explication.
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.settings_daily_openings), fontSize = 13.sp, color = Palette.textSecondary,
                    modifier = Modifier.weight(1f),
                )
                com.chesslab.settings.SettingsStore.DAILY_OPENINGS_CHOICES.forEach { n ->
                    val active = n == cap
                    Text(
                        n.toString(), fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                        color = if (active) Palette.background else Palette.textSecondary,
                        modifier = Modifier
                            .padding(start = 6.dp)
                            .clip(androidx.compose.foundation.shape.CircleShape)
                            .background(if (active) Palette.warning else Palette.surface)
                            .clickable { com.chesslab.settings.SettingsStore.setDailyOpeningsCap(context, n) }
                            .padding(horizontal = 12.dp, vertical = 5.dp)
                            .testTag("seance-ouvertures-$n"),
                    )
                }
            }
        }
    }
    // Un palier de série franchi et la séance finie : on le fête.
    if (current != null && current.isComplete && StreakMedal.isMilestone(current.streak)) CelebrationOverlay(Modifier.fillMaxSize())
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
