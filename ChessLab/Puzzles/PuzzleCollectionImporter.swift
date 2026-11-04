import ChessKit
import Foundation

/// Lit un fichier PGN de PUZZLES — les vôtres, rassemblés ailleurs (chess.com,
/// Lichess, ChessTempo, un export Hiarcs ou ChessBase) — et en fait des puzzles
/// prêts à résoudre. Pendant : `PuzzleCollectionImporter.kt`.
///
/// ## Le format attendu
///
/// Une PARTIE du fichier = UN puzzle :
/// - l'en-tête `[FEN "…"]` donne la position AVANT le premier coup ; **sans lui,
///   la partie est écartée** (sans position, la ligne principale n'est pas un
///   puzzle mais une partie entière, et on n'invente pas où commence l'énoncé) ;
/// - le PREMIER coup de la ligne principale est la PRÉPARATION : celui de
///   l'adversaire (le camp au trait dans le FEN), joué d'avance — c'est la
///   convention de Lichess, celle de la bibliothèque de l'app, et celle des
///   fichiers de Ron (« qu'est-ce qui a changé dans la position ? »). Le
///   puzzle commence APRÈS lui : le FEN enregistré est la position qui suit,
///   et ce coup est gardé à part (``ParsedPuzzle/setupLAN``) pour être montré ;
/// - les coups suivants sont la solution, en alternant celui qui trouve et la
///   riposte forcée — le modèle de ``Puzzle/solutionLANs`` ;
/// - variantes, commentaires et annotations (`!`, `?`, `$1`) sont ignorés.
///
/// Une solution se termine sur un coup de celui qui trouve (comme
/// ``PuzzleSolutionTrimmer``) : une riposte adverse en queue de ligne est
/// retirée, sinon le dernier geste demandé serait un coup auto-joué. Une partie
/// qui n'a QUE sa préparation n'a pas de solution : elle est écartée.
///
/// ## Ce qui est refusé, et dit pourquoi
///
/// Une partie illisible n'arrête jamais l'import des autres : elle est notée
/// dans ``Result/skipped`` avec sa raison (``SkipReason``) et son numéro.
/// Rien n'est deviné — un coup qui ne se joue pas écarte TOUTE la partie, car
/// une solution tronquée serait un puzzle silencieusement différent.
enum PuzzleCollectionImporter {
    /// Un puzzle lu, pas encore enregistré.
    struct ParsedPuzzle: Equatable {
        /// La position où le puzzle COMMENCE : celle qui suit la préparation.
        var fen: String
        /// Le coup de préparation (adverse), en LAN, joué avant l'énoncé.
        var setupLAN: String
        /// En LAN, le premier coup étant celui à trouver.
        var solutionLANs: [String]
        var themeRaw: String
        var phaseRaw: String
    }

    enum SkipReason: Error, Equatable {
        /// Pas d'en-tête `[FEN]`.
        case missingFEN
        /// L'en-tête `[FEN]` n'est pas une position lisible.
        case invalidFEN
        /// Aucun coup dans la partie.
        case noMoves
        /// La préparation est là mais rien après : pas de coup à trouver.
        case noSolution
        /// Ce coup (SAN, tel qu'écrit dans le fichier) ne se joue pas.
        case illegalMove(String)
    }

    struct Skip: Equatable {
        /// Rang de la partie dans le fichier, à partir de 1.
        var gameNumber: Int
        var reason: SkipReason
    }

    struct Result: Equatable {
        var puzzles: [ParsedPuzzle] = []
        var skipped: [Skip] = []
        /// Parties rencontrées (lues + écartées + doublons).
        var gameCount = 0
        /// Le même énoncé (position ET solution) déjà lu plus haut dans le fichier.
        var duplicates = 0
    }

    /// Plafond d'une solution, en demi-coups : au-delà, ce n'est plus un puzzle
    /// mais une partie, et le coup d'une très longue ligne n'est plus vérifiable.
    static let maxSolutionPlies = 40

    static func parse(_ text: String) -> Result {
        var result = Result()
        var seen = Set<String>()
        let games = splitIntoGames(text)
        result.gameCount = games.count
        for (offset, game) in games.enumerated() {
            switch parseGame(game) {
            case .success(let puzzle):
                let key = puzzle.fen + "|" + puzzle.solutionLANs.joined(separator: " ")
                if seen.insert(key).inserted {
                    result.puzzles.append(puzzle)
                } else {
                    result.duplicates += 1
                }
            case .failure(let reason):
                result.skipped.append(Skip(gameNumber: offset + 1, reason: reason))
            }
        }
        return result
    }

    // MARK: Découpage

    /// Une nouvelle partie commence à la première ligne d'EN-TÊTE qui suit des
    /// coups. Contrairement à ``PGNSanitizer/splitIntoGames(_:)``, qui attend un
    /// `[Event …]`, on n'exige aucun en-tête en particulier : un fichier de
    /// puzzles n'a souvent que `[FEN]` (et `[SetUp]`).
    static func splitIntoGames(_ text: String) -> [String] {
        let lines = PGNSanitizer.normalizeWhitespace(text).components(separatedBy: "\n")
        var games: [String] = []
        var current: [String] = []
        var sawMoves = false
        func flush() {
            let game = current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !game.isEmpty { games.append(game) }
            current = []
            sawMoves = false
        }
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isTagLine(trimmed) {
                if sawMoves { flush() }
            } else if !trimmed.isEmpty {
                sawMoves = true
            }
            current.append(line)
        }
        flush()
        return games
    }

    /// `[Clé "valeur"]` — et PAS une ligne de commentaire qui commencerait par
    /// un crochet (`[%clk 0:03:00]`, `[%eval 0.3]`).
    private static func isTagLine(_ line: String) -> Bool {
        line.range(of: #"^\[[A-Za-z0-9_]+\s+""#, options: .regularExpression) != nil
    }

    private static func tag(_ name: String, in game: String) -> String? {
        let pattern = #"(?im)^\s*\[\#(name)\s+"([^"]*)"\s*\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: game, range: NSRange(game.startIndex..., in: game)),
              let range = Range(match.range(at: 1), in: game)
        else { return nil }
        return String(game[range]).trimmingCharacters(in: .whitespaces)
    }

    // MARK: Une partie

    private static func parseGame(_ raw: String) -> Swift.Result<ParsedPuzzle, SkipReason> {
        let game = PGNSanitizer.sanitize(raw)
        guard let fen = tag("FEN", in: game), !fen.isEmpty else { return .failure(.missingFEN) }
        guard let start = Position(fen: fen) else { return .failure(.invalidFEN) }

        let tokens = PGNLoader.movetext(of: game).map(cleaned).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return .failure(.noMoves) }

        var board = Board(position: start)
        var lans: [String] = []
        var startFEN = fen
        // La préparation compte pour un coup de plus que le plafond de la solution.
        for (index, token) in tokens.prefix(maxSolutionPlies + 1).enumerated() {
            guard let move = Move(san: token, position: board.position),
                  let applied = board.move(pieceAt: move.start, to: move.end)
            else { return .failure(.illegalMove(token)) }
            lans.append(move.lan)
            // ChessKit laisse une promotion en suspens jusqu'au choix de la pièce.
            if case .promotion = board.state {
                _ = board.completePromotion(of: applied, to: move.promotedPiece?.kind ?? .queen)
            }
            // Le puzzle commence ICI : après la préparation.
            if index == 0 { startFEN = board.position.fen }
        }
        guard lans.count >= 2 else { return .failure(.noSolution) }
        let setup = lans.removeFirst()
        // Se termine sur le coup de celui qui trouve : longueur impaire.
        if lans.count > 1, lans.count.isMultiple(of: 2) { lans.removeLast() }

        return .success(ParsedPuzzle(
            fen: startFEN,
            setupLAN: setup,
            solutionLANs: lans,
            themeRaw: PuzzleThemeDetector.detect(startFEN: startFEN, solutionLANs: lans).rawValue,
            phaseRaw: GamePhaseClassifier.classify(fen: startFEN).rawValue
        ))
    }

    /// Retire ce qui reste collé au coup après le nettoyage de ``PGNLoader``:
    /// annotations (`!`, `?`), point d'interrogation d'un coup douteux, `e.p.`,
    /// et le tiret de « coup nul » qui n'est pas un coup.
    private static func cleaned(_ token: String) -> String {
        var text = token
        while let last = text.last, "!?".contains(last) { text.removeLast() }
        text = text.replacingOccurrences(of: "e.p.", with: "")
        return text == "--" || text == "Z0" ? "" : text
    }
}
