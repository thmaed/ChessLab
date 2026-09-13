package com.chesslab.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * La pastille de résultat : ivoire pour les Blancs, ardoise pour les Noirs,
 * mi-l'un mi-l'autre pour la nulle. Pendant de `GameResultPill.swift` — le
 * MÊME langage partout où un résultat s'affiche, plutôt qu'un « 1/2-1/2 »
 * sur fond émeraude ici et un autre là.
 */
@Composable
fun GameResultPill(raw: String?, modifier: Modifier = Modifier) {
    val style = when (raw) {
        "1-0" -> Style.white
        "0-1" -> Style.black
        "1/2-1/2", "1/2" -> Style.draw
        else -> Style.unknown
    }
    val foreground = when (style) {
        Style.white -> Palette.background
        Style.black, Style.draw -> Palette.textPrimary
        Style.unknown -> Palette.textSecondary
    }
    val background: Brush = when (style) {
        Style.white -> Brush.linearGradient(listOf(ivory, ivory))
        Style.black -> Brush.linearGradient(listOf(slate, slate))
        // Sur une pastille mi-ivoire mi-ardoise, l'ivoire est atténué de son
        // côté pour que le texte clair s'y lise encore.
        Style.draw -> Brush.horizontalGradient(
            0f to ivory.copy(alpha = 0.55f), 0.5f to ivory.copy(alpha = 0.55f), 0.5f to slate, 1f to slate,
        )
        Style.unknown -> Brush.linearGradient(listOf(Color.Transparent, Color.Transparent))
    }
    Box(
        modifier
            // Largeur commune : sans elle, « 1/2 » et « ? » rétrécissent la
            // pastille et les dates ne s'alignent plus d'une ligne à l'autre.
            .widthIn(min = 34.dp)
            .clip(CircleShape)
            .background(background)
            // Le liseré n'est utile qu'aux fonds sombres ou absents.
            .then(if (style != Style.white) Modifier.border(1.dp, Color.White.copy(alpha = 0.22f), CircleShape) else Modifier)
            .padding(horizontal = 6.dp, vertical = 2.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            when (style) {
                Style.white -> "1-0"
                Style.black -> "0-1"
                // « 1/2-1/2 » est deux fois plus large et déformait l'alignement.
                Style.draw -> "1/2"
                Style.unknown -> "?"
            },
            fontSize = 10.sp, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold, color = foreground,
        )
    }
}

private enum class Style { white, black, draw, unknown }

/** Ivoire de la pièce claire — pas le blanc du texte. */
private val ivory = Color(0.898f, 0.882f, 0.839f)
/** Ardoise de la pièce sombre, plus claire que le fond de carte pour rester une forme et non un trou. */
private val slate = Color(0.110f, 0.133f, 0.180f)
