import ChessKit
import Testing
@testable import ChessLab

/// Orientation de lecture devinée : le cas qui casse en vrai est le MILIEU de
/// partie, pions avancés et roi noir raté par le modèle — la légalité ne peut
/// alors plus trancher.
struct ReadingOrientationTests {

    /// Grille `[ligne][colonne]`, ligne 0 = rangée 8, depuis le champ pièces
    /// d'une FEN. `omitting` retire des pièces pour simuler ce que le modèle
    /// rate (les rois noirs, typiquement).
    private func grid(fen: String, omitting: Set<Character> = []) -> [[SquareReading]] {
        var rows: [[SquareReading]] = []
        for rank in fen.split(separator: " ")[0].split(separator: "/") {
            var row: [SquareReading] = []
            for character in rank {
                if let empty = character.wholeNumberValue {
                    row.append(contentsOf: [SquareReading](repeating: .empty, count: empty))
                } else if omitting.contains(character) {
                    row.append(.empty)
                } else {
                    row.append(SquareReading(occupancy: .piece(
                        color: character.isUppercase ? .white : .black, kind: kind(character)
                    ), confidence: 0.9))
                }
            }
            rows.append(row)
        }
        return rows
    }

    private func kind(_ character: Character) -> Piece.Kind {
        switch Character(character.lowercased()) {
        case "p": .pawn
        case "n": .knight
        case "b": .bishop
        case "r": .rook
        case "q": .queen
        default: .king
        }
    }

    /// Structure avancée : PLUS AUCUN pion sur sa rangée de départ (ni sur la
    /// 1re ou la 8e). L'ancien score — qui ne comptait que les pions restés au
    /// départ — y vaut 0 des DEUX côtés : égalité, et l'orientation était alors
    /// décidée par l'ordre des candidates, pas par l'image.
    private let middlegame = "6k1/8/4p2p/p2pP3/3P1P2/6P1/8/6K1 w - - 0 1"

    @Test func aMiddlegameIsReadTheRightWayUp() {
        let reading = BoardScanReading(grid: grid(fen: middlegame), source: .screenshot)
        #expect(reading.suggestedRotation() == .none)
    }

    /// LE cas du bug : sans roi noir aucune orientation n'est légale, donc tout
    /// repose sur les pions.
    @Test func aMiddlegameWithoutTheBlackKingIsStillReadTheRightWayUp() {
        let reading = BoardScanReading(grid: grid(fen: middlegame, omitting: ["k"]), source: .screenshot)
        #expect(reading.suggestedRotation() == .none)
    }
}

/// Fait tourner le VRAI modèle sur un diagramme rendu dont l'orientation est
/// connue — le seul test qui prouve que la chaîne Vision → grille ne retourne
/// pas l'image. Ignoré si le `.mlpackage` n'est pas dans le bundle.
struct YOLORealModelOrientationTests {

    @Test func theRealModelReadsTheBoardTheRightWayUp() throws {
        guard let classifier = YOLOBoardClassifier() else { return }

        let position = try #require(Position(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"))
        let board = try #require(BoardImageRenderer.renderBoard(
            position: position, theme: .classic, side: 800, orientation: .white
        ))
        let grid = try #require(classifier.classifyBoard(board))

        // Les Blancs sont lus de façon fiable : c'est sur eux qu'on ancre
        // l'orientation. Ligne 7 = rangée 1 = pièces blanches, ligne 6 = pions.
        for column in 0..<8 {
            #expect(grid[7][column].occupancy.color == .white, "ligne 7, colonne \(column)")
            #expect(grid[6][column].occupancy == .piece(color: .white, kind: .pawn))
        }
        // Et rien de blanc en haut de l'image.
        for column in 0..<8 {
            #expect(grid[0][column].occupancy.color != .white)
        }

        let reading = BoardScanReading(grid: grid, source: .screenshot)
        #expect(reading.suggestedRotation() == .none)
    }
}
