import Foundation
import Testing
@testable import ChessLab

/// Sparring (bande bornée, retour vers zéro) et niveau estimé du joueur
/// (mise à jour Elo, bornée), plus la borne Fairy-Stockfish de l'Elo.
@Suite struct SparringAndPlayerLevelTests {

    @Test func sparringEasesOffWhenDominatingAndToughensWhenDominated() {
        #expect(Sparring.offset(after: 400, current: 0) == -25)
        #expect(Sparring.offset(after: -400, current: 0) == 25)
        #expect(Sparring.offset(after: 400, current: -150) == -150, "borné")
        #expect(Sparring.offset(after: -400, current: 150) == 150, "borné")
        // Partie disputée : retour doux vers le niveau nominal.
        #expect(Sparring.offset(after: 50, current: 100) == 87.5)
        #expect(Sparring.offset(after: -50, current: -100) == -87.5)
        #expect(Sparring.offset(after: 0, current: 0) == 0)
        #expect(Sparring.offset(after: nil, current: 75) == 75)
    }

    @Test func playerLevelFollowsAnEloUpdate() {
        #expect(abs(PlayerLevel.expectedScore(player: 1500, opponent: 1500) - 0.5) < 1e-9)
        #expect(PlayerLevel.updated(1500, against: 1500, result: .win) == 1516)
        #expect(PlayerLevel.updated(1500, against: 1500, result: .loss) == 1484)
        #expect(PlayerLevel.updated(1500, against: 1500, result: .draw) == 1500)
        #expect(PlayerLevel.updated(1500, against: 1900, result: .win) > 1520, "battre plus fort rapporte plus")
        #expect(PlayerLevel.updated(2800, against: 2800, result: .win) == 2800, "borné")
    }

    @Test func playerLevelIsSeededThenRemembered() {
        let name = "SparringAndPlayerLevelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        #expect(PlayerLevel.current(seed: 1300, defaults: defaults) == 1300)
        #expect(PlayerLevel.record(result: .win, against: 1300, seed: 1300, defaults: defaults) == 1316)
        #expect(PlayerLevel.current(seed: 999, defaults: defaults) == 1316)
    }

    @Test func fairyStockfishGetsAnEloInsideItsBounds() {
        #expect(EngineStrength.limited(elo: 2000).fairySetupCommands == EngineStrength.limited(elo: 2000).setupCommands)
        #expect(EngineStrength.limited(elo: 3000).fairySetupCommands == EngineStrength.maximum.setupCommands,
                "au-delà de 2850, plus de bridage plutôt qu'un 1350 silencieux")
        #expect(EngineStrength.maximum.fairySetupCommands == EngineStrength.maximum.setupCommands)
        let low = EngineStrength(sliderValue: 900)
        #expect(low.fairySetupCommands == low.setupCommands, "sous 1320 : Skill Level, pas UCI_Elo")
    }

    @Test func theSparringSettingDecodesWithoutItsKey() throws {
        let legacy = try #require("{\"opponentProfileID\": \"marc\"}".data(using: .utf8))
        #expect(try JSONDecoder().decode(PlayGameSettings.self, from: legacy).sparringEnabled == false)
    }
}
