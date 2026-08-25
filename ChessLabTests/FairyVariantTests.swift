import ChessKit
import Testing
@testable import ChessLab

/// Règles PROPRES aux trois variantes Fairy-Stockfish (Roi de la colline,
/// Trois échecs, Horde) — condition de victoire ajoutée par-dessus le
/// mat/pat/nulle standard de ChessKit, testée en isolation (positions
/// construites à la main, pas de séquence de coups à rejouer : la légalité
/// elle-même reste celle, déjà prouvée, de ChessKit).
struct FairyVariantTests {

    @Test("La position de départ de Horde — sans roi blanc — se construit")
    func hordeStartingPositionParses() throws {
        let position = try #require(Position(fen: FairyVariant.horde.startFEN))
        let board = Board(position: position)
        #expect(!board.position.pieces.contains { $0.kind == .king && $0.color == .white },
                "Horde : les Blancs n'ont aucun roi au départ")
        #expect(board.position.pieces.contains { $0.kind == .king && $0.color == .black })
    }

    @Test("Roi de la colline : le roi sur une case centrale déclenche la victoire")
    func kingOfTheHillTriggersOnCentralSquare() throws {
        let board = Board(position: try #require(Position(fen: "8/8/8/8/3K4/8/4k3/8 w - - 0 1")))
        let outcome = FairyVariant.kingOfTheHill.specialOutcome(board: board, mover: .white, checkCounts: [:])
        #expect(outcome == GameOutcome(winner: .white, reason: .kingOfTheHill))
    }

    @Test("Roi de la colline : rien ne se déclenche hors des quatre cases centrales")
    func kingOfTheHillDoesNotTriggerElsewhere() throws {
        let board = Board(position: try #require(Position(fen: "8/8/8/8/2K5/8/4k3/8 w - - 0 1")))
        let outcome = FairyVariant.kingOfTheHill.specialOutcome(board: board, mover: .white, checkCounts: [:])
        #expect(outcome == nil, "c4 n'est pas une case centrale")
    }

    @Test("Trois échecs : la victoire tombe exactement au troisième, pas avant")
    func threeChecksTriggersAtExactlyThree() throws {
        let board = Board(position: try #require(Position(fen: "4k3/8/8/8/8/8/8/4K3 w - - 0 1")))
        let stillPlaying = FairyVariant.threeCheck.specialOutcome(
            board: board, mover: .white, checkCounts: [.white: 2, .black: 0]
        )
        #expect(stillPlaying == nil, "2 échecs ne suffisent pas")

        let won = FairyVariant.threeCheck.specialOutcome(
            board: board, mover: .white, checkCounts: [.white: 3, .black: 0]
        )
        #expect(won == GameOutcome(winner: .white, reason: .threeChecksDelivered))
    }

    @Test("Horde : plus aucune pièce blanche fait gagner les Noirs")
    func hordeExtinctionGrantsBlackTheWin() throws {
        let board = Board(position: try #require(Position(fen: "4k3/8/8/8/8/8/8/8 b - - 0 1")))
        let outcome = FairyVariant.horde.specialOutcome(board: board, mover: .black, checkCounts: [:])
        #expect(outcome == GameOutcome(winner: .black, reason: .hordeExtinction))
    }

    @Test("Horde : un pion blanc restant ne déclenche rien")
    func hordeDoesNotTriggerWhilePawnsRemain() throws {
        let board = Board(position: try #require(Position(fen: "4k3/8/8/8/8/8/4P3/8 b - - 0 1")))
        let outcome = FairyVariant.horde.specialOutcome(board: board, mover: .black, checkCounts: [:])
        #expect(outcome == nil)
    }

    @Test("Le compteur d'échecs se rejoue correctement depuis le journal UCI")
    func checkCountsReplayFromLog() {
        // 1.e4 g6 2.Bc4 g5 3.Qh5#? — pas un mat, mais Dh5 donne échec sur f7? En
        // réalité on ne teste QUE le comptage, pas la fin de partie : une
        // séquence courte qui inflige un échec net et vérifiable.
        // 1.e4 e5 2.Qh5 Nc6 3.Qxf7+ — Dxf7 donne échec.
        let uci = ["e2e4", "e7e5", "d1h5", "b8c6", "h5f7"]
        let counts = FairyVariant.checkCounts(startFEN: FairyVariant.kingOfTheHill.startFEN, uciLog: uci)
        #expect(counts[.white] == 1, "Dxf7+ est le seul échec de la séquence")
        #expect(counts[.black] == 0)
    }
}
