import Foundation

/// Bilan de vos puzzles : taux de réussite global et **thèmes d'erreurs
/// récurrents** (Lot 5.B).
///
/// Le prompt le demande explicitement — « vous ratez souvent des
/// fourchettes ». L'écran de file avait perdu toute section de statistiques.
///
/// Calcul PUR (une liste de puzzles → un bilan), sans SwiftData ni UI : c'est
/// ce qui le rend testable sur des cas choisis plutôt que sur ce que contient
/// la base du moment.
struct PuzzleStats: Equatable {

    /// Un thème sur lequel vous butez.
    struct ThemeRecord: Equatable, Identifiable {
        let theme: PuzzleTheme
        let attempts: Int
        let failures: Int

        var id: String { theme.rawValue }
        var failureRate: Double { attempts == 0 ? 0 : Double(failures) / Double(attempts) }
        var successRate: Double { 1 - failureRate }
    }

    let attempts: Int
    let successes: Int

    /// Thèmes les plus ratés en premier. `nil`-safe : un thème sans assez
    /// d'essais n'y figure pas.
    let weakestThemes: [ThemeRecord]

    /// `nil` tant qu'aucun puzzle n'a été tenté : afficher « 0 % » à quelqu'un
    /// qui n'a rien tenté serait faux ET décourageant.
    var successRate: Double? {
        attempts == 0 ? nil : Double(successes) / Double(attempts)
    }

    var hasEnoughDataForThemes: Bool { !weakestThemes.isEmpty }

    /// En deçà, un thème ne dit rien : rater 1 puzzle sur 1 ne fait pas une
    /// faiblesse. Le prompt dit « affiché si ≥ N tentatives ».
    static let minimumAttemptsPerTheme = 4

    /// Un thème n'est « à travailler » qu'au-delà de ce taux d'échec — sinon
    /// on désignerait comme faiblesse un thème réussi à 90 %, juste parce
    /// qu'il est le moins bon de la liste.
    static let weaknessThreshold = 0.34

    static func compute(
        from puzzles: [Puzzle],
        minimumAttemptsPerTheme: Int = PuzzleStats.minimumAttemptsPerTheme
    ) -> PuzzleStats {
        var totalSuccesses = 0
        var totalFailures = 0
        var byTheme: [PuzzleTheme: (successes: Int, failures: Int)] = [:]

        for puzzle in puzzles {
            let successes = puzzle.successCount ?? 0
            let failures = puzzle.failureCount ?? 0
            guard successes + failures > 0 else { continue }

            totalSuccesses += successes
            totalFailures += failures

            // Un thème illisible (donnée d'une version future) est ignoré
            // plutôt que rangé dans « Tactique » : mieux vaut un thème
            // manquant qu'un thème faux.
            guard let raw = puzzle.themeRaw, let theme = PuzzleTheme(rawValue: raw) else { continue }
            byTheme[theme, default: (0, 0)].successes += successes
            byTheme[theme, default: (0, 0)].failures += failures
        }

        // Décomposé en étapes nommées : en une seule chaîne, le vérificateur
        // de types abandonne (piège récurrent du projet).
        var records: [ThemeRecord] = byTheme.map { theme, counts in
            ThemeRecord(
                theme: theme,
                attempts: counts.successes + counts.failures,
                failures: counts.failures
            )
        }
        records = records.filter { record in
            record.attempts >= minimumAttemptsPerTheme && record.failureRate > weaknessThreshold
        }
        records.sort { first, second in
            // Départage par nombre d'essais : à taux égal, le thème le plus
            // éprouvé est le plus significatif.
            if first.failureRate == second.failureRate {
                return first.attempts > second.attempts
            }
            return first.failureRate > second.failureRate
        }

        return PuzzleStats(
            attempts: totalSuccesses + totalFailures,
            successes: totalSuccesses,
            weakestThemes: records
        )
    }
}
