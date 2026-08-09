import Foundation
import Testing
@testable import ChessLab

/// Vérifie les INVARIANTS de la planification FSRS-5 maison plutôt que des
/// valeurs « en dur » (fragiles) : monotonie des intervalles selon la note,
/// croissance de la stabilité au rappel, échec = rechute, et propriétés de la
/// courbe d'oubli. Ce sont ces garanties qui protègent la mémorisation.
struct FSRSTests {

    private let fsrs = FSRS()
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func firstIntervalGrowsWithRating() {
        let again = fsrs.review(.new, rating: .again, at: now)
        let hard = fsrs.review(.new, rating: .hard, at: now)
        let good = fsrs.review(.new, rating: .good, at: now)
        let easy = fsrs.review(.new, rating: .easy, at: now)

        #expect(again.scheduledDays <= hard.scheduledDays)
        #expect(hard.scheduledDays <= good.scheduledDays)
        #expect(good.scheduledDays < easy.scheduledDays)
    }

    @Test func newCardStateReflectsRating() {
        #expect(fsrs.review(.new, rating: .again, at: now).card.state == .learning)
        #expect(fsrs.review(.new, rating: .good, at: now).card.state == .review)
        #expect(fsrs.review(.new, rating: .good, at: now).card.reps == 1)
    }

    @Test func successfulRecallIncreasesStability() {
        let first = fsrs.review(.new, rating: .good, at: now).card
        let later = now.addingTimeInterval(Double(3) * 86_400)
        let second = fsrs.review(first, rating: .good, at: later)

        #expect(second.card.stability > first.stability)
        #expect(second.card.reps == 2)
        #expect(second.card.due != nil)
        #expect((second.card.due ?? now) > later)
    }

    @Test func lapseCountsAsFailureAndRelearns() {
        let card = fsrs.review(.new, rating: .good, at: now).card
        let later = now.addingTimeInterval(Double(3) * 86_400)
        let lapse = fsrs.review(card, rating: .again, at: later)

        #expect(lapse.card.lapses == card.lapses + 1)
        #expect(lapse.card.state == .relearning)
    }

    @Test func retrievabilityIsOneAtReviewAndTargetAtStability() {
        let card = fsrs.review(.new, rating: .good, at: now).card

        // À t = 0, rappel certain.
        #expect(abs(fsrs.retrievability(of: card, at: now) - 1.0) < 1e-9)

        // À t = stabilité, rappel = rétention désirée (0,9) par construction.
        let atStability = now.addingTimeInterval(card.stability * 86_400)
        #expect(abs(fsrs.retrievability(of: card, at: atStability) - 0.9) < 1e-6)

        // Décroissante dans le temps.
        let farLater = now.addingTimeInterval(card.stability * 5 * 86_400)
        #expect(fsrs.retrievability(of: card, at: farLater) < fsrs.retrievability(of: card, at: atStability))
    }

    @Test func newCardHasNoRetrievability() {
        #expect(fsrs.retrievability(of: .new, at: now) == 0)
    }
}
