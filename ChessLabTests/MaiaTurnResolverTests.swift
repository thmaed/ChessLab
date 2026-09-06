import ChessKit
import Testing
@testable import ChessLab

/// L'arbitre partagé entre le mode Jouer et le Laboratoire : Maia propose,
/// le filet dispose — et surtout, le filet ne dispose que dans ses quatre cas.
@Suite struct MaiaTurnResolverTests {

    private let policy = SafetyNetPolicy()
    private let start = Board(position: .standard)

    @Test func withoutAQuickSearchMaiaPlays() {
        let decision = MaiaTurnResolver.resolve(
            maiaUCI: "e2e4", quick: nil, level: 2400, pieceCount: 32, policy: policy, board: start
        )
        #expect(decision == .play("e2e4"))
    }

    @Test func aShortMateOverridesMaiaOnlyFromTheMateLevel() {
        // Mat du couloir : Ta8# est là, Maia propose autre chose.
        let board = Board(position: Position(fen: "6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1")!)
        let quick = MaiaTurnResolver.QuickSearch(lan: "a1a8", cp: 10_000, mate: 1)
        #expect(MaiaTurnResolver.resolve(maiaUCI: "g1f1", quick: quick, level: 1500, pieceCount: 9, policy: policy, board: board)
                == .override("a1a8", .mate))
        #expect(MaiaTurnResolver.resolve(maiaUCI: "g1f1", quick: quick, level: 1000, pieceCount: 9, policy: policy, board: board)
                == .play("g1f1"))
    }

    @Test func aTechnicalEndgameAsksForABridledSearch() {
        let board = Board(position: Position(fen: "8/8/4k3/8/8/4K3/4P3/8 w - - 0 1")!)
        let quick = MaiaTurnResolver.QuickSearch(lan: "e3d4", cp: 120, mate: nil)
        #expect(MaiaTurnResolver.resolve(maiaUCI: "e2e3", quick: quick, level: 1600, pieceCount: 3, policy: policy, board: board)
                == .searchBridled)
        #expect(MaiaTurnResolver.resolve(maiaUCI: "e2e3", quick: quick, level: 1500, pieceCount: 3, policy: policy, board: board)
                == .play("e2e3"))
    }

    @Test func aWinningRepetitionIsRefused() {
        // Navette de cavalier depuis la position initiale : le troisième
        // retour de la position de départ est une nulle par répétition.
        var board = Board(position: .standard)
        for lan in ["g1f3", "g8f6", "f3g1", "f6g8", "g1f3", "g8f6", "f3g1"] {
            _ = board.move(pieceAt: Square(String(lan.prefix(2))), to: Square(String(lan.suffix(2))))
        }
        #expect(MaiaTurnResolver.state(after: "f6g8", on: board) == .draw(reason: .repetition))

        let winning = MaiaTurnResolver.QuickSearch(lan: "e7e5", cp: 350, mate: nil)
        #expect(MaiaTurnResolver.resolve(maiaUCI: "f6g8", quick: winning, level: 1000, pieceCount: 32, policy: policy, board: board)
                == .override("e7e5", .repetition))
        let equal = MaiaTurnResolver.QuickSearch(lan: "e7e5", cp: 10, mate: nil)
        #expect(MaiaTurnResolver.resolve(maiaUCI: "f6g8", quick: equal, level: 1000, pieceCount: 32, policy: policy, board: board)
                == .play("f6g8"))
    }

    @Test func stateAfterAPromotionIsComputedWithTheRequestedPiece() {
        let board = Board(position: Position(fen: "8/P6k/8/8/8/8/7K/8 w - - 0 1")!)
        let state = MaiaTurnResolver.state(after: "a7a8q", on: board)
        #expect(state != nil)
        if case .promotion = state { Issue.record("la promotion doit être achevée") }
    }
}
