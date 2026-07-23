import Foundation

/// Résultat d'une partie du point de vue du « camp A » — la force
/// configurée à gauche dans les réglages du Laboratoire. L'alternance des
/// couleurs (A joue tantôt Blanc, tantôt Noir) est déjà résolue en amont
/// par ``LabViewModel`` ; ici A désigne toujours le même moteur/réglage,
/// indépendamment de la couleur, ce qui est exactement ce qu'il faut pour
/// estimer un écart Elo non biaisé par l'avantage des Blancs.
enum LabGameResult: String, Codable, Equatable {
    case winA
    case draw
    case winB
}

/// Statistiques agrégées d'une série Laboratoire (Stockfish vs Stockfish).
///
/// Entièrement pur et testable sans moteur : toutes les formules (score,
/// écart Elo, intervalle de confiance à 95 %, LOS) ne dépendent que des
/// comptes W/N/D et de la longueur des parties.
struct LabStats: Equatable {
    /// Longueurs de partie en demi-coups (plies), une entrée par partie
    /// terminée — sert aussi à l'histogramme.
    let plyCounts: [Int]
    let winsA: Int
    let draws: Int
    let winsB: Int

    init(results: [LabGameResult], plyCounts: [Int]) {
        self.plyCounts = plyCounts
        winsA = results.filter { $0 == .winA }.count
        draws = results.filter { $0 == .draw }.count
        winsB = results.filter { $0 == .winB }.count
    }

    var games: Int { winsA + draws + winsB }

    /// Score de A au sens échiquéen : 1 par gain, ½ par nulle.
    var score: Double {
        guard games > 0 else { return 0 }
        return (Double(winsA) + 0.5 * Double(draws)) / Double(games)
    }

    var scorePercent: Double { score * 100 }

    var averagePlies: Double {
        guard !plyCounts.isEmpty else { return 0 }
        return Double(plyCounts.reduce(0, +)) / Double(plyCounts.count)
    }

    /// Longueur moyenne en coups complets (un coup = deux demi-coups).
    var averageMoves: Double { averagePlies / 2 }

    /// Écart Elo estimé de A par rapport à B : −400·log₁₀(1/score − 1).
    /// `nil` quand le score vaut 0 ou 1 (écart théoriquement infini — trop
    /// peu de données pour trancher).
    var eloDifference: Double? { Self.elo(fromScore: score) }

    /// Intervalle de confiance à 95 % sur l'écart Elo, dérivé de l'erreur
    /// standard du score. `nil` s'il n'est pas calculable (< 2 parties, ou
    /// bornes de score dégénérées).
    var elo95ConfidenceInterval: (low: Double, high: Double)? {
        guard let se = scoreStandardError else { return nil }
        let loScore = clampScore(score - 1.96 * se)
        let hiScore = clampScore(score + 1.96 * se)
        guard let low = Self.elo(fromScore: loScore), let high = Self.elo(fromScore: hiScore) else { return nil }
        return (low, high)
    }

    /// Likelihood of Superiority : probabilité que A soit réellement plus
    /// fort que B, estimée sur les seules parties décisives (modèle
    /// binomial normal-approximé). 0,5 quand il n'y a aucune décision.
    var likelihoodOfSuperiority: Double {
        let decisive = winsA + winsB
        guard decisive > 0 else { return 0.5 }
        let x = Double(winsA - winsB) / (sqrt(2.0) * sqrt(Double(decisive)))
        return 0.5 * (1 + erf(x))
    }

    // MARK: Interne

    /// Erreur standard du score moyen (résultats codés 1 / ½ / 0).
    private var scoreStandardError: Double? {
        guard games > 1 else { return nil }
        let sumSquares = Double(winsA) * 1 + Double(draws) * 0.25 // + winsB * 0
        let mean = score
        let variance = max(0, sumSquares / Double(games) - mean * mean)
        return sqrt(variance / Double(games))
    }

    private func clampScore(_ s: Double) -> Double {
        min(max(s, 1e-6), 1 - 1e-6)
    }

    static func elo(fromScore s: Double) -> Double? {
        guard s > 0, s < 1 else { return nil }
        return -400 * log10(1 / s - 1)
    }
}

/// Un point de la courbe de progression du Laboratoire : score cumulé de A
/// (en %) après la partie `game`, avec sa bande de confiance à 95 %.
struct LabProgressPoint: Identifiable, Equatable {
    let game: Int          // numéro de partie, 1-based
    let scorePercent: Double
    let ciLow: Double       // borne basse du score % (95 %), dans [0 ; 100]
    let ciHigh: Double
    let result: LabGameResult
    var id: Int { game }
}

extension LabStats {
    /// Courbe de progression : un point par partie jouée, score cumulé de A
    /// (%) + intervalle de confiance à 95 % qui se resserre à mesure que la
    /// série devient significative. Pur et testable.
    static func progression(of games: [LabCompletedGame]) -> [LabProgressPoint] {
        var points: [LabProgressPoint] = []
        points.reserveCapacity(games.count)
        for index in games.indices {
            let prefix = games[0...index]
            let stats = LabStats(results: prefix.map(\.labResult), plyCounts: prefix.map(\.plyCount))
            let margin = 1.96 * (stats.scoreStandardError ?? 0)
            points.append(
                LabProgressPoint(
                    game: index + 1,
                    scorePercent: stats.score * 100,
                    ciLow: max(0, stats.score - margin) * 100,
                    ciHigh: min(1, stats.score + margin) * 100,
                    result: games[index].labResult
                )
            )
        }
        return points
    }
}
