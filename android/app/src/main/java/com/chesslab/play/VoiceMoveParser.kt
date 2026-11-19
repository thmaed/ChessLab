package com.chesslab.play

import chesskit.Board
import chesskit.Piece

/**
 * Retrouver un coup dans une phrase DITE (« Cavalier f3 », « fou prend c6 », « petit roque »). Pendant de
 * `VoiceMoveParser.swift` (iOS), porté à l'identique — y compris les mots appris de la mesure du 19/11/2026 sur iPhone3.
 *
 * Étude « jouer ses coups à la voix » : on ne cherche pas à comprendre n'importe quelle phrase, on compare ce que la
 * reconnaissance a entendu aux SEULS coups légaux de la position. Module pur : aucun micro, aucun moteur.
 * Français d'abord ; les autres langues viendront si l'on implémente.
 */
object VoiceMoveParser {

    /** Un coup légal : UCI (« g1f3 », « e7e8q ») et SAN brute (« Nf3 », « e8=Q+ »). */
    data class Candidate(val uci: String, val san: String) {
        val from: String get() = uci.take(2)
        val to: String get() = uci.drop(2).take(2)
        val promotion: Char? get() = if (uci.length > 4) uci.last() else null
        val isCastle: Boolean get() = san.startsWith("O-O")
        val isLongCastle: Boolean get() = san.startsWith("O-O-O")
        /** K, Q, R, B, N ou P. */
        val piece: Char
            get() {
                if (isCastle) return 'K'
                val first = san.firstOrNull() ?: return 'P'
                return if (first in "KQRBN") first else 'P'
            }
    }

    sealed interface Outcome {
        data class Move(val move: Candidate) : Outcome
        /** Plusieurs coups répondent (deux cavaliers peuvent aller en d2) : il faut préciser le départ. */
        data class Ambiguous(val moves: List<Candidate>) : Outcome
        /** On a entendu un coup, mais aucun coup légal ne lui répond. */
        data object Illegal : Outcome
        data object NotUnderstood : Outcome
    }

    enum class Castle { short, long, unspecified }

    /** Ce qu'une phrase dit, avant de la confronter à la position. */
    data class Heard(
        var piece: Char? = null,
        /** Les cases entières entendues : la dernière est l'arrivée, l'avant-dernière le départ. */
        val squares: MutableList<String> = mutableListOf(),
        var fromFile: Char? = null,
        var fromRank: Char? = null,
        var castle: Castle? = null,
        var promotion: Char? = null,
        var capture: Boolean = false,
    ) {
        val isEmpty: Boolean get() = piece == null && squares.isEmpty() && castle == null
    }

    // Le vocabulaire (français) — mêmes tables qu'iOS.

    private val pieces = mapOf(
        "roi" to 'K', "rois" to 'K',
        "dame" to 'Q', "dames" to 'Q', "reine" to 'Q', "reines" to 'Q',
        "tour" to 'R', "tours" to 'R',
        "fou" to 'B', "fous" to 'B',
        "cavalier" to 'N', "cavaliers" to 'N', "chevalier" to 'N', "chevaliers" to 'N',
        "pion" to 'P', "pions" to 'P',
        "tout" to 'R', "roy" to 'K', "rouen" to 'K',
    )

    /** Des mots où la reconnaissance a FONDU une case (mesure du 19/11/2026) : on les redécoupe avant de lire. */
    private val fused = mapOf(
        "géant" to listOf("g", "1"), "indien" to listOf("d", "1"), "indéen" to listOf("d", "1"),
        "ancien" to listOf("c", "1"), "hachis" to listOf("h", "6"),
        "décède" to listOf("d", "7"), "décès" to listOf("d", "7"), "17" to listOf("d", "7"), "18" to listOf("d", "8"),
        "dix" to listOf("d"), "10" to listOf("d"),
        "bien" to listOf("b"), "angers" to listOf("g"), "of" to listOf("f"), "off" to listOf("f"),
    )
    private val captureWords = setOf("prend", "prends", "prent", "pren", "mange", "manges", "x", "prise")
    private val promotionWords = setOf("promotion", "promu", "promeut", "promouvoir")

    private val strongFiles = mapOf(
        "a" to 'a', "b" to 'b', "bé" to 'b', "c" to 'c', "cé" to 'c', "d" to 'd', "dé" to 'd', "e" to 'e', "é" to 'e',
        "f" to 'f', "effe" to 'f', "g" to 'g', "gé" to 'g', "h" to 'h', "ache" to 'h', "hache" to 'h',
    )
    private val weakFiles = mapOf(
        "à" to 'a', "ah" to 'a', "ha" to 'a',
        "bey" to 'b', "baie" to 'b', "bée" to 'b',
        "ces" to 'c', "ses" to 'c', "c'est" to 'c', "s'est" to 'c', "sait" to 'c',
        "des" to 'd', "dès" to 'd', "dais" to 'd',
        "euh" to 'e', "eux" to 'e', "eu" to 'e', "et" to 'e', "est" to 'e',
        "ef" to 'f', "effet" to 'f',
        "j'ai" to 'g', "geai" to 'g', "jet" to 'g', "j" to 'g',
        "hash" to 'h', "hach" to 'h',
    )
    private val ranks = mapOf(
        "1" to '1', "un" to '1', "une" to '1',
        "2" to '2', "deux" to '2',
        "3" to '3', "trois" to '3',
        "4" to '4', "quatre" to '4',
        "5" to '5', "cinq" to '5',
        "6" to '6', "six" to '6',
        "7" to '7', "sept" to '7', "set" to '7', "cette" to '7',
        "8" to '8', "huit" to '8',
    )
    private val writtenInitials = mapOf("c" to 'N', "f" to 'B', "t" to 'R', "d" to 'Q', "r" to 'K')

    // Les deux motifs : l'Android refuse ce que la JVM tolère (voir la mémoire du projet) — ici rien à échapper.
    private val initialThenSquare = Regex("""\b([cftdr])x?([a-h][1-8])\b""")
    private val letterThenDigit = Regex("""([a-h])([1-8])""")
    private val separators = Regex("""[^\p{L}\p{N}']+""")

    fun tokens(text: String): List<String> {
        var lowered = text.lowercase().replace('’', '\'')
        lowered = initialThenSquare.replace(lowered, "$1 $2")
        lowered = letterThenDigit.replace(lowered, "$1 $2")
        return lowered.split(separators).filter { it.isNotEmpty() }.flatMap { fused[it] ?: listOf(it) }
    }

    fun heard(text: String): Heard {
        val result = Heard()
        val lowered = text.lowercase()
        result.castle = when {
            "grand roque" in lowered || "o-o-o" in lowered || "0-0-0" in lowered -> Castle.long
            "petit roque" in lowered || "o-o" in lowered || "0-0" in lowered -> Castle.short
            "roque" in lowered -> Castle.unspecified
            else -> null
        }

        val words = tokens(text)
        var index = 0
        var promotionNext = false
        while (index < words.size) {
            val word = words[index]
            val next = words.getOrNull(index + 1)
            val afterNext = words.getOrNull(index + 2)

            val piece = pieces[word]
            if (piece != null) {
                if (promotionNext || result.squares.isNotEmpty()) {
                    // « e8 dame », « e8 promotion dame » : la pièce après la case est la promotion.
                    if (piece != 'P') result.promotion = piece
                } else if (result.piece == null) {
                    result.piece = piece
                }
                promotionNext = false
                index += 1
                continue
            }
            if (word in captureWords) { result.capture = true; index += 1; continue }
            if (word in promotionWords) { promotionNext = true; index += 1; continue }

            // Initiale et colonne collées, puis le chiffre : « FB quatre » = fou b4.
            if (result.piece == null && result.squares.isEmpty() && word.length == 2 && next != null) {
                val initial = writtenInitials[word.take(1)]
                val file = word.last()
                val rank = ranks[next]
                if (initial != null && file in "abcdefgh" && rank != null) {
                    result.piece = initial
                    result.squares += "$file$rank"
                    index += 2
                    continue
                }
            }
            // Une initiale écrite suivie d'une case complète : « C f 3 ».
            if (result.piece == null && result.squares.isEmpty() && writtenInitials[word] != null &&
                next != null && strongFiles[next] != null && afterNext != null && ranks[afterNext] != null
            ) {
                result.piece = writtenInitials[word]
                index += 1
                continue
            }

            val file = strongFiles[word] ?: weakFiles[word]
            val rankAfter = next?.let { ranks[it] }
            if (file != null && rankAfter != null) {
                result.squares += "$file$rankAfter"
                index += 2
                continue
            }
            val strong = strongFiles[word]
            if (strong != null) {
                // Une colonne seule, avant la case d'arrivée : l'indice de départ.
                if (result.squares.isEmpty()) result.fromFile = strong
                index += 1
                continue
            }
            val rank = ranks[word]
            if (rank != null && result.squares.isEmpty() && result.piece != null) result.fromRank = rank
            index += 1
        }
        return result
    }

    fun resolve(heard: Heard, candidates: List<Candidate>): Outcome {
        val castle = heard.castle
        if (castle != null && heard.squares.isEmpty()) {
            return outcome(candidates.filter {
                it.isCastle && when (castle) {
                    Castle.short -> !it.isLongCastle
                    Castle.long -> it.isLongCastle
                    Castle.unspecified -> true
                }
            })
        }
        val destination = heard.squares.lastOrNull()
        if (destination == null) {
            // La colonne s'est perdue (« Roi deux », « Dame en huit ») : pièce + rangée, si UN seul coup y répond.
            val piece = heard.piece ?: return Outcome.NotUnderstood
            val rank = heard.fromRank ?: return Outcome.NotUnderstood
            val pool = candidates.filter { !it.isCastle && it.piece == piece && it.to.last() == rank }
            return if (pool.isEmpty()) Outcome.NotUnderstood else outcome(pool)
        }

        var pool = candidates.filter { it.to == destination && !it.isCastle }
        // Le roque dit par la case du roi (« roi g1 ») reste un roque.
        pool = pool + candidates.filter { it.isCastle && it.to == destination && heard.piece == 'K' }
        if (heard.squares.size >= 2) {
            val start = heard.squares[heard.squares.size - 2]
            pool = pool.filter { it.from == start }
        }
        val piece = heard.piece
        pool = if (piece != null) {
            pool.filter { it.piece == piece }
        } else {
            // « e4 » : un pion, s'il en est un qui peut y aller ; sinon la seule pièce qui le peut.
            pool.filter { it.piece == 'P' }.ifEmpty { pool }
        }
        heard.fromFile?.let { file -> pool.filter { it.from.first() == file }.takeIf { it.isNotEmpty() }?.let { pool = it } }
        heard.fromRank?.let { rank -> pool.filter { it.from.last() == rank }.takeIf { it.isNotEmpty() }?.let { pool = it } }
        if (pool.size > 1 && pool.all { it.promotion != null }) {
            // Promotion : la pièce dite, sinon la dame (la confirmation la nomme, on peut annuler).
            val wanted = (heard.promotion ?: 'Q').lowercaseChar()
            pool = pool.filter { it.promotion == wanted }
        }
        return outcome(pool)
    }

    private fun outcome(pool: List<Candidate>): Outcome = when (pool.size) {
        0 -> Outcome.Illegal
        1 -> Outcome.Move(pool[0])
        else -> Outcome.Ambiguous(pool)
    }

    /** Les lettres qui riment en « é » se confondent à l'oreille : b, c, d, e, g. */
    private val confusable = listOf('b', 'c', 'd', 'e', 'g')

    fun resolveWithConfusions(heard: Heard, candidates: List<Candidate>): Outcome {
        val direct = resolve(heard, candidates)
        val destination = heard.squares.lastOrNull()
        if (direct != Outcome.Illegal || destination == null || destination.first() !in confusable) return direct
        val found = confusable.filter { it != destination.first() }.mapNotNull { other ->
            val variant = heard.copy(squares = heard.squares.toMutableList())
            variant.squares[variant.squares.size - 1] = "$other${destination.drop(1)}"
            (resolve(variant, candidates) as? Outcome.Move)?.move
        }
        return if (found.size == 1) Outcome.Move(found[0]) else direct
    }

    /** Plusieurs transcriptions (la meilleure d'abord) : le premier coup trouvé l'emporte, puis une ambiguïté… */
    fun resolve(transcripts: List<String>, candidates: List<Candidate>, confusions: Boolean = true): Outcome {
        val outcomes = transcripts.map { text ->
            val heard = heard(text)
            when {
                heard.isEmpty -> Outcome.NotUnderstood
                confusions -> resolveWithConfusions(heard, candidates)
                else -> resolve(heard, candidates)
            }
        }
        return outcomes.firstOrNull { it is Outcome.Move }
            ?: outcomes.firstOrNull { it is Outcome.Ambiguous }
            ?: if (Outcome.Illegal in outcomes) Outcome.Illegal else Outcome.NotUnderstood
    }

    private val pieceWords = mapOf('K' to "roi", 'Q' to "dame", 'R' to "tour", 'B' to "fou", 'N' to "cavalier", 'P' to "pion")

    /** Les façons courantes de dire un coup — indices pour la reconnaissance (EXTRA_BIASING_STRINGS). */
    fun spokenForms(candidate: Candidate): List<String> {
        if (candidate.isLongCastle) return listOf("grand roque")
        if (candidate.isCastle) return listOf("petit roque")
        val to = candidate.to
        val name = pieceWords[candidate.piece].orEmpty()
        val forms = mutableListOf("$name $to", "$name en $to")
        if ('x' in candidate.san) forms += "$name prend $to"
        if (candidate.piece == 'P') forms += to
        candidate.promotion?.let { promotion -> pieceWords[promotion.uppercaseChar()]?.let { forms += "$to $it" } }
        return forms
    }

    fun spokenForms(candidates: List<Candidate>): List<String> = candidates.flatMap { spokenForms(it) }.distinct()

    /** Les coups légaux de [board], avec leur SAN (une promotion compte quatre coups). */
    fun candidates(board: Board): List<Candidate> {
        val side = board.position.sideToMove
        val fen = board.position.fen
        // Le plateau Kotlin ne se copie pas : chaque coup essayé repart de la position.
        fun scratchBoard() = Board(chesskit.Position.fromFen(fen) ?: board.position)
        val result = mutableListOf<Candidate>()
        for (piece in board.position.pieces.filter { it.color == side }) {
            for (end in board.legalMoves(forPieceAt = piece.square)) {
                val base = piece.square.notation + end.notation
                val promotes = piece.kind == Piece.Kind.pawn && (end.rank.value == 8 || end.rank.value == 1)
                if (promotes) {
                    for (kind in listOf(Piece.Kind.queen, Piece.Kind.rook, Piece.Kind.bishop, Piece.Kind.knight)) {
                        val scratch = scratchBoard()
                        val move = scratch.move(pieceAt = piece.square, to = end) ?: continue
                        val promoted = scratch.completePromotion(of = move, to = kind)
                        result += Candidate(base + kind.notation.lowercase(), promoted.san)
                    }
                } else {
                    val scratch = scratchBoard()
                    val move = scratch.move(pieceAt = piece.square, to = end) ?: continue
                    result += Candidate(base, move.san)
                }
            }
        }
        return result
    }
}
