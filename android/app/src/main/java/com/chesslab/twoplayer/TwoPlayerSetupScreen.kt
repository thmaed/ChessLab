package com.chesslab.twoplayer

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AllInclusive
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.FlagCircle
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.ScreenRotation
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import com.chesslab.R
import com.chesslab.play.TimeLimitSection
import com.chesslab.play.rememberTimeLimit
import com.chesslab.ui.BasicTextFieldWithPlaceholder
import com.chesslab.ui.CardShape
import com.chesslab.ui.ChipButton
import com.chesslab.ui.Palette
import com.chesslab.ui.SettingsSection
import com.chesslab.ui.accentGradient

/**
 * La configuration d'une partie à deux. Pendant de `TwoPlayerSetupView`.
 *
 * Elle existe pour une raison qui n'a rien d'esthétique : **les noms**. Une
 * partie rangée dans la bibliothèque sous « Blancs — Noirs » se confond avec
 * toutes les autres ; sous « Thierry — Camille », on la retrouve. Et les noms
 * sont MÉMORISÉS d'une partie sur l'autre : deux joueurs récurrents ne les
 * retapent pas à chaque fois.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TwoPlayerSetupScreen(
    /** La position imposée par un autre mode, ou `null` pour une partie neuve. */
    startFen: String? = null,
    onStart: (TwoPlayerSettings) -> Unit,
) {
    val context = LocalContext.current
    // Les réglages d'usine portent des noms VIDES : au tout premier
    // lancement, on les remplit avec « Blancs » / « Noirs » dans la langue
    // active plutôt que de laisser deux champs vides. Un nom déjà enregistré,
    // lui, reste intouché — c'est ce que la personne a tapé une fois.
    val saved = remember { TwoPlayerSettingsStore.load(context) }
    val defaultWhite = stringResource(R.string.color_white)
    val defaultBlack = stringResource(R.string.color_black)
    var white by remember { mutableStateOf(saved?.whiteName?.ifBlank { defaultWhite } ?: defaultWhite) }
    var black by remember { mutableStateOf(saved?.blackName?.ifBlank { defaultBlack } ?: defaultBlack) }
    var rotation by remember { mutableStateOf(saved?.rotation ?: TwoPlayerSettings.RotationMode.faceToFace) }
    val timeLimit = rememberTimeLimit(
        saved?.timeControlId ?: "none", saved?.customMinutes ?: 15, saved?.customIncrementSeconds ?: 0, "twoPlayer",
    )

    Column(Modifier.fillMaxSize()) {
      Column(
        Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
      ) {
        SettingsSection(stringResource(R.string.two_setup_players), Icons.Default.People, Palette.info) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                // Le champ porte son étiquette AU-DESSUS et non seulement en
                // filigrane : dès qu'un nom est tapé, le filigrane disparaît
                // et plus rien ne dit lequel des deux champs est celui des
                // Blancs.
                NameField(stringResource(R.string.color_white), white, "nom-blancs") { white = it }
                NameField(stringResource(R.string.color_black), black, "nom-noirs") { black = it }
                // Retaper deux noms pour les échanger est la friction typique
                // d'une revanche décidée sur place.
                Row(
                    Modifier
                        .clip(CircleShape)
                        .clickable {
                            val swap = white
                            white = black
                            black = swap
                        }
                        .padding(vertical = 6.dp, horizontal = 4.dp)
                        .testTag("inverser-couleurs"),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Default.SwapHoriz, null, tint = Palette.accent, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(
                        stringResource(R.string.two_setup_swap),
                        fontSize = 13.sp, fontWeight = FontWeight.Medium, color = Palette.accent,
                    )
                }
            }
        }

        SettingsSection(stringResource(R.string.two_setup_rotation), Icons.Default.ScreenRotation, Palette.violet) {
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
                            .background(if (active) Palette.violet.copy(alpha = 0.16f) else Palette.surface)
                            .clickable { rotation = mode }
                            .padding(horizontal = 12.dp, vertical = 10.dp)
                            .testTag("rotation-${mode.name}"),
                    ) {
                        Text(
                            stringResource(titre),
                            fontSize = 14.sp,
                            color = if (active) Palette.violet else Palette.textPrimary,
                        )
                        Text(stringResource(note), fontSize = 11.sp, color = Palette.textTertiary)
                    }
                }
            }
        }

        TimeLimitSection(timeLimit, Palette.warning)

        Spacer(Modifier.height(4.dp))
      }

      // Le bouton reste EN BAS et toujours visible, comme sur « Nouvelle
      // partie » : c'est la seule action de l'écran, elle ne doit pas se
      // mériter en défilant. (Sur iOS il vit dans la barre de navigation,
      // au même titre : toujours sous les yeux.)
      Box(
          Modifier
              .fillMaxWidth()
              .background(Palette.background.copy(alpha = 0.94f))
              .padding(horizontal = 16.dp, vertical = 14.dp)
      ) {
          Text(
              stringResource(R.string.setup_start),
              fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
              modifier = Modifier
                  .fillMaxWidth()
                  .clip(CircleShape)
                  .background(com.chesslab.ui.tintedActionGradient(Palette.info))
                  .clickable {
                      val settings = TwoPlayerSettings(
                          whiteName = white.trim().ifEmpty { defaultWhite },
                          blackName = black.trim().ifEmpty { defaultBlack },
                          rotation = rotation,
                          timeControlId = timeLimit.effectiveId,
                          customMinutes = timeLimit.customMinutes,
                          customIncrementSeconds = timeLimit.customIncrement,
                          startFen = startFen,
                      )
                      timeLimit.remember()
                      TwoPlayerSettingsStore.save(context, settings)
                      onStart(settings)
                  }
                  .padding(vertical = 14.dp)
                  .testTag("commencer"),
              textAlign = androidx.compose.ui.text.style.TextAlign.Center,
          )
      }
    }
}

/** Un nom de joueur, son étiquette au-dessus. */
@Composable
private fun NameField(label: String, value: String, tag: String, onChange: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            label.uppercase(),
            fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Palette.textTertiary,
        )
        BasicTextFieldWithPlaceholder(value = value, placeholder = label, tag = tag, onChange = onChange)
    }
}

/** Un nombre qu'on règle à la main, entre deux bornes. */
@Composable
private fun Stepper(title: String, value: Int, range: IntRange, tag: String, onChange: (Int) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(title, fontSize = 13.sp, color = Palette.textPrimary, modifier = Modifier.weight(1f))
        listOf("−" to -1, "+" to 1).forEach { (glyph, delta) ->
            Text(
                glyph, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Palette.accent,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(Palette.surfaceElevated)
                    .clickable { onChange((value + delta).coerceIn(range)) }
                    .padding(horizontal = 14.dp, vertical = 4.dp)
                    .testTag("$tag-$delta"),
            )
            if (delta == -1) {
                Text(
                    "$value", fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                    color = Palette.textPrimary,
                    modifier = Modifier.padding(horizontal = 12.dp).testTag(tag),
                )
            }
        }
    }
}
