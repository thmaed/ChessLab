package com.chesslab.play

import android.content.Context
import android.speech.tts.TextToSpeech
import androidx.annotation.StringRes
import chesskit.Piece
import com.chesslab.R
import com.chesslab.ui.PieceDisplay
import com.chesslab.ui.PieceMask
import java.util.Locale

/**
 * Partie À L'AVEUGLE contre l'ordinateur (17/11/2026). Pendant de `Blindfold.swift`. Les quatre niveaux du
 * mail aux testeurs (plus les disques GRIS, ajoutés le 18/11), du plus facile au plus dur ; décisions de l'utilisateur : les quatre, disques À LA
 * COULEUR au niveau « Cases occupées », coup d'œil en MAINTENANT le doigt (chaque appui compte), voix
 * éteinte par défaut.
 *
 * Ce que le mode coupe, à tous les niveaux : points de coups légaux (ceux d'une tour s'arrêtent devant une
 * pièce cachée), indice, alerte de gaffe, barre d'évaluation. La liste des coups reste.
 */
enum class BlindfoldLevel(@StringRes val titleRes: Int, @StringRes val detailRes: Int) {
    off(R.string.blind_off, R.string.blind_off_detail),
    occupiedSquares(R.string.blind_occupied, R.string.blind_occupied_detail),
    /** Un disque GRIS à la place de chaque pièce : ni à qui, ni laquelle (demande de l'utilisateur, 18/11/2026). */
    occupiedSquaresGrey(R.string.blind_occupied_grey, R.string.blind_occupied_grey_detail),
    opponentHidden(R.string.blind_opponent_hidden, R.string.blind_opponent_hidden_detail),
    ownHidden(R.string.blind_own_hidden, R.string.blind_own_hidden_detail),
    allHidden(R.string.blind_all_hidden, R.string.blind_all_hidden_detail);

    /** Ce que le plateau montre, vu du camp [user]. */
    fun mask(user: Piece.Color): PieceMask = when (this) {
        off -> PieceMask.None
        occupiedSquares -> PieceMask(discs = true)
        occupiedSquaresGrey -> PieceMask(greyDiscs = true)
        opponentHidden -> PieceMask(hidden = setOf(user.opposite))
        ownHidden -> PieceMask(hidden = setOf(user))
        allHidden -> PieceMask(hidden = setOf(Piece.Color.white, Piece.Color.black))
    }

    /** On ne fait glisser que les pièces qu'on VOIT. */
    fun canDrag(user: Piece.Color): Boolean =
        mask(user).display(Piece(Piece.Kind.king, user, chesskit.Square("a1"))) == PieceDisplay.glyph

    companion object {
        /** Les niveaux proposés, dans l'ordre de difficulté. */
        val levels = listOf(occupiedSquares, occupiedSquaresGrey, opponentHidden, ownHidden, allHidden)

        fun fromName(name: String?): BlindfoldLevel = entries.firstOrNull { it.name == name } ?: off
    }
}

/**
 * Un coup d'œil reste affiché AU MOINS [MINIMUM_MS], même après un appui bref : en dessous, l'échiquier
 * clignotait sans qu'on ait le temps de rien voir (demande de l'utilisateur, 17/11/2026). Pendant de
 * `PlayViewModel.minimumPeek` (iOS).
 */
object PeekTiming {
    const val MINIMUM_MS = 700L

    /** Ce qu'il reste à montrer après un relâchement, pour atteindre [MINIMUM_MS]. */
    fun remainingMs(pressedAt: Long, releasedAt: Long): Long = (MINIMUM_MS - (releasedAt - pressedAt)).coerceAtLeast(0L)
}

/**
 * Les coups de l'adversaire lus à voix haute — synthèse vocale de l'APPAREIL (aucune permission réseau),
 * dans la langue de l'app. Pendant de `BlindfoldVoice` (iOS). Si aucune voix n'est installée pour cette
 * langue, le système retombe sur la sienne, ou se tait.
 */
object BlindfoldVoice {
    private var tts: TextToSpeech? = null
    private var ready = false

    fun say(context: Context, text: String, language: String) {
        val engine = tts ?: TextToSpeech(context.applicationContext) { status ->
            ready = status == TextToSpeech.SUCCESS
            if (ready) speakNow(text, language)
        }.also { tts = it }
        if (ready) speakNow(text, language)
    }

    private fun speakNow(text: String, language: String) {
        val engine = tts ?: return
        engine.language = Locale.forLanguageTag(language)
        engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "blindfold")
    }

    fun stop() { tts?.stop() }
}
