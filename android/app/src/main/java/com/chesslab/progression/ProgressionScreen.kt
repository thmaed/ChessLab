package com.chesslab.progression

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.QueryStats
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.library.LibraryDatabase
import com.chesslab.maia.OpponentGallery
import com.chesslab.play.OpponentAvatar
import com.chesslab.ui.Palette
import com.chesslab.ui.SettingsSection
import com.chesslab.ui.tintGradient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.math.roundToInt

/**
 * La progression : ce que l'app a vu de vous. Pendant de `ProgressionView`.
 *
 * Tout vient de la bibliothèque et de la progression des puzzles — rien n'est
 * inventé, et une statistique sans données le dit plutôt que d'afficher un
 * zéro qui ressemblerait à un résultat.
 *
 * @param onTrainTheme lance une série de puzzles sur un thème à travailler.
 */
@Composable
fun ProgressionScreen(onTrainTheme: (String) -> Unit = {}) {
    val context = LocalContext.current
    val games by remember { LibraryDatabase.get(context).games().all() }.collectAsState(initial = emptyList())
    var puzzleRows by remember { mutableStateOf<List<com.chesslab.puzzles.PuzzleProgress>?>(null) }
    var range by remember { mutableStateOf(TimeRange.allTime) }

    // La mémorisation. Relue à l'ouverture de l'écran : ces chiffres ne
    // bougent qu'à la fin d'une séance, pas en continu.
    var training by remember { mutableStateOf<TrainingStats?>(null) }
    LaunchedEffect(Unit) {
        training = TrainingStats.read(context)
        puzzleRows = withContext(Dispatchers.IO) {
            runCatching { LibraryDatabase.get(context).puzzleProgress().all() }.getOrDefault(emptyList())
        }
    }

    val rows = puzzleRows ?: return
    val now = System.currentTimeMillis()
    val cutoff = range.cutoff(now)
    val inRange = if (cutoff == null) games else games.filter { it.playedAt >= cutoff }
    val summary = remember(inRange, rows) { ProgressionSummary.compute(inRange, rows) }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        if (games.isEmpty() && summary.puzzles.attempts == 0 && (training == null || training!!.studied == 0)) {
            EmptyState()
        } else {
            if (games.isNotEmpty()) EngineCard(summary, range, onRange = { range = it })
            if (summary.puzzles.attempts > 0) PuzzleCard(summary.puzzles, onTrainTheme)
            training?.takeIf { it.studied > 0 }?.let { MemoryCard(it) }
        }
        Spacer(Modifier.height(12.dp))
    }
}

// MARK: Contre l'ordinateur

@Composable
private fun EngineCard(summary: ProgressionSummary, range: TimeRange, onRange: (TimeRange) -> Unit) {
    SettingsSection(stringResource(R.string.progress_engine), Icons.Default.Memory, Palette.accent) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.testTag("periode")) {
            TimeRange.entries.forEach { r ->
                Text(
                    stringResource(r.labelRes), fontSize = 12.sp, fontWeight = FontWeight.Medium,
                    color = if (r == range) Palette.background else Palette.textPrimary,
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(if (r == range) Palette.accent else Palette.surfaceElevated)
                        .clickable { onRange(r) }
                        .padding(horizontal = 12.dp, vertical = 6.dp)
                        .testTag("periode-${r.name}"),
                )
            }
        }
        if (summary.engineGames == 0) {
            Spacer(Modifier.height(8.dp))
            Text(stringResource(R.string.progress_no_games_period), fontSize = 11.sp, color = Palette.textTertiary)
        }
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Stat("${summary.engineWins}", stringResource(R.string.progress_wins), Palette.accent, Modifier.weight(1f))
            Stat("${summary.engineDraws}", stringResource(R.string.progress_draws), Palette.textSecondary, Modifier.weight(1f))
            Stat("${summary.engineLosses}", stringResource(R.string.progress_losses), Palette.danger, Modifier.weight(1f))
        }
        summary.bestWinElo?.let { best ->
            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Default.EmojiEvents, null, tint = Palette.warning, modifier = Modifier.size(16.dp))
                Text(stringResource(R.string.progress_best_win, best), fontSize = 13.sp,
                    fontWeight = FontWeight.Medium, color = Palette.textPrimary, modifier = Modifier.testTag("meilleure-victoire"))
            }
        }
        if (summary.engineByBand.isNotEmpty()) {
            Divider()
            SubHeader(stringResource(R.string.progress_by_level))
            summary.engineByBand.forEach { record ->
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 3.dp)) {
                    Text(stringResource(record.band.labelRes), fontSize = 13.sp, color = Palette.textPrimary, modifier = Modifier.weight(1f))
                    // V · N · D compact, la couleur dit le sens sans légende.
                    Pills(record.wins, record.draws, record.losses)
                }
            }
        }
        if (summary.engineByOpponent.isNotEmpty()) {
            Divider()
            SubHeader(stringResource(R.string.progress_by_character))
            summary.engineByOpponent.forEach { record ->
                val profile = OpponentGallery.byId(record.profileId) ?: return@forEach
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 4.dp)) {
                    OpponentAvatar(profile, 28.dp)
                    Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f)) {
                        Text(profile.firstName, fontSize = 13.sp, color = Palette.textPrimary)
                        record.bestWinLevel?.let {
                            Text(stringResource(R.string.progress_beaten_up_to, it), fontSize = 10.sp, color = Palette.textTertiary)
                        }
                    }
                    Pills(record.wins, record.draws, record.losses)
                }
            }
        }
    }
}

// MARK: Puzzles

@Composable
private fun PuzzleCard(stats: PuzzleStats, onTrainTheme: (String) -> Unit) {
    SettingsSection(stringResource(R.string.progress_puzzles), Icons.Default.Extension, Palette.violet) {
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                stats.successRate?.let { "${(it * 100).roundToInt()}" + stringResource(R.string.percent_suffix) } ?: "—",
                fontSize = 36.sp, fontWeight = FontWeight.Bold, color = Palette.violet,
                modifier = Modifier.testTag("reussite-puzzles"),
            )
            Column(Modifier.padding(bottom = 6.dp)) {
                Text(stringResource(R.string.progress_success_rate), fontSize = 13.sp, color = Palette.textSecondary)
                Text(stringResource(R.string.progress_of_attempts, stats.successes, stats.attempts), fontSize = 11.sp, color = Palette.textTertiary)
            }
        }
        stats.reachedTier?.let { tier ->
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Default.Flag, null, tint = Palette.accent, modifier = Modifier.size(15.dp))
                Text(stringResource(R.string.progress_level_reached), fontSize = 13.sp, color = Palette.textSecondary)
                Text(stringResource(tier.labelRes), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
                    modifier = Modifier.testTag("niveau-atteint"))
            }
        }
        if (stats.byTier.isNotEmpty()) {
            Divider()
            SubHeader(stringResource(R.string.progress_by_difficulty))
            stats.byTier.forEach { record ->
                Column(Modifier.padding(vertical = 4.dp)) {
                    Row {
                        Text(stringResource(record.tier.labelRes), fontSize = 13.sp, color = Palette.textPrimary, modifier = Modifier.weight(1f))
                        Text("${(record.successRate * 100).roundToInt()}" + stringResource(R.string.percent_suffix),
                            fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary)
                    }
                    Spacer(Modifier.height(4.dp))
                    // Une barre de réussite : lecture d'un coup d'œil, pas besoin d'un graphe pour un ratio.
                    Box(Modifier.fillMaxWidth().height(6.dp).clip(CircleShape).background(Palette.surfaceElevated)) {
                        Box(
                            Modifier.fillMaxWidth(record.successRate.toFloat().coerceIn(0.02f, 1f)).fillMaxHeight()
                                .clip(CircleShape).background(tintGradient(Palette.violet)),
                        )
                    }
                }
            }
        }
        if (stats.weakestThemes.isNotEmpty()) {
            Divider()
            SubHeader(stringResource(R.string.progress_to_work_on))
            stats.weakestThemes.take(3).forEach { record ->
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).clickable { onTrainTheme(record.theme) }
                        .padding(vertical = 6.dp).testTag("travailler-${record.theme}"),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(stringResource(record.labelRes), fontSize = 13.sp, color = Palette.textPrimary, modifier = Modifier.weight(1f))
                    Text(stringResource(R.string.progress_failed, (record.failureRate * 100).roundToInt()),
                        fontSize = 12.sp, color = Palette.textTertiary)
                    Spacer(Modifier.width(6.dp))
                    Icon(Icons.Default.ChevronRight, stringResource(R.string.progress_train_theme), tint = Palette.accent, modifier = Modifier.size(14.dp))
                }
            }
        }
    }
}

// MARK: Mémorisation (les ouvertures, FSRS)

@Composable
private fun MemoryCard(memo: TrainingStats) {
    SettingsSection(stringResource(R.string.progress_memory), Icons.Default.Psychology, Palette.accent) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Stat("${memo.studied}", stringResource(R.string.progress_positions), Palette.textPrimary, Modifier.weight(1f))
            Stat("${memo.solid}", stringResource(R.string.progress_solid), Palette.accent, Modifier.weight(1f))
            Stat("${memo.hard}", stringResource(R.string.progress_to_firm), Palette.danger, Modifier.weight(1f))
        }
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Stat("${memo.due}", stringResource(R.string.progress_due), Palette.warning, Modifier.weight(1f))
            Stat("${memo.reviewsThisWeek}", stringResource(R.string.progress_reviews_week), Palette.info, Modifier.weight(1f))
            Stat(memo.retentionLabel, stringResource(R.string.progress_success_rate), Palette.violet, Modifier.weight(1f))
        }
        memo.nextDueLabel(LocalContext.current)?.let {
            Spacer(Modifier.height(8.dp))
            Text(it, fontSize = 11.sp, color = Palette.textTertiary, modifier = Modifier.testTag("prochaine-revision"))
        }
    }
}

// MARK: Briques

@Composable
private fun EmptyState() {
    Column(
        Modifier.fillMaxWidth().padding(vertical = 60.dp, horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Default.QueryStats, null, tint = Palette.textTertiary, modifier = Modifier.size(46.dp))
        Text(stringResource(R.string.progress_empty_title), fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
        Text(stringResource(R.string.progress_empty_body), fontSize = 13.sp, color = Palette.textSecondary,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center)
    }
}

@Composable
private fun Stat(value: String, label: String, tint: Color, modifier: Modifier) {
    Column(
        modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Palette.surfaceElevated.copy(alpha = 0.5f))
            .padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(value, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = tint)
        Text(label, fontSize = 11.sp, color = Palette.textSecondary)
    }
}

@Composable
private fun Pills(wins: Int, draws: Int, losses: Int) {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Pill("$wins", Palette.accent); Pill("$draws", Palette.textSecondary); Pill("$losses", Palette.danger)
    }
}

@Composable
private fun Pill(value: String, tint: Color) {
    Text(
        value, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = tint,
        modifier = Modifier.clip(CircleShape).background(tint.copy(alpha = 0.14f))
            .widthIn(min = 26.dp).padding(horizontal = 6.dp, vertical = 3.dp),
        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
    )
}

@Composable
private fun SubHeader(text: String) {
    Text(text, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary, modifier = Modifier.padding(bottom = 4.dp))
}

@Composable
private fun Divider() {
    Spacer(Modifier.height(10.dp))
    Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.stroke))
    Spacer(Modifier.height(10.dp))
}
