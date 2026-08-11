import ChessKit
import Testing
@testable import ChessLab

/// Import de PGN RÉELS (styles Lichess / chess.com, copier-coller web) : chaque
/// échantillon doit passer l'assainisseur puis `Game(pgn:)`. Régression du bug
/// « la fonction d'import ne marche pas bien » : les fins de ligne Windows
/// (`\r\n`) d'un copier-coller faisaient échouer le parsing.
struct PGNImportProbeTests {

    private func parses(_ raw: String) -> Bool {
        let games = PGNSanitizer.splitIntoGames(raw)
        let candidate = PGNSanitizer.sanitize(games.first ?? raw)
        return (try? Game(pgn: candidate)) != nil
    }

    @Test func realWorldPGNsAllParse() {
        let samples: [(name: String, pgn: String)] = [
            ("lichess-propre", """
            [Event "Rated Blitz"]
            [Site "https://lichess.org/abcd1234"]
            [White "alice"]
            [Black "bob"]
            [Result "1-0"]
            [ECO "C50"]

            1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. c3 Nf6 5. d4 exd4 6. cxd4 Bb4+ 1-0
            """),
            ("chesscom-clk", """
            [Event "Live Chess"]
            [Site "Chess.com"]
            [White "a"]
            [Black "b"]
            [Result "0-1"]

            1. e4 {[%clk 0:03:00]} 1... c5 {[%clk 0:03:00]} 2. Nf3 {[%clk 0:02:58]} 2... d6 0-1
            """),
            ("lichess-eval-clk", """
            [Event "x"]
            [White "a"]
            [Black "b"]
            [Result "*"]

            1. d4 { [%eval 0.17] [%clk 0:03:00] } 1... Nf6 { [%eval 0.0] } 2. c4 e6 *
            """),
            ("variations-nags", """
            [Event "x"]
            [White "a"]
            [Black "b"]
            [Result "*"]

            1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 (3... Nf6 4. O-O Nxe4) 4. Ba4 Nf6 $1 5. O-O Be7 *
            """),
            ("bare-movetext", "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *"),
            ("bare-no-numbers-spacing", "1.e4 e5 2.Nf3 Nc6 *"),
            ("black-indicator-after-comment", """
            [Event "x"]
            [White "a"]
            [Black "b"]
            [Result "*"]

            1. e4 e5 2. Nf3 { développe } 2... Nc6 3. Bb5 *
            """),
            ("no-result-token", """
            [Event "x"]
            [White "a"]
            [Black "b"]

            1. e4 e5 2. Nf3 Nc6 3. Bb5
            """),
            // — Les cas de COPIER-COLLER qui échouaient —
            ("crlf-line-endings", "[Event \"x\"]\r\n[White \"a\"]\r\n[Black \"b\"]\r\n[Result \"1-0\"]\r\n\r\n1. e4 e5 2. Nf3 Nc6 1-0"),
            ("bom-prefix", "\u{FEFF}[Event \"x\"]\n[White \"a\"]\n[Black \"b\"]\n[Result \"1-0\"]\n\n1. e4 e5 2. Nf3 Nc6 1-0"),
            ("nbsp-in-movetext", "[Event \"x\"]\n[White \"a\"]\n[Black \"b\"]\n[Result \"*\"]\n\n1.\u{00A0}e4 e5 2.\u{00A0}Nf3 Nc6 *"),
            ("crlf-wrapped-movetext", "[Event \"x\"]\r\n[White \"a\"]\r\n[Black \"b\"]\r\n[Result \"1-0\"]\r\n\r\n1. e4 e5 2. Nf3 Nc6\r\n3. Bb5 a6 4. Ba4 Nf6 1-0"),
        ]
        for s in samples {
            #expect(parses(s.pgn), "PGN devrait être importable : \(s.name)")
        }
    }
}
