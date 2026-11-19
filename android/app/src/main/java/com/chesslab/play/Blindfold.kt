package com.chesslab.play

import android.content.Context
import android.media.AudioAttributes
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
 *
 * La voix sort sur le volume MULTIMÉDIA, que le mode silencieux de la sonnerie ne coupe pas — c'est ce qu'iOS a dû
 * aller chercher le 19/11/2026 (sa session ambiante rendait la voix muette en mode Silencieux).
 *
 * La voix se CHOISIT (19/11/2026, comme iOS) parmi celles INSTALLÉES pour la langue de l'app. Écart assumé : Android
 * ne dit ni le sexe ni un vrai nom de ses voix (des codes comme « fr-fr-x-frc-local ») — elles s'appellent donc
 * « Voix 1, Voix 2… », et on les reconnaît en les écoutant, puisque les choisir les fait entendre. Les voix qui
 * demandent le réseau sont écartées (promesse « aucun réseau »). Le choix est propre à l'appareil.
 */
object BlindfoldVoice {
    private const val PREFS = "blindfold"
    private const val KEY_VOICE = "voiceName"

    /** Ce qu'on retient d'une voix du moteur — de quoi trier et filtrer sans le moteur (tests JVM). */
    data class VoiceInfo(
        val name: String, val language: String, val country: String,
        val needsNetwork: Boolean, val installed: Boolean,
    )

    /** Une voix proposée : son nom technique (la clé), son numéro d'affichage, sa région si la langue en a plusieurs. */
    data class Option(val name: String, val number: Int, val region: String?)

    /**
     * Les voix proposées pour [language] (« fr ») : installées, hors réseau, numérotées dans l'ordre de leur nom
     * pour qu'une voix garde son numéro d'une fois sur l'autre.
     */
    fun optionsOf(voices: Collection<VoiceInfo>, language: String): List<Option> {
        val kept = voices
            .filter { it.language == language && !it.needsNetwork && it.installed }
            .sortedBy { it.name }
        val manyRegions = kept.map { it.country }.toSet().size > 1
        return kept.mapIndexed { index, voice ->
            Option(
                voice.name, index + 1,
                if (manyRegions && voice.country.isNotEmpty())
                    Locale("", voice.country).getDisplayCountry(Locale(language)) else null,
            )
        }
    }

    private var tts: TextToSpeech? = null
    private var ready = false
    private val waiting = mutableListOf<(TextToSpeech) -> Unit>()

    /** Le moteur, une fois prêt ; le premier appel le démarre et les suivants attendent avec lui. */
    private fun withEngine(context: Context, action: (TextToSpeech) -> Unit) {
        val engine = tts
        if (engine != null && ready) { action(engine); return }
        waiting += action
        if (engine != null) return
        tts = TextToSpeech(context.applicationContext) { status ->
            ready = status == TextToSpeech.SUCCESS
            val started = tts
            if (ready && started != null) {
                started.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                waiting.forEach { it(started) }
            }
            waiting.clear()
        }
    }

    private fun infosOf(engine: TextToSpeech): List<VoiceInfo> = engine.voices.orEmpty().map { voice ->
        VoiceInfo(
            voice.name, voice.locale.language, voice.locale.country, voice.isNetworkConnectionRequired,
            TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED !in voice.features.orEmpty(),
        )
    }

    /** Les voix proposées pour la langue de l'app, rendues sur le fil principal quand le moteur est prêt. */
    fun options(context: Context, language: String, onReady: (List<Option>) -> Unit) =
        withEngine(context) { onReady(optionsOf(infosOf(it), Locale.forLanguageTag(language).language)) }

    fun chosenVoice(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_VOICE, "").orEmpty()

    /** Retient la voix (vide = celle du système) et la fait entendre sur un coup d'exemple. */
    fun choose(context: Context, name: String, language: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY_VOICE, name).apply()
        say(context, com.chesslab.ui.MoveNarration.describe(context, "Nf3"), language)
    }

    fun say(context: Context, text: String, language: String) {
        val chosen = chosenVoice(context)
        withEngine(context) { engine -> speakNow(engine, text, language, chosen) }
    }

    private fun speakNow(engine: TextToSpeech, text: String, language: String, chosen: String) {
        val locale = Locale.forLanguageTag(language)
        engine.language = locale
        // La voix choisie si elle est encore là et dans la langue de l'app ; sinon celle du système.
        engine.voices.orEmpty()
            .firstOrNull { it.name == chosen && it.locale.language == locale.language && !it.isNetworkConnectionRequired }
            ?.let { engine.voice = it }
        engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "blindfold")
    }

    fun stop() { tts?.stop() }
}
