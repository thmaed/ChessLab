import ChessKit
import Foundation

/// Énumère les coups légaux du camp au trait et les projette dans le
/// vocabulaire de Maia (``MaiaMoveTable``).
///
/// `Board.legalMoves(forPieceAt:)` de ChessKit rend les cases d'arrivée
/// légales d'une pièce SANS tenir compte du trait : on filtre donc les pièces
/// par couleur. Une arrivée de pion sur la dernière rangée compte pour quatre
/// coups (une promotion par pièce), comme dans le masque de référence.
enum MaiaLegalMoves {
    static func moves(in board: Board) -> [MaiaMove] {
        let position = board.position
        let mover = position.sideToMove
        let mirror = mover == .black
        let lastRank = mover == .white ? 8 : 1
        var result: [MaiaMove] = []

        for piece in position.pieces where piece.color == mover {
            for target in board.legalMoves(forPieceAt: piece.square) {
                let prefix = piece.square.notation + target.notation
                if piece.kind == .pawn, target.rank.value == lastRank {
                    for kind in MaiaMoveTable.promotionKinds {
                        guard let index = MaiaMoveTable.index(
                            from: piece.square, to: target, promotion: kind, mirror: mirror
                        ) else { continue }
                        result.append(MaiaMove(uci: prefix + MaiaMoveTable.promotionLetter(kind), index: index))
                    }
                } else if let index = MaiaMoveTable.index(from: piece.square, to: target, promotion: nil, mirror: mirror) {
                    result.append(MaiaMove(uci: prefix, index: index))
                }
            }
        }
        return result
    }
}
