package com.chesslab.variants

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Numbers
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.ui.BoardView
import com.chesslab.ui.Palette
import com.chesslab.ui.SettingsSection
import com.chesslab.ui.accentGradient
import kotlin.random.Random

/**
 * Le réglage d'une partie de Chess960 : QUELLE position, et contre qui.
 * Pendant réduit de `Chess960SetupView.swift`.
 *
 * Le numéro n'est pas un caprice d'amateur : c'est la numérotation de
 * Scharnagl, celle de Lichess et des moteurs. Pouvoir la saisir, c'est pouvoir
 * rejouer la position d'hier, ou celle dont un ami parle.
 */
@Composable
fun Chess960SetupScreen(onStart: (number: Int, twoPlayer: Boolean) -> Unit) {
    var number by remember { mutableStateOf(Random.nextInt(Chess960Position.range.last + 1)) }
    var typed by remember { mutableStateOf(number.toString()) }
    var twoPlayer by remember { mutableStateOf(false) }

    // La position se VOIT avant de commencer : un numéro seul ne dit rien.
    val position = remember(number) {
        Chess960Position.startingFen(number)?.let { chesskit.FenParser.parse(it) }
    }

    fun pick(value: Int) {
        number = value.coerceIn(Chess960Position.range)
        typed = number.toString()
    }

    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            SettingsSection(stringResource(R.string.chess960_setup), Icons.Default.Numbers) {
                position?.let {
                    BoardView(position = it, enabled = false)
                    Spacer(Modifier.height(10.dp))
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedTextField(
                        value = typed,
                        onValueChange = { text ->
                            typed = text.filter { it.isDigit() }.take(3)
                            typed.toIntOrNull()?.let { if (it in Chess960Position.range) number = it }
                        },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        label = { Text(stringResource(R.string.chess960_number)) },
                        modifier = Modifier.weight(1f).testTag("numero-960"),
                    )
                }
                // Le curseur pour explorer, le champ pour viser : les deux
                // gestes n'ont pas le même but, et l'un sans l'autre agace.
                Slider(
                    value = number.toFloat(),
                    onValueChange = { pick(it.toInt()) },
                    valueRange = 0f..959f,
                    modifier = Modifier.testTag("curseur-960"),
                )
                Text(
                    stringResource(R.string.chess960_number_hint),
                    fontSize = 11.sp, color = Palette.textTertiary,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Chip(stringResource(R.string.chess960_random), "hasard-960") {
                        pick(Random.nextInt(Chess960Position.range.last + 1))
                    }
                    Chip(stringResource(R.string.chess960_classic), "classique-960") {
                        pick(Chess960Position.classic)
                    }
                }
            }

            SettingsSection(stringResource(R.string.route_two_players), Icons.Default.Groups) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Switch(
                        checked = twoPlayer, onCheckedChange = { twoPlayer = it },
                        modifier = Modifier.testTag("a-deux-960"),
                    )
                    Spacer(Modifier.width(10.dp))
                    Column {
                        Text(stringResource(R.string.chess960_two_players), fontSize = 13.sp, color = Palette.textPrimary)
                        Text(
                            stringResource(R.string.chess960_two_players_hint),
                            fontSize = 10.sp, color = Palette.textTertiary,
                        )
                    }
                }
            }
        }

        Text(
            stringResource(R.string.setup_start),
            fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 14.dp)
                .clip(CircleShape)
                .background(accentGradient)
                .clickable { onStart(number, twoPlayer) }
                .padding(vertical = 14.dp)
                .testTag("commencer-960"),
        )
    }
}

@Composable
private fun Chip(label: String, tag: String, onClick: () -> Unit) {
    Text(
        label, fontSize = 12.sp, color = Palette.textPrimary,
        modifier = Modifier
            .clip(CircleShape)
            .background(Palette.surfaceElevated)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 7.dp)
            .testTag(tag),
    )
}
