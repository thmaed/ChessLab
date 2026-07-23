import ChessKit

/// Détection de thème best-effort pour un puzzle nouvellement généré —
/// heuristiques simples, pas une classification tactique exhaustive (pas
/// de détection de clouage par exemple, voir PROGRESS.md).
enum PuzzleThemeDetector {
    /// Valeur minimale pour qu'une pièce compte comme "de valeur" dans
    /// les heuristiques pièce en prise / fourchette (un pion capturé ou
    /// attaqué seul ne suffit pas à qualifier le thème).
    private static let valuablePieceThreshold = 3

    /// Rejoue `solutionLANs` depuis `startFEN` pour détecter le thème :
    /// mat sur la position finale, sinon pièce en prise / fourchette sur
    /// la position juste après le premier coup (celui que l'utilisateur
    /// doit trouver), sinon "Tactique" générique.
    static func detect(startFEN: String, solutionLANs: [String]) -> PuzzleTheme {
        guard let startPosition = Position(fen: startFEN) else { return .tactic }

        var board = Board(position: startPosition)
        var firstMove: Move?
        var boardAfterFirstMove: Board?

        for (ply, lan) in solutionLANs.enumerated() {
            guard lan.count >= 4 else { break }
            let start = Square(String(lan.prefix(2)))
            let end = Square(String(lan.dropFirst(2).prefix(2)))
            guard let move = board.move(pieceAt: start, to: end) else { break }

            if ply == 0 {
                firstMove = move
                boardAfterFirstMove = board
            }
        }

        if case .checkmate = board.state {
            return .checkmate
        }

        guard let firstMove, let boardAfterFirstMove else { return .tactic }

        if isHangingPieceCapture(firstMove, boardAfterMove: boardAfterFirstMove) {
            return .hangingPiece
        }

        if isFork(firstMove, boardAfterMove: boardAfterFirstMove) {
            return .fork
        }

        return .tactic
    }

    /// Le premier coup capture une pièce de valeur, et aucune pièce
    /// adverse ne peut reprendre sur cette case — la pièce était donc
    /// vraiment "en prise" (pas juste un échange équilibré).
    private static func isHangingPieceCapture(_ move: Move, boardAfterMove: Board) -> Bool {
        guard case let .capture(captured) = move.result, pieceValue(captured.kind) >= valuablePieceThreshold else {
            return false
        }
        let canRecapture = boardAfterMove.position.pieces
            .filter { $0.color == move.piece.color.opposite }
            .contains { boardAfterMove.canMove(pieceAt: $0.square, to: move.end) }
        return !canRecapture
    }

    /// Après le premier coup, la pièce qui vient de bouger attaque au
    /// moins deux pièces adverses de valeur — une fourchette typique.
    private static func isFork(_ move: Move, boardAfterMove: Board) -> Bool {
        let attackedValuableTargets = boardAfterMove.legalMoves(forPieceAt: move.end)
            .compactMap { boardAfterMove.position.piece(at: $0) }
            .filter { $0.color != move.piece.color && pieceValue($0.kind) >= valuablePieceThreshold }
        return attackedValuableTargets.count >= 2
    }
}
