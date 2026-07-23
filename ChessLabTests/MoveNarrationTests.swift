import Testing
@testable import ChessLab

struct MoveNarrationTests {
    @Test func pawnMove() {
        #expect(MoveNarration.describe(san: "e4") == "pion en e 4")
    }

    @Test func pieceMove() {
        #expect(MoveNarration.describe(san: "Nf3") == "cavalier en f 3")
    }

    @Test func capture() {
        #expect(MoveNarration.describe(san: "Bxe5") == "fou prend en e 5")
    }

    @Test func pawnCaptureWithDisambiguation() {
        #expect(MoveNarration.describe(san: "exd5") == "pion prend en d 5")
    }

    @Test func check() {
        #expect(MoveNarration.describe(san: "Qh5+") == "dame en h 5, échec")
    }

    @Test func checkmate() {
        #expect(MoveNarration.describe(san: "Qxf7#") == "dame prend en f 7, échec et mat")
    }

    @Test func castling() {
        #expect(MoveNarration.describe(san: "O-O") == "petit roque")
        #expect(MoveNarration.describe(san: "O-O-O+") == "grand roque, échec")
    }

    @Test func promotion() {
        #expect(MoveNarration.describe(san: "e8=Q") == "pion en e 8, promotion en dame")
    }
}
