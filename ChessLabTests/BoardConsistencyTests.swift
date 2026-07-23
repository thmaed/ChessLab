import ChessKit
import Testing
@testable import ChessLab

/// Les garde-fous de cohérence : une lecture impossible aux échecs doit être
/// SIGNALÉE, jamais laissée sûre en silence. C'est le filet qui rattrape la
/// surconfiance du modèle sur un jeu de pièces inconnu.
struct BoardConsistencyTests {

    private func emptyGrid() -> [[SquareReading]] {
        [[SquareReading]](repeating: [SquareReading](repeating: .empty, count: 8), count: 8)
    }

    private func piece(_ color: Piece.Color, _ kind: Piece.Kind, _ confidence: Double = 0.9) -> SquareReading {
        SquareReading(occupancy: .piece(color: color, kind: kind), confidence: confidence)
    }

    /// Deux rois, chacun sa couleur, des pions sur leur rangée : rien à redire.
    @Test func aLegalPositionFlagsNothing() {
        var grid = emptyGrid()
        grid[0][4] = piece(.black, .king)   // e8
        grid[7][4] = piece(.white, .king)   // e1
        grid[6][0] = piece(.white, .pawn)   // 2e rangée
        grid[1][7] = piece(.black, .pawn)   // 7e rangée
        #expect(BoardConsistency.suspectCells(in: grid).isEmpty)
    }

    @Test func aPawnOnTheBackRankIsFlagged() {
        var grid = emptyGrid()
        grid[0][4] = piece(.black, .king)
        grid[7][4] = piece(.white, .king)
        grid[0][0] = piece(.white, .pawn)   // rangée de fond → impossible
        grid[7][3] = piece(.black, .pawn)   // rangée de fond → impossible
        let suspects = BoardConsistency.suspectCells(in: grid)
        #expect(suspects.contains(.init(row: 0, column: 0)))
        #expect(suspects.contains(.init(row: 7, column: 3)))
    }

    @Test func duplicateKingsAreBothFlagged() {
        var grid = emptyGrid()
        grid[7][4] = piece(.white, .king)
        grid[7][6] = piece(.white, .king)   // deux rois blancs : l'un est faux
        grid[0][4] = piece(.black, .king)
        let suspects = BoardConsistency.suspectCells(in: grid)
        #expect(suspects.contains(.init(row: 7, column: 4)))
        #expect(suspects.contains(.init(row: 7, column: 6)))
    }

    /// La confusion nº 1 du modèle : un roi lu comme une dame. Sans roi d'une
    /// couleur, on signale ses dames — le suspect le plus probable.
    @Test func aMissingKingFlagsTheSameColorQueens() {
        var grid = emptyGrid()
        grid[7][4] = piece(.white, .king)
        grid[0][3] = piece(.black, .queen)  // pas de roi noir : cette dame est suspecte
        let suspects = BoardConsistency.suspectCells(in: grid)
        #expect(suspects.contains(.init(row: 0, column: 3)))
    }

    @Test func moreThanEightPawnsFlagsTheLeastConfident() {
        var grid = emptyGrid()
        grid[7][4] = piece(.white, .king)
        grid[0][4] = piece(.black, .king)
        // 9 pions blancs sur les 2e/3e rangées, confiance décroissante.
        var confidence = 0.95
        var placed = 0
        for row in [6, 5] {
            for column in 0..<8 where placed < 9 {
                grid[row][column] = piece(.white, .pawn, confidence)
                confidence -= 0.05
                placed += 1
            }
        }
        // Le 9e (le moins sûr, dernier posé) doit être signalé ; le 1er (le plus
        // sûr) ne doit pas l'être.
        let suspects = BoardConsistency.suspectCells(in: grid)
        #expect(suspects.contains(.init(row: 5, column: 0)))   // 9e posé, confiance la plus basse
        #expect(!suspects.contains(.init(row: 6, column: 0)))  // 1er posé, confiance la plus haute
    }

    @Test func reconciledLowersConfidenceButKeepsOccupancy() {
        var grid = emptyGrid()
        grid[7][4] = piece(.white, .king)
        grid[0][4] = piece(.black, .king)
        grid[0][0] = piece(.white, .pawn, 0.95)   // pion de fond, lu « sûr »
        let out = BoardConsistency.reconciled(grid)
        #expect(out[0][0].occupancy == .piece(color: .white, kind: .pawn), "l'occupation est conservée")
        #expect(!out[0][0].isConfident, "mais la case est désormais signalée")
    }

    /// Plateau réel : le type sort `nil`. Aucune règle de type ne peut alors
    /// s'appliquer — la réconciliation doit être un non-événement.
    @Test func physicalReadingsWithoutKindAreNeverFlagged() {
        var grid = emptyGrid()
        grid[0][0] = SquareReading(occupancy: .piece(color: .white, kind: nil), confidence: 0.8)
        grid[7][7] = SquareReading(occupancy: .piece(color: .black, kind: nil), confidence: 0.8)
        #expect(BoardConsistency.suspectCells(in: grid).isEmpty)
    }
}

/// Le recroisement YOLO × gabarits : un second avis qui ne pèse que quand il
/// est sûr, et qui rattrape aussi bien un mauvais type qu'une pièce manquée.
struct ScanCrossCheckTests {

    private func emptyGrid() -> [[SquareReading]] {
        [[SquareReading]](repeating: [SquareReading](repeating: .empty, count: 8), count: 8)
    }

    private func reading(_ grid: [[SquareReading]]) -> BoardScanReading {
        BoardScanReading(grid: grid, source: .screenshot)
    }

    private func piece(_ color: Piece.Color, _ kind: Piece.Kind, _ confidence: Double = 0.9) -> SquareReading {
        SquareReading(occupancy: .piece(color: color, kind: kind), confidence: confidence)
    }

    @Test func agreementKeepsConfidence() {
        var yolo = emptyGrid(); yolo[5][2] = piece(.white, .knight, 0.9)
        var templates = emptyGrid(); templates[5][2] = piece(.white, .knight, 0.9)
        let out = reading(yolo).crossChecked(against: reading(templates))
        #expect(out.grid[5][2].isConfident)
    }

    @Test func aConfidentDisagreementIsFlaggedButOccupancyKept() {
        var yolo = emptyGrid(); yolo[5][2] = piece(.white, .knight, 0.9)
        var templates = emptyGrid(); templates[5][2] = piece(.white, .bishop, 0.9)
        let out = reading(yolo).crossChecked(against: reading(templates))
        #expect(out.grid[5][2].occupancy == .piece(color: .white, kind: .knight), "le verdict YOLO est conservé")
        #expect(!out.grid[5][2].isConfident, "mais la divergence est signalée")
    }

    @Test func anUnsureSecondaryStaysSilent() {
        var yolo = emptyGrid(); yolo[5][2] = piece(.white, .knight, 0.9)
        var templates = emptyGrid(); templates[5][2] = piece(.white, .bishop, 0.3)  // pas sûr
        let out = reading(yolo).crossChecked(against: reading(templates))
        #expect(out.grid[5][2].isConfident, "un second avis peu sûr ne signale pas")
    }

    /// Le pire défaut du détecteur d'objets : une pièce MANQUÉE, rendue « vide,
    /// sûre ». Les gabarits la voient encore et lèvent le doute.
    @Test func aConfidentSecondaryPieceVetoesAYoloEmpty() {
        let yolo = emptyGrid()   // YOLO n'a rien vu en (2,6)
        var templates = emptyGrid(); templates[2][6] = piece(.black, .queen, 0.9)
        let out = reading(yolo).crossChecked(against: reading(templates))
        #expect(!out.grid[2][6].isConfident, "la case vide « sûre » de YOLO est mise en doute")
    }
}
