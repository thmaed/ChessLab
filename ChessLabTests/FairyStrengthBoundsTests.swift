import Foundation
import Testing
@testable import ChessLab

/// Fairy-Stockfish n'accepte `UCI_Elo` qu'entre 500 et 2850 : au-delà, plus
/// de bridage plutôt qu'un 1350 silencieux.
@Suite struct FairyStrengthBoundsTests {
    @Test func fairyStockfishGetsAnEloInsideItsBounds() {
        #expect(EngineStrength.limited(elo: 2000).fairySetupCommands == EngineStrength.limited(elo: 2000).setupCommands)
        #expect(EngineStrength.limited(elo: 3000).fairySetupCommands == EngineStrength.maximum.setupCommands,
                "au-delà de 2850, plus de bridage plutôt qu'un 1350 silencieux")
        #expect(EngineStrength.maximum.fairySetupCommands == EngineStrength.maximum.setupCommands)
        let low = EngineStrength(sliderValue: 900)
        #expect(low.fairySetupCommands == low.setupCommands, "sous 1320 : Skill Level, pas UCI_Elo")
    }

    @Test func obsoleteAdaptiveKeysAreIgnoredWhenDecoding() throws {
        // Réglages enregistrés par la version qui avait les deux bascules.
        let legacy = try #require("{\"opponentProfileID\": \"marc\", \"profileAdaptiveEnabled\": true, \"sparringEnabled\": true}".data(using: .utf8))
        let decoded = try JSONDecoder().decode(PlayGameSettings.self, from: legacy)
        #expect(decoded.opponentProfileID == "marc")
    }
}
