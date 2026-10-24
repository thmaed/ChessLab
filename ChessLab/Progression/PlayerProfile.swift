import ChessKit
import Foundation

/// Une partie du joueur, réduite à ce que le profil regarde.
struct AnalyzedGame: Equatable {
    let date: Date
    let accuracy: Double?
    let phases: [GamePhase: PhaseLoss]
    let themes: [String: Int]
    let openingName: String?
}

/// Le profil de faiblesses du joueur, tiré de ses parties ANALYSÉES (A4) :
/// où il perd des points, quelles tactiques il manque, comment sa précision
/// évolue, quelles ouvertures lui coûtent. Pur : des parties, un profil.
///
/// Seules comptent les parties jouées contre l'ordinateur (le « vous » est
/// connu) et analysées. Une partie analysée avant A4 n'a pas de profil par phase
/// — elle compte pour la précision, pas pour le reste.
struct PlayerProfile: Equatable {

    struct PhaseStat: Equatable, Identifiable {
        let phase: GamePhase
        /// Points de probabilité de gain perdus par coup, hors théorie.
        let averageLoss: Double
        let moves: Int
        var id: String { phase.rawValue }
    }

    struct ThemeStat: Equatable, Identifiable {
        /// `mate`, `hanging`, `fork`, `discovery`, `pin` ou `other`.
        let theme: String
        let count: Int
        var id: String { theme }
    }

    struct OpeningStat: Equatable, Identifiable {
        let name: String
        let games: Int
        /// Points perdus par coup hors théorie, dans la phase d'ouverture.
        let averageLoss: Double
        var id: String { name }
    }

    struct AccuracyTrend: Equatable {
        /// Précision des parties les plus récentes (dix au plus), de la plus
        /// ancienne à la plus récente — la courbe.
        let recent: [Double]
        let recentAverage: Double
        /// Moyenne des dix précédentes, si au moins trois.
        let previousAverage: Double?
        var delta: Double? { previousAverage.map { recentAverage - $0 } }
    }

    let games: Int
    let accuracy: AccuracyTrend?
    let phases: [PhaseStat]
    let weakestPhase: PhaseStat?
    let themes: [ThemeStat]
    let openings: [OpeningStat]

    /// Sous ce nombre de parties analysées, le profil n'est pas montré :
    /// deux parties ne font pas une tendance.
    static let minimumGames = 3
    /// Sous ce nombre de coups comptés, une phase n'est pas jugée.
    static let minimumPhaseMoves = 8
    static let minimumOpeningMoves = 6
    static let trendWindow = 10

    var isMeaningful: Bool { games >= Self.minimumGames }

    static func compute(from games: [AnalyzedGame]) -> PlayerProfile {
        let ordered = games.sorted { $0.date < $1.date }

        // Précision : les dix dernières contre les dix d'avant.
        let accuracies = ordered.compactMap(\.accuracy)
        var trend: AccuracyTrend?
        if !accuracies.isEmpty {
            let recent = Array(accuracies.suffix(trendWindow))
            let earlier = Array(accuracies.dropLast(recent.count).suffix(trendWindow))
            trend = AccuracyTrend(
                recent: recent,
                recentAverage: recent.reduce(0, +) / Double(recent.count),
                previousAverage: earlier.count >= 3 ? earlier.reduce(0, +) / Double(earlier.count) : nil
            )
        }

        // Phases : pertes cumulées, puis moyenne par coup.
        var totals: [GamePhase: PhaseLoss] = [:]
        for game in ordered {
            for (phase, loss) in game.phases {
                totals[phase, default: PhaseLoss()].total += loss.total
                totals[phase, default: PhaseLoss()].count += loss.count
            }
        }
        let phaseStats: [PhaseStat] = GamePhase.allCases.compactMap { phase in
            guard let loss = totals[phase], loss.count >= minimumPhaseMoves, let average = loss.average
            else { return nil }
            return PhaseStat(phase: phase, averageLoss: average, moves: loss.count)
        }
        let weakest = phaseStats.count >= 2 ? phaseStats.max { $0.averageLoss < $1.averageLoss } : nil

        // Tactiques manquées.
        var themeTotals: [String: Int] = [:]
        for game in ordered { for (theme, count) in game.themes { themeTotals[theme, default: 0] += count } }
        let themes = themeTotals
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(3).map { ThemeStat(theme: $0.key, count: $0.value) }

        // Ouvertures : perte par coup hors théorie dans la phase d'ouverture.
        var byOpening: [String: (games: Int, loss: PhaseLoss)] = [:]
        for game in ordered {
            guard let name = game.openingName, let opening = game.phases[.opening], opening.count > 0 else { continue }
            var entry = byOpening[name] ?? (0, PhaseLoss())
            entry.games += 1
            entry.loss.total += opening.total
            entry.loss.count += opening.count
            byOpening[name] = entry
        }
        let openings: [OpeningStat] = byOpening.compactMap { name, entry in
            guard entry.games >= 2, entry.loss.count >= minimumOpeningMoves, let average = entry.loss.average,
                  average > 0
            else { return nil }
            return OpeningStat(name: name, games: entry.games, averageLoss: average)
        }
        .sorted { $0.averageLoss != $1.averageLoss ? $0.averageLoss > $1.averageLoss : $0.name < $1.name }
        .prefix(3).map { $0 }

        return PlayerProfile(
            games: ordered.count, accuracy: trend, phases: phaseStats, weakestPhase: weakest,
            themes: Array(themes), openings: openings
        )
    }

    /// Les parties du joueur contre l'ordinateur, analysées, vues de son côté.
    @MainActor
    static func compute(games records: [GameRecord]) -> PlayerProfile {
        let mine: [AnalyzedGame] = records.compactMap { record in
            guard record.mode == .vsEngine, let metrics = record.analysisMetrics,
                  let engineColor = record.engineColorRaw
            else { return nil }
            let userIsWhite = engineColor == Piece.Color.black.rawValue
            let side = userIsWhite ? metrics.white : metrics.black
            return AnalyzedGame(
                date: record.playedAt ?? .distantPast, accuracy: side.accuracy,
                phases: side.phases, themes: side.themes, openingName: metrics.openingName
            )
        }
        return compute(from: mine)
    }
}
