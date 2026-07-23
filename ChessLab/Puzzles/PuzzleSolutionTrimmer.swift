import ChessKit

/// Tronque la variante principale (PV) d'un puzzle **issu d'une partie de
/// l'utilisateur** en une solution courte et nette.
///
/// La génération (`AnalysisViewModel.generatePuzzles`) part de la PV
/// complète du moteur (jusqu'à ~10 demi-coups). Exiger cette séquence
/// exacte est fragile : la queue d'une PV n'est pas fiable, et un coup
/// gagnant ALTERNATIF y serait compté faux (voir instructions.md §G7). Les
/// puzzles Lichess, eux, sont curés pour l'unicité — cette troncature ne
/// concerne QUE les puzzles maison.
///
/// Heuristique **purement matérielle** (aucun moteur requis, donc
/// déterministe et testable) : on rejoue la PV et on coupe dès qu'après un
/// coup du résolveur son avantage matériel devient décisif (`≥ +3`, un
/// coup gagnant de pièce mineure) ET stable (la riposte adverse forcée ne
/// le résorbe pas) — ou à un mat. Plafond dur à `maxPlies`. En pratique la
/// plupart des puzzles maison deviennent 1 à 3 coups. La solution se
/// termine toujours sur un coup du résolveur (longueur impaire), pour que
/// le dernier geste demandé à l'utilisateur soit SON coup.
enum PuzzleSolutionTrimmer {
    static func trim(
        pv: [String],
        startFEN: String,
        decisiveGain: Int = 3,
        maxPlies: Int = 6
    ) -> [String] {
        guard let start = Position(fen: startFEN) else {
            return endingOnSolverMove(Array(pv.prefix(maxPlies)))
        }
        let solverColor = start.sideToMove
        let baseDiff = materialDiff(start, from: solverColor)

        var board = Board(position: start)
        var applied: [String] = []

        for (ply, lan) in pv.prefix(maxPlies).enumerated() {
            guard apply(lan: lan, to: &board) else { break }
            applied.append(lan)

            if case .checkmate = board.state {
                return applied // mat : décisif quel que soit le matériel
            }

            let solverJustMoved = ply.isMultiple(of: 2) // pv[0] = coup du résolveur
            guard solverJustMoved else { continue }

            let gain = materialDiff(board.position, from: solverColor) - baseDiff
            guard gain >= decisiveGain else { continue }

            // Stabilité : la riposte forcée (ply+1) ne doit pas ramener
            // l'avantage sous le seuil (sinon c'est un simple échange en
            // cours, la tactique n'est pas encore résolue).
            let replyIndex = ply + 1
            if replyIndex < pv.count && replyIndex < maxPlies {
                var probe = board
                if apply(lan: pv[replyIndex], to: &probe) {
                    let gainAfterReply = materialDiff(probe.position, from: solverColor) - baseDiff
                    if gainAfterReply >= decisiveGain {
                        return applied // décisif et stable → coupe ici
                    }
                    continue // reprise adverse : l'échange continue
                }
            }
            return applied // pas de riposte (ou inapplicable) : déjà décisif
        }

        return endingOnSolverMove(applied)
    }

    /// Une solution doit se terminer sur un coup du résolveur (index pair,
    /// donc longueur impaire) : sinon le dernier demi-coup est une riposte
    /// adverse auto-jouée, ce qui n'a pas de sens comme état "résolu".
    private static func endingOnSolverMove(_ moves: [String]) -> [String] {
        guard moves.count > 1, moves.count.isMultiple(of: 2) else { return moves }
        return Array(moves.dropLast())
    }

    /// Somme des valeurs matérielles de `color` moins celle de l'adversaire
    /// (le roi vaut 0, il n'entre pas dans le calcul).
    private static func materialDiff(_ position: Position, from color: Piece.Color) -> Int {
        position.pieces.reduce(0) { total, piece in
            let value = pieceValue(piece.kind)
            return total + (piece.color == color ? value : -value)
        }
    }

    /// Applique un coup en notation LAN ("e2e4", "e7e8q") sur `board`,
    /// promotion comprise. Même logique que
    /// `PuzzleSolveViewModel.applyForcedMove`.
    private static func apply(lan: String, to board: inout Board) -> Bool {
        guard lan.count >= 4 else { return false }
        let start = Square(String(lan.prefix(2)))
        let end = Square(String(lan.dropFirst(2).prefix(2)))
        guard let move = board.move(pieceAt: start, to: end) else { return false }
        if case .promotion = board.state {
            let kind: Piece.Kind = lan.count == 5
                ? (Piece.Kind(rawValue: String(lan.suffix(1)).uppercased()) ?? .queen)
                : .queen
            _ = board.completePromotion(of: move, to: kind)
        }
        return true
    }
}
