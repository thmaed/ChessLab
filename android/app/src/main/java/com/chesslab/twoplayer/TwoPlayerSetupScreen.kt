package com.chesslab.twoplayer

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.ScreenRotation
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.play.TimeControl
import com.chesslab.ui.BasicTextFieldWithPlaceholder
import com.chesslab.ui.CardShape
import com.chesslab.ui.ChipButton
import com.chesslab.ui.Palette
import com.chesslab.ui.SettingsSection
import com.chesslab.ui.accentGradient
import com.chesslab.ui.subtleBorder

/**
 * La configuration d'une partie à deux. Pendant de `TwoPlayerSetupView`.
 *
 * Elle existe pour une raison qui n'a rien d'esthétique : **les noms**. Une
 * partie rangée dans la bibliothèque sous « Blancs — Noirs » se confond avec
 * toutes les autres ; sous « Thierry — Camille », on la retrouve.
 */
@Composable
fun TwoPlayerSetupScreen(
    initial: TwoPlayerSettings,
    onStart: (TwoPlayerSettings) -> Unit,
) {
    var white by remember { mutableStateOf(initial.whiteName) }
    var black by remember { mutableStateOf(initial.blackName) }
    var rotation by remember { mutableStateOf(initial.rotation) }
    var timeControlId by remember { mutableStateOf(initial.timeControlId) }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        SettingsSection(stringResource(R.string.two_setup_players), Icons.Default.People) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                BasicTextFieldWithPlaceholder(
                    value = white,
                    placeholder = stringResource(R.string.color_white),
                    tag = "nom-blancs",
                ) { white = it }
                BasicTextFieldWithPlaceholder(
                    value = black,
                    placeholder = stringResource(R.string.color_black),
                    tag = "nom-noirs",
                ) { black = it }
            }
        }

        SettingsSection(stringResource(R.string.two_setup_rotation), Icons.Default.ScreenRotation) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                TwoPlayerSettings.RotationMode.entries.forEach { mode ->
                    val titre: Int
                    val note: Int
                    when (mode) {
                        TwoPlayerSettings.RotationMode.faceToFace -> {
                            titre = R.string.two_rotation_face; note = R.string.two_rotation_face_note
                        }
                        TwoPlayerSettings.RotationMode.fixed -> {
                            titre = R.string.two_rotation_fixed; note = R.string.two_rotation_fixed_note
                        }
                        TwoPlayerSettings.RotationMode.tabletop -> {
                            titre = R.string.two_rotation_table; note = R.string.two_rotation_table_note
                        }
                    }
                    val active = rotation == mode
                    Column(
                        Modifier
                            .fillMaxWidth()
                            .clip(CardShape)
                            .background(if (active) Palette.accent.copy(alpha = 0.16f) else Palette.surface)
                            .clickable { rotation = mode }
                            .padding(horizontal = 12.dp, vertical = 10.dp)
                            .testTag("rotation-${mode.name}"),
                    ) {
                        Text(
                            stringResource(titre),
                            fontSize = 14.sp,
                            color = if (active) Palette.accent else Palette.textPrimary,
                        )
                        Text(stringResource(note), fontSize = 11.sp, color = Palette.textTertiary)
                    }
                }
            }
        }

        SettingsSection(stringResource(R.string.setup_time), Icons.Default.Timer) {
            // Les cadences défilent : il y en a plus que de largeur d'écran.
            Row(
                Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                TimeControl.presets.forEach { control ->
                    ChipButton(
                        label = control.label,
                        selected = timeControlId == control.id,
                        modifier = Modifier.testTag("cadence-${control.id}"),
                    ) { timeControlId = control.id }
                }
            }
        }

        Spacer(Modifier.height(4.dp))
        Text(
            stringResource(R.string.setup_start),
            fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
            modifier = Modifier
                .fillMaxWidth()
                .clip(CircleShape)
                .background(accentGradient)
                .clickable {
                    onStart(
                        initial.copy(
                            whiteName = white.trim(),
                            blackName = black.trim(),
                            rotation = rotation,
                            timeControlId = timeControlId,
                        )
                    )
                }
                .padding(vertical = 14.dp)
                .testTag("commencer"),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        Spacer(Modifier.height(20.dp))
    }
}


