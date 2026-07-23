import Foundation
import Testing
@testable import ChessLab

/// Bilan des puzzles (Lot 5.B du final-1407).
///
/// Le prompt demande « réussite, thèmes d'erreurs récurrents » — l'écran de
/// file n'avait plus aucune statistique.
@MainActor
struct PuzzleStatsTests {

    private func puzzle(theme: PuzzleTheme?, successes: Int, failures: Int) -> Puzzle {
        let puzzle = Puzzle()
        puzzle.themeRaw = theme?.rawValue
        puzzle.successCount = successes
        puzzle.failureCount = failures
        return puzzle
    }

    // MARK: Réussite globale

    @Test func successRateCountsEveryAttempt() {
        let stats = PuzzleStats.compute(from: [
            puzzle(theme: .fork, successes: 3, failures: 1),
            puzzle(theme: .pin, successes: 1, failures: 5),
        ])

        #expect(stats.attempts == 10)
        #expect(stats.successes == 4)
        #expect(stats.successRate == 0.4)
    }

    /// « 0 % » à quelqu'un qui n'a rien tenté serait faux ET décourageant :
    /// la carte ne s'affiche pas du tout dans ce cas.
    @Test func aFreshLibraryHasNoRateAtAll() {
        let stats = PuzzleStats.compute(from: [
            puzzle(theme: .fork, successes: 0, failures: 0),
            puzzle(theme: .pin, successes: 0, failures: 0),
        ])

        #expect(stats.successRate == nil)
        #expect(stats.attempts == 0)
        #expect(!stats.hasEnoughDataForThemes)
    }

    @Test func anEmptyLibraryDoesNotCrashTheBilan() {
        let stats = PuzzleStats.compute(from: [])

        #expect(stats.successRate == nil)
        #expect(stats.weakestThemes.isEmpty)
    }

    // MARK: Thèmes d'erreurs récurrents

    @Test func theWeakestThemeComesFirst() {
        let stats = PuzzleStats.compute(from: [
            puzzle(theme: .fork, successes: 1, failures: 7),      // 87 % d'échecs
            puzzle(theme: .pin, successes: 3, failures: 3),       // 50 %
            puzzle(theme: .checkmate, successes: 9, failures: 1), // 10 % → pas une faiblesse
        ])

        #expect(stats.weakestThemes.map(\.theme) == [.fork, .pin])
        #expect(stats.weakestThemes.first?.failureRate == 0.875)
    }

    /// Rater 1 puzzle sur 1 ne fait pas une faiblesse : sans ce seuil, la
    /// carte désignerait un thème dès le premier échec venu.
    @Test func aThemeWithTooFewAttemptsIsNotAWeakness() {
        let stats = PuzzleStats.compute(from: [
            puzzle(theme: .skewer, successes: 0, failures: 1),
        ])

        #expect(stats.weakestThemes.isEmpty, "un seul essai ne prouve rien")
        #expect(stats.successRate == 0, "il compte en revanche dans la réussite globale")
    }

    /// Un thème réussi à 90 % ne doit pas être « à travailler » sous prétexte
    /// qu'il est le moins bon de la liste.
    @Test func aThemeYouAreGoodAtIsNeverListed() {
        let stats = PuzzleStats.compute(from: [
            puzzle(theme: .checkmate, successes: 18, failures: 2),
        ])

        #expect(stats.weakestThemes.isEmpty)
        #expect(stats.successRate == 0.9)
    }

    /// Les essais d'un même thème s'additionnent : la faiblesse porte sur le
    /// THÈME, pas sur un puzzle isolé.
    @Test func attemptsOfTheSameThemeAreAggregated() {
        let stats = PuzzleStats.compute(from: [
            puzzle(theme: .fork, successes: 0, failures: 2),
            puzzle(theme: .fork, successes: 1, failures: 2),
        ])

        let fork = stats.weakestThemes.first
        #expect(fork?.theme == .fork)
        #expect(fork?.attempts == 5)
        #expect(fork?.failures == 4)
    }

    /// Donnée d'une version future : mieux vaut un thème manquant qu'un
    /// thème faux (rangé d'office dans « Tactique », par exemple).
    @Test func anUnknownThemeIsIgnoredButStillCounts() {
        let odd = puzzle(theme: nil, successes: 1, failures: 3)
        odd.themeRaw = "zugzwang_du_futur"

        let stats = PuzzleStats.compute(from: [odd])

        #expect(stats.attempts == 4, "l'essai compte dans la réussite globale")
        #expect(stats.weakestThemes.isEmpty, "mais il n'invente aucun thème")
    }
}
