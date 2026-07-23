import ChessKit

/// Validation de légalité d'un FEN, indépendamment du parseur de `ChessKit`
/// qui est volontairement permissif (il ne fait qu'une lecture structurelle).
///
/// Utilisé par la saisie FEN manuelle (étape 1) et, plus tard, par le
/// scanner d'échiquier et l'éditeur de position (étape 7) : un FEN illégal
/// ne doit **jamais** être envoyé au moteur.
enum FENValidator {

    static func isLegal(_ fen: String) -> Bool {
        errors(in: fen).isEmpty
    }

    static func errors(in fen: String) -> [String] {
        let trimmed = fen.trimmingCharacters(in: .whitespacesAndNewlines)
        let fields = trimmed.split(separator: " ").map(String.init)

        guard fields.count == 6, let position = Position(fen: trimmed) else {
            return ["FEN mal formé : 6 champs attendus (position, trait, roques, en passant, demi-coups, coups)."]
        }

        var errors: [String] = []

        let whiteKings = position.pieces.filter { $0.kind == .king && $0.color == .white }.count
        let blackKings = position.pieces.filter { $0.kind == .king && $0.color == .black }.count
        if whiteKings != 1 || blackKings != 1 {
            errors.append("Il faut exactement un roi blanc et un roi noir.")
        }

        let pawnOnEdgeRank = position.pieces.contains {
            $0.kind == .pawn && ($0.square.rank.value == 1 || $0.square.rank.value == 8)
        }
        if pawnOnEdgeRank {
            errors.append("Un pion ne peut pas être sur la 1re ou la 8e rangée.")
        }

        // Une position fraîchement chargée (aucun coup joué) ne peut avoir
        // dans son état initial qu'un `.check`/`.checkmate` portant sur le
        // camp qui N'A PAS le trait (cf. Board.updateState) : c'est
        // exactement la condition "camp adverse déjà en échec".
        if whiteKings == 1, blackKings == 1 {
            switch Board(position: position).state {
            case .check, .checkmate:
                errors.append("Le camp qui n'a pas le trait ne peut pas être déjà en échec.")
            default:
                break
            }

            // Symétrique du contrôle ci-dessus, que `Board.state` ne peut PAS
            // rendre à l'init (il n'inspecte que le camp sans le trait, voir
            // `GameOutcome.ofStartingPosition`) : un FEN où le camp AU trait
            // est déjà mat ou pat passait la validation, puis le moteur,
            // interrogé sur une position terminée, répondait `bestmove (none)`
            // — écran de jeu figé.
            if !hasLegalMove(in: position) {
                errors.append("Le camp au trait n'a aucun coup légal : la position est déjà terminée (mat ou pat).")
            }
        }

        let castling = fields[2]
        if castling != "-" {
            if castling.contains("K"), !hasRookAndKing(position, kingSquare: "e1", rookSquare: "h1", color: .white) {
                errors.append("Droit de petit roque blanc incohérent avec la position du roi/de la tour.")
            }
            if castling.contains("Q"), !hasRookAndKing(position, kingSquare: "e1", rookSquare: "a1", color: .white) {
                errors.append("Droit de grand roque blanc incohérent avec la position du roi/de la tour.")
            }
            if castling.contains("k"), !hasRookAndKing(position, kingSquare: "e8", rookSquare: "h8", color: .black) {
                errors.append("Droit de petit roque noir incohérent avec la position du roi/de la tour.")
            }
            if castling.contains("q"), !hasRookAndKing(position, kingSquare: "e8", rookSquare: "a8", color: .black) {
                errors.append("Droit de grand roque noir incohérent avec la position du roi/de la tour.")
            }
        }

        let enPassantField = fields[3]
        if enPassantField != "-", enPassantField.count == 2 {
            let epSquare = Square(enPassantField)
            let expectedPawnSquareNotation: String
            let expectedColor: Piece.Color

            switch epSquare.rank.value {
            case 3:
                expectedPawnSquareNotation = "\(epSquare.file.rawValue)4"
                expectedColor = .white
            case 6:
                expectedPawnSquareNotation = "\(epSquare.file.rawValue)5"
                expectedColor = .black
            default:
                expectedPawnSquareNotation = ""
                expectedColor = .white
                errors.append("Case en passant invalide : doit être sur la 3e ou 6e rangée.")
            }

            if !expectedPawnSquareNotation.isEmpty {
                let piece = position.piece(at: Square(expectedPawnSquareNotation))
                if piece?.kind != .pawn || piece?.color != expectedColor {
                    errors.append("Case en passant incohérente : aucun pion capturable à cet endroit.")
                }
            }
        }

        return errors
    }

    /// `Board.legalMoves(forPieceAt:)` ne consulte pas le trait : on peut
    /// donc l'interroger directement sur les pièces du camp au trait.
    private static func hasLegalMove(in position: Position) -> Bool {
        let board = Board(position: position)
        return position.pieces
            .filter { $0.color == position.sideToMove }
            .contains { !board.legalMoves(forPieceAt: $0.square).isEmpty }
    }

    private static func hasRookAndKing(
        _ position: Position,
        kingSquare: String,
        rookSquare: String,
        color: Piece.Color
    ) -> Bool {
        let king = position.piece(at: Square(kingSquare))
        let rook = position.piece(at: Square(rookSquare))
        return king?.kind == .king && king?.color == color
            && rook?.kind == .rook && rook?.color == color
    }
}
