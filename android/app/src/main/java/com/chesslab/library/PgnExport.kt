package com.chesslab.library

import android.content.Context
import chesskit.Game
import chesskit.Piece
import chesskit.Position
import com.chesslab.R
import java.util.Calendar
import java.util.Date
import java.util.GregorianCalendar
import java.util.Locale

/**
 * Un PGN **complet et rechargeable**. Pendant de `PGNExport.swift`.
 *
 * Un testeur a partagé des parties par courriel côté iOS le 27/09/2026 et n'a
 * reçu que des suites de coups — « no pgn tags, no result ». Android avait le
 * même défaut, à moitié : [GameRecorder.save] posait quelques balises à la
 * FIN de la partie (sans Site ni Round), mais un export PENDANT la partie
 * n'en portait aucune. Les sept balises obligatoires (*Seven Tag Roster*)
 * sortent désormais de tous les exports, et le résultat clôt aussi les coups
 * (« * » pour une partie en cours).
 *
 * Les balises se posent sur une COPIE des tags, jamais sur ceux de l'appelant :
 * c'est `chesskit` qui sérialise, dans l'ordre du standard.
 */
object PgnExport {

    /**
     * Les en-têtes d'une partie exportée. `date` à `null` = inconnue, notée
     * « ????.??.?? » comme le veut le standard — une partie importée sans
     * date ne doit pas hériter de celle du jour où on la relit.
     */
    data class Metadata(
        val event: String,
        val site: String = "ChessLab",
        val date: Date? = Date(),
        val round: String = "-",
        val white: String,
        val black: String,
        /** « * » (partie en cours ou inconnue) si `null`. */
        val result: String? = null,
        val variant: String? = null,
    ) {
        companion object {
            /** Contre le moteur : la couleur de l'utilisateur range son nom. */
            fun vsEngine(
                context: Context, userColor: Piece.Color, engineName: String,
                result: String?, date: Date = Date(),
            ): Metadata {
                val you = PlayerName.you(context)
                val engine = PlayerName.display(context, engineName, PlayerName.computer(context))
                return Metadata(
                    event = context.getString(R.string.route_play),
                    date = date,
                    white = if (userColor == Piece.Color.white) you else engine,
                    black = if (userColor == Piece.Color.black) you else engine,
                    result = result,
                )
            }

            /** À deux sur le même appareil : les noms viennent des réglages. */
            fun twoPlayer(
                context: Context, whiteName: String, blackName: String,
                result: String?, date: Date = Date(),
            ) = Metadata(
                event = context.getString(R.string.route_two_players),
                date = date,
                white = PlayerName.display(context, whiteName, PlayerName.white(context)),
                black = PlayerName.display(context, blackName, PlayerName.black(context)),
                result = result,
            )
        }
    }

    /**
     * Le PGN à partager, à copier ou à ranger. Sans [metadata], seuls
     * `SetUp`/`FEN` sont éventuellement ajoutés : c'est le contrat d'origine.
     */
    fun pgn(game: Game, metadata: Metadata? = null): String {
        val original = game.tags
        val filled = copyOf(original)
        metadata?.let { fill(filled, it) }
        declareStartingPosition(game, filled)
        // On prête les tags complétés le temps de sérialiser, et on rend les
        // siens à l'appelant quoi qu'il arrive.
        game.tags = filled
        try {
            return game.pgn
        } finally {
            game.tags = original
        }
    }

    /**
     * Les lignes de balises d'un PGN assemblé À LA MAIN — les variantes que
     * `chesskit` ne sait pas tenir (canard, coup volé, Fairy-Stockfish).
     * Sept balises d'abord, puis la variante et sa position de départ.
     */
    fun tagLines(
        event: String, white: String, black: String, result: String?,
        variant: String? = null, startFen: String? = null, date: Date = Date(),
    ): List<String> = buildList {
        add(tag("Event", event))
        add(tag("Site", "ChessLab"))
        add(tag("Date", pgnDate(date)))
        add(tag("Round", "-"))
        add(tag("White", white))
        add(tag("Black", black))
        add(tag("Result", result ?: "*"))
        variant?.let { add(tag("Variant", it)) }
        startFen?.let {
            add(tag("SetUp", "1"))
            add(tag("FEN", it))
        }
    }

    /** « AAAA.MM.JJ », grégorien, chiffres arabes — quelle que soit la locale. */
    fun pgnDate(date: Date): String {
        val c = GregorianCalendar().apply { time = date }
        return String.format(
            Locale.ROOT, "%04d.%02d.%02d",
            c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH),
        )
    }

    // ---------------------------------------------------------------- détails

    /** Ne remplit QUE ce qui manque : un PGN importé garde ses en-têtes. */
    private fun fill(tags: Game.Tags, m: Metadata) {
        fun missing(v: String) = v.isBlank() || v.trim() == "?"
        if (missing(tags.event)) tags.event = sanitized(m.event)
        if (missing(tags.site)) tags.site = sanitized(m.site)
        if (missing(tags.date)) tags.date = m.date?.let(::pgnDate) ?: "????.??.??"
        if (missing(tags.round)) tags.round = sanitized(m.round)
        if (missing(tags.white)) tags.white = sanitized(m.white)
        if (missing(tags.black)) tags.black = sanitized(m.black)
        if (missing(tags.result)) tags.result = m.result ?: "*"
        m.variant?.let { if (tags.other["Variant"] == null) tags.other["Variant"] = sanitized(it) }
    }

    private fun declareStartingPosition(game: Game, tags: Game.Tags) {
        val start = game.positions[game.startingIndex] ?: return
        if (start.fen == Position.standard.fen || tags.fen.isNotBlank()) return
        tags.fen = start.fen
        tags.setUp = "1"
    }

    private fun copyOf(t: Game.Tags) = Game.Tags().also { c ->
        t.named.forEach { (name, value) -> if (value.isNotEmpty()) c.set(name, value) }
        c.other = LinkedHashMap(t.other)
    }

    private fun tag(name: String, value: String) = "[$name \"${sanitized(value)}\"]"

    /** Ni guillemet, ni crochet, ni saut de ligne : la balise resterait ouverte. */
    private fun sanitized(value: String) = value
        .replace(Regex("[\\r\\n\\t]"), " ")
        .replace(Regex("[\"\\[\\]]"), "")
        .trim()
}
