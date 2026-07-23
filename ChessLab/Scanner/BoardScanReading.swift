import ChessKit
import CoreGraphics
import Foundation

/// Orientation de lecture d'un plateau scanné.
///
/// Une image ne dit JAMAIS de quel côté on la regarde. Pour un diagramme
/// numérique, deux cas suffisent (0° / 180° — on ne publie pas un échiquier
/// couché) ; une photo zénithale d'un plateau réel, elle, n'a aucune
/// orientation de référence, d'où les quatre quarts de tour.
enum BoardReadingRotation: Int, CaseIterable, Identifiable {
    case none = 0
    case quarter = 1
    case half = 2
    case threeQuarters = 3

    var id: Int { rawValue }

    var degrees: Int { rawValue * 90 }

    /// Les seules orientations plausibles pour une source donnée.
    static func candidates(for source: ScanSource) -> [BoardReadingRotation] {
        // Un diagramme numérique a toujours les Blancs en bas OU en haut :
        // deux orientations, jamais quatre (le plateau réel, seul cas à quatre,
        // n'existe plus — voir ``ScanSource``).
        [.none, .half]
    }

    var next: BoardReadingRotation {
        BoardReadingRotation(rawValue: (rawValue + 1) % 4) ?? .none
    }
}

/// Résultat d'un scan : ce qu'on a lu sur chaque case, plus de quoi en faire
/// une position.
struct BoardScanReading {
    /// `[ligne][colonne]`, ligne 0 en haut de l'IMAGE — avant toute
    /// rotation.
    let grid: [[SquareReading]]
    let source: ScanSource

    /// Lectures replacées sur l'échiquier pour une orientation donnée.
    func squares(rotation: BoardReadingRotation) -> [Square: SquareReading] {
        let rotated = Self.rotate(grid, quarterTurns: rotation.rawValue)
        var result: [Square: SquareReading] = [:]

        for row in 0..<8 {
            for column in 0..<8 {
                // Après rotation, la ligne 0 est la 8e rangée et la colonne 0
                // la colonne a — la vue « Blancs en bas », convention de
                // `BoardImageRenderer.square`.
                result[BoardImageRenderer.square(row: row, column: column, orientation: .white)] = rotated[row][column]
            }
        }
        return result
    }

    func pieces(rotation: BoardReadingRotation) -> [Square: Piece] {
        var pieces: [Square: Piece] = [:]
        for (square, reading) in squares(rotation: rotation) {
            if case let .piece(color, kind) = reading.occupancy, let kind {
                pieces[square] = Piece(kind, color: color, square: square)
            }
        }
        return pieces
    }

    /// Cases dont la lecture est douteuse — surlignées à la confirmation.
    func lowConfidenceSquares(rotation: BoardReadingRotation) -> Set<Square> {
        Set(squares(rotation: rotation).filter { !$0.value.isConfident }.map(\.key))
    }

    /// Cases occupées dont le TYPE reste à préciser (plateau réel, Lot 1.E).
    func squaresNeedingKind(rotation: BoardReadingRotation) -> Set<Square> {
        Set(squares(rotation: rotation).filter { $0.value.occupancy.needsKind }.map(\.key))
    }

    /// Les mêmes, avec la couleur qu'on a su lire — de quoi les afficher et
    /// filtrer la palette de complétion à la bonne couleur.
    func unknownPieces(rotation: BoardReadingRotation) -> [Square: Piece.Color] {
        var result: [Square: Piece.Color] = [:]
        for (square, reading) in squares(rotation: rotation) {
            if case let .piece(color, kind) = reading.occupancy, kind == nil {
                result[square] = color
            }
        }
        return result
    }

    var pieceCount: Int {
        grid.flatMap { $0 }.count { !$0.occupancy.isEmpty }
    }

    // MARK: Orientation

    /// Rotation d'un quart de tour dans le sens horaire, `quarterTurns` fois.
    static func rotate<T>(_ grid: [[T]], quarterTurns: Int) -> [[T]] {
        let turns = ((quarterTurns % 4) + 4) % 4
        guard turns > 0 else { return grid }

        var result = grid
        for _ in 0..<turns {
            let size = result.count
            result = (0..<size).map { row in
                (0..<size).map { column in
                    result[size - 1 - column][row]
                }
            }
        }
        return result
    }

    /// Orientation à proposer par défaut.
    ///
    /// Le prompt exige de pouvoir « inverser la lecture » ; autant deviner
    /// quand c'est possible. Une seule orientation qui donne une position
    /// LÉGALE tranche la question ; sinon on retient celle dont les pions
    /// sont le mieux placés, et l'utilisateur garde la main.
    func suggestedRotation(sideToMove: Piece.Color = .white) -> BoardReadingRotation {
        let candidates = BoardReadingRotation.candidates(for: source)

        let legal = candidates.filter { rotation in
            FENValidator.isLegal(fen(rotation: rotation, sideToMove: sideToMove))
        }
        if legal.count == 1 { return legal[0] }

        // Départage : des pions sur la 1re ou la 8e rangée sont impossibles,
        // c'est le signe le plus net d'une lecture à l'envers.
        let ranked = (legal.isEmpty ? candidates : legal).map { rotation in
            (rotation: rotation, score: pawnPlausibility(rotation: rotation))
        }
        return ranked.max { $0.score < $1.score }?.rotation ?? .none
    }

    private func pawnPlausibility(rotation: BoardReadingRotation) -> Int {
        var score = 0
        for (square, reading) in squares(rotation: rotation) {
            guard case let .piece(color, kind) = reading.occupancy, kind == .pawn else { continue }
            let rank = square.rank.value
            if rank == 1 || rank == 8 { score -= 4 }
            // Un pion sur sa rangée de départ est un bon signe.
            if (color == .white && rank == 2) || (color == .black && rank == 7) { score += 1 }
        }
        return score
    }

    // MARK: FEN

    /// FEN de la lecture. Les droits de roque sont déduits de la position
    /// (roi et tour sur leur case), jamais inventés : une image ne dit pas si
    /// le roi a déjà bougé. L'utilisateur les corrige à la confirmation.
    func fen(rotation: BoardReadingRotation, sideToMove: Piece.Color) -> String {
        let pieces = pieces(rotation: rotation)

        var rows: [String] = []
        for rank in stride(from: 8, through: 1, by: -1) {
            var row = ""
            var emptyRun = 0

            for file in Square.File.allCases {
                if let piece = pieces[PositionEditorViewModel.square(file, rank)] {
                    if emptyRun > 0 { row += "\(emptyRun)"; emptyRun = 0 }
                    row += fenCharacter(for: piece)
                } else {
                    emptyRun += 1
                }
            }
            if emptyRun > 0 { row += "\(emptyRun)" }
            rows.append(row)
        }

        var castling = ""
        if canCastle(pieces, color: .white, king: "e1", rook: "h1") { castling += "K" }
        if canCastle(pieces, color: .white, king: "e1", rook: "a1") { castling += "Q" }
        if canCastle(pieces, color: .black, king: "e8", rook: "h8") { castling += "k" }
        if canCastle(pieces, color: .black, king: "e8", rook: "a8") { castling += "q" }
        if castling.isEmpty { castling = "-" }

        return "\(rows.joined(separator: "/")) \(sideToMove == .white ? "w" : "b") \(castling) - 0 1"
    }

    private func canCastle(_ pieces: [Square: Piece], color: Piece.Color, king: String, rook: String) -> Bool {
        let kingPiece = pieces[Square(king)]
        let rookPiece = pieces[Square(rook)]
        return kingPiece?.kind == .king && kingPiece?.color == color
            && rookPiece?.kind == .rook && rookPiece?.color == color
    }

    private func fenCharacter(for piece: Piece) -> String {
        let letter: String
        switch piece.kind {
        case .pawn: letter = "P"
        case .knight: letter = "N"
        case .bishop: letter = "B"
        case .rook: letter = "R"
        case .queen: letter = "Q"
        case .king: letter = "K"
        }
        return piece.color == .white ? letter : letter.lowercased()
    }
}

extension BoardScanReading {

    /// Confiance imposée à une case où un SECOND classifieur, lui-même sûr de
    /// lui, lit autre chose que la lecture principale. Sous le seuil : signalée.
    static let crossCheckConfidence = 0.4

    /// Recroise cette lecture (la principale, YOLO) avec une seconde obtenue
    /// par un classifieur indépendant (les gabarits) : là où le second est SÛR
    /// et contredit le principal, la case est signalée. On garde l'occupation
    /// du principal — on ne fait que douter tout haut, jamais réécrire.
    ///
    /// Le second ne pèse que quand il est confiant. Sur un jeu de pièces qu'il
    /// ne connaît pas, ses scores s'effondrent et il se tait : pas d'inondation
    /// de faux signalements. Réciproquement, il rattrape le pire défaut du
    /// détecteur d'objets — une pièce MANQUÉE, que YOLO rend « vide, sûre »,
    /// mais que les gabarits voient encore.
    func crossChecked(against other: BoardScanReading) -> BoardScanReading {
        guard grid.count == other.grid.count else { return self }

        let merged = grid.indices.map { row -> [SquareReading] in
            guard grid[row].count == other.grid[row].count else { return grid[row] }
            return grid[row].indices.map { column -> SquareReading in
                let mine = grid[row][column]
                let theirs = other.grid[row][column]
                guard theirs.isConfident, theirs.occupancy != mine.occupancy else { return mine }
                return SquareReading(
                    occupancy: mine.occupancy,
                    confidence: min(mine.confidence, Self.crossCheckConfidence)
                )
            }
        }
        return BoardScanReading(grid: merged, source: source)
    }
}

/// Enchaîne la découpe et le classifieur.
enum BoardScanner {
    /// - parameter squares: sortie de ``BoardRectifier/slice(_:)``.
    static func scan(
        squares: [[CGImage]], source: ScanSource, classifier: SquareClassifying
    ) -> BoardScanReading {
        // La grille entière, jamais case par case : c'est ce qui laisse un
        // classifieur de plateau réel exploiter le contexte global. Passée par
        // ``BoardConsistency`` : une lecture impossible aux échecs est signalée,
        // jamais laissée sûre en silence.
        BoardScanReading(grid: BoardConsistency.reconciled(classifier.classify(grid: squares)), source: source)
    }

    /// Variante « plateau entier » : un détecteur d'objets (YOLO) lit l'image
    /// redressée d'un seul tenant. `nil` si le modèle est absent — l'appelant
    /// retombe alors sur la variante par cases.
    static func scan(
        board: CGImage, source: ScanSource, boardClassifier: BoardClassifying
    ) -> BoardScanReading? {
        boardClassifier.classifyBoard(alignedToGrid(board) ?? board)
            .map { BoardScanReading(grid: BoardConsistency.reconciled($0), source: source) }
    }

    /// Recale l'image redressée sur les lignes du damier AVANT la détection
    /// d'objets.
    ///
    /// Le chemin par cases passe par ``BoardGridFinder`` (dans
    /// ``BoardRectifier/rectifyAndSlice(_:quad:)``) ; le chemin YOLO, lui,
    /// découpe l'image en huitièmes exacts et héritait donc de l'erreur de
    /// cadrage telle quelle — y compris la marge de sécurité de 2 % que
    /// ``CheckerboardDetector`` ajoute EXPRÈS en comptant sur ce recalage.
    /// Sans cette étape, le plateau n'occupe que 96 % de l'image et chaque
    /// case est décalée d'un fond de case au bord.
    private static func alignedToGrid(_ rectified: CGImage) -> CGImage? {
        let grid = BoardGridFinder.grid(in: rectified)
        guard let left = grid.columns.first, let right = grid.columns.last,
              let top = grid.rows.first, let bottom = grid.rows.last
        else { return nil }

        let rect = CGRect(x: left, y: top, width: right - left, height: bottom - top).integral
        guard rect.width > 0, rect.height > 0,
              let cropped = rectified.cropping(to: rect)
        else { return nil }
        return BoardRectifier.resize(cropped, to: BoardRectifier.normalizedSide)
    }
}
