package com.chesslab.puzzles

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import com.chesslab.R
import com.chesslab.library.LibraryDatabase
import com.chesslab.progression.PuzzleStats
import com.chesslab.ui.ChipButton
import com.chesslab.ui.Palette
import com.chesslab.ui.QuickSwitchMenu
import com.chesslab.ui.SectionHeader
import com.chesslab.ui.TopBarActions
import com.chesslab.ui.accentGradient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Le choix de la SÉANCE, avant de résoudre. Pendant de `PuzzleQueueView`.
 *
 * Les filtres vivaient en tiroir au-dessus du plateau : on les ouvrait, on
 * choisissait, et le puzzle courant changeait sous les doigts. iOS demande
 * d'abord ce qu'on veut travailler — niveau, phase, type — puis lance la
 * séance ; c'est un écran de DÉCISION, et il a la place de montrer les trois
 * familles en entier plutôt qu'une ligne qui défile.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PuzzleQueueScreen(
    onStart: (PuzzleFilter) -> Unit,
    onPlayVsEngine: () -> Unit = {},
    onOpenTwoPlayer: () -> Unit = {},
    onOpenLab: () -> Unit = {},
) {
    val context = LocalContext.current
    var difficulty by remember { mutableStateOf<DifficultyTier?>(null) }
    var phase by remember { mutableStateOf<GamePhase?>(null) }
    var theme by remember { mutableStateOf<PuzzleThemeKind?>(null) }
    var stats by remember { mutableStateOf<PuzzleStats?>(null) }

    LaunchedEffect(Unit) {
        stats = withContext(Dispatchers.IO) {
            runCatching {
                PuzzleStats.compute(LibraryDatabase.get(context).puzzleProgress().all())
            }.getOrNull()
        }
    }

    TopBarActions {
        QuickSwitchMenu(
            onPlayVsEngine = { onPlayVsEngine() },
            onOpenTwoPlayer = { onOpenTwoPlayer() },
            onOpenLab = { onOpenLab() },
        )
    }

    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            // Chaque groupe a SA couleur — le niveau en vert, la phase en
            // bleu, le thème en ambre — et chaque puce son icône. Trois rangées
            // de puces toutes vertes se ressemblent trop pour qu'on retrouve la
            // sienne d'un coup d'œil ; c'est le parti pris d'iOS.
            Group(stringResource(R.string.puzzle_level)) {
                ChipButton(stringResource(R.string.filter_all), difficulty == null,
                    Modifier.testTag("niveau-tous"), tint = Palette.accent) { difficulty = null }
                DifficultyTier.entries.forEach { tier ->
                    ChipButton(
                        stringResource(tier.labelRes), difficulty == tier,
                        Modifier.testTag("niveau-${tier.name}"), tint = tier.tint,
                    ) { difficulty = if (difficulty == tier) null else tier }
                }
            }
            Group(stringResource(R.string.puzzle_phase)) {
                ChipButton(stringResource(R.string.filter_all_f), phase == null,
                    Modifier.testTag("phase-toutes"), tint = Palette.info) { phase = null }
                GamePhase.entries.forEach { value ->
                    ChipButton(
                        stringResource(value.labelRes), phase == value,
                        Modifier.testTag("phase-${value.name}"),
                        icon = value.icon, tint = Palette.info,
                    ) { phase = if (phase == value) null else value }
                }
            }
            Group(stringResource(R.string.puzzle_type)) {
                ChipButton(stringResource(R.string.filter_all), theme == null,
                    Modifier.testTag("theme-tous"), tint = Palette.warning) { theme = null }
                PuzzleThemeKind.entries.forEach { value ->
                    ChipButton(
                        stringResource(value.labelRes), theme == value,
                        Modifier.testTag("theme-${value.name}"),
                        icon = value.icon, tint = Palette.warning,
                    ) { theme = if (theme == value) null else value }
                }
            }
            stats?.takeIf { it.attempts > 0 }?.let { PuzzleStatsCard(it) }
        }

        // Le pied est ÉPINGLÉ : « Commencer » reste accessible quel que soit
        // le défilement, sur un petit écran comme sur un grand.
        Column(
            Modifier
                .fillMaxWidth()
                .background(Palette.background)
                .padding(horizontal = 20.dp)
                .padding(top = 12.dp, bottom = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                summary(difficulty, phase, theme),
                fontSize = 11.sp, color = Palette.textTertiary,
                modifier = Modifier.testTag("resume-selection"),
            )
            Spacer(Modifier.height(10.dp))
            Text(
                stringResource(R.string.puzzle_start_session),
                fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(CircleShape)
                    .background(accentGradient)
                    .clickable { onStart(PuzzleFilter(difficulty, phase, theme)) }
                    .padding(vertical = 14.dp)
                    .testTag("commencer-puzzles"),
                textAlign = TextAlign.Center,
            )
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Group(title: String, content: @Composable FlowRowScope.() -> Unit) {
    Column {
        SectionHeader(title)
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            content = content,
        )
    }
}

/** « Tous les puzzles », ou ce qu'on a choisi, en une ligne. */
@Composable
private fun summary(
    difficulty: DifficultyTier?,
    phase: GamePhase?,
    theme: PuzzleThemeKind?,
): String {
    val parts = listOfNotNull(
        difficulty?.let { stringResource(it.labelRes) },
        phase?.let { stringResource(it.labelRes) },
        theme?.let { stringResource(it.labelRes) },
    )
    return if (parts.isEmpty()) stringResource(R.string.puzzle_all_puzzles)
    else parts.joinToString(" · ")
}
