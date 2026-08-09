import ChessKit
import Testing
@testable import ChessLab

struct LabStartPositionTests {

    @Test func aLegalFENIsTakenAsIs() throws {
        let fen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
        let resolved = try #require(LabStartPosition.resolve(fen))
        #expect(resolved.fen == fen)
        #expect(resolved.plies == 0)
        #expect(resolved.fromPGN == false)
    }

    @Test func aPGNResolvesToItsFinalPosition() throws {
        // 1. e4 e5 2. Nf3 → 3 demi-coups ; position finale connue.
        let resolved = try #require(LabStartPosition.resolve("1. e4 e5 2. Nf3"))
        #expect(resolved.fromPGN)
        #expect(resolved.plies == 3)
        // La position après 1.e4 e5 2.Nf3 : cavalier en f3, trait aux noirs.
        #expect(resolved.fen.hasPrefix("rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b"))
        // Et c'est une position légale exploitable comme départ.
        #expect(FENValidator.isLegal(resolved.fen))
    }

    @Test func aPGNWithHeadersAndResultStillResolves() throws {
        let pgn = """
        [Event "Test"]
        [White "A"]
        [Black "B"]
        [Result "*"]

        1. d4 d5 2. c4 e6 *
        """
        let resolved = try #require(LabStartPosition.resolve(pgn))
        #expect(resolved.fromPGN)
        #expect(resolved.plies == 4)
        #expect(FENValidator.isLegal(resolved.fen))
    }

    @Test func gibberishResolvesToNil() {
        #expect(LabStartPosition.resolve("ceci n'est ni un fen ni un pgn") == nil)
        #expect(LabStartPosition.resolve("   ") == nil)
    }
}
