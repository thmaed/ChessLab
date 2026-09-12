package com.chesslab.progression

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.library.LibraryDatabase
import com.chesslab.settings.StatsStore
import com.chesslab.ui.Palette
import androidx.compose.ui.res.stringResource
import com.chesslab.R
import androidx.compose.ui.res.pluralStringResource

/**
 * La progression : ce que l'app a vu de vous.
 *
 * Tout vient de la bibliothèque et des compteurs de puzzles — rien n'est
 * inventé, et une statistique sans données le dit plutôt que d'afficher un
 * zéro qui ressemblerait à un résultat.
 */
@Composable
fun ProgressionScreen() {
    val context = LocalContext.current
    val games by remember { LibraryDatabase.get(context).games().all() }.collectAsState(initial = emptyList())
    val puzzles by remember { StatsStore.puzzles(context) }.collectAsState(initial = null)

    // La mémorisation. Relue à l'ouverture de l'écran : ces chiffres ne
    // bougent qu'à la fin d'une séance, pas en continu.
    var training by remember { mutableStateOf<TrainingStats?>(null) }
    LaunchedEffect(Unit) { training = TrainingStats.read(context) }

    val wins = games.count { (it.result == "1-0" && it.white == "Vous") || (it.result == "0-1" && it.black == "Vous") }
    val losses = games.count { (it.result == "0-1" && it.white == "Vous") || (it.result == "1-0" && it.black == "Vous") }
    val draws = games.count { it.result == "1/2-1/2" }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)
    ) {
        Section(stringResource(R.string.progress_games))
        if (games.isEmpty()) {
            Empty(stringResource(R.string.progress_no_games))
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Stat("${games.size}", stringResource(R.string.progress_played), Palette.textPrimary, Modifier.weight(1f))
                Stat("$wins", stringResource(R.string.progress_won), Palette.accent, Modifier.weight(1f))
                Stat("$draws", stringResource(R.string.progress_drawn), Palette.textSecondary, Modifier.weight(1f))
                Stat("$losses", stringResource(R.string.progress_lost), Palette.danger, Modifier.weight(1f))
            }
            Spacer(Modifier.height(8.dp))
            val favourite = games.groupingBy { it.black }.eachCount().maxByOrNull { it.value }
            if (favourite != null) {
                Text(
                    stringResource(
                        R.string.progress_favourite, favourite.key,
                        pluralStringResource(R.plurals.progress_games_count, favourite.value, favourite.value),
                    ),
                    fontSize = 11.sp, color = Palette.textTertiary,
                )
            }
        }

        Spacer(Modifier.height(20.dp))
        Section(stringResource(R.string.progress_puzzles))
        val stats = puzzles
        if (stats == null || stats.attempted == 0) {
            Empty(stringResource(R.string.progress_no_puzzles))
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Stat("${stats.attempted}", stringResource(R.string.progress_attempted), Palette.textPrimary, Modifier.weight(1f))
                Stat("${stats.solved}", stringResource(R.string.progress_solved), Palette.accent, Modifier.weight(1f))
                Stat("${stats.rate} %", stringResource(R.string.progress_success_rate), Palette.violet, Modifier.weight(1f))
            }
        }

        Spacer(Modifier.height(20.dp))
        Section(stringResource(R.string.progress_memory))
        val memo = training
        if (memo == null || memo.studied == 0) {
            Empty(stringResource(R.string.progress_no_memory))
        } else {
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

        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun Section(title: String) {
    Text(
        title, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
        color = Palette.textTertiary, modifier = Modifier.padding(bottom = 6.dp),
    )
}

@Composable
private fun Empty(text: String) {
    Text(text, fontSize = 12.sp, color = Palette.textSecondary, modifier = Modifier.testTag("vide"))
}

@Composable
private fun Stat(value: String, label: String, tint: Color, modifier: Modifier = Modifier) {
    Column(
        modifier
            .clip(RoundedCornerShape(10.dp))
            .background(Palette.surface)
            .padding(vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(value, fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = tint)
        Text(label, fontSize = 10.sp, color = Palette.textTertiary)
    }
}
