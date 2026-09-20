package com.chesslab.settings

import androidx.compose.foundation.Image
import androidx.compose.foundation.border
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.ui.res.painterResource
import chesskit.Piece
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chesskit.Position
import com.chesslab.ui.BoardTheme
import com.chesslab.ui.BoardView
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.HelpOutline
import androidx.compose.material.icons.filled.Category
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Abc
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Vibration
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VolumeUp
import com.chesslab.ui.IconBadge
import com.chesslab.ui.SettingsSection
import com.chesslab.ui.Palette
import androidx.compose.ui.res.stringResource
import com.chesslab.R
import androidx.compose.runtime.*

@Composable
fun SettingsScreen(
    onOpenLicences: () -> Unit = {},
    /** « Sources des données » : à quoi les ouvertures doivent leurs chiffres. */
    onOpenSources: () -> Unit = {},
    /** « Comment ça marche » : le même écran que le « ? » de l'accueil. */
    onOpenHelp: () -> Unit = {},
) {
    val context = LocalContext.current
    val settings by SettingsStore.state.collectAsState()

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        // L'ORDRE d'iOS (`SettingsView`) : la langue d'abord — c'est le
        // réglage qu'on vient changer —, puis ce qui se voit sur le
        // plateau, puis ce qui change la façon de travailler, et enfin
        // l'aide et les licences. L'aperçu suit le thème qu'il montre.
        SettingsSection(stringResource(R.string.settings_language), Icons.Default.Language) {
        val activity = LocalContext.current as? android.app.Activity
        var language by remember { mutableStateOf(AppLanguage.current(context)) }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf(
                AppLanguage.system to R.string.settings_language_system,
                AppLanguage.french to R.string.settings_language_fr,
                AppLanguage.english to R.string.settings_language_en,
            ).forEach { (value, label) ->
                Choice(stringResource(label), value == language, "langue-${value.name}") {
                    language = value
                    AppLanguage.apply(context, value) { activity?.recreate() }
                }
            }
        }

        }

        // Une LIGNE par thème, avec ses VRAIES pièces posées dessus — comme
        // iOS. Android montrait des pastilles de deux couleurs, puis un grand
        // échiquier d'aperçu à part : deux endroits pour une seule question,
        // et aucun des deux ne disait à quoi ressemble une pièce sur ce thème.
        SettingsSection(stringResource(R.string.settings_board_theme), Icons.Default.Palette) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                BoardTheme.all.forEach { theme ->
                    ThemeRow(theme, settings.pieceSetId, theme.id == settings.boardThemeId) {
                        SettingsStore.setBoardTheme(context, theme.id)
                    }
                }
            }
        }

                SettingsSection(stringResource(R.string.settings_piece_set), Icons.Default.Category) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf(
                "classic" to R.string.pieces_classic,
                "chessnut" to R.string.pieces_modern,
                "merida" to R.string.pieces_bold,
            ).forEach { (id, label) ->
                Choice(stringResource(label), id == settings.pieceSetId, "piece-$id") {
                    SettingsStore.setPieceSet(context, id)
                }
            }
        }

        }

        SettingsSection(stringResource(R.string.settings_notation), Icons.Default.Abc) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            // Le libellé porte son propre EXEMPLE : « Cf3 » explique mieux que
            // n'importe quelle phrase ce que le réglage change.
            listOf(
                com.chesslab.settings.PieceNotation.french to "Cf3, Dxd5, O-O",
                com.chesslab.settings.PieceNotation.english to "Nf3, Qxd5, O-O",
            ).forEach { (notation, exemple) ->
                val active = settings.pieceNotation == notation
                Column(
                    Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(10.dp))
                        .background(if (active) Palette.accent.copy(alpha = 0.18f) else Palette.surface)
                        .clickable { SettingsStore.setPieceNotation(context, notation) }
                        .padding(horizontal = 12.dp, vertical = 10.dp)
                        .testTag("notation-${notation.name}"),
                ) {
                    Text(
                        stringResource(
                            if (notation == com.chesslab.settings.PieceNotation.french)
                                R.string.settings_notation_french else R.string.settings_notation_english
                        ),
                        fontSize = 13.sp,
                        color = if (active) Palette.accent else Palette.textPrimary,
                    )
                    Text(exemple, fontSize = 11.sp, color = Palette.textTertiary)
                }
            }
        }

            Spacer(Modifier.height(6.dp))
            Text(
                stringResource(R.string.settings_notation_note),
                fontSize = 11.sp, color = Palette.textTertiary,
            )
        }

        SettingsSection(stringResource(R.string.progress_puzzles), Icons.Default.Extension) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf(1 to R.string.settings_one_try, 3 to R.string.settings_three_tries).forEach { (n, label) ->
                Choice(stringResource(label), n == settings.puzzleAttempts, "essais-$n") {
                    SettingsStore.setPuzzleAttempts(context, n)
                }
            }
        }
            // La note d'iOS, et elle SEULE : Android en avait écrit une
            // seconde qui disait la même chose autrement, et deux phrases
            // jumelles l'une sous l'autre se lisent moins bien qu'une.
            Spacer(Modifier.height(6.dp))
            Text(
                stringResource(R.string.settings_puzzle_attempts_note),
                fontSize = 11.sp, color = Palette.textTertiary,
            )
        }

        // Sons et vibrations dans la MÊME section, comme iOS : ce sont les
        // deux façons dont l'app répond au doigt, et les séparer en faisait
        // deux réglages sans rapport.
        SettingsSection(stringResource(R.string.settings_feedback), Icons.Default.VolumeUp) {
        Row(
            Modifier
                .fillMaxWidth()
                .testTag("sons")
                .clip(RoundedCornerShape(8.dp))
                .background(Palette.surface)
                .clickable { SettingsStore.setSounds(context, !settings.soundsEnabled) }
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Switch(
                checked = settings.soundsEnabled,
                onCheckedChange = { SettingsStore.setSounds(context, it) },
                colors = com.chesslab.ui.chessLabSwitchColors(),
            )
            Spacer(Modifier.width(10.dp))
            Column {
                Text(stringResource(R.string.settings_board_sounds), fontSize = 13.sp, color = Palette.textPrimary)
                Text(
                    stringResource(R.string.settings_sounds_note),
                    fontSize = 10.sp, color = Palette.textTertiary,
                )
            }
        }

        

            Spacer(Modifier.height(6.dp))

        Row(
            Modifier
                .fillMaxWidth()
                .testTag("haptique")
                .clip(RoundedCornerShape(8.dp))
                .background(Palette.surface)
                .clickable { SettingsStore.setHaptics(context, !settings.hapticsEnabled) }
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Switch(
                checked = settings.hapticsEnabled,
                onCheckedChange = { SettingsStore.setHaptics(context, it) },
                colors = com.chesslab.ui.chessLabSwitchColors(),
            )
            Spacer(Modifier.width(10.dp))
            Column {
                Text(stringResource(R.string.settings_board_haptics), fontSize = 13.sp, color = Palette.textPrimary)
                Text(
                    stringResource(R.string.settings_haptics_note),
                    fontSize = 10.sp, color = Palette.textTertiary,
                )
            }
        }

        
        }

                SettingsSection(stringResource(R.string.settings_openings), Icons.Default.MenuBook) {
            LinkRow(
                Icons.Default.Description, stringResource(R.string.settings_sources),
                stringResource(R.string.sources_intro).take(60) + "…", "sources", onOpenSources,
            )
        }

        SettingsSection(stringResource(R.string.settings_help), Icons.AutoMirrored.Filled.HelpOutline) {
            LinkRow(
                Icons.AutoMirrored.Filled.HelpOutline, stringResource(R.string.route_help),
                stringResource(R.string.settings_help_sub), "aide", onOpenHelp,
            )
        }

        SettingsSection(stringResource(R.string.settings_about), Icons.Default.Info) {
            LinkRow(
                Icons.Default.Description, stringResource(R.string.licences_title),
                stringResource(R.string.settings_licences_subtitle), "licences", onOpenLicences,
            )
        }

        Spacer(Modifier.height(12.dp))
    }
}

/** Une ligne qui MÈNE ailleurs : une icône, un titre, une explication, un chevron. */
@Composable
private fun LinkRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    subtitle: String,
    tag: String,
    onClick: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 4.dp)
            .testTag(tag),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        IconBadge(icon, Palette.textSecondary, 34.dp)
        Column(Modifier.weight(1f)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Palette.textPrimary)
            Text(subtitle, fontSize = 11.sp, color = Palette.textTertiary)
        }
        Icon(Icons.Default.ChevronRight, contentDescription = null, tint = Palette.textTertiary)
    }
}

private val remembered: Position get() = Position.standard

@Composable
private fun Section(title: String) {
    Text(
        title,
        fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Palette.textTertiary,
        modifier = Modifier.padding(bottom = 6.dp),
    )
}

@Composable
private fun ThemeRow(
    theme: BoardTheme,
    pieceSetId: String,
    selected: Boolean,
    onPick: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .testTag("theme-${theme.id}")
            .clip(RoundedCornerShape(8.dp))
            .background(if (selected) Palette.accent.copy(alpha = 0.12f) else Palette.surface)
            .clickable(onClick = onPick)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Six cases, six pièces : un roi, une dame et un cavalier de chaque
        // camp. C'est l'échantillon d'iOS, et il suffit à juger un thème.
        Row(
            Modifier
                .clip(RoundedCornerShape(7.dp))
                .border(1.dp, Palette.stroke, RoundedCornerShape(7.dp))
        ) {
            val exemples = listOf(
                Piece.Color.white to Piece.Kind.king,
                Piece.Color.white to Piece.Kind.queen,
                Piece.Color.white to Piece.Kind.knight,
                Piece.Color.black to Piece.Kind.king,
                Piece.Color.black to Piece.Kind.queen,
                Piece.Color.black to Piece.Kind.knight,
            )
            exemples.forEachIndexed { index, (couleur, genre) ->
                Box(
                    Modifier
                        .size(30.dp)
                        .background(if (index % 2 == 0) theme.lightSquare else theme.darkSquare),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        painterResource(
                            com.chesslab.ui.drawableFor(
                                Piece(genre, couleur, chesskit.Square.e1), pieceSetId,
                            )
                        ),
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize().padding(3.dp),
                    )
                }
            }
        }
        Spacer(Modifier.width(12.dp))
        Text(
            theme.label, fontSize = 13.sp,
            color = if (selected) Palette.accent else Palette.textPrimary,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            modifier = Modifier.weight(1f),
        )
        if (selected) {
            Icon(
                Icons.Default.CheckCircle, null,
                tint = Palette.accent, modifier = Modifier.size(18.dp),
            )
        }
    }
}

@Composable
private fun Choice(label: String, selected: Boolean, tag: String, onPick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .testTag(tag)
            .clip(RoundedCornerShape(8.dp))
            .background(if (selected) Palette.accent.copy(alpha = 0.12f) else Palette.surface)
            .clickable(onClick = onPick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RadioButton(selected = selected, onClick = onPick, colors = RadioButtonDefaults.colors(selectedColor = Palette.accent))
        Spacer(Modifier.width(6.dp))
        Text(label, fontSize = 13.sp, color = if (selected) Palette.accent else Palette.textPrimary)
    }
}

private val unusedColor: Color = Color.Transparent
