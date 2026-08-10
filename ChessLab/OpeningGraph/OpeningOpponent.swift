import Foundation

/// Choix de la riposte adverse en entraînement : aléatoire mais PONDÉRÉ par la
/// fréquence réelle en CLUB (à défaut, maîtres ; à défaut, uniforme), jamais
/// uniforme — pour que l'utilisateur affronte ce qu'il rencontre vraiment, pas
/// une distribution artificielle. Pur et testable (générateur injecté).
enum OpeningOpponent {

    static func weightedReply<G: RandomNumberGenerator>(
        from node: PositionNode, using generator: inout G
    ) -> MoveEdge? {
        let moves = node.moves
        guard !moves.isEmpty else { return nil }

        let weights = moves.map { max($0.popularityClub ?? $0.popularityMasters ?? 0, 0) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return moves.randomElement(using: &generator) }

        var roll = Double.random(in: 0..<total, using: &generator)
        for (index, weight) in weights.enumerated() {
            if roll < weight { return moves[index] }
            roll -= weight
        }
        return moves.last
    }
}
