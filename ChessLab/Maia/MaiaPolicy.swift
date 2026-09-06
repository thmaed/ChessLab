import Foundation

/// Un coup légal et la probabilité que Maia lui attribue.
struct MaiaCandidate: Hashable, Sendable {
    let move: MaiaMove
    let probability: Double
}

/// De 4 352 logits à une distribution sur les coups LÉGAUX, puis à un coup :
/// masque, softmax, température, top-p. Module pur, sans Core ML.
///
/// Réplique `sample_from_logits()` du dépôt de référence : une température
/// nulle prend le coup le plus probable ; top-p < 1 ne garde que la tête de
/// la distribution (toujours au moins le premier coup).
enum MaiaPolicy {

    /// Distribution sur les coups légaux, triée par probabilité décroissante.
    static func candidates(logits: [Float], legal: [MaiaMove]) -> [MaiaCandidate] {
        guard !legal.isEmpty else { return [] }
        let scores = legal.map { Double(logits[$0.index]) }
        let probabilities = softmax(scores)
        return zip(legal, probabilities)
            .map { MaiaCandidate(move: $0, probability: $1) }
            .sorted { $0.probability > $1.probability }
    }

    /// Tire un coup dans la distribution.
    ///
    /// - parameter temperature: 0 = le plus probable ; 1 = fidèle aux humains ;
    ///   au-delà, plus erratique.
    /// - parameter topP: seuil de nucleus (1 = désactivé).
    static func sample<G: RandomNumberGenerator>(
        _ candidates: [MaiaCandidate], temperature: Double, topP: Double = 1, using generator: inout G
    ) -> MaiaCandidate? {
        guard let first = candidates.first else { return nil }
        guard temperature > 0 else { return first }

        // Re-tempérer depuis les probabilités (équivalent à tempérer les
        // logits masqués, à une constante près que le softmax absorbe).
        let logs = candidates.map { log(max($0.probability, 1e-12)) / temperature }
        var weights = softmax(logs)

        if topP < 1 {
            // `candidates` est trié : on coupe la queue au-delà de topP, en
            // gardant toujours le premier.
            var cumulative = 0.0
            var kept = 0
            for weight in weights {
                if kept > 0, cumulative > topP { break }
                cumulative += weight
                kept += 1
            }
            weights = Array(weights.prefix(kept))
            let total = weights.reduce(0, +)
            weights = weights.map { $0 / total }
        }

        var roll = Double.random(in: 0..<1, using: &generator)
        for (index, weight) in weights.enumerated() {
            if roll < weight { return candidates[index] }
            roll -= weight
        }
        return candidates[weights.count - 1]
    }

    /// Softmax numériquement stable.
    static func softmax(_ values: [Double]) -> [Double] {
        guard let maximum = values.max() else { return [] }
        let exponentials = values.map { exp($0 - maximum) }
        let total = exponentials.reduce(0, +)
        return exponentials.map { $0 / total }
    }
}
