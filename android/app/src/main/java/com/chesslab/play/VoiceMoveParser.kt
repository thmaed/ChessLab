package com.chesslab.play

import chesskit.Board
import chesskit.Piece

/**
 * Retrouver un coup dans une phrase DITE (« Cavalier f3 », « fou prend c6 », « petit roque »). Pendant de
 * `VoiceMoveParser.swift` (iOS), porté à l'identique — y compris les mots appris de la mesure du 19/11/2026 sur iPhone3.
 *
 * Étude « jouer ses coups à la voix » : on ne cherche pas à comprendre n'importe quelle phrase, on compare ce que la
 * reconnaissance a entendu aux SEULS coups légaux de la position. Module pur : aucun micro, aucun moteur.
 *
 * Les CINQ langues de l'app (décision du 19/11/2026) : un [Vocabulary] par langue. Le français a été mesuré sur vraie
 * voix (51 essais) et porte les mots appris de cette mesure ; les autres partent des mêmes règles.
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
        /**
         * La reconnaissance HÉSITE : ses alternatives désignent des coups légaux DIFFÉRENTS, à égalité de voix (« a3 »
         * ou « e3 »). Le meilleur d'abord. Rien ne se joue : on demande (pendant d'iOS, 21/11/2026).
         */
        data class Conflicting(val moves: List<Candidate>) : Outcome
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
        /** « cavalier b d2 », « tour 1 d1 » : une colonne ou une rangée de départ. */
        var fromFile: Char? = null,
        var fromRank: Char? = null,
        var castle: Castle? = null,
        var promotion: Char? = null,
        var capture: Boolean = false,
    ) {
        val isEmpty: Boolean get() = piece == null && squares.isEmpty() && castle == null
    }

    // Les vocabulaires — mêmes tables qu'iOS.

    /**
     * Les mots d'une langue. Lettre « SÛRE » : un mot qui ne peut guère être autre chose qu'une colonne ; lettre
     * « DOUTEUSE » : un mot courant qui sonne comme une lettre (« c'est », l'article « a » anglais, la préposition « a »
     * espagnole ou italienne) — comptée seulement juste avant un chiffre, jamais comme indice de départ.
     */
    class Vocabulary(
        val pieces: Map<String, Char>,
        /** Des mots où la reconnaissance FOND une case (« géant » = g1) : redécoupés avant lecture. */
        val fused: Map<String, List<String>>,
        val captureWords: Set<String>,
        val promotionWords: Set<String>,
        val strongFiles: Map<String, Char>,
        val weakFiles: Map<String, Char>,
        val ranks: Map<String, Char>,
        /** Les initiales de la notation écrite dans cette langue (« C f3 », « Sf3 »). */
        val writtenInitials: Map<String, Char>,
        val shortCastle: List<String>,
        val longCastle: List<String>,
        val anyCastle: List<String>,
        /** « annule », « reprends » : reprendre son dernier coup. */
        val undo: List<String>,
        /** Pour les indices donnés à la reconnaissance : le nom de chaque pièce, « en », « prend ». */
        val pieceNames: Map<Char, String>,
        val to: String,
        val takes: String,
        val shortCastleName: String,
        val longCastleName: String,
        /**
         * Le roque DÉFORMÉ par la reconnaissance, lu sur les mots COLLÉS : « petit roque » devient « potiro » sur le
         * Galaxy (21/11/2026) — un mot que nulle liste n'attrape, d'où ce filet. Sans effet si le roque n'est pas
         * légal : la réponse est alors « coup impossible », pas un coup au hasard.
         */
        val fuzzyShortCastle: Regex? = null,
        val fuzzyLongCastle: Regex? = null,
    ) {
        // Android refuse ce que la JVM tolère (voir la mémoire du projet) : ici seulement des lettres dans la classe.
        internal val initialThenSquare =
            Regex("""\b([${writtenInitials.keys.sorted().joinToString("")}])x?([a-h][1-8])\b""")
        // L'initiale écrite, la colonne de départ et la case d'arrivée, tout collé (« The1 » = tour h, e1).
        internal val initialThenFileThenSquare =
            Regex("""\b([${writtenInitials.keys.sorted().joinToString("")}])([a-h])([a-h][1-8])\b""")
    }

    /** L'alphabet radio vaut dans toutes les langues : un filet pour les lettres difficiles (« Foxtrot 3 »). */
    private val radioAlphabet = mapOf(
        "alpha" to 'a', "alfa" to 'a', "bravo" to 'b', "charlie" to 'c', "delta" to 'd', "echo" to 'e', "écho" to 'e',
        "foxtrot" to 'f', "golf" to 'g', "hotel" to 'h', "hôtel" to 'h',
    )

    private val digits = (1..8).associate { "$it" to ('0' + it) }

    val french = Vocabulary(
        pieces = mapOf(
            "roi" to 'K', "rois" to 'K', "dame" to 'Q', "dames" to 'Q', "reine" to 'Q', "reines" to 'Q',
            "tour" to 'R', "tours" to 'R', "fou" to 'B', "fous" to 'B',
            "cavalier" to 'N', "cavaliers" to 'N', "chevalier" to 'N', "chevaliers" to 'N', "pion" to 'P', "pions" to 'P',
            // Entendus le 19/11 (mesure sur iPhone3) : « Tout en cinq » pour « Tour en e5 », « Roy », « Rouen ».
            "tout" to 'R', "roy" to 'K', "rouen" to 'K', "plus" to 'P', "faux" to 'B'),
        // Mesure du 19/11/2026, 51 essais : « en g1 » → « géant », « en d1 » → « indien », « en c1 » → « ancien »,
        // « en h6 » → « hachis », « d7 » → « décède », « 17 » (dix-sept), « b1 » → « bien un », « en g » → « Angers ».
        fused = mapOf(
            "géant" to listOf("g", "1"), "indien" to listOf("d", "1"), "indéen" to listOf("d", "1"),
            "ancien" to listOf("c", "1"), "hachis" to listOf("h", "6"),
            "décède" to listOf("d", "7"), "décès" to listOf("d", "7"), "17" to listOf("d", "7"), "18" to listOf("d", "8"),
            "dix" to listOf("d"), "10" to listOf("d"),
            "bien" to listOf("b"), "angers" to listOf("g"), "of" to listOf("f"), "off" to listOf("f"), "détroit" to listOf("d", "3"), "detroit" to listOf("d", "3")),
        captureWords = setOf("prend", "prends", "prent", "pren", "mange", "manges", "x", "prise"),
        promotionWords = setOf("promotion", "promu", "promeut", "promouvoir"),
        strongFiles = mapOf(
            "a" to 'a', "b" to 'b', "bé" to 'b', "c" to 'c', "cé" to 'c', "d" to 'd', "dé" to 'd', "e" to 'e', "é" to 'e',
            "f" to 'f', "effe" to 'f', "g" to 'g', "gé" to 'g', "h" to 'h', "ache" to 'h', "hache" to 'h',
        ),
        weakFiles = mapOf(
            "à" to 'a', "ah" to 'a', "ha" to 'a', "bey" to 'b', "baie" to 'b', "bée" to 'b',
            "ces" to 'c', "ses" to 'c', "c'est" to 'c', "s'est" to 'c', "sait" to 'c', "des" to 'd', "dès" to 'd', "dais" to 'd',
            "euh" to 'e', "eux" to 'e', "eu" to 'e', "et" to 'e', "est" to 'e', "ef" to 'f', "effet" to 'f',
            // « e4 » entendu « Au quatre » / « O quatre », sur iPhone3 et sur l'iPhone XS (20/11/2026).
            "au" to 'e', "o" to 'e',
            // Galaxy A16, 21/11/2026 : « e4 » reconnu « OK 4 » / « ok quatre » (Samsung).
            "ok" to 'e', "okay" to 'e', "okey" to 'e',
            "j'ai" to 'g', "geai" to 'g', "jet" to 'g', "j" to 'g', "hash" to 'h', "hach" to 'h', "les" to 'd'),
        ranks = mapOf(
            "un" to '1', "une" to '1', "deux" to '2', "trois" to '3', "quatre" to '4', "cinq" to '5', "six" to '6',
            "sept" to '7', "set" to '7', "cette" to '7', "huit" to '8',
        ),
        writtenInitials = mapOf("c" to 'N', "f" to 'B', "t" to 'R', "d" to 'Q', "r" to 'K'),
        // Entendus le 20/11 en partie sur iPhone3 : « Petit rock », « Roi, Petit roc », « P rock », « Petitoc ».
        shortCastle = listOf("petit roque", "petit-roque", "petit roc", "petit rock", "p rock", "petitoc"),
        longCastle = listOf("grand roque", "grand-roque", "grand roc", "grand rock"),
        anyCastle = listOf("roque", "roc", "rock"),
        undo = listOf("annule", "annuler", "annulé", "reprends", "reprendre", "reprend le coup", "retour"),
        pieceNames = mapOf('K' to "roi", 'Q' to "dame", 'R' to "tour", 'B' to "fou", 'N' to "cavalier", 'P' to "pion"),
        to = "en", takes = "prend", shortCastleName = "petit roque", longCastleName = "grand roque",
        // Seulement des lettres dans les classes : Android refuse ce que la JVM tolère.
        fuzzyShortCastle = Regex("^p[eéoa]t[ií]+t?r[oôa]c?k?q?u?e?$"),
        fuzzyLongCastle = Regex("^gr[aoe]n?d?r[oôa]c?k?q?u?e?$"),
    )

    val english = Vocabulary(
        pieces = mapOf(
            "king" to 'K', "kings" to 'K', "queen" to 'Q', "queens" to 'Q', "rook" to 'R', "rooks" to 'R',
            "bishop" to 'B', "bishops" to 'B', "knight" to 'N', "knights" to 'N', "night" to 'N', "nights" to 'N',
            "pawn" to 'P', "pawns" to 'P',
        ),
        fused = mapOf("before" to listOf("b", "4"), "rotates" to listOf("rook", "takes"), "shade" to listOf("h", "8")),
        captureWords = setOf("takes", "take", "captures", "capture", "x", "times"),
        promotionWords = setOf("promotes", "promote", "promotion", "equals"),
        strongFiles = mapOf(
            "b" to 'b', "bee" to 'b', "c" to 'c', "see" to 'c', "cee" to 'c', "d" to 'd', "dee" to 'd', "e" to 'e',
            "f" to 'f', "ef" to 'f', "g" to 'g', "gee" to 'g', "h" to 'h', "aitch" to 'h',
        ),
        weakFiles = mapOf("a" to 'a', "ay" to 'a', "eh" to 'a', "be" to 'b', "sea" to 'c', "jee" to 'g', "age" to 'h'),
        ranks = mapOf(
            "one" to '1', "won" to '1', "two" to '2', "to" to '2', "too" to '2', "three" to '3', "tree" to '3',
            "four" to '4', "for" to '4', "fore" to '4', "five" to '5', "six" to '6', "seven" to '7', "eight" to '8', "ate" to '8',
        ),
        writtenInitials = mapOf("n" to 'N', "b" to 'B', "r" to 'R', "q" to 'Q', "k" to 'K'),
        shortCastle = listOf(
            "castles kingside", "castle kingside", "kingside castle", "short castle", "castle short",
            "castles short", "king side", "castles king size", "castle skin side"),
        longCastle = listOf(
            "castles queenside", "castle queenside", "queenside castle", "long castle", "castle long",
            "castles long", "queen side", "castles queen size", "castle's queenside", "castle's queen side"),
        anyCastle = listOf("castle", "castles", "castling"),
        undo = listOf("undo", "take back", "takeback", "take it back", "cancel", "i do", "undue", "under", "and do"),
        pieceNames = mapOf('K' to "king", 'Q' to "queen", 'R' to "rook", 'B' to "bishop", 'N' to "knight", 'P' to "pawn"),
        to = "to", takes = "takes", shortCastleName = "castles kingside", longCastleName = "castles queenside",
    )

    val spanish = Vocabulary(
        pieces = mapOf(
            "rey" to 'K', "reyes" to 'K', "dama" to 'Q', "damas" to 'Q', "reina" to 'Q', "torre" to 'R', "torres" to 'R',
            "alfil" to 'B', "alfiles" to 'B', "caballo" to 'N', "caballos" to 'N', "peón" to 'P', "peon" to 'P', "peones" to 'P', "zorro" to 'R'),
        fused = mapOf("centro" to listOf("c", "3")),
        captureWords = setOf("come", "comes", "captura", "toma", "por", "x"),
        promotionWords = setOf("corona", "promociona", "promoción", "promocion"),
        strongFiles = mapOf(
            "b" to 'b', "c" to 'c', "d" to 'd', "e" to 'e', "f" to 'f', "efe" to 'f', "g" to 'g', "h" to 'h',
            "hache" to 'h', "ache" to 'h',
        ),
        weakFiles = mapOf(
            "a" to 'a', "ah" to 'a', "be" to 'b', "ve" to 'b', "ce" to 'c', "se" to 'c', "de" to 'd', "ge" to 'g', "je" to 'g', "ne" to 'd'),
        ranks = mapOf(
            "uno" to '1', "una" to '1', "un" to '1', "dos" to '2', "tres" to '3', "cuatro" to '4', "cinco" to '5',
            "seis" to '6', "siete" to '7', "ocho" to '8',
        ),
        writtenInitials = mapOf("c" to 'N', "a" to 'B', "t" to 'R', "d" to 'Q', "r" to 'K'),
        shortCastle = listOf("enroque corto", "en roque corto", "en bloque corto", "entró que cortó", "el bloque corto", "el brote corto"),
        longCastle = listOf("enroque largo", "en roque largo", "en bloque largo", "en broque largo"),
        anyCastle = listOf("enroque", "enroca"),
        undo = listOf("deshacer", "deshaz", "anula", "anular", "atrás", "atras"),
        pieceNames = mapOf('K' to "rey", 'Q' to "dama", 'R' to "torre", 'B' to "alfil", 'N' to "caballo", 'P' to "peón"),
        to = "a", takes = "come", shortCastleName = "enroque corto", longCastleName = "enroque largo",
    )

    val german = Vocabulary(
        pieces = mapOf(
            "könig" to 'K', "koenig" to 'K', "dame" to 'Q', "turm" to 'R', "türme" to 'R', "läufer" to 'B', "laeufer" to 'B',
            "springer" to 'N', "pferd" to 'N', "bauer" to 'P', "bauern" to 'P', "tom" to 'R', "baue" to 'P', "springen" to 'N', "spring" to 'N'),
        fused = mapOf("definiert" to listOf("d", "4"), "definieren" to listOf("d", "4")),
        captureWords = setOf("schlägt", "schlaegt", "nimmt", "x", "mal"),
        promotionWords = setOf("umwandlung", "wandelt", "verwandelt"),
        strongFiles = mapOf(
            "a" to 'a', "b" to 'b', "be" to 'b', "c" to 'c', "ce" to 'c', "zeh" to 'c', "d" to 'd', "de" to 'd', "e" to 'e',
            "f" to 'f', "ef" to 'f', "g" to 'g', "ge" to 'g', "h" to 'h', "ha" to 'h',
        ),
        weakFiles = mapOf("beh" to 'b', "tse" to 'c', "dee" to 'd', "eh" to 'e', "eff" to 'f', "geh" to 'g', "hah" to 'h', "die" to 'd'),
        ranks = mapOf(
            "eins" to '1', "ein" to '1', "zwei" to '2', "zwo" to '2', "drei" to '3', "vier" to '4', "fünf" to '5',
            "fuenf" to '5', "sechs" to '6', "sieben" to '7', "acht" to '8',
        ),
        writtenInitials = mapOf("s" to 'N', "l" to 'B', "t" to 'R', "d" to 'Q', "k" to 'K'),
        shortCastle = listOf("kurze rochade", "rochade kurz", "kleine rochade", "kurze rockade", "rockade kurz", "kleine rockade"),
        longCastle = listOf("lange rochade", "rochade lang", "große rochade", "grosse rochade", "lange rockade", "rockade lang", "große rockade", "grosse rockade"),
        anyCastle = listOf("rochade", "rochiert", "rockade"),
        undo = listOf("zurück", "zurueck", "rückgängig", "rueckgaengig", "nimm zurück", "abbrechen"),
        pieceNames = mapOf('K' to "König", 'Q' to "Dame", 'R' to "Turm", 'B' to "Läufer", 'N' to "Springer", 'P' to "Bauer"),
        to = "nach", takes = "schlägt", shortCastleName = "kurze Rochade", longCastleName = "lange Rochade",
    )

    val italian = Vocabulary(
        pieces = mapOf(
            "re" to 'K', "donna" to 'Q', "regina" to 'Q', "torre" to 'R', "torri" to 'R', "alfiere" to 'B', "alfieri" to 'B',
            "cavallo" to 'N', "cavalli" to 'N', "pedone" to 'P', "pedoni" to 'P', "benone" to 'P'),
        // Galaxy A16, 21/11/2026 : « alfiere b cinque » entendu « alfierebbe 5 » / « fierebbe 5 ».
        fused = mapOf("alfierebbe" to listOf("alfiere", "b"), "fierebbe" to listOf("alfiere", "b"), "citroën" to listOf("c", "3"), "citroen" to listOf("c", "3"), "dietro" to listOf("d", "3")),
        captureWords = setOf("prende", "mangia", "cattura", "per", "x"),
        promotionWords = setOf("promozione", "promuove"),
        strongFiles = mapOf(
            "b" to 'b', "bi" to 'b', "c" to 'c', "d" to 'd', "f" to 'f', "effe" to 'f', "g" to 'g', "gi" to 'g',
            "h" to 'h', "acca" to 'h',
        ),
        weakFiles = mapOf("a" to 'a', "ci" to 'c', "di" to 'd', "e" to 'e', "è" to 'e', "ben" to 'b'),
        ranks = mapOf(
            "uno" to '1', "un" to '1', "due" to '2', "tre" to '3', "quattro" to '4', "cinque" to '5', "sei" to '6',
            "sette" to '7', "otto" to '8',
        ),
        writtenInitials = mapOf("c" to 'N', "a" to 'B', "t" to 'R', "d" to 'Q', "r" to 'K'),
        // Galaxy A16, 21/11/2026 : « arrocco corto » entendu « a Rocco corto », « Rocco corto », « a poco corto », « corto ».
        shortCastle = listOf("arrocco corto", "rocco corto", "a rocco corto", "a poco corto", "arocco corto", "corto", "marocco corto", "rocco cordo", "a rocco cordo"),
        longCastle = listOf("arrocco lungo", "rocco lungo", "a rocco lungo", "arocco lungo", "lungo", "marocco lungo", "al rocco lungo"),
        anyCastle = listOf("arrocco", "arrocca", "rocco"),
        undo = listOf("annulla", "indietro", "riprendi"),
        pieceNames = mapOf('K' to "re", 'Q' to "donna", 'R' to "torre", 'B' to "alfiere", 'N' to "cavallo", 'P' to "pedone"),
        to = "in", takes = "prende", shortCastleName = "arrocco corto", longCastleName = "arrocco lungo",
    )

    /** Le vocabulaire d'une langue de l'app (« fr », « en »…) ; le français par défaut. */
    fun vocabulary(language: String): Vocabulary = when (language.take(2)) {
        "en" -> english
        "es" -> spanish
        "de" -> german
        "it" -> italian
        else -> french
    }

    // Lire une phrase

    private val letterThenDigit = Regex("""([a-h])([1-8])""")
    private val fileThenSquare = Regex("""\b([a-h])([a-h][1-8])\b""")
    private val separators = Regex("""[^\p{L}\p{N}']+""")

    fun tokens(text: String, vocabulary: Vocabulary = french): List<String> {
        var lowered = text.lowercase().replace('’', '\'')
        // « Cf3 », « Fxc6 », « Sf3 » : une initiale de pièce collée à une case, comme on l'écrit.
        lowered = vocabulary.initialThenSquare.replace(lowered, "$1 $2")
        lowered = vocabulary.initialThenFileThenSquare.replace(lowered, "$1 $2 $3")
        // Deux colonnes collées à un chiffre (« he1 » pour « tour h, e1 », « ae1 ») : la première est le départ.
        lowered = fileThenSquare.replace(lowered, "$1 $2")
        // Une lettre collée à son chiffre (« f3 », « e4 ») : deux mots.
        lowered = letterThenDigit.replace(lowered, "$1 $2")
        return lowered.split(separators).filter { it.isNotEmpty() }.flatMap { vocabulary.fused[it] ?: listOf(it) }
    }

    /** « annule », « take back » : une demande de reprise, sans case dedans. */
    fun isUndo(text: String, vocabulary: Vocabulary = french): Boolean {
        val spaced = " " + tokens(text, vocabulary).joinToString(" ") + " "
        return vocabulary.undo.any { " $it " in spaced }
    }

    fun heard(text: String, vocabulary: Vocabulary = french): Heard {
        val result = Heard()
        val words = tokens(text, vocabulary)
        val spaced = " " + words.joinToString(" ") + " "
        val raw = text.lowercase()
        fun says(phrases: List<String>) = phrases.any { " $it " in spaced }
        result.castle = when {
            says(vocabulary.longCastle) || "o-o-o" in raw || "0-0-0" in raw -> Castle.long
            says(vocabulary.shortCastle) || "o-o" in raw || "0-0" in raw -> Castle.short
            says(vocabulary.anyCastle) -> Castle.unspecified
            else -> {
                val joined = words.filter { it != "roi" }.joinToString("")
                when {
                    vocabulary.fuzzyLongCastle?.matches(joined) == true -> Castle.long
                    vocabulary.fuzzyShortCastle?.matches(joined) == true -> Castle.short
                    else -> null
                }
            }
        }

        fun strongFile(word: String): Char? = vocabulary.strongFiles[word] ?: radioAlphabet[word]
        fun rank(word: String): Char? = vocabulary.ranks[word] ?: digits[word]

        var index = 0
        var promotionNext = false
        while (index < words.size) {
            val word = words[index]
            val next = words.getOrNull(index + 1)
            val afterNext = words.getOrNull(index + 2)

            val piece = vocabulary.pieces[word]
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
            if (word in vocabulary.captureWords) { result.capture = true; index += 1; continue }
            if (word in vocabulary.promotionWords) { promotionNext = true; index += 1; continue }

            // Initiale et colonne collées, puis le chiffre : « FB quatre » = fou b4 (entendu le 19/11).
            if (result.piece == null && result.squares.isEmpty() && word.length == 2 && next != null) {
                val initial = vocabulary.writtenInitials[word.take(1)]
                val file = word.last()
                val nextRank = rank(next)
                if (initial != null && file in "abcdefgh" && nextRank != null) {
                    result.piece = initial
                    result.squares += "$file$nextRank"
                    index += 2
                    continue
                }
            }
            // Une initiale écrite suivie d'une case complète : « C f 3 ».
            val initial = vocabulary.writtenInitials[word]
            if (result.piece == null && result.squares.isEmpty() && initial != null &&
                next != null && strongFile(next) != null && afterNext != null && rank(afterNext) != null
            ) {
                result.piece = initial
                index += 1
                continue
            }

            val file = strongFile(word) ?: vocabulary.weakFiles[word]
            val rankAfter = next?.let { rank(it) }
            if (file != null && rankAfter != null) {
                result.squares += "$file$rankAfter"
                index += 2
                continue
            }
            val strong = strongFile(word)
            if (strong != null) {
                // Une colonne seule, avant la case d'arrivée : l'indice de départ.
                if (result.squares.isEmpty()) result.fromFile = strong
                index += 1
                continue
            }
            // Une rangée seule : l'indice de départ (« tour 1 d1 »), ou l'arrivée quand la colonne s'est perdue. Pas
            // devant une colonne : « knight to f3 », où « to » sonne comme « two » — sauf un CHIFFRE écrit (« tour 1 a3 »),
            // et sauf en anglais, où la reconnaissance écrit « 2 » pour « to ».
            val beforeFile = next?.let { strongFile(it) != null || vocabulary.weakFiles[it] != null } ?: false
            val isWrittenDigit = digits[word] != null && vocabulary.ranks["to"] == null
            val alone = rank(word)
            if (alone != null && result.squares.isEmpty() && result.piece != null && (!beforeFile || isWrittenDigit)) {
                result.fromRank = alone
            }
            index += 1
        }
        return result
    }

    // Confronter à la position

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
            // Promotion : la pièce dite, sinon la dame.
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

    /**
     * Les lettres qui riment se confondent à l'oreille : b, c, d, e, g (en « é » en français, en « i » en anglais).
     * Quand la case entendue ne donne rien, on essaie ses voisines ; on ne retient le résultat que s'il désigne UN
     * seul coup.
     */
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

    /**
     * Plusieurs transcriptions d'un même enregistrement (la meilleure d'abord). Les coups qu'elles désignent se
     * DÉPARTAGENT PAR LE VOTE : celui que le plus d'alternatives désignent l'emporte, et à égalité la reconnaissance
     * hésite vraiment ([Outcome.Conflicting]) — on ne joue plus la première alternative venue (iPhone 11, 21/11/2026 :
     * `["A3", "E3"]` jouait a3 pour un « e3 » dit). Pendant de `VoiceMoveParser.resolve(transcripts:…)` (iOS).
     */
    fun resolve(
        transcripts: List<String>,
        candidates: List<Candidate>,
        confusions: Boolean = true,
        vocabulary: Vocabulary = french,
    ): Outcome {
        val outcomes = transcripts.map { text ->
            val heard = heard(text, vocabulary)
            when {
                heard.isEmpty -> Outcome.NotUnderstood
                confusions -> resolveWithConfusions(heard, candidates)
                else -> resolve(heard, candidates)
            }
        }
        val votes = LinkedHashMap<Candidate, Int>()
        for (outcome in outcomes) if (outcome is Outcome.Move) votes[outcome.move] = (votes[outcome.move] ?: 0) + 1
        val best = votes.values.maxOrNull()
        if (best != null) {
            val leaders = votes.filterValues { it == best }.keys.toList()
            return if (leaders.size == 1) Outcome.Move(leaders[0]) else Outcome.Conflicting(leaders)
        }
        outcomes.firstOrNull { it is Outcome.Ambiguous }?.let { return it }
        if (Outcome.Illegal in outcomes) {
            // Le MOT de la pièce est ce que la reconnaissance abîme le plus (« fou b5 » → « pions B5 », « tour a8 » →
            // « cavalier à 8 » sur le Galaxy, 21/11/2026 : il fallait le redire) ; la case, elle, passe. Si la pièce
            // dite ne peut pas y aller mais qu'UN SEUL coup légal y mène, c'est celui-là — jamais un pion : « fou c4 » ne devient pas c2-c4 (l'app dit quelle pièce a joué,
            // « annule » le reprend). Deux coups possibles ou plus : on ne devine pas.
            val toSquare = transcripts.flatMap { text ->
                val heard = heard(text, vocabulary)
                val square = heard.squares.singleOrNull()
                if (heard.castle != null || heard.piece == null || square == null) emptyList()
                else candidates.filter { !it.isCastle && it.piece != 'P' && it.to == square }
            }.distinct()
            if (toSquare.size == 1) return Outcome.Move(toSquare[0])
            return Outcome.Illegal
        }
        return Outcome.NotUnderstood
    }

    /**
     * Après « a 3 ou e 3 ? » : « premier » (0) ou « deuxième » (1) — des mots que la reconnaissance n'embrouille pas,
     * contrairement aux lettres. `null` si la phrase ne répond pas. Dans l'ordre où les mots sont dits.
     */
    fun choice(transcripts: List<String>, language: String): Int? {
        val words = choiceWords[language.take(2)] ?: choiceWords.getValue("fr")
        for (text in transcripts) {
            for (token in text.lowercase().split(Regex("[^\\p{L}\\p{N}]+")).filter { it.isNotEmpty() }) {
                if (token in words.first) return 0
                if (token in words.second) return 1
            }
        }
        return null
    }

    private val choiceWords: Map<String, Pair<Set<String>, Set<String>>> = mapOf(
        "fr" to (setOf("premier", "première", "premiere", "un", "1") to
            setOf("deuxième", "deuxieme", "second", "seconde", "deux", "2")),
        "en" to (setOf("first", "one", "1", "1st") to setOf("second", "two", "to", "too", "2", "2nd")),
        "es" to (setOf("primero", "primera", "uno", "1") to setOf("segundo", "segunda", "dos", "2")),
        "de" to (setOf("erste", "erster", "ersten", "eins", "1") to setOf("zweite", "zweiter", "zweiten", "zwei", "2")),
        "it" to (setOf("primo", "prima", "uno", "1") to setOf("secondo", "seconda", "due", "2")),
    )

    /**
     * Une phrase sans rien d'échecs dedans (une conversation autour de la table) : l'écoute permanente l'ignore, au
     * lieu de répondre « pas compris » à chaque mot prononcé dans la pièce.
     */
    fun soundsLikeChess(transcripts: List<String>, vocabulary: Vocabulary = french): Boolean =
        transcripts.any { !heard(it, vocabulary).isEmpty || isUndo(it, vocabulary) }

    // Ce qu'on s'attend à entendre

    /** Les façons courantes de dire un coup — indices pour la reconnaissance (EXTRA_BIASING_STRINGS). */
    fun spokenForms(candidate: Candidate, vocabulary: Vocabulary = french): List<String> {
        if (candidate.isLongCastle) return listOf(vocabulary.longCastleName)
        if (candidate.isCastle) return listOf(vocabulary.shortCastleName)
        val to = candidate.to
        val name = vocabulary.pieceNames[candidate.piece].orEmpty()
        val forms = mutableListOf("$name $to", "$name ${vocabulary.to} $to")
        if ('x' in candidate.san) forms += "$name ${vocabulary.takes} $to"
        if (candidate.piece == 'P') forms += to
        candidate.promotion?.let { promotion ->
            vocabulary.pieceNames[promotion.uppercaseChar()]?.let { forms += "$to $it" }
        }
        return forms
    }

    fun spokenForms(candidates: List<Candidate>, vocabulary: Vocabulary = french): List<String> =
        candidates.flatMap { spokenForms(it, vocabulary) }.distinct()

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
