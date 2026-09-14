package com.chesslab.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.EaseIn
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import kotlin.random.Random

/**
 * La pluie de confettis d'une victoire. Pendant de `CelebrationView`
 * (`Theme.swift`).
 *
 * Trente-six rectangles qui tombent en tournant, chacun avec son retard, sa
 * dérive et sa rotation — les mêmes bornes qu'iOS, pour que les deux apps
 * fêtent pareil.
 *
 * **« Réduire les animations »** : une pluie de confettis est exactement ce
 * que ce réglage système existe pour supprimer. On ne dessine alors RIEN —
 * atténuer ne suffirait pas, c'est le mouvement lui-même qui gêne. Côté
 * Android le réglage se lit dans `Settings.Global`, où une échelle
 * d'animation à zéro dit « pas d'animations ».
 */
@Composable
fun CelebrationOverlay(modifier: Modifier = Modifier, pieceCount: Int = 36) {
    if (rememberReduceMotion()) return

    val palette = listOf(Palette.accent, Palette.info, Palette.warning, Palette.violet, Palette.rose)
    val confetti = remember {
        val random = Random(System.nanoTime())
        List(pieceCount) { index ->
            Confetto(
                xStart = random.nextFloat() * 0.90f + 0.05f,
                color = palette[index % palette.size],
                size = 6f + random.nextFloat() * 5f,
                delay = random.nextFloat() * 0.35f,
                rotation = random.nextFloat() * 440f - 220f,
                drift = random.nextFloat() * 80f - 40f,
            )
        }
    }

    val progress = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        progress.animateTo(1f, tween(durationMillis = 1_950, easing = EaseIn))
    }
    Canvas(modifier.fillMaxSize()) {
        val t = progress.value
        confetti.forEach { piece ->
            // Le retard de chacun, ramené sur la durée utile : 1,6 s de chute
            // dans une enveloppe de 1,95 s, comme iOS.
            val local = ((t - piece.delay * 0.35f) / 0.82f).coerceIn(0f, 1f)
            if (local <= 0f) return@forEach
            val width = piece.size.dp.toPx()
            val height = width * 0.5f
            val x = size.width * piece.xStart + piece.drift.dp.toPx() * local
            val y = -40.dp.toPx() + (size.height + 80.dp.toPx()) * local
            rotate(degrees = piece.rotation * local, pivot = Offset(x, y)) {
                drawRoundRect(
                    color = piece.color.copy(alpha = 1f - local),
                    topLeft = Offset(x - width / 2f, y - height / 2f),
                    size = Size(width, height),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(2.dp.toPx()),
                )
            }
        }
    }
}

private data class Confetto(
    val xStart: Float,
    val color: Color,
    val size: Float,
    val delay: Float,
    val rotation: Float,
    val drift: Float,
)
