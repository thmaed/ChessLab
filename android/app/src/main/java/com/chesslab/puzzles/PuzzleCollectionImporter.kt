package com.chesslab.puzzles

import chesskit.Board
import chesskit.Move
import chesskit.Piece
import chesskit.Position
import chesskit.SanParser
import chesskit.Square
import com.chesslab.analysis.PgnSanitizer

/**
 * Lit un fichier PGN de PUZZLES — les vôtres, rassemblés ailleurs (chess.com,
 * Lichess, ChessTempo, un export Hiarcs ou ChessBase) — et en fait des puzzles
 * prêts à résoudre. Pendant de `PuzzleCollectionImporter.swift`, qui fait foi.
 *
 * ## Le format attendu
 *
 * Une PARTIE du fichier = UN puzzle :
 * - l'en-tête `[FEN "…"]` donne la position AVANT le premier coup ; **sans lui,
 *   la partie est écartée** (sans position, la ligne principale n'est pas un
 *   puzzle mais une partie entière) ;
 * - le PREMIER coup de la ligne principale est la PRÉPARATION : celui de
 *   l'adversaire (le camp au trait dans le FEN), joué d'avance — convention de
 *   Lichess, de la bibliothèque de l'app et des fichiers de Ron. Le puzzle
 *   commence APRÈS lui : le FEN enregistré est la position qui suit, et ce coup
 *   est gardé à part ([ParsedPuzzle.setup]) pour être montré ;
 * - les coups suivants sont la solution, en alternant celui qui trouve et la
 *   riposte forcée ;
 * - variantes, commentaires et annotations (`!`, `?`, `$1`) sont ignorés.
 *
 * Une solution se termine sur un coup de celui qui trouve (comme
 * [PuzzleSolutionTrimmer]) : une riposte adverse en queue de ligne est retirée.
 * Une partie qui n'a QUE sa préparation n'a pas de solution : elle est écartée.
 *
 * Une partie illisible n'arrête jamais l'import des autres : elle est notée dans
 * [Result.skipped] avec sa raison et son numéro. Un coup qui ne se joue pas écarte
 * TOUTE la partie — une solution tronquée serait un puzzle silencieusement
 * différent.
 */
object PuzzleCollectionImporter {

    /** Un puzzle lu, pas encore enregistré. */
    data class ParsedPuzzle(
        /** La position où le puzzle COMMENCE : celle qui suit la préparation. */
        val fen: String,
        /** Le coup de préparation (adverse), en LAN, joué avant l'énoncé. */
        val setup: String,
        /** En LAN, le premier coup étant celui à trouver. */
        val solution: List<String>,
        val theme: String,
        val phase: String,
    )

    sealed class SkipReason {
        /** Pas d'en-tête `[FEN]`. */
        data object MissingFen : SkipReason()
        /** L'en-tête `[FEN]` n'est pas une position lisible. */
        data object InvalidFen : SkipReason()
        /** Aucun coup dans la partie. */
        data object NoMoves : SkipReason()
        /** La préparation est là mais rien après : pas de coup à trouver. */
        data object NoSolution : SkipReason()
        /** Ce coup (SAN, tel qu'écrit dans le fichier) ne se joue pas. */
        data class IllegalMove(val san: String) : SkipReason()
    }

    data class Skip(
        /** Rang de la partie dans le fichier, à partir de 1. */
        val gameNumber: Int,
        val reason: SkipReason,
    )

    data class Result(
        val puzzles: List<ParsedPuzzle> = emptyList(),
        val skipped: List<Skip> = emptyList(),
        /** Parties rencontrées (lues + écartées + doublons). */
        val gameCount: Int = 0,
        /** Le même énoncé (position ET solution) déjà lu plus haut dans le fichier. */
        val duplicates: Int = 0,
    )

    /**
     * Plafond d'une solution, en demi-coups : au-delà, ce n'est plus un puzzle
     * mais une partie.
     */
    const val MAX_SOLUTION_PLIES = 40

    fun parse(text: String): Result {
        val puzzles = ArrayList<ParsedPuzzle>()
        val skipped = ArrayList<Skip>()
        val seen = HashSet<String>()
        var duplicates = 0
        val games = splitIntoGames(text)
        games.forEachIndexed { offset, game ->
            when (val outcome = parseGame(game)) {
                is Outcome.Parsed -> {
                    val key = outcome.puzzle.fen + "|" + outcome.puzzle.solution.joinToString(" ")
                    if (seen.add(key)) puzzles += outcome.puzzle else duplicates++
                }
                is Outcome.Refused -> skipped += Skip(offset + 1, outcome.reason)
            }
        }
        return Result(puzzles, skipped, games.size, duplicates)
    }

    // MARK: Découpage

    /**
     * Une nouvelle partie commence à la première ligne d'EN-TÊTE qui suit des
     * coups. Contrairement à [PgnSanitizer.splitIntoGames], qui attend un
     * `[Event …]`, on n'exige aucun en-tête en particulier : un fichier de
     * puzzles n'a souvent que `[FEN]` (et `[SetUp]`).
     */
    fun splitIntoGames(text: String): List<String> {
        val games = ArrayList<String>()
        val current = ArrayList<String>()
        var sawMoves = false
        fun flush() {
            current.joinToString("\n").trim().takeIf { it.isNotEmpty() }?.let { games += it }
            current.clear()
            sawMoves = false
        }
        for (line in PgnSanitizer.normalizeWhitespace(text).split("\n")) {
            val trimmed = line.trim()
            if (TAG_LINE.containsMatchIn(trimmed)) {
                if (sawMoves) flush()
            } else if (trimmed.isNotEmpty()) {
                sawMoves = true
            }
            current += line
        }
        flush()
        return games
    }

    /** `[Clé "valeur"]` — et PAS une ligne de commentaire qui commencerait par un crochet (`[%clk 0:03:00]`). */
    private val TAG_LINE = Regex("""^\[[A-Za-z0-9_]+\s+"""")
    private val FEN_TAG = Regex("""(?im)^\s*\[FEN\s+"([^"]*)"\s*\]""")

    // MARK: Une partie

    private sealed class Outcome {
        data class Parsed(val puzzle: ParsedPuzzle) : Outcome()
        data class Refused(val reason: SkipReason) : Outcome()
    }

    private fun parseGame(raw: String): Outcome {
        val game = PgnSanitizer.sanitize(raw)
        val fen = FEN_TAG.find(game)?.groupValues?.get(1)?.trim()
        if (fen.isNullOrEmpty()) return Outcome.Refused(SkipReason.MissingFen)
        val start = Position.fromFen(fen) ?: return Outcome.Refused(SkipReason.InvalidFen)

        val tokens = movetext(game).map(::cleaned).filter { it.isNotEmpty() }
        if (tokens.isEmpty()) return Outcome.Refused(SkipReason.NoMoves)

        val board = Board(start)
        val lans = ArrayList<String>()
        var startFen: String = fen
        // La préparation compte pour un coup de plus que le plafond de la solution.
        for ((index, token) in tokens.take(MAX_SOLUTION_PLIES + 1).withIndex()) {
            val move = SanParser.parse(token, board.position)
                ?: return Outcome.Refused(SkipReason.IllegalMove(token))
            val applied = board.move(move.start, move.end)
                ?: return Outcome.Refused(SkipReason.IllegalMove(token))
            lans += move.lan
            // ChessKit laisse une promotion en suspens jusqu'au choix de la pièce.
            if (board.state is Board.State.Promotion) {
                board.completePromotion(applied, move.promotedPiece?.kind ?: Piece.Kind.queen)
            }
            // Le puzzle commence ICI : après la préparation.
            if (index == 0) startFen = board.position.fen
        }
        if (lans.size < 2) return Outcome.Refused(SkipReason.NoSolution)
        val setup = lans.removeAt(0)
        // Se termine sur le coup de celui qui trouve : longueur impaire.
        if (lans.size > 1 && lans.size % 2 == 0) lans.removeAt(lans.lastIndex)

        return Outcome.Parsed(
            ParsedPuzzle(
                fen = startFen,
                setup = setup,
                solution = lans,
                theme = PuzzleThemeDetector.detect(startFen, lans),
                phase = GamePhase.classify(startFen).raw,
            )
        )
    }

    private val RESULTS = setOf("1-0", "0-1", "1/2-1/2", "*")

    /**
     * Jetons de coups : en-têtes, commentaires, variantes, numéros, annotations et
     * résultat retirés. Pendant de `PGNLoader.movetext(of:)`.
     */
    internal fun movetext(pgn: String): List<String> {
        var text = pgn.split("\n").filterNot { it.startsWith("[") }.joinToString(" ")
        text = text.replace(Regex("""\{[^}]*\}"""), " ")
        text = text.replace(Regex("""\([^)]*\)"""), " ")
        text = text.replace(Regex("""\$\d+"""), " ")
        return text.split(Regex("""\s+"""))
            .map { it.replace(Regex("""^\d+\.(\.\.)?"""), "") }
            .filter { it.isNotEmpty() && it !in RESULTS }
    }

    /**
     * Retire ce qui reste collé au coup : annotations (`!`, `?`), `e.p.`, et le
     * tiret du « coup nul », qui n'est pas un coup.
     */
    private fun cleaned(token: String): String {
        val text = token.trimEnd('!', '?').replace("e.p.", "")
        return if (text == "--" || text == "Z0") "" else text
    }
}

/**
 * Détection de thème best-effort pour un puzzle importé — heuristiques simples.
 * Pendant de `PuzzleThemeDetector.swift` (mêmes règles, mêmes seuils) : un mat
 * sur la position finale, sinon pièce en prise / fourchette après le premier
 * coup, sinon « tactique ».
 */
object PuzzleThemeDetector {
    /** Valeur minimale pour qu'une pièce compte comme « de valeur ». */
    private const val VALUABLE = 3

    fun detect(startFen: String, solution: List<String>): String {
        val start = Position.fromFen(startFen) ?: return "tactic"
        val board = Board(start)
        var first: Move? = null
        var afterFirst: Board? = null
        for ((ply, lan) in solution.withIndex()) {
            if (lan.length < 4) break
            val move = board.move(Square(lan.substring(0, 2)), Square(lan.substring(2, 4))) ?: break
            if (board.state is Board.State.Promotion) {
                board.completePromotion(move, promotionKind(lan))
            }
            if (ply == 0) {
                first = move
                afterFirst = Board(board.position.copy())
            }
        }
        if (board.state is Board.State.Checkmate) return "checkmate"
        val move = first ?: return "tactic"
        val after = afterFirst ?: return "tactic"
        if (isHangingPieceCapture(move, after)) return "hangingPiece"
        if (isFork(move, after)) return "fork"
        return "tactic"
    }

    private fun promotionKind(lan: String): Piece.Kind = when (lan.getOrNull(4)?.lowercaseChar()) {
        'n' -> Piece.Kind.knight
        'b' -> Piece.Kind.bishop
        'r' -> Piece.Kind.rook
        else -> Piece.Kind.queen
    }

    private fun value(kind: Piece.Kind): Int = when (kind) {
        Piece.Kind.pawn -> 1
        Piece.Kind.knight, Piece.Kind.bishop -> 3
        Piece.Kind.rook -> 5
        Piece.Kind.queen -> 9
        Piece.Kind.king -> 0
    }

    /**
     * Le premier coup capture une pièce de valeur, et aucune pièce adverse ne peut
     * reprendre sur cette case : elle était vraiment « en prise ».
     */
    private fun isHangingPieceCapture(move: Move, after: Board): Boolean {
        val result = move.result
        if (result !is Move.Result.Capture || value(result.piece.kind) < VALUABLE) return false
        val canRecapture = after.position.pieces
            .filter { it.color == move.piece.color.opposite }
            .any { after.canMove(it.square, move.end) }
        return !canRecapture
    }

    /** Après le premier coup, la pièce qui vient de bouger attaque au moins deux pièces adverses de valeur. */
    private fun isFork(move: Move, after: Board): Boolean =
        after.legalMoves(move.end)
            .mapNotNull { after.position.piece(it) }
            .count { it.color != move.piece.color && value(it.kind) >= VALUABLE } >= 2
}
