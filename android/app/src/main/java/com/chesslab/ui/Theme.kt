package com.chesslab.ui

import androidx.compose.ui.graphics.Color

/**
 * Palette de l'app, reprise de `ChessLab/Theme.swift`. Les valeurs sont les
 * mêmes à la virgule près : le portage doit se voir le moins possible.
 */
object Palette {
    val background = Color(0.055f, 0.063f, 0.078f)
    val backgroundDeep = Color(0.035f, 0.041f, 0.055f)
    val surface = Color(0.106f, 0.118f, 0.137f)
    val surfaceElevated = Color(0.145f, 0.161f, 0.184f)
    val stroke = Color.White.copy(alpha = 0.08f)
    val strokeStrong = Color.White.copy(alpha = 0.16f)

    val accent = Color(0.36f, 0.80f, 0.56f)
    val accentSecondary = Color(0.24f, 0.72f, 0.72f)
    val danger = Color(0.92f, 0.38f, 0.38f)
    val warning = Color(0.95f, 0.75f, 0.30f)
    val info = Color(0.36f, 0.58f, 0.95f)
    val violet = Color(0.62f, 0.51f, 0.96f)
    val rose = Color(0.96f, 0.46f, 0.62f)
    val gold = Color(0.91f, 0.62f, 0.34f)

    val textPrimary = Color.White.copy(alpha = 0.95f)
    val textSecondary = Color.White.copy(alpha = 0.58f)
    val textTertiary = Color.White.copy(alpha = 0.38f)
}

/**
 * Thème de l'échiquier, repris de `ChessLab/Board/BoardTheme.swift`.
 *
 * Comme côté iOS, les couleurs des CASES ne suivent pas le mode sombre du
 * système — c'est le reste de l'interface qui s'adapte.
 */
data class BoardTheme(
    val id: String,
    val label: String,
    val lightSquare: Color,
    val darkSquare: Color,
    val lastMoveLight: Color,
    val lastMoveDark: Color,
    val checkColor: Color,
    val selectedColor: Color,
    val legalDotColor: Color,
    val coordinateColor: Color,
) {
    companion object {
        val classic = BoardTheme(
            id = "classic", label = "Classique",
            lightSquare = Color(0.93f, 0.90f, 0.82f),
            darkSquare = Color(0.46f, 0.59f, 0.34f),
            lastMoveLight = Color(0.98f, 0.90f, 0.45f, 0.85f),
            lastMoveDark = Color(0.75f, 0.68f, 0.20f, 0.85f),
            checkColor = Color.Red.copy(alpha = 0.75f),
            selectedColor = Color.Blue.copy(alpha = 0.35f),
            legalDotColor = Color.Black.copy(alpha = 0.28f),
            coordinateColor = Color.Black.copy(alpha = 0.45f),
        )

        val walnut = classic.copy(
            id = "walnut", label = "Noyer",
            lightSquare = Color(0.87f, 0.72f, 0.53f),
            darkSquare = Color(0.55f, 0.36f, 0.20f),
            lastMoveLight = Color(0.96f, 0.80f, 0.35f, 0.85f),
            lastMoveDark = Color(0.70f, 0.55f, 0.10f, 0.85f),
        )

        val blue = classic.copy(
            id = "blue", label = "Bleu",
            lightSquare = Color(0.86f, 0.89f, 0.92f),
            darkSquare = Color(0.42f, 0.55f, 0.69f),
            lastMoveLight = Color(0.62f, 0.82f, 0.96f, 0.85f),
            lastMoveDark = Color(0.28f, 0.52f, 0.78f, 0.85f),
        )

        val contrast = BoardTheme(
            id = "contrast", label = "Contraste",
            lightSquare = Color(0.96f, 0.96f, 0.93f),
            darkSquare = Color(0.20f, 0.24f, 0.31f),
            lastMoveLight = Color(0.99f, 0.85f, 0.32f, 0.90f),
            lastMoveDark = Color(0.85f, 0.66f, 0.12f, 0.90f),
            checkColor = Color(0.95f, 0.24f, 0.30f, 0.85f),
            selectedColor = Color(0.20f, 0.55f, 0.98f, 0.45f),
            legalDotColor = Color(0.45f, 0.45f, 0.45f, 0.65f),
            coordinateColor = Color.Black.copy(alpha = 0.45f),
        )

        val all = listOf(classic, blue, walnut, contrast)
    }
}
