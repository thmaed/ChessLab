import ChessKit
import CoreGraphics
import Foundation
import Testing
@testable import ChessLab

/// La revue des cases douteuses (06/11/2026) : l'ordre dans lequel on les
/// propose, la deuxième hypothèse, le trait deviné.
struct ScanReviewTests {

    private func emptyGrid() -> [[SquareReading]] {
        [[SquareReading]](repeating: [SquareReading](repeating: .empty, count: 8), count: 8)
    }

    private func piece(
        _ color: Piece.Color, _ kind: Piece.Kind, _ confidence: Double = 0.95, alternatives: [PieceChoice] = []
    ) -> SquareReading {
        SquareReading(occupancy: .piece(color: color, kind: kind), confidence: confidence, alternatives: alternatives)
    }

    private func reading(_ grid: [[SquareReading]]) -> BoardScanReading {
        BoardScanReading(grid: grid, source: .screenshot)
    }

    // MARK: Trait deviné

    /// Une tour blanche donne échec au roi noir : seul le camp NOIR peut être au trait.
    @Test func aBlackKingInCheckMeansBlackToMove() {
        var grid = emptyGrid()
        grid[0][4] = piece(.black, .king)
        grid[1][4] = piece(.white, .rook)
        grid[7][4] = piece(.white, .king)
        #expect(reading(grid).suggestedSideToMove(rotation: .none) == .black)
    }

    @Test func aWhiteKingInCheckMeansWhiteToMove() {
        var grid = emptyGrid()
        grid[0][4] = piece(.black, .king)
        grid[6][4] = piece(.black, .rook)
        grid[7][4] = piece(.white, .king)
        #expect(reading(grid).suggestedSideToMove(rotation: .none) == .white)
    }

    /// Sans échec, les deux traits sont légaux : aucun indice, les Blancs.
    @Test func aQuietPositionDefaultsToWhite() {
        var grid = emptyGrid()
        grid[0][4] = piece(.black, .king)
        grid[7][4] = piece(.white, .king)
        #expect(reading(grid).suggestedSideToMove(rotation: .none) == .white)
    }

    // MARK: Ordre de revue

    @Test func theLeastSureSquareIsReviewedFirst() {
        var grid = emptyGrid()
        grid[0][4] = piece(.black, .king)
        grid[7][4] = piece(.white, .king)
        grid[3][3] = piece(.white, .knight, 0.40)   // d5, le moins sûr
        grid[4][0] = piece(.white, .bishop, 0.50)   // a4
        grid[2][6] = piece(.black, .pawn, 0.50)     // g6, même confiance que a4 : l'ordre du plateau tranche
        let order = reading(grid).reviewSquares(rotation: .none).map(\.notation)
        #expect(order == ["d5", "g6", "a4"])
    }

    @Test func aConfidentReadingHasNothingToReview() {
        var grid = emptyGrid()
        grid[0][4] = piece(.black, .king)
        grid[7][4] = piece(.white, .king)
        #expect(reading(grid).reviewSquares(rotation: .none).isEmpty)
    }

    // MARK: Deuxième hypothèse

    @Test func theMapperKeepsTheDetectorsOtherClasses() {
        let alternatives = [PieceChoice(color: .white, kind: .bishop)]
        let detection = YOLODetectionMapper.Detection(
            color: .white, kind: .knight, confidence: 0.6,
            boundingBox: CGRect(x: 0.25, y: 0.25, width: 0.125, height: 0.125),
            alternatives: alternatives
        )
        let grid = YOLODetectionMapper.grid(from: [detection])
        #expect(grid[2][2].alternatives == alternatives)
        #expect(grid[2][2].occupancy == .piece(color: .white, kind: .knight))
    }

    /// Ce que lit le second avis est la PREMIÈRE alternative proposée : c'est lui qui a fait douter.
    @Test func aCrossCheckContradictionBecomesTheFirstAlternative() {
        var primary = emptyGrid()
        primary[5][2] = piece(.white, .knight, 0.95, alternatives: [PieceChoice(color: .white, kind: .rook)])
        var secondary = emptyGrid()
        secondary[5][2] = piece(.white, .bishop, 0.9)
        let out = reading(primary).crossChecked(against: reading(secondary))
        #expect(out.grid[5][2].alternatives.first == PieceChoice(color: .white, kind: .bishop))
        #expect(out.grid[5][2].alternatives.contains(PieceChoice(color: .white, kind: .rook)))
        #expect(!out.grid[5][2].isConfident)
    }

    /// Une pièce MANQUÉE par le détecteur : la case est vide, et la pièce vue par les gabarits est proposée.
    @Test func aMissedPieceIsOfferedFromTheSecondOpinion() {
        let primary = emptyGrid()
        var secondary = emptyGrid()
        secondary[2][6] = piece(.black, .queen, 0.9)
        let out = reading(primary).crossChecked(against: reading(secondary))
        #expect(out.grid[2][6].occupancy.isEmpty)
        #expect(out.grid[2][6].alternatives == [PieceChoice(color: .black, kind: .queen)])
    }

    @Test func consistencyKeepsTheAlternatives() {
        var grid = emptyGrid()
        grid[0][0] = piece(.white, .pawn, 0.95, alternatives: [PieceChoice(color: .white, kind: .rook)])   // pion en rangée de fond
        let out = BoardConsistency.reconciled(grid)
        #expect(out[0][0].alternatives == [PieceChoice(color: .white, kind: .rook)])
    }

    // MARK: Éditeur

    @MainActor
    @Test func placingChoosesASquaresPieceWithoutTheActiveTool() {
        let vm = PositionEditorViewModel(fen: "4k3/8/8/8/8/8/8/4K3 w - - 0 1")
        let d4 = PositionEditorViewModel.square(.d, 4)
        vm.place((.knight, .white), at: d4)
        #expect(vm.pieces[d4]?.kind == .knight)
        vm.place(nil, at: d4)
        #expect(vm.pieces[d4] == nil)
    }
}
