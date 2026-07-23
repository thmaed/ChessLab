import ChessKit
import CoreGraphics
import Testing
@testable import ChessLab

/// Le mapping détections YOLO → grille 8×8, testé au carré près SANS jamais
/// charger de modèle : c'est la seule partie de l'intégration YOLO qui peut se
/// tromper silencieusement (une pièce sur la mauvaise case passe inaperçue),
/// donc la seule qu'on verrouille par des tests.
struct YOLODetectionMapperTests {

    /// Boîte normalisée (origine HAUT à gauche) couvrant la case `(row, column)`
    /// d'un plateau 8×8, comme la rendrait un détecteur bien calibré.
    private func box(row: Int, column: Int) -> CGRect {
        CGRect(x: Double(column) / 8, y: Double(row) / 8, width: 1.0 / 8, height: 1.0 / 8)
    }

    private func detection(
        _ color: Piece.Color, _ kind: Piece.Kind, row: Int, column: Int, confidence: Double = 0.9
    ) -> YOLODetectionMapper.Detection {
        .init(color: color, kind: kind, confidence: confidence, boundingBox: box(row: row, column: column))
    }

    @Test func placesEachPieceOnItsOwnSquare() {
        // Ligne 0 = haut de l'image (8e rangée vue des Blancs) : tour a8, roi e8.
        let detections = [
            detection(.black, .rook, row: 0, column: 0),
            detection(.black, .king, row: 0, column: 4),
            detection(.white, .pawn, row: 6, column: 4)
        ]

        let grid = YOLODetectionMapper.grid(from: detections)

        #expect(grid[0][0].occupancy == .piece(color: .black, kind: .rook))
        #expect(grid[0][4].occupancy == .piece(color: .black, kind: .king))
        #expect(grid[6][4].occupancy == .piece(color: .white, kind: .pawn))
        #expect(grid[4][4].occupancy == .empty)
    }

    /// Une pièce haute (roi, dame) déborde vers le HAUT de sa case ; son point
    /// d'appui — le bas de la boîte — doit rester sur la bonne case.
    @Test func aTallPieceIsAssignedByItsBaseNotItsTop() {
        // Boîte qui monte d'une case et demie au-dessus de la case d5, mais y
        // POSE : bas de boîte au centre de d5.
        let tall = YOLODetectionMapper.Detection(
            color: .white, kind: .queen, confidence: 0.8,
            boundingBox: CGRect(x: 3.0 / 8, y: 3.0 / 8 - 0.12, width: 1.0 / 8, height: 1.0 / 8 + 0.12)
        )
        let grid = YOLODetectionMapper.grid(from: [tall])

        #expect(grid[3][3].occupancy == .piece(color: .white, kind: .queen), "d5 (ligne 3, colonne 3)")
        #expect(grid[2][3].occupancy == .empty, "la case au-dessus reste vide")
    }

    @Test func twoDetectionsOnOneSquareKeepTheMoreConfident() {
        let grid = YOLODetectionMapper.grid(from: [
            detection(.white, .bishop, row: 5, column: 2, confidence: 0.4),
            detection(.white, .knight, row: 5, column: 2, confidence: 0.95)
        ])
        #expect(grid[5][2].occupancy == .piece(color: .white, kind: .knight))
        #expect(grid[5][2].confidence == 0.95)
    }

    @Test func lowConfidenceDetectionsAreFlaggedNotDropped() {
        let grid = YOLODetectionMapper.grid(from: [detection(.black, .bishop, row: 2, column: 6, confidence: 0.3)])
        #expect(grid[2][6].occupancy == .piece(color: .black, kind: .bishop))
        #expect(!grid[2][6].isConfident, "une détection peu sûre doit être signalée à la confirmation")
    }

    @Test func emptySquaresAreConfidentAbsence() {
        let grid = YOLODetectionMapper.grid(from: [])
        #expect(grid.flatMap { $0 }.allSatisfy { $0.occupancy.isEmpty })
        #expect(grid[0][0].isConfident, "l'absence de pièce reste une lecture confiante")
    }

    /// Le contrat de NOTRE dataset synthétique : 12 classes, ordre de `data.yaml`.
    @Test func theLabelVocabularyMatchesTheTrainingContract() {
        #expect(PieceLabel.trainingOrder.count == 12)
        #expect(PieceLabel.trainingOrder.first == "white-pawn")
        #expect(PieceLabel(rawValue: "black-king")?.kind == .king)
        #expect(PieceLabel(rawValue: "black-king")?.color == .black)
    }
}

/// Le résolveur de libellés : c'est lui qui permet de déposer N'IMPORTE QUEL
/// modèle YOLO (Hugging Face, Roboflow) sans toucher au code — chacun nomme ses
/// classes autrement. On vérifie donc les conventions du terrain.
struct PieceLabelResolverTests {

    private func expect(_ identifier: String, _ color: Piece.Color, _ kind: Piece.Kind) {
        let resolved = PieceLabelResolver.resolve(identifier)
        #expect(resolved?.color == color, "couleur de « \(identifier) »")
        #expect(resolved?.kind == kind, "type de « \(identifier) »")
    }

    @Test func kebabCase() {          // notre dataset, et beaucoup de Roboflow
        expect("white-pawn", .white, .pawn)
        expect("black-king", .black, .king)
    }

    @Test func spacedAndCapitalised() {   // la carte de yamero999
        expect("White Pawn", .white, .pawn)
        expect("Black Queen", .black, .queen)
    }

    @Test func camelCase() {
        expect("whiteBishop", .white, .bishop)
        expect("blackKnight", .black, .knight)
    }

    @Test func fenSingleLetter() {    // la casse porte la couleur
        expect("P", .white, .pawn)
        expect("p", .black, .pawn)
        expect("N", .white, .knight)
        expect("b", .black, .bishop)
        expect("K", .white, .king)
    }

    @Test func twoLetterCodes() {     // « wp », « bk », « wb »
        expect("wp", .white, .pawn)
        expect("bk", .black, .king)
        expect("wb", .white, .bishop)
        expect("bb", .black, .bishop)
    }

    @Test func underscoreAndReversedOrder() {
        expect("pawn_white", .white, .pawn)
        expect("king-black", .black, .king)
    }

    @Test func rejectsGarbage() {
        #expect(PieceLabelResolver.resolve("") == nil)
        #expect(PieceLabelResolver.resolve("corner") == nil)
        #expect(PieceLabelResolver.resolve("board") == nil)
    }
}

/// Le pipeline « plateau entier » de bout en bout, avec un détecteur FICTif :
/// on prouve que des détections produisent la bonne position FEN à travers
/// ``BoardScanner`` et ``BoardScanReading``, sans dépendre d'un `.mlpackage`.
struct YOLOPipelineTests {

    /// Détecteur fictif : rejoue une liste de détections fixée, quelle que soit
    /// l'image.
    private struct StubBoardClassifier: BoardClassifying {
        let detections: [YOLODetectionMapper.Detection]
        func classifyBoard(_ board: CGImage) -> [[SquareReading]]? {
            YOLODetectionMapper.grid(from: detections)
        }
    }

    private func box(row: Int, column: Int) -> CGRect {
        CGRect(x: Double(column) / 8, y: Double(row) / 8, width: 1.0 / 8, height: 1.0 / 8)
    }

    @Test func detectionsBecomeTheExpectedFEN() throws {
        // Roi blanc e1, roi noir e8, pion blanc e2 — la finale du parcours réel.
        let stub = StubBoardClassifier(detections: [
            .init(color: .black, kind: .king, confidence: 0.95, boundingBox: box(row: 0, column: 4)),
            .init(color: .white, kind: .pawn, confidence: 0.9, boundingBox: box(row: 6, column: 4)),
            .init(color: .white, kind: .king, confidence: 0.95, boundingBox: box(row: 7, column: 4))
        ])

        let dummyBoard = try #require(SolidBoardImage.make())
        let reading = try #require(
            BoardScanner.scan(board: dummyBoard, source: .screenshot, boardClassifier: stub)
        )
        let fen = reading.fen(rotation: .none, sideToMove: .white)

        #expect(fen.split(separator: " ")[0] == "4k3/8/8/8/8/8/4P3/4K3")
    }
}

/// Une image carrée unie, juste de quoi satisfaire la signature (le stub
/// ignore le contenu).
private enum SolidBoardImage {
    static func make(side: Int = 64) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(gray: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        return context.makeImage()
    }
}
