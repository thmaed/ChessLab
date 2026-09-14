package com.chesslab.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.Text
import chesskit.Piece
import chesskit.Square
import com.chesslab.settings.SettingsStore

/**
 * Le bandeau des pièces prises, et l'avantage de matériel. Pendant de
 * `CapturedTrayView` (`CapturedMaterial.swift`).
 *
 * Les pièces sont celles du JEU CHOISI, pas des figurines Unicode : le
 * bandeau montrait des symboles d'une autre fonte que le plateau, et deux
 * dames n'avaient pas la même silhouette à dix centimètres d'écart.
 *
 * Les pièces d'un même type se CHEVAUCHENT, d'autant plus qu'elles sont
 * nombreuses. Une largeur fixe par groupe ne se compressait jamais : à
 * quinze prises le bandeau réclamait sa place sur une ligne qui doit aussi
 * loger un nom saisi par l'utilisateur et une pendule. Resserrer garde
 * TOUTES les pièces visibles, là où un rognage en escamoterait en silence.
 */
@Composable
fun CapturedTray(
    kinds: List<Piece.Kind>,
    /** La couleur des pièces montrées — celles qui ont été prises. */
    glyphColor: Piece.Color,
    advantage: Int,
    modifier: Modifier = Modifier,
) {
    if (kinds.isEmpty() && advantage <= 0) return
    val settings by SettingsStore.state.collectAsState()
    val glyph = 15.dp
    val overlap = when {
        kinds.size < 6 -> 9.dp
        kinds.size < 10 -> 7.dp
        else -> 5.dp
    }

    Row(modifier.height(20.dp), horizontalArrangement = Arrangement.spacedBy(3.dp), verticalAlignment = Alignment.CenterVertically) {
        groups(kinds).forEach { (kind, count) ->
            Box(Modifier.width(glyph + overlap * (count - 1)).height(glyph)) {
                repeat(count) { index ->
                    Image(
                        painter = painterResource(
                            drawableFor(Piece(kind, glyphColor, Square("a1")), settings.pieceSetId)
                        ),
                        contentDescription = null,
                        modifier = Modifier.size(glyph).offset(x = overlap * index),
                    )
                }
            }
        }
        if (advantage > 0) {
            Spacer(Modifier.width(2.dp))
            Text("+$advantage", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Palette.accent)
        }
    }
}

/** Les pièces identiques CONSÉCUTIVES, regroupées pour se chevaucher. */
private fun groups(kinds: List<Piece.Kind>): List<Pair<Piece.Kind, Int>> {
    val result = mutableListOf<Pair<Piece.Kind, Int>>()
    for (kind in kinds) {
        val last = result.lastOrNull()
        if (last != null && last.first == kind) result[result.lastIndex] = kind to last.second + 1
        else result += kind to 1
    }
    return result
}
