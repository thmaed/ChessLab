import ChessKit
import Testing
@testable import ChessLab

struct CapturedMaterialTests {

    /// Joue une suite de coups sur un plateau standard et renvoie
    /// (moveLog, board) pour alimenter `CapturedMaterial.from`.
    private func play(_ moves: [(String, String)]) -> (log: [Move], board: Board) {
        var board = Board()
        var log: [Move] = []
        for (from, to) in moves {
            guard let move = board.move(pieceAt: Square(from), to: Square(to)) else {
                Issue.record("Coup illégal \(from)\(to)")
                continue
            }
            log.append(move)
        }
        return (log, board)
    }

    @Test func singleCaptureIsAttributedToCapturingSide() {
        // 1. e4 d5 2. exd5 : les Blancs prennent un pion noir.
        let (log, board) = play([("e2", "e4"), ("d7", "d5"), ("e4", "d5")])
        let captured = CapturedMaterial.from(moveLog: log, board: board)
        #expect(captured.byWhite == [.pawn])
        #expect(captured.byBlack.isEmpty)
        #expect(captured.diff == 1)
        #expect(captured.advantage(for: .white) == 1)
        #expect(captured.advantage(for: .black) == -1)
        #expect(captured.captures(by: .white) == [.pawn])
    }

    @Test func noCaptureYieldsEmptyTraysAndZeroDiff() {
        let (log, board) = play([("e2", "e4"), ("e7", "e5"), ("g1", "f3")])
        let captured = CapturedMaterial.from(moveLog: log, board: board)
        #expect(captured.byWhite.isEmpty)
        #expect(captured.byBlack.isEmpty)
        #expect(captured.diff == 0)
    }

    @Test func blackCaptureGivesBlackAdvantage() {
        // 1. e4 e5 2. Nf3 Nc6 3. d4 exd4 : les Noirs prennent le pion d4.
        let (log, board) = play([
            ("e2", "e4"), ("e7", "e5"), ("g1", "f3"), ("b8", "c6"), ("d2", "d4"), ("e5", "d4"),
        ])
        let captured = CapturedMaterial.from(moveLog: log, board: board)
        #expect(captured.byBlack == [.pawn])
        #expect(captured.byWhite.isEmpty)
        #expect(captured.diff == -1)
        #expect(captured.advantage(for: .black) == 1)
    }
}
