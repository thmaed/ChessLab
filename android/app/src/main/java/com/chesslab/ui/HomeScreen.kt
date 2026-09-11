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

/**
 * Une tuile de l'accueil. Titres, accroches et teintes repris de
 * `HomeView.swift`, y compris les accroches COURTES : sur téléphone, l'app
 * iOS les préfère, et pour la même raison — sinon l'accroche déborde.
 */
data class Mode(
    val route: Route,
    val title: String,
    val subtitle: String,
    val shortSubtitle: String,
    val icon: ImageVector,
    val tint: Color,
    val enabled: Boolean = true,
)

private val modes = listOf(
    Mode(Route.PlayVsEngine(), "Contre l'ordinateur", "Neuf personnages, ou Stockfish", "Personnages", Icons.Default.Memory, Palette.accent),
    Mode(Route.TwoPlayer, "Deux joueurs", "Sur le même appareil", "Même appareil", Icons.Default.People, Palette.info),
    Mode(Route.Puzzles, "Puzzles", "Tactique et bibliothèque Lichess", "Tactique et Lichess", Icons.Default.Extension, Palette.violet),
    Mode(Route.Openings, "Ouvertures", "Apprends et révise tes ouvertures", "Apprends et révise", Icons.Default.MenuBook, Palette.warning),
    Mode(Route.Endgames, "Finales", "Lucena, Philidor, opposition — prouvées", "Fins gagnantes", Icons.Default.EmojiEvents, Palette.gold),
    Mode(Route.Analysis(), "Analyser", "PGN, FEN, bibliothèque", "PGN, FEN", Icons.Default.ShowChart, Palette.teal),
    Mode(Route.Laboratory, "Laboratoire", "L'ordinateur contre lui-même", "Face à lui-même", Icons.Default.Science, Palette.rose),
    Mode(Route.Variants, "Variantes", "Chess960 et autres façons de jouer", "Chess960 et plus", Icons.Default.Casino, Palette.violet),
)

@Composable
fun HomeScreen(onOpen: (Route) -> Unit) {
    val context = LocalContext.current
    val autosaves by remember { LibraryDatabase.get(context).autosaves().all() }
        .collectAsState(initial = emptyList())

    // Combien de positions réclament une révision aujourd'hui. Relu à chaque
    // retour sur l'accueil : une séance vient d'en replanifier.
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
                    "Jouer · Analyser · S'entraîner · Expérimenter",
                    style = MaterialTheme.typography.bodySmall,
                    color = Palette.textSecondary,
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                )
            }
            IconButton(onClick = { onOpen(Route.Settings) }, modifier = Modifier.testTag("reglages")) {
                Icon(Icons.Default.Settings, "Réglages", tint = Palette.textSecondary)
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
                Triple(Route.Scanner, "Scanner", Icons.Default.PhotoCamera),
                Triple(Route.PositionEditor, "Éditeur", Icons.Default.Edit),
                Triple(Route.Progression, "Progression", Icons.Default.TrendingUp),
                Triple(Route.Help, "Aide", Icons.AutoMirrored.Filled.HelpOutline),
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
                    Text(label, fontSize = 11.sp, color = Palette.textSecondary)
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
                    .clickable { onOpen(Route.Train("daily", label = "Révisions du jour")) }
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Default.Schedule, null, tint = Palette.warning, modifier = Modifier.size(22.dp))
                Spacer(Modifier.width(10.dp))
                Column(Modifier.weight(1f)) {
                    Text("Réviser", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.warning)
                    Text(
                        "$due position${if (due > 1) "s" else ""} à revoir" +
                            if (studied > 0) " · $studied apprise${if (studied > 1) "s" else ""}" else "",
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
                    Text("Reprendre", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.accent)
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
            .testTag("mode-${mode.route.title}")
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
                mode.title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                color = Palette.textPrimary.copy(alpha = alpha),
                maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
            Text(
                if (mode.enabled) mode.shortSubtitle else "Bientôt",
                fontSize = 11.sp, color = Palette.textSecondary.copy(alpha = alpha),
                maxLines = 2, overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
