import ChessKit

/// Phase de partie simplifiée (trois catégories, pas de découpage plus
/// fin façon manuel d'échecs) — sert uniquement à organiser/filtrer la
/// bibliothèque de puzzles, pas une classification savante.
enum GamePhase: String, CaseIterable, Codable {
    case opening
    case middlegame
    case endgame

    var label: String {
        switch self {
        case .opening: "Ouverture"
        case .middlegame: "Milieu de partie"
        case .endgame: "Finale"
        }
    }

    var icon: String {
        switch self {
        case .opening: "flag"
        case .middlegame: "bolt.fill"
        case .endgame: "crown.fill"
        }
    }
}

/// Déduit la phase d'une position depuis son seul FEN (les puzzles
/// n'ont pas d'historique de coups) — heuristique volontairement
/// simple :
/// - Finale : plus de dame en jeu, OU peu de pièces majeures/mineures
///   restantes : sans dame, jusqu'à 6 pièces majeures/mineures au total
///   (typiquement une tour et une pièce mineure par camp) ; avec dame(s)
///   encore en jeu, seulement si presque plus rien d'autre ne reste
///   (≤ 2 au total) — une dame seule sur un plateau par ailleurs dégagé
///   ne fait pas une finale à elle seule, mais une position avec dames
///   ET plusieurs autres pièces reste un milieu de partie. Seuils
///   calibrés empiriquement sur l'échantillon Lichess embarqué (voir
///   PROGRESS.md) pour une répartition crédible plutôt qu'une majorité
///   artificielle de "finales".
/// - Ouverture : coup précoce (numéro de coup ≤ 10 dans le FEN) ET la
///   quasi-totalité du matériel de départ est encore là.
/// - Milieu de partie : tout le reste (le cas le plus fréquent pour un
///   puzzle tactique, la simplification menant souvent à une finale
///   n'étant qu'une minorité des cas).
enum GamePhaseClassifier {
    static func classify(fen: String) -> GamePhase {
        guard let position = Position(fen: fen) else { return .middlegame }
        let pieces = position.pieces

        let hasQueen = pieces.contains { $0.kind == .queen }
        let majorMinorCount = pieces.filter { $0.kind != .pawn && $0.kind != .king }.count
        let endgameThreshold = hasQueen ? 2 : 6

        if majorMinorCount <= endgameThreshold {
            return .endgame
        }

        let pawnCount = pieces.filter { $0.kind == .pawn }.count
        if fullmoveNumber(from: fen) <= 10, pawnCount >= 14, majorMinorCount >= 12 {
            return .opening
        }

        return .middlegame
    }

    private static func fullmoveNumber(from fen: String) -> Int {
        guard let field = fen.split(separator: " ").last, let number = Int(field) else { return .max }
        return number
    }
}
