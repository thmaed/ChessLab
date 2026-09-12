package com.chesslab.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.HelpOutline
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.ui.platform.LocalContext
import com.chesslab.library.LibraryDatabase
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.nav.Route
import androidx.annotation.StringRes
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.res.pluralStringResource
import com.chesslab.R

/**
 * Une tuile de l'accueil. Titres, accroches et teintes repris de
 * `HomeView.swift`, y compris les accroches COURTES : sur téléphone, l'app
 * iOS les préfère, et pour la même raison — sinon l'accroche déborde.
 */
data class Mode(
    val route: Route,
    /**
     * Le repère des tests. Stable et indépendant de la langue : un repère tiré
     * du titre affiché aurait changé de nom en passant à l'anglais.
     */
    val tag: String,
    @StringRes val title: Int,
    @StringRes val subtitle: Int,
    @StringRes val shortSubtitle: Int,
    val icon: ImageVector,
    val tint: Color,
    val enabled: Boolean = true,
)

private val modes = listOf(
    Mode(Route.PlayVsEngine(), "play", R.string.route_play, R.string.home_play_long, R.string.home_play_sub, Icons.Default.Memory, Palette.accent),
    Mode(Route.TwoPlayer, "two", R.string.route_two_players, R.string.home_two_long, R.string.home_two_sub, Icons.Default.People, Palette.info),
    Mode(Route.Puzzles, "puzzles", R.string.route_puzzles, R.string.home_puzzles_long, R.string.home_puzzles_sub, Icons.Default.Extension, Palette.violet),
    Mode(Route.Openings, "openings", R.string.route_openings, R.string.home_openings_long, R.string.home_openings_sub, Icons.Default.MenuBook, Palette.warning),
    Mode(Route.Endgames, "endgames", R.string.route_endgames, R.string.home_endgames_long, R.string.home_endgames_sub, Icons.Default.EmojiEvents, Palette.gold),
    Mode(Route.Analysis(), "analysis", R.string.route_analysis, R.string.home_analysis_long, R.string.home_analysis_sub, Icons.Default.ShowChart, Palette.teal),
    Mode(Route.Laboratory, "lab", R.string.route_lab, R.string.home_lab_long, R.string.home_lab_sub, Icons.Default.Science, Palette.rose),
    Mode(Route.Variants, "variants", R.string.route_variants, R.string.home_variants_long, R.string.home_variants_sub, Icons.Default.Casino, Palette.violet),
)

@Composable
fun HomeScreen(onOpen: (Route) -> Unit) {
    val context = LocalContext.current
    val autosaves by remember { LibraryDatabase.get(context).autosaves().all() }
        .collectAsState(initial = emptyList())

    // Combien de positions réclament une révision aujourd'hui. Relu à chaque
    // retour sur l'accueil : une séance vient d'en replanifier.
    val reviewLabel = stringResource(R.string.train_daily)
    var due by remember { mutableStateOf(0) }
    var studied by remember { mutableStateOf(0) }
    LaunchedEffect(Unit) {
        val dao = LibraryDatabase.get(context).training()
        due = dao.dueCount(System.currentTimeMillis())
        studied = dao.studiedCount()
    }

    Column(Modifier.fillMaxSize().padding(horizontal = 16.dp)) {
        Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(
                    "ChessLab",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = Palette.textPrimary,
                )
                Text(
                    stringResource(R.string.home_tagline),
                    style = MaterialTheme.typography.bodySmall,
                    color = Palette.textSecondary,
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                )
            }
            IconButton(onClick = { onOpen(Route.Settings) }, modifier = Modifier.testTag("reglages")) {
                Icon(Icons.Default.Settings, stringResource(R.string.route_settings), tint = Palette.textSecondary)
            }
        }

        // Les actions secondaires : des pastilles NOMMÉES plutôt que des
        // icônes nues. Cinq pictogrammes côte à côte se devinent mal, et ils
        // poussaient l'accroche sur trois lignes.
        Spacer(Modifier.height(6.dp))
        Row(
            Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            listOf(
                Triple(Route.Scanner, R.string.chip_scanner, Icons.Default.PhotoCamera),
                Triple(Route.PositionEditor, R.string.chip_editor, Icons.Default.Edit),
                Triple(Route.Progression, R.string.chip_progress, Icons.Default.TrendingUp),
                Triple(Route.Help, R.string.chip_help, Icons.AutoMirrored.Filled.HelpOutline),
            ).forEach { (route, label, icon) ->
                Row(
                    Modifier
                        .testTag(
                            when (route) {
                                Route.Scanner -> "scanner"
                                Route.PositionEditor -> "editeur"
                                Route.Progression -> "progression"
                                else -> "aide"
                            }
                        )
                        .clip(RoundedCornerShape(14.dp))
                        .background(Palette.surface)
                        .clickable { onOpen(route) }
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(icon, null, tint = Palette.textSecondary, modifier = Modifier.size(15.dp))
                    Spacer(Modifier.width(5.dp))
                    Text(stringResource(label), fontSize = 11.sp, color = Palette.textSecondary)
                }
            }
        }

        Spacer(Modifier.height(12.dp))

        // Les révisions du jour. La bande n'apparaît QUE s'il y a quelque
        // chose à réviser : proposer « 0 position » chaque matin apprend à
        // l'ignorer, et c'est la bande qu'on veut lire quand elle s'allume.
        if (due > 0) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .testTag("reviser")
                    .clip(RoundedCornerShape(14.dp))
                    .background(Palette.warning.copy(alpha = 0.12f))
                    .clickable { onOpen(Route.Train("daily", label = reviewLabel)) }
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Default.Schedule, null, tint = Palette.warning, modifier = Modifier.size(22.dp))
                Spacer(Modifier.width(10.dp))
                Column(Modifier.weight(1f)) {
                    Text(
                        stringResource(R.string.home_review),
                        fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.warning,
                    )
                    Text(
                        pluralStringResource(R.plurals.home_review_due, due, due) +
                            if (studied > 0) " · " + pluralStringResource(R.plurals.home_review_learned, studied, studied) else "",
                        fontSize = 11.sp, color = Palette.textSecondary,
                    )
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        // La partie interrompue, s'il y en a une : elle passe AVANT les modes.
        autosaves.firstOrNull()?.let { save ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .testTag("reprendre")
                    .clip(RoundedCornerShape(14.dp))
                    .background(Palette.accent.copy(alpha = 0.12f))
                    .clickable { onOpen(Route.PlayVsEngine(resume = true)) }
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Default.PlayArrow, null, tint = Palette.accent, modifier = Modifier.size(22.dp))
                Spacer(Modifier.width(10.dp))
                Column(Modifier.weight(1f)) {
                    Text(stringResource(R.string.home_resume), fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.accent)
                    Text(save.label, fontSize = 11.sp, color = Palette.textSecondary)
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        // Le nombre de colonnes suit la largeur : deux sur un téléphone droit,
        // quatre couché ou sur tablette. Deux tuiles de 132 dp sur 900 dp de
        // large, c'est une tuile à moitié vide et un accueil qui défile pour
        // rien.
        LazyVerticalGrid(
            columns = GridCells.Adaptive(minSize = 170.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            contentPadding = PaddingValues(bottom = 24.dp),
        ) {
            items(modes) { mode -> ModeCard(mode, onOpen) }
        }
    }
}

@Composable
private fun ModeCard(mode: Mode, onOpen: (Route) -> Unit) {
    val alpha = if (mode.enabled) 1f else 0.4f
    Box(
        Modifier
            .testTag("mode-${mode.tag}")
            .height(132.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(Palette.surface)
            .clickable(enabled = mode.enabled) { onOpen(mode.route) }
    ) {
        // l'icône « fantôme » du fond, comme sur iOS : la même forme, très pâle,
        // débordant dans le coin
        Icon(
            mode.icon, contentDescription = null,
            tint = mode.tint.copy(alpha = if (mode.enabled) 0.10f else 0.04f),
            modifier = Modifier.size(96.dp).align(Alignment.BottomEnd).offset(x = 22.dp, y = 22.dp),
        )

        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(
                mode.icon, contentDescription = null,
                tint = mode.tint.copy(alpha = alpha),
                modifier = Modifier.size(30.dp),
            )
            Spacer(Modifier.weight(1f))
            Text(
                stringResource(mode.title), fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                color = Palette.textPrimary.copy(alpha = alpha),
                maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
            Text(
                stringResource(if (mode.enabled) mode.shortSubtitle else R.string.soon_label),
                fontSize = 11.sp, color = Palette.textSecondary.copy(alpha = alpha),
                maxLines = 2, overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
