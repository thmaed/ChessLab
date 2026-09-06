import Foundation
import Testing
@testable import ChessLab

/// « S'adapte à mes résultats » : un pas fixe, borné, une nulle ne bouge pas.
@Suite struct AdaptiveLevelTests {
    @Test func aWinRaisesALossLowersADrawHolds() {
        #expect(AdaptiveLevel.next(after: .win, level: 1500) == 1525)
        #expect(AdaptiveLevel.next(after: .loss, level: 1500) == 1475)
        #expect(AdaptiveLevel.next(after: .draw, level: 1500) == 1500)
    }

    @Test func theLevelStaysInsideTheSliderRange() {
        #expect(AdaptiveLevel.next(after: .win, level: 2500) == 2500)
        #expect(AdaptiveLevel.next(after: .loss, level: 800) == 800)
        #expect(AdaptiveLevel.next(after: .win, level: 1490) == 1525, "arrondi au pas")
    }

    @Test func theSettingSurvivesDecodingWithoutTheKey() throws {
        let legacy = try #require("{\"opponentProfileID\": \"lea\"}".data(using: .utf8))
        let decoded = try JSONDecoder().decode(PlayGameSettings.self, from: legacy)
        #expect(decoded.profileAdaptiveEnabled == false)
        var settings = PlayGameSettings.default
        settings.profileAdaptiveEnabled = true
        let round = try JSONDecoder().decode(PlayGameSettings.self, from: JSONEncoder().encode(settings))
        #expect(round.profileAdaptiveEnabled)
    }
}
