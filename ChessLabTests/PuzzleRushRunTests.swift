import Foundation
import Testing
@testable import ChessLab

/// « Contre la montre » (17/11/2026) : la règle, pure et datée de l'extérieur.
struct PuzzleRushRunTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func startsFourHundredPointsBelowTheRating_neverUnder600() {
        #expect(PuzzleRushRun(playerRating: 1500).startRating == 1100)
        #expect(PuzzleRushRun(playerRating: 800).startRating == 600)
    }

    @Test func eachSolvedPuzzleRaisesTheTarget_mistakesDoNot() {
        var run = PuzzleRushRun(playerRating: 1500)
        run.recordSolved(rating: 1120)
        run.recordSolved(rating: 1190)
        run.recordError()
        run.recordSolved(rating: 1150)
        #expect(run.targetRating == 1100 + 3 * PuzzleRushRun.ratingStep)
        #expect(run.highestSolvedRating == 1190)
    }

    @Test func theClockStopsDuringAPause() {
        var run = PuzzleRushRun(playerRating: 1500, duration: 180)
        run.start(at: t0)
        #expect(run.remaining(at: t0.addingTimeInterval(60)) == 120)
        run.pause(at: t0.addingTimeInterval(60))
        #expect(run.remaining(at: t0.addingTimeInterval(500)) == 120, "en pause, le temps ne coule pas")
        run.start(at: t0.addingTimeInterval(500))
        #expect(run.remaining(at: t0.addingTimeInterval(530)) == 90)
        #expect(!run.isOver(at: t0.addingTimeInterval(530)))
        #expect(run.isOver(at: t0.addingTimeInterval(620)))
        #expect(run.remaining(at: t0.addingTimeInterval(9_999)) == 0)
    }

    @Test func threeMistakesEndTheRun() {
        var run = PuzzleRushRun(playerRating: 1500)
        run.start(at: t0)
        run.recordError()
        run.recordError()
        #expect(!run.isOver(at: t0))
        run.recordError()
        run.recordError()
        #expect(run.errors == PuzzleRushRun.maxErrors)
        #expect(run.isOver(at: t0))
    }

    @MainActor
    @Test func theRecordKeepsTheBestOfDeviceAndCloud() throws {
        let defaults = try #require(UserDefaults(suiteName: "PuzzleRushRunTests.\(UUID().uuidString)"))
        #expect(PuzzleRushRecordStore.best(defaults: defaults, remote: nil) == 0)
        #expect(PuzzleRushRecordStore.submit(12, defaults: defaults, remote: nil) == (0, true))
        // Un autre appareil a fait 15 : 13 ne bat rien, et le 15 du nuage est recopié ici.
        #expect(PuzzleRushRecordStore.submit(13, defaults: defaults, remote: 15) == (15, false))
        #expect(defaults.integer(forKey: PuzzleRushRecordStore.key) == 15)
        #expect(PuzzleRushRecordStore.submit(16, defaults: defaults, remote: 15) == (15, true))
        #expect(PuzzleRushRecordStore.best(defaults: defaults, remote: 15) == 16)
    }

    @MainActor
    @Test func theRecordTravelsWithTheSettings() {
        #expect(SettingsCloudSync.syncedKeys.contains("puzzleRush.best.v1"))
    }
}
