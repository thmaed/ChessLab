package com.chesslab.ui

import androidx.annotation.StringRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.HelpOutline
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Science
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.ShowChart
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.discovery.DiscoverySpot
import com.chesslab.discovery.discoveryAnchor
import com.chesslab.library.GameRecord
import com.chesslab.library.LibraryDatabase
import com.chesslab.nav.Route
import androidx.compose.material.icons.filled.ChevronRight
import java.text.DateFormat
import java.util.Date

/**
 * Une tuile de mode. Pendant de `ModeCard` (`HomeView.swift`).
 *
 * [shortTitle] et [shortSubtitle] : sur un téléphone à deux colonnes, une
 * tuile fait environ 160 dp — « Contre l'ordinateur » y finissait en points de
 * suspension. Le titre long reste pour les écrans larges.
 */
data class Mode(
    val route: Route,
    /** Le repère des tests : stable, et indépendant de la langue. */
    val tag: String,
    @StringRes val title: Int,
    @StringRes val shortTitle: Int,
    @StringRes val subtitle: Int,
    @StringRes val shortSubtitle: Int,
    val icon: ImageVector,
    val tint: Color,
    val enabled: Boolean = true,
    /** La cible de la visite guidée que porte cette tuile, s'il y en a une. */
    val spot: DiscoverySpot? = null,
)

private val modes = listOf(
    Mode(Route.NewGame(), "play", R.string.route_play, R.string.home_play_short,
        R.string.home_play_long, R.string.home_play_sub, Icons.Default.Memory, Palette.accent,
        spot = DiscoverySpot.playTile),
    Mode(Route.TwoPlayerSetup(), "two", R.string.route_two_players, R.string.home_two_short,
        R.string.home_two_long, R.string.home_two_sub, Icons.Default.People, Palette.info),
    Mode(Route.PuzzleQueue, "puzzles", R.string.route_puzzles, R.string.route_puzzles,
        R.string.home_puzzles_long, R.string.home_puzzles_sub, Icons.Default.Extension, Palette.violet,
        spot = DiscoverySpot.puzzlesTile),
    Mode(Route.Openings, "openings", R.string.route_openings, R.string.route_openings,
        R.string.home_openings_long, R.string.home_openings_sub, Icons.Default.MenuBook, Palette.warning),
    Mode(Route.Endgames, "endgames", R.string.route_endgames, R.string.route_endgames,
        R.string.home_endgames_long, R.string.home_endgames_sub, Icons.Default.EmojiEvents, Palette.gold),
    Mode(Route.Analysis, "analysis", R.string.route_analysis, R.string.route_analysis,
        R.string.home_analysis_long, R.string.home_analysis_sub, Icons.Default.ShowChart, Palette.teal),
    Mode(Route.Laboratory(), "lab", R.string.route_lab, R.string.route_lab,
        R.string.home_lab_long, R.string.home_lab_sub, Icons.Default.Science, Palette.rose),
    Mode(Route.Variants, "variants", R.string.route_variants, R.string.route_variants,
        R.string.home_variants_long, R.string.home_variants_sub, Icons.Default.Casino, Palette.violet,
        spot = DiscoverySpot.variantsTile),
)

@Composable
fun HomeScreen(onOpen: (Route) -> Unit) {
    val context = LocalContext.current
    val autosaves by remember { LibraryDatabase.get(context).autosaves().all() }
        .collectAsState(initial = emptyList())

    // Les quatre dernières parties, comme sur iOS : un tap ouvre leur
    // analyse sans passer par la bibliothèque.
    val games by remember { LibraryDatabase.get(context).games().all() }
        .collectAsState(initial = emptyList())
    val recent = games.take(4)

    // Une grille SIMPLE, pas paresseuse. Huit tuiles ne valent pas la peine
    // d'être recyclées, et la version paresseuse plantait
    // (« Index 10, size 10 ») dès qu'une bande apparaissait pendant qu'elle
    // mesurait : le nombre d'éléments changeait sous ses pieds. Ici tout est
    // composé, donc rien ne change de nombre.
    BoxWithConstraints(Modifier.fillMaxSize()) {
        // BORNÉE À LA MESURE DE LECTURE, et centrée. Sans cette borne, une
        // tablette étalait les huit tuiles sur une rangée de sept plus une
        // orpheline, et laissait les deux tiers du bas vides. iOS borne de la
        // même façon (`Theme.readableWidth`).
        val largeur = minOf(maxWidth, Metrics.readableWidth)
        val columns = tileColumns(largeur, padding = 20.dp, spacing = 14.dp)
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .testTag("accueil"),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
        Column(
            Modifier.widthIn(max = Metrics.readableWidth).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Header(onOpen)

            // La plus RÉCENTE des parties interrompues, quel que soit son
            // mode : celle qu'on a quittée en dernier est celle qu'on veut
            // reprendre. Les proposer toutes ferait deux bandes concurrentes
            // pour un seul geste.
            autosaves.maxByOrNull { it.savedAt }?.let { save ->
                Banner(
                    Icons.Default.PlayArrow,
                    stringResource(R.string.home_resume_title),
                    // Où en est la partie, comme iOS — pas le nom de
                    // l'adversaire, qu'on retrouve en l'ouvrant.
                    pluralStringResource(
                        R.plurals.home_resume_moves,
                        save.moveList.size,
                        save.moveList.size,
                    ),
                    Palette.accent, "reprendre",
                ) {
                    onOpen(
                        if (save.mode == "twoPlayer") Route.TwoPlayer(resume = true)
                        else Route.PlayVsEngine(resume = true)
                    )
                }
            }
            SectionHeader(stringResource(R.string.home_modes), Modifier.padding(top = 8.dp))
            modes.chunked(columns).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    row.forEach { mode -> Box(Modifier.weight(1f)) { ModeCard(mode, onOpen) } }
                    repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
            if (recent.isNotEmpty()) RecentGames(recent, onOpen)
            Spacer(Modifier.height(8.dp))
        }
        }
    }
}

@Composable
private fun Header(onOpen: (Route) -> Unit) {
    Column {
        // Les trois boutons ronds, en haut à droite : une couleur par
        // fonction — vert pour l'aide, bleu pour la progression comme ses
        // courbes, doré pour les réglages.
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.End,
        ) {
            CircleIconButton(Icons.AutoMirrored.Filled.HelpOutline,
                stringResource(R.string.route_help), Palette.accent, "aide",
                modifier = Modifier.discoveryAnchor(DiscoverySpot.helpButton)) { onOpen(Route.Help) }
            Spacer(Modifier.width(8.dp))
            CircleIconButton(Icons.Default.TrendingUp,
                stringResource(R.string.route_progress), Palette.info, "progression") { onOpen(Route.Progression) }
            Spacer(Modifier.width(8.dp))
            CircleIconButton(Icons.Default.Settings,
                stringResource(R.string.route_settings), Palette.gold, "reglages") { onOpen(Route.Settings) }
        }

        Spacer(Modifier.height(14.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            // L'illustration porte DÉJÀ son cadre et son fond : elle remplace
            // la pastille au lieu d'être posée dessus.
            Image(
                painterResource(R.drawable.app_logo), null,
                modifier = Modifier
                    .size(56.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(16.dp)),
            )
            Spacer(Modifier.width(14.dp))
            Column {
                Text(
                    buildAnnotatedString {
                        withStyle(SpanStyle(color = Palette.textPrimary)) { append("Chess") }
                        withStyle(SpanStyle(brush = accentGradient)) { append("Lab") }
                    },
                    fontSize = 32.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.2.sp,
                )
                Text(
                    stringResource(R.string.home_tagline),
                    fontSize = 14.sp, color = Palette.textSecondary,
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

/** Une bande d'appel pleine largeur : reprendre, réviser. */
@Composable
private fun Banner(
    icon: ImageVector, title: String, subtitle: String,
    tint: Color, tag: String, onClick: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .testTag(tag)
            .clip(ControlShape)
            .background(tint.copy(alpha = 0.12f))
            .tintedCardBorder(tint, shape = ControlShape)
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(22.dp))
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = tint)
            Text(subtitle, fontSize = 11.sp, color = Palette.textSecondary)
        }
    }
}

/**
 * Les parties récentes : l'en-tête, « Voir tout » vers la bibliothèque, puis
 * une ligne par partie qui ouvre directement son analyse. Pendant de
 * `recentGamesSection` (`HomeView.swift`).
 */
@Composable
private fun RecentGames(games: List<GameRecord>, onOpen: (Route) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(
            Modifier.fillMaxWidth().padding(top = 8.dp).discoveryAnchor(DiscoverySpot.recentGames),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SectionHeader(stringResource(R.string.home_recent_games))
            Spacer(Modifier.weight(1f))
            Text(
                stringResource(R.string.home_see_all), fontSize = 13.sp, fontWeight = FontWeight.Medium,
                color = Palette.accent,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .clickable { onOpen(Route.AnalysisBoard()) }
                    .padding(4.dp)
                    .testTag("voir-tout"),
            )
        }
        games.forEach { game ->
            RecentGameRow(game) { onOpen(Route.AnalysisBoard(pgn = game.pgn)) }
        }
    }
}

@Composable
private fun RecentGameRow(game: GameRecord, onOpen: () -> Unit) {
    val playable = game.pgn.isNotEmpty()
    Row(
        Modifier
            .fillMaxWidth()
            .testTag("recente-${game.id}")
            .clip(CardShape)
            .background(cardGradient)
            .subtleBorder()
            .clickable(enabled = playable, onClick = onOpen)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        IconBadge(Icons.Default.ShowChart, Palette.teal, 40.dp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                recentGameTitle(game), fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                color = Palette.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                // La MÊME pastille que la bibliothèque : un seul langage pour
                // la même information.
                GameResultPill(game.result)
                Text(
                    DateFormat.getDateInstance(DateFormat.MEDIUM).format(Date(game.playedAt)),
                    fontSize = 11.sp, color = Palette.textSecondary,
                )
            }
        }
        Text(
            stringResource(R.string.route_analysis), fontSize = 11.sp, fontWeight = FontWeight.SemiBold,
            color = if (playable) Palette.accent else Palette.textTertiary,
        )
        Icon(Icons.Default.ChevronRight, null, tint = Palette.textTertiary, modifier = Modifier.size(16.dp))
    }
}

/**
 * Intitulé lisible : « Contre l'ordinateur » pour une partie moteur, sinon
 * les deux noms. Les noms « Vous »/« Blancs »/« Noirs » sont rangés dans la
 * langue du moment ; on les relit dans celle d'aujourd'hui.
 */
@Composable
private fun recentGameTitle(game: GameRecord): String {
    if (game.source == "engine") return stringResource(R.string.route_play)
    return "${playerName(game.white)} – ${playerName(game.black)}"
}

@Composable
private fun playerName(stored: String): String = when (stored) {
    "Vous", "You" -> stringResource(R.string.you)
    "Blancs", "White" -> stringResource(R.string.color_white_side)
    "Noirs", "Black" -> stringResource(R.string.color_black_side)
    else -> stored
}

@Composable
private fun ModeCard(mode: Mode, onOpen: (Route) -> Unit) {
    Box(
        Modifier
            .testTag("mode-${mode.tag}")
            .then(if (mode.spot != null) Modifier.discoveryAnchor(mode.spot) else Modifier)
            .height(132.dp)
            .clip(CardShape)
            .background(cardGradient)
            .tintedCardBorder(mode.tint, mode.enabled)
            .clickable(enabled = mode.enabled) { onOpen(mode.route) }
    ) {
        // L'icône « fantôme » du fond : la même forme, très pâle, débordant
        // dans le coin. Elle donne un caractère illustré sans image.
        Icon(
            mode.icon, null,
            tint = mode.tint.copy(alpha = if (mode.enabled) 0.08f else 0.03f),
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .offset(x = 28.dp, y = 22.dp)
                .size(96.dp),
        )

        // La flèche de lancement : dit « ceci ouvre un espace » d'un coup d'œil.
        if (mode.enabled) {
            Icon(
                Icons.Default.NorthEast, null,
                tint = mode.tint.copy(alpha = 0.6f),
                modifier = Modifier.align(Alignment.TopEnd).padding(13.dp).size(14.dp),
            )
        }

        Column(Modifier.fillMaxSize().padding(16.dp)) {
            IconBadge(mode.icon, mode.tint, enabled = mode.enabled)
            Spacer(Modifier.weight(1f))
            Text(
                stringResource(mode.shortTitle),
                fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                color = if (mode.enabled) Palette.textPrimary else Palette.textTertiary,
                maxLines = 2, overflow = TextOverflow.Ellipsis,
            )
            Text(
                stringResource(if (mode.enabled) mode.shortSubtitle else R.string.soon_label),
                fontSize = 12.sp, color = Palette.textSecondary,
                modifier = Modifier.padding(top = 2.dp),
                maxLines = 2, overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
