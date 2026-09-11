package chesskit

/** Les erreurs de `PGNParser.Error` (ChessKit, MIT). */
enum class PgnError {
    tooManyLineBreaks, invalidSetUpOrFEN,
    invalidTagFormat, mismatchedTagBrackets, tagStringNotFound, tagSymbolNotFound,
    unexpectedTagCharacter,
    invalidAnnotation, invalidMove, unexpectedMoveTextToken,
    unpairedCommentDelimiter, unpairedVariationDelimiter,
}

class PgnException(val kind: PgnError, val detail: String = "") :
    Exception(if (detail.isEmpty()) kind.name else "${kind.name}: $detail")

/**
 * Écriture du PGN — traduction Kotlin de `PGNParser.convert` (ChessKit, MIT),
 * au format d'export du standard PGN.
 */
object PgnWriter {

    fun convert(game: Game): String {
        val sb = StringBuilder()

        for ((name, value) in game.tags.named) {
            if (value.isNotEmpty()) sb.append("[$name \"$value\"]\n")
        }
        game.tags.other.toSortedMap().forEach { (key, value) ->
            sb.append("[$key \"$value\"]\n")
        }
        if (sb.isNotEmpty()) sb.append("\n")   // ligne vide entre tags et movetext

        for (element in game.moves.pgnRepresentation) {
            when (element) {
                is MoveTree.PGNElement.WhiteNumber -> sb.append("${element.number}. ")
                is MoveTree.PGNElement.BlackNumber -> sb.append("${element.number}... ")
                is MoveTree.PGNElement.MoveElement -> sb.append(movePgn(element.move))
                is MoveTree.PGNElement.PositionAssessmentElement -> sb.append("${element.assessment.raw} ")
                MoveTree.PGNElement.VariationStart -> sb.append("(")
                MoveTree.PGNElement.VariationEnd -> {
                    while (sb.isNotEmpty() && sb.last() == ' ') sb.setLength(sb.length - 1)
                    sb.append(") ")
                }
            }
        }

        sb.append(game.tags.result)
        return sb.toString().trim()
    }

    private fun movePgn(move: Move): String {
        val sb = StringBuilder()
        sb.append(move.san).append(" ")
        if (move.assessment != Move.Assessment.null_) sb.append(move.assessment.raw).append(" ")
        if (move.comment.isNotEmpty()) sb.append("{").append(move.comment).append("} ")
        return sb.toString()
    }
}

/**
 * Lecture du PGN — traduction Kotlin de `PGNParser`, `PGNParser+MoveText` et
 * `PGNParser+Tags` (ChessKit, MIT), au format d'import du standard.
 *
 * La position de départ vient du tag `FEN` quand `SetUp` vaut `1`.
 */
object PgnParser {

    fun parse(pgn: String): Game {
        val lines = pgn.split("\n", "\r\n", "\r")
            .map { it.trim() }
            .filter { !it.startsWith("%") }          // les lignes en % sont ignorées

        val sections = splitOnBlankLines(lines)
        if (sections.size > 2) throw PgnException(PgnError.tooManyLineBreaks)
        val first = sections.firstOrNull() ?: return Game()

        val tagLines = if (sections.size == 2) first else emptyList()
        val moveLines = if (sections.size == 2) sections[1] else first

        val tags = parseTags(tagLines.joinToString(""))
        val game = parseMoveText(moveLines.joinToString(" "), startingPosition(tags))
        game.tags = tags
        return game
    }

    private fun splitOnBlankLines(lines: List<String>): List<List<String>> {
        val out = mutableListOf<List<String>>()
        var current = mutableListOf<String>()
        for (line in lines) {
            if (line.isEmpty()) {
                if (current.isNotEmpty()) { out += current; current = mutableListOf() }
            } else current += line
        }
        if (current.isNotEmpty()) out += current
        return out
    }

    private fun startingPosition(tags: Game.Tags): Position = when {
        tags.setUp == "1" -> FenParser.parse(tags.fen) ?: throw PgnException(PgnError.invalidSetUpOrFEN)
        tags.setUp == "0" || (tags.setUp.isEmpty() && tags.fen.isEmpty()) -> Position.standard
        else -> throw PgnException(PgnError.invalidSetUpOrFEN)
    }

    // ------------------------------------------------------------------ tags

    private fun parseTags(text: String): Game.Tags {
        val tags = Game.Tags()
        var symbol = StringBuilder()
        var string = StringBuilder()
        var quoteOpened = false
        var pendingSymbol: String? = null
        var depth = 0

        for (c in text.replace("\n", "")) {
            when {
                c == '[' -> { depth++; pendingSymbol = null }
                c == ']' -> {
                    if (depth == 0) throw PgnException(PgnError.mismatchedTagBrackets)
                    depth--
                }
                (c == '"' || c == '“') && !quoteOpened -> {
                    if (symbol.isNotEmpty()) { pendingSymbol = symbol.toString(); symbol = StringBuilder() }
                    quoteOpened = true
                }
                (c == '"' || c == '”') && quoteOpened -> {
                    val name = pendingSymbol ?: throw PgnException(PgnError.tagSymbolNotFound)
                    tags.set(name, string.toString())
                    string = StringBuilder()
                    pendingSymbol = null
                    quoteOpened = false
                }
                quoteOpened -> string.append(c)
                c.isWhitespace() -> {
                    if (symbol.isNotEmpty()) { pendingSymbol = symbol.toString(); symbol = StringBuilder() }
                }
                c.isLetterOrDigit() || c == '_' -> symbol.append(c)
                else -> throw PgnException(PgnError.unexpectedTagCharacter, c.toString())
            }
        }
        if (quoteOpened) throw PgnException(PgnError.tagStringNotFound)
        return tags
    }

    // -------------------------------------------------------------- movetext

    private sealed class Token {
        data class Number(val text: String) : Token()
        data class San(val text: String) : Token()
        data class Annotation(val text: String) : Token()
        data class Comment(val text: String) : Token()
        data class Result(val text: String) : Token()
        data object VariationStart : Token()
        data object VariationEnd : Token()
    }

    private enum class Kind { none, number, san, annotation, variationStart, variationEnd, result, comment }

    private fun isNumberChar(c: Char) = c.isDigit() || c == '.'
    private fun isSanChar(c: Char) = c.isLetter() || c.isDigit() || c in "x+#=Oo0-"
    private fun isAnnotationChar(c: Char) = c.isDigit() || c in "$?!□"
    private fun isResultChar(c: Char) = c in "12/-0*½"

    private fun kindOf(c: Char): Kind = when {
        isNumberChar(c) -> Kind.number
        isSanChar(c) -> Kind.san
        isAnnotationChar(c) -> Kind.annotation
        c == '(' -> Kind.variationStart
        c == ')' -> Kind.variationEnd
        isResultChar(c) -> Kind.result
        else -> Kind.none
    }

    private fun accepts(kind: Kind, c: Char): Boolean = when (kind) {
        Kind.none, Kind.comment -> false     // le commentaire est borné par { }
        Kind.number -> isNumberChar(c)
        Kind.san -> isSanChar(c)
        Kind.annotation -> isAnnotationChar(c)
        Kind.variationStart -> c == '('
        Kind.variationEnd -> c == ')'
        Kind.result -> isResultChar(c)
    }

    private fun convert(kind: Kind, text: String): Token? {
        val t = text.trim()
        return when (kind) {
            Kind.none -> null
            Kind.number -> Token.Number(t)
            Kind.san -> Token.San(t)
            Kind.annotation -> Token.Annotation(t)
            Kind.comment -> Token.Comment(t)
            Kind.variationStart -> Token.VariationStart
            Kind.variationEnd -> Token.VariationEnd
            Kind.result -> Token.Result(t)
        }
    }

    private fun tokenize(moveText: String): List<Token> {
        var inline = moveText.replace("\n", "").replace("\r", "")

        // le résultat final (1-0, ½-½, *) est isolé d'abord : ses caractères
        // se confondraient sinon avec des numéros de coup
        var resultToken: Token? = null
        val words = inline.split(" ").toMutableList()
        val last = words.lastOrNull()
        if (last != null && last.isNotEmpty() && last.all { isResultChar(it) }) {
            resultToken = Token.Result(last)
            words.removeAt(words.size - 1)
            inline = words.joinToString(" ")
        }

        val tokens = mutableListOf<Token>()
        var kind = Kind.none
        var current = StringBuilder()

        for (c in inline) {
            when {
                c == '{' -> kind = Kind.comment
                c == '}' -> {
                    if (kind != Kind.comment) throw PgnException(PgnError.unpairedCommentDelimiter)
                    if (current.isNotEmpty()) convert(kind, current.toString())?.let { tokens += it }
                    current = StringBuilder()
                    kind = Kind.none
                }
                kind == Kind.comment || accepts(kind, c) -> current.append(c)
                else -> {
                    if (current.isNotEmpty()) convert(kind, current.toString())?.let { tokens += it }
                    kind = kindOf(c)
                    current = StringBuilder().append(c)
                }
            }
        }
        if (current.isNotEmpty()) convert(kind, current.toString())?.let { tokens += it }
        resultToken?.let { tokens += it }
        return tokens
    }

    private val numericMove = Regex("""^\$\d$""")
    private val numericPosition = Regex("""^\$\d{2,3}$""")
    private val traditional = Regex("""^[!?□]{1,2}$""")

    private fun parseMoveText(moveText: String, startingPosition: Position): Game {
        val tokens = tokenize(moveText)
        val game = Game(startingPosition)
        if (tokens.isEmpty()) return game

        var index: MoveTree.Index
        val first = tokens.first()

        when (first) {
            is Token.Number -> {
                val n = first.text.takeWhile { it != '.' }.toIntOrNull()
                    ?: throw PgnException(PgnError.unexpectedMoveTextToken)
                index = if (first.text.count { it == '.' } >= 3) {
                    MoveTree.Index(n, Piece.Color.black).previous
                } else {
                    MoveTree.Index(n, Piece.Color.white).previous
                }
            }
            is Token.San -> {
                index = if (startingPosition.sideToMove == Piece.Color.white) MoveTree.Index.minimum
                else MoveTree.Index.minimum.next
                val position = game.position(index)
                if (position != null) {
                    val move = SanParser.parse(first.text, position)
                        ?: throw PgnException(PgnError.invalidMove, first.text)
                    index = game.make(move, from = index)
                }
            }
            else -> throw PgnException(PgnError.unexpectedMoveTextToken)
        }

        val variationStack = ArrayDeque<MoveTree.Index>()

        for (token in tokens.drop(1)) {
            when (token) {
                is Token.Number, is Token.Result -> Unit
                is Token.San -> {
                    val position = game.position(index)
                        ?: throw PgnException(PgnError.invalidMove, token.text)
                    val move = SanParser.parse(token.text, position)
                        ?: throw PgnException(PgnError.invalidMove, token.text)
                    index = game.make(move, from = index)
                }
                is Token.Annotation -> {
                    val a = token.text
                    when {
                        numericPosition.matches(a) -> {
                            val assessment = PositionAssessment.fromRaw(a)
                                ?: throw PgnException(PgnError.invalidAnnotation, a)
                            game.annotate(positionAt = index, assessment = assessment)
                        }
                        traditional.matches(a) -> {
                            val assessment = Move.Assessment.entries.firstOrNull { it.notation == a }
                                ?: throw PgnException(PgnError.invalidAnnotation, a)
                            annotateMove(game, index, assessment = assessment)
                        }
                        numericMove.matches(a) -> {
                            val assessment = Move.Assessment.entries.firstOrNull { it.raw == a }
                                ?: throw PgnException(PgnError.invalidAnnotation, a)
                            annotateMove(game, index, assessment = assessment)
                        }
                        else -> throw PgnException(PgnError.invalidAnnotation, a)
                    }
                }
                is Token.Comment -> annotateMove(game, index, comment = token.text)
                Token.VariationStart -> {
                    variationStack.addLast(index)
                    index = index.previous
                }
                Token.VariationEnd -> {
                    index = variationStack.removeLastOrNull()
                        ?: throw PgnException(PgnError.unpairedVariationDelimiter)
                }
            }
        }

        return game
    }

    /**
     * Annote sans écraser l'autre annotation.
     *
     * CORRIGÉ : `annotate(moveAt:comment:)` de l'original a une appréciation
     * par défaut à `.null`, si bien qu'un coup portant « ! » PUIS un
     * commentaire perdait son « ! » en chemin.
     */
    private fun annotateMove(
        game: Game,
        index: MoveTree.Index,
        assessment: Move.Assessment? = null,
        comment: String? = null,
    ) {
        val existing = game.moves[index]
        game.annotate(
            moveAt = index,
            assessment = assessment ?: existing?.assessment ?: Move.Assessment.null_,
            comment = comment ?: existing?.comment ?: "",
        )
    }
}
