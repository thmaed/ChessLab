package com.chesslab.analysis

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.chesslab.ui.Palette
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Courbe d'évaluation, cliquable pour aller au coup correspondant. Pendant
 * d'`EvalCurveView.swift`.
 *
 * L'aire est SIGNÉE depuis la ligne d'équilibre : le regard voit tout de suite
 * qui est devant, sans lire d'axe. Une courbe toujours verte, quel que soit le
 * camp qui mène, ne dirait rien de tel.
 *
 * 64 dp et non 100 : la courbe sert à REPÉRER les décrochages et à y sauter,
 * pas à lire une valeur.
 */
@Composable
fun EvalCurve(
    points: List<CurvePoint>,
    currentPly: Int?,
    onSelect: (Int) -> Unit,
) {
    if (points.size < 2) return

    /**
     * L'échelle verticale S'ADAPTE à la partie au lieu d'être figée à ±10
     * pions. Figée, elle écrasait tout : une partie normale tient dans ±2, donc
     * la courbe ressemblait à un trait plat — le décrochage qu'elle est censée
     * montrer devenait invisible. Elle reste SYMÉTRIQUE, pour que le milieu
     * soit toujours l'égalité, et bornée des deux côtés.
     */
    val bound = min(10.0, max(1.5, (points.maxOfOrNull { abs(it.pawns) } ?: 0.0) * 1.15))
    val last = points.size - 1

    Canvas(
        Modifier
            .fillMaxWidth()
            .height(64.dp)
            .testTag("courbe")
            .pointerInput(points.size) {
                detectTapGestures { offset ->
                    val ply = (offset.x / size.width * last).roundToInt().coerceIn(0, last)
                    // Le point d'index i est atteint par le coup i-1.
                    onSelect(ply - 1)
                }
            }
    ) {
        fun x(ply: Int) = ply.toFloat() / last * size.width
        fun y(pawns: Double) = (0.5 - pawns / (2 * bound)).toFloat() * size.height

        val zero = y(0.0)

        // Deux aires, l'une au-dessus de l'équilibre, l'autre en dessous :
        // chacune se coupe à la ligne médiane, donc une seule couleur par côté.
        for (above in listOf(true, false)) {
            val path = Path().apply {
                moveTo(0f, zero)
                points.forEachIndexed { i, p ->
                    val value = if (above) max(0.0, p.pawns) else min(0.0, p.pawns)
                    lineTo(x(i), y(value))
                }
                lineTo(x(last), zero)
                close()
            }
            drawPath(path, (if (above) Palette.accent else Palette.info).copy(alpha = 0.28f))
        }

        val line = Path().apply {
            points.forEachIndexed { i, p -> if (i == 0) moveTo(x(i), y(p.pawns)) else lineTo(x(i), y(p.pawns)) }
        }
        drawPath(line, Palette.textPrimary.copy(alpha = 0.75f), style = Stroke(width = 1.6.dp.toPx()))

        // Ligne d'équilibre, discrète mais présente : sans elle, une aire
        // signée n'a pas de repère.
        drawLine(Palette.stroke, Offset(0f, zero), Offset(size.width, zero), strokeWidth = 1.dp.toPx())

        // Les MOMENTS CRITIQUES, épinglés. Le halo sombre les détache de l'aire.
        points.forEachIndexed { i, p ->
            val quality = p.quality ?: return@forEachIndexed
            if (!quality.marksCriticalPhase) return@forEachIndexed
            val center = Offset(x(i), y(p.pawns))
            drawCircle(Palette.background, radius = 5.dp.toPx(), center = center)
            drawCircle(quality.tint, radius = 3.5.dp.toPx(), center = center)
        }

        // Où l'on se trouve dans la partie.
        if (currentPly != null && currentPly in 0..last) {
            drawLine(
                Palette.accent.copy(alpha = 0.9f),
                Offset(x(currentPly), 0f), Offset(x(currentPly), size.height),
                strokeWidth = 1.5.dp.toPx(),
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 6f)),
            )
        }
    }
}
