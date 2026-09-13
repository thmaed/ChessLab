package com.chesslab.lab

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.ui.Palette
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Le bilan d'une série : les chiffres, et ce qu'ils veulent dire.
 *
 * Chaque tuile s'ouvre sur son explication — c'est le point du mode. Un écart
 * Elo sans son intervalle, ou un LOS sans qu'on sache qu'il ignore les nulles,
 * se lit de travers : on croit avoir tranché après six parties.
 */
@Composable
fun LabStatsPanel(ui: LabUiState) {
    val stats = ui.stats
    var opened by remember { mutableStateOf<Int?>(null) }

    val elo = stats.eloDifference
    val ci = stats.elo95ConfidenceInterval
    val eloText = when {
        elo == null -> "—"
        ci == null -> signed(elo)
        else -> "${signed(elo)} ± ${((ci.second - ci.first) / 2).roundToInt()}"
    }

    Column(Modifier.fillMaxWidth().testTag("bilan-detaille")) {
        Row(Modifier.height(IntrinsicSize.Min), Arrangement.spacedBy(8.dp)) {
            StatTile(
                stringResource(R.string.lab_stat_score),
                if (stats.games == 0) "—" else "${stats.scorePercent.roundToInt()} %",
                "tuile-score", opened == 0,
            ) { opened = if (opened == 0) null else 0 }
            StatTile(
                stringResource(R.string.lab_stat_elo), eloText,
                "tuile-elo", opened == 1,
            ) { opened = if (opened == 1) null else 1 }
            StatTile(
                stringResource(R.string.lab_stat_los),
                if (stats.winsA + stats.winsB == 0) "—"
                else "${(stats.likelihoodOfSuperiority * 100).roundToInt()} %",
                "tuile-los", opened == 2,
            ) { opened = if (opened == 2) null else 2 }
        }
        Spacer(Modifier.height(8.dp))
        Row(Modifier.height(IntrinsicSize.Min), Arrangement.spacedBy(8.dp)) {
            StatTile(
                stringResource(R.string.lab_stat_wdl),
                "${stats.winsA} · ${stats.draws} · ${stats.winsB}",
                "tuile-vnd", opened == 3,
            ) { opened = if (opened == 3) null else 3 }
            StatTile(
                stringResource(R.string.lab_stat_moves),
                if (stats.games == 0) "—" else "${stats.averageMoves.roundToInt()}",
                "tuile-coups", opened == 4,
            ) { opened = if (opened == 4) null else 4 }
            StatTile(
                stringResource(R.string.lab_stat_games), "${stats.games}",
                "tuile-parties", opened == 5,
            ) { opened = if (opened == 5) null else 5 }
        }

        opened?.let { index ->
            Spacer(Modifier.height(8.dp))
            Explanation(
                stringResource(
                    when (index) {
                        0 -> R.string.lab_explain_score
                        1 -> R.string.lab_explain_elo
                        2 -> R.string.lab_explain_los
                        3 -> R.string.lab_explain_wdl
                        4 -> R.string.lab_explain_moves
                        else -> R.string.lab_explain_games
                    }
                )
            )
        }

        if (stats.games > 0) {
            Spacer(Modifier.height(12.dp))
            SectionLabel(stringResource(R.string.lab_distribution)) {
                opened = if (opened == 6) null else 6
            }
            Spacer(Modifier.height(6.dp))
            DistributionBar(stats)
            if (opened == 6) { Spacer(Modifier.height(8.dp)); Explanation(stringResource(R.string.lab_explain_distribution)) }
        }

        if (stats.games >= 2) {
            Spacer(Modifier.height(12.dp))
            SectionLabel(stringResource(R.string.lab_progression)) {
                opened = if (opened == 7) null else 7
            }
            Spacer(Modifier.height(6.dp))
            ProgressionCurve(LabStats.progression(ui.completed))
            if (opened == 7) { Spacer(Modifier.height(8.dp)); Explanation(stringResource(R.string.lab_explain_progression)) }
        }
    }
}

/** « +12 » ou « −40 » : le signe fait partie de l'information. */
private fun signed(elo: Double): String {
    val rounded = elo.roundToInt()
    return if (rounded >= 0) "+$rounded" else "−${abs(rounded)}"
}

@Composable
private fun RowScope.StatTile(
    label: String,
    value: String,
    tag: String,
    open: Boolean,
    onClick: () -> Unit,
) {
    Column(
        Modifier
            .weight(1f)
            .fillMaxHeight()
            .clip(RoundedCornerShape(10.dp))
            .background(Palette.surface)
            .border(
                1.dp,
                if (open) Palette.accent.copy(alpha = 0.5f) else Palette.stroke,
                RoundedCornerShape(10.dp),
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 8.dp, vertical = 9.dp)
            .testTag(tag),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(value, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary)
        Spacer(Modifier.height(2.dp))
        Text(
            label, fontSize = 9.sp, color = Palette.textTertiary,
            textAlign = TextAlign.Center, maxLines = 2,
        )
    }
}

@Composable
private fun Explanation(text: String) {
    Text(
        text,
        fontSize = 11.sp, color = Palette.textSecondary, lineHeight = 16.sp,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Palette.surfaceElevated)
            .padding(12.dp)
            .testTag("explication"),
    )
}

@Composable
private fun SectionLabel(text: String, onClick: () -> Unit) {
    Text(
        text,
        fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Palette.textSecondary,
        modifier = Modifier.clickable(onClick = onClick),
    )
}

/** V · N · D vue comme une barre : la part de chacun, d'un coup d'œil. */
@Composable
private fun DistributionBar(stats: LabStats) {
    val total = stats.games.coerceAtLeast(1).toFloat()
    Row(
        Modifier
            .fillMaxWidth()
            .height(12.dp)
            .clip(RoundedCornerShape(6.dp))
            .testTag("repartition"),
    ) {
        if (stats.winsA > 0) Box(Modifier.weight(stats.winsA / total).fillMaxHeight().background(Palette.accent))
        if (stats.draws > 0) Box(Modifier.weight(stats.draws / total).fillMaxHeight().background(Palette.textTertiary))
        if (stats.winsB > 0) Box(Modifier.weight(stats.winsB / total).fillMaxHeight().background(Palette.danger))
    }
}

/**
 * Le score cumulé de A, avec sa bande de confiance.
 *
 * La ligne des 50 % est tracée : tant que la bande la chevauche, la série n'a
 * rien tranché. C'est l'information qu'on vient chercher, et elle ne se lit
 * pas sur un chiffre.
 */
@Composable
private fun ProgressionCurve(points: List<LabProgressPoint>) {
    if (points.size < 2) return
    Canvas(Modifier.fillMaxWidth().height(72.dp).testTag("progression")) {
        val last = points.size - 1
        fun x(index: Int) = index.toFloat() / last * size.width
        fun y(percent: Double) = (1 - percent / 100).toFloat() * size.height

        // La bande de confiance, d'abord : la courbe se lit par-dessus.
        val band = Path().apply {
            moveTo(x(0), y(points[0].ciHigh))
            points.forEachIndexed { i, p -> lineTo(x(i), y(p.ciHigh)) }
            for (i in last downTo 0) lineTo(x(i), y(points[i].ciLow))
            close()
        }
        drawPath(band, Palette.accent.copy(alpha = 0.16f))

        // L'égalité : la ligne qu'il faut quitter pour avoir tranché.
        drawLine(
            Palette.textTertiary.copy(alpha = 0.5f),
            Offset(0f, y(50.0)), Offset(size.width, y(50.0)), strokeWidth = 1f,
        )

        val curve = Path().apply {
            moveTo(x(0), y(points[0].scorePercent))
            points.forEachIndexed { i, p -> lineTo(x(i), y(p.scorePercent)) }
        }
        drawPath(curve, Palette.accent, style = androidx.compose.ui.graphics.drawscope.Stroke(width = 2.5f))
    }
}
