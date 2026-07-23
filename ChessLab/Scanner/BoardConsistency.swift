import ChessKit
import Foundation

/// Contrôles de cohérence d'échecs appliqués à une grille lue, quel que soit
/// le classifieur qui l'a produite (YOLO ou gabarits).
///
/// Raison d'être : un détecteur d'objets rend une confiance PAR case, sans
/// jamais regarder le plateau dans son ensemble — et sa confiance est
/// notoirement surestimée sur une image hors distribution (un jeu de pièces
/// qu'il n'a pas vu à l'entraînement). Or certaines lectures sont IMPOSSIBLES
/// aux échecs : un pion sur la rangée de fond, deux rois de la même couleur.
/// Elles trahissent une confusion (typiquement roi↔dame, ou une pièce d'un jeu
/// inconnu mal reconnue) que la confiance brute n'a pas signalée.
///
/// On ne CORRIGE jamais en silence : on fait chuter la confiance des cases
/// fautives sous le seuil, pour qu'elles soient surlignées à la confirmation.
/// C'est l'utilisateur qui tranche — la garantie « rien ne passe sans un
/// regard humain » du scanner.
///
/// Pur (grille → grille), sans image ni état : testable directement.
enum BoardConsistency {

    /// Confiance imposée à une case qui viole une règle dure. Sous
    /// ``SquareReading/confidenceThreshold`` : la case sera signalée.
    static let violationConfidence = 0.2

    /// Position dans la grille brute, `[ligne][colonne]`, ligne 0 en haut.
    struct Cell: Hashable {
        let row: Int
        let column: Int
    }

    /// Grille inchangée dans ses OCCUPATIONS, mais dont la confiance des cases
    /// incohérentes a été abaissée sous le seuil de signalement. On ne devine
    /// pas la bonne pièce à leur place : on avoue seulement le doute.
    static func reconciled(_ grid: [[SquareReading]]) -> [[SquareReading]] {
        let suspects = suspectCells(in: grid)
        guard !suspects.isEmpty else { return grid }

        return grid.indices.map { row in
            grid[row].indices.map { column in
                let reading = grid[row][column]
                guard suspects.contains(Cell(row: row, column: column)) else { return reading }
                return SquareReading(
                    occupancy: reading.occupancy,
                    confidence: min(reading.confidence, violationConfidence)
                )
            }
        }
    }

    /// Cases dont la lecture contredit une règle dure des échecs.
    ///
    /// On ne retient que les règles qui se LOCALISENT sur une case précise —
    /// une confusion de type se voit là où elle casse une invariante. Les
    /// simples improbabilités sont écartées : deux fous de même couleur de case
    /// restent légaux après promotion, une dame en trop aussi.
    static func suspectCells(in grid: [[SquareReading]]) -> Set<Cell> {
        var suspects = Set<Cell>()
        var kings: [Piece.Color: [Cell]] = [.white: [], .black: []]
        var queens: [Piece.Color: [Cell]] = [.white: [], .black: []]
        var pawns: [Piece.Color: [(cell: Cell, confidence: Double)]] = [.white: [], .black: []]

        let lastRow = grid.count - 1
        for row in grid.indices {
            for column in grid[row].indices {
                // Une case au type inconnu (plateau réel : `kind == nil`) ne peut
                // violer aucune règle de type — on ne juge que ce qui est lu.
                guard case let .piece(color, kind) = grid[row][column].occupancy, let kind else { continue }
                let cell = Cell(row: row, column: column)

                // Pion sur une rangée extrême : impossible aux échecs. La grille
                // a la ligne 0 en haut et la dernière en bas — les deux rangées
                // de fond, quelle que soit l'orientation 0°/180° d'un diagramme.
                if kind == .pawn, row == 0 || row == lastRow {
                    suspects.insert(cell)
                }

                switch kind {
                case .king: kings[color]?.append(cell)
                case .queen: queens[color]?.append(cell)
                case .pawn: pawns[color]?.append((cell, grid[row][column].confidence))
                default: break
                }
            }
        }

        for color in [Piece.Color.white, .black] {
            let colorKings = kings[color] ?? []
            // Deux rois d'une couleur : l'un est faux, on ne sait pas lequel —
            // les deux sont donc à vérifier.
            if colorKings.count > 1 { suspects.formUnion(colorKings) }
            // Aucun roi : il a le plus souvent été lu comme une DAME (même
            // silhouette haute, croix contre couronne — la confusion nº 1 du
            // modèle). On signale les dames de cette couleur : le suspect le
            // plus probable, et le seul localisable.
            if colorKings.isEmpty { suspects.formUnion(queens[color] ?? []) }
            // Plus de 8 pions : impossible. On signale les MOINS sûrs au-delà de
            // 8 — ce sont eux qui ont le plus de chances d'être une autre pièce
            // mal lue.
            let colorPawns = (pawns[color] ?? []).sorted { $0.confidence > $1.confidence }
            if colorPawns.count > 8 {
                for extra in colorPawns[8...] { suspects.insert(extra.cell) }
            }
        }

        return suspects
    }
}
