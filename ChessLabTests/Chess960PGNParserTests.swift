import ChessKit
import Testing
@testable import ChessLab

@MainActor
struct Chess960PGNParserTests {

    private func classicalGame() -> Chess960PlayViewModel {
        var settings = Chess960Settings()
        settings.positionNumber = 518
        return Chess960PlayViewModel(settings: settings)
    }

    @Test("L'export d'une partie Jouer se relit à l'identique, roque compris")
    func exportedGameRoundTripsExactly() throws {
        let vm = classicalGame()
        for uci in ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5", "e1h1"] {
            vm.forceMove(uci: uci)
        }
        let pgn = vm.exportedPGN

        let parsed = try #require(Chess960PGNParser.parse(pgn))
        #expect(parsed.moves.map(\.san) == vm.sanLog)
        #expect(parsed.moves.map(\.uci) == vm.uciLog)
        #expect(parsed.startFEN == "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w HAha - 0 1")
    }

    @Test("Un PGN tronqué en plein milieu du texte rend ce qu'il a pu lire")
    func aTruncatedPGNStillReturnsAPrefix() throws {
        let vm = classicalGame()
        for uci in ["e2e4", "e7e5", "g1f3"] {
            vm.forceMove(uci: uci)
        }
        var pgn = vm.exportedPGN
        pgn += " Xyz??"   // jeton illisible en fin de texte

        let parsed = try #require(Chess960PGNParser.parse(pgn))
        #expect(parsed.moves.map(\.san) == ["e4", "e5", "Nf3"], "le préfixe lisible doit survivre au jeton cassé")
    }

    @Test("Sans tag SetUp/FEN, rien à analyser")
    func withoutSetUpTagParsingFails() {
        #expect(Chess960PGNParser.parse("1. e4 e5 *") == nil)
    }
}
