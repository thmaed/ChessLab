package com.chesslab.ui

import androidx.annotation.StringRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import com.chesslab.library.LibraryDatabase
import com.chesslab.nav.Route

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
)

private val modes = listOf(
    Mode(Route.NewGame, "play", R.string.route_play, R.string.home_play_short,
        R.string.home_play_long, R.string.home_play_sub, Icons.Default.Memory, Palette.accent),
    Mode(Route.TwoPlayer, "two", R.string.route_two_players, R.string.home_two_short,
        R.string.home_two_long, R.string.home_two_sub, Icons.Default.People, Palette.info),
    Mode(Route.Puzzles, "puzzles", R.string.route_puzzles, R.string.route_puzzles,
        R.string.home_puzzles_long, R.string.home_puzzles_sub, Icons.Default.Extension, Palette.violet),
    Mode(Route.Openings, "openings", R.string.route_openings, R.string.route_openings,
        R.string.home_openings_long, R.string.home_openings_sub, Icons.Default.MenuBook, Palette.warning),
    Mode(Route.Endgames, "endgames", R.string.route_endgames, R.string.route_endgames,
        R.string.home_endgames_long, R.string.home_endgames_sub, Icons.Default.EmojiEvents, Palette.gold),
    Mode(Route.Analysis, "analysis", R.string.route_analysis, R.string.route_analysis,
        R.string.home_analysis_long, R.string.home_analysis_sub, Icons.Default.ShowChart, Palette.teal),
    Mode(Route.Laboratory, "lab", R.string.route_lab, R.string.route_lab,
        R.string.home_lab_long, R.string.home_lab_sub, Icons.Default.Science, Palette.rose),
    Mode(Route.Variants, "variants", R.string.route_variants, R.string.route_variants,
        R.string.home_variants_long, R.string.home_variants_sub, Icons.Default.Casino, Palette.violet),
)

@Composable
fun HomeScreen(onOpen: (Route) -> Unit) {
    val context = LocalContext.current
    val autosaves by remember { LibraryDatabase.get(context).autosaves().all() }
        .collectAsState(initial = emptyList())

    var due by remember { mutableStateOf(0) }
    var studied by remember { mutableStateOf(0) }
    LaunchedEffect(Unit) {
        val dao = LibraryDatabase.get(context).training()
        due = dao.dueCount(System.currentTimeMillis())
        studied = dao.studiedCount()
    }
    val reviewLabel = stringResource(R.string.train_daily)

    // Une grille SIMPLE, pas paresseuse. Huit tuiles ne valent pas la peine
    // d'être recyclées, et la version paresseuse plantait
    // (« Index 10, size 10 ») dès qu'une bande apparaissait pendant qu'elle
    // mesurait : le nombre d'éléments changeait sous ses pieds. Ici tout est
    // composé, donc rien ne change de nombre.
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val columns = ((maxWidth - 40.dp) / 174.dp).toInt().coerceAtLeast(2)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp).testTag("accueil"),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Header(onOpen)

            autosaves.firstOrNull()?.let { save ->
                Banner(
                    Icons.Default.PlayArrow, stringResource(R.string.home_resume),
                    save.label, Palette.accent, "reprendre",
                ) { onOpen(Route.PlayVsEngine(resume = true)) }
            }
            if (due > 0) {
                Banner(
                    Icons.Default.Schedule, stringResource(R.string.home_review),
                    pluralStringResource(R.plurals.home_review_due, due, due) +
                        if (studied > 0) " · " + pluralStringResource(R.plurals.home_review_learned, studied, studied) else "",
                    Palette.warning, "reviser",
                ) { onOpen(Route.Train("daily", label = reviewLabel)) }
            }

            SectionHeader(stringResource(R.string.home_modes), Modifier.padding(top = 8.dp))
            modes.chunked(columns).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    row.forEach { mode -> Box(Modifier.weight(1f)) { ModeCard(mode, onOpen) } }
                    repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
            Spacer(Modifier.height(8.dp))
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
                stringResource(R.string.route_help), Palette.accent, "aide") { onOpen(Route.Help) }
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

@Composable
private fun ModeCard(mode: Mode, onOpen: (Route) -> Unit) {
    Box(
        Modifier
            .testTag("mode-${mode.tag}")
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
