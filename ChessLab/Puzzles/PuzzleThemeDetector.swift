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

    /// Une VRAIE fourchette : après le premier coup, la pièce qui vient de bouger
    /// attaque au moins deux cibles réelles, et ne peut pas être prise à son désavantage.
    ///
    /// « Attaque deux pièces » ne suffit pas : une dame qui prend et vise deux pièces
    /// PROTÉGÉES ne fourche rien (retour de Ron, 08/11/2026 : sur douze « fourchettes »
    /// détectées dans son fichier, cinq n'en étaient pas). Une cible est réelle si elle
    /// vaut plus que le fourchetteur, ou si elle n'est pas défendue.
    private static func isFork(_ move: Move, boardAfterMove: Board) -> Bool {
        guard forkerSurvives(move, boardAfterMove: boardAfterMove) else { return false }
        // Le roi attaqué (échec) est une cible : la fourchette classique roi + pièce.
        var targets = realTargets(of: move, boardAfterMove: boardAfterMove)
        if case .check = boardAfterMove.state { targets += 1 }
        return targets >= 2
    }

    /// Les pièces de valeur que le fourchetteur peut prendre sans y perdre :
    /// plus précieuses que lui, ou sans défense.
    private static func realTargets(of move: Move, boardAfterMove: Board) -> Int {
        let mover = move.piece.color
        let forkerValue = pieceValue(move.piece.kind)
        // Après le coup, c'est à l'ADVERSAIRE de jouer : on rend le trait au fourchetteur
        // pour simuler sa prise.
        let withForkerToMove = positionWithSideToMoveFlipped(boardAfterMove.position)
        var count = 0
        for square in boardAfterMove.legalMoves(forPieceAt: move.end) {
            guard let target = boardAfterMove.position.piece(at: square),
                  target.color != mover, pieceValue(target.kind) >= valuablePieceThreshold
            else { continue }
            if pieceValue(target.kind) > forkerValue { count += 1; continue }
            guard let position = withForkerToMove else { continue }
            var simulation = Board(position: position)
            guard simulation.move(pieceAt: move.end, to: square) != nil else { continue }
            let recaptured = simulation.position.pieces
                .filter { $0.color == mover.opposite }
                .contains { simulation.canMove(pieceAt: $0.square, to: square) }
            if !recaptured { count += 1 }
        }
        return count
    }

    /// Le fourchetteur n'est pas pris à son désavantage : toute prise de sa case est
    /// refusée à l'adversaire, soit parce que la pièce est défendue ET que le preneur
    /// vaut plus qu'elle (un échange égal défait la fourchette).
    private static func forkerSurvives(_ move: Move, boardAfterMove: Board) -> Bool {
        let mover = move.piece.color
        let forkerValue = pieceValue(move.piece.kind)
        for attacker in boardAfterMove.position.pieces where attacker.color != mover {
            guard boardAfterMove.canMove(pieceAt: attacker.square, to: move.end) else { continue }
            var simulation = boardAfterMove
            guard simulation.move(pieceAt: attacker.square, to: move.end) != nil else { continue }
            let defended = simulation.position.pieces
                .filter { $0.color == mover }
                .contains { simulation.canMove(pieceAt: $0.square, to: move.end) }
            if !defended || pieceValue(attacker.kind) <= forkerValue { return false }
        }
        return true
    }

    /// La même position, avec le trait à l'autre camp (et sans prise en passant).
    private static func positionWithSideToMoveFlipped(_ position: Position) -> Position? {
        var fields = position.fen.split(separator: " ").map(String.init)
        guard fields.count >= 4 else { return nil }
        fields[1] = fields[1] == "w" ? "b" : "w"
        fields[3] = "-"
        return Position(fen: fields.joined(separator: " "))
    }
}
