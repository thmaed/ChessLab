import ChessKit

/// Valeur matérielle conventionnelle d'une pièce (le roi n'entre jamais
/// dans un calcul de matériel, valeur arbitraire non utilisée) — partagée
/// entre ``MoveClassifier`` (sacrifice) et ``PuzzleThemeDetector`` (pièce
/// en prise / fourchette).
func pieceValue(_ kind: Piece.Kind) -> Int {
    switch kind {
    case .pawn: 1
    case .knight, .bishop: 3
    case .rook: 5
    case .queen: 9
    case .king: 0
    }
}
