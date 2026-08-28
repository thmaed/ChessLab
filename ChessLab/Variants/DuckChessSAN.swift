import ChessKit

/// Notation d'un coup de Duck Chess.
///
/// Proche du SAN classique, à une différence près qui dit la variante : il n'y
/// a ni « + » ni « # », puisqu'il n'y a ni échec ni mat. La capture du roi,
/// elle, se marque d'un « ++ » — une convention lisible pour le coup qui
/// termine la partie.
enum DuckChessSAN {

    static func build(
        move: DuckChessRules.Move, position: Position,
        legalMoves: [DuckChessRules.Move], capturesKing: Bool
    ) -> String {
        guard let piece = position.piece(at: move.from) else { return move.uci }
        let suffix = capturesKing ? "++" : ""

        if piece.kind == .king, abs(move.to.file.number - move.from.file.number) == 2 {
            return (move.to.file.number > move.from.file.number ? "O-O" : "O-O-O") + suffix
        }

        let targetOccupied = position.piece(at: move.to) != nil
        let isEnPassant = piece.kind == .pawn && move.from.file != move.to.file && !targetOccupied
        let isCapture = targetOccupied || isEnPassant

        var body = ""
        if piece.kind == .pawn {
            if isCapture { body += String(move.from.notation.prefix(1)) + "x" }
            body += move.to.notation
            if let promotion = move.promotion { body += "=" + promotion.rawValue }
        } else {
            body += piece.kind.rawValue
            body += disambiguation(piece: piece, move: move, legalMoves: legalMoves, position: position)
            if isCapture { body += "x" }
            body += move.to.notation
        }
        return body + suffix
    }

    private static func disambiguation(
        piece: Piece, move: DuckChessRules.Move,
        legalMoves: [DuckChessRules.Move], position: Position
    ) -> String {
        let others = legalMoves.compactMap { candidate -> Square? in
            guard candidate.from != move.from, candidate.to == move.to,
                  let other = position.piece(at: candidate.from),
                  other.kind == piece.kind, other.color == piece.color
            else { return nil }
            return candidate.from
        }
        guard !others.isEmpty else { return "" }
        if !others.contains(where: { $0.file == move.from.file }) {
            return String(move.from.notation.prefix(1))
        }
        if !others.contains(where: { $0.rank == move.from.rank }) {
            return String(move.from.notation.suffix(1))
        }
        return move.from.notation
    }
}
