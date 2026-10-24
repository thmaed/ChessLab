import Foundation
import Testing
@testable import ChessLab

/// La cote de puzzle personnelle (Glicko) — valeur pure.
struct PuzzleRatingTests {

    @Test func startsAt1500WithAWideUncertainty() {
        let rating = PuzzleRating.initial
        #expect(rating.displayed == 1500)
        #expect(rating.deviation == 350)
        #expect(!rating.isSettled)
    }

    @Test func solvingAHarderPuzzleRaisesTheRatingMoreThanAnEasierOne() {
        var vsHard = PuzzleRating.initial
        vsHard.record(solved: true, againstPuzzleRated: 1900)
        var vsEasy = PuzzleRating.initial
        vsEasy.record(solved: true, againstPuzzleRated: 1100)
        #expect(vsHard.rating > vsEasy.rating)
        #expect(vsEasy.rating > 1500)
    }

    @Test func failingLowersTheRating() {
        var rating = PuzzleRating.initial
        rating.record(solved: false, againstPuzzleRated: 1500)
        #expect(rating.rating < 1500)
    }

    @Test func theUncertaintyShrinksButNeverBelowTheFloor() {
        var rating = PuzzleRating.initial
        for _ in 0..<300 { rating.record(solved: true, againstPuzzleRated: 1500) }
        #expect(rating.deviation < 350)
        #expect(rating.deviation >= PuzzleRating.minDeviation)
        #expect(rating.isSettled)
    }

    /// Un joueur qui réussit ~50 % des puzzles de cote 1700 vaut ~1700.
    @Test func convergesTowardsTheLevelAtWhichHalfAreSolved() {
        var rating = PuzzleRating.initial
        var generator = SystemRandomNumberGenerator()
        // Probabilité de réussite de la loi d'Elo, pour un joueur de force 1700.
        for _ in 0..<600 {
            let puzzle = Int.random(in: 1300...2100, using: &generator)
            let probability = 1 / (1 + pow(10, Double(puzzle - 1700) / 400))
            rating.record(solved: Double.random(in: 0..<1, using: &generator) < probability,
                          againstPuzzleRated: puzzle)
        }
        #expect(abs(rating.rating - 1700) < 120, "cote obtenue : \(rating.rating)")
    }

    @Test func theWindowFollowsTheRatingAndWidensWithUncertainty() {
        var rating = PuzzleRating.initial
        let wide = rating.window
        for _ in 0..<200 { rating.record(solved: true, againstPuzzleRated: 1500) }
        let narrow = rating.window
        #expect(wide.count > narrow.count)
        #expect(narrow.contains(rating.displayed))
        #expect(narrow.count >= 199, "au plus serré : ±100")
    }

    @Test func survivesAJSONRoundTripThroughTheStore() {
        let defaults = UserDefaults(suiteName: "PuzzleRatingTests.\(UUID().uuidString)")!
        #expect(PuzzleRatingStore.load(from: defaults) == .initial)
        let after = PuzzleRatingStore.record(solved: true, againstPuzzleRated: 1800, in: defaults)
        #expect(PuzzleRatingStore.load(from: defaults) == after)
        #expect(after.count == 1)
    }

    @MainActor
    @Test func theRatingTravelsWithTheSettings() {
        #expect(SettingsCloudSync.syncedKeys.contains(PuzzleRatingStore.key))
    }
}
