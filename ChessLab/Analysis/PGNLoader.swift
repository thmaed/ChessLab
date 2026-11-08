import ChessKit
import Foundation

/// Décode un PGN en `Game`, avec un filet de sécurité quand ChessKit renonce.
///
/// ## Pourquoi ce détour
///
/// `Game(pgn:)` refuse des parties parfaitement légales. Constaté sur un
/// fichier de tournoi réel : deux parties sur neuf rejetées, pour deux causes
/// distinctes et toutes deux ordinaires.
///
/// 1. **`O-O-O+`** — un roque qui donne échec. Traité en amont par
///    ``PGNSanitizer/stripCastlingCheckMarkers(_:)`` : le marqueur est
///    décoratif, on le retire.
/// 2. **La prise en passant.** Celle-là ne se règle pas par le texte. Mesuré :
///    `Move(san:position:)` la lit sans difficulté, c'est le lecteur de PARTIE
///    qui échoue. On reconstruit donc la partie nous-mêmes, coup par coup,
///    avec le lecteur qui, lui, fonctionne.
///
/// 3. **Une capture désambiguïsée** (`Rfxd7+`) : `Game(pgn:)` joue une autre
///    pièce que celle qui est nommée, voir ``SAN``. La partie est alors soit
///    refusée, soit lue DE TRAVERS sans que rien ne le dise. D'où la contre-épreuve
///    de ``mainLineAgrees(_:with:)``.
///
/// ## L'ordre importe
///
/// On essaie d'abord `Game(pgn:)`, qui conserve variantes et commentaires ;
/// la reconstruction ne garde que la ligne principale et n'intervient donc
/// qu'en dernier recours, pour une partie qui serait autrement PERDUE.
enum PGNLoader {

    /// Jetons qui ne sont pas des coups : numéros, résultats, annotations.
    private static let results: Set<String> = ["1-0", "0-1", "1/2-1/2", "*"]

    static func game(from pgn: String) -> Game? {
        let cleaned = PGNSanitizer.sanitize(pgn)
        if let game = try? Game(pgn: cleaned), mainLineAgrees(game, with: cleaned) { return game }
        return reconstruct(cleaned)
    }

    /// Contre-épreuve de `Game(pgn:)` : chaque coup de sa ligne principale doit être
    /// celui que ``SAN`` lit dans le texte. Ne sert que si le texte contient une
    /// capture désambiguïsée, le seul cas où ChessKit se trompe (voir ``SAN``) ;
    /// sans elle, la partie, variantes et commentaires compris, est gardée telle quelle.
    private static func mainLineAgrees(_ game: Game, with pgn: String) -> Bool {
        let tokens = movetext(of: pgn)
        guard tokens.contains(where: SAN.isDisambiguatedCapture) else { return true }

        let line = game.moves.indices
            .filter { $0.variation == MoveTree.Index.mainVariation }
            .sorted { ($0.number, $0.color == .black ? 1 : 0) < ($1.number, $1.color == .black ? 1 : 0) }
        guard line.count == tokens.count else { return false }
        for (index, token) in zip(line, tokens) {
            guard let played = game.moves[index],
                  game.moves.hasIndex(before: index),
                  let before = game.positions[game.moves.index(before: index)],
                  SAN.move(token, in: before)?.lan == played.lan
            else { return false }
        }
        return true
    }

    /// Rejoue la ligne principale avec ``Move(san:position:)``.
    ///
    /// Les variantes entre parenthèses et les commentaires entre accolades
    /// sont retirés : ce qu'on sauve ici, c'est la partie elle-même. Mieux
    /// vaut une partie sans ses annotations qu'une partie perdue.
    static func reconstruct(_ pgn: String) -> Game? {
        let body = movetext(of: pgn)
        guard !body.isEmpty else { return nil }

        // Une partie « à partir d'une position » (puzzle, finale) commence à son FEN.
        let start = fenTag(of: pgn).flatMap { Position(fen: $0) } ?? .standard
        var board = Board(position: start)
        var game = Game(startingWith: start)
        var index = game.startingIndex
        var played = 0

        for token in body {
            guard let move = SAN.move(token, in: board.position),
                  let applied = board.move(pieceAt: move.start, to: move.end)
            else {
                // On s'arrête au premier coup illisible plutôt que de sauter :
                // les coups suivants porteraient sur une position fausse, et
                // une partie SILENCIEUSEMENT différente est pire qu'une partie
                // tronquée.
                break
            }
            // ChessKit laisse une promotion en suspens jusqu'au choix de la pièce : sans
            // elle, la partie GARDAIT UN PION sur la dernière rangée (« …g1=Q » restait
            // un pion en g1), et Stockfish 19 refuse une telle position — en quittant
            // le process. Constaté le 08/11/2026 sur une partie jouée dans l'app.
            var finalMove = applied
            if case .promotion = board.state {
                finalMove = board.completePromotion(of: applied, to: move.promotedPiece?.kind ?? .queen)
            }
            index = game.make(move: finalMove, from: index)
            played += 1
        }
        guard played > 0 else { return nil }

        game.tags = tags(of: pgn)
        return game
    }

    /// Le FEN de départ de l'en-tête, s'il y en a un.
    private static func fenTag(of pgn: String) -> String? {
        guard let range = pgn.range(of: #"\[FEN\s+"([^"]+)"\]"#, options: .regularExpression) else { return nil }
        let line = String(pgn[range])
        guard let open = line.firstIndex(of: "\""), let close = line.lastIndex(of: "\""), open < close
        else { return nil }
        return String(line[line.index(after: open)..<close])
    }

    /// Jetons de coups : en-têtes, commentaires, variantes, numéros,
    /// annotations et résultat retirés.
    static func movetext(of pgn: String) -> [String] {
        var text = pgn.split(separator: "\n")
            .filter { !$0.hasPrefix("[") }
            .joined(separator: " ")
        text = text.replacingOccurrences(of: "\\{[^}]*\\}", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\([^)]*\\)", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\$\\d+", with: " ", options: .regularExpression)
        return text
            .split(whereSeparator: \.isWhitespace)
            .map { token -> String in
                // « 12. », « 12... » collés au coup ou isolés.
                token.replacingOccurrences(
                    of: "^\\d+\\.(\\.\\.)?", with: "", options: .regularExpression
                )
            }
            .map(cleanedMoveToken)
            .filter { !$0.isEmpty && !results.contains($0) }
    }

    /// Un coup SANS ses annotations de fin (« Rfxd7! » → « Rfxd7 », « Nbxd5?! » → « Nbxd5 ») ni
    /// « e.p. » : ChessKit lit « Rfxd7 » et rejette « Rfxd7! ». Sans ce nettoyage, une partie
    /// commentée qui contient une capture désambiguïsée était tronquée à ce coup.
    static func cleanedMoveToken(_ token: String) -> String {
        var text = token
        while let last = text.last, "!?".contains(last) { text.removeLast() }
        return text.replacingOccurrences(of: "e.p.", with: "")
    }

    /// En-têtes du PGN, pour ne pas perdre joueurs, date et résultat quand on
    /// reconstruit.
    static func tags(of pgn: String) -> Game.Tags {
        var tags = Game.Tags()
        for line in pgn.split(separator: "\n") where line.hasPrefix("[") {
            guard let space = line.firstIndex(of: " "),
                  let open = line.firstIndex(of: "\""),
                  let close = line.lastIndex(of: "\""), open < close
            else { continue }
            let key = String(line[line.index(after: line.startIndex)..<space])
            let value = String(line[line.index(after: open)..<close])
            switch key {
            case "Event": tags.event = value
            case "Site": tags.site = value
            case "Date": tags.date = value
            case "Round": tags.round = value
            case "White": tags.white = value
            case "Black": tags.black = value
            case "Result": tags.result = value
            default: break
            }
        }
        return tags
    }
}
