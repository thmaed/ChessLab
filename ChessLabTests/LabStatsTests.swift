import Foundation
import Testing
@testable import ChessLab

struct LabStatsTests {

    @Test func scoreCountsWinsAndHalvesDraws() {
        let stats = LabStats(results: [.winA, .winA, .draw, .winB], plyCounts: [40, 50, 60, 30])
        #expect(stats.games == 4)
        #expect(stats.winsA == 2)
        #expect(stats.draws == 1)
        #expect(stats.winsB == 1)
        // (2 + 0.5) / 4 = 0.625
        #expect(abs(stats.score - 0.625) < 1e-9)
    }

    @Test func equalScoreGivesZeroEloDifference() {
        let stats = LabStats(results: [.winA, .winA, .winB, .winB], plyCounts: [40, 40, 40, 40])
        #expect(abs(stats.score - 0.5) < 1e-9)
        let elo = try! #require(stats.eloDifference)
        #expect(abs(elo) < 1e-6)
    }

    @Test func aWinningMoreYieldsPositiveElo() {
        let stats = LabStats(results: [.winA, .winA, .winA, .winB], plyCounts: [40, 40, 40, 40])
        let elo = try! #require(stats.eloDifference)
        #expect(elo > 0)
    }

    @Test func perfectScoreHasNoFiniteEloDifference() {
        let stats = LabStats(results: [.winA, .winA, .winA], plyCounts: [40, 40, 40])
        #expect(stats.eloDifference == nil)
    }

    @Test func confidenceIntervalBracketsPointEstimate() {
        let results = Array(repeating: LabGameResult.winA, count: 12)
            + Array(repeating: .draw, count: 4)
            + Array(repeating: .winB, count: 4)
        let stats = LabStats(results: results, plyCounts: Array(repeating: 50, count: 20))
        let elo = try! #require(stats.eloDifference)
        let ci = try! #require(stats.elo95ConfidenceInterval)
        #expect(ci.low < elo)
        #expect(elo < ci.high)
    }

    @Test func likelihoodOfSuperiorityAboveHalfWhenAWinsMore() {
        let stats = LabStats(results: [.winA, .winA, .winA, .winA, .winB, .draw], plyCounts: [40, 40, 40, 40, 40, 40])
        #expect(stats.likelihoodOfSuperiority > 0.5)
    }

    @Test func likelihoodOfSuperiorityIsHalfWithNoDecisiveGames() {
        let stats = LabStats(results: [.draw, .draw, .draw], plyCounts: [40, 40, 40])
        #expect(abs(stats.likelihoodOfSuperiority - 0.5) < 1e-9)
    }

    @Test func averageMovesIsHalfOfAveragePlies() {
        let stats = LabStats(results: [.winA, .winB], plyCounts: [40, 60])
        #expect(abs(stats.averagePlies - 50) < 1e-9)
        #expect(abs(stats.averageMoves - 25) < 1e-9)
    }

    @Test func emptySeriesIsWellDefined() {
        let stats = LabStats(results: [], plyCounts: [])
        #expect(stats.games == 0)
        #expect(stats.score == 0)
        #expect(stats.averageMoves == 0)
        #expect(stats.eloDifference == nil)
    }

    @Test func progressionHasOnePointPerGameAndBracketsScore() {
        let games = [
            LabCompletedGame(index: 0, aWasWhite: true, pgnResult: "1-0", reasonLabel: "Mat", plyCount: 40, pgn: ""),      // winA
            LabCompletedGame(index: 1, aWasWhite: true, pgnResult: "1/2-1/2", reasonLabel: "Nulle", plyCount: 60, pgn: ""), // draw
            LabCompletedGame(index: 2, aWasWhite: false, pgnResult: "1-0", reasonLabel: "Mat", plyCount: 50, pgn: ""),      // winB
        ]
        let points = LabStats.progression(of: games)
        #expect(points.count == 3)
        #expect(points[0].game == 1)
        #expect(abs(points[0].scorePercent - 100) < 1e-9) // 1 partie gagnée par A → 100 %

        let finalStats = LabStats(results: games.map(\.labResult), plyCounts: games.map(\.plyCount))
        #expect(abs(points.last!.scorePercent - finalStats.scorePercent) < 1e-9)

        for point in points {
            #expect(point.ciLow <= point.scorePercent)
            #expect(point.scorePercent <= point.ciHigh)
            #expect(point.ciLow >= 0 && point.ciHigh <= 100)
        }
    }
}

struct LabCompletedGameTests {

    @Test func labResultMapsWhiteWinByColor() {
        let aAsWhiteWins = LabCompletedGame(index: 0, aWasWhite: true, pgnResult: "1-0", reasonLabel: "Mat", plyCount: 30, pgn: "")
        #expect(aAsWhiteWins.labResult == .winA)

        let aAsBlackAndWhiteWins = LabCompletedGame(index: 1, aWasWhite: false, pgnResult: "1-0", reasonLabel: "Mat", plyCount: 30, pgn: "")
        #expect(aAsBlackAndWhiteWins.labResult == .winB)
    }

    @Test func labResultMapsDraw() {
        let drawn = LabCompletedGame(index: 0, aWasWhite: true, pgnResult: "1/2-1/2", reasonLabel: "Pat", plyCount: 30, pgn: "")
        #expect(drawn.labResult == .draw)
    }
}

struct LabPersistenceTests {

    private func game(_ index: Int, aWhite: Bool = true, result: String = "1-0") -> LabCompletedGame {
        LabCompletedGame(index: index, aWasWhite: aWhite, pgnResult: result, reasonLabel: "Mat", plyCount: 40, pgn: "")
    }

    @Test func seriesStateComputesResumePoint() {
        var settings = LabGameSettings.default
        settings.gameCount = 3
        let state = LabSeriesState(settings: settings, completed: [game(0)], savedAt: Date())
        #expect(state.nextGameIndex == 1)
        #expect(state.isComplete == false)
    }

    @Test func seriesStateIsCompleteWhenAllGamesPlayed() {
        var settings = LabGameSettings.default
        settings.gameCount = 2
        let state = LabSeriesState(settings: settings, completed: [game(0), game(1)], savedAt: Date())
        #expect(state.isComplete)
    }

    @Test func seriesStateRoundTripsThroughJSON() throws {
        var settings = LabGameSettings.default
        settings.gameCount = 5
        settings.sideAEloSlider = 2400
        let state = LabSeriesState(settings: settings, completed: [game(0), game(1, aWhite: false, result: "0-1")], savedAt: Date())
        let data = try JSONEncoder().encode(state)
        let back = try JSONDecoder().decode(LabSeriesState.self, from: data)
        #expect(back.completed.count == 2)
        #expect(back.settings.gameCount == 5)
        #expect(back.settings.sideAEloSlider == 2400)
        #expect(back.nextGameIndex == 2)
    }

    @MainActor
    @Test func resumingViewModelStartsAtNextGame() {
        var settings = LabGameSettings.default
        settings.gameCount = 20
        let state = LabSeriesState(settings: settings, completed: [game(0), game(1)], savedAt: Date())
        let viewModel = LabViewModel(resuming: state)
        #expect(viewModel.currentGameIndex == 2)
        #expect(viewModel.completed.count == 2)
        #expect(viewModel.stats.games == 2)
    }
}

struct LabExportTests {

    private var sample: [LabCompletedGame] {
        [
            LabCompletedGame(index: 0, aWasWhite: true, pgnResult: "1-0", reasonLabel: "Mat", plyCount: 41, pgn: "1. e4 e5"),
            LabCompletedGame(index: 1, aWasWhite: false, pgnResult: "1/2-1/2", reasonLabel: "Répétition", plyCount: 80, pgn: "1. d4 d5"),
        ]
    }

    @Test func csvHasHeaderAndOneRowPerGame() {
        let csv = LabExport.csv(sample)
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 3) // en-tête + 2 parties
        #expect(lines[0] == "partie,camp_A,resultat,score_A,demi_coups,fin")
        #expect(lines[1].contains("1-0"))
        #expect(lines[1].hasPrefix("1,Blanc,1-0,1,41"))
    }

    @Test func pgnConcatenatesAllGamesWithHeadersAndResult() {
        var settings = LabGameSettings()
        settings.sideAEloSlider = 2200
        settings.sideBEloSlider = 2000
        let pgn = LabExport.pgn(sample, settings: settings)
        #expect(pgn.contains("1. e4 e5"))
        #expect(pgn.contains("1. d4 d5"))
        // En-têtes synthétiques + résultat en clôture du movetext.
        #expect(pgn.contains("[Event \"ChessLab Lab\"]"))
        #expect(pgn.contains("[White \"A (Elo 2200)\"]"))
        #expect(pgn.contains("[Result \"1-0\"]"))
        #expect(pgn.contains("1. e4 e5 1-0"))
        // Partie 2 : A jouait les Noirs, résultat nul.
        #expect(pgn.contains("[Black \"A (Elo 2200)\"]"))
        #expect(pgn.contains("1. d4 d5 1/2-1/2"))
    }
}
