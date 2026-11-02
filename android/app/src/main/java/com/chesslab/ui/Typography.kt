package com.chesslab.ui

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp

/**
 * La typographie de l'app : celle de Material 3, SANS son interligne ni son
 * espacement de lettres.
 *
 * Material impose à chaque style un interligne FIXE en sp (24 sp pour le corps
 * de texte, 0,5 sp d'espacement) et l'app écrit presque partout
 * `Text(fontSize = 12.sp)` : la police rétrécit, l'interligne reste à 24 sp. Un
 * texte de 12 sp se retrouvait donc avec deux fois l'interligne d'iOS, et
 * chaque tuile ou carte contenant du texte sur plusieurs lignes grandissait
 * d'autant (relevé du 01/11/2026, Galaxy A16 contre iPhone 17 Pro, mêmes
 * polices à la même taille).
 *
 * L'interligne est ici PROPORTIONNEL (`em`) : il suit la taille de police que
 * l'écran demande. 1,3 est le rapport d'iOS pour le texte courant (12,5 pt sur
 * 16 pt, 17 pt sur 22 pt) ; l'espacement de lettres est nul, comme sur iOS.
 */
private fun TextStyle.tight() = copy(lineHeight = 1.3.em, letterSpacing = 0.sp)

val ChessLabTypography: Typography = Typography().let { m ->
    m.copy(
        displayLarge = m.displayLarge.tight(),
        displayMedium = m.displayMedium.tight(),
        displaySmall = m.displaySmall.tight(),
        headlineLarge = m.headlineLarge.tight(),
        headlineMedium = m.headlineMedium.tight(),
        headlineSmall = m.headlineSmall.tight(),
        titleLarge = m.titleLarge.tight(),
        titleMedium = m.titleMedium.tight(),
        titleSmall = m.titleSmall.tight(),
        bodyLarge = m.bodyLarge.tight(),
        bodyMedium = m.bodyMedium.tight(),
        bodySmall = m.bodySmall.tight(),
        labelLarge = m.labelLarge.tight(),
        labelMedium = m.labelMedium.tight(),
        labelSmall = m.labelSmall.tight(),
    )
}
