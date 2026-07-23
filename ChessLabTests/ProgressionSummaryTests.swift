import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Bilan de progression transversal (1.3) : agrégation PURE de ce qui est
/// déjà en base (parties, compteurs de puzzles). Testé sur des cas choisis
/// plutôt que sur le contenu du moment, comme ``PuzzleStats``.
@MainActor
struct ProgressionSummaryTests {

    // MARK: Fabriques

    private func puzzle(rating: Int?, successes: Int, failures: Int, theme: PuzzleTheme = .fork) -> Puzzle {
        let puzzle = Puzzle()
        puzzle.rating = rating
        puzzle.successCount = successes
        puzzle.failureCount = failures
        puzzle.themeRaw = theme.rawValue
        return puzzle
    }

    /// Partie contre le moteur. `userColor` = couleur du JOUEUR ; on stocke la
    /// couleur du MOTEUR (opposée), comme le fait `GameLibraryService`.
    private func engineGame(result: String, userColor: Piece.Color, elo: Int?) -> GameRecord {
        let record = GameRecord()
        record.modeRaw = GameRecordMode.vsEngine.rawValue
        record.resultRaw = result
        record.engineColorRaw = userColor.opposite.rawValue
        record.whiteName = userColor == .white ? "Vous" : "Stockfish"
        record.blackName = userColor == .black ? "Vous" : "Stockfish"
        record.engineEloApprox = elo
        return record
    }

    // MARK: Résultat du point de vue du joueur

    @Test func whiteWinIsAUserWinWhenUserIsWhite() {
        let game = engineGame(result: "1-0", userColor: .white, elo: 1500)
        #expect(ProgressionSummary.userResult(of: game) == .win)
    }

    @Test func whiteWinIsAUserLossWhenUserIsBlack() {
        let game = engineGame(result: "1-0", userColor: .black, elo: 1500)
        #expect(ProgressionSummary.userResult(of: game) == .loss)
    }

    @Test func drawIsADrawRegardlessOfColor() {
        #expect(ProgressionSummary.userResult(of: engineGame(result: "1/2-1/2", userColor: .white, elo: 1500)) == .draw)
        #expect(ProgressionSummary.userResult(of: engineGame(result: "1/2-1/2", userColor: .black, elo: 1500)) == .draw)
    }

    @Test func twoHumanGameHasNoUserResult() {
        let record = GameRecord()
        record.modeRaw = GameRecordMode.twoHuman.rawValue
        record.resultRaw = "1-0"
        #expect(ProgressionSummary.userResult(of: record) == nil)
    }

    @Test func unreadableResultIsIgnored() {
        let record = engineGame(result: "*", userColor: .white, elo: 1500)
        #expect(ProgressionSummary.userResult(of: record) == nil)
    }

    // MARK: Agrégation contre Stockfish

    @Test func winsDrawsLossesAreCounted() {
        let games = [
            engineGame(result: "1-0", userColor: .white, elo: 1400),
            engineGame(result: "0-1", userColor: .white, elo: 1400),
            engineGame(result: "1/2-1/2", userColor: .black, elo: 1400),
        ]
        let summary = ProgressionSummary.compute(games: games, puzzles: [])
        #expect(summary.engineWins == 1)
        #expect(summary.engineLosses == 1)
        #expect(summary.engineDraws == 1)
        #expect(summary.engineGames == 3)
    }

    @Test func bestWinEloIsTheHighestBeaten() {
        let games = [
            engineGame(result: "1-0", userColor: .white, elo: 1400),   // gagnée
            engineGame(result: "1-0", userColor: .white, elo: 2100),   // gagnée, plus fort
            engineGame(result: "0-1", userColor: .white, elo: 2500),   // perdue — ne compte pas
        ]
        let summary = ProgressionSummary.compute(games: games, puzzles: [])
        #expect(summary.bestWinElo == 2100)
    }

    @Test func noWinMeansNoBestWinElo() {
        let games = [engineGame(result: "0-1", userColor: .white, elo: 2000)]
        #expect(ProgressionSummary.compute(games: games, puzzles: []).bestWinElo == nil)
    }

    @Test func resultsAreGroupedByEloBand() {
        let games = [
            engineGame(result: "1-0", userColor: .white, elo: 1000),   // novice
            engineGame(result: "1-0", userColor: .white, elo: 1500),   // amateur
            engineGame(result: "0-1", userColor: .white, elo: 1500),   // amateur
        ]
        let summary = ProgressionSummary.compute(games: games, puzzles: [])
        let amateur = try? #require(summary.engineByBand.first { $0.band == .amateur })
        #expect(amateur?.wins == 1)
        #expect(amateur?.losses == 1)
        #expect(amateur?.games == 2)
        #expect(summary.engineByBand.first { $0.band == .club } == nil) // aucun match ici
    }

    // MARK: Agrégation puzzles

    @Test func puzzleSuccessRateCountsEveryAttempt() {
        let puzzles = [
            puzzle(rating: 800, successes: 3, failures: 1),
            puzzle(rating: 1500, successes: 1, failures: 5),
        ]
        let summary = ProgressionSummary.compute(games: [], puzzles: puzzles)
        #expect(summary.puzzleAttempts == 10)
        #expect(summary.puzzleSuccesses == 4)
        #expect(summary.puzzleSuccessRate == 0.4)
    }

    @Test func puzzlesAreGroupedByDifficultyTier() {
        let puzzles = [
            puzzle(rating: 800, successes: 4, failures: 0),    // débutant
            puzzle(rating: 1500, successes: 2, failures: 2),   // intermédiaire
        ]
        let summary = ProgressionSummary.compute(games: [], puzzles: puzzles)
        let beginner = try? #require(summary.puzzlesByTier.first { $0.tier == .beginner })
        #expect(beginner?.attempts == 4)
        #expect(beginner?.successRate == 1.0)
    }

    @Test func unratedPuzzlesCountOverallButNotInAnyTier() {
        // Un puzzle issu de vos parties (rating nil) n'a pas de palier.
        let puzzles = [puzzle(rating: nil, successes: 2, failures: 1)]
        let summary = ProgressionSummary.compute(games: [], puzzles: puzzles)
        #expect(summary.puzzleAttempts == 3)
        #expect(summary.puzzlesByTier.isEmpty)
    }

    @Test func reachedTierIsTheHardestSolidOne() {
        let puzzles = [
            puzzle(rating: 800, successes: 10, failures: 0),   // débutant : solide
            puzzle(rating: 1500, successes: 8, failures: 2),   // intermédiaire : 80 %, solide
            puzzle(rating: 1800, successes: 1, failures: 9),   // confirmé : 10 %, pas solide
        ]
        let summary = ProgressionSummary.compute(games: [], puzzles: puzzles)
        #expect(summary.reachedTier == .intermediate)
    }

    @Test func reachedTierNeedsEnoughAttempts() {
        // 2/2 en expert ne prouve rien : sous le seuil, pas de palier atteint.
        let puzzles = [puzzle(rating: 2200, successes: 2, failures: 0)]
        #expect(ProgressionSummary.compute(games: [], puzzles: puzzles).reachedTier == nil)
    }

    // MARK: État vide

    @Test func emptyInputHasNoData() {
        let summary = ProgressionSummary.compute(games: [], puzzles: [])
        #expect(!summary.hasAnyData)
        #expect(summary.puzzleSuccessRate == nil)
        #expect(summary.bestWinElo == nil)
    }

    @Test func anyPuzzleOrGameCountsAsData() {
        let withPuzzle = ProgressionSummary.compute(games: [], puzzles: [puzzle(rating: 800, successes: 1, failures: 0)])
        #expect(withPuzzle.hasAnyData)
        let withGame = ProgressionSummary.compute(games: [engineGame(result: "1-0", userColor: .white, elo: 1200)], puzzles: [])
        #expect(withGame.hasAnyData)
    }
}
