import ChessKit
import Foundation

/// Palier de force du moteur, pour regrouper les résultats « contre
/// Stockfish » par niveau d'adversaire plutôt que d'aligner un Elo brut.
///
/// Bornes calées sur la plage du mode Jouer (`EngineStrength.playSliderRange`,
/// 800...2500) plus la pleine puissance (3190) : quatre paliers lisibles,
/// mêmes intentions que ``DifficultyTier`` côté puzzles.
enum EloBand: String, CaseIterable, Codable, Identifiable {
    case novice
    case amateur
    case club
    case expert

    var id: String { rawValue }

    var label: String {
        switch self {
        case .novice: "Débutant"
        case .amateur: "Amateur"
        case .club: "Joueur de club"
        case .expert: "Expert et +"
        }
    }

    /// Borne haute affichable (« ~1200 »), purement indicative pour l'UI.
    var range: ClosedRange<Int> {
        switch self {
        case .novice: 0...1199
        case .amateur: 1200...1699
        case .club: 1700...2199
        case .expert: 2200...Int.max
        }
    }

    static func band(forElo elo: Int) -> EloBand {
        allCases.first { $0.range.contains(elo) } ?? .expert
    }
}

/// Bilan de progression transversal : une vue d'ensemble de ce que
/// l'utilisateur a accompli, agrégée à partir des données **déjà
/// persistées** (parties de la bibliothèque, compteurs de puzzles). Aucune
/// nouvelle collecte — tout est dérivé de ``GameRecord`` et ``Puzzle`` tels
/// qu'ils existent.
///
/// PUR (listes → bilan), sans SwiftData ni UI : testable sur des cas
/// choisis, même discipline que ``PuzzleStats`` — qu'il réutilise pour les
/// thèmes faibles plutôt que de dupliquer cette logique.
///
/// - note: Les puzzles ne stockent que des compteurs CUMULÉS
///   (`successCount`/`failureCount`), pas un historique daté : ce bilan
///   décrit donc un ÉTAT (« où j'en suis »), pas une courbe dans le temps.
///   C'est assumé — mieux vaut un chiffre honnête qu'une fausse timeline.
struct ProgressionSummary: Equatable {

    // MARK: Puzzles

    let puzzleAttempts: Int
    let puzzleSuccesses: Int
    /// Réussite par palier de difficulté (puzzles Lichess notés seulement —
    /// un puzzle issu de vos parties n'a pas de note, voir ``Puzzle/rating``).
    let puzzlesByTier: [TierRecord]
    /// Thèmes tactiques les plus ratés — délégué à ``PuzzleStats`` (déjà testé).
    let weakestThemes: [PuzzleStats.ThemeRecord]

    var puzzleSuccessRate: Double? {
        puzzleAttempts == 0 ? nil : Double(puzzleSuccesses) / Double(puzzleAttempts)
    }

    /// Le palier le plus difficile où la réussite est SOLIDE (≥ 60 % sur au
    /// moins ``minimumAttemptsForReachedTier`` essais) — un « niveau atteint »
    /// honnête, à défaut d'une timeline. `nil` tant qu'aucun palier ne
    /// remplit le critère.
    var reachedTier: DifficultyTier? {
        // Du plus dur au plus facile : on renvoie le plus haut qui tient.
        let hardestFirst: [DifficultyTier] = [.expert, .advanced, .intermediate, .beginner]
        return hardestFirst.first { tier in
            guard let record = puzzlesByTier.first(where: { $0.tier == tier }) else { return false }
            return record.attempts >= Self.minimumAttemptsForReachedTier && record.successRate >= 0.6
        }
    }

    // MARK: Contre Stockfish

    let engineWins: Int
    let engineDraws: Int
    let engineLosses: Int
    /// Résultats groupés par palier de force de l'adversaire.
    let engineByBand: [BandRecord]
    /// Le plus haut Elo battu — la statistique qui motive. `nil` si aucune
    /// victoire enregistrée.
    let bestWinElo: Int?

    var engineGames: Int { engineWins + engineDraws + engineLosses }

    /// Rien à montrer tant que l'utilisateur n'a ni tenté un puzzle ni
    /// terminé une partie contre le moteur — l'écran affiche alors un état
    /// vide accueillant plutôt que des zéros décourageants.
    var hasAnyData: Bool { puzzleAttempts > 0 || engineGames > 0 }

    // MARK: Sous-structures

    struct TierRecord: Equatable, Identifiable {
        let tier: DifficultyTier
        let attempts: Int
        let successes: Int
        var id: String { tier.rawValue }
        var successRate: Double { attempts == 0 ? 0 : Double(successes) / Double(attempts) }
    }

    struct BandRecord: Equatable, Identifiable {
        let band: EloBand
        let wins: Int
        let draws: Int
        let losses: Int
        var id: String { band.rawValue }
        var games: Int { wins + draws + losses }
    }

    enum GameResult { case win, draw, loss }

    // MARK: Constantes

    /// En deçà, la réussite sur un palier ne veut rien dire (réussir 2/2 ne
    /// prouve pas qu'on « tient » le palier expert).
    static let minimumAttemptsForReachedTier = 5

    // MARK: Calcul

    static func compute(games: [GameRecord], puzzles: [Puzzle]) -> ProgressionSummary {
        // Puzzles — total + thèmes faibles délégués à PuzzleStats, plus une
        // ventilation par palier de difficulté propre à cet écran.
        let stats = PuzzleStats.compute(from: puzzles)

        var tierAccumulator: [DifficultyTier: (attempts: Int, successes: Int)] = [:]
        for puzzle in puzzles {
            let successes = puzzle.successCount ?? 0
            let failures = puzzle.failureCount ?? 0
            guard successes + failures > 0, let tier = puzzle.difficultyTier else { continue }
            tierAccumulator[tier, default: (0, 0)].attempts += successes + failures
            tierAccumulator[tier, default: (0, 0)].successes += successes
        }
        let tierRecords: [TierRecord] = DifficultyTier.allCases.compactMap { tier in
            guard let accumulated = tierAccumulator[tier] else { return nil }
            return TierRecord(tier: tier, attempts: accumulated.attempts, successes: accumulated.successes)
        }

        // Contre Stockfish — victoires/nulles/défaites, globales et par palier.
        var wins = 0
        var draws = 0
        var losses = 0
        var bandAccumulator: [EloBand: (wins: Int, draws: Int, losses: Int)] = [:]
        var bestWinElo: Int?

        for game in games {
            guard let result = userResult(of: game) else { continue }
            switch result {
            case .win: wins += 1
            case .draw: draws += 1
            case .loss: losses += 1
            }
            guard let elo = game.engineEloApprox else { continue }
            let band = EloBand.band(forElo: elo)
            switch result {
            case .win: bandAccumulator[band, default: (0, 0, 0)].wins += 1
            case .draw: bandAccumulator[band, default: (0, 0, 0)].draws += 1
            case .loss: bandAccumulator[band, default: (0, 0, 0)].losses += 1
            }
            if result == .win {
                bestWinElo = max(bestWinElo ?? 0, elo)
            }
        }
        let bandRecords: [BandRecord] = EloBand.allCases.compactMap { band in
            guard let accumulated = bandAccumulator[band] else { return nil }
            return BandRecord(
                band: band, wins: accumulated.wins,
                draws: accumulated.draws, losses: accumulated.losses
            )
        }

        return ProgressionSummary(
            puzzleAttempts: stats.attempts,
            puzzleSuccesses: stats.successes,
            puzzlesByTier: tierRecords,
            weakestThemes: stats.weakestThemes,
            engineWins: wins,
            engineDraws: draws,
            engineLosses: losses,
            engineByBand: bandRecords,
            bestWinElo: bestWinElo
        )
    }

    /// Résultat d'une partie DU POINT DE VUE DU JOUEUR. `nil` pour une partie
    /// à deux humains (aucun « vous ») ou un résultat illisible.
    ///
    /// La couleur du joueur se dérive de ``GameRecord/engineColorRaw`` (le
    /// moteur noir ⇒ le joueur est blanc) — champ sémantique, plutôt que du
    /// nom affiché « Vous » qui pourrait être localisé un jour. Repli sur le
    /// nom pour les tout premiers enregistrements sans couleur moteur.
    static func userResult(of record: GameRecord) -> GameResult? {
        guard record.mode == .vsEngine, let result = record.resultRaw else { return nil }

        let userIsWhite: Bool
        if let engineColor = record.engineColorRaw {
            userIsWhite = engineColor == Piece.Color.black.rawValue
        } else {
            userIsWhite = record.whiteName == "Vous"
        }

        switch result {
        case "1-0": return userIsWhite ? .win : .loss
        case "0-1": return userIsWhite ? .loss : .win
        case "1/2-1/2": return .draw
        default: return nil
        }
    }
}
