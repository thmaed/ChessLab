import Foundation

/// Export d'une série Laboratoire : PGN (toutes les parties concaténées) et
/// CSV (une ligne par partie). Pur et testable.
enum LabExport {
    /// PGN complet : chaque partie reçoit des en-têtes synthétiques
    /// (`[Event]`, `[Round]`, `[White]`, `[Black]`, `[Result]`,
    /// `[Termination]`) et son movetext est clos par le résultat — sans
    /// quoi une partie adjugée (abandon / nulle d'accord) sortait sans
    /// résultat ni joueurs, inexploitable dans un autre outil. Les tags de
    /// position de départ (`[SetUp]`/`[FEN]`) émis par ChessKit pour une
    /// série à FEN personnalisé sont préservés.
    static func pgn(_ games: [LabCompletedGame], settings: LabGameSettings) -> String {
        let aElo = Int(settings.sideAEloSlider)
        let bElo = Int(settings.sideBEloSlider)
        return games.map { game in
            let white = game.aWasWhite ? "A (Elo \(aElo))" : "B (Elo \(bElo))"
            let black = game.aWasWhite ? "B (Elo \(bElo))" : "A (Elo \(aElo))"

            let lines = game.pgn.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "\n", omittingEmptySubsequences: false)
            let setupTags = lines.filter { $0.hasPrefix("[SetUp") || $0.hasPrefix("[FEN") }
            var movetext = lines.filter { !$0.hasPrefix("[") }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !movetext.hasSuffix(game.pgnResult) {
                movetext += (movetext.isEmpty ? "" : " ") + game.pgnResult
            }

            var header = """
            [Event "ChessLab Lab"]
            [Round "\(game.index + 1)"]
            [White "\(white)"]
            [Black "\(black)"]
            [Result "\(game.pgnResult)"]
            [Termination "\(game.reasonLabel)"]
            """
            if !setupTags.isEmpty {
                header += "\n" + setupTags.joined(separator: "\n")
            }
            return header + "\n\n" + movetext
        }.joined(separator: "\n\n")
    }

    static func csv(_ games: [LabCompletedGame]) -> String {
        var rows = ["partie,camp_A,resultat,score_A,demi_coups,fin"]
        for game in games {
            let aColor = game.aWasWhite ? "Blanc" : "Noir"
            let scoreA: String
            switch game.labResult {
            case .winA: scoreA = "1"
            case .draw: scoreA = "0.5"
            case .winB: scoreA = "0"
            }
            rows.append("\(game.index + 1),\(aColor),\(game.pgnResult),\(scoreA),\(game.plyCount),\(game.reasonLabel)")
        }
        return rows.joined(separator: "\n")
    }
}
