package com.chesslab.progression

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
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

    val wins = games.count { (it.result == "1-0" && it.white == "Vous") || (it.result == "0-1" && it.black == "Vous") }
    val losses = games.count { (it.result == "0-1" && it.white == "Vous") || (it.result == "1-0" && it.black == "Vous") }
    val draws = games.count { it.result == "1/2-1/2" }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)
    ) {
        Section("Parties")
        if (games.isEmpty()) {
            Empty("Aucune partie enregistrée pour l'instant.")
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Stat("${games.size}", "jouées", Palette.textPrimary, Modifier.weight(1f))
                Stat("$wins", "gagnées", Palette.accent, Modifier.weight(1f))
                Stat("$draws", "nulles", Palette.textSecondary, Modifier.weight(1f))
                Stat("$losses", "perdues", Palette.danger, Modifier.weight(1f))
            }
            Spacer(Modifier.height(8.dp))
            val favourite = games.groupingBy { it.black }.eachCount().maxByOrNull { it.value }
            if (favourite != null) {
                Text(
                    "Adversaire le plus affronté : ${favourite.key} (${favourite.value} parties)",
                    fontSize = 11.sp, color = Palette.textTertiary,
                )
            }
        }

        Spacer(Modifier.height(20.dp))
        Section("Puzzles")
        val stats = puzzles
        if (stats == null || stats.attempted == 0) {
            Empty("Aucun puzzle tenté pour l'instant.")
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Stat("${stats.attempted}", "tentés", Palette.textPrimary, Modifier.weight(1f))
                Stat("${stats.solved}", "résolus", Palette.accent, Modifier.weight(1f))
                Stat("${stats.rate} %", "de réussite", Palette.violet, Modifier.weight(1f))
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
