package com.chesslab.ui

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalView
import com.chesslab.R

/**
 * Verbalise un coup à partir de son SAN — « cavalier en f 3, échec ».
 * Pendant de `MoveNarration.swift`.
 *
 * Quelqu'un qui utilise un lecteur d'écran ne VOIT pas le plateau bouger :
 * sans annonce, il ne sait pas ce que l'adversaire vient de jouer. La case
 * est épelée (« e 4 » et non « e4 ») pour une lecture non ambiguë.
 */
object MoveNarration {

    fun describe(context: Context, san: String): String {
        if (san.startsWith("O-O-O")) return decorate(context, context.getString(R.string.narration_castle_long), san)
        if (san.startsWith("O-O")) return decorate(context, context.getString(R.string.narration_castle_short), san)

        val first = san.firstOrNull() ?: return san
        val named = pieceName(context, first)
        val phrase = named ?: context.getString(R.string.narration_pawn)
        val rest = if (named != null) san.drop(1) else san

        val isCapture = rest.contains('x')
        // La destination : les deux caractères juste avant un éventuel =, + ou #.
        val core = rest.takeWhile { it != '=' && it != '+' && it != '#' }
        val destination = spell(core.takeLast(2))

        var sentence = context.getString(
            if (isCapture) R.string.narration_takes else R.string.narration_to,
            phrase, destination,
        )

        val equals = san.indexOf('=')
        if (equals >= 0 && equals + 1 < san.length) {
            pieceName(context, san[equals + 1])?.let {
                sentence = context.getString(R.string.narration_promotion, sentence, it)
            }
        }
        return decorate(context, sentence, san)
    }

    /** « Blancs : cavalier en f 3 » — qui joue, puis quoi. */
    fun announcement(context: Context, who: String, san: String): String =
        context.getString(R.string.narration_move_by, who, describe(context, san))

    private fun decorate(context: Context, base: String, san: String): String = when {
        san.endsWith("#") -> context.getString(R.string.narration_mate, base)
        san.endsWith("+") -> context.getString(R.string.narration_check, base)
        else -> base
    }

    private fun pieceName(context: Context, letter: Char): String? = when (letter) {
        'N' -> context.getString(R.string.narration_knight)
        'B' -> context.getString(R.string.narration_bishop)
        'R' -> context.getString(R.string.narration_rook)
        'Q' -> context.getString(R.string.narration_queen)
        'K' -> context.getString(R.string.narration_king)
        else -> null
    }

    /** Épelle une case (« e4 » → « e 4 ») pour une lecture non ambiguë. */
    private fun spell(square: String): String = square.map { it.toString() }.joinToString(" ")
}

/**
 * Dit [message] au lecteur d'écran dès qu'il change. `null` ne dit rien.
 *
 * `announceForAccessibility` est l'équivalent Android de
 * `UIAccessibility.post(notification: .announcement,…)` : il ne fait rien
 * quand aucun lecteur d'écran n'écoute, ce qui évite d'avoir à le demander.
 */
@Composable
fun Announce(announcement: Announcement?) {
    val view = LocalView.current
    LaunchedEffect(announcement?.id) {
        val text = announcement?.text
        if (!text.isNullOrBlank()) view.announceForAccessibility(text)
    }
}

/**
 * Une annonce et son NUMÉRO. Le numéro n'est pas une coquetterie : deux coups
 * identiques à la suite (« pion en e 4 » deux fois dans deux parties) ne se
 * distingueraient pas par leur texte, et la seconde annonce ne partirait pas.
 */
data class Announcement(val id: Int, val text: String)
