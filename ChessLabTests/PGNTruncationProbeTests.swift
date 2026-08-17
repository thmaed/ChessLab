import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Sonde de DIAGNOSTIC : combien de coups chaque style de PGN livre-t-il
/// réellement, au bout de toute la chaîne (`PGNLoader.game(from:)`) ?
///
/// Née d'un rapport utilisateur (17/08) : une partie de la bibliothèque
/// s'ouvre dans l'analyse avec « Aucun coup joué ». `PGNImportProbeTests`
/// vérifie que `Game(pgn:)` rend NON-NIL — jamais qu'il rend LES COUPS. Un
/// parseur qui s'arrête en silence passe ce banc et vide l'écran d'analyse.
struct PGNTruncationProbeTests {

    private func mainlineCount(_ game: Game) -> Int {
        var count = 0
        var idx = game.startingIndex
        while game.moves.hasIndex(after: idx) {
            idx = game.moves.index(after: idx)
            count += 1
        }
        return count
    }

    @Test func everyLibraryStylePGNKeepsAllItsMoves() {
        let samples: [(name: String, pgn: String, expected: Int)] = [
            ("lichess-propre", """
            [Event "Rated Blitz"]
            [White "alice"]
            [Black "bob"]
            [Result "1-0"]

            1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. c3 Nf6 5. d4 exd4 6. cxd4 Bb4+ 1-0
            """, 12),
            ("chesscom-clk", """
            [Event "Live Chess"]
            [Site "Chess.com"]
            [White "a"]
            [Black "b"]
            [Result "0-1"]

            1. e4 {[%clk 0:03:00]} 1... c5 {[%clk 0:03:00]} 2. Nf3 {[%clk 0:02:58]} 2... d6 0-1
            """, 4),
            ("lichess-eval-clk", """
            [Event "x"]
            [White "a"]
            [Black "b"]
            [Result "*"]

            1. d4 { [%eval 0.17] [%clk 0:03:00] } 1... Nf6 { [%eval 0.0] } 2. c4 e6 *
            """, 4),
            ("crlf", "[Event \"x\"]\r\n[White \"a\"]\r\n[Black \"b\"]\r\n[Result \"1-0\"]\r\n\r\n1. e4 e5 2. Nf3 Nc6 1-0", 4),
            ("app-vs-engine", """
            [Event "ChessLab"]
            [White "Vous"]
            [Black "Ordinateur"]
            [Result "1-0"]

            1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. Ng5 d5 5. exd5 Nxd5 6. Nxf7 Kxf7 1-0
            """, 12),
            ("sans-section-tags", "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *", 6),
        ]
        for s in samples {
            let game = PGNLoader.game(from: s.pgn)
            let count = game.map(mainlineCount) ?? -1
            #expect(count == s.expected,
                    "\(s.name) : \(count) coup(s) au lieu de \(s.expected)")
        }
    }

    /// Les NEUF parties du fichier de tournoi réel (celui de la bibliothèque
    /// de l'utilisateur) : chaque partie doit livrer autant de coups que son
    /// movetext en contient — c'est le trajet import → bibliothèque →
    /// analyse, rejoué sur les données qui ont déclenché le rapport de bug.
    @Test func everyRealTournamentGameKeepsAllItsMoves() throws {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "Fixtures_nils", withExtension: "pgn"))
        let raw = try String(contentsOf: url, encoding: .utf8)
        let games = PGNSanitizer.splitIntoGames(raw)
        #expect(games.count >= 9, "le fichier contient neuf parties")
        for (i, text) in games.enumerated() {
            let tokens = PGNLoader.movetext(of: PGNSanitizer.sanitize(text)).count
            let game = PGNLoader.game(from: text)
            let count = game.map(mainlineCount) ?? -1
            #expect(count == tokens,
                    "partie \(i + 1) : \(count) coup(s) chargés pour \(tokens) dans le movetext")
        }
    }
}

private final class BundleToken {}
