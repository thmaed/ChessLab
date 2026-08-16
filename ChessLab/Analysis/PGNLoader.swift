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
        if let game = try? Game(pgn: cleaned) { return game }
        return reconstruct(cleaned)
    }

    /// Rejoue la ligne principale avec ``Move(san:position:)``.
    ///
    /// Les variantes entre parenthèses et les commentaires entre accolades
    /// sont retirés : ce qu'on sauve ici, c'est la partie elle-même. Mieux
    /// vaut une partie sans ses annotations qu'une partie perdue.
    static func reconstruct(_ pgn: String) -> Game? {
        let body = movetext(of: pgn)
        guard !body.isEmpty else { return nil }

        var board = Board(position: .standard)
        var game = Game(startingWith: .standard)
        var index = game.startingIndex
        var played = 0

        for token in body {
            guard let move = Move(san: token, position: board.position),
                  let applied = board.move(pieceAt: move.start, to: move.end)
            else {
                // On s'arrête au premier coup illisible plutôt que de sauter :
                // les coups suivants porteraient sur une position fausse, et
                // une partie SILENCIEUSEMENT différente est pire qu'une partie
                // tronquée.
                break
            }
            index = game.make(move: applied, from: index)
            played += 1
        }
        guard played > 0 else { return nil }

        game.tags = tags(of: pgn)
        return game
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
            .filter { !$0.isEmpty && !results.contains($0) }
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
