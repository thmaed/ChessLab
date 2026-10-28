package com.chesslab.play

import android.content.Context
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.FlagCircle
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.discovery.discoveryAnchor
import com.chesslab.ui.ChipButton
import com.chesslab.ui.Palette
import com.chesslab.ui.SettingsSection
import com.chesslab.ui.ToggleRow

/**
 * Le choix de cadence d'un écran de réglage, avec son interrupteur « Limite de
 * temps » : éteint par défaut, et les cadences ne s'affichent que lorsqu'il est
 * allumé. Pendant de `TimeLimitSelection` (iOS) — partagé par les écrans
 * ordinateur, deux joueurs et variantes.
 *
 * Les réglages enregistrés ne changent pas : l'identifiant vaut `"none"`
 * quand la limite est éteinte. La DERNIÈRE cadence choisie est gardée à part
 * (clé propre à chaque écran), pour qu'éteindre puis rallumer l'interrupteur la
 * retrouve, et que l'app se souvienne de la préférence entre deux parties.
 */
class TimeLimitState(
    private val context: Context,
    savedId: String,
    minutes: Int,
    increment: Int,
    private val memoryKey: String,
) {
    var enabled by mutableStateOf(savedId != "none")
    /** Jamais `"none"` : c'est l'interrupteur qui dit « sans limite ». */
    var category by mutableStateOf(FALLBACK.category)
    var presetId by mutableStateOf(FALLBACK.id)
    var customMinutes by mutableStateOf(minutes)
    var customIncrement by mutableStateOf(increment)

    init {
        val id = if (enabled) savedId
        else context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(memoryKey, null) ?: ""
        if (id == "custom") {
            category = "custom"
        } else {
            val found = TimeControl.presets.firstOrNull { it.id == id && it.category != "none" }
            if (found != null) {
                category = found.category
                presetId = found.id
            }
        }
    }

    val isCustom: Boolean get() = category == "custom"

    /** La cadence choisie, même éteinte — ce qu'on rallumera. */
    val rememberedId: String get() = if (isCustom) "custom" else presetId

    /** L'identifiant de la partie : `"none"` tant que la limite est éteinte. */
    val effectiveId: String get() = if (enabled) rememberedId else "none"

    val hasClock: Boolean get() = enabled && (if (isCustom) customMinutes > 0 else TimeControl.byId(presetId).hasClock)

    /**
     * Change de famille en gardant TOUJOURS une cadence valide. Retaper la
     * famille déjà choisie ne fait rien : on retomberait sinon sur sa première
     * cadence en effaçant celle qu'on venait de régler.
     */
    fun select(newCategory: String) {
        if (newCategory == "none" || newCategory == category) return
        category = newCategory
        if (newCategory != "custom") presetId = TimeControl.presets.first { it.category == newCategory }.id
    }

    /** À appeler au lancement : garde la cadence choisie pour la prochaine fois. */
    fun remember() {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(memoryKey, rememberedId).apply()
    }

    companion object {
        private const val PREFS = "time_limit"
        /** Cadence proposée la première fois qu'on allume l'interrupteur. */
        val FALLBACK = TimeControl.byId("rapid_10_0")
        /** Les familles proposées une fois la limite allumée. */
        val categories = listOf("bullet", "blitz", "rapid", "classical", "custom")
    }
}

@Composable
fun rememberTimeLimit(savedId: String, minutes: Int, increment: Int, memoryKey: String): TimeLimitState {
    val context = LocalContext.current
    return remember { TimeLimitState(context, savedId, minutes, increment, memoryKey) }
}

/** Une teinte par famille, du plus nerveux au plus posé (comme iOS). */
fun timeCategoryTint(category: String): Color = when (category) {
    "bullet" -> Palette.rose
    "blitz" -> Palette.warning
    "rapid" -> Palette.accent
    "classical" -> Palette.info
    "custom" -> Palette.violet
    else -> Palette.textSecondary
}

private fun timeCategoryLabel(category: String): Int = when (category) {
    "bullet" -> R.string.time_bullet
    "blitz" -> R.string.time_blitz
    "rapid" -> R.string.time_rapid
    "classical" -> R.string.time_classical
    "custom" -> R.string.time_custom
    else -> R.string.time_none
}

/** Un repère visuel qui se lit plus vite que le mot, du plus rapide au plus lent. */
private fun timeCategoryIcon(category: String) = when (category) {
    "bullet" -> Icons.Default.Speed
    "blitz" -> Icons.Default.Bolt
    "classical" -> Icons.Default.FlagCircle
    "custom" -> Icons.Default.Tune
    else -> Icons.Default.Timer
}

/** Un nombre qu'on règle à la main, entre deux bornes. */
@Composable
private fun TimeStepper(title: String, value: Int, range: IntRange, tag: String, onChange: (Int) -> Unit) {
    Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
        Text(title, fontSize = 13.sp, color = Palette.textPrimary, modifier = Modifier.weight(1f))
        listOf("−" to -1, "+" to 1).forEach { (glyph, delta) ->
            Text(
                glyph, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = timeCategoryTint("custom"),
                modifier = Modifier
                    .clip(CircleShape)
                    .background(Palette.surfaceElevated)
                    .clickable { onChange((value + delta).coerceIn(range)) }
                    .padding(horizontal = 14.dp, vertical = 4.dp)
                    .testTag("$tag-$delta"),
            )
            if (delta == -1) {
                Text(
                    "$value", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary,
                    modifier = Modifier.padding(horizontal = 12.dp).testTag(tag),
                )
            }
        }
    }
}

/**
 * La section « Limite de temps » : un interrupteur, puis — allumé seulement —
 * les familles de cadence et leurs préréglages, chacune dans sa couleur.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TimeLimitSection(state: TimeLimitState, tint: Color = Palette.accent) {
    SettingsSection(
        stringResource(R.string.setup_time_limit), Icons.Default.Timer, tint,
        modifier = Modifier.discoveryAnchor(com.chesslab.discovery.DiscoverySpot.timeLimit),
    ) {
        ToggleRow(stringResource(R.string.setup_time_limit), state.enabled, "limite-de-temps", tint) { state.enabled = it }
        if (state.enabled) {
            Spacer(Modifier.height(10.dp))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                TimeLimitState.categories.forEach { c ->
                    ChipButton(
                        stringResource(timeCategoryLabel(c)), state.category == c,
                        Modifier.testTag("cadence-$c"), icon = timeCategoryIcon(c), tint = timeCategoryTint(c),
                    ) { state.select(c) }
                }
            }
            // Ce que la pendule coûte, dit là où on la choisit (28/10/2026), comme iOS.
            Spacer(Modifier.height(10.dp))
            Text(
                stringResource(R.string.setup_clock_no_takeback), fontSize = 12.sp, color = Palette.textSecondary,
                modifier = Modifier.testTag("pendule-sans-reprise"),
            )
            Spacer(Modifier.height(10.dp))
            if (state.isCustom) {
                TimeStepper(stringResource(R.string.setup_custom_minutes), state.customMinutes, 1..180, "minutes-perso") {
                    state.customMinutes = it
                }
                Spacer(Modifier.height(8.dp))
                TimeStepper(stringResource(R.string.setup_custom_increment), state.customIncrement, 0..60, "increment-perso") {
                    state.customIncrement = it
                }
            } else {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    TimeControl.presets.filter { it.category == state.category }.forEach { tc ->
                        ChipButton(
                            tc.label, state.presetId == tc.id, Modifier.testTag("preset-${tc.id}"),
                            tint = timeCategoryTint(tc.category),
                        ) { state.presetId = tc.id }
                    }
                }
            }
        } else {
            Spacer(Modifier.height(8.dp))
            Text(stringResource(R.string.setup_no_clock), fontSize = 12.sp, color = Palette.textSecondary)
        }
    }
}
