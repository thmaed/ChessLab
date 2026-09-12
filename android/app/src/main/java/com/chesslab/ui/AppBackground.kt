package com.chesslab.ui

import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Shader
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageShader
import androidx.compose.ui.graphics.ShaderBrush
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.draw.drawBehind
import kotlin.math.hypot
import kotlin.random.Random

/**
 * Le fond signature de l'app, porté d'`AppBackground` (`Theme.swift`).
 *
 * La base sombre du thème, puis trois halos très diffus — émeraude en haut à
 * gauche, violet à mi-hauteur, bleu en bas à droite — qui donnent de la
 * profondeur sans jamais gêner la lecture. Les rayons sont des FRACTIONS de la
 * diagonale et non des tailles fixes : sur une tablette, des valeurs calibrées
 * pour un téléphone resteraient collées aux coins et laisseraient le centre
 * plat.
 *
 * Un voile de grain à 3,5 % termine le tout. Un grand dégradé sombre affiche
 * des BANDES sur un écran large — les paliers de quantification du noir
 * deviennent visibles — et un bruit très faible les casse. C'est le remède
 * classique, et il ne coûte qu'une tuile de 128×128 générée une seule fois.
 */
@Composable
fun AppBackground(content: @Composable BoxScope.() -> Unit) {
    val grain = remember { grainBrush() }
    Box(
        Modifier
            .fillMaxSize()
            .drawBehind {
                val diagonal = hypot(size.width, size.height)
                drawRect(
                    Brush.verticalGradient(
                        listOf(Palette.background, Palette.backgroundDeep),
                        startY = 0f, endY = size.height,
                    )
                )
                halo(Palette.accent, 0.12f, 0.12f, -0.02f, diagonal * 0.495f)
                halo(Palette.violet, 0.05f, -0.08f, 0.55f, diagonal * 0.41f)
                halo(Palette.info, 0.07f, 1.05f, 1.02f, diagonal * 0.56f)
                drawRect(grain)
            },
        content = content,
    )
}

/** Un halo radial, centré en fractions de l'écran comme côté iOS. */
private fun DrawScope.halo(color: Color, alpha: Float, x: Float, y: Float, radius: Float) {
    drawRect(
        Brush.radialGradient(
            colors = listOf(color.copy(alpha = alpha), Color.Transparent),
            center = Offset(size.width * x, size.height * y),
            radius = radius,
        )
    )
}

/**
 * La tuile de grain : du bruit monochrome très faible, répété.
 *
 * `Random` sans graine donnerait un grain différent à chaque recomposition, ce
 * qui scintillerait ; la graine est donc fixe.
 */
private fun grainBrush(): ShaderBrush {
    val side = 128
    val random = Random(20260912)
    val pixels = IntArray(side * side) {
        val v = random.nextInt(0, 256)
        // 3,5 % d'opacité : presque invisible, et c'est le but.
        (0x09 shl 24) or (v shl 16) or (v shl 8) or v
    }
    val bitmap = Bitmap.createBitmap(pixels, side, side, Bitmap.Config.ARGB_8888)
    return ShaderBrush(ImageShader(bitmap.asImageBitmap(), TileMode.Repeated, TileMode.Repeated))
}
