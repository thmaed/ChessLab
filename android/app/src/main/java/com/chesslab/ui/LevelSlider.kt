package com.chesslab.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.roundToInt

/**
 * Le niveau : le chiffre (qui porte le réglage réel), le nom du palier, le
 * curseur teinté, les deux bornes, et au besoin une ligne d'échelle.
 */
@Composable
fun LevelSlider(
    title: String,
    valueLabel: String,
    tierLabel: String?,
    value: Double,
    range: ClosedFloatingPointRange<Float>,
    lowLabel: String,
    highLabel: String,
    tint: androidx.compose.ui.graphics.Color,
    note: String?,
    onChange: (Double) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary)
            Spacer(Modifier.weight(1f))
            Text(
                valueLabel, fontSize = 20.sp, fontWeight = FontWeight.Bold,
                color = Palette.textPrimary, modifier = Modifier.testTag("niveau"),
            )
        }
        tierLabel?.let {
            Text(
                it, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = tint,
                modifier = Modifier.fillMaxWidth().testTag("palier"),
                textAlign = androidx.compose.ui.text.style.TextAlign.End,
            )
        }
        Slider(
            value = value.toFloat().coerceIn(range.start, range.endInclusive),
            onValueChange = { onChange(((it / 10).roundToInt() * 10).toDouble().coerceIn(range.start.toDouble(), range.endInclusive.toDouble())) },
            valueRange = range,
            colors = SliderDefaults.colors(thumbColor = tint, activeTrackColor = tint),
            modifier = Modifier.testTag("curseur-niveau"),
        )
        Row {
            Text(lowLabel, fontSize = 12.sp, color = Palette.textTertiary)
            Spacer(Modifier.weight(1f))
            Text(highLabel, fontSize = 12.sp, color = Palette.textTertiary)
        }
        note?.let { Text(it, fontSize = 11.sp, color = Palette.textTertiary) }
    }
}
